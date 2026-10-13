env_get() {
  [ -f .env ] || return 0
  { grep -E "^$1=" .env || true; } | tail -1 | cut -d= -f2- | tr -d '\r' \
    | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}

PG_SERVICE="${PG_SERVICE:-postgres}"
PG_USER="${PG_USER:-$(env_get DB_POSTGRESDB_USER)}"
PG_USER="${PG_USER:-$(env_get DB_POSTGRESDB_USERNAME)}"
PG_USER="${PG_USER:-postgres}"
PG_PASSWORD="${PG_PASSWORD:-$(env_get DB_POSTGRESDB_PASSWORD)}"
PG_DB="${PG_DB:-$(env_get ZURI_DB_NAME)}"
PG_DB="${PG_DB:-zuri}"
PHONE_PEPPER="${PHONE_PEPPER:-$(env_get PHONE_PEPPER)}"
export PG_SERVICE PG_USER PG_PASSWORD PG_DB PHONE_PEPPER