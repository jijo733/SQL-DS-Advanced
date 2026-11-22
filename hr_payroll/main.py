"""Command-line front end for HR leave and payroll.

    python main.py demo                         fresh database, seeded, full walkthrough
    python main.py report [YYYY]                headcount, balances, leave taken
    python main.py leave <emp_id> <TYPE> <start> <end>
    python main.py decide <request_id> <manager_id> approve|reject
    python main.py payroll <YYYY-MM>
    python main.py payslip <YYYY-MM> <emp_code>
    python main.py raise <emp_id> <percent>
"""
import sys

import db
import hr
import reports
import seed


def demo():
    if db.DEFAULT_DB.exists():
        db.DEFAULT_DB.unlink()
    conn = db.connect()
    db.init_db(conn)
    ids = seed.seed(conn)
    print("Seeded 4 employees, 3 leave types, 2 holidays and 4 leave requests.")
    reports.print_table("Headcount by department", reports.headcount_by_department(conn))
    reports.print_table("Leave balances 2026", reports.leave_balances(conn, 2026))
    reports.print_table("Leave taken (approved)", reports.leave_taken(conn))

    print("\n--- Business actions driven from Python ---")

    print("\n1) Working days skip weekends and public holidays:")
    print("   16-20 Nov 2026 (16th is a holiday) =", hr.working_days_between(conn, "2026-11-16", "2026-11-20"), "days")

    print("\n2) Rules reject bad leave requests:")
    for label, args in [
        ("too many days  ", (ids["sneha"], "ANNUAL", "2026-11-30", "2026-12-18")),
        ("overlapping    ", (ids["sneha"], "ANNUAL", "2026-12-22", "2026-12-23")),
        ("weekend only   ", (ids["sneha"], "ANNUAL", "2026-11-07", "2026-11-08")),
    ]:
        try:
            hr.request_leave(conn, *args)
        except hr.HRError as err:
            print(f"   {label}-> REJECTED: {err}")

    print("\n3) Only the manager can approve; approval deducts the balance:")
    reports.print_table("Pending requests", reports.pending_leave(conn))
    try:
        hr.decide_leave(conn, ids["pending"], ids["rahul"], approve=True)
    except hr.HRError as err:
        print("   Rahul tries to approve ->", err)
    hr.decide_leave(conn, ids["pending"], ids["arjun"], approve=True)
    sneha_annual = [r["days_left"] for r in reports.leave_balances(conn, 2026)
                    if r["employee"] == "Sneha Roy" and r["type"] == "ANNUAL"][0]
    print(f"   Arjun approved. Sneha's ANNUAL balance is now {sneha_annual} (was 18, took 5 + 4).")

    print("\n4) Monthly payroll run (progressive tax, unpaid-leave deduction):")
    for period in ("2026-10", "2026-11"):
        hr.run_payroll(conn, period)
    reports.print_table("Payroll summary 2026-11", reports.payroll_summary(conn, "2026-11"))
    reports.print_payslip(reports.payslip(conn, "2026-11", "E004"))
    try:
        hr.run_payroll(conn, "2026-11")
    except hr.HRError as err:
        print("   Running November again ->", err)

    print("\n5) A raise is audited by an SQL trigger:")
    hr.give_raise(conn, ids["sneha"], 10)
    reports.print_table("Salary history", reports.salary_history(conn))

    print("\n6) New-year job grants fresh leave balances:")
    print("   balances created for 2027:", hr.roll_over_year(conn, 2027))
    conn.close()


def main(argv):
    if not argv or argv[0] == "demo":
        return demo()
    conn = db.connect()
    db.init_db(conn)
    cmd, args = argv[0], argv[1:]
    try:
        if cmd == "report":
            year = int(args[0]) if args else 2026
            reports.print_table("Headcount by department", reports.headcount_by_department(conn))
            reports.print_table(f"Leave balances {year}", reports.leave_balances(conn, year))
            reports.print_table("Leave taken (approved)", reports.leave_taken(conn))
            reports.print_table("Pending requests", reports.pending_leave(conn))
        elif cmd == "leave":
            print("Request id:", hr.request_leave(conn, int(args[0]), args[1], args[2], args[3]))
        elif cmd == "decide":
            hr.decide_leave(conn, int(args[0]), int(args[1]), approve=args[2] == "approve")
            print("Decision recorded.")
        elif cmd == "payroll":
            hr.run_payroll(conn, args[0])
            reports.print_table(f"Payroll summary {args[0]}", reports.payroll_summary(conn, args[0]))
        elif cmd == "payslip":
            reports.print_payslip(reports.payslip(conn, args[0], args[1]))
        elif cmd == "raise":
            hr.give_raise(conn, int(args[0]), float(args[1]))
            print("Salary updated.")
        else:
            print(__doc__)
    except (hr.HRError, IndexError, ValueError) as err:
        print("Error:", err)
        return 1
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
