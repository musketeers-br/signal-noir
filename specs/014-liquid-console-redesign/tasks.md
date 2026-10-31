---
description: "Tasks for feature 014 — Liquid Console Redesign"
---

# Tasks: Liquid Console Redesign

**Input**: `specs/014-liquid-console-redesign/` (plan, spec, research, data-model,
contracts/design-tokens.md, quickstart, design/)

**Tests**: MANDATORY (TDD). UI tests: `cd ui && npm test` (Vitest + jsdom + Testing Library +
axe-core). What jsdom cannot see (layout, blur, forced colors, print, 360 px) is checked in the
quickstart. No ObjectScript change; the one platform check (static script on IRIS) is T036.

**Hard rule (FR-002, SC-002)**: no assertion of an existing 005 test is edited. If a test fails after a
markup change, the markup is wrong, not the test. New tests go in new files.

**Reference design**: `design/` is a look reference only. Do not copy its sample data, quick approve,
web fonts, summary strip or extra navigation.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup and baseline

- [X] T001 Run `cd ui && npm ci && npm run check && npm test` on the untouched tree and write the passing test count and `check` result in `research.md` (section "Baseline"). This is the number SC-002 compares against.
- [X] T002 [P] Inventory every literal color, shadow, radius and font stack outside the token layer: `app.css`, every `ui/src/lib/components/*.svelte` and `ui/src/routes/*.svelte` (inline `style=` too), `app.html`. Record the list in `research.md` ("Literals to migrate"). It is the work list for T017 to T024.
- [X] T003 [P] Create `ui/src/styles/` and turn `ui/src/app.css` into the entry that `@import`s, in this order: `tokens.css`, `base.css`, `surfaces.css`, `controls.css`, `layout.css`, `motion.css`, `print.css`. Move the current rules into the new files **unchanged** (old tokens stay in `tokens.css`). `npm test` must stay green: this is a pure move.

---

## Phase 2: User Story 6 — One visual source of truth (P2, done first because everything else uses it)

- [X] T004 [P] [US6] `ui/tests/tokens-contrast.test.ts` (failing first): read `ui/src/styles/tokens.css`, parse each `light-dark(a, b)` token (hex and `rgb()`), and assert the pairs of `contracts/design-tokens.md` in **both** themes: `--ink` and `--ink-muted` on every surface and `--glass-solid` ≥ 4.5; each semantic color on its `-soft` tint and on `--surface` ≥ 4.5; `--accent-ink` on `--accent` ≥ 4.5; `--line-strong` on `--surface` and `--paper` ≥ 3; `--focus` on `--surface`, `--paper`, `--accent` ≥ 3. Fail with the token names and the ratio
- [X] T005 [P] [US6] `ui/tests/token-audit.test.ts` (failing first): scan `ui/src/**/*.{css,svelte,html}` except `tokens.css` and fail on a hex color, `rgb(`/`rgba(`/`hsl(`, a `box-shadow` or `border-radius` with a literal length, a literal `font-family` stack, or an inline `style=` carrying any of these. Print file, line and value. Allow `0`, `inherit`, `currentColor`, `transparent` and `var(...)`
- [X] T006 [US6] `ui/src/styles/tokens.css`: define every token of `contracts/design-tokens.md` once, as `light-dark(light, dark)`. Surfaces, text and lines, the eight semantic roles with `-soft` tints, `--glass`, `--glass-solid`, `--glass-edge`, elevation `--e1`..`--e5` and `--inset` (composed from `--shadow-lo` and `--shadow-hi`), radii, `--sans` and `--mono` (system stacks), the type and spacing scales, layout sizes, `--dur-*`, `--blur`. `:root { color-scheme: light dark }`, `[data-theme='light']` and `[data-theme='dark']` set `color-scheme`. Add one `@supports not (color: light-dark(#000, #fff))` block that falls back to the light values. Start from the reference palette in `design/signal.css` and retune until T004 passes. T004 goes green here
- [X] T007 [US6] Keep the old variable names working as aliases of the new tokens in `tokens.css` (for example `--surface-raised`, `--ink-muted`, `--accent-soft`), so no component breaks while T017 to T024 migrate. Remove the aliases at T023

**Checkpoint**: T004 passes; T005 fails with the migration work list.

---

