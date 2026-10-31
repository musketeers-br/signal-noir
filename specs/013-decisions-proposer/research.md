# Research: Decisions API as a Proposer

**Feature**: 013-decisions-proposer | **Date**: 2026-10-31

## R0 — Live verification (FR-014)

Recorded in [`docs/verification/013-decisions-spike.md`](../../docs/verification/013-decisions-spike.md),
through iris-agentic-dev on `signalnoir-iris` (build 154U, arm64, namespace `IRISAPP`):

- AI Hub route: **not available**. 60 `%AI.*` classes, none for decisions; `%AI.Provider` exposes
  `ChatComplete`/`StreamChatComplete`; `GetCapabilities()` for `openai` lists no decisions capability.
- Direct route (decided by Henry): `%Net.HttpRequest` to `https://api.openai.com/v1/decisions` with TLS
  config `SignalNoirTLS` → HTTP 200 in 930 ms; answer shape
  `{"model", "answers": [{"type": "choice", "name", "choice", "probabilities": [{"value", "probability"}], "confidence"}, {"type": "predicate", "name", "probability"}], "usage": {"input_tokens", "input_tokens_details": {"cached_tokens", "cache_write_tokens"}, "output_tokens", "total_tokens"}}`.
- Failures: unknown model → 404 `error.code = model_not_found`; invalid key → 401
  `error.code = invalid_api_key`, whose `error.message` echoes a masked part of the key.
- Key leak check: 0 occurrences in `docker logs` and `messages.log`.
- Request shape from the official guide (checked 2026-10-31): `model`, `input` (string or messages;
  `input_json` parts with `data`, only in `user` messages), `questions` (1–400, unique `name`,
  `type`, `instructions`; `choices: [{value, description}]` for `choice`). No fallback type: `other`
  is a normal choice value. `refusal` answers have `type: "refusal"` and `name` (full shape not
  documented).

## R1 — Transport

**Decision**: a port `SignalNoir.Core.Port.DecisionsRuntime` (`Decide(body, timeoutSeconds) ->
Result`, `details.answer` = parsed JSON) with the HTTP adapter `SignalNoir.Proposers.DecisionsHttp`.
The key is read from the environment at call time (`SN_DECISIONS_API_KEY`, else `SN_AI_API_KEY` when
`SN_AI_PROVIDER=openai`). Errors become `provider_unavailable` with only `HTTP <status> <error.code>`
or the transport error code; `error.message` is never kept (R0: it echoes the key). The adapter
reuses the TLS config the 015 provider embedder creates (`SignalNoirTLS`, no secret in it).

**Rationale**: the Agent's runtime port pattern (006); fakeable for SC-004.

**Alternatives**: `%AI.Provider` (not possible, R0); Embedded Python `openai` SDK (no decisions
support verified, adds a dependency).

## R2 — Question set and conversion in the core

**Decision**: two pure classes.

