---
description: "Tasks for feature 005 — Operator Console"
---

# Tasks: Operator Console

**Input**: `specs/005-operator-console/` (plan, spec, research, data-model,
contracts/ui-contract-binding.md, quickstart)

**Tests**: MANDATORY (TDD). UI tests: `cd ui && npm test` (Vitest + jsdom + Testing Library +
axe-core). ObjectScript changes compile and test on the live instance through iris-agentic-dev.

**Calendar gate**: waived for this feature by Henry on 2026-10-25 (research.md).

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

- [X] T001 Create `ui/` with exact pins (`package.json`, `package-lock.json`), SvelteKit options in `vite.config.ts` (Kit 3 no longer reads `svelte.config.js`: adapter-static, `router.type: 'hash'`, `paths.base: '/signalnoir/ui'`), `vite.config.ts` (vitest jsdom, fs allow `../contracts`), `tsconfig.json`, `ui/.gitignore` (node_modules, build, .svelte-kit); scripts `dev`, `dev:mock`, `build`, `check`, `test`
- [X] T002 [P] `ui/src/app.html`, `ui/src/app.css` with DESIGN.md tokens (light + dark), typography, focus ring, reduced-motion rules; `ui/src/routes/+layout.ts` (`ssr = false`, `prerender = true`)
- [X] T003 [P] `ui/tests/setup.ts` (jest-dom matchers, `dialog` polyfill for jsdom, `scrollIntoView` stub) and `ui/tests/a11y.ts` (axe-core runner, `color-contrast` off in jsdom)

---

## Phase 2: Foundational

- [X] T004 [P] `ui/src/lib/api/types.ts`: contract types used by the console
- [X] T005 [P] `ui/tests/outcome.test.ts` (failing first): every answer maps to its Outcome — 201, 200 replay, 409 stale, 409 invalid transition, 403, 400 with fields, 422 with verdict reasons, 404, network error, 500
- [X] T006 `ui/src/lib/api/outcome.ts`, `ui/src/lib/api/transport.ts` (fetch transport, base `../api/v1`), `ui/src/lib/api/client.ts` (listCases, getCase, getTimeline, decide, resolve, mappings, actionCatalog)
- [X] T007 `ui/src/lib/api/fixtures.ts`: fixture transport serving `contracts/fixtures/**` by operation, with `next(op, status, body)` / `failNext(op)` scripting for tests and `dev:mock`
- [X] T008 [P] `ui/tests/copy.test.ts` (failing first) then `ui/src/lib/copy.ts`: chip label + glyph + tone and banner copy for the 13 states and `Executing`+`reconciling`; outcome copy; reason-code text; waiting/review/uncertain copy distinct
- [X] T009 [P] `ui/src/lib/format.ts` (BRT time, age, deadline from `serverTime`) with `ui/tests/format.test.ts`
- [X] T010 `ui/src/lib/stores/poller.ts` (1.5 s, stale on failure) and `ui/src/lib/stores/operator.ts` (declared name, no ":")
- [X] T011 `ui/src/routes/+layout.svelte` (top bar: wordmark, Cases, declared-name field, `SYNTHETIC DATA` badge, connection note, toast region) and `ui/src/routes/+page.svelte` (hash routes, focus to main + title on route change)

---

## Phase 3: User Story 1 — See which Cases need me, live (P1) 🎯 MVP

- [X] T012 [P] [US1] `ui/tests/case-list.test.ts`: default Needs you request (`state=PendingApproval&state=ReviewRequired`); rows show caseId, orderId, partner, chip glyph+label, age, deadline, current Action+confidence, last exception, `SYNTHETIC`/`REPLAY`; "Outcome unknown" for `Executing`+`reconciling`; filters Active/Closed/All map to `status`; a poll with a new and a changed Case updates rows in place without remount; "Load older" uses `nextCursor`; empty Needs you copy; axe clean
- [X] T013 [US1] `ui/src/lib/stores/cases.ts` (filter, newer merge by caseId, older paging, stale)
- [X] T014 [US1] Components `CaseList.svelte`, `CaseRow.svelte` (whole row is a link, Enter opens), `StateChip.svelte`

---

## Phase 4: User Story 2 — Read a Case in layers and follow the Evidence (P1)

