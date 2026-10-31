# Phase 0 Research: Validator and Versioned Reference Data

**Date**: 2026-10-24, revised 2026-10-26 against `master` (003, 005, 006, 009 merged)
**Inputs**: [spec.md](./spec.md), `contracts/openapi-signalnoir.yaml` (frozen), `contracts/fixtures/`
(frozen), `docs/seams.md` v4, the code on `master` (`SignalNoir.Core.*`, `SignalNoir.Application.
CaseService`, `ResolutionValidator`, `ToolGateway`, `SignalNoir.Tools.*`, `SignalNoir.Api.Dispatch`),
`specs/009-.../contracts/coordination-004-007.md`, architecture AD-9, AD-12, AD-19, AD-25, AD-26.

**Revision summary (2026-10-26)**: confidence is `HIGH/MEDIUM/LOW`; Evidence convention rewritten on
the real Evidence DTO; no `Core.Catalog`, `ValidationService` or `Api.Reference` (their jobs already
exist on `master` and are extended); identity derived, not passed; approval rule is the catalog's;
`tool.policies` and `tool.mapping_catalog` become 004's to serve. Details in D1, D6, D8–D10, D15.

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
- **Reuse on `master`**: `SignalNoir.Core.ActionCatalog` already holds the closed catalog (entries,
  `ExternalEffect`, `RequiresApproval`, `AllowedParams`); this feature extends it and creates no
  second catalog. `SignalNoir.Core.Identity.Collisions(evidence, order)` already decides ambiguous
  identity for the Rules proposer and the Dossier; the Validator calls it. `Core.ProposalShape` and
  `Core.ResolutionShape` already refuse malformed answers before the Validator; the Validator keeps
  its own catalog/params/scope checks because it must not trust whoever built the Proposal.
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
- **When**: the document change landed on `master` on 2026-10-24 (v2; v3 and v4 by 003 and 006 since).
  The code still implements v1 (`valid`/`invalid`), and `ResolutionValidator` accepts both. The code
  change of the DTO, port, fake and the seam/resolution tests is the first implementation task of
  this feature. Revision: `identity` leaves `ValidationInput` (derived by the Validator, D1).
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
- **Fixture check** (corrected 2026-10-26): a script listed the 13 verdicts found in
  `contracts/fixtures/`; the comparison with these rules was done by reading, not by running a rule
  engine. Reading, 12 of the 13 agree with the rules above; the executable check is
  `TestFixtureVerdicts` (task T042). The exception is `resolution.201.action.json`: an Operator
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
  - `approval`: `{ "deadlineSeconds": 900 }`
- **Rationale**: the smallest set that makes the rules that really vary data-driven and versioned
  (FR-021, FR-023). Values are reviewable defaults; changing one is a new version.
- **Revision 2026-10-26**: the first draft also kept a per-Action `approval` map. It is dropped:
  which Actions need Approval (PRD FR-16: those with an external effect) is a constitutional rule
  (Principle IV), not tunable data, and `Core.ActionCatalog` already encodes it. Keeping two copies
  would let them drift. `requiresApproval` = `ActionCatalog.ExternalEffect(action)`; only the
  Approval deadline is versioned.
- **Finding for Henry**: `ActionCatalog.RequiresApproval` returns true for `REQUEST_REVIEW`
  (`RETRY`, `APPLY_APPROVED_MAPPING` and `REQUEST_REVIEW`). That contradicts FR-16 and every fixture
  (`REVIEW_ALWAYS_ACCEPTED` verdicts carry `requiresApproval: false`). The 009 routing sends
  `REQUEST_REVIEW` to `ReviewRequired` regardless, so nothing breaks today, but
  `GET /reference/action-catalog` reports the wrong value. Fixed with `ExternalEffect` (coordination
  item 3).

## D7 — Canonical condition matching

