"""Clears stuck sessions, refreshes table statistics, then creates ONLY the views
(no analysis SELECTs). Safe to re-run."""
import time
from sqlalchemy import text
from config import get_engine, SQL_DIR

engine = get_engine()

# 1. kill leftover sessions from earlier runs
with engine.begin() as c:
    c.execute(text("""SELECT pg_terminate_backend(pid) FROM pg_stat_activity
                      WHERE datname = 'olist_analytics' AND pid <> pg_backend_pid()"""))
print("cleared stuck sessions")

# 2. refresh planner statistics (needed after a bulk load)
with engine.begin() as c:
    c.exec_driver_sql("ANALYZE")
print("analyzed tables")


def view_statements(sql):
    """Yield only SET / CREATE statements, skipping comments and analysis SELECTs."""
    buf = []
    for line in sql.splitlines():
        s = line.strip()
        if s.startswith("--") or (not s and not buf):
            continue
        buf.append(line)
        if s.endswith(";"):
            stmt = "\n".join(buf)
            buf = []
            if stmt.lstrip().upper().startswith(("SET", "CREATE")):
                yield stmt


for f in ["02_views_base.sql", "05_rfm_segmentation.sql", "06_cohort_retention.sql",
          "07_funnel_analysis.sql", "08_powerbi_views.sql"]:
    t = time.time()
    with engine.begin() as conn:
        cur = conn.connection.cursor()
        for stmt in view_statements((SQL_DIR / f).read_text()):
            cur.execute(stmt)
        cur.close()
    print(f"ok  {f}  ({time.time() - t:.1f}s)")
print("views created")