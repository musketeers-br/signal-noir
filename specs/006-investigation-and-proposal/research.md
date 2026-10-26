# Phase 0 Research: Investigation and Proposal Production

**Date**: 2026-10-25
**Instance**: `congenial-waffle-iris-1`, namespace `IRISAPP`, through iris-agentic-dev.

## Calendar-gate exception

On 2026-10-25 Henry asked for the full cycle of feature 006, including implementation, before the
2026-10-26 gate (same decision as for 003). Recorded here for the G2 review.

## R0 — AI Hub on the dev instance

- **Finding**: `%AI.Agent`, `%AI.ToolSet`, `%AI.Provider`, `%AI.Agent.Session`, `%AI.LLM.Response`
  do not exist on the running instance (`%Dictionary.CompiledClass.%ExistsId` = 0 for each). The
  instance is IRIS 2026.2 build 221. No build 154 image is loaded locally, and there is no `.env` /
  provider key.
- **Decision**: build and test everything that does not need a live model; isolate the AI Hub in
  one adapter (`Proposers.AiHubRuntime`) reached through the internal `AgentRuntime` port, with
  dynamic dispatch (`$ClassMethod`, `$Method`, `$Property`) so the class compiles without `%AI.*`.
  When the classes or the key are missing, the adapter returns "provider unavailable", which is the
  tested path to `ReviewRequired`.
- **API used by the adapter (from the 001 stack research, documentation only — NOT verified)**:
  `%AI.Provider.Create(name, {"api_key": key})`, `%AI.Agent.%New(provider)`, properties `Model`,
  `SystemPrompt`, `CreateSession()`, `Chat(session, input)` returning `%AI.LLM.Response` with
  `Content`. Token usage property names are unknown; the adapter reads them defensively.
- **Open task**: T060 verifies the adapter on build 154 with a real key before G2 and records the
  result here.

## R1 — Agent in pre-collected mode

- **Decision**: the Investigation collects the base package; the Agent receives it in one `Chat`
  call (FR-017 fallback). Native Tool calling would need a `%AI.ToolSet` subclass (XData
  definition), which cannot compile without `%AI.*` and could not be verified.
- **Rationale**: the spec allows it; both modes use the same Tools, budget and recording; the real
  AI Hub call still happens.
- **Prompt**: `XData SystemPrompt` in `Proposers.Agent`, `PROMPTVERSION` parameter; the Evidence is
  passed as a JSON block labelled data; the answer must be one JSON object in the shape of the
  contract's Proposal (diagnosis, action, params, confidence, preconditions, priorReceiptCandidate).

## R2 — Server-enforced budget

- **Decision**: `InvestigationRecord.toolCalls` and `startedAt`/`budgetMs` are the authority.
  `CaseService.ChargeToolCall` checks and increments them under the Case lock before any source is
  read; a 7th call or a call after the deadline closes the Investigation (`ReviewRequired`) and is
  refused. The proposer runs in a `JOB` worker; the coordinator waits until the record leaves `open`
  or the deadline passes, then closes it. Completion and closure both require `status = open` under
  the Case lock, so exactly one wins.
- **Alternatives**: in-process deadline (cannot stop a hung call); `%SYSTEM.Event` signalling
  (more moving parts than polling the record every 50 ms).
- **Verified live**: `JOB ##class(...).Method(args)` runs in `IRISAPP` and sees committed data
  (used by the 003 concurrency tests on this instance).

## R3 — Read-only by construction

- **Decision**: `Core.ToolCatalog` lists the 7 reading Tools of the contract's Evidence `source`
  enum. `ToolGateway.Invoke` refuses any other name before charging the budget and records the
  refusal (`Annotation {kind: write_attempt_blocked}`). Sources only issue HTTP `GET` to the
  Simulator read endpoints (`/partners/{id}/health`, `/partners/{id}/history`,
  `/origin/orders/{orderId}`, `/receipts?patientId=`) or read the Case store.
- **Absence vs fact**: a source that cannot answer (connection error, non-2xx, reference data not
  loaded) yields Evidence `kind = absence` with `result = {available: false, reason}`.

## R4 — Embedded instructions

- **Decision**: `Core.Suspicion.Scan(value)` walks every string of the result and the Order snapshot
  and returns excerpts matching a fixed, case-insensitive phrase list (EN/PT): "ignore previous",
  "ignore all previous", "disregard", "you are now", "system:", "assistant:", "approve", "execute",
  "set state", "change the action", "ignore as instruções", "ignore as instrucoes", "aprove",
  "execute agora". A match sets `suspicious`, keeps the raw result, and appends
  `Annotation {kind: embedded_instruction_blocked}`. Nothing downstream reads `suspicious` to choose
  a path; the conversion and the budget are identical.
