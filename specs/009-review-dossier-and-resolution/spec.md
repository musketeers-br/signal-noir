# Feature Specification: Review Dossier and Operator Resolution

**Feature Branch**: `009-review-dossier-and-resolution`

**Created**: 2026-10-25

**Status**: Implemented (2026-10-26; verified on AI Hub build 154)

**Input**: User description: "the Review Dossier and operator resolution." (full description:
`docs/specify-prompts/009-review-dossier-and-resolution.txt`)

## Context

When Signal Noir cannot decide safely, its value is the truth it hands the Operator (Constitution
VII). This feature produces a Review Dossier every time a Case enters `ReviewRequired`, built only
from what the Case actually recorded, and lets the Operator resolve it: choose one catalog Action
with its parameters, which then passes the same Validator as any Proposal and follows the normal
Approval and Execution path, or cancel the Case with a reason.

Its consumers are the Operator console (005, already built against the contract), the Validator
(004), Approval (007) and Execution (008). The HTTP surface is the frozen contract's `GET
/cases/{caseId}` (`dossier`), `POST /cases/{caseId}/resolution` and the reference operations the
resolution form reads. All data is synthetic.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every review comes with an honest Dossier (Priority: P1)

Whenever a Case moves to `ReviewRequired`, whatever the cause, a Review Dossier is recorded with
the Case: the reason (from a closed list) and a plain explanation, the partial diagnosis when one
exists, the hypotheses considered and why some were discarded, the Evidence that was collected with
conflicts highlighted, colliding records and their divergent fields when identity is ambiguous,
unconfirmed prior-receipt candidates, the factual unknowns, and the suggested next human step.

**Why this priority**: A review without an explanation is just an alert. The Dossier is what makes
`ReviewRequired` an honest, useful outcome.

**Independent Test**: Drive Cases to `ReviewRequired` through each cause (provider unavailable,
invalid response, budget exceeded, interrupted investigation, second rejection) and read each
Dossier.

**Acceptance Scenarios**:

1. **Given** an Investigation that ended because the provider was unavailable, **When** the Case
   enters `ReviewRequired`, **Then** its Dossier names the reason `provider_unavailable`, lists the
   Evidence collected so far, has no partial diagnosis, and states as an unknown that no
   interpretation of the Evidence exists.
2. **Given** an Investigation closed by the budget, an invalid response or a restart, **When** the Case
   enters `ReviewRequired`, **Then** the Dossier names `budget_exceeded`, `invalid_agent_response` or
   `investigation_interrupted` respectively and includes the Evidence collected so far.
3. **Given** a Case whose recorded Evidence shows two synthetic patient records matching the Order,
   **When** its Dossier is built, **Then** it lists the colliding records and marks the fields that
   differ.
4. **Given** a Proposal that pointed to a prior Receipt the Validator did not confirm, **When** the
   Dossier is built, **Then** the candidate is listed with the equivalence fields that do not match.
5. **Given** any Dossier, **When** it is compared with the Case, **Then** every Evidence it mentions
   exists on the Case and no query appears that did not happen.
6. **Given** a Dossier with nothing to flag as unknown, **When** it is read, **Then** its unknowns list
   is empty, which means "nothing flagged" and never "everything is known".

---

### User Story 2 - Resolve with a catalog Action that passes the same Validator (Priority: P1)

From a Case in `ReviewRequired`, the Operator (by declared name) chooses one catalog Action and its
allowed parameters. The choice becomes a Proposal authored `operator:<name>` and goes through the
same Validator as any Proposal. If it is accepted, the Proposal, the Validator's verdict and the
Operator's own Approval (when the Action needs one) are recorded, and the Case follows the normal
path toward Execution. If it is refused, nothing is executed, only the verdict is recorded, and the
answer names the reason codes.

**Why this priority**: This is how a human closes the loop without a shortcut around the Validator
(Constitution III) and without editing payloads.

**Independent Test**: Resolve one review with an Action the Validator accepts and one it refuses;
read the Case, its Proposals, Approvals, Timeline and pending work after each.

**Acceptance Scenarios**:

1. **Given** a Case in `ReviewRequired`, **When** the Operator chooses an Action the Validator
   accepts, **Then** a Proposal authored `operator:<name>` is recorded with the verdict, an Approval
   by the same Operator is recorded when the Action requires approval, the Case moves to `Approved`
   (or straight to `Executing` for an Action that needs no approval) and execution work is pending.
2. **Given** a Case in `ReviewRequired`, **When** the Validator refuses the Operator's choice, **Then**
   the answer is a refusal naming the reason codes, the Case stays in `ReviewRequired` at the same
   version, no Proposal or Approval is current, nothing is executed, and the Timeline records only
   the verdict.
3. **Given** a resolution that carries any field outside the catalog Action and its allowed
   parameters, **When** it is submitted, **Then** it is refused as invalid input and nothing is
   recorded.
4. **Given** a resolution with a stale Case version, or a Case no longer in `ReviewRequired`, **When**
   submitted, **Then** it is refused as a conflict and nothing is recorded.

---

### User Story 3 - Cancel with a reason (Priority: P2)

The Operator may cancel a Case under review. A reason is mandatory and is recorded with the
Operator's name; no effect is sent.

**Why this priority**: Cancelling is a legitimate resolution (duplicate order, origin will resend)
and must be as accountable as an Action.

**Independent Test**: Cancel without a reason (refused), then with one (Cancelled, reason on the
Timeline).

**Acceptance Scenarios**:

1. **Given** a Case in `ReviewRequired`, **When** cancellation is submitted without a reason,
   **Then** it is refused as invalid input and nothing changes.
2. **Given** a reason, **When** cancellation is submitted, **Then** the Case is `Cancelled`, the
   Timeline records the Operator's resolution with the reason, and no execution work exists.

---

### User Story 4 - The console reads it all over the contract (Priority: P2)

The Case detail carries the Dossier and the Approvals; the resolution endpoint answers 201 / 400 /
404 / 409 / 422 as the contract defines; the action catalog and approved mappings can be read for
the resolution form.

**Why this priority**: The console (005) is already built against these operations.

**Independent Test**: Exercise the HTTP operations and validate the responses against
`contracts/openapi-signalnoir.yaml`.

**Acceptance Scenarios**:

1. **Given** a Case in `ReviewRequired`, **When** its detail is read, **Then** the `dossier` conforms
   to the contract.
2. **Given** each resolution outcome, **When** the response is read, **Then** its status and body
   conform to the contract (`ReviewResolutionResult`, `ErrorEnvelope` with the verdict for 422).
3. **Given** the action catalog operation, **When** read, **Then** it lists exactly the four catalog
   Actions with their approval and parameter rules.

---

### Edge Cases

- A Case that enters `ReviewRequired` twice gets a fresh Dossier each time; the latest is the one
  shown.
- A Dossier built when no Evidence was ever collected says so as an unknown; it never invents one.
- Evidence whose source could not answer becomes a factual unknown ("no information from …"), not a
  negative finding.
- An operator name that is empty or contains ":" is refused as invalid input.
- `REQUEST_REVIEW` chosen as a resolution would send a Case already in review back to review; it is
  refused as invalid input for a resolution.

## Requirements *(mandatory)*

### Functional Requirements

**Dossier**

- **FR-001**: Every transition into `ReviewRequired` MUST record a Review Dossier with the Case, in
  the same unit as the transition.
- **FR-002**: The Dossier reason MUST come from the contract's closed list and be derived from the
  recorded cause; its text MUST explain why automation stopped.
- **FR-003**: The Dossier MUST be built only from records of the Case (Evidence, Proposals,
  Exceptions, rejections). It MUST NOT mention Evidence or queries that do not exist.
- **FR-004**: The Dossier MUST include the partial diagnosis and its hypotheses (with discard
  reasons) when a Proposal exists, the relevant Evidence ids, conflicts, colliding records with
  divergent fields when identity is ambiguous, unconfirmed prior-receipt candidates with mismatched
  equivalence fields, the factual unknowns and the suggested next step.
- **FR-005**: Absence of information (an Evidence whose source did not answer, a missing diagnosis,
  no Evidence at all) MUST be listed as a factual unknown and never as a negative conclusion. An
  empty unknowns list means nothing was flagged.

**Resolution**

- **FR-006**: A resolution MUST be either a catalog Action with only its allowed parameters, or a
  cancellation with a reason; any other field is refused as invalid input.
- **FR-007**: The resolution MUST require the Case in `ReviewRequired` at the expected version;
  otherwise it is refused as a conflict and nothing is recorded.
- **FR-008**: An Action resolution MUST become a Proposal authored `operator:<name>` and pass the same
  Validator used for every Proposal.
- **FR-009**: If the Validator refuses, only the verdict MUST be recorded; the answer MUST name the
  reason codes; nothing is executed.
- **FR-010**: If the Validator accepts, the Proposal, the verdict and (when the Action requires
  approval) the Operator's Approval MUST be recorded together with the transitions toward
  Execution, and execution work MUST be pending; an Action that needs no approval goes to
  `Executing` directly.
- **FR-011**: A cancellation MUST move the Case to `Cancelled` with the Operator and reason recorded.
- **FR-012**: The operator's declared name MUST be non-empty and contain no ":".

**Contract surface**

- **FR-013**: The Case detail MUST carry the latest Dossier and the Approvals; the resolution and
  reference operations MUST answer as `contracts/openapi-signalnoir.yaml` defines.

**Reaching review**

- **FR-014**: A Proposal from an Investigation MUST pass the same Validator as an operator
  resolution, in the same unit as its recording. A blocked Proposal or a `REQUEST_REVIEW` MUST move
  the Case to `ReviewRequired` (and so produce its Dossier); an accepted Action goes to
  `PendingApproval`, or to `Executing` when it needs no approval.
- **FR-015**: Recorded synthetic patient records that share the Order's patient name with a different
  identity MUST be treated as ambiguous identity by one core rule, used by Rules Mode (which then asks
  for review) and by the Dossier (reason `ambiguous_identity`, colliding records, divergent fields).
  The base Evidence package MUST include recent receipts and orders by patient so these records exist.

### Key Entities

- **Review Dossier**: reason, reason text, creation time, partial diagnosis, hypotheses, relevant
  Evidence ids, conflicts, colliding records, unconfirmed candidates, unknowns, suggested next step.
- **Operator Proposal**: a Proposal authored `operator:<name>` with the chosen Action and parameters.
- **Approval**: the recorded decision on one exact Proposal (approved by the same Operator in a
  resolution), with its deadline.
- **Validator verdict**: accepted/blocked with reason codes and whether approval is required.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of Cases that enter `ReviewRequired` in the test suite have a Dossier with a
  closed reason and a next step.
- **SC-002**: 0 Dossiers in the test suite reference an Evidence id that is not on the Case.
- **SC-003**: 100% of operator Action resolutions in the tests pass through the Validator and are
  authored `operator:<name>`; 0 refused resolutions leave a current Proposal, an Approval or
  execution work behind.
- **SC-004**: 100% of resolution and detail responses produced by the tests conform to the
  contract.

## Assumptions

- The Validator in this branch is the seam-v1 core Validator (feature 004's v2 is not merged).
  Resolution calls it through one adapter, so 004's integration changes one class; its reason-code
  vocabulary is 004's.
- The Approval record is the contract's `Approval`; feature 007 owns the approval command and
  expiry. This feature only writes the Operator's own Approval inside a resolution, as the
  contract's `resolveReview` describes. Coordination point with 007.
- The approval deadline uses the PRD's assumption of 15 minutes.
- Approved mappings are reference data of feature 004; until it is integrated the mappings operation
  returns an empty list with `mappingVersion` "unloaded", and the Validator path decides.
- Ambiguous identity is detected only from recorded Evidence that carries synthetic patient records
  (recent receipts and orders by patient); nothing is inferred beyond what those records show.
- Prior-receipt confirmation is feature 011 / the Validator's (004); this feature lists a candidate
  the current Proposal points to and shows which equivalence fields do not match.
