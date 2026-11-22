-- HR Leave & Payroll System : database schema (SQLite)
-- SQL guards data integrity and keeps an audit trail; Python (hr.py) runs
-- the business rules (leave approval, payroll run, payslips).

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS departments (
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS employees (
    id            INTEGER PRIMARY KEY,
    emp_code      TEXT    NOT NULL UNIQUE,
    name          TEXT    NOT NULL,
    email         TEXT    NOT NULL UNIQUE,
    department_id INTEGER NOT NULL REFERENCES departments(id),
    manager_id    INTEGER REFERENCES employees(id),
    base_salary   REAL    NOT NULL CHECK (base_salary > 0),   -- monthly
    join_date     TEXT    NOT NULL,
    active        INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1))
);

CREATE TABLE IF NOT EXISTS leave_types (
    id            INTEGER PRIMARY KEY,
    code          TEXT NOT NULL UNIQUE,         -- ANNUAL, SICK, UNPAID
    yearly_quota  INTEGER NOT NULL CHECK (yearly_quota >= 0),
    paid          INTEGER NOT NULL CHECK (paid IN (0,1))
);

CREATE TABLE IF NOT EXISTS leave_balances (
    employee_id   INTEGER NOT NULL REFERENCES employees(id),
    leave_type_id INTEGER NOT NULL REFERENCES leave_types(id),
    year          INTEGER NOT NULL,
    days_left     REAL    NOT NULL CHECK (days_left >= 0),      -- cannot go below 0
    PRIMARY KEY (employee_id, leave_type_id, year)
);

CREATE TABLE IF NOT EXISTS leave_requests (
    id            INTEGER PRIMARY KEY,
    employee_id   INTEGER NOT NULL REFERENCES employees(id),
    leave_type_id INTEGER NOT NULL REFERENCES leave_types(id),
    start_date    TEXT NOT NULL,
    end_date      TEXT NOT NULL,
    working_days  INTEGER NOT NULL CHECK (working_days > 0),
    status        TEXT NOT NULL DEFAULT 'PENDING'
                  CHECK (status IN ('PENDING','APPROVED','REJECTED','CANCELLED')),
    reason        TEXT,
    decided_by    INTEGER REFERENCES employees(id),
    CHECK (end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS holidays (
    day  TEXT PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS payroll_runs (
    id        INTEGER PRIMARY KEY,
    period    TEXT NOT NULL UNIQUE,             -- 'YYYY-MM'  (one run per month)
    run_at    TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS payslips (
    id             INTEGER PRIMARY KEY,
    run_id         INTEGER NOT NULL REFERENCES payroll_runs(id),
    employee_id    INTEGER NOT NULL REFERENCES employees(id),
    working_days   INTEGER NOT NULL,
    unpaid_days    INTEGER NOT NULL,
    gross          REAL NOT NULL,
    unpaid_deduct  REAL NOT NULL,
    tax            REAL NOT NULL,
    net            REAL NOT NULL,
    UNIQUE (run_id, employee_id)
);

CREATE TABLE IF NOT EXISTS salary_history (
    id           INTEGER PRIMARY KEY,
    employee_id  INTEGER NOT NULL REFERENCES employees(id),
    old_salary   REAL NOT NULL,
    new_salary   REAL NOT NULL,
    changed_at   TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_leave_emp   ON leave_requests(employee_id, status);
CREATE INDEX IF NOT EXISTS idx_payslip_run ON payslips(run_id);

-- Every salary change is recorded automatically.
CREATE TRIGGER IF NOT EXISTS trg_salary_audit
AFTER UPDATE OF base_salary ON employees
WHEN OLD.base_salary <> NEW.base_salary
BEGIN
    INSERT INTO salary_history(employee_id, old_salary, new_salary)
    VALUES (OLD.id, OLD.base_salary, NEW.base_salary);
END;

-- Payslips are legal records: they can never be edited or deleted.
CREATE TRIGGER IF NOT EXISTS trg_payslip_no_update
BEFORE UPDATE ON payslips
BEGIN SELECT RAISE(ABORT, 'payslips are immutable'); END;

CREATE TRIGGER IF NOT EXISTS trg_payslip_no_delete
BEFORE DELETE ON payslips
BEGIN SELECT RAISE(ABORT, 'payslips are immutable'); END;

-- Handy view for managers.
CREATE VIEW IF NOT EXISTS v_pending_leave AS
SELECT lr.id, e.name AS employee, lt.code AS type,
       lr.start_date, lr.end_date, lr.working_days, e.manager_id
FROM leave_requests lr
JOIN employees e   ON e.id = lr.employee_id
JOIN leave_types lt ON lt.id = lr.leave_type_id
WHERE lr.status = 'PENDING';
