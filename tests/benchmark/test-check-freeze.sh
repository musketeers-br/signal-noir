#!/bin/sh
# Proves both outcomes of scripts/benchmark/check-freeze.sh in a throwaway git repository
# (feature 010, T052): unchanged files pass, a changed or missing file fails, a placeholder says so.
#
#   sh tests/benchmark/test-check-freeze.sh
set -eu

here="$(cd "$(dirname "$0")/../.." && pwd)"
script="$here/scripts/benchmark/check-freeze.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"
git init -q .
mkdir -p src/SignalNoir/Benchmark/Data src/x
printf 'one\n' > src/x/a.txt
printf 'two\n' > src/x/b.txt

record() {
  # $1: freezeId, $2: blob of a.txt, $3: blob of b.txt
  cat > src/SignalNoir/Benchmark/Data/Freeze.cls <<EOF
Class SignalNoir.Benchmark.Data.Freeze Extends SignalNoir.Benchmark.Data.Base
{

XData Record [ MimeType = application/json ]
{
{
  "freezeId": "$1",
  "files": [{"path": "src/x/a.txt", "blob": "$2"}, {"path": "src/x/b.txt", "blob": "$3"}]
}
}

}
EOF
}

fail() { echo "FAIL: $1" >&2; exit 1; }

record "" "" ""
out="$(sh "$script")" || fail "a placeholder must pass"
echo "$out" | grep -q "no freeze yet" || fail "a placeholder must say there is no freeze"

a="$(git hash-object src/x/a.txt)"
b="$(git hash-object src/x/b.txt)"
record "freeze_1" "$a" "$b"
sh "$script" > /dev/null || fail "unchanged files must pass"

printf 'changed\n' > src/x/a.txt
if out="$(sh "$script")"; then fail "a changed file must fail"; fi
echo "$out" | grep -q "CHANGED  src/x/a.txt" || fail "the changed file must be named"
printf 'one\n' > src/x/a.txt

rm src/x/b.txt
if out="$(sh "$script")"; then fail "a missing file must fail"; fi
echo "$out" | grep -q "MISSING  src/x/b.txt" || fail "the missing file must be named"

echo "check-freeze: all outcomes proven"
