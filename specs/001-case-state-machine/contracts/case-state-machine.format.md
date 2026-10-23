# Contract: format of `contracts/case-state-machine.yaml`

The fields are in [data-model.md](../data-model.md), Part 1. Below is a reference excerpt, with one row of each kind, to fix the syntax. The complete file is in `contracts/case-state-machine.yaml`.

```yaml
version: 1.0.0
supersedes:
  - "prd-signal-noir/addendum.md §D"
  - "architecture-signal-noir.md AD-24 (Pontos fixados)"
parameters:
  approvalTtl: PT15M
  reassessInterval: PT60S
  maxInconclusiveReconciliations: 3
  maxDenials: 2

states:
  - { name: Open,          class: active,   transient: true,  restart: redispatch }
  - { name: Held,          class: waiting,  transient: false, restart: keep }
  - { name: Failed,        class: terminal, transient: false, restart: keep }
  # ... 13 in total

transitions:
  - id: T18
    from: Approved
    to: PendingApproval
    trigger: "Expire command (FR-18)"
    command: Expire
    actors: [sweeper]
    preconditions:
      - { check: state, expected: Approved }
      - { check: approvalExpired, expected: true }
      - { check: noAuthorization, expected: true }
    events: [ApprovalExpired]
    followUp: { outbox: [], inProcess: null, dossier: false, terminal: false }
    decision: D3

  - id: T26
    from: Executing
    to: ReviewRequired
    trigger: "Reconciliation inconclusive after the round limit (D4)"
    command: Reconcile
    actors: [system]
    preconditions:
      - { check: executionOutcome, expected: reconciling }
      - { check: inconclusiveReconciliations, expected: maxInconclusiveReconciliations }
    events: [ReconciliationPerformed, DossierCreated]
    effectsOnRecords: ["Execution stays reconciling", "Dossier reason=outcome_unknown"]
    followUp: { outbox: [], inProcess: null, dossier: true, terminal: false }
    decision: D4
    pendingContractChange: "2.5"
    contractChanges: [C2, C5]

attachments:
  - event: Annotation
    states: ["*"]
    actors: [system, "operator:*"]
    kinds: [receipt_corrected, receipt_missing, new_episode_opened, note]
    terminalKinds: [receipt_corrected, receipt_missing, new_episode_opened]

refusals:
  - { code: INVALID_TRANSITION, when: "(from, to) pair outside the table", records: CommandDiscarded, httpStatus: 409, changesState: false }

decisions:
  - { id: D2, contradiction: 2, replaces: "AD-24: Failed → Investigating", rule: "...", reason: "...", forbids: [[Failed, Investigating]] }

journeyTrace:
  - { journey: UJ-1, step: "step 5", refs: [T11], actors: ["operator:*"] }
```

Format rules:
- Ids in increasing order with no gaps.
- `"*"` in `states` means all states; in `actors`, only as `operator:*`.
- All text in English (Constitution 1.1.0, Language); identifiers as in the contract.
- `StateChanged` never appears in `events`, because it is implicit in every transition.
- A precondition value that names a parameter (e.g. `maxDenials`) resolves against `parameters`.
