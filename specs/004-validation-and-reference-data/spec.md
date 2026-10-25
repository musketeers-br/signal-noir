# Feature Specification: Validator and Versioned Reference Data

**Feature Branch**: `004-validation-and-reference-data`

**Created**: 2026-10-24

**Status**: Draft

**Input**: User description: "the deterministic Validator and versioned reference data." (full description: `docs/specify-prompts/004-validation-and-reference-data.txt`)

## Context

Every Proposal in Signal Noir — from the Agent, from Rules Mode, from the Operator's resolution of a
Review Dossier, or from the Benchmark — passes through one deterministic Validator before it can
reach Approval or Execution (Constitution, Principle III). The Validator checks that the Action is
in the closed catalog, that its parameters and scope are valid, that an approved Mapping exists and
applies to the Order, that the minimum Evidence for the Action is present, and that the Proposal is
confident enough and does not touch an ambiguous identity. It decides whether human Approval is
required, and it re-checks a closed set of preconditions right before an effect is sent.

The Validator works only on the inputs it is given. Policies and approved Mappings are versioned
reference data owned by the application, loaded from versioned fixtures, and a BenchmarkRun may pin
which version it uses. The Simulator never owns them.

Its consumers are the proposers (006 Investigation, 009 Operator resolution), Approval (007),
Revalidation before the send (008), the Benchmark (010) and the operator console (005), which reads
the catalog and the Mappings to build the resolution form.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Only catalog Actions with valid parameters pass (Priority: P1)

A proposer submits a Proposal. The Validator accepts only `RETRY`, `APPLY_APPROVED_MAPPING`, `HOLD`
and `REQUEST_REVIEW`, with the parameters each one allows and the single-Case scope. Anything else
is blocked, and the verdict is recorded on the Case so the block is visible and auditable.

**Why this priority**: It is the outermost safety gate. Without it, an input or a model could make
the system act outside the four declared Actions (Principle II).

**Independent Test**: Submit one Proposal per Action with valid parameters, then one with an
unknown Action, one with a forbidden parameter, one without the mandatory Mapping parameters and
one with a scope other than single Case; read the verdicts and the Case timeline.

**Acceptance Scenarios**:

1. **Given** a Proposal with an Action outside the catalog, **When** it is validated, **Then** the
   verdict is `blocked` with reason `ACTION_NOT_IN_CATALOG`, and a verdict event is recorded on the
   Case timeline.
2. **Given** an `APPLY_APPROVED_MAPPING` Proposal without `mappingId` or `mappingVersion`, **When**
   it is validated, **Then** the verdict is `blocked` with `PARAMS_INVALID`.
3. **Given** a `RETRY` Proposal carrying any parameter, or any Proposal carrying a parameter its
   Action does not declare, **When** it is validated, **Then** the verdict is `blocked` with
   `PARAMS_INVALID`.
4. **Given** a Proposal whose scope is not a single Case, **When** it is validated, **Then** the
   verdict is `blocked` with `SCOPE_INVALID`.
5. **Given** a valid `REQUEST_REVIEW` Proposal, **When** it is validated, **Then** the verdict is
   `accepted` with `REVIEW_ALWAYS_ACCEPTED` and no Approval is required.
6. **Given** the same inputs, **When** they are validated twice, **Then** both verdicts are
   identical, including reasons and their order.

---

### User Story 2 - A Mapping is applied only when it exists and its conditions match (Priority: P1)

A proposer chooses `APPLY_APPROVED_MAPPING` with a Mapping id and version. The Validator accepts it
only when that exact Mapping exists in the reference data in force, its source code appears in the
Order, and every applicability condition (for example the specimen type) matches the Order.

**Why this priority**: The P8b family has two approved Mappings for the same code that differ only
by Order context. Applying the wrong one is the incorrect effect the product exists to prevent.

**Independent Test**: With the reference Mappings for one discontinued code (one for plasma, one
for serum), validate both against a plasma Order, then validate an unknown Mapping id and a known id
with a wrong version.

**Acceptance Scenarios**:

