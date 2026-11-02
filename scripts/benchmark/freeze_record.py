#!/usr/bin/env python3
"""Writes the freeze record into Freeze.cls (feature 010, T056, plan D8).

    python -I scripts/benchmark/freeze_record.py --freeze-id freeze-2026-11-05 --inputs inputs.txt

The inputs half comes from IRIS, computed the way a reference run computes it:

    Do ##class(SignalNoir.Application.Benchmark.FreezeDraft).Print("gpt-4o-mini")

Save its line (`FREEZE-INPUTS {...}`) or the JSON alone to the file given as --inputs. This script
adds the files half: the git blob id of each frozen source file (FROZEN), the commit the freeze
is made from (HEAD) and the time, and writes the XData Record of Freeze.cls. Run it last, after
every frozen file is in its final state, then commit everything in one commit and run
`sh scripts/benchmark/check-freeze.sh`, which must pass. Changing a frozen file afterwards needs
a new freeze.

Exit status: 0 written; 1 refused (inputs missing or empty, a frozen file missing); 2 usage.
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys

# The inputs FreezeCheck compares at run time (Core.Benchmark.FreezeCheck FIELDS)
FIELDS = [
    "promptVersion", "model", "baselineVersion", "policyVersion", "mappingVersion",
    "policyDigest", "mappingDigest", "evaluatorVersion", "reservedCatalogDigest", "answerKeyDigest",
]

# The source files frozen with the record: the proposers and the prompt, what the baseline matches
# Mappings with, the evaluator, the reference data, the reserved variants and their texts, and the
# reserved answer keys
FROZEN = [
    "src/SignalNoir/Proposers/Agent.cls",
    "src/SignalNoir/Proposers/Rules.cls",
    "src/SignalNoir/Core/MappingMatch.cls",
    "src/SignalNoir/Core/Conditions.cls",
    "src/SignalNoir/Core/Identity.cls",
    "src/SignalNoir/Core/Benchmark/Scorer.cls",
    "src/SignalNoir/Core/Benchmark/Stats.cls",
    "src/SignalNoir/Application/Benchmark/CaseFacts.cls",
    "src/SignalNoir/Application/Reference/Policies/V2026101.cls",
    "src/SignalNoir/Application/Reference/Mappings/V2026101.cls",
    "src/SignalNoir/Sim/Catalog/P5Test.cls",
    "src/SignalNoir/Sim/Catalog/P8Test.cls",
    "src/SignalNoir/Sim/Catalog/CleanTest.cls",
    "src/SignalNoir/Sim/Catalog/Wording.cls",
    "src/SignalNoir/Benchmark/Data/AnswerKeyTest.cls",
]

RECORD = "src/SignalNoir/Benchmark/Data/Freeze.cls"
XDATA = re.compile(r"(XData Record[^\n]*\n\{\n)(.*)(\n\}\s*\n\n?\})", re.S)


class Refused(Exception):
    pass


def read_inputs(text):
    """The inputs object from the line IRIS printed, or from the JSON alone"""
    text = text.strip()
    if text.startswith("FREEZE-REFUSED"):
        raise Refused("IRIS refused the inputs: " + text[len("FREEZE-REFUSED"):].strip())
    for line in text.splitlines():
        if line.startswith("FREEZE-INPUTS "):
            text = line[len("FREEZE-INPUTS "):]
            break
    try:
        inputs = json.loads(text)
    except ValueError as error:
        raise Refused(f"the inputs are not JSON: {error}")
    if not isinstance(inputs, dict):
        raise Refused("the inputs must be a JSON object")
    empty = [f for f in FIELDS if not isinstance(inputs.get(f), str) or not inputs.get(f)]
    if empty:
        raise Refused("inputs missing or empty: " + ", ".join(empty))
    return inputs


def git(root, *args):
    done = subprocess.run(["git", *args], cwd=root, capture_output=True, text=True)
    if done.returncode != 0:
        raise Refused(f"git {' '.join(args)}: {done.stderr.strip()}")
    return done.stdout.strip()


def build(inputs, freeze_id, files, root, now=None):
    """The record: id, commit, time, the inputs, and {path, blob} of each frozen file"""
    if not freeze_id:
        raise Refused("a freeze id is needed")
    missing = [p for p in files if not os.path.isfile(os.path.join(root, p))]
    if missing:
        raise Refused("frozen files missing: " + ", ".join(missing))
    now = now or datetime.datetime.now(datetime.timezone.utc)
    record = {
        "freezeId": freeze_id,
        "commit": git(root, "rev-parse", "HEAD"),
        "frozenAt": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    for field in FIELDS:
        record[field] = inputs[field]
    record["files"] = [{"path": p, "blob": git(root, "hash-object", "--", p)} for p in files]
    return record


def render(record):
    """The record as the XData body: one field per line, one frozen file per line"""
    lines = []
    for key, value in record.items():
        if key == "files":
            continue
        lines.append(f"  {json.dumps(key)}: {json.dumps(value)},")
    entries = [f"    {json.dumps(entry)}" for entry in record["files"]]
    lines.append('  "files": [')
    lines.append(",\n".join(entries))
    lines.append("  ]")
    return "{\n" + "\n".join(lines) + "\n}"


def write(path, record):
    with open(path, encoding="utf-8", newline="") as handle:
        text = handle.read()
    crlf = "\r\n" in text
    text = text.replace("\r\n", "\n")
    match = XDATA.search(text)
    if not match:
        raise Refused(f"cannot find the XData Record in {path}")
    text = text[: match.start(2)] + render(record) + text[match.end(2):]
    if crlf:
        text = text.replace("\n", "\r\n")
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--freeze-id", required=True)
    parser.add_argument("--inputs", required=True, help="file with the FREEZE-INPUTS line or the JSON")
    parser.add_argument("--record", default=RECORD)
    parser.add_argument("--root", default=".")
    args = parser.parse_args(argv)
    try:
        with open(args.inputs, encoding="utf-8") as handle:
            inputs = read_inputs(handle.read())
        record = build(inputs, args.freeze_id, FROZEN, args.root)
        write(os.path.join(args.root, args.record), record)
    except Refused as error:
        print(f"refused: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"refused: {error}", file=sys.stderr)
        return 1
    print(f"wrote the freeze {args.freeze_id} with {len(record['files'])} frozen files to {args.record}")
    print("commit it together with the frozen files, then run: sh scripts/benchmark/check-freeze.sh")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
