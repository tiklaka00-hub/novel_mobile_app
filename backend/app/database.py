import os
from pathlib import Path
from uuid import uuid4

import mysql.connector
from dotenv import load_dotenv

# Load .env.local first (local dev environment), then fall back to .env
_BACKEND_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(_BACKEND_ROOT / ".env.local", override=False)
load_dotenv(_BACKEND_ROOT / ".env", override=False)

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

SEED_CATEGORIES = [
    ("Editor's Picks", 0, "discover", 5),
    ("Rising", 0, "discover", 6),
    ("Popular", 0, "discover", 7),
    ("Fanfaction", 0, "discover", 8),
    ("Activity", 0, "discover", 9),
    ("Drama", 28, "explore", 15),
    ("Romance", 41, "explore", 16),
    ("Paranormal", 19, "explore", 17),
    ("Fantasy", 36, "explore", 18),
    ("Sci-Fi", 22, "explore", 19),
    ("Adventure", 18, "explore", 20),
    ("Action", 17, "explore", 21),
    ("Young Adult", 26, "explore", 22),
    ("Horror", 13, "explore", 23),
    ("LGBTQ+", 11, "explore", 24),
    ("Erotica", 8, "explore", 25),
]

SEED_BOOKS = [
    (
        "River (Revised version)",
        "Lola Grant",
        "A revised edition prepared for publication with deeper character arcs.",
        "story_card_images/c1a4b2d2-7ba9-44ea-9ea9-81873119a8ec.jpg",
        "#8DB7C8",
        "recently_updated",
        "2hr ago",
        4.5,
        "Historical Fiction",
        "Drama",
        "Read now",
        20,
        0,
    ),
    (
        "Misery's Chosen",
        "I. Falon",
        "Mico faces a shadowed figure with glowing eyes on a stormy night.",
        "story_card_images/cf12c459-4fe5-4725-8ca0-01f42b898d21.jpg",
        "#4A4A62",
        "recently_completed",
        "Completed",
        4.8,
        "Horror",
        "Mystery",
        "Read now",
        21,
        1,
    ),
    (
        "Goddess Tamer",
        "Ari Nova",
        "A reborn hero must tame a dangerous goddess and survive a hostile realm.",
        "story_card_images/d1a0655f-892d-4603-919f-92cdf779dae7.jpg",
        "#7F74C1",
        "recently_completed",
        "Completed",
        4.9,
        "Adventure",
        "Fantasy",
        "Read now",
        22,
        1,
    ),
    (
        "Avengard: The Fall of Senvia",
        "R. Den",
        "Two survivors chase a stolen voice across a drowned empire.",
        "story_card_images/d7728b65-7fcc-45cc-bfb2-38a47dfea216.jpg",
        "#6A8DB5",
        "recently_updated",
        "1yr ago",
        4.3,
        "Fantasy",
        "Romance",
        "Read now",
        23,
        0,
    ),
    (
        "Diary Of Nobody",
        "K. Haze",
        "A quiet diary that reveals pages no one was meant to read.",
        "story_card_images/d55997d3-bc48-43a1-a42e-d004598104d0.jpg",
        "#7D6A5A",
        "recently_updated",
        "1m ago",
        4.1,
        "Poetry",
        "Drama",
        "Read now",
        24,
        0,
    ),
    (
        "Demon King Leveling System",
        "J. Ard",
        "A trapped student awakens a leveling system to survive the abyss.",
        "story_card_images/dc335f4a-9cf3-498d-8c27-5addd0cb15cf.jpg",
        "#3F6FA0",
        "recently_updated",
        "5m ago",
        4.7,
        "Fantasy",
        "Action",
        "Read now",
        25,
        0,
    ),
    (
        "The Boy with the Checkered Scarf",
        "M. Wren",
        "A mythic tale where one scarf links three broken timelines.",
        "story_card_images/dc499710-91bd-4dae-8d0c-145faa5345e2.jpg",
        "#7C6D6A",
        "recently_updated",
        "10m ago",
        4.4,
        "Poetry",
        "Literary Fiction",
        "Read now",
        26,
        0,
    ),
    (
        "The Mnemonivores",
        "Liora Fane",
        "Creatures that feed on memories stalk a city after sunset.",
        "story_card_images/de52e8d5-1a1c-43b2-8752-70582d3e6c94.jpg",
        "#51406A",
        "recently_updated",
        "7m ago",
        4.6,
        "Paranormal",
        "Urban Fantasy",
        "Read now",
        27,
        0,
    ),
    (
        "Gaming Cube Adventures",
        "E. Barrett",
        "A failed streamer logs into a game that refuses to let him leave.",
        "story_card_images/e65f5659-9564-4623-b4c6-a5c37cb4aa5e.jpg",
        "#5875A3",
        "recently_updated",
        "2wk ago",
        4.2,
        "Action",
        "Fantasy",
        "Read now",
        28,
        0,
    ),
    (
        "The Apex Transfer",
        "Elena Torres",
        "An invisible outlier discovers she carries royal wolf blood.",
        "story_card_images/fdc309b2-20b4-4966-8293-9db4532dd8e3.jpg",
        "#7B5D56",
        "recently_completed",
        "Completed",
        5.0,
        "Fantasy",
        "Paranormal",
        "Read now",
        29,
        1,
    ),
]