1. **Given** a plasma Order and the plasma Mapping, **When** validated, **Then** the verdict is
   `accepted` with `MAPPING_CONDITION_MATCHES` among the reasons.
2. **Given** a plasma Order and the serum Mapping, **When** validated, **Then** the verdict is
   `blocked` with `MAPPING_CONDITION_MISMATCH`.
3. **Given** a Mapping id that does not exist, or an existing id with a version that does not exist,
   **When** validated, **Then** the verdict is `blocked` with `MAPPING_NOT_FOUND`.
4. **Given** a Mapping whose source code is not among the Order's exam codes, **When** validated,
   **Then** the verdict is `blocked` with `MAPPING_SOURCE_CODE_ABSENT`.
5. **Given** an Order whose specimen type is written in a different case or language than the
   Mapping condition (for example `plasma` vs `PLASMA`, `soro` vs `SERUM`), **When** validated,
   **Then** the comparison uses the canonical value, and the verdict is the same as for the canonical
   spelling.

---

### User Story 3 - Unsupported, unconfident or identity-ambiguous Proposals go to review (Priority: P1)

A Proposal must carry the minimum Evidence for its Action. If any mandatory Evidence is missing, if
the confidence is low, or if the Order's identity is ambiguous and the Action would act on the
Partner, the verdict is `review` with a specific reason, so the Case goes to `ReviewRequired`
instead of moving toward an effect.

**Why this priority**: This is what turns "the model sounded sure" into "the system has the facts".
It drives the Dossier path and the "safe review" outcome the Benchmark measures.

**Independent Test**: For each Action, validate a Proposal with all its mandatory Evidence, then one
missing each mandatory item in turn; validate a low-confidence Proposal; validate a `RETRY` on an
Order whose identity is ambiguous.

**Acceptance Scenarios**:

1. **Given** a `RETRY` Proposal with attempt policy, attempt history and recent partner health,
   **When** validated, **Then** the verdict is `accepted` with `REQUIRED_EVIDENCE_PRESENT`.
2. **Given** a `RETRY` Proposal missing the attempt history, **When** validated, **Then** the verdict
   is `review` with `EVIDENCE_MISSING_ATTEMPT_HISTORY`; likewise `EVIDENCE_MISSING_POLICY` and
   `EVIDENCE_MISSING_PARTNER_HEALTH` for the other two items.
3. **Given** an `APPLY_APPROVED_MAPPING` Proposal missing the substitution policy, the Mapping
   evidence or the Order field that satisfies the Mapping condition, **When** validated, **Then** the
   verdict is `review` with `EVIDENCE_MISSING_POLICY`, `EVIDENCE_MISSING_MAPPING` or
   `EVIDENCE_MISSING_ORDER_FIELD` respectively.
4. **Given** a `HOLD` Proposal with neither recent partner health nor a policy maintenance window,
   **When** validated, **Then** the verdict is `review` with `EVIDENCE_MISSING_HEALTH_OR_WINDOW`; with
   either one, it is `accepted`.
5. **Given** a Proposal with confidence `BAIXA` (low), **When** validated, **Then** the verdict is
   `review` with `CONFIDENCE_LOW`.
6. **Given** an Order flagged with ambiguous identity, **When** a `RETRY`, `APPLY_APPROVED_MAPPING`
   or `HOLD` Proposal is validated, **Then** the verdict is `review` with
   `IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION`; a `REQUEST_REVIEW` Proposal is still `accepted`.
7. **Given** a `RETRY` Proposal when the attempt policy's maximum attempts has been reached,
   **When** validated, **Then** the verdict is `blocked` with `RETRY_BUDGET_EXHAUSTED`; below the
   maximum, `RETRY_BUDGET_AVAILABLE` is among the reasons.

---

### User Story 4 - The approval policy decides who must approve (Priority: P1)

Every accepted verdict states whether human Approval is required. Outside a BenchmarkRun, `RETRY`
and `APPLY_APPROVED_MAPPING` (the Actions with an external effect) require human Approval; `HOLD`
and `REQUEST_REVIEW` do not. Automatic Approval exists only inside a BenchmarkRun, is identified as
automatic, and the actor `benchmark` is refused anywhere else.

