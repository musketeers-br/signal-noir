# Research: Hybrid Proposer

**Feature**: 016-hybrid-proposer | **Date**: 2026-10-31

No new platform claim: the Decisions route was verified in 013 (R0 there) and the AI Hub Agent in
006 (T060). Everything below reuses those.

## R1 — Where the cascade lives

**Decision**: a proposer `SignalNoir.Proposers.Hybrid` behind the existing Proposer port. It holds two
proposers (`Decisions`, `Agent`; overridable for tests) and returns either result. The decision of
"decisive or not" is already a core rule (`Core.DecisionAnswer`): Hybrid only branches on `Result.ok`.

**Alternatives**: a cascade inside `InvestigationService` (puts mode logic after the port, against 006
FR-012); a new outbox command for a second Investigation (two Investigations, two budgets, two
Timelines for one decision).

## R2 — Author of the Proposal

**Decision**: the Hybrid result carries `details.author` (`decisions` or `agent`).
`InvestigationService.Work` passes it to `ProposalShape.Convert` and in `meta.author`;
`CaseService.CompleteInvestigation` uses it for `ProposalRecord.author`, the `ProposalCreated` actor and
the transition actor, only when the Investigation's mode is `hybrid` and the value is `agent` or
`decisions`. Every other mode keeps `author = mode`.

**Rationale**: FR-004; both actors are already allowed to move `Investigating → DecisionProposed`.

## R3 — Budget split

**Decision**: the Decisions call gets `min(budgetMs / 4, 10000)` ms through the context's `budgetMs`
(Decisions already derives its HTTP timeout from it); the Agent gets the original context. The
Investigation's own deadline still governs the total.

## R4 — Trace

**Decision**: `details.cascade = {decisions: "decisive" | <code>, reason, choice, probability,
decisionsTokensIn, decidedBy}`; `Work` appends one `Annotation` `kind: proposer_cascade` through
`CaseService.Append` before completing or closing. Messages are codes (013 already drops provider error
text).

## R5 — Readiness and selection

**Decision**: `Factory.ConfiguredMode()` accepts `hybrid`; `Ready("hybrid") = AiHubRuntime.Configured()
or DecisionsHttp.Configured()`. With neither, the Case goes to review at open, as today.

## R6 — Verification record (2026-10-31)

- Full `SignalNoir` suite through iris-agentic-dev: **344 methods, all passing** (run 161), with the
  new `Application.TestHybridProposer` (decisive, six fallback outcomes, neither decides, budget, mode
  selection). Agent, Rules and Decisions suites unchanged.
- Contract: `validate_fixtures.py` 31 valid.
- **Live, decisive path** (synthetic serum Order, real `Hybrid` through `InvestigationService`):
  Decisions chose `APPLY_APPROVED_MAPPING:map_glicj_soro` with probability 0.9 in 480 ms
  (2,071 input tokens); Proposal authored `decisions`, `HIGH`, Case in `PendingApproval`; no AI Hub
  call; one `proposer_cascade` event.
- **Live, fallback path** (Decisions forced to fail with a scripted 503, real AI Hub Agent): the
  Agent (`openai` / `gpt-4o-mini`) proposed the same mapping in 3.0 s, authored `agent`, cascade
  `decidedBy: agent`.
- Not done: running the container with `SN_PROPOSER_MODE=hybrid` (needs a recreate).
