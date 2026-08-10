from collections import defaultdict
import base64
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import json
import logging
import os
import sqlite3
from pathlib import Path
from typing import Any
from urllib.parse import urlencode
from urllib.request import urlopen
from uuid import uuid4

from fastapi import Depends, FastAPI, File, Header, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
try:
    import mysql.connector as mysql_connector
except ModuleNotFoundError:
    mysql_connector = None
from pydantic import BaseModel

from .database import (
    get_connection,
    initialize_database_if_needed,
    run_startup_migrations,
    USE_SQLITE,
)

DB_INIT_EXCEPTIONS = (sqlite3.Error, FileNotFoundError, OSError, ValueError)
if mysql_connector is not None:
    DB_INIT_EXCEPTIONS = (mysql_connector.Error, sqlite3.Error, FileNotFoundError, OSError, ValueError)

app = FastAPI(title="Novel Mobile Backend")
LOGGER = logging.getLogger(__name__)
UPLOAD_ROOT = Path(os.getenv("UPLOAD_DIR", "./uploads")).resolve()
JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret-key-change-in-production")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "admin_Supun")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "Ux3@f=7x2")
ADMIN_TOKEN_EXPIRES_HOURS = int(os.getenv("ADMIN_TOKEN_EXPIRES_HOURS", "24"))
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
# Support multiple acceptable client IDs via comma-separated env var for flexibility
# e.g. GOOGLE_CLIENT_IDS=android-client-id,web-client-id
GOOGLE_CLIENT_IDS = [s.strip() for s in os.getenv("GOOGLE_CLIENT_IDS", GOOGLE_CLIENT_ID).split(",") if s.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_ROOT), name="uploads")


class LibraryCreateRequest(BaseModel):
    book_id: int
    reading_status: str
    updated_text: str = ""
    chapters: int = 0
    primary_genre: str = ""
    secondary_genre: str = ""


class LibraryUpdateRequest(BaseModel):
    reading_status: str | None = None
    updated_text: str | None = None
    chapters: int | None = None
    primary_genre: str | None = None
    secondary_genre: str | None = None


class ReadingListCreateRequest(BaseModel):
    name: str
    story_count: int = 0
    cover_path: str = ""
    sort_order: int = 999


class StoryCreateRequest(BaseModel):
    title: str
    author: str
    description: str
    genre: str
    cover_path: str = ""


class StoryUpdateRequest(BaseModel):
    title: str | None = None
    author: str | None = None
    description: str | None = None
    genre: str | None = None
    cover_path: str | None = None


class ChapterCreateRequest(BaseModel):
    title: str
    content: str
    chapter_number: int | None = None
    notes: str | None = None
    submission_status: str | None = None
    scheduled_for: str | None = None


class ChapterUpdateRequest(BaseModel):
    title: str | None = None
    content: str | None = None
    chapter_number: int | None = None
    notes: str | None = None
    submission_status: str | None = None
    scheduled_for: str | None = None


class CategoryCreateRequest(BaseModel):
    name: str
    topic_count: int = 0
    tab_group: str
    sort_order: int = 0


class CategoryUpdateRequest(BaseModel):
    name: str | None = None
    topic_count: int | None = None
    tab_group: str | None = None
    sort_order: int | None = None


class AdminBookCreateRequest(BaseModel):
    title: str
    author: str
    description: str
    cover_path: str = ""
    accent_hex: str = "#808080"
    section_name: str = "recently_updated"
    status_text: str = "Draft"
    rating: float = 0.0
    genre: str = ""
    cta_label: str = "Read now"
    sort_order: int = 999


class AdminBookUpdateRequest(BaseModel):
    title: str | None = None
    author: str | None = None
    description: str | None = None
    cover_path: str | None = None
    accent_hex: str | None = None
    section_name: str | None = None
    status_text: str | None = None
    rating: float | None = None
    genre: str | None = None
    cta_label: str | None = None
    sort_order: int | None = None


class AdminNotificationCreateRequest(BaseModel):
    tab_name: str
    title: str
    message: str
    created_at: str
    sort_order: int = 999


class AdminNotificationUpdateRequest(BaseModel):
    tab_name: str | None = None
    title: str | None = None
    message: str | None = None
    created_at: str | None = None
    sort_order: int | None = None


class AdminMenuItemCreateRequest(BaseModel):
    section_name: str
    section_order: int
    label: str
    icon_name: str
    route_name: str
    sort_order: int = 999


class AdminMenuItemUpdateRequest(BaseModel):
    section_name: str | None = None
    section_order: int | None = None
    label: str | None = None
    icon_name: str | None = None
    route_name: str | None = None
    sort_order: int | None = None


class AdminWriteScreenUpdateRequest(BaseModel):
    manage_tabs: str
    story_tabs: str
    filter_label: str
    sort_label: str
    empty_title: str
    empty_cta: str


class AdminProfileUpdateRequest(BaseModel):
    display_name: str
    username: str
    following: int
    followers: int
    blocked: int
    chapters_read: int
    social_karma: int
    day_streak: int


class AdminReadingListCreateRequest(BaseModel):
    profile_id: int = 1
    name: str
    story_count: int = 0
    cover_path: str = ""
    sort_order: int = 999


class AdminReadingListUpdateRequest(BaseModel):
    profile_id: int | None = None
    name: str | None = None
    story_count: int | None = None
    cover_path: str | None = None
    sort_order: int | None = None


class AdminAchievementCreateRequest(BaseModel):
    group_name: str
    group_order: int
    title: str
    subtitle: str
    progress_label: str
    badge_value: str
    style: str
    sort_order: int = 999


class AdminAchievementUpdateRequest(BaseModel):
    group_name: str | None = None
    group_order: int | None = None
    title: str | None = None
    subtitle: str | None = None
    progress_label: str | None = None
    badge_value: str | None = None
    style: str | None = None
    sort_order: int | None = None


class AdminLoginRequest(BaseModel):
    username: str
    password: str


class SupportRequestCreateRequest(BaseModel):
    email: str
    first_name: str
    issue: str
    subject: str
    description: str
    device_type: str = ""
    attachment_path: str = ""


class SupportRequestUpdateRequest(BaseModel):
    status: str


class GoogleAuthRequest(BaseModel):
    id_token: str | None = None
    access_token: str | None = None


class EmailAuthRequest(BaseModel):
    email: str
    display_name: str = ""


class GuestAuthRequest(BaseModel):
    pass


class ChatMessageCreateRequest(BaseModel):
    message: str
    sender: str = "user"


class VersionResponse(BaseModel):
    value: str
    updated_at: str | None = None


def _to_db_query(query: str) -> str:
    return query.replace("%s", "?") if USE_SQLITE else query


def fetch_all(query: str, params: tuple[Any, ...] | None = None):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True) if not USE_SQLITE else connection.cursor()
    cursor.execute(_to_db_query(query), params or ())
    rows = cursor.fetchall()
    cursor.close()
    connection.close()
    return rows


def execute_write(query: str, params: tuple[Any, ...]):
    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute(_to_db_query(query), params)
    connection.commit()
    last_id = cursor.lastrowid
    affected = cursor.rowcount
    cursor.close()
    connection.close()
    return last_id, affected


def _serialize_db_datetime(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, str):
        return value
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)


def _content_version_row() -> dict[str, Any]:
    rows = fetch_all(
        "SELECT key_value, updated_at FROM app_metadata WHERE key_name='content_version' LIMIT 1"
    )
    if rows:
        row = rows[0]
        return {
            "value": row["key_value"],
            "updated_at": _serialize_db_datetime(row["updated_at"]),
        }

    value = str(uuid4())
    execute_write(
        "INSERT INTO app_metadata (key_name, key_value) VALUES ('content_version', %s)",
        (value,),
    )
    return {"value": value, "updated_at": None}


