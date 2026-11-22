"""Business logic for the retail shop.

Python decides *what should happen* (discount rules, loyalty tiers, reorder
policy) and runs it as SQL inside transactions, so a failed step never leaves
half an order behind.
"""

# (tier, minimum lifetime spend, discount rate) - highest first
TIERS = [("GOLD", 5000, 0.10), ("SILVER", 1000, 0.05), ("BRONZE", 0, 0.0)]
REORDER_MULTIPLIER = 3   # order enough to reach 3x the reorder level


class ShopError(Exception):
    """Raised for any rule violation; the surrounding transaction rolls back."""


def discount_rate(tier):
    return next(rate for name, _, rate in TIERS if name == tier)


# ---------------------------------------------------------------- master data
def add_category(conn, name):
    with conn:
        conn.execute("INSERT OR IGNORE INTO categories(name) VALUES (?)", (name,))
    return conn.execute("SELECT id FROM categories WHERE name=?", (name,)).fetchone()["id"]


def add_product(conn, sku, name, category, price, stock, reorder_level=5):
    category_id = add_category(conn, category)
    with conn:
        cur = conn.execute(
            "INSERT INTO products(sku,name,category_id,price,stock,reorder_level) "
            "VALUES (?,?,?,?,?,?)",
            (sku, name, category_id, price, stock, reorder_level))
        if stock:
            conn.execute("INSERT INTO stock_movements(product_id,change,reason) VALUES (?,?,?)",
                         (cur.lastrowid, stock, "OPENING"))
    return cur.lastrowid


def add_customer(conn, name, email):
    if "@" not in email:
        raise ShopError(f"Invalid email: {email!r}")
    with conn:
        cur = conn.execute("INSERT INTO customers(name,email) VALUES (?,?)", (name, email))
    return cur.lastrowid


def set_price(conn, sku, new_price):
    """Change a price. The DB trigger records the change in price_history."""
    if new_price < 0:
        raise ShopError("Price cannot be negative")
    with conn:
        cur = conn.execute("UPDATE products SET price=? WHERE sku=?", (new_price, sku))
        if cur.rowcount == 0:
            raise ShopError(f"Unknown SKU {sku}")


# --------------------------------------------------------------------- orders
def _refresh_tier(conn, customer_id):
    """Promote a customer according to lifetime spend on PAID orders."""
    spend = conn.execute(
        "SELECT COALESCE(SUM(total),0) FROM orders WHERE customer_id=? AND status='PAID'",
        (customer_id,)).fetchone()[0]
    tier = next(name for name, minimum, _ in TIERS if spend >= minimum)
    conn.execute("UPDATE customers SET tier=? WHERE id=?", (tier, customer_id))
    return tier


def place_order(conn, customer_id, items, placed_at=None):
    """Place an order for [(sku, qty), ...]; all-or-nothing.

    Stock is taken with a guarded UPDATE (`stock >= qty`), which is safe even if
    two sessions order the last unit at the same time.
    """
    if not items:
        raise ShopError("An order needs at least one item")
    with conn:   # commit on success, rollback on any exception
        customer = conn.execute("SELECT * FROM customers WHERE id=?", (customer_id,)).fetchone()
        if customer is None:
            raise ShopError(f"Unknown customer {customer_id}")
        order_id = conn.execute(
            "INSERT INTO orders(customer_id, created_at) VALUES (?, COALESCE(?, CURRENT_TIMESTAMP))",
            (customer_id, placed_at)).lastrowid

        subtotal = 0.0
        for sku, qty in items:
            if qty <= 0:
                raise ShopError(f"Quantity for {sku} must be positive")
            product = conn.execute("SELECT id, price, stock FROM products WHERE sku=?",
                                   (sku,)).fetchone()
            if product is None:
                raise ShopError(f"Unknown SKU {sku}")
            taken = conn.execute("UPDATE products SET stock = stock - ? WHERE id=? AND stock >= ?",
                                 (qty, product["id"], qty))
            if taken.rowcount == 0:
                raise ShopError(f"Insufficient stock for {sku}: wanted {qty}, have {product['stock']}")
            conn.execute("INSERT INTO order_items(order_id,product_id,qty,unit_price) VALUES (?,?,?,?)",
                         (order_id, product["id"], qty, product["price"]))
            conn.execute("INSERT INTO stock_movements(product_id,change,reason) VALUES (?,?,?)",
                         (product["id"], -qty, f"SALE order {order_id}"))
            subtotal += qty * product["price"]

        discount = round(subtotal * discount_rate(customer["tier"]), 2)
        conn.execute("UPDATE orders SET subtotal=?, discount=?, total=? WHERE id=?",
                     (round(subtotal, 2), discount, round(subtotal - discount, 2), order_id))
        _refresh_tier(conn, customer_id)
    return order_id


def cancel_order(conn, order_id):
    """Cancel a PAID order, return its items to stock and re-evaluate the tier."""
    with conn:
        order = conn.execute("SELECT * FROM orders WHERE id=?", (order_id,)).fetchone()
        if order is None:
            raise ShopError(f"Unknown order {order_id}")
        if order["status"] == "CANCELLED":
            raise ShopError(f"Order {order_id} is already cancelled")
        for item in conn.execute("SELECT product_id, qty FROM order_items WHERE order_id=?", (order_id,)):
            conn.execute("UPDATE products SET stock = stock + ? WHERE id=?", (item["qty"], item["product_id"]))
            conn.execute("INSERT INTO stock_movements(product_id,change,reason) VALUES (?,?,?)",
                         (item["product_id"], item["qty"], f"CANCEL order {order_id}"))
        conn.execute("UPDATE orders SET status='CANCELLED' WHERE id=?", (order_id,))
        _refresh_tier(conn, order["customer_id"])


# ------------------------------------------------------------------ purchasing
def auto_reorder(conn):
    """Raise one OPEN purchase order for every low-stock product that has none."""
    created = []
    with conn:
        rows = conn.execute("""
            SELECT l.id, l.sku, l.stock, l.reorder_level
            FROM v_low_stock l
            WHERE NOT EXISTS (SELECT 1 FROM purchase_orders po
                              WHERE po.product_id = l.id AND po.status = 'OPEN')""").fetchall()
        for row in rows:
            qty = max(1, row["reorder_level"] * REORDER_MULTIPLIER - row["stock"])
            po_id = conn.execute("INSERT INTO purchase_orders(product_id,qty) VALUES (?,?)",
                                 (row["id"], qty)).lastrowid
            created.append((po_id, row["sku"], qty))
    return created


def receive_purchase_order(conn, po_id):
    """Goods arrive: add the quantity to stock and close the purchase order."""
    with conn:
        po = conn.execute("SELECT * FROM purchase_orders WHERE id=?", (po_id,)).fetchone()
        if po is None or po["status"] != "OPEN":
            raise ShopError(f"Purchase order {po_id} is not open")
        conn.execute("UPDATE products SET stock = stock + ? WHERE id=?", (po["qty"], po["product_id"]))
        conn.execute("INSERT INTO stock_movements(product_id,change,reason) VALUES (?,?,?)",
                     (po["product_id"], po["qty"], f"RECEIVE PO {po_id}"))
        conn.execute("UPDATE purchase_orders SET status='RECEIVED' WHERE id=?", (po_id,))