## Phase 3: User Story 2 — Light and dark, chosen by the Operator (P1)

- [X] T008 [P] [US2] `ui/tests/theme.test.ts` (failing first): store and toggle. No stored value → effective theme is the system's (matchMedia stub), `data-theme` absent; toggle → opposite theme, `signalnoir.theme` written, `data-theme` set; a stored `light`/`dark` wins over the system; a stored `banana` is ignored; `localStorage` that throws on read and on write → toggle still changes the theme for the session; a system-change event updates the effective theme only while there is no stored choice; the toggle's accessible name is "Switch to dark theme" in light and "Switch to light theme" in dark; Enter and Space operate it; switching the theme keeps focus, a typed value in the declared-name field and an open dialog
- [X] T009 [US2] `ui/src/lib/stores/theme.svelte.ts`: `choice` (`'light' | 'dark' | null`), `effective`, `toggle()`, guarded reads and writes of `signalnoir.theme`, a `matchMedia('(prefers-color-scheme: dark)')` listener, and the `data-theme` attribute on `document.documentElement` (absent when following the system). Never writes on load
- [X] T010 [P] [US2] `ui/src/lib/copy.ts`: add the two theme toggle labels. Do not touch `ui/tests/copy.test.ts` (existing file): the labels are covered in `theme.test.ts`
- [X] T011 [US2] `ui/src/lib/components/ThemeToggle.svelte`: a real `<button>` with `aria-label` from copy, inline stroke SVG sun and moon (`aria-hidden`), 44 × 44 px target, class `theme-toggle`. T008 goes green here
- [X] T012 [US2] `ui/static/theme-init.js` and `ui/src/app.html`: synchronous script in `<head>` (`<script src="%sveltekit.assets%/theme-init.js">`) that reads `signalnoir.theme` inside `try/catch` and sets `data-theme` only for `light` or `dark`. Keep `<meta name="color-scheme" content="light dark">`. Add a test in `theme.test.ts` that evaluates the script against a stubbed `localStorage` and checks all four cases (light, dark, absent, junk)

**Checkpoint**: the theme works end to end with the old look; `signalnoir.theme` round-trips.

---

## Phase 4: User Stories 1 and 3 — The whole console wears the new look, and meaning survives (P1) 🎯 MVP

- [X] T013 [P] [US3] `ui/tests/a11y-themes.test.ts`: for each theme (set `data-theme` on `<html>`), render the list, a Case detail, the approval dialog and the dossier from the fixtures and run `violations()` from `tests/a11y.ts`; expect none. Add a "without color" test: for every `CaseState` and `Executing`+`reconciling`, the chip has a glyph and a label (reuse the copy table); for a passed and a failed Validator check, the glyph or text differs
- [X] T014 [P] [US3] Extend coverage of labels in the same file: `SYNTHETIC` is present on every row, every Case header and the top bar, and `REPLAY` where the fixture is a replay, in both themes
- [X] T015 [US1] `ui/src/styles/base.css`: reset, type scale, `.mono`, `.small`, `.muted`, `.page-title`, `.section-title`, `.overline`, `.visually-hidden`, the focus ring (`--focus`, 3 px, visible on every surface), selection and link colors, all from tokens
- [X] T016 [US1] `ui/src/styles/surfaces.css`: `.layer`, `.card`, `.well` (inset), `.glass` (blur + translucent fill + `--glass-edge`), `.e1`..`.e5`, `.banner`, `.dossier`, `.interpretation-card`, `.evidence-card`, `.conflict`, `.next-step`, `.empty`, `.not-yet`, `.raw`. Content the Operator reads to decide stays **opaque** (FR-012). Evidence keeps its solid fact-colored left border; the interpretation card keeps its dashed border (US3)
- [X] T017 [US1] `ui/src/styles/controls.css`, buttons and fields: `.btn`, `.btn-primary`, `.btn-secondary`, `.btn-danger`, `.btn-link`, `.field`, inputs, textareas, `fieldset`, `.option`, `.inline-error`. Raised buttons with a visible `--line-strong` boundary, inset fields, 44 px targets, **not pills** (FR-011)
- [X] T018 [US1] `ui/src/styles/controls.css`, chips and filters: `.chip` is the only pill; `.tone-*`, `.tag`, `.badge-synthetic`, `.connection-note`, `.ev-chip`. Turn `.filters` into a segmented control (inset track, raised selected segment, `aria-pressed` styling) without changing its DOM or roles
- [X] T019 [US1] Migrate `CaseList.svelte`, `CaseRow.svelte`, `StateChip.svelte`, `Labels.svelte` to the new classes. Rows are raised surfaces; the selected or focused row is clearly distinct; the row change flash uses tokens
- [X] T020 [US1] Migrate `CaseDetail.svelte`, `StateBanner.svelte`, `LayerWhatFailed`, `LayerEvidence`, `EvidenceCard`, `EvidenceChip`, `LayerDiagnosis`, `DiagnosisView`, `LayerProposal`, `LayerApproval`, `LayerExecution`, `NotYet`. Tables and `.kv` scroll or wrap inside their own box
- [X] T021 [US1] Migrate `Timeline.svelte` (compact list, state changes in accent, blocks in attention), `Dossier.svelte` and `ResolutionForm.svelte` (attention border kept; Dossier first when `ReviewRequired`, last and collapsed when closed, as in 005)
- [X] T022 [US3] Run T013 and T014; fix every finding in the styles, not in the tests. Compare each state's chip and banner in both themes against `EXPERIENCE.md` State Patterns
- [X] T023 [US6] Migrate every remaining literal listed in T002 into tokens until `token-audit.test.ts` (T005) passes. Delete the aliases of T007 and any now-unused variable. T005 goes green here
- [X] T024 Run the whole suite. The count equals T001's baseline plus the new tests, and every 005 test passes unedited. Record both numbers in `research.md`