def bump_content_version() -> dict[str, Any]:
    value = str(uuid4())
    connection = get_connection()
    cursor = connection.cursor()
    if USE_SQLITE:
        cursor.execute(
            """
            INSERT INTO app_metadata (key_name, key_value)
            VALUES ('content_version', ?)
            ON CONFLICT(key_name) DO UPDATE SET key_value = excluded.key_value
            """,
            (value,),
        )
    else:
        cursor.execute(
            """
            INSERT INTO app_metadata (key_name, key_value)
            VALUES ('content_version', %s)
            ON DUPLICATE KEY UPDATE key_value = VALUES(key_value)
            """,
            (value,),
        )
    connection.commit()
    cursor.close()
    connection.close()
    return _content_version_row()


def create_admin_token(username: str) -> str:
    expires_at = datetime.now(timezone.utc) + timedelta(hours=ADMIN_TOKEN_EXPIRES_HOURS)
    payload = {
        "sub": username,
        "role": "admin",
        "exp": expires_at.isoformat(),
    }
    encoded_payload = base64.urlsafe_b64encode(
        json.dumps(payload, separators=(",", ":")).encode("utf-8")
    ).decode("ascii")
    signature = hmac.new(
        JWT_SECRET.encode("utf-8"),
        encoded_payload.encode("ascii"),
        hashlib.sha256,
    ).hexdigest()
    return f"{encoded_payload}.{signature}"


def require_admin(authorization: str | None = Header(default=None)) -> dict[str, Any]:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing admin token")

    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Missing admin token")

    try:
        encoded_payload, provided_signature = token.split(".", 1)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail="Invalid admin token") from exc

    expected_signature = hmac.new(
        JWT_SECRET.encode("utf-8"),
        encoded_payload.encode("ascii"),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(expected_signature, provided_signature):
        raise HTTPException(status_code=401, detail="Invalid admin token")

    try:
        payload = json.loads(
            base64.urlsafe_b64decode(encoded_payload.encode("ascii")).decode("utf-8")
        )
    except (ValueError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=401, detail="Invalid admin token") from exc

    if payload.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")

    expires_raw = payload.get("exp")
    if not isinstance(expires_raw, str):
        raise HTTPException(status_code=401, detail="Invalid admin token")

    try:
        expires_at = datetime.fromisoformat(expires_raw)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail="Invalid admin token") from exc

    if expires_at <= datetime.now(timezone.utc):
        raise HTTPException(status_code=401, detail="Admin token expired")

    return payload


def _sign_token(payload: dict[str, Any]) -> str:
    encoded_payload = base64.urlsafe_b64encode(
        json.dumps(payload, separators=(",", ":")).encode("utf-8")
    ).decode("ascii")
    signature = hmac.new(
        JWT_SECRET.encode("utf-8"),
        encoded_payload.encode("ascii"),
        hashlib.sha256,
    ).hexdigest()
    return f"{encoded_payload}.{signature}"


def create_user_token(user_id: int) -> str:
    expires_at = datetime.now(timezone.utc) + timedelta(days=180)
    return _sign_token(
        {
            "sub": f"user:{user_id}",
            "role": "user",
            "exp": expires_at.isoformat(),
        }
    )


def require_user(authorization: str | None = Header(default=None)) -> dict[str, Any]:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing user token")

    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Missing user token")

    try:
        encoded_payload, provided_signature = token.split(".", 1)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail="Invalid user token") from exc

    expected_signature = hmac.new(
        JWT_SECRET.encode("utf-8"),
        encoded_payload.encode("ascii"),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(expected_signature, provided_signature):
        raise HTTPException(status_code=401, detail="Invalid user token")

    try:
        payload = json.loads(
            base64.urlsafe_b64decode(encoded_payload.encode("ascii")).decode("utf-8")
        )
    except (ValueError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=401, detail="Invalid user token") from exc

    if payload.get("role") != "user":
        raise HTTPException(status_code=403, detail="User role required")

    sub = payload.get("sub")
    if not isinstance(sub, str) or not sub.startswith("user:"):
        raise HTTPException(status_code=401, detail="Invalid user token")

    expires_raw = payload.get("exp")
    if not isinstance(expires_raw, str):
        raise HTTPException(status_code=401, detail="Invalid user token")

    try:
        expires_at = datetime.fromisoformat(expires_raw)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail="Invalid user token") from exc

    if expires_at <= datetime.now(timezone.utc):
        raise HTTPException(status_code=401, detail="User token expired")

    return {"user_id": int(sub.split(":", 1)[1])}


def _public_image_path(filename: str) -> str:
    return f"/uploads/{filename}"


def _normalize_cover_path(path: str | None) -> str:
    if not path:
        return ""
    raw = str(path).strip()
    if not raw:
        return ""
    if raw.startswith(("http://", "https://")):
        return raw
    # Already a public uploads path
    if raw.startswith("/uploads/"):
        return raw
    # Legacy: story_card_images/... or assets/story_card_images/...
    if "story_card_images/" in raw:
        return _public_image_path(raw.split("/")[-1])
    # Bare filename or uploads/filename without leading slash
    if "/" not in raw or raw.startswith("uploads/"):
        return _public_image_path(raw.split("/")[-1])
    return raw


def _available_story_images() -> list[dict[str, str]]:
    items: list[dict[str, str]] = []
    for file_path in sorted(UPLOAD_ROOT.glob("*")):
        if not file_path.is_file():
            continue
        extension = file_path.suffix.lower()
        if extension not in {".jpg", ".jpeg", ".png", ".webp"}:
            continue
        items.append(
            {
                "name": file_path.name,
                "path": _public_image_path(file_path.name),
            }
        )
    return items


def _fetch_google_json(endpoint: str, query: dict[str, str]) -> dict[str, Any]:
    url = f"{endpoint}?{urlencode(query)}"
    with urlopen(url, timeout=10) as response:
        return json.loads(response.read().decode("utf-8"))


def _verify_google_payload(payload: GoogleAuthRequest) -> dict[str, Any]:
    if payload.id_token:
        token_info = _fetch_google_json(
            "https://oauth2.googleapis.com/tokeninfo",
            {"id_token": payload.id_token},
        )
        LOGGER.debug("Google tokeninfo (id_token): %s", token_info)
        audience = token_info.get("aud", "")
        if GOOGLE_CLIENT_IDS and audience not in GOOGLE_CLIENT_IDS:
            LOGGER.warning("Google audience mismatch: aud=%s allowed=%s tokeninfo=%s", audience, GOOGLE_CLIENT_IDS, token_info)
            raise HTTPException(status_code=401, detail="Google audience mismatch")

        email = token_info.get("email", "")
        subject = token_info.get("sub", "")
        if not email or not subject:
            raise HTTPException(status_code=401, detail="Invalid Google token")

        return {
            "email": email,
            "subject": subject,
            "display_name": token_info.get("name") or email.split("@")[0],
            "photo_url": token_info.get("picture") or "",
        }

    if payload.access_token:
        token_info = _fetch_google_json(
            "https://oauth2.googleapis.com/tokeninfo",
            {"access_token": payload.access_token},
        )
        LOGGER.debug("Google tokeninfo (access_token): %s", token_info)
        audience = token_info.get("aud", "")
        if GOOGLE_CLIENT_IDS and audience not in GOOGLE_CLIENT_IDS:
            LOGGER.warning("Google audience mismatch: aud=%s allowed=%s tokeninfo=%s", audience, GOOGLE_CLIENT_IDS, token_info)
            raise HTTPException(status_code=401, detail="Google audience mismatch")

        user_info = _fetch_google_json(
            "https://www.googleapis.com/oauth2/v2/userinfo",
            {"access_token": payload.access_token},
        )
        LOGGER.debug("Google userinfo: %s", user_info)
        email = user_info.get("email", "")
        subject = user_info.get("id", "")
        if not email or not subject:
            raise HTTPException(status_code=401, detail="Invalid Google token")

        return {
            "email": email,
            "subject": subject,
            "display_name": user_info.get("name") or email.split("@")[0],
            "photo_url": user_info.get("picture") or "",
        }

    raise HTTPException(status_code=400, detail="Missing Google token")


def _parse_optional_datetime(value: str | None) -> datetime | None:
    if value is None or value.strip() == "":
        return None
    normalized = value.strip().replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid scheduled date") from exc


def _serialize_datetime(value: datetime | None) -> str | None:
    return value.isoformat() if value else None


