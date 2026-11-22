"""Business reports. Each report is one SQL query; Python only formats the result."""


def sales_by_category(conn):
    return conn.execute("""
        SELECT c.name AS category,
               SUM(oi.qty)                  AS units,
               ROUND(SUM(oi.qty*oi.unit_price), 2) AS revenue
        FROM order_items oi
        JOIN orders o     ON o.id = oi.order_id AND o.status = 'PAID'
        JOIN products p   ON p.id = oi.product_id
        JOIN categories c ON c.id = p.category_id
        GROUP BY c.id
        ORDER BY revenue DESC""").fetchall()


def top_customers(conn, limit=3):
    return conn.execute("""
        SELECT c.name, c.tier, COUNT(o.id) AS orders, ROUND(SUM(o.total), 2) AS spent
        FROM customers c
        JOIN orders o ON o.customer_id = c.id AND o.status = 'PAID'
        GROUP BY c.id
        ORDER BY spent DESC
        LIMIT ?""", (limit,)).fetchall()


def low_stock(conn):
    return conn.execute("SELECT sku, name, stock, reorder_level FROM v_low_stock ORDER BY stock").fetchall()


def monthly_revenue(conn):
    return conn.execute("""
        SELECT strftime('%Y-%m', created_at) AS month,
               COUNT(*) AS orders,
               ROUND(SUM(total), 2) AS revenue
        FROM orders WHERE status = 'PAID'
        GROUP BY month ORDER BY month""").fetchall()


def best_sellers(conn, limit=3):
    return conn.execute("""
        SELECT p.sku, p.name, SUM(oi.qty) AS units
        FROM order_items oi
        JOIN orders o   ON o.id = oi.order_id AND o.status = 'PAID'
        JOIN products p ON p.id = oi.product_id
        GROUP BY p.id ORDER BY units DESC LIMIT ?""", (limit,)).fetchall()


def print_table(title, rows):
    print(f"\n=== {title} ===")
    if not rows:
        print("  (none)")
        return
    cols = rows[0].keys()
    widths = [max(len(c), *(len(str(r[c])) for r in rows)) for c in cols]
    print("  " + "  ".join(c.upper().ljust(w) for c, w in zip(cols, widths)))
    for r in rows:
        print("  " + "  ".join(str(r[c]).ljust(w) for c, w in zip(cols, widths)))


def full_report(conn):
    print_table("Sales by category", sales_by_category(conn))
    print_table("Monthly revenue", monthly_revenue(conn))
    print_table("Top customers", top_customers(conn))
    print_table("Best sellers", best_sellers(conn))
    print_table("Low stock", low_stock(conn))
