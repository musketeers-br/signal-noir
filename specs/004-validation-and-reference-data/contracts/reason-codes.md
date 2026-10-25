# Reason codes (closed vocabulary of `SignalNoir.Core.Reasons`)

Order in this table is the pipeline order (research D3); reasons in a verdict follow it.
`*` = already used by `contracts/fixtures/`.

| Step | Code | Kind | Text (English, shown to operators) |
|------|------|------|------------------------------------|
| 1 | `REFERENCE_DATA_UNAVAILABLE` | block | No policy or mapping version is in force. |
| 2 | `ACTION_IN_CATALOG` * | pass | The action is in the closed catalog. |
| 2 | `ACTION_NOT_IN_CATALOG` | block | The action is not in the closed catalog. |
| 3 | `SCOPE_INVALID` | block | Only single-case scope is allowed. |
| 4 | `PARAMS_VALID` * | pass | The parameters match the action. |
| 4 | `PARAMS_INVALID` | block | The parameters do not match the action. |
| 4 | `REVIEW_ALWAYS_ACCEPTED` * | pass | A review request is always accepted. |
| 5 | `PRECONDITION_UNKNOWN` | block | A declared precondition is not in the closed vocabulary. |
| 6 | `MAPPING_CONDITION_MATCHES` * | pass | The approved mapping applies to this order. |
| 6 | `MAPPING_NOT_FOUND` | block | No approved mapping with this id and version is in force. |
| 6 | `MAPPING_SOURCE_CODE_ABSENT` | block | The order does not contain the mapping's source code. |
| 6 | `MAPPING_CONDITION_MISMATCH` * | block | The mapping conditions do not match the order. |
| 7 | `RETRY_BUDGET_AVAILABLE` * | pass | The attempt policy allows another attempt. |
| 7 | `RETRY_BUDGET_EXHAUSTED` | block | The attempt policy's maximum attempts was reached. |
| 8 | `PRECONDITION_FAILED_PARTNER_HEALTHY_WINDOW` | block | The partner is not healthy within the policy window. |
| 8 | `PRECONDITION_FAILED_ORDER_ACTIVE_AT_ORIGIN` | block | The order is no longer active at the origin. |
| 8 | `PRECONDITION_FAILED_APPROVAL_VALID` | block | The approval is missing, expired or for another proposal. |
| 8 | `PRECONDITION_FAILED_POLICY_VERSION_UNCHANGED` | block | The policy version changed since the proposal. |
| 8 | `PRECONDITION_FAILED_MAPPING_VERSION_UNCHANGED` | block | The mapping version changed or the mapping is gone. |
| 9 | `IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION` * | review | The order identity is ambiguous; no automatic action. |
| 10 | `REQUIRED_EVIDENCE_PRESENT` * | pass | The minimum evidence for the action is present. |
| 10 | `EVIDENCE_MISSING_POLICY` | review | The required policy evidence is missing. |
| 10 | `EVIDENCE_MISSING_ATTEMPT_HISTORY` | review | The attempt history evidence is missing. |
| 10 | `EVIDENCE_MISSING_PARTNER_HEALTH` | review | Recent partner health evidence is missing. |
| 10 | `EVIDENCE_MISSING_MAPPING` | review | Evidence of the approved mapping is missing. |
| 10 | `EVIDENCE_MISSING_ORDER_FIELD` | review | Evidence of the order field the mapping depends on is missing. |
| 10 | `EVIDENCE_MISSING_HEALTH_OR_WINDOW` | review | Neither partner health nor a maintenance window is in evidence. |
| 11 | `CONFIDENCE_LOW` | review | The proposal's confidence is low. |
| 12 | `EQUIVALENCE_KEY_MATCH` * | pass | The prior receipt is for the same order. |
| 12 | `EQUIVALENCE_KEY_MISMATCH` | review | The prior receipt's order differs from this order. |
| A | `ACTOR_BENCHMARK_OUTSIDE_RUN` | refuse | The benchmark actor can approve only inside a benchmark run. |
| A | `ACTOR_NOT_ALLOWED_TO_APPROVE` | refuse | This actor cannot approve. |

Step `A` codes are returned by `Admit`, not in a verdict. Dossier mapping (for 009):
`validator_blocked` ← any block code; `missing_evidence` ← `EVIDENCE_MISSING_*`; `low_confidence` ←
`CONFIDENCE_LOW`; `ambiguous_identity` ← `IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION`;
`prior_receipt_unconfirmed` ← `EQUIVALENCE_KEY_MISMATCH`.
