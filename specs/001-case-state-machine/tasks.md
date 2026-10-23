---

description: "Task list for the normative Case state machine (story 2.2 / B01)"
---

# Tasks: Normative Case state machine

**Input**: Design documents from `/specs/001-case-state-machine/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: mandatory (Constitution: TDD; Principle IX). This story has no submission code (the calendar gate of Constitution 1.1.0 forbade it before 10/26; 1.2.0 lifted it). What is tested is the table's validator. Each rule first enters as a failing negative case (an invalid YAML plus the expected message) and only then as validator code. The Core's parity test belongs to Phase B, in another story, whose Plan chooses the language (research R4).

**Language**: tasks, code, comments and test names are in English (Constitution 1.1.0, Language).

**Organization**: tasks are grouped by the spec's User Stories. The whole table (T01–T29) is transcribed in the Foundational phase because every story depends on it. Each story adds its YAML sections, the validator rules that prove its criterion, and the negative cases for those rules.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no pending dependency)
- **[Story]**: the spec's User Story (US1–US5)

## Path Conventions

- Normative table: `contracts/case-state-machine.yaml`
- Validator: `contracts/tools/validate_state_machine.py`, which exposes `validate(yaml_path, spec_path, openapi_path) -> list[str]` (list of errors; empty = valid) and a CLI with `--file` (default `contracts/case-state-machine.yaml`)
- Negative cases: `contracts/tools/tests/state_machine/<name>.yaml`, listed in `contracts/tools/tests/state_machine/cases.json` as `[{ "file": "<name>.yaml", "expect": "<message excerpt>" }]`
- Case runner: `contracts/tools/test_validate_state_machine.py`. For each case, it runs `validate` and fails if no message contains `expect`. Then it requires zero errors on the real table.
- Test command: `uv run --with pyyaml python contracts/tools/test_validate_state_machine.py`
- Each negative case is a copy of the real table with **one** violation. While the real table does not exist (Phase 2), use `contracts/tools/tests/state_machine/_base.yaml` (T003) as the base.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: folder structure and test runner

- [X] T001 Create directory `contracts/tools/tests/state_machine/` with an empty `cases.json` (`[]`) and a `README.md` explaining the case format (one violation per YAML, `expect` = substring of the validator message) and the test command from Path Conventions
- [X] T002 Create the test runner `contracts/tools/test_validate_state_machine.py`: load `cases.json`, import `validate` from `contracts/tools/validate_state_machine.py`, assert each case produces an error containing `expect`, then assert `validate("contracts/case-state-machine.yaml", "specs/001-case-state-machine/spec.md", "contracts/openapi-signalnoir.yaml")` returns no errors; print `ok`/`FAIL` per case like `contracts/tools/validate_fixtures.py`; exit 1 on any failure
- [X] T003 [P] Create `contracts/tools/tests/state_machine/_base.yaml`: a minimal valid table following [contracts/case-state-machine.format.md](contracts/case-state-machine.format.md) (header, `parameters`, all 13 `states`, transitions T01–T03 copied from the spec so the ids stay sequential, empty `attachments`, `refusals` and `journeyTrace`), used as the starting point for negative cases until the real table exists

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: basic validator and the complete T01–T29 table, which every story depends on

**⚠️ CRITICAL**: no User Story starts before this phase ends

### Tests first (must fail)

- [X] T004 [P] Add negative case `states-missing-failed.yaml` (13 states minus `Failed`) to `contracts/tools/tests/state_machine/` with `expect: "states differ from CaseState"` in `cases.json`
- [X] T005 [P] Add negative case `transition-without-precondition.yaml` (T03 with `preconditions: []`) with `expect: "T03: no preconditions"` in `contracts/tools/tests/state_machine/cases.json`
- [X] T006 [P] Add negative case `unknown-event.yaml` (T01 `events: [ApprovalTimedOut]`) with `expect: "T01: event ApprovalTimedOut not in TimelineEventType"` in `contracts/tools/tests/state_machine/cases.json`
- [X] T007 [P] Add negative case `unknown-command.yaml` (T03 `followUp.outbox: [Investigar]`) with `expect: "T03: command Investigar not allowed"` in `contracts/tools/tests/state_machine/cases.json`
- [X] T008 [P] Add negative case `spec-parity-actor.yaml` (T03 `actors: [sweeper]`) with `expect: "T03: actors differ from spec.md"` in `contracts/tools/tests/state_machine/cases.json`
- [X] T009 [P] Add negative case `id-gap.yaml` (Ids T01, T03 without T02) with `expect: "transition ids must be sequential"` in `contracts/tools/tests/state_machine/cases.json`
- [X] T010 Run the test command and confirm T004–T009 fail because `contracts/tools/validate_state_machine.py` does not exist yet (record the red run in the PR description)

### Implementation

- [X] T011 Create `contracts/tools/validate_state_machine.py` with the module docstring and CLI in the style of `contracts/tools/validate_fixtures.py`: load the YAML, read `CaseState` and `TimelineEventType` enums and the `Actor` pattern from `components.schemas` of `contracts/openapi-signalnoir.yaml`, and parse the transition table of `specs/001-case-state-machine/spec.md` (rows starting with `| T\d\d |`: Id, `From → To`, `Actor`)
- [X] T012 Implement rule 1 (states set == `CaseState` enum, message `states differ from CaseState: missing=[…] extra=[…]`) in `contracts/tools/validate_state_machine.py`
- [X] T013 Implement rule 3 (each transition: non-empty `actors`, each matching the `Actor` pattern where `operator:*` is allowed; non-empty `preconditions`; each event in `TimelineEventType` and `StateChanged` not listed; `followUp` present; each outbox/`command` in {`Investigate`, `Execute`, `Reconcile`, `Expire`, `Reassess`, `Resume`, `decideProposal`, `resolveReview`}) and the sequential-Id check in `contracts/tools/validate_state_machine.py`
- [X] T014 Implement rule 6 (for every spec row: same Id, same `from`/`to` with `—` = `null`, same actor set after normalizing `operator:<name>` to `operator:*` and "`agent`, `rules` or `replay`" to three actors; extra or missing Ids reported) in `contracts/tools/validate_state_machine.py`
- [X] T015 Create `contracts/case-state-machine.yaml` with header (`version: 1.0.0`, `supersedes`, `parameters` from research R6), the 13 `states` with `class`/`transient`/`restart` from [data-model.md](data-model.md) and FR-018, and transitions T01–T29 transcribed from the spec's normative table: `trigger`, `command`, `actors`, `preconditions` using the `check` vocabulary of data-model.md, `events` without `StateChanged`, `effectsOnRecords`, `followUp`, `sameStepAs` (T07→T11/T12, T28→T07→T11, T08 via T28), `decision` (D1–D5), and `pendingContractChange: "2.5"` on T02 and T26
- [X] T016 Run the test command: T004–T009 pass and the real table validates with zero errors

**Checkpoint**: complete table, checked against the OpenAPI and against the spec

---

## Phase 3: User Story 1 - Find the transition and actor of each step of a journey (Priority: P1) 🎯 MVP

**Goal**: the UJ-1 to UJ-4 trace exists as checked data, and José can reproduce it without help

**Independent Test**: the validator accepts the table with a complete `journeyTrace` and refuses a trace that cites a nonexistent transition or leaves out a step; José does the blind proof of [quickstart.md](quickstart.md) §3

### Tests first

- [X] T017 [P] [US1] Add negative case `trace-unknown-ref.yaml` (a UJ-1 step with `refs: [T99]`) with `expect: "journeyTrace UJ-1: unknown ref T99"` in `contracts/tools/tests/state_machine/cases.json`
- [X] T018 [P] [US1] Add negative case `trace-missing-step.yaml` (UJ-2 without step "step 5 (variant)") with `expect: 'journeyTrace UJ-2: missing step "step 5 (variant)"'` (step keys repeat the spec's first column up to the colon) in `contracts/tools/tests/state_machine/cases.json`
- [X] T019 [P] [US1] Add negative case `state-no-exit.yaml` (remove T27 so `Held` has no exit) with `expect: "Held: non-terminal state has no exit"` in `contracts/tools/tests/state_machine/cases.json`

### Implementation

- [X] T020 [US1] Implement rule 2 (each non-terminal state appears in at least one `from` and in at least one `to`, `Open` reached only by creation rows with `from: null`; each terminal appears in a `to` and never in a `from`) in `contracts/tools/validate_state_machine.py`
- [X] T021 [US1] Implement rule 5 in `contracts/tools/validate_state_machine.py`: each `refs` item is an existing transition Id or a spec requirement Id (`FR-0\d\d`); the steps per journey match the "Journey trace" table of `specs/001-case-state-machine/spec.md` (parse its first column); report missing and extra steps
- [X] T022 [US1] Add the `journeyTrace` section to `contracts/case-state-machine.yaml` with every row of the spec's "Journey trace" table (journey, step, refs, actors)
- [X] T023 [US1] Run the test command: T017–T019 pass and the real table has zero errors
- [ ] T024 [US1] Run the blind walkthrough of [quickstart.md](quickstart.md) §3 with José (only the YAML or spec table plus `_bmad-output/initiative-signal-noir/ux-signal-noir/EXPERIENCE.md`, timed, target ≤ 30 min, 100% match) and record the result in the `notes` of entry 2 in `_bmad-output/initiative-signal-noir/tickets/epic-contratos-e-spike/tickets/tickets.toml`

**Checkpoint**: the ticket's main acceptance criterion proven (SC-001, SC-002)

---

## Phase 4: User Story 2 - Refuse and record a disallowed transition or actor (Priority: P1)

**Goal**: the refusal rules are in the table, and the validator guarantees there is no duplicate owner and no misplaced actor

**Independent Test**: the validator refuses an `Open → Executing` row, a `benchmark` outside T12 and a (from, to) pair with two owners; the `refusals` section has the four codes with `changesState: false`

### Tests first

- [X] T025 [P] [US2] Add negative case `open-to-executing.yaml` (extra row T30 `Open → Executing`, actor `system`) with `expect: "T30: transition not in spec.md"` in `contracts/tools/tests/state_machine/cases.json` (already caught by the spec-parity rule of T014, so it passes before T030)
- [X] T026 [P] [US2] Add negative case `benchmark-outside-t12.yaml` (T11 actors `[operator:*, benchmark]`) with `expect: "T11: actor benchmark only allowed in T12"` in `contracts/tools/tests/state_machine/cases.json`
- [X] T027 [P] [US2] Add negative case `proposer-outside-t04.yaml` (T14 actors `[agent]`) with `expect: "T14: proposer actors only allowed in T04"` in `contracts/tools/tests/state_machine/cases.json`
- [X] T028 [P] [US2] Add negative case `duplicate-owner.yaml` (T19 and T20 rewritten with identical preconditions but different actors) with `expect: "Executing → Held: rows T19, T20 not distinguishable by preconditions"` in `contracts/tools/tests/state_machine/cases.json`
- [X] T029 [P] [US2] Add negative case `refusal-changes-state.yaml` (`INVALID_ACTOR` with `changesState: true`) with `expect: "refusals INVALID_ACTOR: must not change state"` in `contracts/tools/tests/state_machine/cases.json`

### Implementation

- [X] T030 [US2] Implement rule 4 in `contracts/tools/validate_state_machine.py`: rows sharing the same (`from`, `to`) pair must differ in at least one precondition `check`/`expected` pair (review H-1); `benchmark` only in T12; `agent`/`rules`/`replay` only in T04; `sweeper` only in rows listed by FR-017 (T06, T18)
- [X] T031 [US2] Implement the `refusals` checks in `contracts/tools/validate_state_machine.py`: exactly `INVALID_TRANSITION`, `INVALID_ACTOR`, `STALE_VERSION`, `APPROVAL_EXPIRED`; each with `records: CommandDiscarded` and `changesState: false`
- [X] T032 [US2] Add the `refusals` section (four rules, `when` text from spec FR-012 and FR-007, `httpStatus` 409/403 where exposed by the API, `pendingContractChange: "2.5"` on the `CommandDiscarded` payload per [contracts/openapi-delta.md](contracts/openapi-delta.md) C4) and the `CommandDiscarded` attachment (all states, actor of the refused command) to `contracts/case-state-machine.yaml`
- [X] T033 [US2] Run the test command: T025–T029 pass and the real table has zero errors

**Checkpoint**: SC-005 proven; no transition with two owners

---

## Phase 5: User Story 3 - Waiting, rejection and expiration with a single owner per transition (Priority: P2)

**Goal**: `Held`, `Rejected` and expiration with their owner, counter and parameters fixed and checked

**Independent Test**: the validator refuses an expiration without `sweeper`, an exit from `Held` other than T27 and a `maxDenials` different from the one used in T13–T15

### Tests first

- [X] T034 [P] [US3] Add negative case `expire-by-system.yaml` (T18 `actors: [system]`, spec parity check disabled via a copied spec fixture `contracts/tools/tests/state_machine/spec-expire-by-system.md`) with `expect: "T18: expiration must be owned by sweeper only"` in `contracts/tools/tests/state_machine/cases.json` (the optional `spec` field is already supported by the runner since T002)
- [X] T035 [P] [US3] Add negative case `held-extra-exit.yaml` (extra row `Held → PendingApproval`) with `expect: "Held: only exit allowed is T27"` in `contracts/tools/tests/state_machine/cases.json`
- [X] T036 [P] [US3] Add negative case `denials-param-mismatch.yaml` (`parameters.maxDenials: 3` while T15 expects `denialCount = 2`) with `expect: "T15: denialCount must equal parameters.maxDenials"` in `contracts/tools/tests/state_machine/cases.json`. Also add `review-auto-exit.yaml` (T29 owned by `system`) with `expect: "T29: ReviewRequired exits only by operator"`, the test for the `ReviewRequired` check of T037

### Implementation

- [X] T037 [US3] Implement the single-owner checks in `contracts/tools/validate_state_machine.py`: any row with `command: Expire` has `actors == [sweeper]`; `Held` exits only through the row whose `command` is `Reassess`; `ReviewRequired` exits only through rows with actor `operator:*`; precondition values written as parameter names (`maxDenials`, `maxInconclusiveReconciliations`) resolve against `parameters`, and T15's `denialCount` equals `parameters.maxDenials`
- [X] T038 [US3] Review T11–T18 and T27 in `contracts/case-state-machine.yaml` against spec FR-006, FR-007, FR-009 and the Clarifications (denialCount never reset; same Proposal stays current after T18): `effectsOnRecords` says "increments denialCount" only on T13 and "Proposal stays current" on T18
- [X] T039 [US3] Run the test command: T034–T036 pass and the real table has zero errors

**Checkpoint**: H-1 closed (expiration, `Held` and `Rejected` with one owner each)

---

## Phase 6: User Story 4 - Uncertainty and closure without a duplicated effect (Priority: P2)

**Goal**: D3 and D4 complete in the table, with the pending contract changes listed for 2.5

**Independent Test**: the validator refuses `Executing → PendingApproval`, a T26 without `DossierCreated` and a revalidation without `noAttemptSent`; the CLI output lists C1–C5 as pending for 2.5

### Tests first

- [X] T040 [P] [US4] Add negative case `executing-to-pending.yaml` (extra row `Executing → PendingApproval`) with `expect: "Executing → PendingApproval is forbidden by D3"` in `contracts/tools/tests/state_machine/cases.json`
- [X] T041 [P] [US4] Add negative case `t26-without-dossier.yaml` (T26 `events: [ReconciliationPerformed]`, `followUp.dossier: false`) with `expect: "T26: rows into ReviewRequired must emit DossierCreated"` in `contracts/tools/tests/state_machine/cases.json`
- [X] T042 [P] [US4] Add negative case `revalidation-after-attempt.yaml` (T19 without the `noAttemptSent` precondition) with `expect: "T19: revalidation exits require noAttemptSent"` in `contracts/tools/tests/state_machine/cases.json`. Also add `unmarked-contract-change.yaml` (T26 without the marker; tests T044) and `exception-trigger-elsewhere.yaml` (T27 with a `newException` precondition; tests the D1 rule of T043). The `decisions` section (T045) is data and was written before these cases so they can derive from the real table

### Implementation

- [X] T043 [US4] Implement in `contracts/tools/validate_state_machine.py`: an explicit `forbidden` list (from the YAML `decisions` entries, field `forbids: [["Executing","PendingApproval"], ...]`) checked against all rows; the D1 rule `exceptionTriggersOnlyFrom` (only rows from those states may carry a `newException` precondition); every row with `to: ReviewRequired` emits `DossierCreated` and has `followUp.dossier: true`; rows triggered by `revalidationFailed` (T19, T21, T22) carry `noAttemptSent` and an `effectsOnRecords` entry containing "authorization voided"
- [X] T044 [US4] Implement the pending-contract-change report in `contracts/tools/validate_state_machine.py`: collect every element with `pendingContractChange`, print them at the end under `pending contract changes (2.5)` with their `contractChanges` ids (new optional field citing openapi-delta items), and accept enum values outside the OpenAPI only when marked
- [X] T045 [US4] Add the `decisions` section (D1–D5: `id`, `rule`, `reason`, `forbids`, `contradiction` 1–5, `replaces` naming the §D or AD-24 line) to `contracts/case-state-machine.yaml`, with D3 forbidding `Approved → Held`, `Approved → Cancelled`, `Executing → PendingApproval` and `Investigating → ResolvedByPriorReceipt`, D2 forbidding `Failed → Investigating`, and D1 adding the rule `exceptionTriggersOnlyFrom: [PendingApproval]` (the validator, in T043, rejects any row other than T16 whose preconditions include `{check: newException}`)
- [X] T046 [US4] Add the attachments for `Executing`/`ReviewRequired` (`RevalidationPerformed`, `AttemptRecorded`, `ReconciliationPerformed` including the conclusive-in-ReviewRequired note from D4) to `contracts/case-state-machine.yaml`
- [X] T047 [US4] Run the test command: T040–T042 pass, the real table has zero errors, and the CLI output lists C1–C5 of [contracts/openapi-delta.md](contracts/openapi-delta.md)

**Checkpoint**: contradictions 3 and 4 recorded and checked

---

## Phase 7: User Story 5 - A terminal state never reopens (Priority: P3)

**Goal**: terminal states without exits, restricted attachments in terminal states, new episode and D5 in the table

**Independent Test**: the validator refuses an exit from `Failed` and an `Annotation` in a terminal state with a `kind` outside `receipt_corrected`, `receipt_missing` and `new_episode_opened`

### Tests first

- [X] T048 [P] [US5] Add negative case `failed-reopens.yaml` (extra row `Failed → Investigating`) with `expect: "Failed: terminal state has an exit"` in `contracts/tools/tests/state_machine/cases.json` (already caught by rule 2 of T020 and by D2's `forbids`, so it passes before T051). The attachments section (T052) is data and was completed before these cases so they derive from the real table
- [X] T049 [P] [US5] Add negative case `terminal-annotation-kind.yaml` (Annotation attachment allowing `note` in terminals) with `expect: "Annotation: terminal states only accept receipt_corrected, receipt_missing, new_episode_opened"` in `contracts/tools/tests/state_machine/cases.json`
- [X] T050 [P] [US5] Add negative case `terminal-attachment.yaml` (an `ExceptionRecorded` attachment listing `Resolved`) with `expect: "ExceptionRecorded: not accepted in terminal state Resolved"` in `contracts/tools/tests/state_machine/cases.json`

### Implementation

- [X] T051 [US5] Implement in `contracts/tools/validate_state_machine.py`: terminal states accept only the `Annotation` (with a `terminalKinds` subset of the three kinds) and `CommandDiscarded` attachments; `"*"` in `states` expands to all 13 states before the check
- [X] T052 [US5] Complete the `attachments` section of `contracts/case-state-machine.yaml` with every row of the spec's attachments table: the `ExceptionRecorded` row with its per-state notes from D1 and the Clarifications (no restart in `Investigating`), and `Annotation` with `kinds` and `terminalKinds` marked `pendingContractChange: "2.5"` (C3)
- [X] T053 [US5] Check T02 and T25 in `contracts/case-state-machine.yaml`: T02 records `previousEpisodeCaseId` (C1, `pendingContractChange: "2.5"`) and the `new_episode_opened` annotation on the previous Case; T25 `sameStepAs: [T02]` conditioned on `pendingReassessmentExceptions`
- [X] T054 [US5] Run the test command: T048–T050 pass and the real table has zero errors

**Checkpoint**: contradictions 2 and 5 recorded and checked; the five decisions covered (SC-004)

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: CI, replacement of the old sources and hand-off to 2.5

- [X] T055 Add a step "State machine validates" to `.github/workflows/contracts.yml` running `uv run --with pyyaml python contracts/tools/test_validate_state_machine.py`, and add `specs/001-case-state-machine/spec.md` to the `paths` of both `pull_request` and `push` triggers
- [X] T056 [P] Mark `addendum.md` §D as superseded in `_bmad-output/initiative-signal-noir/prd-signal-noir/addendum.md`: a heading note saying the section was replaced on 2026-10-22 by the normative state machine (`contracts/case-state-machine.yaml`, `specs/001-case-state-machine/spec.md`) and is kept only as history, written in Portuguese like the rest of the addendum; table kept unchanged
- [X] T057 [P] Mark the "Pontos fixados" table of AD-24 as superseded in `_bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md` with the same note, keeping the AD-24 rule (Core owns the table, `INVALID_ACTOR`)
- [X] T058 [P] Update FR-5 in `_bmad-output/initiative-signal-noir/prd-signal-noir/prd-signal-noir.md` to point to `contracts/case-state-machine.yaml` instead of `addendum.md` §D, and FR-3's "returns to `Investigating`" sentence to reference decision D1
- [X] T059 [P] Add a note to entry 5 in `_bmad-output/initiative-signal-noir/tickets/epic-contratos-e-spike/tickets/tickets.toml` linking `specs/001-case-state-machine/contracts/openapi-delta.md` (C1–C8) as input for freezing the contract 1.0.0
- [X] T060 Run every command of [quickstart.md](quickstart.md) §1, §2 and §4 (state machine tests, Redocly lint, fixture validation) and confirm all pass, with the OpenAPI and fixtures untouched (`git diff --exit-code -- contracts/openapi-signalnoir.yaml contracts/fixtures`)
- [ ] T061 Request Henrique's review of `contracts/case-state-machine.yaml` and the spec (SC-006: no open transition, no double owner) and record the outcome in the notes of entry 2 in `_bmad-output/initiative-signal-noir/tickets/epic-contratos-e-spike/tickets/tickets.toml`
- [X] T062 Translate every artifact of `specs/001-case-state-machine/` and the text of `contracts/case-state-machine.yaml` to English (Constitution 1.1.0, Language), adjusting the validator's spec parsing and messages, replacing the ad hoc case scripts with the committed generator `contracts/tools/tests/state_machine/generate_cases.py`, and regenerating the negative cases

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies
- **Foundational (Phase 2)**: depends on Setup; blocks every story
- **US1 (Phase 3)** and **US2 (Phase 4)**: depend only on Phase 2; can run in parallel with each other
- **US3 (Phase 5)**: depends on Phase 2; T034 uses the optional `spec` field of the case format
- **US4 (Phase 6)**: depends on Phase 2; T045 depends on T043
- **US5 (Phase 7)**: depends on Phase 2; T052 completes the attachments that US2 (T032) and US4 (T046) started, so do it after them, or combine the edits
- **Polish (Phase 8)**: T055 after every story; T056–T059 can start right after Phase 2; T060 and T061 last

### Within Each User Story

- Negative cases first, all [P] (different files; the only shared edit is adding a line to `cases.json`)
- Validator rules next, in `contracts/tools/validate_state_machine.py` (shared file: no [P] across stories)
- YAML sections after the rules
- Run the suite to close the story

### File conflicts

`contracts/tools/validate_state_machine.py`, `contracts/case-state-machine.yaml` and `contracts/tools/tests/state_machine/cases.json` are touched by every story. Whoever works in parallel should do the stories on short branches and integrate them in sequence.

## Parallel Example: User Story 2

```bash
Task: "Add negative case open-to-executing.yaml in contracts/tools/tests/state_machine/"
Task: "Add negative case benchmark-outside-t12.yaml in contracts/tools/tests/state_machine/"
Task: "Add negative case proposer-outside-t04.yaml in contracts/tools/tests/state_machine/"
Task: "Add negative case duplicate-owner.yaml in contracts/tools/tests/state_machine/"
Task: "Add negative case refusal-changes-state.yaml in contracts/tools/tests/state_machine/"
```

The same holds for each story's negative cases and for T056–T059 of Polish.

## Implementation Strategy

### MVP (User Story 1)

1. Phases 1 and 2: complete table, checked against the OpenAPI and the spec
2. Phase 3: journey trace and José's blind proof
3. **Stop and validate**: with this the ticket's `verify` is already met (13 states and UJ-1 to UJ-4 traceable), and ticket entries 3, 4 and 5 can start

### Incremental Delivery

1. US2: refusals and single owners (criterion "a disallowed transition is refused and recorded")
2. US3 and US4: the waiting, expiration and uncertainty decisions become checked by rules
3. US5: terminal states and new episode
4. Polish: CI, replacement notes, hand-off to 2.5 and Henrique's review

Reference deadline: finish before 10/26, when the three fronts start.
