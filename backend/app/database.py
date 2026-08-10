import os
import sqlite3
from pathlib import Path
from uuid import uuid4

try:
    import mysql.connector as mysql_connector
except ModuleNotFoundError:
    mysql_connector = None

try:
    from dotenv import load_dotenv
except ModuleNotFoundError:
    load_dotenv = lambda *args, **kwargs: None

# Load .env.local first (local dev environment), then fall back to .env
_BACKEND_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(_BACKEND_ROOT / ".env.local", override=False)
load_dotenv(_BACKEND_ROOT / ".env", override=False)

DB_TYPE_ENV = os.getenv("DB_TYPE")
if DB_TYPE_ENV:
    DB_TYPE = DB_TYPE_ENV.strip().lower()
elif mysql_connector is None:
    DB_TYPE = "sqlite"
else:
    DB_TYPE = "mysql"

USE_SQLITE = DB_TYPE == "sqlite"
SQLITE_FILE = Path(os.getenv("SQLITE_FILE", str(_BACKEND_ROOT / "novel_app.db"))).resolve()

MYSQL_ERROR = mysql_connector.Error if mysql_connector is not None else Exception

REQUIRED_TABLES = {
    "categories",
    "books",
    "chapters",
    "library_entries",
    "write_screen",
    "notifications",
    "menu_items",
    "profiles",
    "reading_lists",
    "achievements",
}
