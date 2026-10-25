# Phase 0 Research: Validator and Versioned Reference Data

**Date**: 2026-10-24
**Inputs**: [spec.md](./spec.md), `contracts/openapi-signalnoir.yaml` (frozen), `contracts/fixtures/`
(frozen), `docs/seams.md` v1, the 001 code (`SignalNoir.Core.*`, `SignalNoir.Application.CaseService`,
`SignalNoir.Api.Dispatch`), architecture AD-9, AD-12, AD-19, AD-25, AD-26.

Platform facts verified by 001 through iris-agentic-dev are cited as "001-Vn". New platform claims
are in **Verification backlog** and MUST be verified with throwaway probes through iris-agentic-dev
before `/speckit-implement` (iris-agentic-dev was not reachable from the planning session).

---

## D1 — Where the rules live

- **Decision**: All validation rules live in the Core, in `SignalNoir.Core.Validator` (rewritten;
  owned by this feature from now on) plus `SignalNoir.Core.Reasons` (closed reason vocabulary) and
  `SignalNoir.Core.Conditions` (canonical matching of Mapping conditions). Inputs arrive as one
  immutable `SignalNoir.Core.Dto.ValidationInput`, reference data as an immutable
  `SignalNoir.Core.Dto.ReferenceData` snapshot. The Core does no I/O.
- **Rationale**: Principles I and III and FR-016: one origin-blind gate, testable exhaustively without
  a database or an instance.
- **Alternatives considered**: reading reference data inside the Validator (I/O in the Core);
  a Validator per origin (forbidden by Principle III).

## D2 — Seam contract change (Validator v2)

- **Decision**: Publish `docs/seams.md` **v2** for the Validator only, as an explicit contract change
  ([contracts/contract-change-004-validator-seam.md](./contracts/contract-change-004-validator-seam.md)):
  - `ValidatorVerdict` becomes `{verdict: accepted|blocked|review|prior_receipt_confirmed, reasons[],
    requiresApproval, versions{policy, mapping}, at}` — the product contract's shape plus the versions.
  - The port gets three operations: `Validate(input)`, `Revalidate(input)` (adds
    `PreconditionResult[]`) and `Admit(actor, runContext)`.
  - `FakeValidator` becomes configurable on the new shape; its default is `accepted`,
    `requiresApproval = true`, reasons `[ACTION_IN_CATALOG]`.
- **When**: the document change is applied to `docs/seams.md` on master **now** (contract work is
  allowed before 2026-10-26), in its own small commit, so that 006 (Henry) plans against v2. The code
  change of the DTO, port, fake and the 001 seam tests is the first implementation task of this
  feature.
- **Rationale**: v1 (`valid/invalid`, `Validate(proposal)`) cannot carry FR-013/FR-016. Rule 6 of the
  parallelism guide: a divergence becomes a contract change, never a merge-time fix. No consumer
  depends on v1 yet, so the change is cheap today.
- **Alternatives considered**: keeping v1 and mapping `invalid` to `blocked` (loses `review`,
  reasons and approval flag); an adapter translating v2 to v1 (two shapes for one rule).

## D3 — Verdict composition and precedence

