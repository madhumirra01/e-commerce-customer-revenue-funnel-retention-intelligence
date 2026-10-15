"""Central config: paths + database connection. Every other script imports from here
so credentials and paths live in exactly one place."""
from pathlib import Path
import os

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.engine import URL

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "data" / "raw"
PROCESSED_DIR = ROOT / "data" / "processed"
SQL_DIR = ROOT / "sql"
OUTPUT_DIR = ROOT / "outputs"
FIG_DIR = OUTPUT_DIR / "figures"

load_dotenv(ROOT / ".env")

DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "olist_analytics")


def db_url(database: str = DB_NAME) -> URL:
    # URL.create safely escapes special characters (@, #, /) in passwords
    return URL.create("postgresql+psycopg2", username=DB_USER, password=DB_PASSWORD,
                      host=DB_HOST, port=DB_PORT, database=database)


def get_engine(database: str = DB_NAME):
    return create_engine(db_url(database))
