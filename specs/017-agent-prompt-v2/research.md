# Research: Agent Prompt v2

## R1 — Source of the misses

- **Decision**: the misses are instruction gaps; the model stays (gpt-4o-mini, build 154).
- **Rationale**: in the run_000001 export every miss states a reason the Evidence contradicts or that the
  instructions never framed (spec, Context). The 6 right Cases show the model reads the Evidence and
  cites it correctly.
- **Alternatives considered**: a larger model (a separate freeze decision, out of scope); tool-calling
  mode instead of pre-collected Evidence (out of scope, 006 FR-017).

## R2 — Decision order

- **Decision**: (1) ambiguous identity → REQUEST_REVIEW; (2) Partner unstable or unavailable → HOLD;
  (3) exactly one applicable approved Mapping → APPLY_APPROVED_MAPPING; (4) isolated transient failure,
  Partner up, attempts below the policy maximum → RETRY; (5) otherwise → REQUEST_REVIEW.
- **Rationale**: steps 1–3 and 5 are `rules-v2` rules 1–4 (`docs/benchmark/baseline-rules.md`), so Rules
  and the Agent differ in reasoning, not policy (Constitution VIII, FR-002). Step 4 is the one Rules
  lacks: RETRY is in the catalog and the Validator has a retry-budget rule, so the Agent may use it, but
  only after the hold step has ruled out instability.
- **Alternatives considered**: no fixed order, criteria only (agent-v1's failure mode: no Action wins);
  Mapping before instability (applies a Mapping while the Partner is down).

## R3 — What counts as instability

- **Decision**: instability = `tool.partner_health.status` DOWN, or `maintenance.active` true, or a
  maintenance window in `tool.policies` covering now, or `window.timeouts / window.total >= 0.5` in
  `tool.partner_failure_history` (this Order's attempts). Answered errors (`errors`, an HTTP status, a
  rejection with a reason, a rejection inside an accepted delivery) are the failure under investigation.
  The prompt tells the Agent not to use `window.errorRate`.
- **Rationale**: the Simulator's history capture (`tests/sim-contract/captures/history.200.json`) has
  `errorRate: 1` with `errors: 0, timeouts: 2`: `errorRate` mixes timeouts and errors, and the Agent read
  "100% error rate" on P5-injection as instability. `rules-v2` counts timeouts only for the same reason.
  The maintenance capture (`health.200.maintenance.json`) shows `status: DOWN` and `maintenance.active`.
- **Alternatives considered**: telling the Agent to trust `errorRate` (reproduces the miss).

## R4 — Mapping match

- **Decision**: a Mapping applies when its `sourceCode` equals an exam code of the Order and every
  condition holds, comparing values case-insensitively and through `synonyms` of the Mapping catalog
  Evidence (a value matches a canonical value when it is that value or one of its listed variants).
  Exactly one applicable Mapping → apply it; zero or several → no Mapping (fall through).
- **Rationale**: this is the Validator's and `rules-v2`'s comparison (`Core.Conditions`,
  `Core.MappingMatch`), stated in words; the catalog Evidence already carries `synonyms` (004 on master).
- **Alternatives considered**: pre-computing the match in the input (would change Evidence building, out
  of scope FR-010, and would hand the Agent the Rules answer).

## R5 — Tests without a live provider

- **Decision**: a new `SignalNoir.Tests.Proposers.TestAgentPromptV2` reads `Agent.Prompt()` and the
  version recorded on a Proposal made through `AgentWithFakeRuntime`; `TestProposerModes` now expects
  `agent-v2`. Model behaviour is measured by the tuning rehearsal (FR-016), labelled development.
- **Rationale**: the prompt's effect on a real model cannot be a unit test; its content and version can.
  Tests run on the dev container `signalnoir-iris` (`IRISAPP`), as every suite in the repository.
- **Alternatives considered**: golden answers from a recorded model (Replay never counts as a real run,
  Constitution VIII).

## R6 — Reserved data

- **Decision**: the prompt is written from the spec, the run_000001 export (tuning only), the public
  Simulator contract captures and `baseline-rules.md`; the Simulator catalog classes are not opened.
- **Rationale**: the catalog may hold the reserved variants and answer key, which the Agent's author must
  not read before the freeze (Constitution VIII).

## Verification log

- **T001 baseline (2026-11-01)**, master `846a25c` on the dev container: 466 tests passed, 1 failed
  (`TestResolution:TestNoteIsRecordedAsEvidenceWithoutDossierEvidence`, already on master; it passed on
  the next run, so it is intermittent).
- **T011 (2026-11-01)**, branch `017-agent-prompt-v2`: 473 passed, 0 failed, including
  `TestAgentPromptV2` (7 tests) and `TestProposerModes` with `agent-v2`. `TestAgentPromptV2` failed 5 of
  7 before the prompt change.
