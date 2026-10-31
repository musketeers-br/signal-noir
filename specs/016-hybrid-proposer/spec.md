# Feature Specification: Hybrid Proposer (Decisions first, AI Hub Agent as fallback)

**Feature Branch**: `016-hybrid-proposer`

**Created**: 2026-10-31

**Status**: Ready for planning

**Input**: Henry, 2026-10-31: the system must work in a hybrid way, part Decisions and part AI Hub.
Chosen shape: **Decisions first, Agent as fallback**. The Decisions API (feature 013) answers first;
when its answer is decisive it becomes the Proposal; when it is not (uncertain, refused, failed), the
AI Hub Agent (feature 006) investigates and proposes.

## Context

Feature 013 added a Decisions proposer that answers in about a second with explicit probabilities but
sends every indecisive answer to a human. The AI Hub Agent reasons in text over the same Evidence and
can settle cases a typed answer cannot, at a higher cost and latency. The hybrid mode uses each where it
is strongest: the fast typed answer for clear cases, the Agent for the rest. A human still sees every
case neither of them settles.

Nothing after the Proposer port changes. The Proposal of a hybrid Investigation passes the same
`ProposalShape` conversion and the same Validator as any other (Constitution III), and is authored by
the proposer that actually produced it, so the Benchmark and the Timeline say who decided.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A clear case is settled by the typed answer (Priority: P1)

A Case in `hybrid` mode is investigated. The Decisions API answers decisively. That answer becomes the
Proposal, authored `decisions`, and the Agent is not called.

**Independent Test**: Script a decisive Decisions answer and an Agent answer; check that the Proposal
is the Decisions one, authored `decisions`, and that the Agent was never called.

**Acceptance Scenarios**:

1. **Given** a hybrid Case and a decisive Decisions answer, **When** the Investigation runs, **Then**
   the Proposal comes from Decisions, its author is `decisions`, and no AI Hub call is made.
2. **Given** that Proposal, **When** the Timeline is read, **Then** it shows which proposer decided and
   that the Agent was not needed.

---

### User Story 2 - An unclear case goes to the AI Hub Agent (Priority: P1)

When the Decisions answer is below the threshold, a tie, `other`, a refusal, invalid, or the Decisions
call fails or is not configured, the Agent investigates the same Evidence in the same Investigation and
proposes. Its Proposal is authored `agent`.

**Independent Test**: For each Decisions outcome that is not decisive, script an Agent answer and check
that the Proposal is the Agent's, authored `agent`, and that the Timeline records why Decisions handed
over.

**Acceptance Scenarios**:

1. **Given** an uncertain Decisions answer, **When** the Investigation runs, **Then** the Agent is
   called once and its Proposal is recorded with author `agent`.
2. **Given** a Decisions call that fails or is not configured, **Then** the Agent proposes, and the
   Timeline records the Decisions failure as a code, never the provider's error text.
3. **Given** a fallback, **When** the Timeline is read, **Then** one event records the Decisions
   outcome (decisive or the reason it was not), the probability when there was one, and which proposer
   decided.

---

### User Story 3 - Neither can decide: a human does (Priority: P1)

When Decisions is not decisive and the Agent also fails (provider unavailable, invalid answer, refusal,
budget), no Proposal is created and the Case goes to `ReviewRequired` with the Agent's reason, as for an
Agent-only Case.

**Acceptance Scenarios**:

1. **Given** an uncertain Decisions answer and an unavailable AI Hub provider, **Then** the Case is in
   `ReviewRequired` with "provider unavailable: …" and no Proposal.

---

### User Story 4 - One budget for both (Priority: P2)

The Decisions call and the Agent share the Investigation budget. The Decisions call is capped so that
the Agent keeps most of the budget. A late answer still changes nothing.

**Acceptance Scenarios**:

1. **Given** a Decisions call slower than its cap, **When** the cap passes, **Then** the Agent is called
   with the remaining budget.
2. **Given** a hybrid Investigation past the total budget, **Then** it closes with "investigation budget
   exceeded: time".

---

### User Story 5 - The deployment chooses it (Priority: P2)

The deployment selects the mode with `SN_PROPOSER_MODE=hybrid`. Without it nothing changes (the default
stays `agent`). The mode is ready when at least one of its proposers is configured.

## Requirements *(mandatory)*

- **FR-001**: A proposer mode `hybrid` MUST exist; `Factory.ClassFor("hybrid")` returns the hybrid
  proposer and `Ready("hybrid")` is true when the AI Hub Agent or the Decisions adapter is configured.
- **FR-002**: The hybrid proposer MUST call Decisions first and return its result when it is a Proposal
  answer. It MUST call the Agent, once, for every other Decisions outcome (`uncertain`, `refused`,
  `invalid_response`, `provider_unavailable`).
- **FR-003**: Both proposers MUST receive the same Investigation context (the same Evidence package,
  Order and budget). The hybrid proposer MUST NOT add, remove or rewrite Evidence, and MUST NOT pass the
  Decisions answer to the Agent (the Agent decides on the Evidence alone).
- **FR-004**: The Proposal MUST be authored by the proposer that produced it (`decisions` or `agent`).
  The Investigation keeps the mode `hybrid`.
- **FR-005**: Each hybrid Investigation MUST append one Timeline `Annotation` with `kind:
  proposer_cascade`, the Decisions outcome (`decisive` or its failure code), the reason, the chosen
  value and probability when present, and the proposer that decided (`decisions`, `agent`, or `none`).
  No key and no provider error text.
- **FR-006**: The Decisions call MUST be capped at a fraction of the Investigation budget (default one
  quarter, at most 10 s), so the Agent keeps the rest.
- **FR-007**: When the Agent fails too, the result MUST be the Agent's failure value, so the Case goes
  to review with the same reason as an Agent-only Case.
- **FR-008**: `hybrid` MUST be added to the contract's `ProposerMode` by a contract change. The `Actor`
  vocabulary does not change (the author is `decisions` or `agent`).
- **FR-009**: Token usage MUST be recorded for the proposer that decided; the Decisions usage of a
  fallback MUST appear in the cascade event.
- **FR-010**: The Validator, Approval, Execution and Reconciliation MUST NOT change.

## Success Criteria *(mandatory)*

- **SC-001**: A decisive Decisions answer produces a Proposal authored `decisions` with zero AI Hub
  calls, in 100% of the tests.
- **SC-002**: Every non-decisive Decisions outcome produces exactly one Agent call, and the Proposal (if
  any) is authored `agent`, in 100% of the tests.
- **SC-003**: Every hybrid Investigation leaves exactly one `proposer_cascade` event.
- **SC-004**: Agent-only, Rules and Decisions-only suites pass unchanged.

## Assumptions

- Feature 013 is in `master` (adapter, questions, conversion, thresholds `decisions-v1`).
- The Agent is the AI Hub proposer of feature 006; the hybrid mode keeps an AI Hub Agent in the
  decision path for every case Decisions does not settle, which is what the contest requirement asks of
  the Agent.
- The Benchmark (010) can run `hybrid` as a contender; reporting it is 010's work.
- A decisive `REQUEST_REVIEW` from Decisions is a Proposal, not a fallback: it is the typed answer
  asking for a human.
