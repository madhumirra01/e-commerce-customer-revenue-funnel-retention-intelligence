"""Step 0 - confirm the 8 Olist CSVs are in data/raw and print shape + columns.
Run:  python src/00_check_raw_data.py"""
import pandas as pd
from config import RAW_DIR

EXPECTED = [
    "olist_customers_dataset.csv",
    "olist_orders_dataset.csv",
    "olist_order_items_dataset.csv",
    "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset.csv",
    "olist_products_dataset.csv",
    "olist_sellers_dataset.csv",
    "product_category_name_translation.csv",
]

missing = [f for f in EXPECTED if not (RAW_DIR / f).exists()]
if missing:
    raise SystemExit(f"Missing files in {RAW_DIR}:\n  " + "\n  ".join(missing) +
                     "\nDownload from kaggle.com/datasets/olistbr/brazilian-ecommerce and unzip into data/raw/")

for f in EXPECTED:
    df = pd.read_csv(RAW_DIR / f, dtype=str)
    print(f"\n{f}: {df.shape[0]:,} rows x {df.shape[1]} cols")
    print("  columns:", list(df.columns))
print("\nAll files present. (olist_geolocation_dataset.csv is intentionally not used.)")
