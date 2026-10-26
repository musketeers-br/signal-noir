"""Validate live Signal Noir API responses against contracts/openapi-signalnoir.yaml.

Dev-only conformance check of features 003 (FR-032, SC-006) and 006 (Evidence,
Proposal, Diagnosis and metrics layers of the Case detail). It reads the list,
a polling page, one Case detail, its Timeline, an unknown Case and a bad cursor,
and validates each body against the contract schema (JSON Schema 2020-12, as in
contracts/tools/validate_fixtures.py).

Usage (from the repo root):
    uv run --with jsonschema --with pyyaml --with requests \
        python tests/contract/validate_live.py --base http://localhost:52773/signalnoir/api/v1
Exit code 1 when any response fails.
"""

import argparse
import sys
from pathlib import Path

import requests
import yaml
from jsonschema import Draft202012Validator
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT202012

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "contracts" / "openapi-signalnoir.yaml"
BASE_URI = "urn:signalnoir:openapi"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    args = parser.parse_args()
    base = args.base.rstrip("/")

    spec = yaml.safe_load(CONTRACT.read_text(encoding="utf-8"))
    registry = Registry().with_resource(BASE_URI, Resource.from_contents(spec, default_specification=DRAFT202012))

    def validator(schema: str) -> Draft202012Validator:
        return Draft202012Validator({"$ref": f"{BASE_URI}#/components/schemas/{schema}"}, registry=registry)

    failures = 0

    def check(label: str, path: str, status: int, schema: str):
        nonlocal failures
        resp = requests.get(base + path, timeout=10)
        body = resp.json()
        errors = sorted(validator(schema).iter_errors(body), key=lambda e: list(e.absolute_path))
        problems = [f"status {resp.status_code} != {status}"] if resp.status_code != status else []
        problems += [f"{'/'.join(str(p) for p in e.absolute_path) or '(root)'}: {e.message[:160]}" for e in errors[:8]]
        print(f"{'FAIL' if problems else 'ok  '} {label} {path} ({schema})")
        for p in problems:
            print(f"     {p}")
        failures += bool(problems)
        return body

    page = check("list", "/cases?limit=5", 200, "CaseListPage")
    check("poll", f"/cases?direction=newer&cursor={page['headCursor']}", 200, "CaseListPage")
    if page.get("nextCursor"):
        check("next page", f"/cases?limit=5&cursor={page['nextCursor']}", 200, "CaseListPage")
    check("filters", "/cases?state=Open&state=ReviewRequired&status=open&pendingApproval=false", 200, "CaseListPage")
    for item in page["items"][:3]:
        case_id = item["caseId"]
        detail = check("detail", f"/cases/{case_id}", 200, "CaseDetail")
        if detail.get("labels", {}).get("synthetic") is not True:
            print("FAIL     detail is not labelled synthetic")
            failures += 1
        check("timeline", f"/cases/{case_id}/timeline?sinceSeq=0&limit=2", 200, "TimelinePage")
        check("timeline tail", f"/cases/{case_id}/timeline?sinceSeq={detail['lastEventSeq']}", 200, "TimelinePage")
    proposed = check("with proposals", "/cases?state=DecisionProposed&limit=2", 200, "CaseListPage")
    for item in proposed["items"]:
        detail = check("detail+proposal", f"/cases/{item['caseId']}", 200, "CaseDetail")
        if not detail.get("proposals") or not detail.get("evidence"):
            print("FAIL     DecisionProposed detail without proposals/evidence")
            failures += 1
    check("unknown case", "/cases/case_doesnotexist", 404, "ErrorEnvelope")
    check("unknown timeline", "/cases/case_doesnotexist/timeline", 404, "ErrorEnvelope")
    check("bad cursor", "/cases?cursor=not-a-cursor!", 400, "ErrorEnvelope")
    check("bad sinceSeq", f"/cases/{page['items'][0]['caseId']}/timeline?sinceSeq=-1", 400, "ErrorEnvelope")

    print(f"\n{'all responses conform' if not failures else f'{failures} failing'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
