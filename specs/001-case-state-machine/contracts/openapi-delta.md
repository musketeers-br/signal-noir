# Contract: proposed changes to `openapi-signalnoir.yaml` (input to story 2.5)

Nothing here is applied to the OpenAPI in this story (research R3). Each item becomes an entry marked `pendingContractChange: "2.5"` (with `contractChanges` naming the item) in the state-machine YAML, and the validator lists them.

| # | Where | Change | Origin |
|---|---|---|---|
| C1 | `CaseHeader` | `previousEpisodeCaseId`: `CaseId` or `null` | FR-004, T02 |
| C2 | `Dossier.reason` | new value `outcome_unknown` | T26, D4 |
| C3 | `TimelineEvent.payload` for `Annotation` | `{ kind: receipt_corrected \| receipt_missing \| new_episode_opened \| note, ... }` | D5, FR-004 |
| C4 | `TimelineEvent.payload` for `CommandDiscarded` | `{ command, actor, currentState, requestedState, code }` with `code` ∈ `INVALID_TRANSITION`, `INVALID_ACTOR`, `STALE_VERSION`, `APPROVAL_EXPIRED` | FR-012 |
| C5 | `CaseSummary.executionOutcome` (description) | `reconciling` also with the Case in `ReviewRequired` | T26 |
| C6 | `x-open-questions` | close API-Q5 (the resolution goes through `ReviewRequired → DecisionProposed → PendingApproval → Approved`, one `StateChanged` per step) and API-Q3 (no `REQUEST_REVIEW` in the resolution) | T28, edge cases |
| C7 | `ErrorCode` | decide with API-Q2 whether `APPROVAL_EXPIRED` leaves through the API; it is used only internally (T17), so the proposal is **not** to expose it | T17 |
| C8 | Fixtures | `case.pending-approval.superseded` must show T16 (new Exception) or T04 (new Proposal), depending on the scenario; add a fixture of `ReviewRequired` with `outcome_unknown` and one of a Case with `previousEpisodeCaseId` | C1, C2 |

`CaseState` and `TimelineEventType` do **not** change.

Story 2.5 must also translate the contract's descriptions, summaries, example prose and open questions to English (Constitution 1.1.0, Language).