- **Rationale**: the guarantee does not come from detection (which can miss) but from the
  architecture: the answer can only name a catalog Action, which the Validator and the Operator
  still check. Detection exists to record the attempt (FR-010).

## R5 — Conversion of answers

- **Decision**: `Core.ProposalShape.Convert(answer, evidenceIds, author, versions, metrics)`:
  requires `diagnosis.summary`, `claims[]` each with ≥1 evidenceId from the Case, `hypotheses[]` with
  `status` chosen/discarded and a `reason` for discarded; `action` in the catalog; `params` only
  `mappingId`, `mappingVersion`, `reason`, with both mapping fields for `APPLY_APPROVED_MAPPING`;
  `confidence` in `HIGH/MEDIUM/LOW` (contract enum changed from `ALTA/MEDIA/BAIXA`, contract change 006); `preconditions[].check` in the closed vocabulary; scope forced
  to `single_case`. Any failure → ordered reasons, no Proposal.
- **Agent text**: the adapter strips a surrounding Markdown code fence and parses one JSON object;
  anything else is "invalid proposer response".

## R6 — Immutability

- **Decision**: `ProposalRecord` stores a `contentHash` (SHA-256 of its content JSON) at insert;
  `%OnBeforeSave` refuses an update whose recomputed hash differs. Only `current` and
  `supersededBy` may change (supersession).

## R7 — Where the mode is read

- **Decision**: `Proposers.Factory.For(mode)` is the only reader of `CaseRecord.proposerMode`.
  The Investigation stores the chosen proposer class on its record so the worker rebuilds it.
  Tests inject scripted proposers and sources by class name.

## R8 — Validator hand-off

- **Decision**: this feature ends at `DecisionProposed`. Calling the Validator and routing to
  `PendingApproval`/`ReviewRequired` belongs to the Validator integration (004 seam v2, not in this
  branch) and 007's command flow. No mode-dependent routing exists after the port.

## R9 — Scenario instance id

- **Decision**: `OrderIn.Accept(json, transactionId, runId, scenarioInstanceId)` stores the feed
  envelope's `scenarioInstanceId` on the Order; Simulator sources pass it as the required query
  parameter.

## Verification log

| Check | Result |
|---|---|
| `%AI.*` classes on the dev instance | absent (5/5) — R0 |
| Local build 154 image / provider key | none |
| `JOB` + committed reads across processes | works (003 concurrency suite, 100 trials) |
| Baseline at branch start (T001) | 82 pass, 1 fail (`Api.TestHealth`, pre-existing in 001) |

## Implementation verification log (iris-agentic-dev, 2026-10-25)

| Check | Result |
|---|---|
| Full suite after 006 (T042) | 109 test methods pass, 1 fails (the same pre-existing `Api.TestHealth`). 006 adds Core (budget, catalog, suspicion, conversion), Application (investigation, budget, gateway, modes, provider failures) and Api (detail layers) suites. |
| Server-enforced budget | 7th Tool call refused before reaching the source (source read count stays 6); a proposer sleeping past a 1.5 s test budget is closed by the coordinator, and its later answer is recorded as `CommandDiscarded` without a Proposal. |
| Read-only gateway | `partner.send`, `case.transition`, `tool.partner_send`, `approve` refused, nothing charged, each refusal recorded. |
| Record-first | the source double records how many Evidence rows existed when it was read; the returned Evidence id is already stored when `Invoke` returns. |
| Embedded instructions | twin Cases with and without an instruction in the Order notes and Partner log reach the same Action and parameters; the Partner log Evidence is suspicious; both attempts are recorded. |
| AI Hub adapter on this instance | the real `Proposers.Agent` + `AiHubRuntime` end in `ReviewRequired` "provider unavailable: AI Hub is not available on this instance" with the base Evidence kept. The live `%AI.*` path is still unverified (T060). |
| Live HTTP conformance (T039) | `tests/contract/validate_live.py` now also validates `DecisionProposed` details with Evidence and Proposals: all conform. The first run found `priorReceiptCandidate: {}` (an unset `%DynamicObject` property reads as `{}`); fixed to `null`. |
| Frozen fixtures | 25 valid, 0 invalid. |
| Secret audit (T041) | `SN_AI_API_KEY` is read only in `AiHubRuntime` (at call time) and in 001's `Bootstrap` (startup provider setup); `TestProviderFailures.TestKeyNeverPersisted` finds no key in Evidence, Proposal, Timeline or Investigation rows. |
