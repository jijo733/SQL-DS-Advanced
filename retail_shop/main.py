"""Command-line front end for the retail shop.

    python main.py demo        build a fresh database, seed it and show a full business day
    python main.py report      print all reports for the existing database
    python main.py order <customer_id> SKU:QTY [SKU:QTY ...]
    python main.py cancel <order_id>
    python main.py reorder     raise purchase orders for low-stock items
    python main.py receive <po_id>
    python main.py price <SKU> <new_price>
"""
import sys

import db
import reports
import seed
import shop


def demo():
    if db.DEFAULT_DB.exists():
        db.DEFAULT_DB.unlink()
    conn = db.connect()
    db.init_db(conn)
    ids = seed.seed(conn)
    print(f"Seeded {len(seed.PRODUCTS)} products, {len(ids)} customers, {len(seed.ORDERS)} orders.")
    reports.full_report(conn)

    print("\n--- Business actions driven from Python ---")

    print("\n1) Order with too little stock is rejected and rolled back:")
    try:
        shop.place_order(conn, ids[3], [("HDP-001", 1), ("DSK-001", 99)])
    except shop.ShopError as err:
        print("   REJECTED:", err)
    stock = conn.execute("SELECT stock FROM products WHERE sku='HDP-001'").fetchone()[0]
    print(f"   HDP-001 stock is still {stock} (the headphones line was rolled back too)")

    print("\n2) Price change is audited automatically by an SQL trigger:")
    shop.set_price(conn, "PHN-001", 16999)
    for row in conn.execute("SELECT * FROM price_history"):
        print(f"   product {row['product_id']}: {row['old_price']} -> {row['new_price']}")

    print("\n3) Loyalty tiers follow lifetime spend; cancelling an order reverses it:")
    tier = lambda cid: conn.execute("SELECT tier FROM customers WHERE id=?", (cid,)).fetchone()[0]
    newbie = shop.add_customer(conn, "Esha Menon", "esha@example.com")
    print(f"   New customer starts as {tier(newbie)}")
    oid = shop.place_order(conn, newbie, [("PEN-001", 10)])
    print(f"   After a 1,200 order (#{oid}) -> {tier(newbie)}")
    shop.cancel_order(conn, oid)
    print(f"   After cancelling #{oid} (stock returned) -> {tier(newbie)}")

    print("\n4) Auto-reorder low-stock items, then receive the goods:")
    created = shop.auto_reorder(conn)
    for po_id, sku, qty in created:
        print(f"   PO {po_id}: {qty} x {sku}")
    for po_id, _, _ in created:
        shop.receive_purchase_order(conn, po_id)
    print("   All purchase orders received.")
    reports.print_table("Low stock after receiving", reports.low_stock(conn))
    conn.close()


def main(argv):
    if not argv or argv[0] == "demo":
        return demo()
    conn = db.connect()
    db.init_db(conn)
    cmd, args = argv[0], argv[1:]
    try:
        if cmd == "report":
            reports.full_report(conn)
        elif cmd == "order":
            items = [(s.split(":")[0], int(s.split(":")[1])) for s in args[1:]]
            print("Order placed:", shop.place_order(conn, int(args[0]), items))
        elif cmd == "cancel":
            shop.cancel_order(conn, int(args[0]))
            print("Order cancelled.")
        elif cmd == "reorder":
            print(shop.auto_reorder(conn) or "Nothing to reorder.")
        elif cmd == "receive":
            shop.receive_purchase_order(conn, int(args[0]))
            print("Received.")
        elif cmd == "price":
            shop.set_price(conn, args[0], float(args[1]))
            print("Price updated.")
        else:
            print(__doc__)
    except (shop.ShopError, IndexError, ValueError) as err:
        print("Error:", err)
        return 1
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
