# Superset with a ClickHouse warehouse, for Railway

Apache Superset already connected to a ClickHouse warehouse, with the driver
installed, the connection registered, an admin account created and a table of
example events to point a chart at.

## Why this exists

Superset appears in this catalogue three times: 175 installs at 84%, 154 at
67%, 45 at 0%. ClickHouse has a healthy template of its own — and it is empty,
with no BI in front of it.

Putting the two together is not one step. The official Superset image has **no
ClickHouse driver**, so the connection you want cannot be created at all. It
also needs a metadata database, a secret key, an admin created by CLI, and
`superset init` run before anything works. Miss any of it and you get a login
page you cannot get past.

This template does all of that at first boot, and does it idempotently — a
redeploy does not recreate the admin or duplicate the connection.

## What you get

- **Superset 5.0.0** with `clickhouse-connect` installed.
- **A ClickHouse warehouse**, already registered as a database connection named
  `ClickHouse` — visible in the UI, usable in SQL Lab.
- **An `analytics.events` table** with a few hundred rows, so there is something
  to chart on the first day. It is a shape worth copying: an event stream keyed
  by time, with a low-cardinality name and a JSON blob for the rest.
- **Postgres** for Superset's own metadata and **Redis** for its caches.
- **An admin account** with a generated password.

## After deploying

Open the service URL and sign in with `ADMIN_USERNAME` / `ADMIN_PASSWORD`. Go to
**SQL Lab** and run:

```sql
select event_name, count() as n
from analytics.events
group by event_name
order by n desc
```

Then point your own writers at ClickHouse and replace the example table.

## Prove it works

```bash
scripts/verify-analytics.sh https://your-superset.up.railway.app admin 'the-password'
```

The check that matters is the last one: SQL sent through Superset's API,
executed by ClickHouse, rows coming back. Everything before it — health, the API
refusing anonymous callers, the login, the registered connection — is a
precondition for that one call.

## Decisions worth knowing

- **The drivers go into the image's virtualenv, not the system Python.** The
  Superset image runs from `/app/.venv`, that venv has no `pip` of its own, and a
  plain `pip install` succeeds while leaving the package where nothing will
  import it. The failure surfaces much later as `ModuleNotFoundError` at
  start-up.
- **Bootstrap is idempotent.** It runs on every deploy: `db upgrade`, then
  create-admin (ignored if it exists), then `init`, then update-or-create the
  ClickHouse connection.
- **The metadata database is separate from the warehouse.** Superset writes to
  its metadata constantly, and ClickHouse is not built for that traffic.
- **`ENABLE_PROXY_FIX` is on**, because behind the platform's TLS termination
  Superset would otherwise build `http://` links that a browser on an `https`
  page refuses.
- **Gunicorn binds `0.0.0.0`, not `::`** — an IPv6-only socket is unreachable
  from the platform's HTTP proxy, and the symptom is a 502 while the application
  logs that it is serving.
- **The example rows are inserted from Python, not from SQL.** ClickHouse will
  not read the target table inside an `INSERT ... SELECT`, so an "only if empty"
  guard written in SQL silently inserts nothing.

## Configuration

| Variable | Purpose |
|----------|---------|
| `SUPERSET_SECRET_KEY` | Signs sessions. **Changing it logs everyone out and invalidates saved credentials** |
| `DATABASE_URL` | Postgres for Superset's metadata |
| `REDIS_URL` | Caches; optional, but without it every replica recomputes each chart |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | Created on first boot |
| `CLICKHOUSE_URI` | `clickhousedb://user:password@host:8123/database` |
| `SEED_EXAMPLE_DATA` | `false` to skip the example table |
| `SUPERSET_WORKERS` | Gunicorn workers, default 4 |

## Scaling

Superset itself is stateless — add replicas. Postgres and ClickHouse each hold a
volume, so they scale up rather than out.

For heavy dashboards, add a Celery worker for async queries; the Redis
connection is already configured for it.

## License

Template configuration MIT. Superset is Apache-2.0, ClickHouse is Apache-2.0.
