---
name: Signal Noir
status: final
updated: 2026-10-20
sources:
  - ../initiative-signal-noir.md
  - ../prototype-signal-noir/findings.md
  - ../../../contracts/openapi-signalnoir.yaml
---

# Signal Noir: experience spine

## Foundation

- **Surface:** one responsive web SPA, the operator console. Svelte 5 with SvelteKit and `adapter-static`, compiled to static files and served by an IRIS web application at `/signalnoir/` (AD-17).
- **UI system:** none. `DESIGN.md` is the full visual system.
- **Routing:** hash routing (`#/cases`, `#/cases/<caseId>`, `#/benchmark`), so deep links survive the static server.
- **Data:** polling every 1–2 s against `/signalnoir/api/v1` (contract `1.0.0-draft.2`):
  - the list uses the `(lastEventAt, caseId)` cursor;
  - the timeline uses `sinceSeq`;
  - every case response carries `caseVersion`, `lastEventSeq` and `serverTime`.

  There is no SSE in v1.
- **Identity:** no authentication. The operator types a name, which is stored in the browser and sent as `operator` in every command. It is labelled as a declared name everywhere it appears.
- **Language:** English UI copy (decided 20/10). Times on screen are BRT; the API is UTC.
- **Reference:** the throwaway prototype in `../prototype-signal-noir/` shows the composition of every surface below. This spine wins on any conflict. The prototype's scenario panel and API log are review tools and are not part of the product.

## Information Architecture

| Surface | Reached from | Purpose | Requirement |
|---|---|---|---|
| Case list | App open, `Cases` in the top bar | See every case and what needs the operator. Filters: **Needs you** (default), Active, Closed, All. | R32, FR-34 |
| Case detail | A list row | Six layers (What failed, Evidence, Diagnosis, Proposal, Approval, Execution & receipt) plus the timeline. | R32–R35, FR-35 |
| Approval dialog | "Review & approve…" on a case in `PendingApproval` | Decide on one exact proposal version. | R21–R23, R33 |
| Review dossier | Top of the case detail when `ReviewRequired`; at the bottom, collapsed, once closed | Understand why automation stopped, then resolve or cancel. | R2, R30, R31 |
| Benchmark report | `Benchmark` in the top bar | Read the reference run: agent decision versus platform guarantees. | R42–R45 |
| Visual Trace | Link in the case header | Opens the IRIS Visual Trace session for the order in a new tab. | FR-37 |

Top bar on every surface: wordmark, Cases, Benchmark, the declared-name field and the `SYNTHETIC DATA` badge. Dialogs never stack: one dialog at a time.

## Voice and Tone

Plain, specific and honest. Say what happened, what was not done, and what the operator can do next.

| Do | Don't |
|---|---|
| "Waiting for your approval. Nothing is sent until you approve this exact version." | "Action required!" |
| "This proposal changed while you were reviewing it. Nothing was approved." | "Something went wrong. Please try again." |
| "The outcome is unknown. The partner may already have this order." | "Processing…" for an uncertain send |
| "Missing information is listed here. It is not a negative conclusion." | "No issues found" when nothing was checked |
| "Already approved by Carla. No new effect." | "Success!" on an idempotent replay |
| "The validator blocked this. Nothing was executed." | Hide the validator's reason codes |
| Name the effect: "Change exam code GLIC-J → GLIC-S, then resend ORD-24117 to Partner A." | "Apply proposal" |

Rules:
- Never claim an effect the server did not confirm.
- Never call the agent "AI assistant" or give it a persona; it is "the agent".
- "Synthetic" is always stated, never implied.

## Component Patterns

Behavior only; visual specs are in `DESIGN.md.Components`.