def _record_chapter_revision(
    chapter_id: int,
    title: str,
    content: str,
    notes: str,
    submission_status: str,
    scheduled_for: datetime | None,
) -> None:
    scheduled_value = scheduled_for.isoformat() if isinstance(scheduled_for, datetime) else scheduled_for
    execute_write(
        """
        INSERT INTO chapter_revisions (chapter_id, title, content, notes, submission_status, scheduled_for)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (chapter_id, title, content, notes, submission_status, scheduled_value),
    )


@app.get("/")
def healthcheck():
    return {"message": "Novel Mobile backend is running."}


@app.on_event("startup")
def startup_initialize_database():
    try:
        initialized = initialize_database_if_needed()
        migration_report = run_startup_migrations()
        if initialized:
            LOGGER.info("Database tables were missing. Schema/data initialized automatically.")
        LOGGER.info("Startup migrations: %s", migration_report)
        _content_version_row()
    except DB_INIT_EXCEPTIONS as exc:
        LOGGER.exception("Automatic database initialization failed: %s", exc)


@app.get("/api/content/version", response_model=VersionResponse)
def get_content_version():
    return _content_version_row()


@app.post("/api/admin/login")
def admin_login(payload: AdminLoginRequest):
    if payload.username != ADMIN_USERNAME or payload.password != ADMIN_PASSWORD:
        raise HTTPException(status_code=401, detail="Invalid admin credentials")

    token = create_admin_token(payload.username)
    return {
        "token": token,
        "username": payload.username,
        "expires_in_hours": ADMIN_TOKEN_EXPIRES_HOURS,
    }


@app.post("/api/auth/google")
def authenticate_google(payload: GoogleAuthRequest):
    google_user = _verify_google_payload(payload)
    rows = fetch_all("SELECT id FROM app_users WHERE email=%s LIMIT 1", (google_user["email"],))

    if rows:
        user_id = rows[0]["id"]
        execute_write(
            """
            UPDATE app_users
            SET provider=%s, provider_subject=%s, display_name=%s, photo_url=%s, last_login_at=CURRENT_TIMESTAMP
            WHERE id=%s
            """,
            (
                "google",
                google_user["subject"],
                google_user["display_name"],
                google_user["photo_url"],
                user_id,
            ),
        )
    else:
        user_id, _ = execute_write(
            """
            INSERT INTO app_users (email, provider, provider_subject, display_name, photo_url)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (
                google_user["email"],
                "google",
                google_user["subject"],
                google_user["display_name"],
                google_user["photo_url"],
            ),
        )

    return {
        "id": user_id,
        "email": google_user["email"],
        "display_name": google_user["display_name"],
        "photo_url": google_user["photo_url"],
        "provider": "google",
        "token": create_user_token(user_id),
    }


@app.post("/api/auth/email")
def authenticate_email(payload: EmailAuthRequest):
    email = payload.email.strip()
    if not email or "@" not in email:
        raise HTTPException(status_code=400, detail="Invalid email")

    display_name = (payload.display_name or "").strip() or email.split("@")[0]
    rows = fetch_all("SELECT id FROM app_users WHERE email=%s LIMIT 1", (email,))
    if rows:
        user_id = rows[0]["id"]
        execute_write(
            """
            UPDATE app_users
            SET provider='email', display_name=%s, last_login_at=CURRENT_TIMESTAMP
            WHERE id=%s
            """,
            (display_name, user_id),
        )
    else:
        user_id, _ = execute_write(
            """
            INSERT INTO app_users (email, provider, display_name, photo_url)
            VALUES (%s, 'email', %s, '')
            """,
            (email, display_name),
        )

    return {
        "id": user_id,
        "email": email,
        "display_name": display_name,
        "photo_url": "",
        "provider": "email",
        "token": create_user_token(user_id),
    }


@app.post("/api/auth/guest")
def authenticate_guest(_: GuestAuthRequest):
    email = "guest@novel.app"
    display_name = "Guest"
    rows = fetch_all("SELECT id FROM app_users WHERE email=%s LIMIT 1", (email,))
    if rows:
        user_id = rows[0]["id"]
        execute_write(
            """
            UPDATE app_users
            SET provider='guest', display_name=%s, last_login_at=CURRENT_TIMESTAMP
            WHERE id=%s
            """,
            (display_name, user_id),
        )
    else:
        user_id, _ = execute_write(
            """
            INSERT INTO app_users (email, provider, display_name, photo_url)
            VALUES (%s, 'guest', %s, '')
            """,
            (email, display_name),
        )

    return {
        "id": user_id,
        "email": email,
        "display_name": display_name,
        "photo_url": "",
        "provider": "guest",
        "token": create_user_token(user_id),
    }


@app.get("/api/me")
def get_me(user: dict[str, Any] = Depends(require_user)):
    rows = fetch_all(
        "SELECT id, email, display_name, photo_url, provider FROM app_users WHERE id=%s LIMIT 1",
        (user["user_id"],),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="User not found")
    u = rows[0]
    story_count_rows = fetch_all(
        "SELECT COUNT(*) AS c FROM books WHERE user_id=%s",
        (user["user_id"],),
    )
    library_count_rows = fetch_all(
        "SELECT COUNT(*) AS c FROM library_entries WHERE user_id=%s",
        (user["user_id"],),
    )
    reading_list_count_rows = fetch_all(
        "SELECT COUNT(*) AS c FROM reading_lists WHERE user_id=%s",
        (user["user_id"],),
    )
    completed_rows = fetch_all(
        """
        SELECT COUNT(*) AS c FROM library_entries
        WHERE user_id=%s AND LOWER(reading_status) IN ('completed', 'complete', 'finished', 'done')
        """,
        (user["user_id"],),
    )
    story_count = int(story_count_rows[0]["c"]) if story_count_rows else 0
    library_count = int(library_count_rows[0]["c"]) if library_count_rows else 0
    reading_list_count = int(reading_list_count_rows[0]["c"]) if reading_list_count_rows else 0
    completed_count = int(completed_rows[0]["c"]) if completed_rows else 0
    display_name = u.get("display_name") or (u.get("email") or "Reader").split("@")[0]
    username = "@" + display_name.lower().replace(" ", "")
    return {
        "id": u["id"],
        "email": u.get("email") or "",
        "display_name": display_name,
        "username": username,
        "photo_url": u.get("photo_url") or "",
        "provider": u.get("provider") or "",
        "following": 0,
        "followers": 0,
        "blocked": 0,
        "chapters_read": completed_count,
        "social_karma": story_count * 10,
        "day_streak": 0,
        "story_count": story_count,
        "library_count": library_count,
        "reading_list_count": reading_list_count,
    }


@app.get("/api/admin/session")
def admin_session(_: dict[str, Any] = Depends(require_admin)):
    return {"ok": True, "username": ADMIN_USERNAME}


@app.get("/api/story-images")
def list_story_images():
    return {"items": _available_story_images()}


@app.post("/api/upload-image")
async def upload_image(
    file: UploadFile = File(...),
    _: dict[str, Any] = Depends(require_admin),
):
    extension = Path(file.filename or "upload").suffix.lower()
    if extension not in {".jpg", ".jpeg", ".png", ".webp"}:
        raise HTTPException(status_code=400, detail="Unsupported image format")

    filename = f"{uuid4().hex}{extension}"
    target_path = UPLOAD_ROOT / filename
    content = await file.read()
    target_path.write_bytes(content)
    bump_content_version()
    return {"path": _public_image_path(filename), "filename": filename}


@app.post("/api/write/upload-image")
async def upload_writer_image(file: UploadFile = File(...)):
    extension = Path(file.filename or "upload").suffix.lower()
    if extension not in {".jpg", ".jpeg", ".png", ".webp"}:
        raise HTTPException(status_code=400, detail="Unsupported image format")

    filename = f"{uuid4().hex}{extension}"
    target_path = UPLOAD_ROOT / filename
    target_path.write_bytes(await file.read())
    bump_content_version()
    return {"path": _public_image_path(filename), "filename": filename}


