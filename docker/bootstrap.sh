#!/bin/bash
# First boot: migrate, create the admin, register the warehouse, then serve.
#
# All of it is idempotent, because this runs on every deploy - not only the
# first one - and a deploy that recreated the admin or duplicated the database
# connection would be worse than one that did nothing.
set -e

echo "[bootstrap] upgrading the metadata database"
superset db upgrade

echo "[bootstrap] ensuring the admin user"
superset fab create-admin \
  --username "${ADMIN_USERNAME:-admin}" \
  --firstname Admin --lastname User \
  --email "${ADMIN_EMAIL:-admin@example.com}" \
  --password "${ADMIN_PASSWORD}" || echo "[bootstrap] admin already exists"

echo "[bootstrap] initialising roles and permissions"
superset init

if [ -n "${CLICKHOUSE_URI:-}" ]; then
  echo "[bootstrap] registering the ClickHouse connection"
  # Registered through Superset's own API so the connection is a first-class
  # database object - visible in the UI, usable in SQL Lab, and updated rather
  # than duplicated when this runs again.
  python <<'PY'
import os

from superset.app import create_app

app = create_app()
with app.app_context():
    from superset import db
    from superset.models.core import Database

    name = os.environ.get("CLICKHOUSE_DATABASE_NAME", "ClickHouse")
    uri = os.environ["CLICKHOUSE_URI"]

    existing = db.session.query(Database).filter_by(database_name=name).one_or_none()
    if existing:
        existing.set_sqlalchemy_uri(uri)
        existing.allow_dml = True
        print(f"[bootstrap] updated the connection {name!r}")
    else:
        database = Database(database_name=name, allow_ctas=True, allow_cvas=True, allow_dml=True)
        database.set_sqlalchemy_uri(uri)
        db.session.add(database)
        print(f"[bootstrap] created the connection {name!r}")
    db.session.commit()
PY
fi

echo "[bootstrap] starting the web server on ${PORT:-8088}"
# 0.0.0.0, not ::. Gunicorn would bind an IPv6 socket exclusively and the
# platform's HTTP proxy, which connects over IPv4, would get a refused
# connection - a 502 with the application running perfectly.
exec gunicorn \
  --bind "0.0.0.0:${PORT:-8088}" \
  --workers "${SUPERSET_WORKERS:-4}" \
  --worker-class gthread \
  --threads 8 \
  --timeout "${SUPERSET_WEBSERVER_TIMEOUT:-120}" \
  --limit-request-line 0 \
  --limit-request-field_size 0 \
  "superset.app:create_app()"
