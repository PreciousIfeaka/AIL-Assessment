#!/usr/bin/env bash
# Usage: ./tests/run-tests.sh      (needs WA_URL; see tests/.env.example)
set -uo pipefail
cd "$(dirname "$0")/.."
if [ -f tests/.env ]; then set -a; . tests/.env; set +a; fi
WAIT="${WAIT:-4}"; export WAIT
ADA=2348011112222; BOLA=2348033334444; CHIDI=2348055556666
PASS=0; FAIL=0; REC=tests/test_record.csv

q() { ./db/psql.sh -tA -c "$1"; }
last()  { q "SELECT text FROM outbox ORDER BY id DESC LIMIT 1;" | tr '\n' ' '; }
esc()   { q "SELECT COALESCE((SELECT category||'/'||priority||'/'||assigned_to FROM escalations ORDER BY id DESC LIMIT 1),'none');"; }
state() { q "SELECT COALESCE((SELECT intent||'/'||step FROM conversation_state WHERE phone_hash=(SELECT phone_hash FROM contacts WHERE wa_phone='$1')),'none');"; }
send()  { LABEL="$1" tests/send.sh "$2" "$3" "${4:-}" >/dev/null; sleep "$WAIT"; }
clean() { printf '%s' "$1" | tr '\n' ' ' | tr '"' "'" | cut -c1-140; }

check() {   # id | input | expected | actual | regex
  local result=FAIL
  if printf '%s' "$4" | grep -qiE -- "$5"; then result=PASS; PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
  printf '%-5s %-5s %s\n' "$1" "$result" "$2"
  [ "$result" = FAIL ] && printf '        expected: %s\n        actual:   %s\n' "$3" "$(clean "$4")"
  printf '"%s","%s","%s","%s",%s\n' "$1" "$(clean "$2")" "$(clean "$3")" "$(clean "$4")" "$result" >> "$REC"
}

tests/reset.sh
echo 'id,input,expected,actual,result' > "$REC"

# ---- Intents ----
send t01 $ADA "How much is the ceramic vase?"
check T01 "How much is the ceramic vase?" "price and stock" "$(last)" "15,000"
send t02 $ADA "vase ceramic price"
check T02 "vase ceramic price" "same product, word order ignored" "$(last)" "15,000"
send t03 $ADA "do you have flower pot?"
check T03 "do you have flower pot?" "synonym match via keywords" "$(last)" "Ceramic Vase"
send t04 $ADA "price of vase"
check T04 "price of vase" "list of matching products" "$(last)" "few matches"
send t05 $ADA "how much is the brass lamp"
check T05 "how much is the brass lamp" "out-of-stock wording" "$(last)" "out of stock"
send t06 $ADA "price of unicorn lamp"
check T06 "price of unicorn lamp" "not-found reply" "$(last)" "could not find"
send t07 $ADA "price?"
check T07 "price?" "asks which product" "$(last)" "which product"
send t08 $ADA "delivery to Abuja?"
check T08 "delivery to Abuja?" "zones and fees" "$(last)" "5,500"
send t09 $ADA "I want to pay by bank transfer"
check T09 "I want to pay by bank transfer" "bank details" "$(last)" "Demo Bank"

# ---- payment follow-up, order status, cancel ----
send t10 $ADA "I've paid"
check T10 "I've paid" "state saved, waiting for order ID" "$(state $ADA)" "^payment_info/await_id$"
send t11 $ADA "ZH-10001"
check T11 "ZH-10001 (follow-up)" "payment_verification escalation, state cleared" "$(esc) ; $(state $ADA)" "^payment_verification/normal/sales ; none$"
send t12 $ADA "Where is ZH-10001"
check T12 "Where is ZH-10001" "status of own order" "$(last)" "awaiting payment"
send t13 $BOLA "Where is ZH-10001"
check T13 "Where is ZH-10001 (other customer)" "ownership check blocks it" "$(last)" "could not match"
send t14 $ADA "track ZH-12"
check T14 "track ZH-12" "format re-prompt, state saved" "$(last) ; $(state $ADA)" "ZH-12345.*order_status/await_id"
send t15 $ADA "ZH-10002"
check T15 "ZH-10002 (follow-up)" "status shown, state cleared" "$(last) ; $(state $ADA)" "delivered.* ; none$"
send t16 $ADA "where is my order"
check T16 "where is my order" "asks for order ID" "$(last)" "order ID"
send t17 $ADA "cancel"
check T17 "cancel" "flow cancelled, state cleared, audited" "$(last) ; $(state $ADA) ; $(q "SELECT COUNT(*) FROM audit_log WHERE event='flow_cancelled';")" "cancelled.* ; none ; 1$"

