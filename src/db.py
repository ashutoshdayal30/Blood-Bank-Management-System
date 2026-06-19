import os
from contextlib import contextmanager

import pandas as pd
import psycopg2
from dotenv import load_dotenv


load_dotenv()


def database_config() -> dict:
    return {
        "host": os.getenv("DB_HOST", "localhost"),
        "port": int(os.getenv("DB_PORT", "5432")),
        "dbname": os.getenv("DB_NAME", "blood_bank_db"),
        "user": os.getenv("DB_USER", "blood_bank_user"),
        "password": os.getenv("DB_PASSWORD", "blood_bank_password"),
    }


@contextmanager
def get_connection():
    conn = psycopg2.connect(**database_config())
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def query_df(sql: str, params=None) -> pd.DataFrame:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            columns = [description[0] for description in cur.description]
            rows = cur.fetchall()

    return pd.DataFrame(rows, columns=columns)


def execute(sql: str, params=None):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
