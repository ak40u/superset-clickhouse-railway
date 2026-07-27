#!/usr/bin/env bash
# End-to-end check of a deployed Superset + ClickHouse stack.
#
# The check that matters is the last one: a SQL query sent through Superset's
# API, executed by ClickHouse, returning rows. Everything before it is a
# precondition for that.
#
#   scripts/verify-analytics.sh https://your-superset.up.railway.app admin 'the-password'
set -uo pipefail

BASE="${1:?usage: verify-analytics.sh <base-url> <admin-user> <admin-password>}"
USER_NAME="${2:?usage: verify-analytics.sh <base-url> <admin-user> <admin-password>}"
PASSWORD="${3:?usage: verify-analytics.sh <base-url> <admin-user> <admin-password>}"
BASE="${BASE%/}"
failed=0

ok()   { echo "  ok   $1${2:+ - $2}"; }
fail() { echo "  FAIL $1 - $2"; failed=1; }

pick() {
  python3 -c '
import json, sys
try:
    node = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)
for part in sys.argv[2:]:
    try:
        node = node[int(part)] if part.isdigit() else node[part]
    except Exception:
        sys.exit(0)
print(node if isinstance(node, str) else json.dumps(node))
' "$@"
}

echo "checking $BASE"

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 60 "$BASE/health")
[ "$code" = "200" ] && ok "health" || fail "health" "got $code"

# 1. The dashboard list is not public.
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 60 "$BASE/api/v1/dashboard/")
[ "$code" = "401" ] && ok "the api requires a session" || fail "the api requires a session" "got $code"

# 2. Log in through the API with the generated admin credentials.
login=$(curl -s --max-time 60 -X POST "$BASE/api/v1/security/login" -H 'content-type: application/json' \
  -d "{\"username\":\"$USER_NAME\",\"password\":\"$PASSWORD\",\"provider\":\"db\",\"refresh\":true}")
TOKEN=$(pick "$login" access_token)
[ -n "$TOKEN" ] && ok "admin login" || fail "admin login" "${login:0:160}"

auth=(-H "authorization: Bearer $TOKEN")

# 3. The warehouse connection exists - registered at boot, not by hand.
dbs=$(curl -s --max-time 60 "${auth[@]}" "$BASE/api/v1/database/")
case "$dbs" in
  *ClickHouse*) ok "the ClickHouse connection is registered" ;;
  *) fail "the ClickHouse connection is registered" "${dbs:0:200}" ;;
esac
DB_ID=$(python3 -c '
import json, sys
try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)
for row in data.get("result", []):
    if "clickhouse" in str(row.get("database_name", "")).lower():
        print(row.get("id"))
        break
' "$dbs")

# 4. Run a query. This is the whole product in one call: Superset accepts SQL,
#    ClickHouse executes it, rows come back.
if [ -n "$DB_ID" ]; then
  csrf_body=$(curl -s --max-time 60 "${auth[@]}" -c /tmp/superset-cookies.txt "$BASE/api/v1/security/csrf_token/")
  CSRF=$(pick "$csrf_body" result)
  query=$(curl -s --max-time 120 "${auth[@]}" -b /tmp/superset-cookies.txt \
    -H "x-csrftoken: $CSRF" -H "referer: $BASE" -H 'content-type: application/json' \
    -X POST "$BASE/api/v1/sqllab/execute/" \
    -d "{\"database_id\":$DB_ID,\"sql\":\"select event_name, count() as n from analytics.events group by event_name order by n desc\",\"schema\":\"analytics\",\"runAsync\":false,\"select_as_cta\":false}")
  rows=$(pick "$query" data)
  case "$rows" in
    *event_name*|*page_view*) ok "a query ran against ClickHouse" "$(echo "$rows" | head -c 90)" ;;
    *) fail "a query ran against ClickHouse" "${query:0:220}" ;;
  esac
  rm -f /tmp/superset-cookies.txt
else
  fail "a query ran against ClickHouse" "no ClickHouse database id"
fi

echo
[ "$failed" = "0" ] && echo "all checks passed" || { echo "some checks failed"; exit 1; }
