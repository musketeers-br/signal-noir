"""Validate Simulator contract captures against contracts/openapi-sim.yaml.

Usage (from the repo root):
    uv run --with jsonschema --with pyyaml python tests/sim-contract/validate_sim_captures.py

Captures are written by the SignalNoir.Tests.Sim.Contract.* suites (feature 002, research D13).
Each manifest entry is {file, operationId, status, schema}; schema is a component name
(``ScenarioInstance``) or a JSON pointer into the OpenAPI document (``#/paths/...``). OpenAPI 3.1
schemas are JSON Schema 2020-12, validated with the whole document as the reference root.
Exit code 1 when any capture fails, or when an operation of the contract has no capture.
"""

import json
import sys
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT202012

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "contracts" / "openapi-sim.yaml"
CAPTURES = Path(__file__).resolve().parent / "captures"
BASE_URI = "urn:signalnoir:openapi-sim"


def main() -> int:
    spec = yaml.safe_load(CONTRACT.read_text(encoding="utf-8"))
    registry = Registry().with_resource(BASE_URI, Resource.from_contents(spec, default_specification=DRAFT202012))
    manifest = json.loads((CAPTURES / "manifest.json").read_text(encoding="utf-8"))
    operations = {op["operationId"] for path in spec["paths"].values() for op in path.values() if isinstance(op, dict) and "operationId" in op}
    seen = set()
    failures = 0
    for entry in manifest["fixtures"]:
        seen.add(entry["operationId"])
        schema = entry["schema"]
        ref = schema if schema.startswith("#") else f"#/components/schemas/{schema}"
        validator = Draft202012Validator({"$ref": f"{BASE_URI}{ref}"}, registry=registry)
        body = json.loads((CAPTURES / entry["file"]).read_text(encoding="utf-8"))
        errors = sorted(validator.iter_errors(body), key=lambda e: list(e.absolute_path))
        if errors:
            failures += 1
            print(f"FAIL {entry['file']} ({entry['operationId']} {entry['status']}, {schema})")
            for err in errors[:8]:
                where = "/".join(str(p) for p in err.absolute_path) or "(root)"
                print(f"     {where}: {err.message[:160]}")
        else:
            print(f"ok   {entry['file']} ({entry['operationId']} {entry['status']}, {schema})")
    missing = sorted(operations - seen)
    for op in missing:
        failures += 1
        print(f"FAIL no capture for operation {op}")
    print(f"\n{len(manifest['fixtures'])} captures, {len(seen & operations)}/{len(operations)} operations, {failures} failing")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
