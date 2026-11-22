"""Tests for the retail shop (run: python -m unittest -v)."""
import sqlite3
import unittest

import db
import reports
import seed
import shop


class ShopTests(unittest.TestCase):
    def setUp(self):
        self.conn = db.connect(":memory:")
        db.init_db(self.conn)
        self.ids = seed.seed(self.conn)

    def tearDown(self):
        self.conn.close()

    def stock(self, sku):
        return self.conn.execute("SELECT stock FROM products WHERE sku=?", (sku,)).fetchone()[0]

    def tier(self, cid):
        return self.conn.execute("SELECT tier FROM customers WHERE id=?", (cid,)).fetchone()[0]

    def test_order_reduces_stock_for_new_bronze_customer_at_full_price(self):
        newbie = shop.add_customer(self.conn, "Newbie", "newbie@example.com")
        self.assertEqual(self.tier(newbie), "BRONZE")
        before = self.stock("PEN-001")
        oid = shop.place_order(self.conn, newbie, [("PEN-001", 2)])
        row = self.conn.execute("SELECT * FROM orders WHERE id=?", (oid,)).fetchone()
        self.assertEqual(self.stock("PEN-001"), before - 2)
        self.assertEqual((row["subtotal"], row["discount"], row["total"]), (240, 0, 240))

    def test_gold_customer_gets_10_percent(self):
        self.assertEqual(self.tier(self.ids[0]), "GOLD")
        oid = shop.place_order(self.conn, self.ids[0], [("PEN-001", 10)])
        row = self.conn.execute("SELECT * FROM orders WHERE id=?", (oid,)).fetchone()
        self.assertEqual((row["subtotal"], row["discount"], row["total"]), (1200, 120, 1080))

    def test_insufficient_stock_rolls_back_whole_order(self):
        count = self.conn.execute("SELECT COUNT(*) FROM orders").fetchone()[0]
        hdp = self.stock("HDP-001")
        with self.assertRaises(shop.ShopError):
            shop.place_order(self.conn, self.ids[3], [("HDP-001", 1), ("DSK-001", 999)])
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM orders").fetchone()[0], count)
        self.assertEqual(self.stock("HDP-001"), hdp)

    def test_unknown_sku_and_bad_quantity_rejected(self):
        with self.assertRaises(shop.ShopError):
            shop.place_order(self.conn, self.ids[0], [("NOPE", 1)])
        with self.assertRaises(shop.ShopError):
            shop.place_order(self.conn, self.ids[0], [("PEN-001", 0)])
        with self.assertRaises(shop.ShopError):
            shop.place_order(self.conn, self.ids[0], [])

    def test_database_itself_refuses_negative_stock(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute("UPDATE products SET stock = -1 WHERE sku='PEN-001'")

    def test_cancel_restores_stock_and_demotes_tier(self):
        newbie = shop.add_customer(self.conn, "Newbie", "newbie@example.com")
        oid = shop.place_order(self.conn, newbie, [("PEN-001", 10)])   # 1,200 -> SILVER
        self.assertEqual(self.tier(newbie), "SILVER")
        before = self.stock("PEN-001")
        shop.cancel_order(self.conn, oid)
        self.assertEqual(self.stock("PEN-001"), before + 10)
        self.assertEqual(self.tier(newbie), "BRONZE")
        with self.assertRaises(shop.ShopError):
            shop.cancel_order(self.conn, oid)

    def test_tier_thresholds(self):
        self.assertEqual([self.tier(i) for i in self.ids], ["GOLD", "GOLD", "GOLD", "GOLD"])

    def test_price_change_is_audited_by_trigger(self):
        shop.set_price(self.conn, "PHN-001", 15000)
        row = self.conn.execute("SELECT * FROM price_history").fetchone()
        self.assertEqual((row["old_price"], row["new_price"]), (18000, 15000))

    def test_old_orders_keep_their_original_price(self):
        shop.set_price(self.conn, "PHN-001", 1)
        unit = self.conn.execute(
            "SELECT unit_price FROM order_items WHERE product_id="
            "(SELECT id FROM products WHERE sku='PHN-001') LIMIT 1").fetchone()[0]
        self.assertEqual(unit, 18000)

    def test_auto_reorder_and_receive(self):
        shop.place_order(self.conn, self.ids[0], [("DSK-001", 3)])   # drops desks to low stock
        created = shop.auto_reorder(self.conn)
        skus = [sku for _, sku, _ in created]
        self.assertIn("DSK-001", skus)
        self.assertEqual(shop.auto_reorder(self.conn), [])           # no duplicate POs
        before = self.stock("DSK-001")
        po_id = next(po for po, sku, _ in created if sku == "DSK-001")
        qty = next(q for po, sku, q in created if sku == "DSK-001")
        shop.receive_purchase_order(self.conn, po_id)
        self.assertEqual(self.stock("DSK-001"), before + qty)
        with self.assertRaises(shop.ShopError):
            shop.receive_purchase_order(self.conn, po_id)

    def test_stock_ledger_matches_stock_level(self):
        rows = self.conn.execute("""
            SELECT p.sku, p.stock, COALESCE(SUM(m.change),0) AS ledger
            FROM products p LEFT JOIN stock_movements m ON m.product_id = p.id
            GROUP BY p.id""").fetchall()
        for r in rows:
            self.assertEqual(r["stock"], r["ledger"], r["sku"])

    def test_reports_ignore_cancelled_orders(self):
        total_before = sum(r["revenue"] for r in reports.monthly_revenue(self.conn))
        shop.cancel_order(self.conn, 7)
        total_after = sum(r["revenue"] for r in reports.monthly_revenue(self.conn))
        self.assertLess(total_after, total_before)

    def test_invalid_customer_email_rejected(self):
        with self.assertRaises(shop.ShopError):
            shop.add_customer(self.conn, "X", "not-an-email")


if __name__ == "__main__":
    unittest.main()
