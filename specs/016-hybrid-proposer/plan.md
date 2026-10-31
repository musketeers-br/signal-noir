# Implementation Plan: Hybrid Proposer

**Branch**: `016-hybrid-proposer` | **Date**: 2026-10-31 | **Spec**: [spec.md](./spec.md)

## Summary

A `hybrid` proposer mode runs the 013 Decisions proposer first, with a quarter of the budget (at most
10 s); a decisive typed answer becomes the Proposal, authored `decisions`. Any other outcome hands the
same Investigation context to the AI Hub Agent, whose Proposal is authored `agent`; if the Agent fails
too, the Case goes to review with the Agent's reason. One `proposer_cascade` Timeline event records
what Decisions said and who decided. The cascade sits behind the Proposer port, so ProposalShape, the
Validator and everything after are unchanged.

## Technical Context

**Language/Version**: ObjectScript, IRIS 2026.3.0AI build 154. **Primary Dependencies**: 013
`Proposers.Decisions`, 006 `Proposers.Agent`, `InvestigationService`, `CaseService`.
**Storage**: none new. **Testing**: `%UnitTest` via iris-agentic-dev with the fake Decisions runtime
and the fake AI Hub runtime. **Constraints**: one budget; no key or provider text in the Timeline.

## Constitution Check

- [x] **I** — the cascade is mode selection before the port; the decisive/indecisive rule stays in
  `Core.DecisionAnswer`.
- [x] **II** — both proposers read the same Evidence; the Agent never sees the Decisions answer.
- [x] **III** — one conversion, one Validator; author is metadata only.
- [x] **IV, V, VI** — unchanged.
- [x] **VII** — every failure stays a value; the final failure is the Agent's.
- [x] **VIII** — Proposals are authored by the real decider; the cascade event shows the route.
- [x] **IX** — sliced by story, tests first.
- [x] **Platform** — the AI Hub Agent stays in the path for every case Decisions does not settle.
- [x] **iris-agentic-dev** — no new platform claim; tests run through it.

## Project Structure

```text
specs/016-hybrid-proposer/  spec.md plan.md research.md tasks.md contracts/contract-change-016-hybrid-mode.md
src/SignalNoir/Proposers/Hybrid.cls  Factory.cls
src/SignalNoir/Application/InvestigationService.cls  CaseService.cls
contracts/openapi-signalnoir.yaml  docs/seams.md (v7)  README.md  .env.example
tests/SignalNoir/Tests/Application/TestHybridProposer.cls
tests/SignalNoir/Tests/Fakes/HybridWithFakes.cls
```

## Complexity Tracking

None.
