# Feature Specification: Operator Console

**Feature Branch**: `005-operator-console`

**Created**: 2026-10-25

**Status**: Draft

**Input**: User description: "the operator console (static SPA over the frozen HTTP contract)." (full
description: `docs/specify-prompts/005-operator-console.txt`)

## Context

The Operator is the human authority of Signal Noir. The console is where they see which Cases need
them, read what failed and why, check the Evidence behind the agent's claims, approve or deny one
exact Proposal, and resolve a Review Dossier with a catalog Action or a cancellation. It talks only
to the product API under the normative contract `contracts/openapi-signalnoir.yaml`; it adds no
endpoint and no field. Its experience is fixed by the UX spine
(`_bmad-output/initiative-signal-noir/ux-signal-noir/EXPERIENCE.md`, `DESIGN.md`).

The console's core promise is honesty: it never shows a refusal, a replay or an uncertain outcome
as success, and it never changes what is on screen before the server says so.

All data is synthetic and every row, header and export says so. UI copy is English.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See which Cases need me, live (Priority: P1)

The Operator opens the console and sees the Case list, filtered by default to "Needs you": Cases
waiting for approval or review. Each row shows the Case, the Order, the partner, the state (glyph
and label), age, the approval deadline when any, the current proposal's Action and confidence, the
last exception, and the synthetic/replay labels. Filters switch between Needs you, Active, Closed
and All. New Cases and state changes appear on their own, without reloading the page; the list
pages back through older Cases with the contract cursor.

**Why this priority**: The list is how the Operator finds work; without it nothing else is reachable.

**Independent Test**: Load the list against contract responses, change the server's answer for the
next poll (a new Case, a state change), and check the rows update in place with focus kept.

**Acceptance Scenarios**:

1. **Given** the console opens, **When** the list loads, **Then** the "Needs you" filter is active and
   only Cases waiting for approval or in review are shown.
2. **Given** the list is shown, **When** the next poll returns a new Case and a changed state,
   **Then** the new row appears and the changed row updates, without a page reload, and a row that
   changed is announced once.
3. **Given** more Cases than one page, **When** the Operator asks for older Cases, **Then** the next
   page is loaded with the contract cursor and appended; there is no infinite scroll.
4. **Given** an empty "Needs you", **When** shown, **Then** it says "No case needs a decision from you
   right now."
5. **Given** any row, **When** shown, **Then** it carries the `SYNTHETIC` label, and `REPLAY` when the
   Case is a replay.

---

### User Story 2 - Read a Case in layers and follow the Evidence (Priority: P1)

Opening a Case shows one state banner with the copy for its state, and the six layers: What failed,
Evidence, Diagnosis, Proposal (Action, parameters, scope, confidence), Approval, Execution & receipt,
plus the Timeline. Only the current Proposal is shown; earlier versions are collapsed. Model,
provider, duration, tool calls, attempts and estimated cost are visible. Evidence is read-only;
clicking an Evidence reference inside a claim moves to that Evidence card and focuses it. Conflicting
Evidence is shown side by side and marked as a conflict; obsoleted Evidence stays, marked
"obsoleted by".

**Why this priority**: Approving responsibly requires reading the decision against its Evidence.

**Independent Test**: Open the P5/P8b contract fixture, check the six layers, follow a claim's
Evidence reference, and check the conflict and obsolete markers.

**Acceptance Scenarios**:

1. **Given** a Case in `PendingApproval`, **When** its detail opens, **Then** the banner says nothing is
   sent until this exact version is approved, and the six layers and the Timeline are shown.
2. **Given** a claim citing Evidence, **When** the Operator activates the reference, **Then** the
   Evidence card is scrolled into view and receives focus.
3. **Given** Evidence that conflicts, **When** the Evidence layer is shown, **Then** the conflicting
   cards are side by side under a conflict marker with its description.
4. **Given** obsoleted Evidence, **When** shown, **Then** it remains visible with "obsoleted by" and the
   newer Evidence's id.
5. **Given** a Case with earlier Proposals, **When** the Proposal layer is shown, **Then** only the
   current one is expanded and the others are in a collapsed "Earlier versions (n)" block.
