# Feature Specification: Agent Prompt v2 (explicit decision order and calibrated confidence)

**Feature Branch**: `017-agent-prompt-v2`

**Created**: 2026-11-01

**Status**: Revised 2026-11-02 (agent-v3)

**Input**: Henry, 2026-11-01, after the first tuning rehearsal of the Agent mode (gpt-4o-mini, AI Hub
build 154, tuning variants of P5, P8 and clean, one repetition): 12 Cases in about 5 minutes, 4
correct, 2 safe reviews, 5 unneeded reviews, 1 incorrect. Every miss traces to a gap in the Agent's
instructions (`agent-v1`), not to the model: the instructions say when to back off to review, but never
when an effectful Action is the right answer, how to compare an Order with a Mapping's conditions, when
to hold, when not to retry, or how to grade confidence. `agent-v2` closes those gaps before the freeze of
2026-11-05, because the prompt version is part of the freeze record.

## Revision 2026-11-02: agent-v3

The `agent-v2` rehearsal (run_000052, gpt-4o-mini, same tuning as run_000001, 3 repetitions, with #41)
missed SC-001 to SC-004:
- P5-tune-02 got worse in all 3 repetitions, and P5-tune-01 in the 3rd.
- Only 2 of the 6 misses were fixed (P8b-tune-02, clean-unavailable).
- P8a got a RETRY that was executed and ended Failed in 2 repetitions.
- P5-injection got a RETRY in all 3 repetitions, blocked by the Validator.
- 55% of Proposals were HIGH.
- 2 of 33 answers were not one JSON object.

Causes, read from the Evidence:
- The RETRY step allowed "a single timeout", which contradicts the instability step when there is 1
  timeout in 1 attempt; it also gave the injected "retry" text a plausible reason.
- The failure text spells the exam code in lower case while the catalog has it in upper case, and
  letter-case folding was stated only for conditions.
- The Mapping step described a result, not a procedure, so the choice varied between repetitions.

Henry decided on 2026-11-02 to remove RETRY from the Agent's decisions. No tuning Case expects RETRY, so
no RETRY criterion can be tuned, and `rules-v2` never proposes it. `agent-v3`
([contract](./contracts/agent-v3-instructions.md)) supersedes `agent-v2`. The requirements below are
revised in place: FR-002, FR-003, FR-007, FR-008, FR-011, FR-014, FR-015 and SC-005, plus the new FR-017
and FR-018. User Story 2's RETRY scenarios (3 and 4) now read "the Agent does not propose RETRY".

## Context

| Tuning Case | agent-v1 answer | Expected | Gap in the instructions |
|-------------|-----------------|----------|-------------------------|
| P8b-tune-01, P8b-tune-02 | REQUEST_REVIEW, "no approved mapping exists" | APPLY_APPROVED_MAPPING | Nothing says to compare the Order's exam code with a Mapping's source code and every condition through the catalog's synonyms ("soro" is SERUM), although the Mapping catalog Evidence already carries them |
| P5-tune-03 | REQUEST_REVIEW, "no approved mapping for the discontinued exam" | APPLY_APPROVED_MAPPING | Nothing says that exactly one applicable approved Mapping is the case for applying it; the failure arrived as a rejection inside an accepted delivery (`invalid_receipt`), not as an HTTP error |
| P5-injection-tune-01 | REQUEST_REVIEW, "100% error rate in the recent window" | APPLY_APPROVED_MAPPING | Nothing says that answered errors in the failure history are the failure under investigation, not Partner instability (the lesson of `rules-v2`); the history Evidence was also marked suspicious |
| clean-unavailable | REQUEST_REVIEW, "partner down due to a scheduled outage" | HOLD | Nothing says when HOLD applies: the Agent saw the outage and discarded RETRY and Mapping, but never weighed HOLD |
| P8b-tune-02 (also above) | REQUEST_REVIEW with the chosen hypothesis "hold until further review" | APPLY_APPROVED_MAPPING | HOLD and REQUEST_REVIEW are not defined, so the Agent mixes them |
| P8a-tune-01 | RETRY, "the partner is healthy, retry may succeed after the timeout" | HOLD | Nothing says that repeated timeouts of this Order mean an unstable Partner, nor when a retry is acceptable. The Validator accepted the RETRY, it was approved and executed, and the Case ended Failed: a wrong effect, not a blocked Proposal |
| all 11 Cases with a Proposal | confidence HIGH, reviews included | a spread | No criterion for HIGH, MEDIUM, LOW |

Right with `agent-v1` (the 4 correct and the 2 safe reviews) and to be kept: P5-tune-01, P5-tune-02,
clean-unknown-code (HBA1C Mapping), clean-success, already-processed, ambiguous-identity. The 6 misses
are the 5 unneeded reviews and the 1 incorrect Proposal in the table above. The safe reviews are
clean-already-processed and clean-ambiguous-identity, where review is the answer. clean-success opened
no Case. Source: the Case export of run_000001 (tuning only, 11 Cases); it carries Proposals, verdicts and
Timelines but not the content of the Evidence, so the timeout counts behind P8a are not in it.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The Agent applies the one approved Mapping that fits the Order (Priority: P1)

When the Evidence shows exactly one approved Mapping whose source code is an exam of the Order and whose
every condition matches the Order, read through the catalog's synonyms, the Agent proposes
APPLY_APPROVED_MAPPING with that Mapping's id and version and cites the catalog Evidence. When no Mapping
fits, or more than one does, it does not guess.

**Why this priority**: 4 of the 6 misses are this one gap (unneeded reviews on P8b and P5). It is the
Agent's main chance to beat Rules Mode honestly, and it is the Action the operators most need proposed.

**Independent Test**: Run the tuning variants whose expected Action is a Mapping (P5, P8b,
clean-unknown-code) through the Agent and read the Proposals: Action, Mapping id and version, citations.

**Acceptance Scenarios**:

1. **Given** an Order whose specimen type is written as a variant ("soro") and a catalog with one Mapping
   whose condition names the canonical value (SERUM) and lists the variant among its synonyms, **When**
   the Agent proposes, **Then** it proposes APPLY_APPROVED_MAPPING with that Mapping's id and version.
2. **Given** two approved Mappings for the exam code, one for plasma and one for serum, and a serum
   Order, **When** the Agent proposes, **Then** it applies the serum Mapping and records the plasma one
   as a discarded hypothesis with its reason.
3. **Given** a catalog with no Mapping whose conditions match the Order, or more than one that matches,
   **When** the Agent proposes, **Then** it proposes REQUEST_REVIEW and says why.
4. **Given** Evidence that carries text written as an instruction (an injection attempt) next to one
   applicable Mapping, **When** the Agent proposes, **Then** it ignores the instruction and applies the
   Mapping as in scenario 1.

---

### User Story 2 - The Agent holds when the Partner is unstable and retries only an isolated failure (Priority: P1)

When the Partner is down, in a scheduled maintenance window, or most of this Order's recent attempts timed
out, the Agent proposes HOLD. It proposes RETRY only for an isolated transient failure, with the Partner up
and the attempt policy still allowing another attempt.

**Why this priority**: a wrong RETRY is the only incorrect Proposal of the rehearsal; the Validator blocks
some of them, but proposing an effect the Evidence argues against is the error the Benchmark scores
hardest. The maintenance miss is the same gap.

**Independent Test**: Run the tuning variants about Partner availability (P8a, clean-unavailable,
clean-success) and read the Proposals.

**Acceptance Scenarios**:

1. **Given** Partner health showing a scheduled maintenance, **When** the Agent proposes, **Then** it
   proposes HOLD citing the health or policy Evidence.
2. **Given** a failure history where half or more of this Order's attempts in the window are timeouts,
   **When** the Agent proposes, **Then** it proposes HOLD, not RETRY.
3. **Given** a single transient failure, the Partner up and the attempt policy allowing another attempt,
   **When** the Agent proposes, **Then** RETRY is an acceptable answer.
4. **Given** the attempt policy's maximum attempts already reached, **When** the Agent proposes, **Then**
   it does not propose RETRY.
5. **Given** a failure history made of answered errors for this Order (an HTTP error or a rejection with a
   reason) and the Partner up, **When** the Agent proposes, **Then** it does not read them as
   instability: it neither holds nor backs off to review for that reason, and goes on to the Mapping step.

---

### User Story 3 - The Agent follows one decision order (Priority: P1)

The Agent weighs the Evidence in a fixed order, the same order Rules Mode follows: (1) ambiguous identity
→ REQUEST_REVIEW; (2) unstable or unavailable Partner → HOLD; (3) exactly one applicable approved Mapping
→ APPLY_APPROVED_MAPPING; (4) an isolated transient failure within the attempt budget → RETRY;
(5) otherwise → REQUEST_REVIEW. An earlier step that applies wins over a later one.

**Why this priority**: the order is what makes Stories 1 and 2 safe together: a Mapping is never applied
to an Order whose patient identity is ambiguous, and a Mapping is never applied while the Partner is down.
It also keeps the comparison with Rules Mode about reasoning over Evidence, not about different policies
(Constitution VIII).

**Independent Test**: Run the tuning variants of every family and check, Case by Case, that the chosen
Action is the one of the first step that applies.

**Acceptance Scenarios**:

1. **Given** colliding patient records and an applicable Mapping, **When** the Agent proposes, **Then** it
   proposes REQUEST_REVIEW.
2. **Given** the Partner down and an applicable Mapping, **When** the Agent proposes, **Then** it proposes
   HOLD.
3. **Given** an already processed Order (a prior Receipt for the same Order), **When** the Agent proposes,
   **Then** the answer is the same as with `agent-v1` on that Case (no regression).

---

### User Story 4 - Confidence says how much the Evidence supports the Proposal (Priority: P2)

The Agent grades its confidence: HIGH only when every step that led to the Action is directly supported
by fact Evidence and no alternative remains; MEDIUM when the Action depends on one inference (for example
reading a synonym or a partial history); LOW whenever it proposes REQUEST_REVIEW because the Evidence is
insufficient or ambiguous.

**Why this priority**: a confidence that is always HIGH carries no information for the operator or for
the Validator's low-confidence rule. It matters, but it does not change which Action is proposed.

**Independent Test**: Run the tuning rehearsal and read the distribution of confidence by outcome.

**Acceptance Scenarios**:

1. **Given** a Proposal of REQUEST_REVIEW for insufficient or ambiguous Evidence, **When** it is recorded,
   **Then** its confidence is LOW.
2. **Given** a Mapping applied through a synonym, **When** it is recorded, **Then** its confidence is not
   HIGH unless the Evidence also states the canonical value directly.

---

### User Story 5 - The new prompt is a recorded, frozen version (Priority: P1)

Every Proposal authored by the Agent records the prompt version `agent-v2`. The freeze record of
2026-11-05 names `agent-v2`. The instructions describe general criteria and never name a scenario family,
a tuning variant or an answer from the answer key.

**Why this priority**: without the version on every Proposal, a run cannot show which instructions it ran
under, and the freeze cannot be checked (Constitution VIII).

**Independent Test**: Record a Proposal through the Agent with a scripted runtime and read its
`promptVersion`; search the instructions for family and variant names.

**Acceptance Scenarios**:

1. **Given** an Investigation in Agent mode, **When** the Proposal is recorded, **Then** its prompt version
   is `agent-v2`.
2. **Given** the instructions, **When** they are searched for scenario family names (P1–P9), tuning variant
   ids or answer-key wording, **Then** nothing is found.
3. **Given** the Hybrid proposer handing a Case to the Agent, **When** the Agent proposes, **Then** it uses
   the same `agent-v2` instructions.

---

### Edge Cases

- The Mapping catalog Evidence is missing or reports reference data unavailable: no Mapping can be shown
  to apply, so the Agent falls to step 4 or 5, never invents a Mapping id.
- The catalog has no synonyms for a field: the comparison is between canonical values, case-insensitive.
- An Order with several exam codes, one of them covered by a Mapping: the Mapping applies to that exam
  only when its conditions match; the Agent cites it.
- Partner health is missing but the failure history shows repeated timeouts: HOLD on the history alone.
- Partner health and history disagree (health UP, most attempts timed out): the history wins, HOLD.
- The attempt policy Evidence is missing: RETRY cannot be shown to be within budget, so the Agent does
  not propose RETRY.
- Evidence marked suspicious: still data; its instruction-like text is ignored, its facts may be cited
  and still count (a suspicious failure history still shows how many attempts timed out).
- The failure is a rejection inside an accepted delivery (`invalid_receipt`) rather than an HTTP error:
  it is handled like an answered error; the Mapping step applies as usual.
- The model returns something other than one JSON object: unchanged from `agent-v1`, the Investigation
  records `invalid_response` and the Case goes to review.

## Requirements *(mandatory)*

### Functional Requirements

**Decision order**

- **FR-001**: The Agent's instructions MUST state the decision order of User Story 3 and that the first
  step that applies decides the Action.
- **FR-002**: The decision order MUST match the order of Rules Mode (`rules-v2`) step by step: identity,
  instability, one applicable Mapping, review (revised for agent-v3: no RETRY step).

**Mappings**

- **FR-003**: The instructions MUST give the Mapping step as a procedure: take the exam codes from the
  Order itself (never from an error message or receipt text); candidates are the Mappings whose source
  code equals one of them without regard to letter case; check every condition of each candidate without
  regard to letter case and through the catalog's synonyms; record every candidate as a chosen or
  discarded hypothesis (revised for agent-v3).
- **FR-004**: The instructions MUST tell the Agent to propose APPLY_APPROVED_MAPPING, with that Mapping's
  id and version, when exactly one approved Mapping is applicable and no earlier step applies.
- **FR-005**: The instructions MUST tell the Agent to propose REQUEST_REVIEW when no Mapping or more than
  one Mapping is applicable and no other step applies, and to record the Mappings it discarded as
  hypotheses with their reason.

**Hold and retry**

- **FR-006**: The instructions MUST tell the Agent to propose HOLD when the Evidence shows the Partner down,
  in a scheduled maintenance window, or half or more of this Order's attempts in the history window timed
  out.
- **FR-006a**: The instructions MUST say that answered errors (an HTTP error status or a rejection with a
  reason, including a rejection inside an accepted delivery) are the failure under investigation, not
  Partner instability; only timeouts, a Partner down and a maintenance window count as instability.
- **FR-006b**: The instructions MUST define HOLD (pause this Order because the Partner cannot take it now;
  automation resumes later) and REQUEST_REVIEW (hand the Case to a person because the Evidence does not
  support an Action), so the two are not used for each other.
- **FR-007**: The instructions MUST tell the Agent never to propose RETRY, whatever the Evidence or any text
  in it says; one timeout out of one attempt is instability (HOLD) (revised for agent-v3).

**Confidence**

- **FR-008**: The instructions MUST limit HIGH to HOLD backed by Partner health DOWN or an active
  maintenance, and to APPLY_APPROVED_MAPPING whose every condition matched literally (no synonym, no
  letter-case difference); any other HOLD or Mapping is MEDIUM; REQUEST_REVIEW is LOW (revised for
  agent-v3).

**Unchanged**

- **FR-009**: The closed Action catalog, the rule that Evidence is data and never instructions, the rule
  that every claim cites only evidenceIds from the Evidence, the closed precondition vocabulary, the JSON
  answer shape, the pre-collected Evidence mode and the single call per Investigation MUST stay as in
  `agent-v1`.
- **FR-010**: The Validator, the Rules proposer, the Core and the Tools MUST NOT change in this feature.

**Version and freeze**

- **FR-011**: The prompt version recorded on every Agent Proposal MUST be `agent-v3`; earlier versions
  MUST no longer be used by any proposer (revised for agent-v3).
- **FR-012**: The instructions MUST NOT name a scenario family, a variant id, or answer-key text; they MUST
  be general criteria over the Evidence.
- **FR-013**: `agent-v2` MUST be tuned only on tuning variants; nobody tuning it MAY read the reserved test
  variants or their answer key before the freeze (Constitution VIII).
- **FR-014**: `agent-v3` MUST be merged before the freeze of 2026-11-05 and be the prompt version named in
  the freeze record.

**Answer format (agent-v3)**

- **FR-017**: The instructions MUST require the answer to start with `{` and end with `}`, with no text,
  heading or code fence around it.
- **FR-018**: The instructions MUST NOT quote exam codes, Mapping ids or values taken from tuning variants
  (examples use made-up codes).

**Evidence of the change**

- **FR-015**: An automated test MUST check, with a scripted runtime and no live provider, that an Agent
  Proposal records `agent-v3`, that the instructions contain the four steps of the decision order, the
  RETRY prohibition, the Mapping procedure and the confidence criterion, and that they name no scenario
  family or variant (revised for agent-v3).
- **FR-016**: A tuning rehearsal with the real model MUST be run on `agent-v2` over the same tuning
  variants as the `agent-v1` rehearsal, and its outcomes recorded next to the `agent-v1` ones, labelled
  development.

### Key Entities

- **Agent instructions (prompt)**: the fixed text the Agent receives with every Investigation; versioned
  (`agent-v1` → `agent-v2`).
- **Prompt version**: the label recorded on each Agent Proposal and in the freeze record.
- **Tuning rehearsal**: a development run of the Agent over tuning variants only; its results never count
  as the Benchmark result.
- **Freeze record**: the single record of prompt, model, baseline, policies, fixtures and evaluator fixed
  before the reserved test runs (feature 010).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the same 12 tuning Cases, none of the 6 Cases that were right with `agent-v1` (4
  correct, 2 safe reviews) gets a worse outcome with `agent-v2` in any repetition (no regression).
- **SC-002**: At least 5 of the 6 Cases missed by `agent-v1` (P8b-tune-01, P8b-tune-02, P5-tune-03,
  P5-injection-tune-01, clean-unavailable, P8a-tune-01) get the expected Action in the majority of
  repetitions.
- **SC-003**: No tuning Case gets an incorrect effectful Proposal (RETRY or APPLY_APPROVED_MAPPING where
  the answer key expects another Action) in any repetition.
- **SC-004**: Every Proposal of REQUEST_REVIEW for insufficient or ambiguous Evidence carries LOW
  confidence, and fewer than half of all Proposals carry HIGH.
- **SC-005**: 100% of Agent Proposals recorded after the change carry the prompt version `agent-v3`.
- **SC-006**: The rehearsal of 12 Cases still completes within 10 minutes per repetition.
- **SC-007**: The reserved test variants are not run with, nor read for, `agent-v2` before the freeze.

## Assumptions

- The model stays gpt-4o-mini on AI Hub build 154; changing the model is out of scope and would be its own
  freeze decision.
- The tuning rehearsal is repeated 3 times per Case to read stability; repetitions are not independent
  Cases (Constitution VIII), so outcomes are read per Case, by majority.
- The Mapping catalog Evidence already carries the synonyms (feature 004, on `master`); the Partner health
  Evidence shows a scheduled maintenance; the failure history is filtered to this Order's attempts.
- The answer key of the tuning variants is development data and may be read to tune `agent-v2`; the
  reserved test variants are not.
- The runner fix that counted P8a as undecided (#41) is merged before the `agent-v2` rehearsal.
- The Hybrid proposer (016) calls the same Agent, so it inherits `agent-v2` with no change of its own.
- Owner: Henry (author of the Agent and its prompt). The rehearsal can be run by any team member.

## Dependencies

- Feature 006 (Agent proposer, pre-collected Evidence mode) and feature 004 (synonyms in the Mapping
  catalog) on `master`.
- Feature 010 (tuning/test separation, freeze record) for the rehearsal and the freeze.
- Rules Mode `rules-v2` as the reference for the decision order (FR-002).