**Why this priority**: The Operator's authority over effects (Principle IV) starts here: Approval
(007) relies on this verdict to know whether it must wait for a human.

**Independent Test**: Validate each Action outside and inside a BenchmarkRun; ask the Validator
whether an Approval by the `benchmark` actor is admissible in both contexts.

**Acceptance Scenarios**:

1. **Given** an accepted `RETRY` or `APPLY_APPROVED_MAPPING` outside a BenchmarkRun, **When**
   validated, **Then** `requiresApproval` is true.
2. **Given** an accepted `HOLD` or `REQUEST_REVIEW`, **When** validated, **Then** `requiresApproval`
   is false.
3. **Given** an Approval by the actor `benchmark` for a Case outside a BenchmarkRun, **When** its
   admissibility is checked, **Then** it is refused with `ACTOR_BENCHMARK_OUTSIDE_RUN`.
4. **Given** a Case that belongs to a BenchmarkRun, **When** an Approval by `benchmark` is checked,
   **Then** it is admissible and labelled `automatic`.
5. **Given** an Approval by an operator actor (`operator:<name>`), **When** checked inside or outside
   a run, **Then** it is admissible and labelled `human`.

---

### User Story 5 - Preconditions are re-checked from a closed vocabulary (Priority: P2)

Right before an effect is sent, Revalidation (008) asks the Validator to evaluate the Proposal's
preconditions against freshly observed values. Only five checks exist: `PARTNER_HEALTHY_WINDOW`,
`ORDER_ACTIVE_AT_ORIGIN`, `APPROVAL_VALID`, `POLICY_VERSION_UNCHANGED`, `MAPPING_VERSION_UNCHANGED`.
Each result states what was expected, what was observed and whether it passed.

**Why this priority**: It is the half of P3 the Validator owns: a world change between Approval and
Execution must stop the effect. It depends on Stories 1–4 producing an approvable Proposal.

**Independent Test**: Evaluate the preconditions of an approved Proposal with observed values equal
to the expected ones, then change one observed value at a time.

**Acceptance Scenarios**:

1. **Given** all observed values match, **When** preconditions are evaluated, **Then** every check
   passes and the verdict stays `accepted`.
2. **Given** the policy version in force differs from the one the Proposal relied on, **When**
   evaluated, **Then** `POLICY_VERSION_UNCHANGED` fails, and the verdict is `blocked` with
   `PRECONDITION_FAILED_POLICY_VERSION_UNCHANGED`.
3. **Given** the Mapping version in force differs, or the Mapping no longer exists, **When**
   evaluated, **Then** `MAPPING_VERSION_UNCHANGED` fails with its reason code.
4. **Given** the partner is degraded, its recent error rate exceeds the policy threshold, or a policy
   maintenance window is active, **When** evaluated, **Then** `PARTNER_HEALTHY_WINDOW` fails.
5. **Given** the Order is cancelled at the Origin, **When** evaluated, **Then**
   `ORDER_ACTIVE_AT_ORIGIN` fails.
6. **Given** the Approval has expired, belongs to another Proposal, or the Proposal is no longer
   current, **When** evaluated, **Then** `APPROVAL_VALID` fails.
7. **Given** a Proposal that declares a precondition outside the five, **When** validated, **Then**
   the verdict is `blocked` with `PRECONDITION_UNKNOWN`.
8. **Given** new Evidence that does not change any of the five observed values, **When** evaluated,
   **Then** every check still passes (new Evidence alone does not expire an Approval).

---

### User Story 6 - Reference data is versioned, pinnable and readable (Priority: P2)

Policies and approved Mappings are loaded from versioned fixtures. Every verdict names the policy and
Mapping versions it used. A BenchmarkRun can pin the versions so its Cases are validated against the
same data from start to finish. The action catalog and the Mappings in force are readable through
the product API so the console can build the resolution form without inventing values.

**Why this priority**: Reproducible verdicts need reproducible inputs (Principle VIII), and the
console (005) needs the catalog and Mappings. It depends on Stories 1–2 for the rules that use the
data.

