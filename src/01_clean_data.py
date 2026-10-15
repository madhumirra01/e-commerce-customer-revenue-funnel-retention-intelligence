"""Step 1 - Clean + validate the raw Olist CSVs.

Input : data/raw/*.csv
Output: data/processed/*.csv (analysis-ready) and outputs/data_quality_report.csv
Run   : python src/01_clean_data.py

Principle: every check is COUNTED and LOGGED, nothing is dropped silently. The report is
evidence of data-quality work you can show a recruiter.
"""
import pandas as pd
from config import RAW_DIR, PROCESSED_DIR, OUTPUT_DIR

PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

dq = []  # data-quality log


def log(table, check, n, action):
    dq.append({"table": table, "check": check, "rows_affected": int(n), "action": action})


def read(name):
    # dtype=str keeps leading zeros in zip codes and prevents wrong auto-typing
    return pd.read_csv(RAW_DIR / name, dtype=str, keep_default_na=True)


def drop_dups(df, subset, table):
    n = df.duplicated(subset=subset).sum()
    log(table, f"duplicate rows on {subset}", n, "dropped (kept first)" if n else "none found")
    return df.drop_duplicates(subset=subset, keep="first")


def drop_orphans(df, col, valid_ids, table, parent):
    mask = ~df[col].isin(valid_ids)
    log(table, f"{col} not found in {parent}", mask.sum(), "dropped" if mask.sum() else "none found")
    return df[~mask]


# ---------------------------------------------------------------- customers
customers = read("olist_customers_dataset.csv")
log("customers", "raw rows", len(customers), "info")
customers = drop_dups(customers, ["customer_id"], "customers")
customers["customer_zip_code_prefix"] = customers["customer_zip_code_prefix"].str.zfill(5)
customers["customer_city"] = customers["customer_city"].str.strip().str.lower()
customers["customer_state"] = customers["customer_state"].str.strip().str.upper()
log("customers", "unique customers (customer_unique_id) vs customer_id rows",
    customers["customer_id"].nunique() - customers["customer_unique_id"].nunique(),
    "info: customer_id is per-ORDER; customer_unique_id is the real person")

# ---------------------------------------------------------------- sellers
sellers = read("olist_sellers_dataset.csv")
sellers = drop_dups(sellers, ["seller_id"], "sellers")
sellers["seller_zip_code_prefix"] = sellers["seller_zip_code_prefix"].str.zfill(5)
sellers["seller_city"] = sellers["seller_city"].str.strip().str.lower()
sellers["seller_state"] = sellers["seller_state"].str.strip().str.upper()

# ---------------------------------------------------------------- products (+ English category)
products = read("olist_products_dataset.csv")
products = products.rename(columns={
    "product_name_lenght": "product_name_length",          # typo in source
    "product_description_lenght": "product_description_length",
})
products = drop_dups(products, ["product_id"], "products")
num_cols = ["product_name_length", "product_description_length", "product_photos_qty",
            "product_weight_g", "product_length_cm", "product_height_cm", "product_width_cm"]
for c in num_cols:
    products[c] = pd.to_numeric(products[c], errors="coerce")
log("products", "missing product_category_name", products["product_category_name"].isna().sum(),
    "filled with 'unknown'")
products["product_category_name"] = products["product_category_name"].fillna("unknown")

trans = read("product_category_name_translation.csv")
products = products.merge(trans, on="product_category_name", how="left")
no_tr = products["product_category_name_english"].isna() & (products["product_category_name"] != "unknown")
log("products", "category has no English translation", no_tr.sum(),
    "fell back to Portuguese name")
products["product_category_name_english"] = (
    products["product_category_name_english"].fillna(products["product_category_name"]))
for c in ["product_weight_g", "product_length_cm", "product_height_cm", "product_width_cm"]:
    log("products", f"missing {c}", products[c].isna().sum(), "left NULL (not imputed)")

# ---------------------------------------------------------------- orders
orders = read("olist_orders_dataset.csv")
log("orders", "raw rows", len(orders), "info")
orders = drop_dups(orders, ["order_id"], "orders")
ts_cols = ["order_purchase_timestamp", "order_approved_at", "order_delivered_carrier_date",
           "order_delivered_customer_date", "order_estimated_delivery_date"]
for c in ts_cols:
    orders[c] = pd.to_datetime(orders[c], errors="coerce")
orders = drop_orphans(orders, "customer_id", set(customers["customer_id"]), "orders", "customers")

bad = orders["order_delivered_customer_date"] < orders["order_purchase_timestamp"]
log("orders", "delivered BEFORE purchase (impossible)", bad.sum(), "delivered date set to NULL")
orders.loc[bad, "order_delivered_customer_date"] = pd.NaT
m = (orders["order_status"] == "delivered") & orders["order_delivered_customer_date"].isna()
log("orders", "status=delivered but no delivery date", m.sum(), "kept; excluded from delivery-time metrics")
m = (orders["order_status"] != "delivered") & orders["order_delivered_customer_date"].notna()
log("orders", "status<>delivered but has delivery date", m.sum(), "kept; flagged for review")
m = orders["order_approved_at"] < orders["order_purchase_timestamp"]
log("orders", "approved BEFORE purchase", m.sum(), "kept; flagged")
log("orders", "order_status distribution (see value counts)", len(orders), "info: " +
    ", ".join(f"{k}={v}" for k, v in orders["order_status"].value_counts().items()))
