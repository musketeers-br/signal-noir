# Phase 0 Research: Operator Console

**Date**: 2026-10-25

## Calendar-gate exception

Henry asked for the full cycle of 005, including implementation, on 2026-10-25 (same decision as for
003 and 006). Recorded for the G2 review.

## R1 — Stack

- **Decision**: Svelte 5 + SvelteKit 3 with `adapter-static`, hash router, `ssr = false`,
  `paths.relative = true`; TypeScript 6. Versions pinned exactly (plan Technical Context), checked
  against the npm registry on 2026-10-25 (`@sveltejs/kit` 3.1.0 published 2026-10-14; peers `vite
  ^8.0.12`, `svelte ^5.57.1`, `typescript ^6.0.0`).
- **Rationale**: AD-17 and the UX spine fix Svelte 5/SvelteKit/adapter-static and hash routing; the
  stack research (`research-stack.md` §2) confirmed adapter-static 4 for a pure SPA.
- **Alternatives**: plain Svelte + Vite without Kit (loses the agreed structure); a component library
  (rejected by DESIGN.md).

## R2 — Testing

- **Decision**: Vitest 5 + jsdom 30 + Testing Library (svelte, user-event, jest-dom) + axe-core 4.14.
  A fixture transport answers the contract operations from `contracts/fixtures/**` and lets a test
  script the next answer (status + body), including network failure.
- **Rationale**: the stories are about what the Operator sees and can do; component tests over the
  real contract payloads prove that without a backend. axe-core gives the automated part of
  WCAG 2.2 AA; keyboard parity is a user-event journey.
- **Limit**: jsdom does no layout, so contrast is checked against DESIGN.md's tokens (which state
  AA in both themes) and axe's `color-contrast` rule is disabled in jsdom. Real-browser checks are
  part of the quickstart walk-through.

## R3 — Serving from IRIS

- **Verified live (iris-agentic-dev, 2026-10-25)**: a web app with `Path=/tmp/snprobe/`,
  `ServeFiles=1`, `Type=2` served `index.html` (200, text/html) and `app.js` (200,
  application/javascript), but `GET /snprobe/` returned **404**; `Recurse=1` did not change it. The
  probe app was deleted.
- **Decision**: two apps — `/signalnoir/ui` static (`Path` from `SN_UI_PATH`, default
  `/home/irisowner/dev/ui/build/` in the dev container) and `/signalnoir` with a tiny `%CSP.REST`
  (`SignalNoir.Api.Console`) that redirects `/` to `ui/index.html#/cases`. `/signalnoir/api/v1`
  keeps its own app (longest prefix wins).
- **Consequence**: the client's API base is `../api/v1` relative to `/signalnoir/ui/`.

## R4 — Honesty in one place

- **Decision**: `outcome.ts` maps every HTTP answer to a closed union: `created`, `replay`,
  `stale`, `invalidTransition`, `invalidActor`, `badRequest(fields)`, `blocked(reasons)`,
  `notFound`, `network`, `server`. Components only switch on it; copy for each comes from `copy.ts`.
  Nothing writes data from a command answer except by triggering a refetch.

## R5 — Polling without losing the Operator's place

- **Decision**: stores hold server data only; open/closed sections, field values, focus and inline
  errors live in component-local state keyed by stable ids (caseId, evidenceId, proposalId). Svelte 5
  keyed `#each` keeps DOM nodes (and focus) across updates. The list merges `direction=newer` pages
  by caseId; a full reload only on filter change.
- **Network failure**: the poller sets `stale = true` after a failed poll and clears it on the next
  success; the top bar shows the persistent note.

## R6 — Filters

- **Decision** (contract filters): Needs you = `state=PendingApproval&state=ReviewRequired`;
  Active = `status=open`; Closed = `status=terminal`; All = no filter.

## R7 — Fixtures as data

- The fixtures carry the contract's shapes for every surface (list, P5/P8b detail, superseded
  proposal, held P3, outcome unknown, dossiers, decisions 201/200/409/400, resolution 201/422, 404,
  reference mappings). The transport serves them by operation; no fixture is edited.

## Implementation notes (2026-10-25)

- **SvelteKit 3 differences found while building**: configuration moved from `svelte.config.js` to
  `sveltekit({...})` in `vite.config.ts`; `tsconfig.json` must extend `$app/tsconfig` and keep
  `$app/types`; there is no default `$lib` alias (relative imports are used); with
  `router.type: 'hash'` page options (`ssr`, `prerender`) are not allowed.
- **Base path instead of relative paths**: with the hash router the build emits root-absolute asset
  URLs, so `paths.base = '/signalnoir/ui'` (the fixed IRIS path, AD-17). A first build with the
  pathname router showed Kit's own 404 at `/signalnoir/ui/index.html`; the hash router plus a
  catch-all `[...rest]` route fixed it.
- **Process note**: in this feature the component code was written before most of its tests (the
  test files followed in the same session, before any green run). TDD order was kept for the
  ObjectScript part (`TestBootstrap.TestConsoleApplicationsRegistered`).

## Verification log (2026-10-25)

| Check | Result |
|---|---|
| `npm run check` (svelte-check) | 0 errors, 0 warnings |
| `npm test` (Vitest + jsdom + Testing Library + axe-core) | 45 passed: outcome mapping, copy, format, list, detail, approval dialog, keyboard journey, dossier, state banners, polling |
| `npm run build` | static site in `ui/build` (`index.html` + `_app/`) |
| IRIS serving (iris-agentic-dev + curl) | `/signalnoir/` → 302 `ui/index.html#/cases`; `/signalnoir/ui/index.html` 200; JS asset 200 `application/javascript`; `/signalnoir/api/v1/cases` 200 |
| Real browser (built-in browser, dark scheme) | list loads from the IRIS API with Needs you active; a case detail shows banner, layers and honest empty states |
| ObjectScript suite | 110 pass, 1 fail (the pre-existing `Api.TestHealth` of 001) |
| Edge found in the browser | a `PendingApproval` case without a current proposal (backend test data) offered "Review & approve…"; the banner now offers it only with a current proposal (test added) |