- `Core.DecisionQuestions.Build(evidence, order, mappings)` → request body without `model`. One
  `choice` named `action` with options `RETRY`, `HOLD`, `REQUEST_REVIEW`, one
  `APPLY_APPROVED_MAPPING:<mappingId>` per candidate mapping (FR-006), and `other`; one `predicate`
  per Evidence item named `ev:<evidenceId>` with a fixed template ("Does the evidence item with
  evidenceId <id> support choosing an action for this failed delivery?"). Every instruction is a
  constant or a template over system ids, never Order or Partner text (FR-008). The Evidence goes in
  one `user` message as `input_json`, with `suspicious` flags and neutralized results
  (`Core.Suspicion.Neutralize`, as the Agent). Version `decisions-v1`.
- `Core.DecisionAnswer.Convert(response, evidenceIds, candidates, thresholds)` → `Result`: the raw
  Proposal answer (same shape the Agent returns, then `ProposalShape.Convert` as for every origin), or
  an error value: `uncertain` with "proposer uncertain: below threshold | tie | other", `refused`,
  `invalid_response` (missing/duplicate names, unknown choice value, out-of-catalog Action).

Diagnosis: summary "Decisions API chose <value> with probability <p> (confidence <c>)."; one claim per
predicate with probability ≥ threshold, citing that Evidence id, text "<source> supports the
decision (p = <p>)". A predicate whose id is not in the Evidence produces no claim (FR-005). If no
predicate passes, the claim cites the system Exception Evidence when there is one, so the minimum
Evidence rule is judged by the Validator as usual. Confidence enum: `HIGH` ≥ 0.8, `MEDIUM` ≥ 0.5,
else `LOW`. Params and preconditions per Action follow Rules (`HOLD` → `PARTNER_HEALTHY_WINDOW`
expected false; mapping → `mappingId`, `mappingVersion` and `MAPPING_VERSION_UNCHANGED`; `RETRY` →
`PARTNER_HEALTHY_WINDOW` and `ORDER_ACTIVE_AT_ORIGIN` expected true; `REQUEST_REVIEW` →
`reason: "decisions chose review"`).

**Rationale**: Principle I: the conversion is a rule and lives in the core; testable without a key.

## R3 — Candidate mappings shared with Rules

**Decision**: extract the "approved mapping matches an exam code and the specimen type" filter from
`Proposers.Rules` into pure `Core.MappingMatch.Candidates(snapshot, catalogItems)`; Rules and
Decisions both call it. Rules' behavior is unchanged (its tests stay green). The Validator still
checks applicability.

## R4 — Thresholds and versions

**Decision**: parameters of `Core.DecisionAnswer` (`MINTOP = 0.5`, `TIEMARGIN = 0.1`,
`MINPREDICATE = 0.7`), version `decisions-v1` reported as `promptVersion`; model `gpt-6-luna` as a
parameter of the adapter, overridable by `SN_DECISIONS_MODEL`. Uncalibrated start values; changing
them changes the version (Constitution VIII).

## R5 — Usage and cache (FR-010)

**Decision**: `details.tokensIn = usage.input_tokens`, `tokensOut = usage.output_tokens`, and a new
`tokensCached = input_tokens_details.cached_tokens` stored on `InvestigationRecord` (new property,
`ApplyMeta` and `InvestigationService.Work` copy it). `estCostUsd` is not computed (no published
price in the guide).

## R6 — Review reasons (FR-016)

**Decision**: `InvestigationService.FailureReason`: `uncertain` → its message; `refused` → "proposer
refused: <message>" (was "invalid proposer response"; the 006 test is updated). The Decisions adapter
puts only codes in messages. `DossierReason` maps both to `review_requested` (default), quoting the
recorded reason.

## R7 — Mode selection (FR-017)

**Decision**: `CaseService.NewCase` sets `proposerMode` from `Proposers.Factory.ConfiguredMode()`,
which reads `SN_PROPOSER_MODE` (`agent` default; `rules`, `decisions`; anything else → `agent`).
`Factory.ClassFor("decisions")` → `SignalNoir.Proposers.Decisions`; `Ready("decisions")` →
`DecisionsHttp.Configured()` (key present). Replay stays as is: a recorded Decisions answer replays
through `Replay` and is labelled replay.

## R8 — Benchmark (FR-013, US5)

010 has no spec yet. This feature delivers what 010 needs: the mode value in the contract, a
versioned question set and thresholds, and token usage. Listing Decisions in the report is 010's
work (declared dependency).

## R9 — Verification record (2026-10-31)

- Full `SignalNoir` suite through iris-agentic-dev: **339 methods, all passing** (run 159), with the
  new `Core.TestDecisionAnswer`, `Core.TestDecisionQuestions`, `Core.TestMappingMatch` and
  `Application.TestDecisionsProposer` (decisive answer, six review paths, injection, same verdict as
  the Agent, budget, mode selection). Rules suites unchanged after the `MappingMatch` extraction;
  `TestProviderFailures` updated for "proposer refused: …"; `TestCaseMachine` for the new actor.
- Found while testing: `CaseMachine` allowed only `agent`, `rules` and `replay` to move
  `Investigating → DecisionProposed`; `decisions` was added there.
- Contract: `validate_fixtures.py` 31 valid; `validate_live.py` all responses conform.
- **Live smoke (labelled live)**, `DecisionsHttp.Smoke()`: HTTP 200 in 306 ms, `gpt-6-luna`; partner
  `DOWN` + timeout → `HOLD` with probability 0.73 (confidence 0.64), both predicates ≥ 0.9 became
  claims; converted to a `MEDIUM` Proposal answer. Synthetic data only.
- Not done: a live Investigation with `SN_PROPOSER_MODE=decisions` set on the container (it needs a
  container recreate); thresholds are uncalibrated start values.
