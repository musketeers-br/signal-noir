# Data Model: Investigation and Proposal Production

All records are in `SignalNoir.Application.Model` and written only by `CaseService`.

## Investigation (`InvestigationRecord`, IdKey `investigationId` = the request's `cmd_` id)

| Field | Rule |
|---|---|
| investigationId | the `Investigate` outbox commandId (one Investigation per request) |
| caseId | link |
| caseVersionAtStart | the Case version the request carried; completion requires it unchanged |
| mode | `agent`, `rules`, `replay` (copied from the Case) |
| proposerClass, sourceClass | classes the worker rebuilds (Factory output, or test doubles) |
| status | `open` → `proposed` / `review` / `discarded` (terminal) |
| startedAt, closedAt, budgetMs (20000), toolCalls (0..6) | budget authority |
| provider, model, promptVersion, policyVersion, mappingVersion | versions |
| durationMs, tokensIn, tokensOut, estCostUsd | metrics (empty when unknown) |
| outcomeReason | e.g. `investigation budget exceeded: time`, `provider unavailable: …` |
| proposalId | when proposed |

## Evidence (`EvidenceRecord`, IdKey `evidenceId` = `evid_…`)

caseId, investigationId, source (contract enum), kind (`fact` / `absence`), calledBy (actor),
paramsJson, resultJson (raw, by value), observedAt, durationMs, suspicious, suspiciousExcerpts
(list), obsoletedBy (empty). Insert-only. Index on caseId.

## Proposal (`ProposalRecord`, IdKey `proposalId` = `prop_…`)

caseId, investigationId, author (`agent`/`rules`/`replay`), createdAt, current, supersededBy,
diagnosisJson, action, paramsJson, scope (`single_case`), confidence, preconditionsJson,
versionsJson (policy, mapping, prompt, model, provider), metricsJson, priorReceiptCandidateJson,
contentHash. Content immutable (hash guard); only current/supersededBy change.

## Order (`OrderRecord`)

+ `scenarioInstanceId` (from the feed envelope).

## Timeline events written

| Event | When | Payload |
|---|---|---|
| `Annotation` `{kind: investigation_started}` | start | investigationId, mode |
| `Annotation` `{kind: evidence, source}` | system Evidence (Exceptions) | evidenceId |
| `ToolCalled` | each Tool call | evidenceId, tool, kind, suspicious, durationMs (refId = evidenceId) |
| `Annotation` `{kind: embedded_instruction_blocked}` | suspicious content | evidenceId, excerpts |
| `Annotation` `{kind: write_attempt_blocked}` | refused Tool | tool |
| `ProposalCreated` | Proposal recorded | proposalId, author, action, confidence |
| `StateChanged` | `→ DecisionProposed` / `→ ReviewRequired` | from, to, reason, caseVersionAfter |
| `CommandDiscarded` | stale/duplicate request, late answer | investigationId, reason |

## State changes

| From | To | Actor | When |
|---|---|---|---|
| Investigating | DecisionProposed | agent / rules / replay | answer converted, Investigation open, version unchanged |
| Investigating | ReviewRequired | system | budget, provider failure, invalid answer, worker failure |

## Commands (CaseService)

| Command | Kind |
|---|---|
| `StartInvestigation(commandId, proposerClass, sourceClass, budgetMs)` | claims the request (`pending → dispatched`), checks state/version, creates the record, records Exceptions as Evidence; else discards |
| `ChargeToolCall(investigationId)` | budget check + increment; closes on breach |
| `RecordEvidence(investigationId, evidence)` | attachment (`ToolCalled` + annotations) |
| `CompleteInvestigation(investigationId, proposal, meta)` | Proposal + `ProposalCreated` + `→ DecisionProposed`, atomic, only while open |
| `CloseInvestigation(investigationId, reason, meta)` | `→ ReviewRequired`, only while open |
| `DiscardAnswer(investigationId, reason)` | `CommandDiscarded` on a closed Investigation |