- **Decision**: One fixed pipeline, evaluated in this order; each step yields a pass code or a fail
  code with a class (`block` or `review`):

  | # | Step | Pass code | Fail code (class) |
  |---|------|-----------|-------------------|
  | 1 | reference data in force | — | `REFERENCE_DATA_UNAVAILABLE` (block) |
  | 2 | Action in catalog | `ACTION_IN_CATALOG` | `ACTION_NOT_IN_CATALOG` (block) |
  | 3 | scope | — | `SCOPE_INVALID` (block) |
  | 4 | parameters | `PARAMS_VALID` | `PARAMS_INVALID` (block) |
  | 5 | declared preconditions known | — | `PRECONDITION_UNKNOWN` (block) |
  | 6 | Mapping exists / source code / conditions | `MAPPING_CONDITION_MATCHES` | `MAPPING_NOT_FOUND`, `MAPPING_SOURCE_CODE_ABSENT`, `MAPPING_CONDITION_MISMATCH` (block) |
  | 7 | retry budget | `RETRY_BUDGET_AVAILABLE` | `RETRY_BUDGET_EXHAUSTED` (block) |
  | 8 | preconditions evaluated (Revalidate only) | — | `PRECONDITION_FAILED_<CHECK>` (block) |
  | 9 | identity | — | `IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION` (review) |
  | 10 | minimum Evidence | `REQUIRED_EVIDENCE_PRESENT` | `EVIDENCE_MISSING_*` (review) |
  | 11 | confidence | — | `CONFIDENCE_LOW` (review) |
  | 12 | prior receipt (only with a candidate) | `EQUIVALENCE_KEY_MATCH` | `EQUIVALENCE_KEY_MISMATCH` (review) |
  | — | `REQUEST_REVIEW` short-circuit after step 4 | `REVIEW_ALWAYS_ACCEPTED` | — |

  Steps 1–4 stop the pipeline on failure (later steps need a well-formed Proposal); steps 5–12 all run.
  Result: any `block` → `blocked`; else any `review` → `review`; else `prior_receipt_confirmed` if
  step 12 passed, else `accepted`.
- **Reasons list**: for `blocked` and `review`, the fail codes only, in step order. For `accepted`,
  the pass codes of the steps that apply, in step order: `PARAMS_VALID` only for an Action that takes
  mandatory parameters (`APPLY_APPROVED_MAPPING`); `MAPPING_CONDITION_MATCHES` only when the Mapping
  has conditions; `RETRY_BUDGET_AVAILABLE` only for `RETRY`. `REQUEST_REVIEW` yields
  `[REVIEW_ALWAYS_ACCEPTED]`, followed by `IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION` as an informational
  code when the identity is ambiguous. `prior_receipt_confirmed` yields `[EQUIVALENCE_KEY_MATCH]`.
- **Fixture check**: these rules reproduce 13 of the 14 verdicts in `contracts/fixtures/` (checked
  with a script on 2026-10-24). The exception is `resolution.201.action.json`: an Operator
  `APPLY_APPROVED_MAPPING` with the conditional `map_glicj_plasma`, whose reasons are
  `[ACTION_IN_CATALOG, PARAMS_VALID]` — missing `MAPPING_CONDITION_MATCHES` and
  `REQUIRED_EVIDENCE_PRESENT`. Principle III forbids a lighter rule for the Operator, so the fixture
  (generated by the prototype mock) is wrong, not the rule. Recorded in
  [contracts/contract-change-004-validator-seam.md](./contracts/contract-change-004-validator-seam.md)
  §Fixture divergence: the mock is fixed and the fixtures regenerated, never edited by hand
  (`contracts/fixtures/README.md`).
- **Rationale**: FR-015 (blocked over review, fixed order), fixture compatibility, Principle III.

## D4 — Reason vocabulary

- **Decision**: `SignalNoir.Core.Reasons` holds the closed list as a parameter plus an English text
  per code ([contracts/reason-codes.md](./contracts/reason-codes.md)); `IsReason(code)` and
  `Text(code)`. The verdict carries codes only (the contract field is `reasons: string[]`).
- **Rationale**: FR-014; the contract does not close the strings, so the Core does, starting from the
  9 codes used by fixtures.

## D5 — Reference data as versioned XData fixtures

- **Decision**: Policies and Mappings are separate versioned fixtures, because the contract versions
  them separately (`fixtureSet.policyVersion`, `fixtureSet.mappingVersion`, `Proposal.versions.policy`,
  `.mapping`):
  - `SignalNoir.Application.Reference.Policies.V2026101` — `XData Content` JSON, `Parameter VERSION =
    "2026.10.1"`.
  - `SignalNoir.Application.Reference.Mappings.V2026101` — same; items identical to
    `contracts/fixtures/reference.mappings.json` (a test asserts equality), plus the condition-field
    synonym list.
  - `SignalNoir.Application.Reference.Store` lists the fixture classes through the class dictionary,
    validates each (FR-024), builds an immutable `ReferenceData` snapshot per `(policyVersion,
    mappingVersion)` and keeps the versions in force in `^SignalNoir.Reference("inForce")`. With no
    explicit choice, the highest version of each loads lazily on first use, so no bootstrap change is
    needed.
