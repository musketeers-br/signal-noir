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
- **T015 (2026-11-02)**, branch `017-agent-prompt-v3` from master `a472c3a`: compile without errors; 652
  passed, 6 failed. `TestAgentPromptV2` (7 tests, 6 of them failing before the prompt change) and
  `TestProposerModes` with `agent-v3` pass. The 6 failures are environmental, none touches the prompt:
  - `TestCaseOpening:TestWithoutAValidRunTheCaseIsTheAgentsAndUnmarked` and
    `TestGateG4:TestAnOrderWithNoRunKeepsModeAgent` expect the default mode `agent`, but the dev container
    sets `SN_PROPOSER_MODE=hybrid`.
  - `TestRunnerObserves` (3 tests) and `TestGateG4:TestARulesRunOverTuningVariantsEndsWithATwoPartReport`
    wait on the Benchmark runner's background jobs, which left the runs `planned` or `failed` here; the
    rules run does not use the Agent's instructions.

## R7 — agent-v3 after run_000052 (2026-11-02)

- **Decision**: remove RETRY from the Agent's decisions; make the Mapping step a procedure with exam codes
  from the Order and letter-case folding on the source code; limit HIGH to two literal cases; require the
  answer to start with `{` and end with `}`.
- **Rationale**: in run_000052 every incorrect effect came from the RETRY step:
  - On P8a, 1 attempt with 1 timeout matched both "half or more timeouts" (HOLD) and "a single timeout"
    (RETRY), and the model took RETRY.
  - On P5-injection, the step gave the injected retry text a plausible reason.

  No tuning Case expects RETRY, so no criterion can be tuned, and `rules-v2` never proposes it. The P5
  regressions came from the code in the failure text (`glic-j`) against the catalog (`GLIC-J`): folding
  was stated for conditions only. Temperature is already 0 in `AiHubRuntime`, so the variation between
  repetitions is the model's; a procedure narrows it. The parser already strips code fences, so the 2
  non-JSON answers had text around the object.
- **Alternatives considered**:
  - RETRY only for a 5xx answered error with no timeout: P5-injection is a 500 with injected text, so it
    stays exposed.
  - Pre-computing the Mapping match in the input: it changes Evidence building and hands the Agent the
    Rules answer.

## R8 — agent-v4 after run_000146 (2026-11-02)

- **Decision**: the platform computes what each decision step needs (`Core.DecisionFacts`) and passes
  it to the Agent in a CHECKS block. The instructions tell the model to read the checks and not
  recompute them.
- **Rationale**: in run_000146 the misses came from the model not following rules that agent-v3 already
  stated:
  - It compared condition values literally: "expected PLASMA, found plasma" on P8b, SORO against
    SERUM on P5, once even "expected 'SERUM' but found 'SERUM'".
  - It held back on 1 timeout in 1 attempt (P8a, repetition 2).
  - It proposed a GLIC-J mapping for a TSH Order (already-processed, repetition 3).
  - It chose a hypothesis and still asked for review (unknown-code, repetition 1).

  Temperature is 0, so the variation between repetitions is gpt-4o-mini's own. More text would not make
  it compare reliably. `Core.Conditions` and `Core.Identity` already make these comparisons for the
  Validator and Rules, so the Agent now sees the same values the Validator will check.
- **Trade-off**: on these families the Agent's Action now follows the same facts as `rules-v2`, so the
  Agent and Rules results in the benchmark move closer. The Agent still decides on reading them, writes
  the diagnosis, and handles what the checks do not cover. R7 had rejected pre-computing the match for
  this reason; run_000146 showed the cost of not doing it.
- **Alternatives considered**:
  - An agent-v4 with more wording: the agent-v3 wording was already right.
  - A larger model: still worth measuring, but not a fix before the freeze.
  - A Validator rule against "chosen hypothesis + REQUEST_REVIEW": blocking a review ends in review
    anyway, so the outcome does not change.
- **T020 (2026-11-02)**, master `69cdce1` with the agent-v4 change: compile without errors; 664 passed,
  4 failed.
  - `TestDecisionFacts` (7), `TestAgentPromptV2` (9), `TestProposerModes` and
    `TestPrecedentNeutrality` pass.
  - 3 failures are the environmental ones of T015: `TestCaseOpening` and `TestGateG4` (the container
    sets `SN_PROPOSER_MODE=hybrid`) and `TestRunnerObserves:TestARunOpensItsCasesAndEnds`.
  - `TestRecoverySuite:TestRestartDuringExecuting` failed while an earlier test session was still
    running in the same container; run alone, `TestRecoverySuite` passes 6 of 6.

