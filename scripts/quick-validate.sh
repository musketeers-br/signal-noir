#!/bin/sh
# Quick validation (feature 010, FR-033): runs three reference cases (a control, a P5 or P8b case and a
# case that ends in a Dossier), compares each outcome with the recorded reference result, and says for
# each "matches the reference" or "diverged" with the reason. It must finish within three minutes.
# Needs only sh and curl.
#   sh scripts/quick-validate.sh                  # against http://localhost:52773
#   SN_HOST=http://host:port sh scripts/quick-validate.sh
# Exit status: 0 only when all three Cases match the reference; 1 otherwise, or when the report is not
# there within SN_QUICK_SECONDS (default 180).
# The mode is the Agent when the application reports a configured provider, otherwise Replay (a
# recorded response: deterministic, no key). A Replay never counts as a real run.
set -u
HOST=${SN_HOST:-http://localhost:52773}
API=$HOST/signalnoir/api/v1
LIMIT=${SN_QUICK_SECONDS:-180}
REQUEST=${SN_QUICK_REQUEST:-docs/benchmark/quick-validation-request.json}
START=$(date +%s)

elapsed() { echo $(( $(date +%s) - START )); }
fail() { echo "quick-validate: FAIL after $(elapsed)s: $1" >&2; exit 1; }

[ -f "$REQUEST" ] || fail "no request at $REQUEST"
curl -fsS "$API/health" 2>/dev/null | grep -q '"liveness":"alive"' || fail "the application is not alive at $API/health"

if curl -fsS "$API/health" 2>/dev/null | grep -q '"configured":true'; then MODE=agent; else MODE=replay; fi
echo "quick-validate: mode $MODE"

BODY=$(sed "s/__MODE__/$MODE/" "$REQUEST")
ANSWER=$(curl -sS -X POST -H 'Content-Type: application/json' -d "$BODY" "$API/benchmark-runs")
RUN=$(echo "$ANSWER" | sed -n 's/.*"runId":"\([^"]*\)".*/\1/p')
[ -n "$RUN" ] || fail "the run was not created: $ANSWER"
echo "quick-validate: run $RUN"

while :; do
	[ "$(elapsed)" -ge "$LIMIT" ] && fail "no report for $RUN within ${LIMIT}s"
	CODE=$(curl -s -o /tmp/quick-report.$$ -w '%{http_code}' "$API/benchmark-runs/$RUN/report")
	[ "$CODE" = 200 ] && break
	[ "$CODE" = 409 ] || [ "$CODE" = 000 ] || fail "the report answered HTTP $CODE"
	sleep 3
done

LINES=$(tr '{' '\n' < /tmp/quick-report.$$ | grep '"referenceCase"')
rm -f /tmp/quick-report.$$
[ -n "$LINES" ] || fail "the report has no quickValidation section"
MATCH=0
BAD=0
echo "$LINES" | while IFS= read -r line; do
	refcase=$(echo "$line" | sed -n 's/.*"referenceCase":"\([^"]*\)".*/\1/p')
	status=$(echo "$line" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')
	reason=$(echo "$line" | sed -n 's/.*"reason":"\([^"]*\)".*/\1/p')
	echo "quick-validate: $refcase: $status${reason:+ - $reason}"
done
MATCH=$(echo "$LINES" | grep -c '"status":"matches_reference"')
BAD=$(echo "$LINES" | grep -vc '"status":"matches_reference"')
if [ "$MATCH" -eq 3 ] && [ "$BAD" -eq 0 ]; then
	echo "quick-validate: PASS in $(elapsed)s: 3 of 3 Cases match the reference"
	exit 0
fi
echo "quick-validate: FAIL in $(elapsed)s: $MATCH matched, $BAD did not" >&2
exit 1