**Checkpoint (MVP)**: every existing view has the new surfaces in both themes, meaning intact, tests green.

---

## Phase 5: User Story 4 — One layout from phone to wide desktop (P1)

- [X] T025 [P] [US4] `ui/tests/shell-layout.test.ts` (failing first), structure only (jsdom has no layout): the shell renders one navigation landmark named "Main" with exactly one entry, **Cases**, and no link to Orders, Partners, Outbox or Benchmark (FR-015); the theme toggle, the declared-name field and the `SYNTHETIC` badge are in the shell at every render; the main region keeps `tabindex="-1"` and receives focus on a route change; the page title is announced as in 005
- [X] T026 [US4] `ui/src/lib/components/Shell.svelte`, markup only: wrap the existing top bar so it is a **rail** at 1100 px and up and a compact **top bar** below. Add `ThemeToggle`. Keep the route, polling, focus and title logic byte for byte
- [X] T027 [US4] `ui/src/styles/layout.css`: the three bands of 005. 1100+: rail (`--rail-w`) beside the content, `.detail-grid` as layers + sticky Timeline (`--timeline-w`), `.case-link` as a grid. 640 to 1099: compact bar, Timeline under the layers, partner column dropped (labels stay). Under 640: stacked card rows, wrapping bar that keeps the name field and the `SYNTHETIC` label, `--gutter-mobile`. `minmax(0, 1fr)` on grid columns; wide tables, raw bodies and long identifiers scroll or wrap in their own box
- [X] T028 [US4] Touch targets: every interactive control is at least 44 × 44 px (buttons, toggle, filter segments, row link, Evidence chips, dialog actions, toast close if any). Evidence chips keep their visual size with padding or a pseudo-element hit area
- [X] T029 [US4] Dialog on a phone: the `<dialog>` scrolls inside itself (`max-height`, `overflow: auto`) and both decisions stay reachable
- [ ] T030 [US4] Quickstart steps 6 and 8 in a real browser at 360, 640, 1100 and 1440 px, then at 200% text size and 400% zoom. Tick the coverage table columns "360 px" and "1440 px"

**Checkpoint**: the console is usable from a phone to a wide desktop.

---

## Phase 6: User Story 5 — Beautiful without making it harder to use (P2)