**Independent Test**: Load two fixture versions, validate the same Proposal under each, pin a run to
the older one; read the catalog and the Mappings through the API.

**Acceptance Scenarios**:

1. **Given** fixture versions A and B where B removes a Mapping, **When** the same Proposal is
   validated under A and under B, **Then** it is accepted under A and blocked with
   `MAPPING_NOT_FOUND` under B, and each verdict names its versions.
2. **Given** a BenchmarkRun pinned to version A while B is in force, **When** a Case of that run is
   validated, **Then** version A is used.
3. **Given** the action catalog is requested, **When** it is read, **Then** it lists exactly the four
   Actions with external effect, approval requirement, parameter shape and minimum Evidence.
4. **Given** the Mappings are requested, optionally filtered by source code, **When** they are read,
   **Then** the Mappings of the version in force are returned with that version.
5. **Given** a fixture that declares an Action outside the catalog, a condition field the Validator
   does not know, or a duplicate Mapping id within one version, **When** it is loaded, **Then** the
   load is refused and the previous version stays in force.

---

### User Story 7 - Prior-receipt confirmation (Priority: P3)

When a Proposal points to a prior Receipt as evidence that the Order was already delivered, the
Validator confirms it only if the canonical equivalence keys of the two Orders match. The product
behavior on prior receipts (011) is conditional; this story makes the verdict available.

**Why this priority**: P9 is conditional; the verdict value and its rule exist so 011 can be built
without changing the Validator.

**Independent Test**: Validate a prior-receipt candidate whose Order matches the current one after
canonicalization, then one that differs in one key field.

**Acceptance Scenarios**:

1. **Given** a candidate whose canonical equivalence key equals the current Order's, **When**
   validated, **Then** the verdict is `prior_receipt_confirmed` with `EQUIVALENCE_KEY_MATCH` and no
   Approval is required.
2. **Given** a candidate whose key differs, **When** validated, **Then** the verdict is `review` with
   `EQUIVALENCE_KEY_MISMATCH`.
3. **Given** an ambiguous identity, **When** a candidate is validated, **Then** the verdict is
   `review` with `IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION`; there is no confirmation by inference.

---

### Edge Cases

- A Proposal has several problems at once (for example an invalid parameter and missing Evidence):
  `blocked` takes precedence over `review`, and the reasons list every failed check in a fixed order.
- A Proposal arrives without an Action, without confidence or without the versions it relied on:
  `blocked` with `PARAMS_INVALID` (or the matching reason), never an exception.
- A Mapping has no conditions: it applies to any Order that contains its source code.
- A Mapping condition names an Order field that is absent from the Order: the condition does not
  match (`MAPPING_CONDITION_MISMATCH`), and the Order-field Evidence counts as missing.
- Evidence marked as obsolete or as suspicious (for example containing an embedded instruction) does
  not count toward the minimum Evidence.
- Evidence belonging to another Case is ignored.
- An Operator's resolution Proposal is validated by exactly the same rules as an Agent's or Rules
  Mode's; the origin never changes the verdict.
- Two verdicts for the same Proposal and the same inputs, computed at different times, differ only in
  the timestamp supplied by the caller.
- The fixture set in force cannot be loaded at startup: no verdict other than `blocked` with
  `REFERENCE_DATA_UNAVAILABLE` is produced until it can.

## Requirements *(mandatory)*

### Functional Requirements

**Catalog, parameters and scope**

- **FR-001**: The Validator MUST accept only the Actions `RETRY`, `APPLY_APPROVED_MAPPING`, `HOLD`
  and `REQUEST_REVIEW`; any other Action MUST be `blocked` with `ACTION_NOT_IN_CATALOG`. No input or
  configuration can add an Action.
- **FR-002**: Parameters MUST follow the catalog: `RETRY` takes none; `APPLY_APPROVED_MAPPING`
  requires `mappingId` and `mappingVersion`; `HOLD` and `REQUEST_REVIEW` take only an optional
  `reason`. Any other parameter, or a missing mandatory one, MUST be `blocked` with
  `PARAMS_INVALID`.
- **FR-003**: Scope MUST be single Case; any other scope MUST be `blocked` with `SCOPE_INVALID`.

