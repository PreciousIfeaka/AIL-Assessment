#!/usr/bin/env bash
# Runs psql inside the Postgres container (no published port needed).
# Usage:  ./db/psql.sh -c "SELECT 1;"      or      ./db/psql.sh < file.sql
set -euo pipefail
cd "$(dirname "$0")/.."          # run from the project root, wherever this file lives
. db/env.sh

ENV_ARGS=(-e "PGOPTIONS=--client-min-messages=warning")      # hides harmless NOTICE lines
if [ -n "${PG_PASSWORD:-}" ]; then
  ENV_ARGS+=(-e "PGPASSWORD=$PG_PASSWORD")
fi

if [ -n "${PG_CONTAINER:-}" ]; then          # only if Postgres is NOT in this compose project
  exec docker exec -i "${ENV_ARGS[@]}" "$PG_CONTAINER" \
    psql -U "$PG_USER" -d "$PG_DB" -v ON_ERROR_STOP=1 "$@"
else
  exec docker compose exec -T "${ENV_ARGS[@]}" "$PG_SERVICE" \
    psql -U "$PG_USER" -d "$PG_DB" -v ON_ERROR_STOP=1 "$@"
fi