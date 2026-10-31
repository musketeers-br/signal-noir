# Phase 0 Research: Liquid Console Redesign

**Date**: 2026-10-31

## R1 — How the console is styled today

- **Finding**: all styling is global classes in `ui/src/app.css` (128 lines); there is no `<style>` block
  in any component or route. Colors come from the DESIGN.md tokens as CSS variables; dark mode is one
  `@media (prefers-color-scheme: dark)` block. Components emit classes such as `.layer`, `.chip`,
  `.tone-*`, `.case-link`, `.banner`, `.dialog`, `.toast`.
- **Decision**: keep every class name and rewrite what sits behind it. This is what makes FR-002 and
  SC-002 cheap to hold: the DOM the tests query does not change except in the shell.

## R2 — One definition for light and dark

- **Decision**: define each token once as `light-dark(<light>, <dark>)` and switch themes with
  `color-scheme` on the root: `:root { color-scheme: light dark }` follows the system,
  `[data-theme='light']` and `[data-theme='dark']` force one.
- **Rationale**: the system preference, the Operator's override and the live follow of a system change
  (spec Edge Cases) all fall out of the platform with no JavaScript for colors. A token file has one
  list, so the contrast test reads each pair directly.
- **Alternatives**: two full variable blocks plus a media query (three copies of the dark values, easy
  to drift); a class swap with runtime-computed values (JavaScript in the paint path).
- **Risk**: `light-dark()` needs a 2024+ browser. Accepted: target is evergreen (005). A single
  `@supports not (color: light-dark(#000, #fff))` block falls back to the light values, so an old
  browser gets a correct light console rather than a broken one.

## R3 — Pre-paint theme

- **Decision**: `ui/static/theme-init.js`, a synchronous script in `<head>`, reads `signalnoir.theme`; if it is
  `light` or `dark` it sets `data-theme` on `<html>`; anything else leaves it unset. All reads are in
  `try/catch`. The store in `theme.svelte.ts` uses the same key and the same validation.
- **Rationale**: SvelteKit's `app.html` is the only place that runs before first paint in a static SPA.
  A separate file instead of an inline script avoids breaking under a stricter Content-Security-Policy
  later. With no remembered choice nothing runs, and the system preference applies through
  `color-scheme` with no flash.
- **Alternatives**: setting it in the root layout on mount (flash for one frame); a cookie read by the
  server (the app is static).

## R4 — Palette and the semantic roles

- **Finding**: the reference has a cream paper with teal accent in light and a green-black noir in dark,
  but only four roles (accent, ok, warn, bad). DESIGN.md has eight (accent, fact, interpretation,
  attention, hold, success, danger, focus), and 005 depends on telling them apart.
- **Decision**: keep the eight roles and their meanings. Re-tune values toward the reference's warmer,
  softer feel and prove them with the contrast test: text on its own surface 4.5:1; large text 3:1;
  boundaries and focus ring against both neighbors 3:1. Each role has a `-soft` tint for fills; text on a
  tint is tested as its own pair.
- **Rationale**: a soft palette fails AA first on muted text and on tinted chips. Testing the pairs
  catches that before a screenshot does.

## R5 — Elevation, shapes and glass

- **Decision**:
  - Elevation levels `e1` flat (border only), `e2` hover, `e3` raised, `e4` dialog, `e5` popover, each a
    token composed from `--shadow-lo` and `--shadow-hi` (the paired dark and light shadows of the
    reference), so dark mode gets a quieter highlight without a second list.
  - Inset surfaces for inputs and the segmented filter.
  - Radius tokens `sm 8`, `md 12`, `lg 20`, `xl 28`; the pill only on `.chip`.
  - Glass (`backdrop-filter` blur with a translucent fill and a 1 px light edge) only on the rail or top
    bar, dialog, toasts, connection note. Opaque everywhere the Operator reads to decide (FR-012).
- **Fallbacks**: `@supports not (backdrop-filter: blur(1px))` and `@media (prefers-reduced-transparency:
  reduce)` swap `--glass` for `--glass-solid`, an opaque token with the same AA pair. Forced colors drops
  shadows and uses system colors with 1 px borders.
