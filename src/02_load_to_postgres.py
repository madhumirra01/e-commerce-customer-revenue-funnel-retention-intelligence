"""Step 2 - Create the database (if missing), build the schema, load the cleaned CSVs.
Run: python src/02_load_to_postgres.py
Needs a filled-in .env (copy .env.example) and step 1 already run."""
import pandas as pd
from sqlalchemy import text
from config import get_engine, PROCESSED_DIR, SQL_DIR, DB_NAME

# 1) create the database itself by connecting to the default 'postgres' db
admin = get_engine("postgres").execution_options(isolation_level="AUTOCOMMIT")
with admin.connect() as conn:
    exists = conn.execute(text("SELECT 1 FROM pg_database WHERE datname=:n"), {"n": DB_NAME}).scalar()
    if not exists:
        conn.execute(text(f'CREATE DATABASE "{DB_NAME}"'))
        print(f"created database {DB_NAME}")

engine = get_engine()

# 2) build schema (drops and recreates the 'olist' schema)
def run_sql_file(conn, path):
    """Run a multi-statement .sql file through the raw DBAPI cursor.
    (exec_driver_sql would treat a literal '%' in SQL comments as a parameter marker.)"""
    cur = conn.connection.cursor()
    cur.execute(path.read_text())
    cur.close()


with engine.begin() as conn:
    run_sql_file(conn, SQL_DIR / "01_schema.sql")
print("schema created")

# 3) load in dependency order: parents before children (foreign keys!)
LOAD_ORDER = {
    "customers": [],
    "sellers": [],
    "products": [],
    "orders": ["order_purchase_timestamp", "order_approved_at", "order_delivered_carrier_date",
               "order_delivered_customer_date", "order_estimated_delivery_date"],
    "order_items": ["shipping_limit_date"],
    "order_payments": [],
    "order_reviews": ["review_creation_date", "review_answer_timestamp"],
}
for table, date_cols in LOAD_ORDER.items():
    df = pd.read_csv(PROCESSED_DIR / f"{table}.csv", parse_dates=date_cols,
                     dtype={"customer_zip_code_prefix": str, "seller_zip_code_prefix": str})
    df = df.astype(object).where(df.notna(), None)      # NaN/NaT -> proper SQL NULL
    df.to_sql(table, engine, schema="olist", if_exists="append", index=False,
              method="multi", chunksize=2000)
    print(f"loaded {table:<15} {len(df):>8,} rows")

# 4) verify: row counts in DB must equal CSV rows
print("\nVerification (DB row counts):")
with engine.connect() as conn:
    for table in LOAD_ORDER:
        n = conn.execute(text(f"SELECT COUNT(*) FROM olist.{table}")).scalar()
        print(f"  {table:<15} {n:>8,}")

