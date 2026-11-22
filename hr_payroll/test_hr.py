"""Tests for HR leave and payroll (run: python -m unittest -v)."""
import sqlite3
import unittest

import db
import hr
import reports
import seed


class HRTests(unittest.TestCase):
    def setUp(self):
        self.conn = db.connect(":memory:")
        db.init_db(self.conn)
        self.ids = seed.seed(self.conn)

    def tearDown(self):
        self.conn.close()

    def balance(self, name, code="ANNUAL", year=2026):
        return self.conn.execute(
            "SELECT days_left FROM leave_balances lb JOIN employees e ON e.id=lb.employee_id "
            "JOIN leave_types lt ON lt.id=lb.leave_type_id WHERE e.name=? AND lt.code=? AND lb.year=?",
            (name, code, year)).fetchone()[0]

    # ------------------------------------------------------------ calendars
    def test_working_days_skip_weekends_and_holidays(self):
        self.assertEqual(hr.working_days_between(self.conn, "2026-11-02", "2026-11-06"), 5)
        self.assertEqual(hr.working_days_between(self.conn, "2026-11-16", "2026-11-20"), 4)  # 16th holiday
        self.assertEqual(hr.working_days_between(self.conn, "2026-11-07", "2026-11-08"), 0)  # weekend

    def test_progressive_tax(self):
        self.assertEqual(hr.calculate_tax(20000), 0)
        self.assertEqual(hr.calculate_tax(60000), 4500)    # 2,500 + 2,000
        self.assertEqual(hr.calculate_tax(120000), 18500)  # 2,500 + 10,000 + 6,000

    # ----------------------------------------------------------- leave flow
    def test_seeded_balances_after_approved_leave(self):
        self.assertEqual(self.balance("Sneha Roy"), 13)            # 18 - 5
        self.assertEqual(self.balance("Rahul Das", "SICK"), 6)     # 8 - 2

    def test_insufficient_balance_rejected(self):
        # 30 Nov - 18 Dec = 15 working days, Sneha has 13 left and no overlap
        with self.assertRaisesRegex(hr.HRError, "Insufficient ANNUAL balance"):
            hr.request_leave(self.conn, self.ids["sneha"], "ANNUAL", "2026-11-30", "2026-12-18")

    def test_overlap_rejected(self):
        with self.assertRaisesRegex(hr.HRError, "Overlaps"):
            hr.request_leave(self.conn, self.ids["sneha"], "ANNUAL", "2026-12-22", "2026-12-23")

    def test_weekend_only_and_reversed_dates_rejected(self):
        with self.assertRaises(hr.HRError):
            hr.request_leave(self.conn, self.ids["sneha"], "ANNUAL", "2026-11-07", "2026-11-08")
        with self.assertRaises(hr.HRError):
            hr.request_leave(self.conn, self.ids["sneha"], "ANNUAL", "2026-11-10", "2026-11-09")

    def test_unknown_leave_type_and_inactive_employee_rejected(self):
        with self.assertRaises(hr.HRError):
            hr.request_leave(self.conn, self.ids["sneha"], "SABBATICAL", "2026-11-02", "2026-11-03")
        hr.terminate(self.conn, self.ids["sneha"])
        with self.assertRaises(hr.HRError):
            hr.request_leave(self.conn, self.ids["sneha"], "ANNUAL", "2026-11-02", "2026-11-03")

    def test_only_manager_can_decide_and_approval_deducts(self):
        with self.assertRaises(hr.HRError):
            hr.decide_leave(self.conn, self.ids["pending"], self.ids["rahul"])
        hr.decide_leave(self.conn, self.ids["pending"], self.ids["arjun"])
        self.assertEqual(self.balance("Sneha Roy"), 9)             # 13 - 4
        with self.assertRaises(hr.HRError):                        # cannot decide twice
            hr.decide_leave(self.conn, self.ids["pending"], self.ids["arjun"])

    def test_rejection_keeps_balance(self):
        hr.decide_leave(self.conn, self.ids["pending"], self.ids["arjun"], approve=False)
        self.assertEqual(self.balance("Sneha Roy"), 13)

    def test_cancel_approved_leave_refunds_days(self):
        hr.decide_leave(self.conn, self.ids["pending"], self.ids["arjun"])
        hr.cancel_leave(self.conn, self.ids["pending"])
        self.assertEqual(self.balance("Sneha Roy"), 13)
        with self.assertRaises(hr.HRError):
            hr.cancel_leave(self.conn, self.ids["pending"])

    def test_database_refuses_negative_balance(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute("UPDATE leave_balances SET days_left = -1")

    # -------------------------------------------------------------- payroll
    def test_payroll_numbers(self):
        hr.run_payroll(self.conn, "2026-11")
        sneha = reports.payslip(self.conn, "2026-11", "E003")
        self.assertEqual((sneha["working_days"], sneha["unpaid_days"]), (20, 0))
        self.assertEqual((sneha["gross"], sneha["tax"], sneha["net"]), (60000, 4500, 55500))
        rahul = reports.payslip(self.conn, "2026-11", "E004")
        self.assertEqual(rahul["unpaid_days"], 3)                    # 23-25 Nov
        self.assertEqual(rahul["unpaid_deduct"], 6000)               # 40000 / 20 * 3
        self.assertEqual((rahul["tax"], rahul["net"]), (900, 33100))

    def test_paid_leave_does_not_reduce_pay(self):
        hr.run_payroll(self.conn, "2026-10")                         # Sneha was on ANNUAL leave
        sneha = reports.payslip(self.conn, "2026-10", "E003")
        self.assertEqual((sneha["unpaid_days"], sneha["unpaid_deduct"]), (0, 0))

    def test_payroll_runs_once_per_month(self):
        hr.run_payroll(self.conn, "2026-11")
        with self.assertRaises(hr.HRError):
            hr.run_payroll(self.conn, "2026-11")
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM payslips").fetchone()[0], 4)

    def test_payslips_are_immutable(self):
        hr.run_payroll(self.conn, "2026-11")
        with self.assertRaises(sqlite3.DatabaseError):
            self.conn.execute("UPDATE payslips SET net = 999999")
        with self.assertRaises(sqlite3.DatabaseError):
            self.conn.execute("DELETE FROM payslips")

    def test_terminated_and_not_yet_joined_are_not_paid(self):
        hr.terminate(self.conn, self.ids["rahul"])
        hr.hire(self.conn, "E005", "Future Hire", "future@corp.example", "Support", 30000, "2026-12-01")
        hr.run_payroll(self.conn, "2026-11")
        codes = {r["emp_code"] for r in self.conn.execute(
            "SELECT e.emp_code FROM payslips p JOIN employees e ON e.id = p.employee_id")}
        self.assertEqual(codes, {"E001", "E002", "E003"})

    # ------------------------------------------------------------- the rest
    def test_raise_is_audited_by_trigger(self):
        hr.give_raise(self.conn, self.ids["sneha"], 10)
        row = self.conn.execute("SELECT * FROM salary_history").fetchone()
        self.assertEqual((row["old_salary"], row["new_salary"]), (60000, 66000))
        with self.assertRaises(hr.HRError):
            hr.give_raise(self.conn, self.ids["sneha"], -5)

    def test_roll_over_year_is_idempotent(self):
        created = hr.roll_over_year(self.conn, 2027)
        self.assertEqual(created, 4 * 3)                             # 4 employees x 3 leave types
        self.assertEqual(hr.roll_over_year(self.conn, 2027), 0)
        self.assertEqual(self.balance("Sneha Roy", "ANNUAL", 2027), 18)

    def test_invalid_email_rejected_on_hire(self):
        with self.assertRaises(hr.HRError):
            hr.hire(self.conn, "E009", "Bad", "no-at-sign", "Support", 1000, "2026-01-01")


if __name__ == "__main__":
    unittest.main()
