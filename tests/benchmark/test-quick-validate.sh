#!/bin/sh
# Proves the outcomes of scripts/quick-validate.sh against a stub of curl (feature 010, T068):
# all three Cases match (exit 0), one diverged (exit 1, with its reason), no report in time (exit 1).
#
#   sh tests/benchmark/test-quick-validate.sh
set -eu

here="$(cd "$(dirname "$0")/../.." && pwd)"
script="$here/scripts/quick-validate.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"

cat > "$work/bin/curl" <<'STUB'
#!/bin/sh
# a stand-in for curl: answers by URL; SCENARIO says what the report holds
out=""; fmt=""; url=""; prev=""
for a in "$@"; do
	[ "$prev" = "-o" ] && out="$a"
	[ "$prev" = "-w" ] && fmt="$a"
	case "$a" in http*) url="$a" ;; esac
	prev="$a"
done
case "$url" in
	*/health) echo '{"liveness":"alive","provider":{"configured":false}}' ;;
	*/benchmark-runs) echo '{"runId":"run_stub1","status":"running"}' ;;
	*/report)
		case "$SCENARIO" in
			late) [ -n "$out" ] && echo "" > "$out"; [ -n "$fmt" ] && printf '409'; exit 0 ;;
		esac
		match='{"referenceCase":"a/1","caseId":"","status":"matches_reference","reason":null},{"referenceCase":"b/1","caseId":"c2","status":"matches_reference","reason":null},{"referenceCase":"c/1","caseId":"c3","status":"matches_reference","reason":null}'
		diverged='{"referenceCase":"a/1","caseId":"","status":"matches_reference","reason":null},{"referenceCase":"b/1","caseId":"c2","status":"diverged","reason":"a different Action: the reference sent APPLY_APPROVED_MAPPING"},{"referenceCase":"c/1","caseId":"c3","status":"matches_reference","reason":null}'
		body=$match; [ "$SCENARIO" = diverged ] && body=$diverged
		if [ -n "$out" ]; then echo "{\"quickValidation\":[$body]}" > "$out"; printf '200'; else echo "{\"quickValidation\":[$body]}"; fi ;;
esac
STUB
chmod +x "$work/bin/curl"
export PATH="$work/bin:$PATH"
cd "$here"

fail() { echo "FAIL: $1" >&2; exit 1; }

out="$(SCENARIO=match sh "$script")" || fail "three matching Cases must pass"
echo "$out" | grep -q "PASS" || fail "the pass must be said"
echo "$out" | grep -q "mode replay" || fail "no provider configured: replay"
[ "$(echo "$out" | grep -c ': matches_reference')" -eq 3 ] || fail "each Case must be reported"

if out="$(SCENARIO=diverged sh "$script" 2>&1)"; then fail "a diverged Case must fail"; fi
echo "$out" | grep -q "b/1: diverged - a different Action" || fail "the divergence and its reason must be shown"

if out="$(SCENARIO=late SN_QUICK_SECONDS=2 sh "$script" 2>&1)"; then fail "no report in time must fail"; fi
echo "$out" | grep -q "no report for run_stub1 within 2s" || fail "the timeout must be said"

echo "quick-validate: all outcomes proven"
