# Implementation Plan: Liquid Console Redesign

**Branch**: `014-liquid-console-redesign` | **Date**: 2026-10-31 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/014-liquid-console-redesign/spec.md`

## Summary

Restyle the whole console in `ui/` without touching its behavior. The console's styling is already
centralized (one `app.css` of global classes, no scoped component styles), so the work is mostly a
new style layer plus a small amount of markup in the shell:

1. **One token file** defines every color, surface, shadow, radius, type size, spacing and motion value
   once, for light and dark, using the CSS `color-scheme` property and `light-dark()`. A theme is just
   `color-scheme` on the root, so there is no second copy of the dark values.
2. **The existing class names stay.** Components keep emitting the same classes, roles and labels, so the
   005 tests keep passing unedited. Only the CSS behind those classes changes.
3. **A theme store and a toggle** (`light` | `dark` | none) persist the choice in `localStorage` and set
   the theme on `<html>`. A tiny static script in `<head>` applies it before first paint.
4. **A shell restructure**: a side rail at 1100 px and up (Cases only), the compact top bar below. The
   shell's logic (hash routes, polling, focus) is untouched.
5. **Three guards written as tests**: a contrast test over the token pairs of both themes, a token audit
   that fails on literal colors, shadows or radii outside the token file, and an axe run per theme.

No new endpoint, field, route or dependency. The reference design in `design/` is used for look and
proportions only; its sample data, quick approve, web fonts, summary strip and extra navigation are not
adopted (spec Assumptions).

## Technical Context

**Language/Version**: TypeScript 6.0.3, Svelte 5.57.2, plain CSS (no preprocessor); Node 24 LTS for
builds. Unchanged from 005.

**Primary Dependencies**: none added. Existing pins stay (`@sveltejs/kit 3.1.0`, `vite 8.3.5`,
`vitest 5.0.5`, `jsdom 30.1.3`, `axe-core 4.14.0`). No component library, no icon package, no font
package.

**Storage**: the declared Operator name and the theme choice in `localStorage` (keys `signalnoir.operator`,
`signalnoir.theme`; the first already exists). No server storage.

**Testing**: Vitest + jsdom + Testing Library as in 005. New tests: theme store and toggle, token
contrast (pure computation over `tokens.css`), token audit (file scan), axe per theme. All 005 tests
run unedited. Real-browser checks (layout, blur, forced colors, reduced motion, print, 360 px) are in
`quickstart.md`, because jsdom has no layout.

**Target Platform**: evergreen browsers (`light-dark()`, `color-mix()`, `backdrop-filter`,
`prefers-reduced-transparency` where available, with fallbacks); IRIS private web server serving
`/signalnoir/ui/` as in 005.

**Project Type**: web frontend inside the single IRIS project (`ui/`).

**Performance Goals**: first paint without a theme flash; at most three blurred layers on screen at
once (rail or top bar, one dialog or toast stack, one connection note); no layout shift from a poll.

**Constraints**: no behavior change (FR-002); no request outside the console (FR-021); WCAG 2.2 AA in
both themes (FR-016); no free-form colors outside tokens (SC-006); prototype and reference code are
not copied as-is.

**Scale/Scope**: 23 components and one stylesheet of 128 lines to restyle; one new store, one new
component, one static script; no backend change.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Pure Core** — presentation only; no domain rule is added or moved.
- [x] **II. Closed Action Catalog / Read-Only Agent** — no Action, Tool or payload path is touched;
  the resolution form still offers catalog Actions only.
- [x] **III. One Validator** — untouched; 422 verdicts render as before.
- [x] **IV. Human Authority** — the approval dialog is restyled, not shortened: it still freezes
  `proposalId` and Case version and separates Approve and Deny. The reference's quick approve is
  rejected (spec Assumptions).
- [x] **V. Case as Source of Truth** — no optimistic update is introduced; a theme switch changes
  styling only.
- [x] **VI. Effects at Most Once** — Approve stays disabled while in flight; no new way to send a command.
- [x] **VII. Honest Outcomes** — glyph + label rules and the distinct copy for waiting, review and
  uncertain outcome are kept and tested without color (FR-009).
- [x] **VIII. Honest Measurement** — N/A.
- [x] **IX. Verifiable Increments** — five slices, each starting with a failing test (see Delivery order).
- [x] **Platform Constraints** — synthetic labels kept; no secret in the client; no AI Hub image touched.
- [x] **iris-agentic-dev** — one platform claim: IRIS serves a new static file, `theme-init.js`, from
  the existing static web app. 005 verified static serving (R3). The check is repeated live in the
  quickstart and its result is recorded in `research.md` R7 before merge. Nothing in the runtime
  depends on it.

### Post-design re-check (after Phase 1)

All gates pass. No contract change, no backend change, no new dependency.

## Delivery order (slices, each test-first)

1. **Tokens and contrast guard.** `tokens.css` + the contrast test + the token audit. The audit starts
   failing on the old `app.css` literals, then passes as the styles are migrated. Value: one source of truth (US6).
2. **Theme.** Theme store, `ThemeToggle`, `theme-init.js`, `app.html`. Tests first (US2).
3. **Surfaces and controls.** Rewrite the component styles on the tokens: list, rows, filters, buttons,
   fields, chips, banner, six layers, Evidence, Diagnosis, Proposal, Timeline, Dossier, forms (US1, US3).
4. **Shell and layout.** Rail at 1100+, compact bar below, stacked cards under 640, sticky Timeline,
   scroll boxes for wide content (US4).
5. **Floating layers and fallbacks.** Dialog, toasts, connection note as glass; blur fallback, reduced
   transparency, reduced motion, forced colors, print; update `DESIGN.md` (US5, US6).

## Project Structure

### Documentation (this feature)

```text
specs/014-liquid-console-redesign/
├── plan.md  research.md  data-model.md  quickstart.md  tasks.md   # tasks.md comes from /speckit-tasks
├── contracts/design-tokens.md      # the token names and roles, light and dark
├── design/                         # reference design (non-normative)
└── checklists/requirements.md
```

### Source Code (repository root)

```text
ui/
├── static/theme-init.js            # NEW: sync script in <head>; reads signalnoir.theme, sets data-theme
├── src/
│   ├── app.html                    # + <script src="%sveltekit.assets%/theme-init.js">, theme-color
│   ├── app.css                     # becomes the entry: @imports of src/styles/*
│   ├── styles/                     # NEW
│   │   ├── tokens.css              # the only file with literal colors, shadows, radii, sizes
│   │   ├── base.css                # reset, type, focus ring, utility classes (.mono .small .muted ...)
│   │   ├── surfaces.css            # .layer .card .well .glass, elevation levels
│   │   ├── controls.css            # .btn .field .filters (segmented) .chip .tag .toast ...
│   │   ├── layout.css              # shell/rail, .detail-grid, .case-link, bands, scroll boxes
│   │   ├── motion.css              # durations, flash, spinner, reduced motion
│   │   └── print.css               # no glass, no shadows, black on white
│   └── lib/
│       ├── copy.ts                 # + theme labels ("Switch to dark theme" / "light theme")
│       ├── stores/theme.svelte.ts  # NEW: choice, effective theme, persistence, system listener
│       └── components/
│           ├── ThemeToggle.svelte  # NEW
│           └── Shell.svelte        # markup: rail + top bar; logic unchanged
└── tests/
    ├── theme.test.ts               # NEW
    ├── tokens-contrast.test.ts     # NEW
    ├── token-audit.test.ts         # NEW
    └── a11y-themes.test.ts         # NEW: axe on list, detail, dialog, dossier in each theme