- **Rationale**: compiled with the module, no file path or Dockerfile change (integration files),
  reviewable in git, same idiom as the Simulator catalog (002 D7). A new version is a new class; old
  versions stay available for pinned runs.
- **Alternatives considered**: JSON files under `fixtures/` (needs image/module changes); globals seeded
  by a script (state, not code).
- **Verification backlog**: V1.

## D6 — Policy content (version 2026.10.1)

- **Decision**: one JSON document with:
  - `attempt`: `{ "maxAttempts": 3 }`
  - `substitution`: `{ "enabled": true }` (APPLY_APPROVED_MAPPING allowed when a Mapping applies)
  - `maintenanceWindows`: `[]` per partner (`{partnerId, startsAt, endsAt}`), consulted together with
    the window the Partner announces (002 SIM-Q2)
  - `partnerHealth`: `{ "windowSeconds": 300, "maxErrorRate": 0.2 }`
  - `approval`: `{ "RETRY": true, "APPLY_APPROVED_MAPPING": true, "HOLD": false, "REQUEST_REVIEW":
    false, "deadlineSeconds": 900 }`
- **Rationale**: the smallest set that makes every rule in the spec data-driven and versioned (FR-011,
  FR-021, FR-023). Values are reviewable defaults; changing one is a new version.
- **Note**: `approval` cannot make `RETRY`/`APPLY_APPROVED_MAPPING` approval-free outside a run: the
  loader refuses such a version (Principle IV), so the policy is data but the invariant is code.

## D7 — Canonical condition matching

- **Decision**: Known condition fields and their Order paths: `specimenType` → `specimen.type`,
  `specimenUnit` → `specimen.unit`. Values are compared after trim, upper-case and synonym lookup from
  the Mapping fixture (`"synonyms": {"specimenType": {"PLASMA": ["PLASMA"], "SERUM": ["SERUM", "SORO"]}}`).
  Exam codes compare after trim and upper-case. A condition on an unknown field fails the fixture
  load (FR-024); on an absent Order field it does not match.
- **Rationale**: FR-005; the Simulator's raw Orders carry `plasma`/`soro` while the fixture carries
  `PLASMA`/`SERUM`.

## D8 — Validation Input and Evidence kinds (cross-feature contract)

- **Decision**: [contracts/validation-input.md](./contracts/validation-input.md) fixes what the caller
  passes. Minimum Evidence is recognised by `Evidence.source` from the contract enum and a small
  `facts` convention:

  | Required item | Recognised Evidence |
  |---|---|
  | attempt policy | `tool.policies` with `facts.policy = "attempt"` |
  | substitution policy | `tool.policies` with `facts.policy = "substitution"` |
  | maintenance window | `tool.policies` with `facts.policy = "maintenance"` |
  | attempt history | `tool.partner_failure_history` |
  | recent partner health | `tool.partner_health` |
  | approved Mapping | `tool.mapping_catalog` with `facts.mappingId` = the Proposal's |
  | Order field | `tool.order_timeline` (or the Order snapshot evidence) with `facts.field` = the condition's Order path |

  Evidence counts only if `caseId` matches, it is not obsolete and `suspicious = false`.
- **Rationale**: FR-006/FR-007 need a deterministic way to recognise Evidence; the contract fixes
  `source` but not the payload. The convention is small and owned here.
- **Open dependency**: 006 (Henry) produces this Evidence; the convention must be confirmed with him
  before 006's plan. Flagged in the seam contract change.

## D9 — Recording the verdict

