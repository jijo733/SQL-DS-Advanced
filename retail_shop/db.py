"""Database helpers: open a connection and create the schema."""
import sqlite3
from pathlib import Path

BASE = Path(__file__).parent
DEFAULT_DB = BASE / "shop.db"


def connect(path=DEFAULT_DB):
    """Open SQLite with dict-like rows and foreign keys enforced."""
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db(conn):
    """Create all tables, indexes, triggers and views (safe to re-run)."""
    conn.executescript((BASE / "schema.sql").read_text())
