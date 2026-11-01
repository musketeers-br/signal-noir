#!/bin/sh
# Compares each frozen source file with the freeze record (feature 010, plan D8).
#
#   sh scripts/benchmark/check-freeze.sh [FREEZE_CLASS_FILE]
#
# The freeze record is the XData `Record` of src/SignalNoir/Benchmark/Data/Freeze.cls. Its `files`
# lists {path, blob}: the git blob id of each source file that was frozen (the proposers, the
# prompt, the evaluator, the fixtures, the reserved variants). A file whose `git hash-object` differs
# was changed after the freeze: the freeze must be redone, and a run made since is development data.
# The runtime cannot hash source files, so this runs in CI.
#
# Exit status: 0 when every frozen file is unchanged, or when nothing is frozen yet (said plainly);
# 1 when a frozen file differs or is missing; 2 on a usage or format error.
set -eu

record="${1:-src/SignalNoir/Benchmark/Data/Freeze.cls}"
[ -f "$record" ] || { echo "no freeze record at $record" >&2; exit 2; }

py="$(command -v python3 || command -v python)" || { echo "python is needed" >&2; exit 2; }
"$py" - "$record" <<'PYEOF'
import json
import re
import subprocess
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
match = re.search(r"XData Record[^\n]*\n\{\n(.*)\n\}\s*\n\n?\}", text, re.S)
if not match:
    print(f"cannot find the XData Record in {path}", file=sys.stderr)
    sys.exit(2)
try:
    record = json.loads(match.group(1))
except ValueError as error:
    print(f"the freeze record is not valid JSON: {error}", file=sys.stderr)
    sys.exit(2)

if not record.get("freezeId"):
    print("no freeze yet: the record is a placeholder, nothing to compare")
    sys.exit(0)

files = record.get("files", [])
if not files:
    print("the freeze names no file: a freeze must list the source files it froze", file=sys.stderr)
    sys.exit(1)

bad = 0
for entry in files:
    name, blob = entry.get("path", ""), entry.get("blob", "")
    done = subprocess.run(["git", "hash-object", "--", name], capture_output=True, text=True)
    if done.returncode != 0:
        print(f"MISSING  {name}: {done.stderr.strip()}")
        bad += 1
    elif done.stdout.strip() != blob:
        print(f"CHANGED  {name}: frozen {blob[:10]}, now {done.stdout.strip()[:10]}")
        bad += 1
if bad:
    print(f"{bad} of {len(files)} frozen files differ from the freeze {record['freezeId']}: freeze again")
    sys.exit(1)
print(f"all {len(files)} frozen files match the freeze {record['freezeId']}")
PYEOF
