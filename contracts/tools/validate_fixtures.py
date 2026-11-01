"""Validate contracts/fixtures/*.json against contracts/openapi-signalnoir.yaml.

Usage (from the repo root):
    uv run --with jsonschema --with pyyaml python contracts/tools/validate_fixtures.py [DIR]

DIR defaults to contracts/fixtures; another directory with its own manifest.json (such as the
responses captured from the implementation in tests/benchmark/contract-captures) is checked the same way.

Each manifest entry names a schema: either a component name (``CaseDetail``) or a JSON
pointer into the OpenAPI document (``#/paths/...``). OpenAPI 3.1 schemas are JSON Schema
2020-12, so they are validated as-is with the whole document as the reference root.
Exit code 1 when any fixture fails.
"""

import json
import sys
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT202012

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "contracts" / "openapi-signalnoir.yaml"
FIXTURES = ROOT / "contracts" / "fixtures"
BASE_URI = "urn:signalnoir:openapi"


def main() -> int:
    fixtures = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else FIXTURES
    spec = yaml.safe_load(CONTRACT.read_text(encoding="utf-8"))
    registry = Registry().with_resource(BASE_URI, Resource.from_contents(spec, default_specification=DRAFT202012))
    manifest = json.loads((fixtures / "manifest.json").read_text(encoding="utf-8"))
    failures = 0
    for entry in manifest["fixtures"]:
        schema = entry["schema"]
        ref = schema if schema.startswith("#") else f"#/components/schemas/{schema}"
        validator = Draft202012Validator({"$ref": f"{BASE_URI}{ref}"}, registry=registry)
        body = json.loads((fixtures / entry["file"]).read_text(encoding="utf-8"))
        errors = sorted(validator.iter_errors(body), key=lambda e: list(e.absolute_path))
        if errors:
            failures += 1
            print(f"FAIL {entry['file']} ({schema})")
            for err in errors[:8]:
                where = "/".join(str(p) for p in err.absolute_path) or "(root)"
                print(f"     {where}: {err.message[:160]}")
        else:
            print(f"ok   {entry['file']} ({schema})")
    print(f"\n{len(manifest['fixtures']) - failures} valid, {failures} invalid")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
