from pathlib import Path
import sys

import pandas as pd
from psycopg2.extras import execute_values


PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.append(str(PROJECT_ROOT))

from src.db import get_connection

DATA_DIR = PROJECT_ROOT / "data"


def load_csv(file_name: str) -> pd.DataFrame:
    return pd.read_csv(DATA_DIR / file_name)


def reset_tables(cursor) -> None:
    cursor.execute(
        """
        TRUNCATE TABLE
            inventory_logs,
            blood_requests,
            blood_units,
            donations,
            recipients,
            hospitals,
            donors
        RESTART IDENTITY CASCADE;
        """
    )


def reset_sequence(cursor, table_name: str, id_column: str) -> None:
    cursor.execute(
        f"""
        SELECT setval(
            pg_get_serial_sequence('{table_name}', '{id_column}'),
            COALESCE((SELECT MAX({id_column}) FROM {table_name}), 1),
            TRUE
        );
        """
    )


def insert_dataframe(cursor, table_name: str, df: pd.DataFrame) -> None:
    columns = list(df.columns)
    values = [tuple(row) for row in df.to_numpy()]
    column_sql = ", ".join(columns)
    insert_sql = f"INSERT INTO {table_name} ({column_sql}) VALUES %s"
    execute_values(cursor, insert_sql, values)


def seed_blood_units(cursor, df: pd.DataFrame) -> None:
    for row in df.to_dict("records"):
        cursor.execute(
            """
            INSERT INTO donations (donor_id, donation_date, volume_ml, collection_site)
            VALUES (%s, %s, %s, %s)
            RETURNING donation_id;
            """,
            (
                int(row["donor_id"]),
                row["collection_date"],
                int(row["volume_ml"]),
                "Main Blood Center",
            ),
        )
        donation_id = cursor.fetchone()[0]

        cursor.execute(
            """
            INSERT INTO blood_units (
                donation_id,
                unit_code,
                blood_type,
                collection_date,
                expiry_date,
                status,
                storage_location
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING unit_id;
            """,
            (
                donation_id,
                row["unit_code"],
                row["blood_type"],
                row["collection_date"],
                row["expiry_date"],
                row["status"],
                row["storage_location"],
            ),
        )
        unit_id = cursor.fetchone()[0]

        cursor.execute(
            """
            SELECT add_inventory_log(
                %s, NULL, 'added', NULL, %s, 'seed script',
                'Seeded sample blood unit ' || %s
            );
            """,
            (unit_id, row["status"], row["unit_code"]),
        )


def main() -> None:
    donors = load_csv("donors.csv")
    hospitals = load_csv("hospitals.csv")
    recipients = load_csv("recipients.csv")
    blood_units = load_csv("blood_units.csv")
    blood_requests = load_csv("blood_requests.csv")

    with get_connection() as conn:
        with conn.cursor() as cur:
            reset_tables(cur)
            insert_dataframe(cur, "donors", donors)
            insert_dataframe(cur, "hospitals", hospitals)
            insert_dataframe(cur, "recipients", recipients)
            seed_blood_units(cur, blood_units)
            insert_dataframe(cur, "blood_requests", blood_requests)

            reset_sequence(cur, "donors", "donor_id")
            reset_sequence(cur, "hospitals", "hospital_id")
            reset_sequence(cur, "recipients", "recipient_id")
            reset_sequence(cur, "blood_requests", "request_id")

    print("Seed data loaded successfully.")


if __name__ == "__main__":
    main()
