# Coordination of 004 with 006, 009 (Henry) and 008 (Henrique)

Counterpart of `specs/009-review-dossier-and-resolution/contracts/coordination-004-007.md`. No change
to `contracts/openapi-signalnoir.yaml`. The items below are small edits to files that 003, 006 and 009
already merged; each is agreed with Henry **before** the 004 task that makes it starts, and each is
listed with the 004 task that carries it.

## Edits to files owned by 003 / 006 / 009

| # | File | Edit | 004 task |
|---|------|------|----------|
| 1 | `Application/ResolutionValidator.cls` | `Verdict(validator, proposal, now)` becomes `Verdict(validator, input)` with a new `InputFor(rec, proposal, now)` that builds the Validation Input (contracts/validation-input.md). The 009 note says "only the body changes"; the callers must also pass what the v2 input needs. Returns the contract verdict including `versions`. | T015 |
| 2 | `Application/CaseService.cls` | The two call sites, `CompleteInvestigation` and `ResolveReview`, call `InputFor`. The `ValidatorVerdict` event payload gains `versions`. | T015 |
| 3 | `Core/ActionCatalog.cls` | `RequiresApproval` returns `ExternalEffect(action)`: `REQUEST_REVIEW` becomes false (PRD FR-16: only effectful Actions need Approval; the fixtures record `requiresApproval: false` for `REQUEST_REVIEW`). `Entries()` fills `requiredEvidence`. | T010 |
| 4 | `Tools/LocalSource.cls` | `tool.policies` and `tool.mapping_catalog` answer from the Store instead of "reference data not loaded". Absent when nothing is loaded. | T037 |
| 5 | `Api/Dispatch.cls` | `Mappings()` serves the Store instead of the `"unloaded"` placeholder. | T037 |
| 6 | `tests/.../Fakes/FakeValidator.cls`, `Consumer.cls`, `TestConsumerUsesSeam.cls`, `TestResolution.cls`, `TestDossier.cls` | v2 shape: `accepted`/`blocked` instead of `valid`/`invalid`. | T003, T006 |

## Requests for the baseline (Henry, wave 4)

1. **Rules and specimen synonyms.** `Proposers/Rules` matches a Mapping with
   `$ZConvert(...,"U")` equality on `specimen.type`. The contract's own examples of raw Orders use
   `soro`/`plasma` (the Simulator's variants may emit them; 002 has not written them yet) while the
   fixtures carry `SERUM`/`PLASMA`, so Rules would find no Mapping where the Validator would accept
   one: a weaker baseline than the platform allows (Principle VIII). Call
   `Core.Conditions.Matches(conditions, order, result.synonyms)` (004, US2) so Rules and the
   Validator agree.
2. **REQUEST_REVIEW approval**, edit 3 above: the endpoint `GET /reference/action-catalog` and the
   verdict must report the same `requiresApproval`.

## For 008 (Henrique)

- `Revalidate(input)` is pure (004, US5); recording `RevalidationPerformed` and the transition to
  `Held` stay in 008. 004 provides no `RevalidateAndRecord`.
- The attempt count passed in `ValidationInput` is 0 until 008 records Attempts; the `RETRY` budget
  rule (`RETRY_BUDGET_EXHAUSTED`) is exercised in 004's tests with a supplied count.

## For 007 (Henrique)

- `Admit(actor, run)` and the Approval deadline (`policies.approval.deadlineSeconds`) are 004's
  surface for Approval; 007 reuses `ApprovalRecord` from 009.