- **Rationale**: soft shadows between near colors are not a boundary (spec US5), so every control also
  has a `--line-strong` border at 3:1.

## R6 — Fonts

- **Decision**: system stacks from DESIGN.md (`system-ui` for sans; `ui-monospace` for mono). No font
  files, no third-party service.
- **Rationale**: the console is served by IRIS and must render offline (FR-021, SC-008). The reference
  loads two web fonts; adopting them would add a network request or a font asset for little gain. If the
  team later wants a face, shipping a file inside `ui/static` is a one-token change.

## R7 — Static script served by IRIS (iris-agentic-dev check)

- **Claim to verify**: the existing `/signalnoir/ui` static web app serves `theme-init.js` with a JavaScript
  content type, from the same build output as `index.html`.
- **Prior evidence**: 005 R3 verified static serving on this instance.
- **Status**: verified on 2026-10-31 (T036) on `signalnoir-iris` (build 154U): after `npm run build`,
  `GET /signalnoir/ui/theme-init.js` → **200 `application/javascript`**; `index.html` → 200; the 2 CSS and
  8 JS assets it references → 200. **Result on IRIS: pass.**
- **Note**: IRIS serves `index.html` and the CSS as `charset=ISO-8859-1`. Harmless today (all three files are
  pure ASCII, checked byte by byte); a non-ASCII character in either file would be decoded wrongly.

## R8 — Summary strip

- **Finding**: the contract returns per-Case counts (`pendingApproval`, `exceptionCount`) but no totals
  for the list; a count of the loaded page would mislead (the page is capped and paged by cursor).
- **Decision**: omit the summary strip. Revisit only if the contract gains a totals field (a contract
  change, not a console change).

## R9 — Navigation

- **Decision**: the rail and the compact bar list **Cases** only, matching 005's assumption. Orders,
  Partners, Outbox and Benchmark are not rendered, not even disabled, so there is no dead link
  (FR-015). Adding a screen later adds an entry with it.

## R10 — Verifying look without a layout engine

- **Finding**: jsdom cannot compute contrast, layout, blur or media queries (005's `a11y.ts` already
  disables `color-contrast` for that reason).
- **Decision**: three layers.
  1. Pure tests over `tokens.css`: parse each `light-dark()` token, compute the WCAG ratio for the
     declared text/surface and boundary pairs, in both themes.
  2. A file scan that fails on a literal color, shadow, radius or font stack outside `tokens.css`.
  3. Real-browser checks in `quickstart.md` for layout, blur, forced colors, reduced motion, print and
     360 px, with axe including contrast.
- **Rationale**: layers 1 and 2 are deterministic and run in CI; layer 3 covers what only a browser can.

## R11 — Print

- **Decision**: `print.css` hides the rail, top bar controls, toasts and the connection note, removes
  glass, blur and shadows, forces black on white, expands the Timeline, and keeps state glyphs, labels
  and `SYNTHETIC`.

## Baseline (T001, 2026-10-31)

Untouched tree: `npm run check` 0 errors; `npm test` 11 files, 46 tests, all passing.

## Outcome so far (2026-10-31)

- After the redesign: `npm run check` 0 errors; `npm test` 17 files, 140 tests (46 of 005, unedited, plus
  94 new: 63 token-contrast and audit, 21 theme and a11y-themes, 10 shell-layout and fallbacks); `npm run build` ok.
- Contrast: all 30 token pairs pass in both themes (the test fails with token names and the ratio).
  The `--focus` on `--accent` pair of the contract was dropped: the ring sits 3 px off the control, on the page.
- Vitest empties CSS by default, so `vite.config.ts` sets `test.css.include` for `src/**/*.css`; the
  audit also asserts that no stylesheet is read as empty.
- Real browser (dev:mock, built-in browser): axe with contrast on the list, a Case, the approval dialog
  and the Dossier, in light and dark, at 360 px: no violations. Found and fixed at 360 px: a grid column
  that widened the page (`minmax(0, 1fr)`), a long unbroken `<code>`, and two links under 44 px.