def _split_sql_statements(sql_content: str) -> list[str]:
    statements: list[str] = []
    current: list[str] = []
    in_string = False
    string_char = ""

    for index, char in enumerate(sql_content):
        if char in ('"', "'") and (index == 0 or sql_content[index - 1] != "\\"):
            if not in_string:
                in_string = True
                string_char = char
            elif char == string_char:
                in_string = False

        if char == ";" and not in_string:
            statement = "".join(current).strip()
            if statement and not statement.startswith("--"):
                statements.append(statement)
            current = []
        else:
            current.append(char)

    return statements


def _ensure_database_exists() -> None:
    """Create the target database if it does not exist yet."""
    ssl_disabled = os.getenv("MYSQL_SSL_DISABLED", "false").lower() == "true"
    db_name = os.getenv("MYSQL_DATABASE", "novel_app_db")
    try:
        connection = mysql.connector.connect(
            host=os.getenv("MYSQL_HOST", "127.0.0.1"),
            port=int(os.getenv("MYSQL_PORT", "3306")),
            user=os.getenv("MYSQL_USER", "root"),
            password=os.getenv("MYSQL_PASSWORD", ""),
            ssl_disabled=ssl_disabled,
            use_pure=True,
        )
        cursor = connection.cursor()
        cursor.execute(
            f"CREATE DATABASE IF NOT EXISTS `{db_name}` "
            "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
        )
        connection.commit()
        cursor.close()
        connection.close()
    except mysql.connector.Error as exc:
        # If we cannot even connect without a database, re-raise.
        raise exc


def initialize_database_if_needed() -> bool:
    """Initialize schema/seed data on startup when required tables are missing."""
    init_sql = os.getenv("MYSQL_INIT_SQL", "setup_railway.sql")
    sql_path = Path(__file__).resolve().parents[1] / "sql" / init_sql

    if not sql_path.exists():
        raise FileNotFoundError(f"Init SQL file not found: {sql_path}")

    _ensure_database_exists()

    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute("SHOW TABLES")
    existing_tables = {row[0] for row in cursor.fetchall()}

    if REQUIRED_TABLES.issubset(existing_tables):
        cursor.close()
        connection.close()
        return False

    sql_content = sql_path.read_text(encoding="utf-8")
    statements = _split_sql_statements(sql_content)

    cursor.execute("SET FOREIGN_KEY_CHECKS=0")

    for statement in statements:
        try:
            cursor.execute(statement)
        except mysql.connector.Error as exc:
            # Ignore idempotent creation/seed issues to support partial environments.
            if exc.errno not in (1050, 1062):
                cursor.execute("SET FOREIGN_KEY_CHECKS=1")
                connection.rollback()
                cursor.close()
                connection.close()
                raise

    cursor.execute("SET FOREIGN_KEY_CHECKS=1")
    connection.commit()
    cursor.close()
    connection.close()
    return True


