"""Step 3 - Run every SELECT in sql/03..07 and save the results.
Output: outputs/query_results/<file>__<query-title>.csv  +  outputs/insights_summary.md
The summary file contains the REAL numbers from your database - copy findings from here
into reports/business_report.md. Never type numbers from memory.
Run: python src/03_run_analysis_queries.py"""
import re
import pandas as pd
from sqlalchemy import text
from config import get_engine, SQL_DIR, OUTPUT_DIR

FILES = ["03_revenue_analysis", "04_customer_behaviour", "05_rfm_segmentation",
         "06_cohort_retention", "07_funnel_analysis"]
RES_DIR = OUTPUT_DIR / "query_results"
RES_DIR.mkdir(parents=True, exist_ok=True)


def split_statements(sql: str):
    """Yield (title, statement). Title = the nearest preceding '-- Qn.' style comment."""
    title, buf = "", []
    for line in sql.splitlines():
        s = line.strip()
        if s.startswith("--"):
            if not buf and re.match(r"--\s*(Q\d+|Segment|Sanity)", s):
                title = s.lstrip("- ").strip()
            continue
        if not s and not buf:
            continue
        buf.append(line)
        if s.endswith(";"):
            yield title, "\n".join(buf)
            title, buf = "", []


engine = get_engine()
md = ["# Insights summary (auto-generated from the database)\n"]
with engine.connect() as conn:
    conn.exec_driver_sql("SET search_path TO olist")   # the SET lines inside the .sql files are skipped here
    for f in FILES:
        md.append(f"\n## {f}\n")
        for i, (title, stmt) in enumerate(split_statements((SQL_DIR / f"{f}.sql").read_text()), 1):
            head = stmt.lstrip().upper()
            if not head.startswith(("SELECT", "WITH")):
                continue                                   # skip SET / CREATE VIEW
            df = pd.read_sql(text(stmt), conn)
            name = re.sub(r"[^a-z0-9]+", "_", (title or f"query_{i}").lower())[:60].strip("_")
            df.to_csv(RES_DIR / f"{f}__{name}.csv", index=False)
            md.append(f"\n### {title or 'Query ' + str(i)}\n")
            md.append(df.head(25).to_markdown(index=False))
            print(f"ok  {f} :: {title or i}  ({len(df)} rows)")

(OUTPUT_DIR / "insights_summary.md").write_text("\n".join(md), encoding="utf-8")
print("\nwrote outputs/insights_summary.md")