- **Decision**: Known condition fields and their Order paths: `specimenType` → `specimen.type`,
  `specimenUnit` → `specimen.unit`. Values are compared after trim, upper-case and synonym lookup from
  the Mapping fixture (`"synonyms": {"specimenType": {"PLASMA": ["PLASMA"], "SERUM": ["SERUM", "SORO"]}}`).
  Exam codes compare after trim and upper-case. A condition on an unknown field fails the fixture
  load (FR-024); on an absent Order field it does not match.
- **Rationale**: FR-005; the contract's own examples of raw Orders use `plasma`/`soro` while the
  fixture carries `PLASMA`/`SERUM`, and the Simulator's variants (002) may emit either.

## D8 — Validation Input and Evidence kinds (cross-feature contract)

- **Decision** (rewritten 2026-10-26 on the real Evidence DTO of 006):
  [contracts/validation-input.md](./contracts/validation-input.md) fixes what the caller passes.
  Minimum Evidence is recognised by `Evidence.source` and by the keys present in `Evidence.result`;
  there is no `facts` convention and no `obsolete` flag (the DTO has `obsoletedBy`):

  | Required item | Recognised Evidence |
  |---|---|
  | attempt policy | `tool.policies`, `result.attempt` defined |
  | substitution policy | `tool.policies`, `result.substitution` defined |
  | maintenance window | `tool.policies`, `result.maintenanceWindows` defined |
  | attempt history | `tool.partner_failure_history` |
  | recent partner health | `tool.partner_health` |
  | approved Mapping | `tool.mapping_catalog`, `result.items[]` has the Proposal's `mappingId` + `mappingVersion` |
  | Order field | the Order the Case holds has the condition's Order path (no Tool call) |

  Evidence counts only if `caseId` matches, `kind = fact`, `obsoletedBy` is empty and `suspicious` is
  false. `kind = absence` never counts (Principle VII).
- **Rationale**: FR-006/FR-007 need a deterministic way to recognise Evidence. The Tools gateway
  (006) already records `source`, `kind` and the raw `result`, and the base Investigation package
  (`tool.partner_health`, `tool.partner_failure_history`, `tool.origin_order_status`,
  `tool.mapping_catalog`, `tool.policies`, `tool.receipts_and_orders_by_patient`) spends the whole
  budget of 6 calls, so `tool.order_timeline` is never in a Case: the Order field must come from the
  Order itself.
- **No open dependency**: the earlier request to Henry about an Evidence convention is withdrawn.

## D9 — Recording the verdict

- **Decision** (rewritten 2026-10-26): no `ValidationService`. `CaseService.CompleteInvestigation` and
  `CaseService.ResolveReview` already call `ResolutionValidator.Verdict`, store the verdict on the
  Proposal (`ProposalRecord.verdictJson`), append a `ValidatorVerdict` event and route the Case
  (`RouteProposal`). 004 changes that adapter: `InputFor(rec, proposal, now)` builds the Validation
  Input from the Case record, `Verdict(validator, input)` returns the contract verdict with
  `versions`, and the event payload gains `versions`. The 009 note says "only the adapter's body
  changes"; in fact `Verdict(validator, proposal, now)` has no Evidence, Order or run, so both call
  sites change too (coordination items 1 and 2).
- **Rationale**: FR-018 is already met by the Case command path; a second recorder would duplicate
  events. Revalidation is not a `ValidatorVerdict`: it is a `RevalidationPerformed` event recorded
  by 008, so 004 provides no `RevalidateAndRecord`.

## D10 — Reference endpoints

- **Decision** (rewritten 2026-10-26): no new REST class. `SignalNoir.Api.Dispatch` already routes
  `/reference/action-catalog` (served from `Core.ActionCatalog.Entries()`) and `/reference/mappings`
  (a placeholder: `mappingVersion: "unloaded"`, `items: []`). 004 replaces the body of
  `Dispatch.Mappings()` to serve the Store (with the `sourceCode` filter) and fills
  `requiredEvidence` in the catalog entries. Both are one-method edits in files owned by earlier
  features (coordination items 3 and 5).
