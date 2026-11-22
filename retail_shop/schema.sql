-- Retail Inventory & Order System : database schema (SQLite)
-- Constraints, indexes, a trigger and views live here in SQL;
-- Python (shop.py) drives the business workflow on top of them.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS categories (
    id    INTEGER PRIMARY KEY,
    name  TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS products (
    id            INTEGER PRIMARY KEY,
    sku           TEXT    NOT NULL UNIQUE,
    name          TEXT    NOT NULL,
    category_id   INTEGER NOT NULL REFERENCES categories(id),
    price         REAL    NOT NULL CHECK (price >= 0),
    stock         INTEGER NOT NULL CHECK (stock >= 0),      -- DB refuses negative stock
    reorder_level INTEGER NOT NULL DEFAULT 5 CHECK (reorder_level >= 0)
);

CREATE TABLE IF NOT EXISTS customers (
    id          INTEGER PRIMARY KEY,
    name        TEXT NOT NULL,
    email       TEXT NOT NULL UNIQUE,
    tier        TEXT NOT NULL DEFAULT 'BRONZE' CHECK (tier IN ('BRONZE','SILVER','GOLD')),
    created_at  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS orders (
    id          INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id),
    status      TEXT NOT NULL DEFAULT 'PAID' CHECK (status IN ('PAID','CANCELLED')),
    subtotal    REAL NOT NULL DEFAULT 0,
    discount    REAL NOT NULL DEFAULT 0,
    total       REAL NOT NULL DEFAULT 0,
    created_at  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
    id          INTEGER PRIMARY KEY,
    order_id    INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id  INTEGER NOT NULL REFERENCES products(id),
    qty         INTEGER NOT NULL CHECK (qty > 0),
    unit_price  REAL    NOT NULL                 -- price frozen at time of sale
);

CREATE TABLE IF NOT EXISTS stock_movements (
    id          INTEGER PRIMARY KEY,
    product_id  INTEGER NOT NULL REFERENCES products(id),
    change      INTEGER NOT NULL,                -- +in / -out
    reason      TEXT    NOT NULL,                -- SALE, CANCEL, RECEIVE, ...
    created_at  TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS purchase_orders (
    id          INTEGER PRIMARY KEY,
    product_id  INTEGER NOT NULL REFERENCES products(id),
    qty         INTEGER NOT NULL CHECK (qty > 0),
    status      TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','RECEIVED')),
    created_at  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS price_history (
    id          INTEGER PRIMARY KEY,
    product_id  INTEGER NOT NULL REFERENCES products(id),
    old_price   REAL NOT NULL,
    new_price   REAL NOT NULL,
    changed_at  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_items_order     ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_items_product   ON order_items(product_id);

-- Audit every price change automatically, no matter who changes it.
CREATE TRIGGER IF NOT EXISTS trg_price_audit
AFTER UPDATE OF price ON products
WHEN OLD.price <> NEW.price
BEGIN
    INSERT INTO price_history(product_id, old_price, new_price)
    VALUES (OLD.id, OLD.price, NEW.price);
END;

-- Products at or below their reorder level.
CREATE VIEW IF NOT EXISTS v_low_stock AS
SELECT p.id, p.sku, p.name, p.stock, p.reorder_level
FROM products p
WHERE p.stock <= p.reorder_level;