@app.post("/api/support/upload-attachment")
async def upload_support_attachment(file: UploadFile = File(...)):
    extension = Path(file.filename or "upload").suffix.lower()
    if extension not in {".jpg", ".jpeg", ".png", ".webp"}:
        raise HTTPException(status_code=400, detail="Unsupported attachment format")

    filename = f"support-{uuid4().hex}{extension}"
    target_path = UPLOAD_ROOT / filename
    target_path.write_bytes(await file.read())
    return {"path": _public_image_path(filename), "filename": filename}


@app.get("/api/bootstrap")
def bootstrap():
    discover_tabs = [
        row["name"]
        for row in fetch_all(
            "SELECT name FROM categories WHERE tab_group = 'discover' ORDER BY sort_order"
        )
    ]

    explore_topics = fetch_all(
        "SELECT name, topic_count FROM categories WHERE tab_group = 'explore' ORDER BY sort_order"
    )

    books = fetch_all(
        """
        SELECT id, title, author, description, cover_path, accent_hex, section_name,
               status_text, rating, genre, cta_label,
               COALESCE(primary_genre, genre) AS primary_genre,
               COALESCE(secondary_genre, '') AS secondary_genre,
               COALESCE(is_completed, 0) AS is_completed
        FROM books
        ORDER BY sort_order
        """
    )

    recently_updated = [
        {
            "id": book["id"],
            "title": book["title"],
            "author": book["author"],
            "cover_path": _normalize_cover_path(book["cover_path"]),
            "accent_hex": book["accent_hex"],
        }
        for book in books
        if book["section_name"] == "recently_updated"
    ]

    recently_completed = [
        {
            "id": book["id"],
            "title": book["title"],
            "author": book["author"],
            "cover_path": _normalize_cover_path(book["cover_path"]),
            "accent_hex": book["accent_hex"],
        }
        for book in books
        if book["section_name"] == "recently_completed"
    ]

    featured_candidates = [b for b in books if b["section_name"] == "featured"]
    if not featured_candidates:
        featured_candidates = books[:1]

    featured_book = None
    if featured_candidates:
        featured_raw = featured_candidates[0]
        featured_book = {
            "id": featured_raw["id"],
            "title": featured_raw["title"],
            "author": featured_raw["author"],
            "description": featured_raw["description"],
            "status_text": featured_raw["status_text"],
            "rating": featured_raw["rating"],
            "genre": featured_raw["genre"],
            "cta": featured_raw["cta_label"],
        }

    library_entries = fetch_all(
        """
        SELECT le.id, le.reading_status, le.updated_text, le.chapters, le.primary_genre,
               le.secondary_genre, b.id AS book_id, b.title, b.author, b.cover_path, b.accent_hex
        FROM library_entries le
        JOIN books b ON b.id = le.book_id
        ORDER BY le.sort_order, le.id
        """
    )

    library_payload = [
        {
            "id": row["id"],
            "book": {
                "id": row["book_id"],
                "title": row["title"],
                "author": row["author"],
                "cover_path": _normalize_cover_path(row["cover_path"]),
                "accent_hex": row["accent_hex"],
            },
            "reading_status": row["reading_status"],
            "updated_text": row["updated_text"],
            "chapters": row["chapters"],
            "primary_genre": row["primary_genre"],
            "secondary_genre": row["secondary_genre"],
        }
        for row in library_entries
    ]

    write_meta_rows = fetch_all(
        "SELECT manage_tabs, story_tabs, filter_label, sort_label, empty_title, empty_cta FROM write_screen LIMIT 1"
    )
    if not write_meta_rows:
        raise HTTPException(status_code=500, detail="Write metadata is missing")

    write_meta = write_meta_rows[0]
    write_screen = {
        "manage_tabs": write_meta["manage_tabs"].split(","),
        "story_tabs": write_meta["story_tabs"].split(","),
        "filter_label": write_meta["filter_label"],
        "sort_label": write_meta["sort_label"],
        "empty_title": write_meta["empty_title"],
        "empty_cta": write_meta["empty_cta"],
    }

    notifications = fetch_all(
        "SELECT tab_name AS tab, title, message, created_at FROM notifications ORDER BY sort_order"
    )

    menu_rows = fetch_all(
        "SELECT section_name, label, icon_name, route_name FROM menu_items ORDER BY section_order, sort_order"
    )
    menu_map = defaultdict(list)
    for row in menu_rows:
        menu_map[row["section_name"]].append(
            {
                "label": row["label"],
                "icon": row["icon_name"],
                "route": row["route_name"],
            }
        )

    menu_sections = [
        {"section": section, "items": items}
        for section, items in menu_map.items()
    ]

    profile_rows = fetch_all(
        "SELECT display_name, username, following, followers, blocked, chapters_read, social_karma, day_streak FROM profiles LIMIT 1"
    )
    if not profile_rows:
        raise HTTPException(status_code=500, detail="Profile is missing")

    profile = profile_rows[0]
    reading_lists = fetch_all(
        "SELECT name, story_count, cover_path FROM reading_lists ORDER BY sort_order"
    )

    profile_payload = {
        **profile,
        "reading_lists": [
            {**row, "cover_path": _normalize_cover_path(row["cover_path"])}
            for row in reading_lists
        ],
    }

    achievement_rows = fetch_all(
        """
        SELECT group_name, title, subtitle, progress_label, badge_value, style
        FROM achievements
        ORDER BY group_order, sort_order
        """
    )
    achievement_map = defaultdict(list)
    for row in achievement_rows:
        achievement_map[row["group_name"]].append(
            {
                "title": row["title"],
                "subtitle": row["subtitle"],
                "progress_label": row["progress_label"],
                "badge_value": row["badge_value"],
                "style": row["style"],
            }
        )

    achievements = [
        {"group_name": group_name, "items": items}
        for group_name, items in achievement_map.items()
    ]

    return {
        "discover_tabs": discover_tabs,
        "recently_updated": recently_updated,
        "recently_completed": recently_completed,
        "discover_books": [
            {**book, "cover_path": _normalize_cover_path(book["cover_path"])}
            for book in books
        ],
        "featured_book": featured_book,
        "explore_topics": explore_topics,
        "library_entries": library_payload,
        "write_screen": write_screen,
        "notifications": notifications,
        "menu_sections": menu_sections,
        "profile": profile_payload,
        "achievements": achievements,
    }


@app.get("/api/search")
def search_stories(
    query: str = Query(default=""),
    genre: str = Query(default=""),
    min_rating: float = Query(default=0.0),
    limit: int = Query(default=40, ge=1, le=100),
):
    q = "%" + query.strip() + "%"
    g = genre.strip()
    if g:
        g_like = "%" + g + "%"
        rows = fetch_all(
            """
            SELECT id, title, author, description, cover_path, accent_hex, status_text, rating, genre
            FROM books
            WHERE (title LIKE %s OR author LIKE %s OR description LIKE %s)
              AND (
                    genre LIKE %s
                 OR COALESCE(primary_genre, '') LIKE %s
                 OR COALESCE(secondary_genre, '') LIKE %s
              )
              AND rating >= %s
            ORDER BY rating DESC, id DESC
            LIMIT %s
            """,
            (q, q, q, g_like, g_like, g_like, min_rating, limit),
        )
    else:
        rows = fetch_all(
            """
            SELECT id, title, author, description, cover_path, accent_hex, status_text, rating, genre
            FROM books
            WHERE (title LIKE %s OR author LIKE %s OR description LIKE %s)
              AND rating >= %s
            ORDER BY rating DESC, id DESC
            LIMIT %s
            """,
            (q, q, q, min_rating, limit),
        )
    return {
        "items": [
            {**row, "cover_path": _normalize_cover_path(row["cover_path"])}
            for row in rows
        ]
    }


@app.get("/api/notifications")
def get_notifications(tab: str = Query(default="")):
    if tab.strip():
        rows = fetch_all(
            "SELECT tab_name AS tab, title, message, created_at FROM notifications WHERE LOWER(tab_name)=LOWER(%s) ORDER BY sort_order",
            (tab.strip(),),
        )
    else:
        rows = fetch_all(
            "SELECT tab_name AS tab, title, message, created_at FROM notifications ORDER BY sort_order"
        )
    return {"items": rows}