- [X] T015 [P] [US2] `ui/tests/case-detail.test.ts`: P5/P8b fixture → one banner, six layers + Timeline; claim chip focuses the Evidence card; conflict group side by side with description; obsoleted Evidence marked; superseded fixture → "Earlier versions (1)" collapsed; no-diagnosis copy; "Not yet" layers; metrics (model, provider, duration, tool calls, attempts, cost) visible; 404 fixture → "Case not found" + link; axe clean
- [X] T016 [US2] `ui/src/lib/stores/caseDetail.ts` (detail + incremental timeline, full reload when `lastEventSeq` goes back)
- [X] T017 [US2] Components `CaseDetail.svelte`, `StateBanner.svelte`, `LayerWhatFailed`, `LayerEvidence`, `EvidenceCard`, `EvidenceChip`, `LayerDiagnosis`, `LayerProposal`, `LayerApproval`, `LayerExecution`, `Timeline`, `NotYet`

---

## Phase 5: User Story 3 — Approve or deny one exact version (P1)

- [X] T018 [P] [US3] `ui/tests/approval-dialog.test.ts`: frozen proposalId + caseVersion survive a poll that changes the Case; body = `{decision, operator, expectedCaseVersion[, reason]}`; Approve disabled in flight; 201 closes + toast; 200 replay → "Already approved by {name}. No new effect." not success-styled; 409 stale keeps open, "Nothing was recorded", hides Approve/Deny, offers "Review the new version"; 409 invalid transition copy; 400/deny without reason blocked client-side; network → "may not have reached the server", Approve stays disabled until the next poll; Esc closes, focus returns to trigger; axe clean
- [X] T019 [US3] `ApprovalDialog.svelte` (native `<dialog>`), `Toasts.svelte`, `stores/toasts.ts`; diff line from reference mappings for `APPLY_APPROVED_MAPPING`
- [X] T020 [P] [US3] `ui/tests/keyboard-journey.test.ts`: keyboard only — set name, open the needs-you row, reach "Review & approve…", approve, toast, back to list

---

## Phase 6: User Story 4 — Resolve a Review Dossier (P2)

- [X] T021 [P] [US4] `ui/tests/dossier.test.ts`: review fixtures → Dossier first; reason, partial diagnosis, hypotheses, conflicts, colliding records with `≠` divergent cells, unconfirmed candidates, unknowns ("Nothing flagged" when empty), next step; resolved fixture with dossier → bottom, collapsed; form offers only catalog Actions and reference mappings, no free payload input; 422 shows reasons + "Nothing was executed." and keeps values; cancel requires reason; 201 resets + toast; axe clean
- [X] T022 [US4] `Dossier.svelte`, `ResolutionForm.svelte`

---

## Phase 7: User Story 5 — Distinct, honest copy (P2)

- [X] T023 [P] [US5] `ui/tests/state-copy.test.ts`: banner per state renders its copy and ≤1 primary action; `reconciling` banner text; PendingApproval / ReviewRequired / reconciling share no sentence
- [X] T024 [US5] Wire `copy.ts` into `StateBanner`/`StateChip` for all states (fix gaps found by T023)

---

## Phase 8: User Story 6 — Polling that respects the Operator (P2)

- [X] T025 [P] [US6] `ui/tests/polling.test.ts`: focused deny reason keeps focus and text across polls with changes; expanded "Earlier versions" and a 422 inline error survive polls; failing poll shows persistent "Connection lost, retrying" + stale marker; success clears it
- [X] T026 [US6] Fix any re-render loss found by T025 (keyed each, local state)

---

## Phase 9: Serving and polish

- [X] T027 Create `src/SignalNoir/Api/Console.cls` (`/` → 302 `ui/index.html#/cases`) and register `/signalnoir` + `/signalnoir/ui` (`SN_UI_PATH`) in `src/SignalNoir/Interop/Bootstrap.cls`; extend `tests/SignalNoir/Tests/Interop/TestBootstrap.cls`
- [X] T028 Build `ui/`, run `OnStart`, verify live: `/signalnoir/` → 302, `/signalnoir/ui/index.html` 200, assets 200, `/signalnoir/api/v1/cases` 200; record in research.md
- [X] T029 [P] Responsive rules (≥1100 two columns + sticky timeline, 640–1099, <640 stacked) in `app.css`/components
- [X] T030 Full run: `npm run check`, `npm test`, `npm run build`, ObjectScript suite; record counts in research.md
- [X] T031 Update `docs/specify-prompts/PARALELISMO.md` board row 005

## Dependencies & Execution Order

Setup → Foundational → US1 → US2 → US3 → US4 → US5 → US6 → Serving/polish. US3 needs US2's detail;
US4 needs US2; US5/US6 verify across the components built before.

## Parallel Opportunities

T002/T003; T004/T005/T008/T009; story test files ([P]) alongside each other.

## Implementation Strategy

MVP = Foundational + US1 + US2 + US3 (find, read, approve exactly); then dossier, copy audit,
polling discipline, serving.