# ---- place_order (Chidi) ----
send t18a $CHIDI "I want to buy a vase"
check T18a "I want to buy a vase" "asks what to buy" "$(last) ; $(state $CHIDI)" "What would you like.* ; place_order/item$"
send t18b $CHIDI "ceramic vase"
check T18b "ceramic vase" "asks quantity" "$(last) ; $(state $CHIDI)" "How many.* ; place_order/qty$"
send t18c $CHIDI "2"
check T18c "2" "asks address" "$(state $CHIDI)" "^place_order/address$"
send t18d $CHIDI "Kano"
check T18d "Kano (invalid address)" "re-prompt, same step" "$(last) ; $(state $CHIDI)" "full address.* ; place_order/address$"
send t18e $CHIDI "8 Aba Road, GRA, Port Harcourt"
check T18e "8 Aba Road, GRA, Port Harcourt" "asks name" "$(state $CHIDI)" "^place_order/name$"
send t18f $CHIDI "Chidi Demo"
check T18f "Chidi Demo" "summary with total" "$(last)" "35,500"
send t18g $CHIDI "YES"
check T18g "YES" "order created, sales alerted, state cleared" "$(q "SELECT COALESCE((SELECT total_ngn||'/'||status FROM orders WHERE customer_name='Chidi Demo' AND status='awaiting_payment'),'no order');") ; $(esc) ; $(state $CHIDI)" "^35500/awaiting_payment ; new_order/normal/sales ; none$"

# ---- stuck intake, interrupts, escalation, failures ----
send t19a $ADA "I want to buy a vase"
send t19b $ADA "ceramic vase"
send t19c $ADA "abc"
send t19d $ADA "abc"
send t19e $ADA "abc"
check T19 "three invalid quantities" "intake_stuck escalation, state cleared" "$(esc) ; $(state $ADA)" "^intake_stuck/normal/sales ; none$"
send t20a $BOLA "I want to buy a scarf"
send t20b $BOLA "agent"
check T20 "agent (mid-order)" "human_request escalation, state cleared" "$(esc) ; $(state $BOLA)" "^human_request/normal/sales ; none$"
send t21 $ADA "I want a refund"
check T21 "I want a refund" "high priority, routed to manager" "$(esc)" "^complaint_refund/high/manager$"
send t22 $BOLA "asdfgh"
check T22 "asdfgh" "low_confidence escalation and audit row" "$(esc) ; $(q "SELECT COUNT(*) FROM audit_log WHERE event='low_confidence';")" "^low_confidence/normal/sales ; 1$"
send t23a $ADA "How much is the glass vase?" wamid.TEST.DUP1
send t23b $ADA "How much is the glass vase?" wamid.TEST.DUP1
check T23 "same message ID sent twice" "1 message, 1 reply, 1 duplicate_ignored" "$(q "SELECT (SELECT COUNT(*) FROM messages WHERE wa_message_id='wamid.TEST.DUP1')||'/'||(SELECT COUNT(*) FROM outbox WHERE request_id='wamid.TEST.DUP1')||'/'||(SELECT COUNT(*) FROM audit_log WHERE event='duplicate_ignored');")" "^1/1/1$"
TYPE=image LABEL=t24 tests/send.sh $CHIDI "" >/dev/null; sleep "$WAIT"
check T24 "image message" "media_received escalation" "$(esc)" "^media_received/normal/sales$"

echo; echo "Passed: $PASS   Failed: $FAIL   (record: $REC)"
[ "$FAIL" -eq 0 ]