- Not yet verified: 640, 768, 1100 px beyond the rail at 1440; reduced motion, reduced transparency, forced
  colors, print preview; zoom 400%; offline; `theme-init.js` on the IRIS instance (T036).

## Outcome (2026-10-31, real-browser pass: T030, T035, T036, T037, T038, T041)

Chromium (Playwright, headless) over `npm run dev:mock` (contract fixtures) for every view and state, and
over the live IRIS console for serving and network. Every list filter, a Case in every fixture state
(pending approval, superseded, held, outcome unknown, prior receipt, review after denial, ambiguous
identity, provider unavailable), "Case not found", the approval dialog, "Versions and metrics", an approval
and its toast; light and dark; 360, 640, 768, 1100 and 1440 px.

**Found and fixed** (each pinned by `ui/tests/browser-findings.test.ts`):

1. axe `color-contrast` (serious): the `FACT` overline of obsoleted Evidence was 3.5:1 in light because
   the card used `opacity: 0.75`. The opacity is gone; the dashed border and the "Obsoleted by" tag carry
   the meaning.
2. axe `scrollable-region-focusable` (serious): the revalidation and colliding-records tables scroll in
   their own box but could not be reached by keyboard. They take `tabindex="0"`.
3. Reflow at 320 px (400% zoom): the conflict pair and `.kv` used `1fr`, and long mono codes did not
   break, so the page scrolled 20 px. Columns are `minmax(0, 1fr)` and `.mono` may break anywhere.
4. Print kept the raised shadow of buttons. Print now removes every `box-shadow`.
5. "Back to cases" on "Case not found" was 95×18 px. It gets the 44 px `.back-link`.

**Results after the fixes**

- **SC-001** pass: every view and state above rendered in both themes; the coverage table is ticked.
  The empty "Needs you" and the dialog's refusal answers (stale, invalid transition, invalid actor,
  network) are not reachable with the browser mock and are covered in both themes by `case-list`,
  `approval-dialog` and `a11y-themes` (jsdom).
- **SC-002** pass: the 46 tests of 005 run unedited inside 161 passing tests (20 files).
- **SC-003** pass: axe with contrast enabled, WCAG 2.2 A/AA: **0 violations** on 13 views × 2 themes × 5
  widths, plus versions, approval and toast at 360 and 1440 in both themes.
- **SC-004** pass: achromatopsia with all shadows removed: state chips keep glyph and label, fact and
  interpretation keep their solid and dashed borders, failed and passed checks keep ✕ and ✓.
- **SC-005** pass: no horizontal page scroll at any width from 360 to 1440, and none at 320 (400% zoom);
  every control at least 44 px (radios sit in 44 px labels).
- **SC-006** pass: `token-audit` (no literal color, shadow, radius or font outside the tokens).
- **SC-007** pass: reduced motion leaves 0 animated elements; reduced transparency and `prefers-contrast:
  more` make the top bar and dialog opaque with no blur; forced colors drops every shadow and keeps
  1 px borders; keyboard focus shows a 3 px solid ring (dialog included).
- **SC-008** pass as specified: with every request outside `localhost` blocked, the live console renders
  50 rows, loads no web font and makes 0 external requests. A fully offline reload fails
  (`ERR_INTERNET_DISCONNECTED`): there is no service worker and the data comes from the IRIS API, which the
  spec does not ask to cache.
- **SC-009** pass: a chosen theme is on `<html>` before `<body>` exists (no flash), survives a reload,
  and an invalid stored value (`banana`) is ignored.
- Text at 200% (1100 and 1440 px) and 400% zoom: no overflow, no clipped control.
- Print: white page, black text, no blur, no shadow, Timeline expanded, glyphs, labels and `SYNTHETIC`
  kept; the top bar stays because it carries the `SYNTHETIC` badge (T034).

**T041 full run**: `npm run check` 0 errors, 0 warnings; `npm test` 20 files, 161 tests passing;
`npm run build` ok.
