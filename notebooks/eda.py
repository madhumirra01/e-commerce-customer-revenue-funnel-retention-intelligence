# %% [markdown]
# # EDA - Olist e-commerce (run cell by cell in VS Code: "Run Cell" above each # %%)
# Reads the CLEANED csvs from data/processed. Figures are saved to outputs/figures/.

# %%
import sys
from pathlib import Path
sys.path.append(str(Path.cwd().parent / "src")) if Path.cwd().name == "notebooks" else sys.path.append("src")
import pandas as pd, numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from config import PROCESSED_DIR, FIG_DIR
FIG_DIR.mkdir(parents=True, exist_ok=True)
sns.set_theme(style="whitegrid", context="notebook")

orders = pd.read_csv(PROCESSED_DIR / "orders.csv", parse_dates=[
    "order_purchase_timestamp", "order_approved_at", "order_delivered_carrier_date",
    "order_delivered_customer_date", "order_estimated_delivery_date"])
items = pd.read_csv(PROCESSED_DIR / "order_items.csv")
pay = pd.read_csv(PROCESSED_DIR / "order_payments.csv")
rev = pd.read_csv(PROCESSED_DIR / "order_reviews.csv")
cust = pd.read_csv(PROCESSED_DIR / "customers.csv", dtype=str)
prod = pd.read_csv(PROCESSED_DIR / "products.csv")

# %% [markdown]
# ## 1. Shape, types, missing values

# %%
for name, df in {"orders": orders, "items": items, "payments": pay, "reviews": rev,
                 "customers": cust, "products": prod}.items():
    print(f"\n{name}: {df.shape}")
    print(df.isna().sum()[df.isna().sum() > 0])

# %% [markdown]
# ## 2. Order status mix

# %%
status = orders["order_status"].value_counts()
ax = status.plot(kind="barh", figsize=(7, 4), color="#2a6f97")
ax.set_title("Orders by status"); ax.invert_yaxis()
plt.tight_layout(); plt.savefig(FIG_DIR / "01_order_status.png", dpi=150); plt.show()

# %% [markdown]
# ## 3. Monthly revenue and orders (valid sales only)

# %%
valid = orders[~orders["order_status"].isin(["canceled", "unavailable"])]
rev_o = items.groupby("order_id")["price"].sum().rename("revenue")
m = valid.join(rev_o, on="order_id")
m["month"] = m["order_purchase_timestamp"].dt.to_period("M").dt.to_timestamp()
monthly = m.groupby("month").agg(orders=("order_id", "count"), revenue=("revenue", "sum"))
fig, ax1 = plt.subplots(figsize=(11, 4.5))
ax1.bar(monthly.index, monthly["revenue"], width=20, color="#8ecae6", label="Revenue")
ax2 = ax1.twinx(); ax2.plot(monthly.index, monthly["orders"], color="#023047", marker="o", label="Orders")
ax1.set_title("Monthly revenue (bars) and orders (line)"); ax1.set_ylabel("Revenue"); ax2.set_ylabel("Orders")
plt.tight_layout(); plt.savefig(FIG_DIR / "02_monthly_revenue_orders.png", dpi=150); plt.show()

# %% [markdown]
# ## 4. Order value distribution (log scale shows the long tail)

# %%
ov = rev_o[rev_o > 0]
fig, ax = plt.subplots(1, 2, figsize=(11, 4))
sns.histplot(ov, bins=60, ax=ax[0], color="#2a6f97"); ax[0].set_title("Order value")
sns.histplot(np.log10(ov), bins=60, ax=ax[1], color="#219ebc"); ax[1].set_title("Order value (log10)")
plt.tight_layout(); plt.savefig(FIG_DIR / "03_order_value_distribution.png", dpi=150); plt.show()
print(ov.describe().round(2))

# %% [markdown]
# ## 5. Top categories by revenue

# %%
ic = items.merge(prod[["product_id", "product_category_name_english"]], on="product_id")
ic = ic[ic["order_id"].isin(valid["order_id"])]
top = ic.groupby("product_category_name_english")["price"].sum().nlargest(10).sort_values()
ax = top.plot(kind="barh", figsize=(8, 5), color="#2a6f97"); ax.set_title("Top 10 categories by revenue")
plt.tight_layout(); plt.savefig(FIG_DIR / "04_top_categories.png", dpi=150); plt.show()

# %% [markdown]
# ## 6. Delivery performance and review scores

# %%
d = orders.dropna(subset=["order_delivered_customer_date"]).copy()
d["delivery_days"] = (d["order_delivered_customer_date"] - d["order_purchase_timestamp"]).dt.days
d["late"] = d["order_delivered_customer_date"] > d["order_estimated_delivery_date"]
r = rev.groupby("order_id")["review_score"].mean().rename("score")
d = d.join(r, on="order_id")
fig, ax = plt.subplots(1, 2, figsize=(11, 4))
sns.histplot(d["delivery_days"].clip(upper=60), bins=40, ax=ax[0], color="#2a6f97"); ax[0].set_title("Delivery days (clipped at 60)")
sns.barplot(data=d.dropna(subset=["score"]), x="late", y="score", ax=ax[1], color="#8ecae6")
ax[1].set_title("Avg review score: on time (False) vs late (True)")
plt.tight_layout(); plt.savefig(FIG_DIR / "05_delivery_vs_reviews.png", dpi=150); plt.show()

# %% [markdown]
# ## 7. Payment types and orders per customer

# %%
fig, ax = plt.subplots(1, 2, figsize=(11, 4))
pay["payment_type"].value_counts().plot(kind="bar", ax=ax[0], color="#2a6f97"); ax[0].set_title("Payment rows by type")
opc = orders[orders["order_status"] == "delivered"].merge(cust[["customer_id", "customer_unique_id"]], on="customer_id")
opc = opc.groupby("customer_unique_id").size().clip(upper=5)
opc.value_counts().sort_index().plot(kind="bar", ax=ax[1], color="#219ebc"); ax[1].set_title("Orders per customer (5 = 5+)")
plt.tight_layout(); plt.savefig(FIG_DIR / "06_payments_and_orders_per_customer.png", dpi=150); plt.show()