log("orders", "purchase date range", len(orders),
    f"info: {orders['order_purchase_timestamp'].min()} to {orders['order_purchase_timestamp'].max()}")
valid_orders = set(orders["order_id"])

# ---------------------------------------------------------------- order_items
items = read("olist_order_items_dataset.csv")
items["order_item_id"] = items["order_item_id"].astype(int)
items["shipping_limit_date"] = pd.to_datetime(items["shipping_limit_date"], errors="coerce")
items["price"] = pd.to_numeric(items["price"], errors="coerce")
items["freight_value"] = pd.to_numeric(items["freight_value"], errors="coerce")
items = drop_dups(items, ["order_id", "order_item_id"], "order_items")
items = drop_orphans(items, "order_id", valid_orders, "order_items", "orders")
items = drop_orphans(items, "product_id", set(products["product_id"]), "order_items", "products")
items = drop_orphans(items, "seller_id", set(sellers["seller_id"]), "order_items", "sellers")
log("order_items", "price <= 0", (items["price"] <= 0).sum(), "kept; flagged")
log("order_items", "null price or freight", items[["price", "freight_value"]].isna().any(axis=1).sum(), "kept; flagged")

# ---------------------------------------------------------------- payments
pay = read("olist_order_payments_dataset.csv")
pay["payment_sequential"] = pay["payment_sequential"].astype(int)
pay["payment_installments"] = pay["payment_installments"].astype(int)
pay["payment_value"] = pd.to_numeric(pay["payment_value"], errors="coerce")
pay = drop_dups(pay, ["order_id", "payment_sequential"], "order_payments")
pay = drop_orphans(pay, "order_id", valid_orders, "order_payments", "orders")
log("order_payments", "payment_type = not_defined", (pay["payment_type"] == "not_defined").sum(), "kept; flagged")
log("order_payments", "payment_value = 0", (pay["payment_value"] == 0).sum(), "kept; flagged")
log("order_payments", "payment_installments = 0", (pay["payment_installments"] == 0).sum(), "kept; flagged")

# ---------------------------------------------------------------- reviews
rev = read("olist_order_reviews_dataset.csv")
log("order_reviews", "raw rows", len(rev), "info")
rev["review_score"] = pd.to_numeric(rev["review_score"], errors="coerce")
rev["review_creation_date"] = pd.to_datetime(rev["review_creation_date"], errors="coerce")
rev["review_answer_timestamp"] = pd.to_datetime(rev["review_answer_timestamp"], errors="coerce")
dup_id = rev["review_id"].duplicated().sum()
log("order_reviews", "review_id repeated across rows (not a unique key in source)", dup_id,
    "composite key (review_id, order_id) used instead")
rev["has_comment"] = rev["review_comment_message"].notna()
rev = rev.sort_values("review_answer_timestamp").drop_duplicates(["review_id", "order_id"], keep="last")
rev = drop_orphans(rev, "order_id", valid_orders, "order_reviews", "orders")
log("order_reviews", "review_score outside 1-5", (~rev["review_score"].between(1, 5)).sum(), "dropped")
rev = rev[rev["review_score"].between(1, 5)]
rev["review_score"] = rev["review_score"].astype(int)
rev = rev[["review_id", "order_id", "review_score", "has_comment",
           "review_creation_date", "review_answer_timestamp"]]   # free-text dropped: not needed, keeps DB lean
multi = rev.groupby("order_id").size().gt(1).sum()
log("order_reviews", "orders with more than one review", multi, "kept; SQL averages per order")

# ---------------------------------------------------------------- cross-table reconciliation
no_items = len(valid_orders - set(items["order_id"]))
log("cross-table", "orders with zero order_items", no_items, "kept; excluded from revenue (LEFT JOIN)")
no_pay = len(valid_orders - set(pay["order_id"]))
log("cross-table", "orders with zero payments", no_pay, "kept")
a = items.groupby("order_id").apply(lambda d: (d["price"] + d["freight_value"]).sum(), include_groups=False)
b = pay.groupby("order_id")["payment_value"].sum()
j = pd.concat([a.rename("items_total"), b.rename("paid_total")], axis=1).dropna()
mism = ((j["items_total"] - j["paid_total"]).abs() > 1.0).sum()
log("cross-table", "|items+freight - payments| > 1.00 BRL", mism,
    "info: caused by instalment interest / vouchers; revenue is defined from items, not payments")

# ---------------------------------------------------------------- write outputs
out = {
    "customers": customers, "sellers": sellers, "products": products, "orders": orders,
    "order_items": items, "order_payments": pay, "order_reviews": rev,
}
for name, df in out.items():
    df.to_csv(PROCESSED_DIR / f"{name}.csv", index=False)
    print(f"wrote {name}.csv  ({len(df):,} rows)")

report = pd.DataFrame(dq)
report.to_csv(OUTPUT_DIR / "data_quality_report.csv", index=False)
print("\n=== DATA QUALITY REPORT ===")
print(report.to_string(index=False))
