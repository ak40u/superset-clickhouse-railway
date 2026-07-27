"""Superset configuration.

Everything here is read from the environment, because a configuration file with
a database password in it is a configuration file you cannot commit.
"""
import os

SECRET_KEY = os.environ["SUPERSET_SECRET_KEY"]

# Metadata: dashboards, users, saved queries. Separate from the data warehouse
# on purpose - Superset writes to this one constantly, and ClickHouse is not
# built for that.
SQLALCHEMY_DATABASE_URI = os.environ["DATABASE_URL"].replace("postgresql://", "postgresql+psycopg2://", 1)
SQLALCHEMY_TRACK_MODIFICATIONS = False

REDIS_URL = os.environ.get("REDIS_URL")
if REDIS_URL:
    # Without a shared cache every replica recomputes the same chart, and the
    # results of an async query are unreachable from the replica that did not
    # run it.
    CACHE_CONFIG = {
        "CACHE_TYPE": "RedisCache",
        "CACHE_DEFAULT_TIMEOUT": 300,
        "CACHE_KEY_PREFIX": "superset_",
        "CACHE_REDIS_URL": REDIS_URL,
    }
    DATA_CACHE_CONFIG = dict(CACHE_CONFIG, CACHE_DEFAULT_TIMEOUT=3600, CACHE_KEY_PREFIX="superset_data_")
    FILTER_STATE_CACHE_CONFIG = dict(CACHE_CONFIG, CACHE_KEY_PREFIX="superset_filter_")
    EXPLORE_FORM_DATA_CACHE_CONFIG = dict(CACHE_CONFIG, CACHE_KEY_PREFIX="superset_explore_")

# Behind the platform's proxy; without this Superset builds http:// links and
# the browser refuses them on an https page.
ENABLE_PROXY_FIX = True
WTF_CSRF_ENABLED = True
# The API is used by the verification script and by anything automating
# Superset; CSRF applies to browser sessions, not to token auth.
WTF_CSRF_EXEMPT_LIST = ["superset.views.core.log", "superset.security.api.guest_token"]

FEATURE_FLAGS = {
    "DASHBOARD_RBAC": True,
    "EMBEDDED_SUPERSET": False,
}

SQLLAB_CTAS_NO_LIMIT = True
SUPERSET_WEBSERVER_TIMEOUT = int(os.environ.get("SUPERSET_WEBSERVER_TIMEOUT", 120))
