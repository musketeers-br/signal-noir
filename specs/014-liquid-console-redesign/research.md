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
- **Status**: not yet run on the live instance (T036). `npm run build` writes `build/theme-init.js` and
  `build/index.html` references it; the dev server serves it. Result on IRIS: `<result: pending>`.

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