**Mappings**

- **FR-004**: `APPLY_APPROVED_MAPPING` MUST be accepted only if the Mapping with that exact id and
  version exists in the reference data in force (else `MAPPING_NOT_FOUND`), its source code appears
  among the Order's exam codes (else `MAPPING_SOURCE_CODE_ABSENT`), and every applicability condition
  matches the Order (else `MAPPING_CONDITION_MISMATCH`).
- **FR-005**: Condition matching MUST compare canonical values: codes and enumerated fields
  case-insensitively and through the versioned synonym list of the reference data (for example
  `soro` → `SERUM`); a condition on an absent Order field MUST NOT match.

**Minimum Evidence, confidence and identity**

- **FR-006**: The Validator MUST require, as minimum Evidence of the Case:
  - `RETRY`: attempt policy, attempt history, recent partner health;
  - `APPLY_APPROVED_MAPPING`: substitution policy, the approved Mapping, the Order field that
    satisfies the Mapping condition;
  - `HOLD`: recent partner health or a policy maintenance window;
  - `REQUEST_REVIEW`: none.
- **FR-007**: A Proposal missing a mandatory Evidence item MUST get verdict `review` with the
  specific reason (`EVIDENCE_MISSING_POLICY`, `EVIDENCE_MISSING_ATTEMPT_HISTORY`,
  `EVIDENCE_MISSING_PARTNER_HEALTH`, `EVIDENCE_MISSING_MAPPING`, `EVIDENCE_MISSING_ORDER_FIELD`,
  `EVIDENCE_MISSING_HEALTH_OR_WINDOW`). Obsolete, suspicious or other-Case Evidence MUST NOT count.
- **FR-008**: A Proposal with low confidence (`BAIXA`) MUST get verdict `review` with
  `CONFIDENCE_LOW`.
- **FR-009**: When the Order's identity is ambiguous, any Action other than `REQUEST_REVIEW` MUST get
  verdict `review` with `IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION`.
- **FR-010**: `RETRY` MUST be `blocked` with `RETRY_BUDGET_EXHAUSTED` when the attempt count has
  reached the attempt policy's maximum.

**Approval policy**

- **FR-011**: Every verdict MUST state `requiresApproval`: true for `RETRY` and
  `APPLY_APPROVED_MAPPING`, false for `HOLD`, `REQUEST_REVIEW` and `prior_receipt_confirmed`. The
  approval policy is itself versioned reference data.
- **FR-012**: The Validator MUST answer whether an Approval by a given actor is admissible for a Case:
  the actor `benchmark` only when the Case belongs to a BenchmarkRun (labelled `automatic`), refused
  with `ACTOR_BENCHMARK_OUTSIDE_RUN` otherwise; `operator:<name>` always (labelled `human`); any
  other actor refused with `ACTOR_NOT_ALLOWED_TO_APPROVE`.

**Verdict**

- **FR-013**: The verdict MUST be one of `accepted`, `blocked`, `review`, `prior_receipt_confirmed`,
  with `requiresApproval`, the ordered list of reason codes (passed and failed checks), the policy and
  Mapping versions used, and the time supplied by the caller.
- **FR-014**: Reason codes MUST come from one closed list, each with a short human-readable English
  text. The list includes at least the codes named in this specification and the codes already used
  by the contract fixtures (`ACTION_IN_CATALOG`, `PARAMS_VALID`, `MAPPING_CONDITION_MATCHES`,
  `MAPPING_CONDITION_MISMATCH`, `REQUIRED_EVIDENCE_PRESENT`, `RETRY_BUDGET_AVAILABLE`,
  `REVIEW_ALWAYS_ACCEPTED`, `EQUIVALENCE_KEY_MATCH`, `IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION`).
- **FR-015**: When several checks fail, `blocked` MUST take precedence over `review`, and the reasons
  MUST list every failed check in a fixed, documented order.
- **FR-016**: The same inputs MUST always produce the same verdict. The Validator MUST receive every
  input as a parameter (Proposal, Case Evidence, Order snapshot, reference data version, run context,
  observed precondition values, current time) and MUST perform no I/O.
