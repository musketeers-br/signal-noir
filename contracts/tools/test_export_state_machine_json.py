"""Test export_state_machine_json.py against the small table used by the negative cases.

Usage (from the repo root):
    uv run --with pyyaml python contracts/tools/test_export_state_machine_json.py

Exit code 1 on any failure.
"""

import json
import re
import sys
import tempfile
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))

from export_state_machine_json import export  # noqa: E402

BASE = Path(__file__).resolve().parent / "tests" / "state_machine" / "_base.yaml"
SECTIONS = ["parameters", "states", "transitions", "attachments", "refusals", "journeyTrace"]


def main() -> int:
    failures = []
    source = yaml.safe_load(BASE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as tmp:
        json_path = Path(tmp) / "table.json"
        class_path = Path(tmp) / "TableFixture.cls"
        export(BASE, json_path, class_path)

        exported = json.loads(json_path.read_text(encoding="utf-8"))
        for section in SECTIONS:
            if exported.get(section) != source.get(section):
                failures.append(f"json: section {section} differs from the YAML")
        if exported.get("version") != str(source.get("version")):
            failures.append("json: version missing or different")

        text = class_path.read_text(encoding="utf-8")
        if not text.startswith("/// "):
            failures.append("xdata: class must start with a /// doc comment")
        if "Class SignalNoir.Tests.Core.TableFixture" not in text:
            failures.append("xdata: wrong class name")
        match = re.search(r"XData Table \[ MimeType = application/json \]\n\{\n(.*?)\n\}\n\n\}\n$", text, re.S)
        if not match:
            failures.append("xdata: no XData Table block")
        elif json.loads(match.group(1)) != exported:
            failures.append("xdata: XData JSON differs from the exported JSON")

    for failure in failures:
        print(f"FAIL {failure}")
    print("ok   export_state_machine_json" if not failures else f"\n{len(failures)} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
