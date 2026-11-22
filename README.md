# SQL Real World Projects (Python controls the SQL)

Two small but realistic business systems. In both, **SQL protects and stores the data**
and **Python runs the business actions** on top of it. Only the Python standard
library is used (`sqlite3`, `unittest`), so there is nothing to install.

| | Project 1: `retail_shop` | Project 2: `hr_payroll` |
|---|---|---|
| Business | Inventory, orders, loyalty, purchasing | Leave management and monthly payroll |
| Python actions | place / cancel order, tier upgrades, auto-reorder, receive stock, price change | request / approve / cancel leave, payroll run, payslips, raise, year roll-over |
| SQL features | FK + CHECK constraints, trigger (price audit), view (low stock), joins, GROUP BY, indexes | FK + CHECK constraints, triggers (salary audit, immutable payslips), view (pending leave), composite PK, CROSS JOIN, GROUP BY |
| Tests | 13 | 19 |

## How to run

```bash
cd retail_shop            # or: cd hr_payroll
python3 main.py demo      # builds a fresh database, seeds it, shows a full walkthrough
python3 -m unittest -v    # run the tests
python3 main.py           # (no args = demo)
```

Each project's `main.py` also has real commands (see the top of the file), for example:

```bash
# retail_shop
python3 main.py order 1 LAP-001:1 HDP-001:2
python3 main.py cancel 1
python3 main.py reorder
python3 main.py price PHN-001 16999

# hr_payroll
python3 main.py leave 3 ANNUAL 2026-12-21 2026-12-24
python3 main.py decide 4 2 approve
python3 main.py payroll 2026-11
python3 main.py payslip 2026-11 E004
```

## File layout (same in both projects)

| File | Role |
|---|---|
| `schema.sql` | Tables, constraints, indexes, triggers, views (pure SQL) |
| `db.py` | Opens the connection (foreign keys ON) and creates the schema |
| `shop.py` / `hr.py` | **Business rules in Python**; every action is one atomic transaction |
| `reports.py` | Each report is a single SQL query; Python only formats it |
| `seed.py` | Sample data for the demo and tests |
| `main.py` | Command-line interface + guided demo |
| `test_*.py` | Unit tests, run against a fresh in-memory database |

## Ideas worth studying

1. **Transactions (all-or-nothing).** `with conn:` commits on success and rolls back on any
   exception. A 2-line order where line 2 is out of stock leaves *no* trace of line 1.
2. **Defence in depth.** Python checks the rules and gives friendly errors; the database
   *also* refuses bad data (`CHECK (stock >= 0)`, `CHECK (days_left >= 0)`), so a bug
   or a manual SQL edit cannot corrupt the data.
3. **Triggers for audit.** Price and salary changes are logged by SQL, so the history is
   complete no matter which program makes the change. Payslips are made immutable by triggers.
4. **Parameterised queries.** Every value goes in through `?` placeholders, never string
   concatenation, which prevents SQL injection.
5. **Snapshots.** `order_items.unit_price` stores the price at the time of sale, so later price
   changes never rewrite old orders.
6. **Idempotent jobs.** Payroll can run only once per month (`UNIQUE(period)`), and the year
   roll-over uses `INSERT OR IGNORE`, so a repeated run does no harm.

## Business rules

**retail_shop**: loyalty tiers by lifetime spend on PAID orders: Bronze 0%, Silver (>= 1,000) 5%,
Gold (>= 5,000) 10%. Cancelling an order returns the stock and re-evaluates the tier. Low-stock
items (stock <= reorder level) get an automatic purchase order for `3 x reorder level - stock`.

**hr_payroll**: leave days count Monday-Friday and skip public holidays. A request is refused if it
overlaps another, exceeds the balance, or has no working days. Only the employee's manager
can approve. Payroll: unpaid leave deducts `salary / working days in month x unpaid days`;
tax is progressive (0% to 25k, 10% to 50k, 20% to 100k, 30% above).

## Extending

Swap SQLite for MySQL/PostgreSQL by changing `db.connect()` and using `%s` placeholders (the
repository already has `Python_Mysql_connection.py` one folder up). Ideas: a web front end
(Flask), CSV export of reports, an e-mail notification when stock is low or leave is decided.
