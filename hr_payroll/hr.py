"""Business rules for HR leave and payroll.

SQL stores and protects the data; Python applies the policy:
  * working days exclude weekends and public holidays
  * a leave request is checked for balance and overlap before it is accepted
  * only the employee's manager may approve; approval deducts the balance atomically
  * the monthly payroll run is idempotent (one run per month) and immutable
"""
import calendar
from datetime import date, timedelta

# Simplified progressive tax on monthly gross: (upper limit, rate)
TAX_SLABS = [(25000, 0.0), (50000, 0.10), (100000, 0.20), (float("inf"), 0.30)]


class HRError(Exception):
    """Raised for any rule violation; the surrounding transaction rolls back."""


def _d(value):
    return value if isinstance(value, date) else date.fromisoformat(value)


# ------------------------------------------------------------------ calendars
def holiday_set(conn):
    return {r["day"] for r in conn.execute("SELECT day FROM holidays")}


def working_days_between(conn, start, end):
    """Number of Mon-Fri days in [start, end] that are not public holidays."""
    start, end = _d(start), _d(end)
    holidays = holiday_set(conn)
    days, cur = 0, start
    while cur <= end:
        if cur.weekday() < 5 and cur.isoformat() not in holidays:
            days += 1
        cur += timedelta(days=1)
    return days


def month_bounds(period):
    year, month = map(int, period.split("-"))
    return date(year, month, 1), date(year, month, calendar.monthrange(year, month)[1])


def calculate_tax(gross):
    """Progressive tax: each slab is taxed at its own rate."""
    tax, lower = 0.0, 0.0
    for upper, rate in TAX_SLABS:
        if gross > lower:
            tax += (min(gross, upper) - lower) * rate
        lower = upper
    return round(tax, 2)


# ------------------------------------------------------------- master data
def add_department(conn, name):
    with conn:
        conn.execute("INSERT OR IGNORE INTO departments(name) VALUES (?)", (name,))
    return conn.execute("SELECT id FROM departments WHERE name=?", (name,)).fetchone()["id"]


def add_leave_type(conn, code, quota, paid=True):
    with conn:
        return conn.execute("INSERT INTO leave_types(code,yearly_quota,paid) VALUES (?,?,?)",
                            (code, quota, int(paid))).lastrowid


def add_holiday(conn, day, name):
    with conn:
        conn.execute("INSERT OR REPLACE INTO holidays(day,name) VALUES (?,?)", (_d(day).isoformat(), name))


def hire(conn, emp_code, name, email, department, salary, join_date, manager_id=None):
    """Create an employee and give them this year's leave balances."""
    if "@" not in email:
        raise HRError(f"Invalid email: {email!r}")
    dept_id = add_department(conn, department)
    with conn:
        emp_id = conn.execute(
            "INSERT INTO employees(emp_code,name,email,department_id,manager_id,base_salary,join_date) "
            "VALUES (?,?,?,?,?,?,?)",
            (emp_code, name, email, dept_id, manager_id, salary, _d(join_date).isoformat())).lastrowid
        year = _d(join_date).year
        for lt in conn.execute("SELECT id, yearly_quota FROM leave_types"):
            conn.execute("INSERT INTO leave_balances(employee_id,leave_type_id,year,days_left) VALUES (?,?,?,?)",
                         (emp_id, lt["id"], year, lt["yearly_quota"]))
    return emp_id


def give_raise(conn, emp_id, percent):
    """Raise salary by a percentage; the trigger writes salary_history."""
    if percent <= 0:
        raise HRError("Raise must be positive")
    with conn:
        cur = conn.execute("UPDATE employees SET base_salary = ROUND(base_salary*(1+?/100.0),2) WHERE id=?",
                           (percent, emp_id))
        if cur.rowcount == 0:
            raise HRError(f"Unknown employee {emp_id}")


def roll_over_year(conn, year):
    """New-year job: grant every active employee the yearly quota for each leave type.

    INSERT OR IGNORE makes it safe to run twice - existing balances are left alone.
    """
    with conn:
        cur = conn.execute(
            "INSERT OR IGNORE INTO leave_balances(employee_id,leave_type_id,year,days_left) "
            "SELECT e.id, lt.id, ?, lt.yearly_quota FROM employees e CROSS JOIN leave_types lt "
            "WHERE e.active = 1", (year,))
    return cur.rowcount


def terminate(conn, emp_id):
    with conn:
        conn.execute("UPDATE employees SET active=0 WHERE id=?", (emp_id,))


# ------------------------------------------------------------------ leave flow
def _leave_type(conn, code):
    row = conn.execute("SELECT * FROM leave_types WHERE code=?", (code,)).fetchone()
    if row is None:
        raise HRError(f"Unknown leave type {code}")
    return row


