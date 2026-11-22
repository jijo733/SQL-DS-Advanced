"""Sample data so the project can be demonstrated straight away."""
import shop

PRODUCTS = [
    # sku, name, category, price, stock, reorder_level
    ("LAP-001", "Laptop 14in",          "Electronics", 52000, 12, 4),
    ("PHN-001", "Smartphone",           "Electronics", 18000, 25, 8),
    ("HDP-001", "Headphones",           "Electronics",  2500, 40, 10),
    ("DSK-001", "Office Desk",          "Furniture",    7500,  6, 3),
    ("CHR-001", "Ergonomic Chair",      "Furniture",    9500,  9, 4),
    ("NTB-001", "Notebook (pack of 5)", "Stationery",    250, 100, 20),
    ("PEN-001", "Gel Pen (box of 10)",  "Stationery",    120,  60, 15),
]

CUSTOMERS = [
    ("Asha Rao",    "asha@example.com"),
    ("Bilal Khan",  "bilal@example.com"),
    ("Chitra Nair", "chitra@example.com"),
    ("Dev Patel",   "dev@example.com"),
]

# customer index, placed_at, [(sku, qty)]
ORDERS = [
    (0, "2026-09-05 10:15:00", [("LAP-001", 1), ("HDP-001", 2)]),
    (1, "2026-09-12 14:30:00", [("NTB-001", 10), ("PEN-001", 6)]),
    (2, "2026-09-20 09:00:00", [("DSK-001", 2), ("CHR-001", 2)]),
    (0, "2026-10-02 16:45:00", [("PHN-001", 2)]),
    (3, "2026-10-09 11:20:00", [("PHN-001", 1), ("HDP-001", 1)]),
    (1, "2026-10-18 13:05:00", [("CHR-001", 3)]),
    (2, "2026-11-03 17:10:00", [("LAP-001", 1)]),
    (0, "2026-11-10 12:00:00", [("DSK-001", 1), ("NTB-001", 20)]),
]


def seed(conn):
    for sku, name, category, price, stock, level in PRODUCTS:
        shop.add_product(conn, sku, name, category, price, stock, level)
    ids = [shop.add_customer(conn, n, e) for n, e in CUSTOMERS]
    for ci, when, items in ORDERS:
        shop.place_order(conn, ids[ci], items, placed_at=when)
    return ids