@app.post("/api/support/requests")
def create_support_request(payload: SupportRequestCreateRequest):
    request_id, affected = execute_write(
        """
        INSERT INTO support_requests (
            email, first_name, issue, subject, description,
            device_type, attachment_path, status
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, 'open')
        """,
        (
            payload.email,
            payload.first_name,
            payload.issue,
            payload.subject,
            payload.description,
            payload.device_type,
            payload.attachment_path,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to create support request")
    bump_content_version()
    return {"ok": True, "id": request_id}


@app.get("/api/chat/messages")
def get_chat_messages(user: dict[str, Any] = Depends(require_user)):
    rows = fetch_all(
        """
        SELECT id, user_id, sender, message, created_at
        FROM chat_messages
        WHERE user_id=%s
        ORDER BY created_at ASC, id ASC
        """,
        (user["user_id"],),
    )
    return {
        "items": [
            {
                "id": row["id"],
                "sender": row["sender"],
                "message": row["message"],
                "created_at": _serialize_db_datetime(row["created_at"]),
            }
            for row in rows
        ]
    }


@app.post("/api/chat/messages")
def create_chat_message(
    payload: ChatMessageCreateRequest,
    user: dict[str, Any] = Depends(require_user),
):
    message = payload.message.strip()
    if not message:
        raise HTTPException(status_code=400, detail="Message cannot be empty")
    sender = (payload.sender or "user").strip() or "user"
    row_id, _ = execute_write(
        "INSERT INTO chat_messages (user_id, sender, message) VALUES (%s, %s, %s)",
        (user["user_id"], sender, message),
    )
    return {"ok": True, "id": row_id}


@app.get("/api/library")
def get_library_entries(user: dict[str, Any] = Depends(require_user)):
    rows = fetch_all(
        """
        SELECT le.id, le.reading_status, le.updated_text, le.chapters, le.primary_genre,
               le.secondary_genre, b.id AS book_id, b.title, b.author, b.cover_path, b.accent_hex
        FROM library_entries le
        JOIN books b ON b.id = le.book_id
        WHERE le.user_id = %s
        ORDER BY le.sort_order, le.id
        """,
        (user["user_id"],),
    )
    return {
        "items": [
            {
                "id": row["id"],
                "book": {
                    "id": row["book_id"],
                    "title": row["title"],
                    "author": row["author"],
                    "cover_path": _normalize_cover_path(row["cover_path"]),
                    "accent_hex": row["accent_hex"],
                },
                "reading_status": row["reading_status"],
                "updated_text": row["updated_text"],
                "chapters": row["chapters"],
                "primary_genre": row["primary_genre"],
                "secondary_genre": row["secondary_genre"],
            }
            for row in rows
        ]
    }


@app.post("/api/library")
def create_library_entry(
    payload: LibraryCreateRequest,
    user: dict[str, Any] = Depends(require_user),
):
    _, affected = execute_write(
        """
        INSERT INTO library_entries (user_id, book_id, reading_status, updated_text, chapters, primary_genre, secondary_genre, sort_order)
        VALUES (%s, %s, %s, %s, %s, %s, %s, 999)
        """,
        (
            user["user_id"],
            payload.book_id,
            payload.reading_status,
            payload.updated_text,
            payload.chapters,
            payload.primary_genre,
            payload.secondary_genre,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to create library entry")
    bump_content_version()
    return {"ok": True}


@app.put("/api/library/{entry_id}")
def update_library_entry(
    entry_id: int,
    payload: LibraryUpdateRequest,
    user: dict[str, Any] = Depends(require_user),
):
    current_rows = fetch_all(
        "SELECT * FROM library_entries WHERE id=%s AND user_id=%s",
        (entry_id, user["user_id"]),
    )
    if not current_rows:
        raise HTTPException(status_code=404, detail="Library entry not found")

    current = current_rows[0]
    _, affected = execute_write(
        """
        UPDATE library_entries
        SET reading_status=%s,
            updated_text=%s,
            chapters=%s,
            primary_genre=%s,
            secondary_genre=%s
        WHERE id=%s AND user_id=%s
        """,
        (
            payload.reading_status or current["reading_status"],
            payload.updated_text or current["updated_text"],
            payload.chapters if payload.chapters is not None else current["chapters"],
            payload.primary_genre or current["primary_genre"],
            payload.secondary_genre or current["secondary_genre"],
            entry_id,
            user["user_id"],
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update library entry")
    bump_content_version()
    return {"ok": True}


@app.delete("/api/library/{entry_id}")
def delete_library_entry(entry_id: int, user: dict[str, Any] = Depends(require_user)):
    _, affected = execute_write(
        "DELETE FROM library_entries WHERE id=%s AND user_id=%s",
        (entry_id, user["user_id"]),
    )
    if affected == 0:
        raise HTTPException(status_code=404, detail="Library entry not found")
    bump_content_version()
    return {"ok": True}


@app.get("/api/reading-lists")
def get_public_reading_lists(user: dict[str, Any] = Depends(require_user)):
    rows = fetch_all(
        """
        SELECT id, profile_id, name, story_count, cover_path, sort_order
        FROM reading_lists
        WHERE user_id = %s OR (user_id IS NULL AND profile_id = 1)
        ORDER BY sort_order, id
        """,
        (user["user_id"],),
    )
    return {
        "items": [
            {**row, "cover_path": _normalize_cover_path(row.get("cover_path"))}
            for row in rows
        ]
    }


@app.post("/api/reading-lists")
def create_public_reading_list(
    payload: ReadingListCreateRequest,
    user: dict[str, Any] = Depends(require_user),
):
    name = (payload.name or "").strip()
    if not name:
        raise HTTPException(status_code=400, detail="Reading list name is required")
    row_id, _ = execute_write(
        """
        INSERT INTO reading_lists (user_id, profile_id, name, story_count, cover_path, sort_order)
        VALUES (%s, 1, %s, %s, %s, %s)
        """,
        (
            user["user_id"],
            name,
            payload.story_count,
            _normalize_cover_path(payload.cover_path),
            payload.sort_order,
        ),
    )
    bump_content_version()
    return {"ok": True, "id": row_id}


@app.get("/api/write/stories")
def get_writer_stories(user: dict[str, Any] = Depends(require_user)):
    rows = fetch_all(
        """
        SELECT id, title, author, description, genre, status_text, cover_path, accent_hex
        FROM books
        WHERE user_id = %s
        ORDER BY id DESC
        """,
        (user["user_id"],),
    )
    return {
        "items": [
            {**row, "cover_path": _normalize_cover_path(row["cover_path"])}
            for row in rows
        ]
    }


@app.get("/api/write/stories/{story_id}/chapters")
def get_story_chapters(story_id: int):
    story_rows = fetch_all("SELECT id FROM books WHERE id=%s", (story_id,))
    if not story_rows:
        raise HTTPException(status_code=404, detail="Story not found")

    rows = fetch_all(
        """
        SELECT id, story_id, chapter_number, title, content, notes, submission_status, scheduled_for,
               sort_order, created_at, updated_at
        FROM chapters
        WHERE story_id=%s
        ORDER BY chapter_number, sort_order, id
        """,
        (story_id,),
    )
    return {
        "items": [
            {
                **row,
                "scheduled_for": _serialize_datetime(row.get("scheduled_for")),
                "created_at": _serialize_datetime(row.get("created_at")),
                "updated_at": _serialize_datetime(row.get("updated_at")),
            }
            for row in rows
        ]
    }


@app.get("/api/write/chapters/{chapter_id}/revisions")
def get_story_chapter_revisions(chapter_id: int):
    rows = fetch_all(
        """
        SELECT id, chapter_id, title, notes, submission_status, scheduled_for, created_at
        FROM chapter_revisions
        WHERE chapter_id=%s
        ORDER BY created_at DESC, id DESC
        """,
        (chapter_id,),
    )
    return {
        "items": [
            {
                **row,
                "scheduled_for": _serialize_datetime(row.get("scheduled_for")),
                "created_at": _serialize_datetime(row.get("created_at")),
            }
            for row in rows
        ]
    }


@app.post("/api/write/stories/{story_id}/chapters")
def create_story_chapter(story_id: int, payload: ChapterCreateRequest):
    story_rows = fetch_all("SELECT id FROM books WHERE id=%s", (story_id,))
    if not story_rows:
        raise HTTPException(status_code=404, detail="Story not found")

    chapter_number = payload.chapter_number
    if chapter_number is None:
        next_rows = fetch_all(
            "SELECT COALESCE(MAX(chapter_number), 0) + 1 AS next_chapter FROM chapters WHERE story_id=%s",
            (story_id,),
        )
        chapter_number = next_rows[0]["next_chapter"]

    submission_status = (payload.submission_status or "draft").strip() or "draft"
    scheduled_for = _parse_optional_datetime(payload.scheduled_for)
    scheduled_value = scheduled_for.isoformat() if isinstance(scheduled_for, datetime) else scheduled_for
    row_id, _ = execute_write(
        """
        INSERT INTO chapters (
            story_id, chapter_number, title, content, notes, submission_status, scheduled_for, sort_order
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            story_id,
            chapter_number,
            payload.title,
            payload.content,
            payload.notes or "",
            submission_status,
            scheduled_value,
            chapter_number,
        ),
    )
    _record_chapter_revision(
        row_id,
        payload.title,
        payload.content,
        payload.notes or "",
        submission_status,
        scheduled_for,
    )
    bump_content_version()
    return {"ok": True, "id": row_id}


@app.put("/api/write/chapters/{chapter_id}")
def update_story_chapter(chapter_id: int, payload: ChapterUpdateRequest):
    rows = fetch_all("SELECT * FROM chapters WHERE id=%s", (chapter_id,))
    if not rows:
        raise HTTPException(status_code=404, detail="Chapter not found")

    current = rows[0]
    next_title = payload.title or current["title"]
    next_content = payload.content if payload.content is not None else current["content"]
    next_notes = payload.notes if payload.notes is not None else current.get("notes", "")
    next_status = (payload.submission_status or current.get("submission_status") or "draft").strip() or "draft"
    next_scheduled_for = (
        _parse_optional_datetime(payload.scheduled_for)
        if payload.scheduled_for is not None
        else current.get("scheduled_for")
    )
    # Normalize scheduled_for for both SQLite (TEXT) and MySQL (DATETIME).
    scheduled_value = next_scheduled_for
    if isinstance(scheduled_value, datetime):
        scheduled_value = scheduled_value.isoformat()

    execute_write(
        """
        UPDATE chapters
        SET chapter_number=%s, title=%s, content=%s, notes=%s, submission_status=%s,
            scheduled_for=%s, sort_order=%s
        WHERE id=%s
        """,
        (
            payload.chapter_number
            if payload.chapter_number is not None
            else current["chapter_number"],
            next_title,
            next_content,
            next_notes,
            next_status,
            scheduled_value,
            payload.chapter_number
            if payload.chapter_number is not None
            else current["sort_order"],
            chapter_id,
        ),
    )
    # Do not treat SQLite rowcount==0 as failure: identical values still succeed.
    _record_chapter_revision(
        chapter_id,
        next_title,
        next_content,
        next_notes,
        next_status,
        next_scheduled_for if isinstance(next_scheduled_for, datetime) else (
            _parse_optional_datetime(str(next_scheduled_for)) if next_scheduled_for else None
        ),
    )
    bump_content_version()
    return {"ok": True}


@app.delete("/api/write/chapters/{chapter_id}")
def delete_story_chapter(chapter_id: int):
    _, affected = execute_write("DELETE FROM chapters WHERE id=%s", (chapter_id,))
    if affected == 0:
        raise HTTPException(status_code=404, detail="Chapter not found")
    bump_content_version()
    return {"ok": True}


@app.post("/api/write/stories")
def create_writer_story(
    payload: StoryCreateRequest,
    user: dict[str, Any] = Depends(require_user),
):
    cover = _normalize_cover_path(payload.cover_path)
    story_id, _ = execute_write(
        """
        INSERT INTO books (
            user_id, title, author, description, cover_path, accent_hex, section_name,
            status_text, rating, genre, primary_genre, cta_label, sort_order
        )
        VALUES (%s, %s, %s, %s, %s, '#557E7A', 'recently_updated', 'Draft', 0.0, %s, %s, 'Read now', 999)
        """,
        (
            user["user_id"],
            payload.title,
            payload.author,
            payload.description,
            cover,
            payload.genre,
            payload.genre,
        ),
    )
    bump_content_version()
    return {"ok": True, "id": story_id}


@app.put("/api/write/stories/{story_id}")
def update_writer_story(
    story_id: int,
    payload: StoryUpdateRequest,
    user: dict[str, Any] = Depends(require_user),
):
    rows = fetch_all(
        "SELECT * FROM books WHERE id=%s AND (user_id=%s OR user_id IS NULL)",
        (story_id, user["user_id"]),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Story not found")

    current = rows[0]
    next_cover = (
        _normalize_cover_path(payload.cover_path)
        if payload.cover_path is not None
        else current["cover_path"]
    )
    _, affected = execute_write(
        """
        UPDATE books
        SET title=%s, author=%s, description=%s, genre=%s, primary_genre=%s, cover_path=%s, user_id=%s
        WHERE id=%s
        """,
        (
            payload.title or current["title"],
            payload.author or current["author"],
            payload.description or current["description"],
            payload.genre or current["genre"],
            payload.genre or current.get("primary_genre") or current["genre"],
            next_cover,
            user["user_id"],
            story_id,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update story")
    bump_content_version()
    return {"ok": True}


@app.delete("/api/write/stories/{story_id}")
def delete_writer_story(story_id: int, user: dict[str, Any] = Depends(require_user)):
    _, affected = execute_write(
        "DELETE FROM books WHERE id=%s AND (user_id=%s OR user_id IS NULL)",
        (story_id, user["user_id"]),
    )
    if affected == 0:
        raise HTTPException(status_code=404, detail="Story not found")
    bump_content_version()
    return {"ok": True}


@app.get("/api/admin/bootstrap")
def admin_bootstrap(_: dict[str, Any] = Depends(require_admin)):
    categories = fetch_all(
        "SELECT id, name, topic_count, tab_group, sort_order FROM categories ORDER BY tab_group, sort_order, id"
    )
    books = fetch_all(
        """
        SELECT id, title, author, description, cover_path, accent_hex, section_name,
               status_text, rating, genre, cta_label, sort_order
        FROM books
        ORDER BY sort_order, id
        """
    )
    notifications = fetch_all(
        "SELECT id, tab_name, title, message, created_at, sort_order FROM notifications ORDER BY sort_order, id"
    )
    menu_items = fetch_all(
        "SELECT id, section_name, section_order, label, icon_name, route_name, sort_order FROM menu_items ORDER BY section_order, sort_order, id"
    )
    write_screen_rows = fetch_all(
        "SELECT id, manage_tabs, story_tabs, filter_label, sort_label, empty_title, empty_cta FROM write_screen ORDER BY id ASC LIMIT 1"
    )
    profile_rows = fetch_all(
        "SELECT id, display_name, username, following, followers, blocked, chapters_read, social_karma, day_streak FROM profiles ORDER BY id ASC LIMIT 1"
    )
    reading_lists = fetch_all(
        "SELECT id, profile_id, name, story_count, cover_path, sort_order FROM reading_lists ORDER BY sort_order, id"
    )
    achievements = fetch_all(
        "SELECT id, group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order FROM achievements ORDER BY group_order, sort_order, id"
    )
    support_requests = fetch_all(
        "SELECT id, email, first_name, issue, subject, description, device_type, attachment_path, status, created_at FROM support_requests ORDER BY created_at DESC, id DESC"
    )

    return {
        "categories": categories,
        "books": [
            {**book, "cover_path": _normalize_cover_path(book["cover_path"])}
            for book in books
        ],
        "notifications": notifications,
        "menu_items": menu_items,
        "write_screen": write_screen_rows[0] if write_screen_rows else None,
        "profile": profile_rows[0] if profile_rows else None,
        "reading_lists": reading_lists,
        "achievements": achievements,
        "support_requests": support_requests,
        "stats": {
            "category_count": len(categories),
            "book_count": len(books),
            "notification_count": len(notifications),
            "menu_item_count": len(menu_items),
            "reading_list_count": len(reading_lists),
            "achievement_count": len(achievements),
            "support_request_count": len(support_requests),
        },
    }


@app.get("/api/admin/support-requests")
def admin_get_support_requests(_: dict[str, Any] = Depends(require_admin)):
    rows = fetch_all(
        "SELECT id, email, first_name, issue, subject, description, device_type, attachment_path, status, created_at FROM support_requests ORDER BY created_at DESC, id DESC"
    )
    return {"items": rows}


@app.put("/api/admin/support-requests/{request_id}")
def admin_update_support_request(
    request_id: int,
    payload: SupportRequestUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    _, affected = execute_write(
        "UPDATE support_requests SET status=%s WHERE id=%s",
        (payload.status, request_id),
    )
    if affected == 0:
        raise HTTPException(status_code=404, detail="Support request not found")
    bump_content_version()
    return {"ok": True}


@app.post("/api/admin/categories")
def admin_create_category(
    payload: CategoryCreateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    _, affected = execute_write(
        "INSERT INTO categories (name, topic_count, tab_group, sort_order) VALUES (%s, %s, %s, %s)",
        (payload.name, payload.topic_count, payload.tab_group, payload.sort_order),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to create category")
    bump_content_version()
    return {"ok": True}


@app.put("/api/admin/categories/{category_id}")
def admin_update_category(
    category_id: int,
    payload: CategoryUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    rows = fetch_all("SELECT * FROM categories WHERE id=%s", (category_id,))
    if not rows:
        raise HTTPException(status_code=404, detail="Category not found")

    current = rows[0]
    _, affected = execute_write(
        """
        UPDATE categories
        SET name=%s, topic_count=%s, tab_group=%s, sort_order=%s
        WHERE id=%s
        """,
        (
            payload.name or current["name"],
            payload.topic_count if payload.topic_count is not None else current["topic_count"],
            payload.tab_group or current["tab_group"],
            payload.sort_order if payload.sort_order is not None else current["sort_order"],
            category_id,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update category")
    bump_content_version()
    return {"ok": True}


@app.delete("/api/admin/categories/{category_id}")
def admin_delete_category(
    category_id: int,
    _: dict[str, Any] = Depends(require_admin),
):
    _, affected = execute_write("DELETE FROM categories WHERE id=%s", (category_id,))
    if affected == 0:
        raise HTTPException(status_code=404, detail="Category not found")
    bump_content_version()
    return {"ok": True}


@app.post("/api/admin/books")
def admin_create_book(
    payload: AdminBookCreateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    book_id, _ = execute_write(
        """
        INSERT INTO books (
            title, author, description, cover_path, accent_hex, section_name,
            status_text, rating, genre, cta_label, sort_order
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            payload.title,
            payload.author,
            payload.description,
            payload.cover_path,
            payload.accent_hex,
            payload.section_name,
            payload.status_text,
            payload.rating,
            payload.genre,
            payload.cta_label,
            payload.sort_order,
        ),
    )
    bump_content_version()
    return {"ok": True, "id": book_id}


@app.put("/api/admin/books/{book_id}")
def admin_update_book(
    book_id: int,
    payload: AdminBookUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    rows = fetch_all("SELECT * FROM books WHERE id=%s", (book_id,))
    if not rows:
        raise HTTPException(status_code=404, detail="Book not found")

    current = rows[0]
    _, affected = execute_write(
        """
        UPDATE books
        SET title=%s, author=%s, description=%s, cover_path=%s, accent_hex=%s,
            section_name=%s, status_text=%s, rating=%s, genre=%s, cta_label=%s, sort_order=%s
        WHERE id=%s
        """,
        (
            payload.title or current["title"],
            payload.author or current["author"],
            payload.description or current["description"],
            payload.cover_path if payload.cover_path is not None else current["cover_path"],
            payload.accent_hex or current["accent_hex"],
            payload.section_name or current["section_name"],
            payload.status_text or current["status_text"],
            payload.rating if payload.rating is not None else current["rating"],
            payload.genre or current["genre"],
            payload.cta_label or current["cta_label"],
            payload.sort_order if payload.sort_order is not None else current["sort_order"],
            book_id,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update book")
    bump_content_version()
    return {"ok": True}


@app.delete("/api/admin/books/{book_id}")
def admin_delete_book(
    book_id: int,
    _: dict[str, Any] = Depends(require_admin),
):
    _, affected = execute_write("DELETE FROM books WHERE id=%s", (book_id,))
    if affected == 0:
        raise HTTPException(status_code=404, detail="Book not found")
    bump_content_version()
    return {"ok": True}


@app.get("/api/admin/notifications")
def admin_get_notifications(_: dict[str, Any] = Depends(require_admin)):
    rows = fetch_all(
        "SELECT id, tab_name, title, message, created_at, sort_order FROM notifications ORDER BY sort_order, id"
    )
    return {"items": rows}


@app.post("/api/admin/notifications")
def admin_create_notification(
    payload: AdminNotificationCreateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    row_id, _ = execute_write(
        """
        INSERT INTO notifications (tab_name, title, message, created_at, sort_order)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (
            payload.tab_name,
            payload.title,
            payload.message,
            payload.created_at,
            payload.sort_order,
        ),
    )
    bump_content_version()
    return {"ok": True, "id": row_id}


@app.put("/api/admin/notifications/{notification_id}")
def admin_update_notification(
    notification_id: int,
    payload: AdminNotificationUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    rows = fetch_all("SELECT * FROM notifications WHERE id=%s", (notification_id,))
    if not rows:
        raise HTTPException(status_code=404, detail="Notification not found")

    current = rows[0]
    _, affected = execute_write(
        """
        UPDATE notifications
        SET tab_name=%s, title=%s, message=%s, created_at=%s, sort_order=%s
        WHERE id=%s
        """,
        (
            payload.tab_name or current["tab_name"],
            payload.title or current["title"],
            payload.message or current["message"],
            payload.created_at or current["created_at"],
            payload.sort_order if payload.sort_order is not None else current["sort_order"],
            notification_id,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update notification")
    bump_content_version()
    return {"ok": True}


@app.delete("/api/admin/notifications/{notification_id}")
def admin_delete_notification(
    notification_id: int,
    _: dict[str, Any] = Depends(require_admin),
):
    _, affected = execute_write("DELETE FROM notifications WHERE id=%s", (notification_id,))
    if affected == 0:
        raise HTTPException(status_code=404, detail="Notification not found")
    bump_content_version()
    return {"ok": True}


@app.get("/api/admin/menu-items")
def admin_get_menu_items(_: dict[str, Any] = Depends(require_admin)):
    rows = fetch_all(
        "SELECT id, section_name, section_order, label, icon_name, route_name, sort_order FROM menu_items ORDER BY section_order, sort_order, id"
    )
    return {"items": rows}


@app.post("/api/admin/menu-items")
def admin_create_menu_item(
    payload: AdminMenuItemCreateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    row_id, _ = execute_write(
        """
        INSERT INTO menu_items (section_name, section_order, label, icon_name, route_name, sort_order)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (
            payload.section_name,
            payload.section_order,
            payload.label,
            payload.icon_name,
            payload.route_name,
            payload.sort_order,
        ),
    )
    bump_content_version()
    return {"ok": True, "id": row_id}


@app.put("/api/admin/menu-items/{menu_item_id}")
def admin_update_menu_item(
    menu_item_id: int,
    payload: AdminMenuItemUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    rows = fetch_all("SELECT * FROM menu_items WHERE id=%s", (menu_item_id,))
    if not rows:
        raise HTTPException(status_code=404, detail="Menu item not found")

    current = rows[0]
    _, affected = execute_write(
        """
        UPDATE menu_items
        SET section_name=%s, section_order=%s, label=%s, icon_name=%s, route_name=%s, sort_order=%s
        WHERE id=%s
        """,
        (
            payload.section_name or current["section_name"],
            payload.section_order if payload.section_order is not None else current["section_order"],
            payload.label or current["label"],
            payload.icon_name or current["icon_name"],
            payload.route_name or current["route_name"],
            payload.sort_order if payload.sort_order is not None else current["sort_order"],
            menu_item_id,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update menu item")
    bump_content_version()
    return {"ok": True}


@app.delete("/api/admin/menu-items/{menu_item_id}")
def admin_delete_menu_item(
    menu_item_id: int,
    _: dict[str, Any] = Depends(require_admin),
):
    _, affected = execute_write("DELETE FROM menu_items WHERE id=%s", (menu_item_id,))
    if affected == 0:
        raise HTTPException(status_code=404, detail="Menu item not found")
    bump_content_version()
    return {"ok": True}


@app.get("/api/admin/write-screen")
def admin_get_write_screen(_: dict[str, Any] = Depends(require_admin)):
    rows = fetch_all(
        "SELECT id, manage_tabs, story_tabs, filter_label, sort_label, empty_title, empty_cta FROM write_screen ORDER BY id ASC LIMIT 1"
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Write screen config not found")
    return rows[0]


@app.put("/api/admin/write-screen")
def admin_update_write_screen(
    payload: AdminWriteScreenUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    rows = fetch_all("SELECT id FROM write_screen ORDER BY id ASC LIMIT 1")
    if not rows:
        execute_write(
            """
            INSERT INTO write_screen (manage_tabs, story_tabs, filter_label, sort_label, empty_title, empty_cta)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (
                payload.manage_tabs,
                payload.story_tabs,
                payload.filter_label,
                payload.sort_label,
                payload.empty_title,
                payload.empty_cta,
            ),
        )
        bump_content_version()
        return {"ok": True}

    _, affected = execute_write(
        """
        UPDATE write_screen
        SET manage_tabs=%s, story_tabs=%s, filter_label=%s, sort_label=%s, empty_title=%s, empty_cta=%s
        WHERE id=%s
        """,
        (
            payload.manage_tabs,
            payload.story_tabs,
            payload.filter_label,
            payload.sort_label,
            payload.empty_title,
            payload.empty_cta,
            rows[0]["id"],
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update write screen config")
    bump_content_version()
    return {"ok": True}


@app.get("/api/admin/profile")
def admin_get_profile(_: dict[str, Any] = Depends(require_admin)):
    rows = fetch_all(
        "SELECT id, display_name, username, following, followers, blocked, chapters_read, social_karma, day_streak FROM profiles ORDER BY id ASC LIMIT 1"
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Profile not found")
    return rows[0]


@app.put("/api/admin/profile")
def admin_update_profile(
    payload: AdminProfileUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    rows = fetch_all("SELECT id FROM profiles ORDER BY id ASC LIMIT 1")
    if not rows:
        execute_write(
            """
            INSERT INTO profiles (display_name, username, following, followers, blocked, chapters_read, social_karma, day_streak)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                payload.display_name,
                payload.username,
                payload.following,
                payload.followers,
                payload.blocked,
                payload.chapters_read,
                payload.social_karma,
                payload.day_streak,
            ),
        )
        bump_content_version()
        return {"ok": True}

    _, affected = execute_write(
        """
        UPDATE profiles
        SET display_name=%s, username=%s, following=%s, followers=%s, blocked=%s,
            chapters_read=%s, social_karma=%s, day_streak=%s
        WHERE id=%s
        """,
        (
            payload.display_name,
            payload.username,
            payload.following,
            payload.followers,
            payload.blocked,
            payload.chapters_read,
            payload.social_karma,
            payload.day_streak,
            rows[0]["id"],
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update profile")
    bump_content_version()
    return {"ok": True}


@app.get("/api/admin/reading-lists")
def admin_get_reading_lists(_: dict[str, Any] = Depends(require_admin)):
    rows = fetch_all(
        "SELECT id, profile_id, name, story_count, cover_path, sort_order FROM reading_lists ORDER BY sort_order, id"
    )
    return {"items": rows}


@app.post("/api/admin/reading-lists")
def admin_create_reading_list(
    payload: AdminReadingListCreateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    row_id, _ = execute_write(
        """
        INSERT INTO reading_lists (profile_id, name, story_count, cover_path, sort_order)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (
            payload.profile_id,
            payload.name,
            payload.story_count,
            payload.cover_path,
            payload.sort_order,
        ),
    )
    bump_content_version()
    return {"ok": True, "id": row_id}


@app.put("/api/admin/reading-lists/{list_id}")
def admin_update_reading_list(
    list_id: int,
    payload: AdminReadingListUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    rows = fetch_all("SELECT * FROM reading_lists WHERE id=%s", (list_id,))
    if not rows:
        raise HTTPException(status_code=404, detail="Reading list not found")

    current = rows[0]
    _, affected = execute_write(
        """
        UPDATE reading_lists
        SET profile_id=%s, name=%s, story_count=%s, cover_path=%s, sort_order=%s
        WHERE id=%s
        """,
        (
            payload.profile_id if payload.profile_id is not None else current["profile_id"],
            payload.name or current["name"],
            payload.story_count if payload.story_count is not None else current["story_count"],
            payload.cover_path if payload.cover_path is not None else current["cover_path"],
            payload.sort_order if payload.sort_order is not None else current["sort_order"],
            list_id,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update reading list")
    bump_content_version()
    return {"ok": True}


@app.delete("/api/admin/reading-lists/{list_id}")
def admin_delete_reading_list(
    list_id: int,
    _: dict[str, Any] = Depends(require_admin),
):
    _, affected = execute_write("DELETE FROM reading_lists WHERE id=%s", (list_id,))
    if affected == 0:
        raise HTTPException(status_code=404, detail="Reading list not found")
    bump_content_version()
    return {"ok": True}


@app.get("/api/admin/achievements")
def admin_get_achievements(_: dict[str, Any] = Depends(require_admin)):
    rows = fetch_all(
        "SELECT id, group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order FROM achievements ORDER BY group_order, sort_order, id"
    )
    return {"items": rows}


@app.post("/api/admin/achievements")
def admin_create_achievement(
    payload: AdminAchievementCreateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    row_id, _ = execute_write(
        """
        INSERT INTO achievements (group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            payload.group_name,
            payload.group_order,
            payload.title,
            payload.subtitle,
            payload.progress_label,
            payload.badge_value,
            payload.style,
            payload.sort_order,
        ),
    )
    bump_content_version()
    return {"ok": True, "id": row_id}


@app.put("/api/admin/achievements/{achievement_id}")
def admin_update_achievement(
    achievement_id: int,
    payload: AdminAchievementUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    rows = fetch_all("SELECT * FROM achievements WHERE id=%s", (achievement_id,))
    if not rows:
        raise HTTPException(status_code=404, detail="Achievement not found")

    current = rows[0]
    _, affected = execute_write(
        """
        UPDATE achievements
        SET group_name=%s, group_order=%s, title=%s, subtitle=%s,
            progress_label=%s, badge_value=%s, style=%s, sort_order=%s
        WHERE id=%s
        """,
        (
            payload.group_name or current["group_name"],
            payload.group_order if payload.group_order is not None else current["group_order"],
            payload.title or current["title"],
            payload.subtitle or current["subtitle"],
            payload.progress_label or current["progress_label"],
            payload.badge_value or current["badge_value"],
            payload.style or current["style"],
            payload.sort_order if payload.sort_order is not None else current["sort_order"],
            achievement_id,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update achievement")
    bump_content_version()
    return {"ok": True}


@app.delete("/api/admin/achievements/{achievement_id}")
def admin_delete_achievement(
    achievement_id: int,
    _: dict[str, Any] = Depends(require_admin),
):
    _, affected = execute_write("DELETE FROM achievements WHERE id=%s", (achievement_id,))
    if affected == 0:
        raise HTTPException(status_code=404, detail="Achievement not found")
    bump_content_version()
    return {"ok": True}
