# Quickstart: validate agent-v2

## 1. Automated (no live provider)

On the dev container (`signalnoir-iris`, `IRISAPP`), after compiling (`dev/aihub/README.md`):

- `SignalNoir.Tests.Proposers.TestAgentPromptV2` — version `agent-v2` on a Proposal through the scripted
  runtime; the decision order, criteria and definitions are in the instructions; no family or variant
  names.
- `SignalNoir.Tests.Application.TestProposerModes` — `versions.prompt` is `agent-v2`.
- The whole suite stays green (`RunTest("SignalNoir","/noload/nodelete/recursive")`).

## 2. Tuning rehearsal (real model, development)

With an AI provider key in `.env`, run the same tuning rehearsal as run_000001 (tuning variants of P5,
P8 and clean), 3 repetitions, Agent mode, after #41 is merged. Record the outcomes next to run_000001,
labelled development.

**Expected** (spec SC-001–SC-006): none of the 6 right Cases gets worse; at least 5 of the 6 misses get
the expected Action by majority; no incorrect effectful Proposal; reviews carry LOW, fewer than half of
Proposals carry HIGH; every Proposal records `agent-v2`; each repetition within 10 minutes.

Never run the reserved test variants with `agent-v2` before the freeze (SC-007).

**Status (2026-11-01)**: automated checks green; the tuning rehearsal with the real model is pending (it
needs a provider key) and is left to the team member who runs the Benchmark.