_bmad-output/initiative-signal-noir/ux-signal-noir/DESIGN.md   # updated, superseded sections marked
```

**Structure Decision**: keep the single `ui/` package and split the one stylesheet into small files by
job, imported in a fixed order from `app.css`. Component files stay as they are, because their classes
are global and already shared. Scoped component styles are not introduced: they would scatter literals
and defeat the token audit.

## Key decisions (detail in research.md)

- **Tokens with `color-scheme` and `light-dark()`** instead of two blocks or a runtime class swap.
- **Semantic roles kept, values retuned** for the softer palette and re-proved by the contrast test.
- **System font stacks**, no font files and no third-party service (FR-021).
- **Glass only where it floats**; opaque surfaces for everything the Operator reads to decide (FR-012).
- **Buttons are not pills**; the pill stays for state chips (FR-011).
- **No summary strip**: the contract has no list totals (only per-Case fields), so it is omitted.
- **Pre-paint theme via a static script file**, not an inline script, so a future strict CSP does not break it.

## Complexity Tracking

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| A blocking script in `<head>` | The theme must be set before first paint (FR-005, SC-009) | Applying it after mount flashes the wrong theme for a frame on every load |
| A contrast test that parses `tokens.css` | jsdom cannot compute contrast, and the soft palette is where AA fails first (FR-016) | Manual checks drift as tokens change |
| A token audit test | SC-006 asks for no stray literals, and a reviewer cannot grep 23 components reliably | Convention alone erodes within a few edits |
