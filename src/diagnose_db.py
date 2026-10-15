from sqlalchemy import text
from config import get_engine

with get_engine().connect() as c:
    rows = c.execute(text("""
        SELECT pid, state, wait_event_type, wait_event,
               now() - query_start AS running, left(query, 80) AS query
        FROM pg_stat_activity
        WHERE datname = 'olist_analytics' AND pid <> pg_backend_pid()
    """)).fetchall()
    print(f"{len(rows)} other sessions")
    for r in rows:
        print(r)