# UI ↔ contract binding (feature 005)

No contract change. The console uses these operations of `contracts/openapi-signalnoir.yaml`
unchanged:

| Operation | Console use | Fixture(s) used in tests |
|---|---|---|
| `GET /cases` | list, filters, `direction=newer` polling, `older` paging | `cases.list.needs-you.json`, `cases.list.outcome-unknown.json` |
| `GET /cases/{caseId}` | detail | `case.pending-approval.p5-p8b.json`, `case.pending-approval.superseded.json`, `case.held.p3.json`, `case.executing.outcome-unknown.json`, `case.resolved.*.json`, `case.review.*.json`, `case.resolved-by-prior-receipt.p9.json`, `case.404.json` |
| `GET /cases/{caseId}/timeline` | timeline | `timeline.full.p5-p8b.json`, `timeline.incremental.p5-p8b.json` |
| `POST /cases/{caseId}/proposals/{proposalId}/decision` | approval dialog | `decision.201.approved.json`, `decision.201.denied.json`, `decision.200.idempotent-replay.json`, `decision.409.stale-version.json`, `decision.409.invalid-transition.json`, `decision.400.denial-without-reason.json` |
| `POST /cases/{caseId}/resolution` | dossier resolution | `resolution.201.action.json`, `resolution.201.cancel.json`, `resolution.422.validator-blocked.json` |
| `GET /reference/mappings?sourceCode=` | mapping options | `reference.mappings.json` |
| `GET /reference/action-catalog` | Action options | none: the catalog is the closed contract enum `Action`; the transport answers it from that enum |

Request bodies are exactly the contract's `ProposalDecisionRequest` and `ReviewResolutionRequest`.
