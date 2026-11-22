"""Sample company data so the project can be demonstrated straight away."""
import hr


def seed(conn):
    """Create a small company. Returns a dict of useful ids."""
    for code, quota, paid in [("ANNUAL", 18, True), ("SICK", 8, True), ("UNPAID", 0, False)]:
        hr.add_leave_type(conn, code, quota, paid)
    hr.add_holiday(conn, "2026-10-02", "Gandhi Jayanti")
    hr.add_holiday(conn, "2026-11-16", "Company Foundation Day")

    ids = {}
    ids["meera"] = hr.hire(conn, "E001", "Meera Iyer",  "meera@corp.example",  "Management",  120000, "2026-01-05")
    ids["arjun"] = hr.hire(conn, "E002", "Arjun Mehta", "arjun@corp.example",  "Engineering",  80000, "2026-01-12", ids["meera"])
    ids["sneha"] = hr.hire(conn, "E003", "Sneha Roy",   "sneha@corp.example",  "Engineering",  60000, "2026-02-02", ids["arjun"])
    ids["rahul"] = hr.hire(conn, "E004", "Rahul Das",   "rahul@corp.example",  "Support",      40000, "2026-03-02", ids["arjun"])

    # Past leave, already decided by the manager
    r = hr.request_leave(conn, ids["sneha"], "ANNUAL", "2026-10-05", "2026-10-09", "Family trip")
    hr.decide_leave(conn, r, ids["arjun"], approve=True)
    r = hr.request_leave(conn, ids["rahul"], "SICK", "2026-10-12", "2026-10-13", "Fever")
    hr.decide_leave(conn, r, ids["arjun"], approve=True)
    r = hr.request_leave(conn, ids["rahul"], "UNPAID", "2026-11-23", "2026-11-25", "Personal")
    hr.decide_leave(conn, r, ids["arjun"], approve=True)

    # A request still waiting for the manager
    ids["pending"] = hr.request_leave(conn, ids["sneha"], "ANNUAL", "2026-12-21", "2026-12-24", "Year-end break")
    return ids