| Component | Behavioral rules |
|---|---|
| Case row | The whole row is a link. The state chip comes from `state` plus `executionOutcome`: `Executing` with `reconciling` shows "Outcome unknown". Age and approval deadline tick locally from `serverTime` without refetching. A row that changed since the last poll flashes once (no flash under reduced motion). |
| State banner | Exactly one per case. Its copy comes from the state table below. It holds at most one primary action ("Review & approve…" or "Go to dossier"). It is announced politely (`role="status"`). |
| Evidence chip | Inside a claim, hypothesis or dossier. Clicking it scrolls to the evidence card, focuses it and highlights it briefly. It never opens a modal. |
| Evidence card | Read-only. Raw `result` renders as key/value; nested arrays render as compact lines. The full query is visible. Obsolete evidence stays, marked "obsoleted by". |
| Proposal card | Shows only the current proposal. Earlier versions sit in a collapsed "Earlier versions (n)" block. Versions and metrics are collapsed and labelled with their source. |
| Approval dialog | Opens from the banner or the proposal layer. It freezes `proposalId` and `caseVersion` at open time and sends exactly those. Approve and Deny are separate. Deny reveals a required reason, which becomes evidence. Approve is disabled while the request is in flight. |
| Resolution form (dossier) | Options come from the catalog for this order: approved mappings whose `sourceCode` matches, plus Retry, Hold and Cancel. No free payload field. Submitting goes to `POST /cases/{id}/resolution`. A 422 shows the validator's reasons inline and keeps the form as it was. Cancel requires a reason. |
| Timeline | Append-only, newest first, incremental by `sinceSeq`. If `lastEventSeq` goes backwards (case recreated), reload the whole timeline. |
| Toast | Only for the outcome of the operator's own action (approved, denied, resolved, replay). Dismisses after about 6 s. Never the only place an error is shown. |

## State Patterns

### Case states (one banner per state)

| State (enum) | Chip label · tone | Banner copy (essence) | Operator action |
|---|---|---|---|
| `Open` | Open · fact | Exception recorded; investigation starts shortly. | none |
| `Investigating` | Investigating · fact | The agent investigates with read-only tools; nothing is sent. | none |
| `DecisionProposed` | Decision proposed · fact | The validator is checking a proposal. | none |
| `PendingApproval` | Needs approval · attention | Nothing is sent until you approve this exact version. | Review & approve… |
| `Approved` | Approved · fact | Preconditions are re-checked right before sending. | none |
| `Rejected` | Denied · attention | One more investigation runs with your reason as evidence. | none |
| `Executing` (+ `in_progress`) | Executing · fact | Sending with idempotency key …. | none |
| `Executing` (+ `reconciling`) | Outcome unknown · interpretation | The partner may already have this order; new sends are blocked, even from a new proposal, until reconciliation finds or rules out a receipt. | none |
| `Held` | On hold · hold | A precondition failed before sending, so nothing was sent. The case is re-investigated when the condition clears, and any new action needs a new approval. | none |
| `ReviewRequired` | Review required · attention | Automation stopped; the dossier explains why. | Go to dossier |
| `Resolved` | Resolved · success | Receipt … confirms delivery (and says when it was found by reconciliation without resending). | none |
| `ResolvedByPriorReceipt` | Already delivered · success | The validator confirmed an earlier receipt; nothing was resent. | none |
| `Cancelled` | Cancelled · muted | No effect was sent. | none |
| `Failed` | Failed · danger | What failed and that no further automatic action follows. | none |

### Server responses

| Response | Where | Treatment |
|---|---|---|
| `201` decision or resolution | Dialog or form | Close or reset, toast with what happens next, refresh the detail immediately. |
| `200` with `idempotentReplay: true` | Dialog | Close; toast: "Already approved by {name}. No new effect." Never styled as a new success. |
| `409 STALE_VERSION` | Dialog or form | Keep it open. Say the proposal or case changed and nothing was recorded. Offer "Review the new version", which reloads and reopens with the current proposal. Hide Approve and Deny. |
| `409 INVALID_TRANSITION` | Dialog or form | Keep it open: "This case is now {state}. Nothing was recorded." Offer to close and see the case. |
| `422 VALIDATION_FAILED` (validator) | Resolution form | Inline danger block with each reason code in mono and its plain-language meaning. "Nothing was executed." Form values are kept. |
| `400 VALIDATION_FAILED` | Dialog or form | Field-level message (name missing or containing ":", reason missing on deny or cancel). |
| `404` | Detail | "Case not found" with a link back to Cases. |
| Network error or timeout | Any command | Say the request may not have reached the server. Leave Approve disabled until the next poll shows whether the case changed. Never assume success or failure. |
| Polling failure | Top bar | A small persistent "Connection lost, retrying" note. Data on screen stays, marked as possibly stale. Clears on the next successful poll. |