6. **Given** a Case with no Diagnosis, **When** the Diagnosis layer is shown, **Then** it says "No
   interpretation exists. The agent has not produced one." and is never an empty card.
7. **Given** a layer the Case has not reached, **When** shown, **Then** it says "Not yet. The case has
   not reached this step."
8. **Given** an unknown Case, **When** opened, **Then** "Case not found" with a link back to Cases.

---

### User Story 3 - Approve or deny one exact version (Priority: P1)

From a Case in `PendingApproval`, the Operator opens the approval dialog. The dialog freezes the
proposalId and the Case version at the moment it opens and sends exactly those. Approve and Deny are
separate; Deny requires a reason, which becomes Evidence. Approve is disabled while a request is in
flight. Every server answer has its own treatment and none is misread.

**Why this priority**: This is Principle IV made visible: the Operator approves a specific change,
not an intention, and must never believe something happened that did not.

**Independent Test**: Open the dialog, let the next poll change the Case underneath, approve, and
check the request body; then replay each contract response (201, 200 replay, 409 stale, 409
invalid transition, 400, 404, network error) and check the dialog's state and copy.

**Acceptance Scenarios**:

1. **Given** the dialog was opened at proposal P and version 7, **When** a poll brings version 8 and
   the Operator approves, **Then** the request carries P and 7.
2. **Given** a 201, **When** it arrives, **Then** the dialog closes, a toast says what happens next,
   and the detail refreshes.
3. **Given** a 200 with `idempotentReplay`, **When** it arrives, **Then** the toast says "Already
   approved by {name}. No new effect." and is not styled as a new success.
4. **Given** a 409 `STALE_VERSION`, **When** it arrives, **Then** the dialog stays open, says the
   proposal or case changed and nothing was recorded, hides Approve and Deny, and offers to review the
   new version.
5. **Given** a 409 `INVALID_TRANSITION`, **When** it arrives, **Then** the dialog stays open and says
   the Case is now in another state and nothing was recorded.
6. **Given** a network error, **When** it happens, **Then** the dialog says the request may not have
   reached the server, assumes neither success nor failure, and keeps Approve disabled until the next
   poll shows whether the Case changed.
7. **Given** Deny without a reason, **When** submitted, **Then** it is not sent and the reason field
   says it is required.
8. **Given** only a keyboard, **When** the Operator goes from the list to the Case, opens the dialog,
   approves and returns, **Then** every step is reachable and focus is managed (dialog focus on open,
   back to the trigger on close).

---

### User Story 4 - Resolve a Review Dossier (Priority: P2)

When a Case is in `ReviewRequired`, its Review Dossier sits at the top: reason, partial diagnosis,
hypotheses, conflicts, colliding records with divergent fields marked, unconfirmed candidates, what
is not known, and the suggested next step. The Operator resolves it by choosing a catalog Action
(with only the parameters the catalog allows, mappings taken from the reference list) or cancelling
with a reason. There is no free payload field. Once the Case is closed, the Dossier moves to the
bottom, collapsed.

**Why this priority**: Review is the honest outcome when automation cannot decide; the Operator must
be able to act on it without inventing payloads.

**Independent Test**: Open each Dossier fixture, check its sections, submit an Action that the
validator blocks (422) and one that it accepts (201), and cancel.

**Acceptance Scenarios**:

1. **Given** a Case in `ReviewRequired`, **When** opened, **Then** the Dossier is the first section
   after the banner.
2. **Given** a Dossier whose unknowns list is empty, **When** shown, **Then** it says "Nothing
   flagged", never "everything is known".
3. **Given** the resolution form, **When** shown, **Then** it offers only the catalog Actions and,
   for `APPLY_APPROVED_MAPPING`, only the approved mappings from the reference list; no field accepts
   a free payload.
4. **Given** a 422 from the validator, **When** it arrives, **Then** each reason code is shown inline
   with its meaning, "Nothing was executed." is stated, and the form keeps its values.
5. **Given** Cancel, **When** submitted without a reason, **Then** it is not sent and asks for one.
6. **Given** a closed Case with a Dossier, **When** opened, **Then** the Dossier is at the bottom,
   collapsed.

---

