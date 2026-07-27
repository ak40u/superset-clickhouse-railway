# Pinned to a release, not a moving tag: Superset publishes dozens of images a
# day and most of them are development builds.
FROM apache/superset:5.0.0

USER root
# The official image carries no ClickHouse driver, which is the single reason a
# "Superset + ClickHouse" deployment cannot be assembled from stock images.
#
# Installed into the image's virtualenv explicitly: a plain `pip install` here
# lands in the system Python, which Superset does not use, and the failure
# arrives later as ModuleNotFoundError at start-up.
RUN /app/.venv/bin/pip install --no-cache-dir \
      clickhouse-connect==1.6.0 psycopg2-binary==2.9.12 redis==6.4.0

COPY docker/superset_config.py /app/pythonpath/superset_config.py
COPY docker/bootstrap.sh /app/bootstrap.sh
RUN chmod +x /app/bootstrap.sh && chown superset /app/bootstrap.sh

USER superset
ENV SUPERSET_CONFIG_PATH=/app/pythonpath/superset_config.py
CMD ["/app/bootstrap.sh"]