### Content states

| State | Treatment |
|---|---|
| Layer not reached yet | Dashed inline note: "Not yet. The case has not reached this step." |
| No diagnosis (agent never ran) | "No interpretation exists. The agent has not produced one." Never an empty card. |
| Dossier `unknowns` empty | "Nothing flagged", never "everything is known". |
| Empty "Needs you" filter | "No case needs a decision from you right now." |
| Synthetic or replay | `SYNTHETIC` tag on every row, header and export; `REPLAY` where `labels.replay` is true. |

## Interaction Primitives

- **Pointer and keyboard parity.** Every action is a real `<button>` or `<a>`; no hover-only affordances.
- **Keyboard:** `Tab` order follows the reading order (header, banner, dossier, layers 1–6, timeline). `Esc` closes the dialog. `Enter` on a focused row opens the case.
- **No optimistic updates.** The screen changes only after the server answers or a poll shows the change. This is the core honesty rule.
- **Re-render discipline:** polling must not steal focus, reset form input, collapse open sections or clear an inline error. If the case changes underneath a focused control, keep focus and values and refresh the rest.
- **Banned:**
  - infinite scroll (the list paginates by cursor);
  - drag and drop;
  - stacked dialogs;
  - auto-approve or "approve all";
  - editing a payload;
  - any control that sends without the dialog.

## Accessibility Floor

- WCAG 2.2 AA. Contrast is set in `DESIGN.md`; light and dark both meet it.
- State is never conveyed by color alone: chip glyph plus label, `≠` marker on divergent dossier cells, "✓ holds / ✕ fails" text in the revalidation table.
- The banner is `role="status"`. Toasts live in a polite `aria-live` region. Inline errors are `role="alert"`.
- Route changes move focus to the main region and announce the page title ("Case ORD-24117, needs approval").
- The approval dialog is a native `<dialog>` opened modally. Focus starts on the first field and returns to the trigger on close.
- Evidence chips move focus to the evidence card (`tabindex="-1"`) so screen readers follow the jump.
- Respect `prefers-reduced-motion` (no row flash, no evidence highlight animation, no smooth scroll).
- Touch targets are at least 36 px tall.

## Responsive & Platform

| Width | Behavior |
|---|---|
| ≥ 1100 px | Detail in two columns: layers plus a sticky timeline. The list row shows all six fields. |
| 640–1099 px | The timeline moves under the layers. The list row drops partner and labels. |
| < 640 px | List rows become stacked cards. Key/value lists stack. Wide tables scroll inside their container. The top bar wraps. |

Primary use is desktop or laptop; phones must be usable for reading and for approving. Built output uses relative asset paths, so it works under `/signalnoir/` (AD-17).

## Contract Binding

Which call feeds which surface (contract `1.0.0-draft.2`):

| Surface | Calls | Fields that drive behavior |
|---|---|---|
| Case list | `GET /cases` (cursor) | `state`, `executionOutcome`, `pendingApproval`, `approvalDeadline`, `currentProposal`, `lastExceptionSummary`, `labels` |
| Case detail | `GET /cases/{id}`, `GET /cases/{id}/timeline?sinceSeq=` | `caseVersion` (sent back as `expectedCaseVersion`), `currentProposalId`, `executions[].outcome`, `dossier.unknowns`, `visualTraceUrl` |
| Approval | `POST /cases/{id}/proposals/{proposalId}/decision` | `idempotentReplay`, error `code` |
| Resolution | `POST /cases/{id}/resolution`, `GET /reference/mappings?sourceCode=` | `error.details.verdict.reasons` |
| Benchmark | `GET /benchmark-reports`, `GET /benchmark-runs/{runId}/report` | denominators and categories as published |

The open contract proposals from the prototype that affect this spine are F-5 (evidence summary), F-6 (closed reason enum), F-7 (partner display name) and F-8 (preview payload). They are in `../prototype-signal-noir/findings.md`. Until they land, the UI renders raw results, keeps a local reason-to-text map, shows `partnerId`, and builds the approval diff from `/reference/mappings`.