- [X] T031 [P] [US5] `ui/tests/fallbacks.test.ts`: read the shipped CSS text and assert the fallbacks exist — an `@supports not (backdrop-filter: blur(1px))` block and a `@media (prefers-reduced-transparency: reduce)` block that both set `--glass` to `--glass-solid`; a `@media (prefers-reduced-motion: reduce)` block that zeroes `--dur-*` and disables `animation`, `transition` and `scroll-behavior`; a `@media (forced-colors: active)` block that removes shadows and sets borders; a `@media print` block. (A text check: behavior is verified in the browser at T035)
- [X] T032 [US5] `ui/src/styles/surfaces.css`, glass: apply `.glass` to the rail or top bar, the approval dialog (with its backdrop), `.toasts` and the connection note, **only** those (FR-012). At most three blurred layers on screen at once. Add the `@supports` and `prefers-reduced-transparency` fallbacks
- [X] T033 [US5] `ui/src/styles/motion.css`: tokens for durations, the row flash, the spinner, toast entry; `prefers-reduced-motion: reduce` removes all of it and a busy state stays visible as text. A row change never moves a control under the focus or pointer (FR-019). `@media (forced-colors: active)`: system colors, 1 px borders, no shadows, focus ring visible; `@media (prefers-contrast: more)`: stronger `--line-strong` and opaque glass
- [X] T034 [US5] `ui/src/styles/print.css`: hide the rail, theme toggle, toasts and connection note; remove glass, blur and shadows; black on white; expand the Timeline; keep state glyphs and labels and `SYNTHETIC`
- [ ] T035 [US5] Quickstart steps 5 and 7 in a real browser: color-blind emulation with shadows off, reduced motion, reduced transparency or blur off, forced colors, `prefers-contrast: more`, print preview. Fix findings in the styles

**Checkpoint**: every effect degrades to a legible, usable console.

---

## Phase 7: Documentation, serving check and polish

- [ ] T036 Build and verify on the live instance with iris-agentic-dev (quickstart step 9): `cd ui && npm run build`; request `/signalnoir/ui/theme-init.js` and confirm 200 and a JavaScript content type; confirm `index.html` and the assets still 200. Record the result in `research.md` R7 (replace `pending`)
- [ ] T037 Offline check (quickstart step 10): load once, block the network, reload; the console renders fully. Search the built output for any `http://` or `https://` URL that is not the console itself and confirm none loads a font, style, script or image (FR-021, SC-008)
- [ ] T038 Real-browser accessibility (quickstart step 12): axe with contrast enabled on the list, a Case, the dialog and the Dossier, light and dark, at 360, 768 and 1440 px. Record the result (SC-003)
- [X] T039 Update `_bmad-output/initiative-signal-noir/ux-signal-noir/DESIGN.md`: the new frontmatter tokens, a "Theme" section (system default, override, remembered), and mark **superseded by 014** the previous Elevation & Depth, Shapes, the dark-mode sentence in Colors while keeping the semantic meanings, the system-font rule, the mono-for-literals rule and the Do's and Don'ts (FR-020). Link `specs/014-liquid-console-redesign/`
- [X] T040 [P] Update `specs/005-operator-console/spec.md` Assumptions with one line pointing to 014 for the visual system, and `docs/specify-prompts/PARALELISMO.md` with the 014 row
- [ ] T041 Full run: `cd ui && npm run check && npm test && npm run build`. Record counts. Tick every box of the coverage table in `checklists/requirements.md`; confirm SC-001 to SC-009 one by one in `research.md` ("Outcome")

## Dependencies & Execution Order

Setup (T001–T003) → US6 tokens (T004–T007) → US2 theme (T008–T012) → US1 + US3 surfaces (T013–T024)
→ US4 layout (T025–T030) → US5 fallbacks (T031–T035) → docs and serving (T036–T041).

- T006 needs T004 and T005 written first (they fail until it and T023 land).
- T011 needs T009. T012 is independent of T011.
- T015 to T018 (style files) come before the component migrations T019 to T021.
- T026 needs T011 (the toggle). T027 needs T026.
- T032 and T033 extend files created in T016 and T003.
- T036 needs a built `ui/` (after T012).

## Parallel Opportunities

T002/T003; T004/T005; T008/T010; T013/T014; the style files T015/T016/T017/T018 touch different files;
T019/T020/T021 touch different components; T025/T031.

## Implementation Strategy

- **MVP = through T024**: tokens, theme, every existing view restyled, meaning intact, tests green.
- Then the layout bands and the rail (US4), then the fallbacks and print (US5), then the docs, the
  live-instance check and the final run.
- Commit nothing until asked; each phase ends at a green `npm test`.
