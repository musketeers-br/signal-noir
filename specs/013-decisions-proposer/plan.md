# Implementation Plan: Decisions API as a Proposer

**Branch**: `013-decisions-proposer` (stacked on `015-case-precedents`) | **Date**: 2026-10-31 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/013-decisions-proposer/spec.md`

## Summary

A fourth proposer, `decisions`, asks the OpenAI Decisions API (`POST /v1/decisions`, model
`gpt-6-luna`) for typed answers: one `choice` over the closed catalog (mappings expanded into their
matching candidates) plus `other`, and one `predicate` per Evidence item. AI Hub build 154 cannot reach
that endpoint (spike, R0), so by Henry's decision the call is a direct HTTP client behind a runtime
port, with the key read at call time. Building the request and converting the answer are pure core
rules (`Core.DecisionQuestions`, `Core.DecisionAnswer`): a decisive answer becomes the same raw
Proposal answer every proposer returns, then `ProposalShape` and the single Validator as usual; an
indecisive one (below threshold, tie, `other`, refusal) becomes an error value and the Case goes to
review with a distinct reason. The mode is off unless `SN_PROPOSER_MODE=decisions`.

## Technical Context

**Language/Version**: ObjectScript on IRIS 2026.3.0AI build 154 (verified, research R0).

**Primary Dependencies**: `%Net.HttpRequest` + TLS config `SignalNoirTLS`; existing Proposer port,
`InvestigationService`, `ProposalShape`, Validator; OpenAI Decisions API (external).

**Storage**: one new property, `InvestigationRecord.tokensCached`.

**Testing**: `%UnitTest` through iris-agentic-dev with a fake `DecisionsRuntime`; one live smoke call,
labelled live.

**Target Platform / Project Type**: the `signalnoir-iris` container, single IRIS project.

**Performance Goals**: one request per Investigation inside the 20 s budget (spike: 930 ms).

**Constraints**: no key in code, records, Timeline, logs or messages (the 401 message echoes part of
the key, so provider messages are dropped); no instruction text from input; off by default.

**Scale/Scope**: one adapter, two core classes, one shared core extraction, one contract change.

## Constitution Check

*Initial and post-design: all pass, with one platform deviation tracked below.*

- [x] **I. Pure Core** — question building, answer conversion, thresholds and mapping candidates are
  pure core classes; the adapter only does HTTP.
- [x] **II. Closed Catalog / Read-Only Agent** — choices are the catalog plus `other`; out-of-catalog
  answers are refused; Evidence travels as `input_json` with suspicious flags and neutralized
  results; instructions are constants or templates over system ids; no tools in the request.
- [x] **III. One Validator** — Decisions answers go through `ProposalShape` and the same Validator;
  no shortcut (FR-012); a shared-verdict test (SC-001).
- [x] **IV. Human Authority** — unchanged; uncertainty goes to review.
- [x] **V. Case as Source of Truth** — unchanged command path (`CompleteInvestigation` /
  `CloseInvestigation`).
- [x] **VI. Effects at Most Once** — not touched.
- [x] **VII. Honest Outcomes** — `uncertain`, `refused`, `provider_unavailable` are values with
  distinct review reasons; no Proposal for any of them.
- [x] **VIII. Honest Measurement** — versioned question set and thresholds, same Evidence package and
  budget; reporting in the Benchmark is 010's (declared dependency).
- [x] **IX. Verifiable Increments** — sliced by story, tests first.
- [~] **Platform Constraints** — the Agent still runs through AI Hub; this optional proposer does not
  (see Complexity Tracking). Synthetic data; key only at runtime.
- [x] **iris-agentic-dev** — AI Hub inventory and the live direct call verified (R0); tests run
  through it; not a runtime dependency.

## Project Structure

```text
specs/013-decisions-proposer/  spec.md plan.md research.md data-model.md quickstart.md tasks.md
                               contracts/contract-change-013-decisions-mode.md
docs/verification/013-decisions-spike.md
src/SignalNoir/Core/  DecisionQuestions.cls  DecisionAnswer.cls  MappingMatch.cls  Vocab.cls (+ decisions actor)
src/SignalNoir/Core/Port/DecisionsRuntime.cls
src/SignalNoir/Proposers/  Decisions.cls  DecisionsHttp.cls  Factory.cls (mode, ClassFor, Ready)  Rules.cls (uses MappingMatch)
src/SignalNoir/Application/  CaseService.cls (mode at creation, tokensCached)  InvestigationService.cls (reasons, tokensCached)
src/SignalNoir/Application/Model/InvestigationRecord.cls (+ tokensCached)
contracts/openapi-signalnoir.yaml  docs/seams.md (v6)  README.md  .env.example
tests/SignalNoir/Tests/Core/  TestDecisionQuestions  TestDecisionAnswer  TestMappingMatch
tests/SignalNoir/Tests/Application/TestDecisionsProposer
tests/SignalNoir/Tests/Fakes/FakeDecisionsRuntime.cls  DecisionsWithFakeRuntime.cls
```

**Structure Decision**: existing layout; the adapter sits with the other proposers.

## Complexity Tracking

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| A proposer outside AI Hub (direct HTTP) | AI Hub build 154 has no decisions route (R0); Henry chose the direct client on 2026-10-31 | Waiting for AI Hub support would drop the feature; the Agent remains the AI Hub contender, so the contest requirement still holds |
| `refused` reason changed for every proposer | US2 needs a distinct, honest reason; one mapping serves all origins | A Decisions-only reason would make the same failure read differently by origin |