- **Rationale**: the routes exist and the console (005) already calls them; a second class and a
  forward would duplicate the surface. Tests call the Dispatch payload methods, as 009's
  `TestResolutionApi` does.

## D11 — Run pinning and actor admissibility

- **Decision**: `ValidationInput.run = {inRun, runId, policyVersion, mappingVersion}`. The caller (003
  copies run flags when the Case opens; 010 creates runs) supplies it; `Store.For(run)` returns the
  pinned snapshot or the one in force. `Validator.Admit(actor, run)` returns `{admissible, label
  (human|automatic), reason}`; 007 maps a refusal to 403 `INVALID_ACTOR`.
- **Rationale**: FR-012, FR-025, AD-19, AD-23.

## D12 — Preconditions (Revalidation)

- **Decision**: `Revalidate(input)` runs the whole pipeline plus step 8 using `input.observed`
  (`partnerHealth {status, errorRate, evidenceId}`, `partnerMaintenanceActive`, `originStatus`,
  `approval {approvalId, proposalId, deadline}`, `proposalCurrent`, `policyVersionInForce`,
  `mappingVersionInForce`, `mappingExists`; the clock is `input.now`; the policy's own maintenance
  windows are read from the snapshot). Each check returns `PreconditionResult {check,
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

## D15 — Tools that serve reference data

- **Decision**: `SignalNoir.Tools.LocalSource` answers `tool.policies` and `tool.mapping_catalog`
  from the Store, with the result shapes in [contracts/validation-input.md](./contracts/validation-input.md)
  (`tool.mapping_catalog` returns the endpoint's `mappingVersion` and `items` plus `synonyms`).
  With nothing loaded it keeps today's "reference data not loaded" absence. For a Case in a
  BenchmarkRun, the Tools read the run's pinned versions (`Store.For(run)`), so the proposer sees the
  data the Validator will use.
- **Rationale**: `LocalSource` says these two Tools wait for 004, and the Validator's minimum-Evidence
  rule needs them as facts. Exposing `synonyms` is what lets an Agent or the Rules baseline relate an
  Order's `soro` to a Mapping's `SERUM`; hiding it would make the Validator accept what the proposer
  could not have known.
- **Open point for Henry**: `Rules` compares specimen types with plain upper-case equality
  (coordination request 1).

## D16 — Existing tests that assume v1

`FakeValidator`, `Consumer`, `TestConsumerUsesSeam` (seam), `TestResolution` and `TestDossier` (set
`Verdict = "invalid"`) use the v1 vocabulary. The first implementation tasks move them to
`accepted`/`blocked` (T003, T006). `ResolutionValidator` accepts `valid` and `accepted` today, so the
suites stay green during the move.

---

## Verification backlog (iris-agentic-dev, before `/speckit-implement`)

| # | Claim | Needed by |
|---|-------|-----------|
| V1 | `%Dictionary.CompiledXData` (or `##class(%Dictionary.XDataDefinition)`) returns the JSON of a compiled `XData` block on build 154, and listing subclasses of a package works through `%Dictionary.CompiledClass` | D5 |

(The first draft's V2, a `<Map Forward>` in `UrlMap`, and V3, a test-only web application, are
dropped with the new `Api.Reference` class, D10.) Baseline, not a platform claim: before T001's
edits, the suites already on `master` pass on the dev container.

## Verification log

2026-10-30, Henrique (T001), on `congenial-waffle-iris-1`: IRIS 2026.2 (Build 221U), **not** AI Hub
build 154 (its image is not loaded on this machine). No provider configured (no `SN_*` variables, no
`.env`). Code under test: `master` at `4d619a4`.

