#!/bin/sh
# Signal Noir smoke check (feature 012 FR-008): sends one synthetic Order through the Simulator and
# waits for the background feed reader to open its Case. Needs only sh and curl.
#   sh scripts/smoke.sh                 # against http://localhost:52773
#   SN_HOST=http://host:port sh scripts/smoke.sh
set -u
HOST=${SN_HOST:-http://localhost:52773}
API=$HOST/signalnoir/api/v1
SIM=$HOST/sim/api/v1
WAIT=${SN_SMOKE_WAIT_SECONDS:-600}
START=$(date +%s)

elapsed() { echo $(( $(date +%s) - START )); }
fail() { echo "smoke: FAIL after $(elapsed)s: $1" >&2; exit 1; }

# "degraded" (no provider) still serves Cases: liveness is enough
echo "smoke: waiting for $API/health"
until curl -fsS "$API/health" 2>/dev/null | grep -q '"liveness":"alive"'; do
	[ "$(elapsed)" -ge "$WAIT" ] && fail "the application is not ready"
	sleep 5
done
curl -fsS "$API/health"; echo

SEED=$(( $(date +%s) % 100000 ))
SCI=$(curl -fsS -X POST -H 'Content-Type: application/json' \
	-d "{\"family\":\"P5\",\"variant\":\"P5-tune-01\",\"seed\":$SEED}" "$SIM/scenarios" |
	sed -n 's/.*"scenarioInstanceId":"\([^"]*\)".*/\1/p')
[ -n "$SCI" ] || fail "the Simulator did not create a scenario"
ORDER=$(curl -fsS -X POST "$SIM/scenarios/$SCI/emissions" | sed -n 's/.*"orderId":"\([^"]*\)".*/\1/p')
[ -n "$ORDER" ] || fail "the Simulator did not emit an Order"
echo "smoke: synthetic Order $ORDER emitted (scenario $SCI); waiting for its Case"

while :; do
	LINE=$(curl -fsS "$API/cases?limit=200" 2>/dev/null | tr '{' '\n' | grep "\"orderId\":\"$ORDER\"" | head -1)
	if [ -n "$LINE" ]; then
		CASE=$(echo "$LINE" | sed -n 's/.*"caseId":"\([^"]*\)".*/\1/p')
		STATE=$(echo "$LINE" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p')
		echo "smoke: PASS in $(elapsed)s: Case $CASE for Order $ORDER is $STATE"
		echo "smoke: open $HOST/signalnoir/ to see it in the console"
		exit 0
	fi
	[ "$(elapsed)" -ge "$WAIT" ] && fail "no Case for Order $ORDER (is SN_BACKGROUND_TASKS=1 in .env?)"
	sleep 10
done
