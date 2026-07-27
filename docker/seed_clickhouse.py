"""Creates the example events table and fills it once.

A fresh deployment with an empty warehouse gives you nothing to look at, and
"nothing to look at" is indistinguishable from "broken" on the first day.
"""
import os
import re
from urllib.parse import unquote, urlparse

import clickhouse_connect

uri = os.environ["CLICKHOUSE_URI"]
parsed = urlparse(uri)
client = clickhouse_connect.get_client(
    host=parsed.hostname,
    port=parsed.port or 8123,
    username=unquote(parsed.username or "default"),
    password=unquote(parsed.password or ""),
    database="default",
)

statements = [
    s.strip()
    for s in re.split(r";\s*\n", open("/app/init-events.sql").read())
    if s.strip() and not s.strip().startswith("--")
]

for statement in statements:
    client.command(statement)

count = client.query("select count() from analytics.events").result_rows[0][0]
print(f"[bootstrap] analytics.events holds {count} rows")
