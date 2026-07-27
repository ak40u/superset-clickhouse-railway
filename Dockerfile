# Pinned to a release, not a moving tag: Superset publishes dozens of images a
# day and most of them are development builds.
FROM apache/superset:5.0.0

USER root
# The official image carries no ClickHouse driver, which is the single reason a
# "Superset + ClickHouse" deployment cannot be assembled from stock images.
RUN pip install --no-cache-dir clickhouse-connect==0.9.4 psycopg2-binary==2.9.11 redis==6.6.0

COPY docker/superset_config.py /app/pythonpath/superset_config.py
COPY docker/bootstrap.sh /app/bootstrap.sh
RUN chmod +x /app/bootstrap.sh && chown superset /app/bootstrap.sh

USER superset
ENV SUPERSET_CONFIG_PATH=/app/pythonpath/superset_config.py
CMD ["/app/bootstrap.sh"]
