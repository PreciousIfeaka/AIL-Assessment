#!/usr/bin/env bash
cd "$(dirname "$0")/.."
./db/psql.sh -q <<'SQL'
TRUNCATE messages, conversation_state, escalations, audit_log, outbox RESTART IDENTITY CASCADE;
DELETE FROM orders WHERE order_id NOT IN
  ('ZH-10001','ZH-10002','ZH-10003','ZH-10004','ZH-10005','ZH-10006');
SQL
echo "Runtime tables cleared (catalogue, contacts, seeded orders kept)."