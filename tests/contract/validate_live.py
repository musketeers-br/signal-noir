"""Validate live Signal Noir API responses against contracts/openapi-signalnoir.yaml.

Dev-only conformance check of features 003 (FR-032, SC-006), 006 (Evidence,
Proposal, Diagnosis and metrics layers of the Case detail), 009 (Dossier,
resolution answers, reference data) and 007 (decision answers). The 009 part cancels one ReviewRequired
test case and the 007 part approves one PendingApproval test case. It reads the list,
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
        ref = schema if schema.startswith("#") else f"#/components/schemas/{schema}"
        return Draft202012Validator({"$ref": f"{BASE_URI}{ref}"}, registry=registry)

    failures = 0

    def check(label: str, path: str, status: int, schema: str, body=None):
        nonlocal failures
        resp = requests.get(base + path, timeout=10) if body is None else requests.post(base + path, json=body, timeout=10)
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
    proposed = check("with proposals", "/cases?state=PendingApproval&limit=50", 200, "CaseListPage")
    # backend tests leave PendingApproval cases with a fixture proposal and no evidence;
    # every detail must conform, and at least one investigated case must carry evidence
    investigated = 0
    for item in [i for i in proposed["items"] if i.get("currentProposal")][:10]:
        detail = check("detail+proposal", f"/cases/{item['caseId']}", 200, "CaseDetail")
        investigated += bool(detail.get("proposals") and detail.get("evidence"))
    if proposed["items"] and not investigated:
        print("FAIL     no PendingApproval detail with proposals and evidence")
        failures += 1
    # feature 007: the decision on the exact Proposal
    waiting = [i for i in proposed["items"] if i.get("currentProposal")]
    if waiting:
        item = waiting[-1]
        case_id, version, proposal_id = item["caseId"], item["caseVersion"], item["currentProposal"]["proposalId"]
        path = f"/cases/{case_id}/proposals/{proposal_id}/decision"
        check("decision 400", path, 400, "ErrorEnvelope", {"decision": "denied", "operator": "Carla", "expectedCaseVersion": version})
        stale = check("decision 409", path, 409, "ErrorEnvelope", {"decision": "approved", "operator": "Carla", "expectedCaseVersion": version + 100})
        if stale.get("error", {}).get("details", {}).get("currentProposalId") != proposal_id:
            print("FAIL     409 without the current proposal")
            failures += 1
        check("decision 404", "/cases/case_doesnotexist/proposals/prop_x/decision", 404, "ErrorEnvelope", {"decision": "approved", "operator": "Carla", "expectedCaseVersion": 1})
        created = check("decision 201", path, 201, "ProposalDecisionResult", {"decision": "approved", "operator": "Carla", "expectedCaseVersion": version})
        replay = check("decision 200", path, 200, "ProposalDecisionResult", {"decision": "approved", "operator": "Carla", "expectedCaseVersion": version})
        if not replay.get("idempotentReplay") or replay.get("approval", {}).get("approvalId") != created.get("approval", {}).get("approvalId"):
            print("FAIL     replay did not return the same approval")
            failures += 1
    else:
        print("skip     no PendingApproval case with a proposal; decision answers not exercised")
    # feature 009: review dossier, resolution answers and reference data
    review = check("in review", "/cases?state=ReviewRequired&limit=3", 200, "CaseListPage")
    for item in review["items"][:1]:
        detail = check("detail+dossier", f"/cases/{item['caseId']}", 200, "CaseDetail")
        if not detail.get("dossier"):
            print("FAIL     ReviewRequired detail without dossier")
            failures += 1
    if len(review["items"]) >= 2:
        case_id, version = review["items"][1]["caseId"], review["items"][1]["caseVersion"]
        path = f"/cases/{case_id}/resolution"
        check("resolution 400", path, 400, "ErrorEnvelope", {"kind": "action", "operator": "Carla", "expectedCaseVersion": version, "action": "RETRY", "payload": {}})
        check("resolution 409", path, 409, "ErrorEnvelope", {"kind": "cancel", "operator": "Carla", "expectedCaseVersion": version + 100, "reason": "x"})
        blocked = check("resolution 422", path, 422, "ErrorEnvelope", {"kind": "action", "operator": "Carla", "expectedCaseVersion": version, "action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_soro"}})
        if not blocked.get("error", {}).get("details", {}).get("verdict", {}).get("reasons"):
            print("FAIL     422 without verdict reasons")
            failures += 1
        check("resolution 201", path, 201, "ReviewResolutionResult", {"kind": "cancel", "operator": "Carla", "expectedCaseVersion": version, "reason": "conformance check"})
    else:
        print("skip     fewer than two ReviewRequired cases; resolution answers not exercised")
    check("action catalog", "/reference/action-catalog", 200, "#/paths/~1reference~1action-catalog/get/responses/200/content/application~1json/schema")
    check("mappings", "/reference/mappings?sourceCode=GLIC-J", 200, "#/paths/~1reference~1mappings/get/responses/200/content/application~1json/schema")
    check("unknown case", "/cases/case_doesnotexist", 404, "ErrorEnvelope")
    check("unknown timeline", "/cases/case_doesnotexist/timeline", 404, "ErrorEnvelope")
    check("bad cursor", "/cases?cursor=not-a-cursor!", 400, "ErrorEnvelope")
    check("bad sinceSeq", f"/cases/{page['items'][0]['caseId']}/timeline?sinceSeq=-1", 400, "ErrorEnvelope")

    print(f"\n{'all responses conform' if not failures else f'{failures} failing'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
