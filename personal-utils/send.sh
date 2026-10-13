#!/usr/bin/env bash
# Usage: [TYPE=image] [LABEL=t01] tests/send.sh <phone> "<text>" [wa_message_id]
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -f tests/.env ]; then set -a; . tests/.env; set +a; fi
: "${WA_URL:?Set WA_URL to the WA-Inbound production webhook URL}"
PHONE="$1"; TEXT="${2:-}"
WA_ID="${3:-wamid.TEST.$(date +%s%N)}"
TYPE="${TYPE:-text}"
FILE="test_inputs/${LABEL:-last}.json"
mkdir -p test_inputs

jq -n --arg from "$PHONE" --arg id "$WA_ID" --arg ts "$(date +%s)" --arg body "$TEXT" --arg type "$TYPE" '
  { object: "whatsapp_business_account",
    entry: [{ id: "101234567890123", changes: [{ field: "messages", value: {
      messaging_product: "whatsapp",
      metadata: { display_phone_number: "2348099999999", phone_number_id: "109876543210987" },
      contacts: [{ profile: { name: "Test User" }, wa_id: $from }],
      messages: [ if $type == "image"
        then { from: $from, id: $id, timestamp: $ts, type: "image", image: { id: "media-1", mime_type: "image/jpeg" } }
        else { from: $from, id: $id, timestamp: $ts, type: "text", text: { body: $body } } end ]
    } }] }] }' > "$FILE"

curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST "$WA_URL" \
  -H "Content-Type: application/json" --data-binary @"$FILE"