def run_startup_migrations() -> dict[str, int]:
    """Apply lightweight, idempotent migrations and baseline seed content."""
    connection = get_connection()
    cursor = connection.cursor()

    result = {
        "columns_added": 0,
        "tables_added": 0,
        "categories_added": 0,
        "books_added": 0,
        "assets_seeded": 0,
    }

    uploads_dir = Path(os.getenv("UPLOAD_DIR", "./uploads")).resolve()
    uploads_dir.mkdir(parents=True, exist_ok=True)

    cursor.execute("SHOW TABLES LIKE 'app_metadata'")
    if cursor.fetchone() is None:
        cursor.execute(
            """
            CREATE TABLE app_metadata (
                key_name VARCHAR(100) PRIMARY KEY,
                key_value TEXT NOT NULL,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
            """
        )
        result["tables_added"] += 1

    cursor.execute(
        """
        INSERT INTO app_metadata (key_name, key_value)
        VALUES ('content_version', %s)
        ON DUPLICATE KEY UPDATE key_value = key_value
        """,
        (str(uuid4()),),
    )

    cursor.execute("SHOW TABLES LIKE 'chapters'")
    if cursor.fetchone() is None:
        cursor.execute(
            """
            CREATE TABLE chapters (
                id INT AUTO_INCREMENT PRIMARY KEY,
                story_id INT NOT NULL,
                chapter_number INT NOT NULL DEFAULT 1,
                title VARCHAR(255) NOT NULL,
                content LONGTEXT NOT NULL,
                sort_order INT NOT NULL DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                CONSTRAINT fk_chapter_story FOREIGN KEY (story_id) REFERENCES books(id) ON DELETE CASCADE
            )
            """
        )
        result["tables_added"] += 1

    cursor.execute("SHOW COLUMNS FROM chapters LIKE 'notes'")
    if cursor.fetchone() is None:
        cursor.execute("ALTER TABLE chapters ADD COLUMN notes TEXT NULL AFTER content")
        result["columns_added"] += 1

    cursor.execute("SHOW COLUMNS FROM chapters LIKE 'submission_status'")
    if cursor.fetchone() is None:
        cursor.execute(
            "ALTER TABLE chapters ADD COLUMN submission_status VARCHAR(40) NOT NULL DEFAULT 'draft' AFTER notes"
        )
        result["columns_added"] += 1

    cursor.execute("SHOW COLUMNS FROM chapters LIKE 'scheduled_for'")
    if cursor.fetchone() is None:
        cursor.execute("ALTER TABLE chapters ADD COLUMN scheduled_for DATETIME NULL AFTER submission_status")
        result["columns_added"] += 1

    cursor.execute("SHOW TABLES LIKE 'chapter_revisions'")
    if cursor.fetchone() is None:
        cursor.execute(
            """
            CREATE TABLE chapter_revisions (
                id INT AUTO_INCREMENT PRIMARY KEY,
                chapter_id INT NOT NULL,
                title VARCHAR(255) NOT NULL,
                content LONGTEXT NOT NULL,
                notes TEXT NULL,
                submission_status VARCHAR(40) NOT NULL DEFAULT 'draft',
                scheduled_for DATETIME NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT fk_revision_chapter FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE
            )
            """
        )
        result["tables_added"] += 1

    cursor.execute("SHOW TABLES LIKE 'support_requests'")
    if cursor.fetchone() is None:
        cursor.execute(
            """
            CREATE TABLE support_requests (
                id INT AUTO_INCREMENT PRIMARY KEY,
                email VARCHAR(255) NOT NULL,
                first_name VARCHAR(120) NOT NULL,
                issue VARCHAR(120) NOT NULL,
                subject VARCHAR(255) NOT NULL,
                description TEXT NOT NULL,
                device_type VARCHAR(120) NOT NULL DEFAULT '',
                attachment_path TEXT NULL,
                status VARCHAR(40) NOT NULL DEFAULT 'open',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
            """
        )
        result["tables_added"] += 1

    cursor.execute("SHOW TABLES LIKE 'app_users'")
    if cursor.fetchone() is None:
        cursor.execute(
            """
            CREATE TABLE app_users (
                id INT AUTO_INCREMENT PRIMARY KEY,
                email VARCHAR(255) NOT NULL UNIQUE,
                provider VARCHAR(40) NOT NULL DEFAULT 'google',
                provider_subject VARCHAR(255) NULL,
                display_name VARCHAR(255) NOT NULL,
                photo_url TEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                last_login_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        result["tables_added"] += 1

    # Allow guest/email users without a provider subject (nullable).
    cursor.execute("SHOW COLUMNS FROM app_users LIKE 'provider_subject'")
    if cursor.fetchone() is not None:
        cursor.execute(
            "ALTER TABLE app_users MODIFY provider_subject VARCHAR(255) NULL"
        )
        result["columns_added"] += 1

    # Add user_id to library_entries so each user has their own library.
    cursor.execute("SHOW COLUMNS FROM library_entries LIKE 'user_id'")
    if cursor.fetchone() is None:
        cursor.execute(
            "ALTER TABLE library_entries ADD COLUMN user_id INT NULL AFTER id"
        )
        result["columns_added"] += 1

    # Add user_id to books so writer stories are scoped to the author.
    cursor.execute("SHOW COLUMNS FROM books LIKE 'user_id'")
    if cursor.fetchone() is None:
        cursor.execute("ALTER TABLE books ADD COLUMN user_id INT NULL AFTER id")
        result["columns_added"] += 1

    # Add user_id to reading_lists so lists are per-user.
    cursor.execute("SHOW COLUMNS FROM reading_lists LIKE 'user_id'")
    if cursor.fetchone() is None:
        cursor.execute(
            "ALTER TABLE reading_lists ADD COLUMN user_id INT NULL AFTER id"
        )
        result["columns_added"] += 1

    # Chat history table for the in-app support/contact chat.
    cursor.execute("SHOW TABLES LIKE 'chat_messages'")
    if cursor.fetchone() is None:
        cursor.execute(
            """
            CREATE TABLE chat_messages (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                sender VARCHAR(40) NOT NULL DEFAULT 'user',
                message TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT fk_chat_user FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
            )
            """
        )
        result["tables_added"] += 1

    support_columns = {
        "device_type": "ALTER TABLE support_requests ADD COLUMN device_type VARCHAR(120) NOT NULL DEFAULT ''",
        "attachment_path": "ALTER TABLE support_requests ADD COLUMN attachment_path TEXT NULL",
    }

    for column, alter_sql in support_columns.items():
        cursor.execute(f"SHOW COLUMNS FROM support_requests LIKE '{column}'")
        if cursor.fetchone() is None:
            cursor.execute(alter_sql)
            result["columns_added"] += 1

    book_columns = {
        "primary_genre": "ALTER TABLE books ADD COLUMN primary_genre VARCHAR(80) NOT NULL DEFAULT ''",
        "secondary_genre": "ALTER TABLE books ADD COLUMN secondary_genre VARCHAR(80) NOT NULL DEFAULT ''",
        "is_completed": "ALTER TABLE books ADD COLUMN is_completed TINYINT(1) NOT NULL DEFAULT 0",
    }

    for column, alter_sql in book_columns.items():
        cursor.execute(f"SHOW COLUMNS FROM books LIKE '{column}'")
        if cursor.fetchone() is None:
            cursor.execute(alter_sql)
            result["columns_added"] += 1

    cursor.execute(
        "UPDATE books SET primary_genre = genre WHERE (primary_genre = '' OR primary_genre IS NULL)"
    )
    cursor.execute(
        """
        UPDATE books
        SET cover_path = CONCAT('/uploads/', SUBSTRING_INDEX(cover_path, '/', -1))
        WHERE cover_path LIKE 'story_card_images/%'
        """
    )

    for name, topic_count, tab_group, sort_order in SEED_CATEGORIES:
        cursor.execute(
            "SELECT id FROM categories WHERE name=%s AND tab_group=%s LIMIT 1",
            (name, tab_group),
        )
        if cursor.fetchone() is None:
            cursor.execute(
                "INSERT INTO categories (name, topic_count, tab_group, sort_order) VALUES (%s, %s, %s, %s)",
                (name, topic_count, tab_group, sort_order),
            )
            result["categories_added"] += 1

    for (
        title,
        author,
        description,
        cover_path,
        accent_hex,
        section_name,
        status_text,
        rating,
        primary_genre,
        secondary_genre,
        cta_label,
        sort_order,
        is_completed,
    ) in SEED_BOOKS:
        cursor.execute("SELECT id FROM books WHERE title=%s LIMIT 1", (title,))
        if cursor.fetchone() is None:
            cursor.execute(
                """
                INSERT INTO books (
                    title, author, description, cover_path, accent_hex, section_name, status_text,
                    rating, genre, primary_genre, secondary_genre, cta_label, sort_order, is_completed
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    title,
                    author,
                    description,
                    cover_path,
                    accent_hex,
                    section_name,
                    status_text,
                    rating,
                    primary_genre,
                    primary_genre,
                    secondary_genre,
                    cta_label,
                    sort_order,
                    is_completed,
                ),
            )
            result["books_added"] += 1

    static_story_dir = Path(__file__).resolve().parents[2] / "story_card_images"
    if static_story_dir.exists():
        for image_path in sorted(static_story_dir.glob("*")):
            if not image_path.is_file():
                continue
            extension = image_path.suffix.lower()
            if extension not in {".jpg", ".jpeg", ".png", ".webp"}:
                continue

            target_path = uploads_dir / image_path.name
            if target_path.exists():
                continue

            target_path.write_bytes(image_path.read_bytes())
            result["assets_seeded"] += 1

    connection.commit()
    cursor.close()
    connection.close()
    return result


def get_connection():
    # Use SSL by default for cloud MySQL (Railway uses caching_sha2_password over secure transport).
    # Set MYSQL_SSL_DISABLED=true only for local/non-SSL setups.
    ssl_disabled = os.getenv("MYSQL_SSL_DISABLED", "false").lower() == "true"
    return mysql.connector.connect(
        host=os.getenv("MYSQL_HOST", "127.0.0.1"),
        port=int(os.getenv("MYSQL_PORT", "3306")),
        user=os.getenv("MYSQL_USER", "root"),
        password=os.getenv("MYSQL_PASSWORD", ""),
        database=os.getenv("MYSQL_DATABASE", "novel_app_db"),
        ssl_disabled=ssl_disabled,
        # Use the pure-Python implementation. The bundled C extension
        # (_mysql_connector.cp313-win_amd64.pyd) crashes with an access
        # violation (0xC0000005) on this machine.
        use_pure=True,
    )
