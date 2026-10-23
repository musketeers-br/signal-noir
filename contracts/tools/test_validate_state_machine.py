"""Run the negative cases of validate_state_machine.py, then the real table.

Usage (from the repo root):
    uv run --with pyyaml python contracts/tools/test_validate_state_machine.py

Each entry of contracts/tools/tests/state_machine/cases.json must make the validator report an
error containing its ``expect`` text. After the cases, contracts/case-state-machine.yaml must
validate with no errors. Exit code 1 on any failure.
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from validate_state_machine import DEFAULT_OPENAPI, DEFAULT_SPEC, DEFAULT_TABLE, validate  # noqa: E402

CASES = Path(__file__).resolve().parent / "tests" / "state_machine"


def main() -> int:
    failures = 0
    cases = json.loads((CASES / "cases.json").read_text(encoding="utf-8"))
    for case in cases:
        spec = CASES / case["spec"] if "spec" in case else DEFAULT_SPEC
        errors = validate(CASES / case["file"], spec, DEFAULT_OPENAPI)
        if any(case["expect"] in e for e in errors):
            print(f"ok   {case['file']}")
        else:
            failures += 1
            print(f"FAIL {case['file']}: expected an error containing {case['expect']!r}")
            for err in errors[:6]:
                print(f"     got: {err[:160]}")

    errors = validate(DEFAULT_TABLE, DEFAULT_SPEC, DEFAULT_OPENAPI)
    if errors:
        failures += 1
        print(f"FAIL {DEFAULT_TABLE.name}: {len(errors)} error(s)")
        for err in errors:
            print(f"     {err}")
    else:
        print(f"ok   {DEFAULT_TABLE.name}")

    print(f"\n{len(cases) + 1 - failures} passed, {failures} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