### User Story 5 - Distinct, honest copy for waiting, review and uncertainty (Priority: P2)

Every state has its own banner copy and chip (glyph + label). Waiting for approval, review required
and an uncertain outcome never share wording. `Executing` with an uncertain outcome says the partner
may already have the order and new sends are blocked until reconciliation.

**Why this priority**: The Operator's next move depends on telling these apart.

**Independent Test**: Render the banner and chip for each state and for `Executing` with
`in_progress` vs `reconciling`; compare copy.

**Acceptance Scenarios**:

1. **Given** each of the 13 states, **When** its banner is shown, **Then** it uses that state's copy
   and at most one primary action.
2. **Given** `Executing` with outcome `reconciling`, **When** shown, **Then** the chip says "Outcome
   unknown" and the banner says the partner may already have the order and new sends are blocked until
   reconciliation.
3. **Given** `PendingApproval`, `ReviewRequired` and `Executing`/`reconciling`, **When** their copy is
   compared, **Then** no two share a sentence.

---

### User Story 6 - Polling that respects the Operator (Priority: P2)

The console polls the list and the open Case every 1–2 seconds. A poll never steals focus, resets a
field, collapses an open section or clears an inline error. Nothing on screen changes except after a
server answer or a poll. When polling fails, a persistent "Connection lost, retrying" note appears
and the data is marked possibly stale until a poll succeeds.

**Why this priority**: Without it the Operator cannot type a denial reason or read Evidence on a busy
Case.

**Independent Test**: Focus the deny reason, type, let several polls with changes arrive; check focus,
value, open sections and inline errors. Make polls fail and recover.

**Acceptance Scenarios**:

1. **Given** a focused field with typed text, **When** polls arrive with changes, **Then** focus and
   text are kept.
2. **Given** an expanded section and an inline error, **When** polls arrive, **Then** both remain.
3. **Given** a failing poll, **When** it fails, **Then** the persistent connection note appears and data
   is marked possibly stale; **When** the next poll succeeds, **Then** the note clears.

---

### Edge Cases

- The Operator's name is required before any command and must not contain ":"; it is remembered in
  the browser and labelled as a declared name.
- A Timeline whose last event sequence goes backwards is reloaded in full.
- A Case that disappears (404) while open shows "Case not found" with a link back.
- The approval deadline and ages tick locally from the server time, without extra requests.
- Reduced-motion preference disables row flashes, highlight animations and smooth scrolling.
- Phone widths keep reading and approving usable (stacked rows, wrapping top bar).

## Requirements *(mandatory)*

### Functional Requirements

**List**

- **FR-001**: The console MUST list Cases from the contract's list operation with the filters Needs you
  (default: approval pending or review required), Active, Closed and All, mapped to the contract's
  `state`/`status` filters.
- **FR-002**: Each row MUST show caseId, orderId, partner, state (glyph + label, with "Outcome unknown"
  for `Executing` + `reconciling`), age, approval deadline when present, current proposal Action and
  confidence, last exception summary, and the `SYNTHETIC` / `REPLAY` labels.
- **FR-003**: The list MUST poll for newer changes with the contract cursor and update rows in place,
  and MUST page back with the cursor on request (no infinite scroll).

**Detail**

- **FR-004**: The detail MUST show exactly one state banner per Case with the state's copy and at most
  one primary action, announced politely.
- **FR-005**: The detail MUST show the six layers (What failed, Evidence, Diagnosis, Proposal,
  Approval, Execution & receipt) and the Timeline, with explicit "not yet" and "no interpretation"
  copy instead of empty sections.
- **FR-006**: Only the current Proposal MUST be expanded; earlier versions MUST be collapsed and
  counted. Proposal versions and metrics (model, provider, duration, tool calls, tokens, cost) and
  execution attempts MUST be visible.
- **FR-007**: Evidence MUST be read-only. An Evidence reference MUST move focus to its card. Conflicts
  MUST be grouped side by side with their description; obsoleted Evidence MUST remain, marked.
- **FR-008**: The Timeline MUST load incrementally by sequence number and reload fully if the last
  sequence goes backwards.

**Commands**