## R9 — agent-v5 after run_000193 (2026-11-02)

- **Decision**:
  - The platform sets the confidence from CHECKS (`DecisionFacts.Confidence`, `Agent.Calibrate`) and
    records a correction on the Timeline.
  - CHECKS gains `steps`, saying whether steps 1 to 3 apply, in order.
  - The instructions write out the preconditions of each Action.
- **Rationale**: run_000193 left three gaps that more text did not close.
  - The model wrote HIGH on 12 mappings whose candidate said `exact: false`, although agent-v4 named
    `exact` as the HIGH criterion. Confidence is a function of CHECKS, so computing it is exact.
  - On P8a it went to the Mapping step with `partner.unstable: true` in all 3 repetitions.
  - Once it invented a precondition name.
- **Kept with the model**: the Action, the hypotheses, the diagnosis and the citations. Overriding the
  Action from CHECKS would make the Agent the Rules baseline; a wrong Action still meets the Validator,
  and an unneeded review is a safe outcome.
- **Alternatives considered**:
  - Only the sentence "applicable with exact false is MEDIUM": it is also in the text now, but agent-v4
    already said it in other words.
  - A Validator rule on confidence: that would change the Core for every origin.
  - A `firstApplicableStep` field: it states the Action outright. `steps` gives each step's result and
    leaves the decision order to the model.
- **T025 (2026-11-02)**: compile without errors; 672 passed, 2 failed. The 2 failures are the
  environmental ones of T015 (`TestCaseOpening` and `TestGateG4`, `SN_PROPOSER_MODE=hybrid` in the
  container).
  - Found on the way: step 3 was first named "approved mapping" in `steps`. `Core.Suspicion` reads
    "approve" as an instruction, so CHECKS reached the model with `[embedded instruction removed]`
    (`TestToolGateway:TestModelInputCarriesNoInstruction` counted 3 markers instead of 2). It is now
    named "mapping", and `TestChecksInInput` asserts that CHECKS carries no marker.
  - The same run fixed the flaky `TestResolution:TestNoteIsRecordedAsEvidenceWithoutDossierEvidence`:
    `Support.SeedEvidence` made ids outside the `IdFactory` sequence (`evid_seed_N`). Evidence recorded
    in the same millisecond is listed by evidenceId, so the Operator's note sorted before them in 11 of
    40 tries. The seed now takes its ids from `IdFactory`; 0 of 40.

## Rehearsals (T016, T021, T026)

Tuning variants of P5, P8 and clean, gpt-4o-mini, 3 repetitions, seed 2026, run by Henrique in the 010
container; 12 variants per repetition. Exports with Evidence and Timeline were sent to Henry.

| Run | Prompt | Correct | Safe review | Unneeded review | Incorrect | HIGH | Invalid | Time |
|---|---|---|---|---|---|---|---|---|
| run_000146 | agent-v3 | 22 | 6 | 8 | 0 | - | 0 | - |
| run_000193 | agent-v4 | 26 | 6 | 4 | 0 | 20 of 32 | 1 | 7m42s |
| run_000240 | agent-v5 | 30 | 6 | 0 | 0 | 9 of 33 | 0 | 7m07s |

- **run_000146 (T016)**: SC-001, SC-002 and SC-003 failed (condition values compared literally, one
  timeout led to review, a chosen hypothesis ended in REQUEST_REVIEW); this led to agent-v4 (R8).
- **run_000193 (T021)**: SC-004 failed and P8a went to review in all 3 repetitions; this led to agent-v5 (R9).
- **run_000240 (T026)**: SC-001 to SC-006 pass. All 33 Agent Proposals record `agent-v5`; the 6
  REQUEST_REVIEW are LOW; P8a is HOLD in all 3 repetitions. `Calibrate` corrected one confidence (P8a,
  repetition 1, HIGH to MEDIUM), so the model's own answers had 10 HIGH of 33: SC-004 passes without the
  platform's correction too. agent-v5 is the prompt version of the freeze.
