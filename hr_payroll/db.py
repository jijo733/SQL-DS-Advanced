"""Database helpers: open a connection and create the schema."""
import sqlite3
from pathlib import Path

BASE = Path(__file__).parent
DEFAULT_DB = BASE / "hr.db"


def connect(path=DEFAULT_DB):
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db(conn):
    """Create tables, triggers and views (safe to re-run)."""
    conn.executescript((BASE / "schema.sql").read_text())