- **FR-009**: The approval dialog MUST freeze proposalId and Case version at open and send exactly
  those with the declared Operator name; Approve and Deny MUST be separate; Deny MUST require a
  reason; Approve MUST be disabled while a request is in flight.
- **FR-010**: Server answers MUST be handled as specified: 201 close + toast + refresh; 200
  `idempotentReplay` as "already approved, no new effect" (not a new success); 409 `STALE_VERSION`
  keep open, nothing recorded, offer reload, hide Approve/Deny; 409 `INVALID_TRANSITION` keep open
  with the new state; 400 field messages; 422 validator reasons inline with form values kept; 404 link
  back; network error "may not have reached the server", no assumption.
- **FR-011**: The Review Dossier MUST be first when `ReviewRequired` and last, collapsed, once closed;
  it MUST show reason, partial diagnosis, hypotheses, conflicts, colliding records (divergent fields
  marked by glyph), unconfirmed candidates, unknowns ("Nothing flagged" when empty) and next step.
- **FR-012**: The resolution form MUST offer only catalog Actions and their allowed parameters
  (mappings from the reference list for `APPLY_APPROVED_MAPPING`), or cancel with a required reason;
  it MUST NOT offer a free payload field.
- **FR-013**: The console MUST NOT change displayed data optimistically; only a server answer or a
  poll may change it.

**Polling and honesty**

- **FR-014**: Polling MUST run every 1–2 s for the list and the open Case and MUST NOT steal focus,
  reset inputs, collapse sections or clear inline errors.
- **FR-015**: A failing poll MUST show a persistent "Connection lost, retrying" note and mark data as
  possibly stale until a poll succeeds.
- **FR-016**: Waiting, review and uncertain outcome MUST have distinct copy.
- **FR-017**: Synthetic data MUST be labelled on every row and Case header and the top bar; Replay
  where applicable.

**Accessibility**

- **FR-018**: The console MUST meet WCAG 2.2 AA: keyboard parity, no hover-only action, state by glyph
  and label, managed focus for dialogs and Evidence jumps, polite live regions for banners and toasts,
  alerts for inline errors, reduced-motion support, responsive layout (≥1100, 640–1099, <640 px).

### Key Entities

The console owns no data. It renders the contract's CaseListPage, CaseSummary, CaseDetail (with
Evidence, Diagnosis, Proposal, Approval, Execution, ReceiptCopy, Dossier), TimelinePage,
ProposalDecisionResult, ReviewResolutionResult, ErrorEnvelope, the action catalog and approved
mappings. It keeps only the declared Operator name in the browser.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Using only the keyboard, an Operator completes list → Case → approval → back in the test
  journey with no unreachable step.
- **SC-002**: For each of the server answers in FR-010, the console's visible outcome matches the
  specified treatment in 100% of the tests; no refusal, replay or network error is shown as success.
- **SC-003**: 100% of approval requests in the tests carry the proposalId and Case version frozen at
  dialog open, even when polls changed the Case meanwhile.
- **SC-004**: Across polls with changes, focus, typed values, open sections and inline errors are
  preserved in 100% of the tests.
- **SC-005**: Automated accessibility checks report no WCAG 2.2 AA violations on the list, detail,
  dialog and dossier views.
- **SC-006**: Every contract fixture of the Cases, Approvals and Review operations renders without
  error and with its synthetic label.

## Assumptions

- The Benchmark report screen is not part of this feature (it belongs with the Benchmark, 010); the top
  bar shows Cases only until then.
- Decision, resolution and reference endpoints are not served by the backend yet (features 007/009 and
  004). The console is built and tested against the contract and its fixtures; it calls the real
  endpoints unchanged when they exist.
- Visual Trace links appear only when the Case carries `visualTraceUrl`.
- Times are shown in BRT (America/Sao_Paulo) as the UX spine says; the API stays UTC.
- The approval diff ("GLIC-J → GLIC-S") is built from the reference mappings, as the UX spine says,
  until a preview field exists (prototype finding F-8).
- The visual system of this console was redesigned by feature 014 (`specs/014-liquid-console-redesign/`): soft surfaces, liquid glass for floating layers, a light and dark theme the Operator can switch. Behavior and copy defined here are unchanged.