- **V1: passes on 2026.2.** `##class(%Dictionary.CompiledXData).%OpenId("SignalNoir.Sim.Catalog.P1||Variants")`
  returns the block (`MimeType = application/json`) and `{}.%FromJSON(x.Data)` parses it (a
  `%DynamicArray`). `SELECT ID FROM %Dictionary.CompiledClass WHERE ID %STARTSWITH 'SignalNoir.Sim.Catalog.'`
  lists the package's 12 classes. Reading `^oddCOM` directly is refused by iris-agentic-dev, so the
  Store must use these APIs. Still to confirm on build 154.
- **Compile:** `iris-agentic-dev compile` compiles one file at a time in `find` order, so the first
  pass fails on classes whose dependencies come later (181/222), and the second on
  `COMPILE_SUPERCLASS_STALE` (218/222). The third pass compiles 222/222. The container was not
  recreated.
- **Baseline: does not pass.** `RunTest("SignalNoir","/noload/nodelete/recursive")` runs in 43 s:
  272 methods pass, 3 fail. All three fail because no provider is configured; they also fail when
  run alone.
  - `Tests.Api.TestHealth:TestHealthPayloadShape`: test bug. `$Find(reason, "provider unavailable") = 1`
    is never true (`$Find` returns the position after the match, 21 here), so the not-configured
    branch always fails. The reason itself is correct.
  - `Tests.Application.TestExecutionFailure:TestBusinessErrorFailsAndOpensARelatedCase` and
    `Tests.Recovery.TestGateG3:TestRefusalComesBackWithADossier`: the related Case goes to
    `ReviewRequired`, not `Investigating`, because `CaseService.ProcessException` sends a new Case
    to review when `Proposers.Factory.Ready` is false. The tests assume a ready provider.

Decision (Henrique, 2026-10-30): the three failures are accepted as environmental for this baseline;
they are not rerun on build 154 before T003. T001 is done. Expect the same three to fail until a
provider is configured (and `TestHealthPayloadShape` until its `$Find` assertion is fixed); any other
failure is a regression.

Update (Henrique, 2026-10-30, later the same day): with the Simulator reachable, six more tests fail
in `Tests.Recovery.TestRecoverySuite` (`TestBlockingPreconditions`, `TestClean`, `TestLateWorker`,
`TestLostResponse`, `TestRepeatedClickAndCommand`, `TestRestartDuringExecuting`). Same cause, no
provider: a new Case goes to `ReviewRequired`, the suite needs `Investigating`. The first baseline run
did not show them because the suite skips itself (passing) when its Simulator probe fails. The
baseline is therefore 9 environmental failures when the Simulator answers, and the same on the
unchanged `master` container. Runs of the 004 branch use a second container, `signalnoir-004`, that
mounts the worktree.