## Inspiration & Anti-patterns

- **Kept from the prototype:**
  - the state banner as the single "what now" surface;
  - `FACT` versus `INTERPRETATION` tagging;
  - evidence chips inside claims;
  - the 409 handling that keeps the dialog open.
- **Rejected — chat transcript of the agent:** the agent's output is structured (diagnosis, claims, hypotheses), not a conversation. A transcript would invite reading tone instead of checking evidence.
- **Rejected — canvas or flow editor:** out of scope (Boundaries); the case is a linear story.
- **Rejected — confidence as a percentage:** the contract has three levels; a number would suggest a precision that does not exist.
- **Rejected — the prototype's scenario panel and API log:** review tools only.

## Key Flows

Protagonists and journey names follow the PRD (§2.3).

### UJ-1. Carla finds out the "server error" was a discontinued code with two replacements

1. A new case appears in "Needs you": ORD-24117, "Attempt 2 · HTTP 500 with a validation body", proposal `APPLY_APPROVED_MAPPING`, confidence High.
2. She opens it. The banner says it waits for her approval. Layer 1 shows the raw 500 body, which reports a validation error.
3. Layer 2 opens with a conflict: the HTTP 500 suggests a server fault, but partner health is UP.
4. Layer 3 claims the specimen is SERUM, which matches only `map_glicj_soro`; the chip jumps to the mapping catalog evidence. She sees two discarded hypotheses, "RETRY" and "the first mapping".
5. She clicks "Review & approve…". The dialog shows the diff `exams[0].code GLIC-J → GLIC-S` and the preconditions. She approves.
6. **Climax:** the banner moves to Approved, then Executing, then "Resolved. Partner receipt RCP-… confirms delivery". The timeline shows the revalidation passed before the send.
7. **Edge:** she clicks Approve again from another tab. The toast says "Already approved by Carla. No new effect", and the execution count stays at one.

### UJ-2. Carla holds an execution that went stale

1. Carla approves a `RETRY` for a sincere 503.
2. Before the send, revalidation finds the partner error rate at 38%.
3. **Climax:** the banner turns to "On hold … nothing was sent". The revalidation table shows the failed `PARTNER_HEALTHY_WINDOW` row. The timeline shows each reassessment.
4. When the partner recovers, the case returns to "Needs approval" with a new proposal version, and she approves it again.
5. **Variant:** the order is cancelled at the origin, and the case ends "Cancelled. No effect was sent."

### UJ-3. Carla finds out the "failed" order was already delivered (P9, conditional)

1. The case shows a timeout and a healthy partner.
2. The diagnosis says ORD-24199 has the same patient, exam, specimen and collection time and already has a receipt.
3. **Climax:** the banner reads "Already delivered", and the execution layer stays empty because nothing was sent.

### UJ-4. Carla gets a dossier, not an alert

1. The case is in `ReviewRequired`. The dossier sits at the top: the reason, "What was checked" (chips), "What we don't know" (from `dossier.unknowns`), the colliding records with the divergent cells marked, and the next step.
2. She tries `RETRY`. The form shows "The validator blocked this. Nothing was executed. `IDENTITY_UNRESOLVED`: confirm identity at the origin first."
3. **Climax:** she cancels with the reason "origin will resend with the confirmed patient". The banner turns to "Cancelled", with her declared name in the timeline.
4. **Variant (provider unavailable):** the dossier states the provider rejected the call, shows no hypotheses, and lists "no diagnosis: the agent never ran" under unknowns. She chooses the mapping whose condition matches PLASMA, the validator accepts it, and the case resolves.

### UJ-6. Rafael, a judge, sees a real decision change the workflow

1. Rafael opens `/signalnoir/` after the README setup. "Needs you" shows the reference cases.
2. **Climax:** in UJ-1's case he follows the claims to the evidence, approves, and opens the Visual Trace from the header to see the same order.
3. In Benchmark he reads both parts. The agent-decision table is per family with denominators, and the platform guarantees are pass or fail, not credited to the agent.