def request_leave(conn, emp_id, type_code, start, end, reason=""):
    """Validate and file a PENDING leave request. Returns the request id."""
    start, end = _d(start), _d(end)
    if end < start:
        raise HRError("End date is before start date")
    with conn:
        emp = conn.execute("SELECT * FROM employees WHERE id=? AND active=1", (emp_id,)).fetchone()
        if emp is None:
            raise HRError(f"No active employee {emp_id}")
        lt = _leave_type(conn, type_code)
        days = working_days_between(conn, start, end)
        if days == 0:
            raise HRError("Those dates contain no working days")
        overlap = conn.execute(
            "SELECT 1 FROM leave_requests WHERE employee_id=? AND status IN ('PENDING','APPROVED') "
            "AND start_date <= ? AND end_date >= ?",
            (emp_id, end.isoformat(), start.isoformat())).fetchone()
        if overlap:
            raise HRError("Overlaps with an existing leave request")
        bal = conn.execute("SELECT days_left FROM leave_balances WHERE employee_id=? AND leave_type_id=? AND year=?",
                           (emp_id, lt["id"], start.year)).fetchone()
        if lt["code"] != "UNPAID" and (bal is None or bal["days_left"] < days):
            have = 0 if bal is None else bal["days_left"]
            raise HRError(f"Insufficient {type_code} balance: need {days}, have {have}")
        return conn.execute(
            "INSERT INTO leave_requests(employee_id,leave_type_id,start_date,end_date,working_days,reason) "
            "VALUES (?,?,?,?,?,?)",
            (emp_id, lt["id"], start.isoformat(), end.isoformat(), days, reason)).lastrowid


def decide_leave(conn, request_id, manager_id, approve=True):
    """Manager approves or rejects. Approval deducts the balance in the same transaction."""
    with conn:
        req = conn.execute("SELECT lr.*, e.manager_id FROM leave_requests lr "
                           "JOIN employees e ON e.id = lr.employee_id WHERE lr.id=?", (request_id,)).fetchone()
        if req is None:
            raise HRError(f"Unknown request {request_id}")
        if req["status"] != "PENDING":
            raise HRError(f"Request {request_id} is already {req['status']}")
        if req["manager_id"] != manager_id:
            raise HRError("Only the employee's manager can decide this request")
        if approve:
            lt = conn.execute("SELECT code FROM leave_types WHERE id=?", (req["leave_type_id"],)).fetchone()
            if lt["code"] != "UNPAID":
                year = _d(req["start_date"]).year
                done = conn.execute(
                    "UPDATE leave_balances SET days_left = days_left - ? "
                    "WHERE employee_id=? AND leave_type_id=? AND year=? AND days_left >= ?",
                    (req["working_days"], req["employee_id"], req["leave_type_id"], year, req["working_days"]))
                if done.rowcount == 0:
                    raise HRError("Balance no longer sufficient")
        conn.execute("UPDATE leave_requests SET status=?, decided_by=? WHERE id=?",
                     ("APPROVED" if approve else "REJECTED", manager_id, request_id))


def cancel_leave(conn, request_id):
    """Employee cancels; an APPROVED request gives its days back."""
    with conn:
        req = conn.execute("SELECT * FROM leave_requests WHERE id=?", (request_id,)).fetchone()
        if req is None or req["status"] not in ("PENDING", "APPROVED"):
            raise HRError("Only pending or approved requests can be cancelled")
        if req["status"] == "APPROVED":
            lt = conn.execute("SELECT code FROM leave_types WHERE id=?", (req["leave_type_id"],)).fetchone()
            if lt["code"] != "UNPAID":
                conn.execute("UPDATE leave_balances SET days_left = days_left + ? "
                             "WHERE employee_id=? AND leave_type_id=? AND year=?",
                             (req["working_days"], req["employee_id"], req["leave_type_id"],
                              _d(req["start_date"]).year))
        conn.execute("UPDATE leave_requests SET status='CANCELLED' WHERE id=?", (request_id,))


# --------------------------------------------------------------------- payroll
def _unpaid_days_in_month(conn, emp_id, first, last):
    """Approved UNPAID-leave working days that fall inside the month."""
    total = 0
    rows = conn.execute(
        "SELECT lr.start_date, lr.end_date FROM leave_requests lr "
        "JOIN leave_types lt ON lt.id = lr.leave_type_id "
        "WHERE lr.employee_id=? AND lr.status='APPROVED' AND lt.paid=0 "
        "AND lr.start_date <= ? AND lr.end_date >= ?",
        (emp_id, last.isoformat(), first.isoformat())).fetchall()
    for r in rows:
        total += working_days_between(conn, max(_d(r["start_date"]), first), min(_d(r["end_date"]), last))
    return total


def run_payroll(conn, period):
    """Generate payslips for all active employees. One run per month, all-or-nothing."""
    first, last = month_bounds(period)
    with conn:
        if conn.execute("SELECT 1 FROM payroll_runs WHERE period=?", (period,)).fetchone():
            raise HRError(f"Payroll for {period} has already been run")
        month_days = working_days_between(conn, first, last)
        run_id = conn.execute("INSERT INTO payroll_runs(period) VALUES (?)", (period,)).lastrowid
        for emp in conn.execute("SELECT * FROM employees WHERE active=1 AND join_date <= ?",
                                (last.isoformat(),)).fetchall():
            gross = emp["base_salary"]
            unpaid = _unpaid_days_in_month(conn, emp["id"], first, last)
            deduct = round(gross / month_days * unpaid, 2) if month_days else 0.0
            taxable = gross - deduct
            tax = calculate_tax(taxable)
            conn.execute(
                "INSERT INTO payslips(run_id,employee_id,working_days,unpaid_days,gross,unpaid_deduct,tax,net) "
                "VALUES (?,?,?,?,?,?,?,?)",
                (run_id, emp["id"], month_days, unpaid, gross, deduct, tax, round(taxable - tax, 2)))
    return run_id