- **Decision**: `SignalNoir.Application.ValidationService.ValidateAndRecord(caseId, input)` calls the
  Core Validator and appends a `ValidatorVerdict` timeline event through `CaseService.Append`
  (attachment; does not bump `caseVersion`) with payload `{proposalId, verdict, reasons,
  requiresApproval, versions}`. The Proposal's `validatorVerdict` in the API is the projection of the
  latest such event for that `proposalId`; the Proposal record and its projection belong to 006.
- **Rationale**: FR-018 without 004 owning the Proposal record; `Append` already exists in the seam
  (`CaseCommands.Append`) and `ValidatorVerdict` is in the contract's `TimelineEventType`.

## D10 — Reference endpoints

- **Decision**: a new `%CSP.REST` class `SignalNoir.Api.Reference` serves `GET /action-catalog` and
  `GET /mappings`, reached through a forward `<Map Prefix="/reference" Forward="SignalNoir.Api.Reference"/>`
  in `SignalNoir.Api.Dispatch`. The forward line is a **G1 integration change**; until then tests call
  `SignalNoir.Api.Reference` payload methods directly and over HTTP through a test-only web
  application.
- **Rationale**: keeps 004 out of 001's (and 003's) `Dispatch.cls` during development.
- **Verification backlog**: V2.

## D11 — Run pinning and actor admissibility

- **Decision**: `ValidationInput.run = {inRun, runId, policyVersion, mappingVersion}`. The caller (003
  copies run flags when the Case opens; 010 creates runs) supplies it; `Store.For(run)` returns the
  pinned snapshot or the one in force. `Validator.Admit(actor, run)` returns `{admissible, label
  (human|automatic), reason}`; 007 maps a refusal to 403 `INVALID_ACTOR`.
- **Rationale**: FR-012, FR-025, AD-19, AD-23.

## D12 — Preconditions (Revalidation)

- **Decision**: `Revalidate(input)` runs the whole pipeline plus step 8 using `input.observed`
  (`partnerHealth {status, errorRate, windowSeconds}`, `maintenance {active}` from Partner and from
  policy, `originStatus`, `approval {proposalId, deadline}`, `proposalCurrent`, `policyVersionInForce`,
  `mappingVersionInForce`, `mappingExists`, `now`). Each check returns `PreconditionResult {check,
  expected, observed, passed, evidenceId}`. Only these values feed step 8, so other new Evidence cannot
  change the outcome (FR-022).
- **Rationale**: FR-019–FR-022; 008 owns gathering the observed values and the transition to `Held`.

## D13 — Determinism and "no I/O" checks

- **Decision**: (a) every test validates twice and compares the serialized verdicts; (b) a static test
  scans the compiled methods of `SignalNoir.Core.Validator`, `Reasons`, `Conditions` and the input
  DTOs for global references (`^`), `%Persistent`/`%Net`/`%File`/`%SQL` usage, `$ZF`, `$HOROLOG`,
  `$ZTIMESTAMP`, `$NOW`, `Open`/`Use`/`Read`/`Write` and `$RANDOM`; any hit fails.
- **Rationale**: FR-016, SC-003, SC-005 made checkable.

## D14 — Performance budget

- **Decision**: a single `Validate` on a typical input completes in ≤ 50 ms on the dev container; a
  test runs 1000 validations and asserts the mean.
- **Rationale**: SC-005 ("well under one second") turned into a number.

---

## Verification backlog (iris-agentic-dev, before `/speckit-implement`)

| # | Claim | Needed by |
|---|-------|-----------|
| V1 | `%Dictionary.CompiledXData` (or `##class(%Dictionary.XDataDefinition)`) returns the JSON of a compiled `XData` block on build 154, and listing subclasses of a package works through `%Dictionary.CompiledClass` | D5 |
| V2 | A `<Map Prefix=… Forward=…>` in a `%CSP.REST` `UrlMap` forwards to another `%CSP.REST` class on build 154 | D10 |
| V3 | A test-only web application (`/signalnoir/test/reference`) can be created and removed from a `%UnitTest` | D10 |

## Verification log

_Empty — to be filled with throwaway probes through iris-agentic-dev before `/speckit-implement`._
