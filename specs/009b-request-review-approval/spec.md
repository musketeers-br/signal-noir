# Feature Specification: Correction 009b — Approval Policy for a Request for Review

**Feature Branch**: `009b-request-review-approval`

**Created**: 2026-10-26

**Status**: Implemented

**Input**: Correction to feature 009 raised by the 004 coordination review
(`specs/004-validation-and-reference-data/contracts/coordination-004-006-009.md`, point 2): the
action catalog and the Validator's verdict say that a request for review needs human Approval,
while the initiative (R19, PRD FR-16) and the contract fixtures say it does not.

## Context

Feature 009 published the closed action catalog (`GET /reference/action-catalog`) and the verdict
that the single Validator returns for every Proposal. Both carry a `requiresApproval` flag. 009
set it to true for `REQUEST_REVIEW`. The initiative says otherwise: only `RETRY` and
`APPLY_APPROVED_MAPPING` need human Approval; `REQUEST_REVIEW` only stops automation and has no
external effect. The contract fixtures (`case.review.ambiguous-identity.json`,
`case.review.after-denial.json`) record `requiresApproval: false` for it. The console's offline
mock repeats the same mistake.

No Case is routed wrongly today: a Proposal that asks for review goes to review before the flag is
read. The harm is in what the system *reports*: an Operator, a reviewer or the 004 Validator reads
a policy that the product does not have.

The same review found that 009's coordination note promised more than it can keep ("when 004's v2
lands, only the body of the adapter changes"). This correction fixes the note so 004 and 009 work
from the same description.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The catalog tells the truth about Approval (Priority: P1)

An Operator, or the console, reads the action catalog to know which Actions will ask a human for
Approval. A request for review must be listed as not needing one, and the two Actions with an
external effect must be listed as needing one.

**Why this priority**: The catalog is the reference the console and the other teams read; a
wrong policy there spreads to every consumer.

**Independent Test**: Read the action catalog and check the Approval flag of each of the four
Actions.

**Acceptance Scenarios**:

1. **Given** the running system, **When** the action catalog is read, **Then** `RETRY` and
   `APPLY_APPROVED_MAPPING` say Approval is required and `HOLD` and `REQUEST_REVIEW` say it is not.
2. **Given** the catalog, **When** any entry is read, **Then** it needs Approval exactly when it
   has an external effect.

---

### User Story 2 - The verdict on a request for review matches the catalog (Priority: P1)

When a proposer asks for review, the Validator's verdict is recorded on the Case and shown on the
Timeline. That verdict must say no Approval is required, and the Case must still go to review with
its Dossier, exactly as before.

**Why this priority**: The verdict is the recorded evidence of the decision; it must agree with
the catalog.

**Independent Test**: Run an investigation whose Proposal is `REQUEST_REVIEW`; read the recorded
verdict and the Case state.

**Acceptance Scenarios**:

1. **Given** a Proposal that asks for review, **When** the Validator accepts it, **Then** the
   recorded verdict says Approval is not required and the Case goes to review with a Dossier.
2. **Given** a Proposal for `RETRY` or `APPLY_APPROVED_MAPPING`, **When** the Validator accepts
   it, **Then** the verdict still says Approval is required and the Case waits for Approval.

---

### User Story 3 - The console's offline mode shows the same policy (Priority: P2)

A developer or reviewer runs the console against the contract fixtures, without a backend. The
catalog it serves must match the real one.

**Why this priority**: The offline mode is how the console is demonstrated and reviewed; it is
not on the production path.

**Independent Test**: In the console tests, read the mock action catalog and compare each entry
with the policy.

**Acceptance Scenarios**:

1. **Given** the console in offline mode, **When** the action catalog is read, **Then** each
   Action needs Approval exactly when it has an external effect.

---

### User Story 4 - The coordination note describes the real change (Priority: P3)

The 004 team reads 009's coordination note to plan the switch to the new Validator. The note must
say that the adapter's inputs change too, and that the Approval policy fix is done here, so 004
does not repeat it.

**Why this priority**: Documentation; it avoids two teams editing the same file.

**Independent Test**: Read the note and check it against the 004 coordination document.

**Acceptance Scenarios**:

1. **Given** 009's coordination note, **When** it is read, **Then** it states that the adapter
   gains the inputs the new Validator needs and that the `REQUEST_REVIEW` Approval policy was
   corrected by 009b.

### Edge Cases

- An Operator resolving a review cannot choose `REQUEST_REVIEW` (009 refuses it). That rule does
  not change.
- A blocked Proposal reports the policy of its own Action. A blocked `RETRY` still says Approval is
  required; that rule does not change.
- `HOLD` keeps needing no Approval and goes straight to execution.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The action catalog MUST report that an Action needs human Approval if and only if
  the Action has an external effect (`RETRY`, `APPLY_APPROVED_MAPPING`).
- **FR-002**: The Validator's recorded verdict MUST report the same Approval policy as the catalog
  for the Action of the Proposal.
- **FR-003**: A Proposal that asks for review MUST still move the Case to review with a Dossier,
  without creating Approval work.
- **FR-004**: The console's offline catalog MUST report the same Approval policy as FR-001.
- **FR-005**: 009's coordination note MUST describe the adapter change that the new Validator
  needs and record that the Approval policy was corrected here.
- **FR-006**: No contract file, contract fixture or seam MAY change.

### Key Entities

- **Action catalog entry**: an Action with its external effect, Approval policy, allowed
  parameters and required Evidence.
- **Validator verdict**: the decision on a Proposal, its reasons and its Approval policy.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 4 of 4 catalog entries report an Approval policy equal to their external effect, in
  the service and in the console's offline mode.
- **SC-002**: 100% of recorded verdicts on a request for review say Approval is not required.
- **SC-003**: The full test suite, the live contract check, the contract fixtures and the console
  tests pass with no regression.

## Assumptions

- The policy source is the initiative R19 (PRD FR-16) and the contract fixtures; the contract
  schema does not fix the value.
- The routing of a Proposal (009) already checks for a request for review before the Approval
  flag, so no state transition changes.
- The other points of the 004 review stay with 004 and wave 4: the new Validator inputs (004
  T015), reference data in the Tools and the mappings endpoint (004 T037), the required Evidence in
  the catalog (004 T010) and specimen synonyms in the Rules proposer (wave 4, after 004 merges).
- Calendar gate: same exception the user granted for 003, 005, 006 and 009, recorded in
  research.md.
