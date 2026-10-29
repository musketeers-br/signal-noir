#!/bin/sh
# Fails when a tracked file holds something shaped like a provider key, or when a secret file is
# tracked (feature 012 FR-006). Run from the repository root; CI runs it on every push.
set -u
status=0
for f in .env .iris-agentic-dev.toml; do
	if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then echo "secret-scan: $f is tracked"; status=1; fi
done
if git ls-files | grep -E '(^|/)[^/]*\.key$|-docker\.tar\.gz$'; then echo "secret-scan: a license key or EAP archive is tracked"; status=1; fi
PATTERN='sk-(proj-|ant-)?[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35}|AKIA[0-9A-Z]{16}'
# the tests' fake keys say so in their name
HITS=$(git grep -nIE "$PATTERN" -- . ':(exclude)scripts/secret-scan.sh' | grep -v 'sk-signalnoir-test-')
if [ -n "$HITS" ]; then echo "$HITS"; echo "secret-scan: a provider key is committed"; status=1; fi
[ $status -eq 0 ] && echo "secret-scan: clean"
exit $status