- **FR-017**: Every Proposal from any origin (Agent, Rules Mode, Operator, Benchmark) MUST be
  validated by the same rules; the origin MUST NOT change the verdict.
- **FR-018**: Each validation of a Proposal MUST be recorded on its Case: the verdict is attached to
  the Proposal and a verdict event is appended to the timeline, including when the verdict is
  `blocked`.

**Preconditions**

- **FR-019**: Preconditions MUST use only `PARTNER_HEALTHY_WINDOW`, `ORDER_ACTIVE_AT_ORIGIN`,
  `APPROVAL_VALID`, `POLICY_VERSION_UNCHANGED`, `MAPPING_VERSION_UNCHANGED`; any other MUST be
  `blocked` with `PRECONDITION_UNKNOWN`.
- **FR-020**: Evaluating preconditions MUST return, per check, the expected value, the observed value
  and pass/fail; any failure MUST make the verdict `blocked` with
  `PRECONDITION_FAILED_<CHECK>`.
- **FR-021**: `PARTNER_HEALTHY_WINDOW` passes only when declared health is `UP`, the recent error rate
  is within the policy threshold over the policy window, and no policy maintenance window is active;
  `ORDER_ACTIVE_AT_ORIGIN` only when the Origin status is active; `APPROVAL_VALID` only when an
  Approval of this exact Proposal exists, is before its deadline, and the Proposal is current;
  `POLICY_VERSION_UNCHANGED` / `MAPPING_VERSION_UNCHANGED` only when the version in force equals the
  version the Proposal relied on (and, for the Mapping, it still exists).
- **FR-022**: Evidence outside these five checks MUST NOT change the outcome of a precondition
  evaluation.

**Reference data**

- **FR-023**: Policies (attempt, substitution, maintenance window, partner health threshold,
  approval) and approved Mappings MUST be versioned reference data owned by the application and
  loaded from versioned fixtures; the Simulator MUST NOT own or serve them.
- **FR-024**: Loading a fixture version MUST be refused, keeping the previous version in force, when
  it declares an Action outside the catalog, an unknown condition field or a duplicate Mapping id.
- **FR-025**: A BenchmarkRun MUST be able to pin the policy and Mapping versions, and Cases of that
  run MUST be validated against the pinned versions.
- **FR-026**: The product API MUST serve the action catalog (`GET /reference/action-catalog`) and the
  Mappings in force (`GET /reference/mappings`, optional `sourceCode` filter) exactly as
  `contracts/openapi-signalnoir.yaml` defines them.
- **FR-027**: When no reference data version is in force, every validation MUST be `blocked` with
  `REFERENCE_DATA_UNAVAILABLE`.

**Prior receipt**

- **FR-028**: For a Proposal that names a prior Receipt candidate, the Validator MUST compare the
  canonical equivalence keys of the current Order and the candidate's Order snapshot: equal →
  `prior_receipt_confirmed` with `EQUIVALENCE_KEY_MATCH`; different → `review` with
  `EQUIVALENCE_KEY_MISMATCH`; ambiguous identity → `review` with
  `IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION`.

### Key Entities

- **Proposal (input)**: Action, parameters, scope, confidence, declared preconditions with expected
  values, versions relied on (policy, Mapping), origin, optional prior Receipt candidate.
- **Validation Input**: the Proposal plus the Case's Evidence, the Order snapshot and its identity
  status, the attempt count, the reference data version, the run context (in a BenchmarkRun or not,
  pinned versions), observed precondition values (for Revalidation) and the current time.
- **Verdict**: verdict value, requires-approval flag, ordered reason codes, versions used, time.
- **Precondition Result**: check, expected, observed, passed.
- **Reason Code**: closed code with its English text.
- **Action Catalog Entry**: Action, external effect, approval requirement, parameter shape, minimum
  Evidence.
- **Approved Mapping**: id, version, source code, target code, applicability conditions.
- **Policy Set**: versioned attempt, substitution, maintenance-window, health-threshold and approval
  policies.
- **Reference Data Version**: one consistent set of Policies, Mappings and synonyms with its version
  identifiers.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of Proposals that reach Approval or Execution carry a recorded verdict.
