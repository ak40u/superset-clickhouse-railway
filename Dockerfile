# Pinned to a release, not a moving tag: Superset publishes dozens of images a
# day and most of them are development builds.
# The -py312 variant: the untagged image still runs Python 3.10, which reaches
# end of life this month.
FROM apache/superset:6.1.0-py312

USER root
# The official image carries no ClickHouse driver, which is the single reason a
# "Superset + ClickHouse" deployment cannot be assembled from stock images.
#
# Installed into the image's virtualenv rather than the system Python, which
# Superset does not use - a plain `pip install` here succeeds and the failure
# arrives later as ModuleNotFoundError at start-up. The venv is built by uv and
# has no pip of its own, so the packages go straight into its site-packages.
# The redis client is not listed: the image already ships the one Superset
# supports (it requires redis<6), and a newer copy here would shadow it.
RUN VENV_SITE="$(ls -d /app/.venv/lib/python*/site-packages)" \
    && pip install --no-cache-dir --target "$VENV_SITE" \
       clickhouse-connect==1.9.0 psycopg2-binary==2.9.13

COPY docker/superset_config.py /app/pythonpath/superset_config.py
COPY docker/bootstrap.sh /app/bootstrap.sh
COPY docker/seed_clickhouse.py /app/seed_clickhouse.py
COPY clickhouse/init-events.sql /app/init-events.sql
RUN chmod +x /app/bootstrap.sh && chown superset /app/bootstrap.sh

USER superset
ENV SUPERSET_CONFIG_PATH=/app/pythonpath/superset_config.py
CMD ["/app/bootstrap.sh"]
