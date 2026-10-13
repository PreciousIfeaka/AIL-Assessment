#!/usr/bin/env bash
# Creates and seeds the Zuri PostgreSQL database inside a Docker container.
# Usage: PHONE_PEPPER=<same value n8n uses> ./db/setup.sh [--reset]
#
# Optional settings (environment variables):
#   PG_SERVICE    compose service name of Postgres      (default: postgres)
#   PG_CONTAINER  container name, if it is NOT in this compose project
#   PG_USER       database user                         (default: zuri_app)
#   PG_DB         database name                         (default: zuri)
#   PG_PASSWORD   only if your container asks for one
set -euo pipefail
cd "$(dirname "$0")/.."          # run from the project root, wherever this file lives

. db/env.sh
: "${PHONE_PEPPER:?Set PHONE_PEPPER in .env or on the command line (it must match n8n)}"

RESET=0
case "${1:-}" in
  --reset) RESET=1 ;;
  "")      ;;
  *)       echo "Unknown option: $1 (use --reset to drop and reseed)"; exit 1 ;;
esac

# ---- sanity checks ----------------------------------------------------------
for f in db/schema.sql db/seed.sql; do
  [ -f "$f" ] || { echo "Missing $f"; exit 1; }
done
command -v openssl >/dev/null || { echo "openssl is required on the host"; exit 1; }
command -v docker  >/dev/null || { echo "docker is required"; exit 1; }

# ---- run psql inside the container (no published port needed) ----------------
ENV_ARGS=(-e "PGOPTIONS=--client-min-messages=warning")      # hides harmless NOTICE lines
[ -n "${PG_PASSWORD:-}" ] && ENV_ARGS+=(-e "PGPASSWORD=$PG_PASSWORD")

psql_run() {
  if [ -n "${PG_CONTAINER:-}" ]; then
    docker exec -i "${ENV_ARGS[@]}" "$PG_CONTAINER" \
      psql -U "$PG_USER" -d "$PG_DB" -v ON_ERROR_STOP=1 "$@"
  else
    docker compose exec -T "${ENV_ARGS[@]}" "$PG_SERVICE" \
      psql -U "$PG_USER" -d "$PG_DB" -v ON_ERROR_STOP=1 "$@"
  fi
}

# ---- connection check ---------------------------------------------------------
if ! OUT=$(psql_run -tA -c "SELECT 1;" 2>&1); then
  echo "Cannot connect to Postgres:"
  echo "$OUT"
  echo
  echo "Check: service/container name (PG_SERVICE or PG_CONTAINER), user (PG_USER), database (PG_DB)."
  echo "Create the database if needed:  docker compose exec $PG_SERVICE createdb -U $PG_USER $PG_DB"
  exit 1
fi

# ---- refuse to overwrite existing data unless --reset -------------------------
EXISTS=$(psql_run -tA -c "SELECT to_regclass('public.products') IS NOT NULL;" | tr -d '[:space:]')
if [ "$EXISTS" = "t" ] && [ "$RESET" -ne 1 ]; then
  echo "Zuri tables already exist. Re-run with --reset to drop and reseed."
  exit 1
fi

# ---- phone hashes: HMAC-SHA256(phone, PHONE_PEPPER), hex ----------------------
# Same algorithm as the Hash Phone node in n8n.
hash_phone() { printf '%s' "$1" | openssl dgst -sha256 -hmac "$PHONE_PEPPER" -r | cut -d' ' -f1; }
HASH_A=$(hash_phone 2348011112222)   # Ada Test:     owns ZH-10001, ZH-10002
HASH_B=$(hash_phone 2348033334444)   # Bola Sample:  owns ZH-10003, ZH-10004
HASH_C=$(hash_phone 2348055556666)   # Chidi Demo:   owns ZH-10005, ZH-10006

for h in "$HASH_A" "$HASH_B" "$HASH_C"; do
  [ "${#h}" -eq 64 ] || { echo "Hashing failed (expected 64 hex characters, got '${h}')"; exit 1; }
done

# ---- create schema, then seed ---------------------------------------------------
echo "Creating schema..."
psql_run -q < db/schema.sql

echo "Seeding data..."
sed -e "s/@@HASH_A@@/$HASH_A/g" \
    -e "s/@@HASH_B@@/$HASH_B/g" \
    -e "s/@@HASH_C@@/$HASH_C/g" \
    db/seed.sql | psql_run -q

# ---- verify ---------------------------------------------------------------------
COUNTS=$(psql_run -tA -F ' ' -c "SELECT (SELECT count(*) FROM products),
                                        (SELECT count(*) FROM contacts),
                                        (SELECT count(*) FROM orders);" | tr -d '\r')
echo "products / contacts / orders: $COUNTS"

if [ "$COUNTS" != "20 3 6" ]; then
  echo "Unexpected row counts (expected 20 3 6). Check db/schema.sql and db/seed.sql."
  exit 1
fi
echo "Done. Database '$PG_DB' is ready."