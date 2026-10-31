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
| 3 | `Core/ActionCatalog.cls` | `Entries()` fills `requiredEvidence` (it returns `[]` today). `RequiresApproval` already returns `ExternalEffect(action)` on master (merged with 009b), so `REQUEST_REVIEW` is already false, as PRD FR-16 and the fixtures (`requiresApproval: false`) require; nothing to change there. | T010 |
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
2. **REQUEST_REVIEW approval**: the endpoint `GET /reference/action-catalog` and the verdict must
   report the same `requiresApproval`. This already holds on master (edit 3); the request is a test
   on Henry's side that pins the equality.

## For 008 (Henrique)

- `Revalidate(input)` is pure (004, US5); recording `RevalidationPerformed` and the transition to
  `Held` stay in 008. 004 provides no `RevalidateAndRecord`.
- The attempt count passed in `ValidationInput` is 0 until 008 records Attempts; the `RETRY` budget
  rule (`RETRY_BUDGET_EXHAUSTED`) is exercised in 004's tests with a supplied count.

## For 007 (Henrique)

- `Admit(actor, run)` and the Approval deadline (`policies.approval.deadlineSeconds`) are 004's
  surface for Approval; 007 reuses `ApprovalRecord` from 009.

## Decision (T002, 2026-10-31)

Walked with Henry on 2026-10-31.

- Edits 1–6: **agreed as written**, no adjustments. Order: 6, then 3, then 1 and 2 together, then 4
  and 5 (US2+).
- Baseline requests 1 (Rules calls `Core.Conditions.Matches`) and 2 (a test pins `requiresApproval`
  of `REQUEST_REVIEW` between the catalog endpoint and the verdict): **accepted** for Henry's wave 4.
- T045 of spec 001 (second member approves the 001 contract change): **approved**.

Applied the same day, in the agreed order (uncommitted on `004-validation-and-reference-data`):
edit 6 with T003–T006 (seam v2 verdict, port, `FakeValidator`, consumer and seam tests), edit 3 with
T009–T010 (`requiredEvidence`; `|` joins alternatives, as for `HOLD`), edits 1–2 with T018–T019
(`InputFor`, `Verdict(validator, input)`, `versions` on the stored verdict and the event). Until T017,
`Core.Validator` returns the v2 shape with the slice-1 rules. Edits 4–5 wait for US2+ (T037).
