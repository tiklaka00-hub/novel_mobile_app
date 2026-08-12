from pathlib import Path
import logging
from typing import Any

from .database import initialize_database_if_needed, run_startup_migrations, get_connection

LOGGER = logging.getLogger(__name__)


def _query_count(connection, table: str) -> int:
    cursor = connection.cursor()
    try:
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        row = cursor.fetchone()
        return int(row[0]) if row is not None else 0
    except Exception:
        return 0
    finally:
        cursor.close()


def run_startup_tasks() -> dict[str, Any]:
    """Run idempotent startup tasks: initialize DB schema, run migrations/seeds,
    and return a small summary so callers (and logs) can verify seeds applied.
    """
    result: dict[str, Any] = {
        "initialized": False,
        "migrations": {},
        "counts": {},
    }

    # Ensure DB schema exists
    initialized = initialize_database_if_needed()
    result["initialized"] = bool(initialized)

    # Run migrations and seed data
    migration_report = run_startup_migrations()
    result["migrations"] = migration_report

    # Report counts for key tables
    try:
        conn = get_connection()
        for tbl in ("menu_items", "achievements", "reading_lists", "profiles", "write_screen"):
            result["counts"][tbl] = _query_count(conn, tbl)
        conn.close()
    except Exception as exc:
        LOGGER.exception("Failed to query counts after migrations: %s", exc)

    LOGGER.info("Startup tasks finished: %s", result)
    return result