Update (2026-10-30, after Henry's fix): `master` now carries PR #19 (`fix-provider-independent-tests`),
which removes the nine failures above: the Recovery suite and `TestGateG3` open the Case with
`RecordException` and walk it, `TestExecutionFailure` and `TestGateG3` assert the routing for the
instance, and `/health` returns `provider.configured` as a boolean. The 004 branch merged it
(8927907). The baseline is now green with no provider configured: 300 tests pass, 0 fail, on two
consecutive full runs in `signalnoir-004`. The first run right after compiling the changed classes
showed six `TestRecoverySuite` failures (`<INVALID OREF>`) that did not come back; cause not
established. Any failure from here on is a regression.

### Quickstart walked end to end (2026-10-31, T043)

Container `signalnoir-004`, branch `004-validation-and-reference-data`; full recursive run: 414 tests
passing, 0 failing.

1. **Core suites** (`TestCatalogParams`, `TestMappings`, `TestEvidenceConfidenceIdentity`,
   `TestApprovalPolicy`, `TestPreconditions`, `TestPriorReceipt`, `TestDeterminismNoIo`): all pass.
   The static scan looked at 94 methods of 12 classes and found no I/O; the mean of 1000 validations
   is 0.07 ms (budget 50 ms); a fresh process (`JOB`) gives the same JSON for the 14 inputs.
2. **Fixture agreement** (`TestFixtureVerdicts`): the 13 verdicts rebuilt; 12 match (reasons and
   `requiresApproval`). `resolution.201.action.json` is the known divergence: 004 gives
   `ACTION_IN_CATALOG, PARAMS_VALID, MAPPING_CONDITION_MATCHES, REQUIRED_EVIDENCE_PRESENT`, the
   fixture records the first two. The fixtures are written in the mock's older Evidence shape
   (`patient.id`, `catalogVersion`, `orders`/`receipts`); the test translates the shape and nothing
   else.
3. **Reference data**: `TestStore` (version B without `map_glicj_soro` blocks the same Proposal with
   `MAPPING_NOT_FOUND`, a run pinned to 2026.10.1 still accepts while B is in force, malformed
   fixtures are refused and leave the versions in force alone), `TestMappingsMatchContractFixture`,
   `TestReferenceTools`, `TestReferenceEndpoints`: all pass.
4. **Adapter and recording**: `TestResolutionValidator` passes; the stored verdict and the
   `ValidatorVerdict` event carry `verdict`, `reasons`, `requiresApproval` and `versions`.
5. **Endpoints over HTTP** (`http://localhost:64987/signalnoir/api/v1`): `GET /reference/action-catalog`
   returns four entries with `requiredEvidence` filled and `requiresApproval` false for `HOLD` and
   `REQUEST_REVIEW`; `GET /reference/mappings?sourceCode=GLIC-J` returns the two Mappings with
   `mappingVersion` 2026.10.1.

Deviations from the quickstart text: the container is `signalnoir-004` on port 64987, not
`signalnoir-iris` on 52773; and the Evidence of the fixtures is translated, as noted in item 2.

Update (2026-10-31, fixtures regenerated): the mock's Operator path now follows the rules of 004; the
exporter reproduced the other 24 fixtures byte for byte and changed `resolution.201.action.json`
only (it gained `MAPPING_CONDITION_MATCHES` and `REQUIRED_EVIDENCE_PRESENT`). 25 valid, 0 invalid
against the contract. `TestFixtureVerdicts` agrees on all 13 verdicts.

### Diff review (2026-10-31, T046)

Against the Constitution, the spec, the plan and the tests, on the changes since PR #21 of `master`
(the earlier ones were reviewed when they were merged):

- **Only the listed files changed**, with these exceptions, each needed by a requirement:
  `Application/InvestigationService.cls` (a Proposal's policy version is read from `policyVersion`
  of the Tool's result, so `POLICY_VERSION_UNCHANGED` compares real versions);
  `Application/ResolutionValidator.cls` (`RunFor`, `PriorReceiptOrder`, the Proposal's `caseId`);
  and the test supports of other features, whose Cases had no Evidence or an Order without the
  exam the Mapping needs (`Support`, `TestResolution`, `TestResolutionValidator`, `TestGateG3`,
  `TestInvestigation`, `Fakes/ScriptedSource`).
- **`contracts/` at the root is untouched.** The fixture divergence is asserted, not edited.
- **No rule reads the origin.** The only `origin` in `Core/Validator.cls` is `originStatus`, the
  Origin system's answer about the Order. `TestCatalogParams`, `TestMappings`, `TestPreconditions`
  and `TestFixtureVerdicts` check that the author of a Proposal changes nothing.
- **No second recorder of verdicts.** `ValidatorVerdict` events are still appended only by
  `CaseService` (the investigation path and `ResolveReview`).
- **The Core classes pass the no-I/O scan** (`TestDeterminismNoIo`: 94 methods of 12 classes).
- **No new Action, reason code, precondition or condition field** can be added by an input: the
  catalog, `Core.Reasons`, `Vocab` and `Core.Conditions` are code.

