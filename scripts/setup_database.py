from pathlib import Path
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.append(str(PROJECT_ROOT))

from src.db import get_connection
SQL_FILES = [
    PROJECT_ROOT / "database" / "schema.sql",
    PROJECT_ROOT / "database" / "indexes.sql",
    PROJECT_ROOT / "database" / "functions.sql",
    PROJECT_ROOT / "database" / "seed.sql",
]


def run_sql_file(cursor, path: Path) -> None:
    print(f"Running {path.relative_to(PROJECT_ROOT)}")
    sql = path.read_text(encoding="utf-8")
    executable_lines = [
        line for line in sql.splitlines()
        if line.strip() and not line.strip().startswith("--")
    ]
    if not executable_lines:
        print(f"Skipping {path.relative_to(PROJECT_ROOT)} because it has no executable SQL.")
        return

    cursor.execute(sql)


def main() -> None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            for sql_file in SQL_FILES:
                run_sql_file(cur, sql_file)

    print("Database setup finished.")


if __name__ == "__main__":
    main()