- **SC-002**: 0 Proposals with an Action outside the catalog are accepted across the full test suite,
  including fuzzed Action names and parameters.
- **SC-003**: Validating each of the test inputs twice, and across a restart, yields identical
  verdicts in 100% of cases.
- **SC-004**: Every acceptance scenario of Stories 1–7 maps to exactly one expected verdict value and
  reason set, and the suite checks all of them.
- **SC-005**: A single validation completes fast enough to be invisible to the operator (well under
  one second) and makes no call outside its inputs.
- **SC-006**: For the P8b reference data, the Validator accepts exactly one of the two Mappings for
  each test Order and blocks the other, in 100% of test variants.
- **SC-007**: Changing one observed precondition value at a time fails exactly the corresponding
  check in 100% of cases.

## Assumptions

- **Confidence vocabulary**: the description's "LOW" is the contract's `BAIXA` (`ALTA`, `MEDIA`,
  `BAIXA`); only `BAIXA` routes to review.
- **Reason codes**: the contract leaves `ValidatorVerdict.reasons` as strings; this feature closes the
  list in the Core vocabulary, starting from the codes already used by the fixtures. The verdict
  carries codes only; the English text is looked up from the vocabulary by whoever shows it (Dossier,
  console, error messages).
- **"Blocked and recorded"**: the verdict is recorded on the Case (attached to the Proposal, plus a
  timeline event) by the validation command this feature provides; proposers call that command. No
  Approval is recorded here.
- **Ambiguous identity**: the Validation Input carries an identity status established from Evidence
  (for example conflicting patient records); the Validator does not search for identity itself.
- **Order-field Evidence**: the Order snapshot field that satisfies the Mapping condition counts as
  Evidence when the Case has Evidence of the Order (its snapshot or timeline) showing that field.
- **Specimen synonyms**: the reference data carries a versioned synonym list (PT/EN, case variants)
  for enumerated condition fields, starting with specimen type (`plasma`/`PLASMA`, `soro`/`serum` →
  `SERUM`).
- **Approval deadline**: its duration is an approval-policy value; Approval itself is recorded by
  007, which supplies it to `APPROVAL_VALID`.
- **Reference fixtures**: `contracts/fixtures/reference.mappings.json` is the response example of the
  Mapping endpoint; the application's own versioned fixtures (Policies, Mappings, synonyms) are
  produced by this feature and must be consistent with it.
- **Calendar gate**: until 2026-10-26 only this specification, its plan, tasks, contract notes and
  fixtures are produced; no submission code.

## Dependencies

- `contracts/openapi-signalnoir.yaml` (frozen): `Action`, `ActionParams`, `ActionCatalogEntry`,
  `ApprovedMapping`, `Confidence`, `PreconditionCheck`, `Precondition`, `PreconditionResult`,
  `ValidatorVerdict`, `ValidatorVerdictValue`, `ErrorCode` (`VALIDATION_FAILED`, `INVALID_ACTOR`),
  `/reference/action-catalog`, `/reference/mappings`.
- **Seam contract change required**: `docs/seams.md` v1 defines `ValidatorVerdict` as
  `valid`/`invalid` with a single reason and `Validate(proposal)` with the Proposal as the only input.
  This feature needs the contract's verdict shape (`accepted`/`blocked`/`review`/
  `prior_receipt_confirmed`, `reasons[]`, `requiresApproval`) and a Validation Input carrying every
  input (FR-013, FR-016). Per the parallelism rules, this is recorded as an explicit seam
  contract-change in the plan, together with the `FakeValidator` update, before any consumer depends
  on the v1 shape.
- 001: the Case command path (to record verdicts) and the canonical equivalence key (`Canon`).
- Consumers: 005 (catalog, Mappings), 006 and 009 (validation of Proposals), 007 (approval policy and
  actor admissibility), 008 (precondition evaluation), 010 (pinned versions), 011 (prior receipt).

## Out of Scope

Recording Approvals, executing effects, generating Proposals, the operator console, the Benchmark
runner, and the product's behavior on prior receipts.
