"""HR reports. Each report is one SQL query; Python only formats the result."""


def headcount_by_department(conn):
    return conn.execute("""
        SELECT d.name AS department, COUNT(e.id) AS staff,
               ROUND(AVG(e.base_salary), 2) AS avg_salary,
               ROUND(SUM(e.base_salary), 2) AS monthly_cost
        FROM departments d JOIN employees e ON e.department_id = d.id AND e.active = 1
        GROUP BY d.id ORDER BY monthly_cost DESC""").fetchall()


def leave_balances(conn, year):
    return conn.execute("""
        SELECT e.name AS employee, lt.code AS type, lb.days_left
        FROM leave_balances lb
        JOIN employees e    ON e.id = lb.employee_id AND e.active = 1
        JOIN leave_types lt ON lt.id = lb.leave_type_id
        WHERE lb.year = ? AND lt.code <> 'UNPAID'
        ORDER BY e.name, lt.code""", (year,)).fetchall()


def leave_taken(conn):
    return conn.execute("""
        SELECT e.name AS employee, lt.code AS type, SUM(lr.working_days) AS days
        FROM leave_requests lr
        JOIN employees e    ON e.id = lr.employee_id
        JOIN leave_types lt ON lt.id = lr.leave_type_id
        WHERE lr.status = 'APPROVED'
        GROUP BY e.id, lt.id ORDER BY e.name""").fetchall()


def pending_leave(conn):
    return conn.execute("SELECT id, employee, type, start_date, end_date, working_days FROM v_pending_leave").fetchall()


def payroll_summary(conn, period):
    return conn.execute("""
        SELECT d.name AS department, COUNT(*) AS staff,
               ROUND(SUM(p.gross), 2) AS gross,
               ROUND(SUM(p.unpaid_deduct), 2) AS unpaid_deduct,
               ROUND(SUM(p.tax), 2) AS tax,
               ROUND(SUM(p.net), 2) AS net
        FROM payslips p
        JOIN payroll_runs r ON r.id = p.run_id AND r.period = ?
        JOIN employees e    ON e.id = p.employee_id
        JOIN departments d  ON d.id = e.department_id
        GROUP BY d.id ORDER BY net DESC""", (period,)).fetchall()


def payslip(conn, period, emp_code):
    return conn.execute("""
        SELECT e.emp_code, e.name, r.period, p.working_days, p.unpaid_days,
               p.gross, p.unpaid_deduct, p.tax, p.net
        FROM payslips p
        JOIN payroll_runs r ON r.id = p.run_id AND r.period = ?
        JOIN employees e    ON e.id = p.employee_id AND e.emp_code = ?""", (period, emp_code)).fetchone()


def salary_history(conn):
    return conn.execute("""
        SELECT e.name AS employee, h.old_salary, h.new_salary, h.changed_at
        FROM salary_history h JOIN employees e ON e.id = h.employee_id ORDER BY h.id""").fetchall()


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


def print_payslip(row):
    if row is None:
        print("No payslip found.")
        return
    print(f"\n+-------------- PAYSLIP {row['period']} --------------+")
    print(f"  Employee      : {row['name']} ({row['emp_code']})")
    print(f"  Working days  : {row['working_days']}   Unpaid leave days: {row['unpaid_days']}")
    print(f"  Gross salary  : {row['gross']:>12,.2f}")
    print(f"  Unpaid deduct : {row['unpaid_deduct']:>12,.2f}")
    print(f"  Income tax    : {row['tax']:>12,.2f}")
    print(f"  NET PAY       : {row['net']:>12,.2f}")
    print("+--------------------------------------------+")
