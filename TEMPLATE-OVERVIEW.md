# Deploy and Host Superset with ClickHouse on Railway

Apache Superset already connected to a ClickHouse warehouse: the driver installed, the connection registered, an admin account created, and a table of example events waiting for a chart.

Open the URL, sign in, run a query. Nothing to wire.

## About Hosting Superset with ClickHouse

Superset appears in this catalogue three times — 175 installs at 84%, 154 at 67%, 45 at 0%. ClickHouse has a healthy template of its own, and it is empty: a warehouse with no way to look at it.

Putting the two together is not one step, and the reason is specific: **the official Superset image ships no ClickHouse driver**. The connection you want cannot be created at all until one is installed, and installing it into the right place is its own trap — the image runs from a virtualenv that has no `pip` of its own, so a plain `pip install` succeeds while leaving the package where nothing will import it.

On top of that, Superset needs a metadata database, a secret key, an admin created through the CLI and `superset init` run before anything works. Miss any of it and the result is a login page you cannot get past.

## Common Use Cases

- **Event analytics on your own infrastructure** — page views, signups, purchases — without a per-event bill.
- **A BI front for data you already have in ClickHouse**, with SQL Lab for the questions a dashboard does not answer.
- **Dashboards for a team**, with Superset's roles deciding who sees which data.

## Dependencies for Superset Hosting

### Deployment Dependencies

- [Apache Superset](https://superset.apache.org) 5.0.0 with `clickhouse-connect`
- [ClickHouse](https://clickhouse.com) 26.5.6 — the warehouse
- Postgres — Superset's metadata, deliberately separate from the warehouse
- Redis — chart, filter and form-data caches
- [Template source](https://github.com/ak40u/superset-clickhouse-railway)

### Implementation Details

- **The ClickHouse driver is installed into the image's virtualenv**, not the system Python. This is the single change that makes the pairing possible, and the place it goes is the part that catches people out: the failure from getting it wrong arrives much later, as `ModuleNotFoundError` at start-up.
- **First boot is idempotent and complete**: migrate the metadata database, create the admin if absent, run `superset init`, then update-or-create the ClickHouse connection. A redeploy repeats all of it without duplicating anything.
- **The connection is registered through Superset's own model**, so it is a first-class database object — visible in the UI, usable in SQL Lab, editable afterwards.
- **Metadata and warehouse are separate databases.** Superset writes to its metadata constantly; ClickHouse is not built for that.
- **`ENABLE_PROXY_FIX` is on**, because behind TLS termination Superset would otherwise build `http://` links that the browser refuses on an `https` page.
- **Gunicorn binds `0.0.0.0`, not `::`.** An IPv6-only socket is unreachable from the platform's HTTP proxy, and the symptom is a 502 while the application logs that it is serving happily.
- **The example rows are inserted from Python rather than SQL** — ClickHouse will not read the target table inside an `INSERT ... SELECT`, so an "only if empty" guard written in SQL silently inserts nothing. Discovered by watching a seeded table come up with zero rows.

The repository carries `scripts/verify-analytics.sh`, whose last check is the whole product in one call: SQL sent through Superset's API, executed by ClickHouse, rows coming back. This template was published only after that script passed against a deployment created from the template itself.

## Why Deploy Superset with ClickHouse on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Superset with ClickHouse on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
