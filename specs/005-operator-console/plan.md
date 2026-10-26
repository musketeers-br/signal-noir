# Implementation Plan: Operator Console

**Branch**: `005-operator-console` | **Date**: 2026-10-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/005-operator-console/spec.md`

## Summary

A static single-page console in `ui/`, built with Svelte 5 + SvelteKit 3 (`adapter-static`, hash
router, base path `/signalnoir/ui`), served by IRIS. It reads and writes only through a typed
client of `contracts/openapi-signalnoir.yaml`. All server answers are mapped to one closed
`Outcome` type, so the honesty rules (no optimistic update, replay ≠ success, 409/422/network
handling) live in one place and are unit-tested. Polling stores keep the list and the open Case
fresh every 1.5 s and only replace data; components keep focus, input and open/closed state in
their own local state, so a poll cannot reset them. Copy for states and outcomes comes from one
copy table derived from the UX spine. Tests run in Vitest + jsdom with Testing Library and axe-core,
against a transport that serves the contract fixtures (the same transport powers `npm run dev:mock`).
IRIS serves the built files at `/signalnoir/ui/`; `/signalnoir/` redirects there; the API stays at
`/signalnoir/api/v1`.

## Technical Context

**Language/Version**: TypeScript 6.0.3, Svelte 5.57.2; Node 24 LTS for builds (dev machine has Node
26.3.1, which satisfies `node >= 22.17`).

**Primary Dependencies** (exact pins, from `research-stack.md` + npm registry, 2026-10-25):
`@sveltejs/kit 3.1.0`, `@sveltejs/adapter-static 4.0.0`, `svelte 5.57.2`, `vite 8.3.5`,
`@sveltejs/vite-plugin-svelte 7.3.1`, `typescript 6.0.3`, `svelte-check 4.7.7`; tests:
`vitest 5.0.5`, `jsdom 30.1.3`, `@testing-library/svelte 5.4.2`, `@testing-library/user-event
14.6.8`, `@testing-library/jest-dom 7.0.1`, `@testing-library/dom` (peer), `axe-core 4.14.0`. No UI
component library (DESIGN.md is the visual system).

**Storage**: none server-side; the declared Operator name in `localStorage`.

**Testing**: Vitest component and store tests (jsdom) against the fixture transport; axe-core
checks on list, detail, dialog and dossier; a keyboard-only journey test with user-event.
`svelte-check` for types. Backend unchanged except one dispatch class for the redirect.

**Target Platform**: evergreen browsers; IRIS private web server (`/signalnoir/ui/` static,
`/signalnoir/` redirect).

**Project Type**: web frontend inside the single IRIS project (`ui/` folder).

**Performance Goals**: poll every 1.5 s (AD-17 range 1–2 s); list page 50; incremental Timeline.

**Constraints**: no new endpoint or field; no optimistic updates; WCAG 2.2 AA; prototype code is not
copied (Constitution, Workflow); calendar-gate exception granted (research).

**Scale/Scope**: list + detail + approval + dossier resolution; Benchmark screen excluded.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Pure Core** — the console holds no domain rule: states, catalog and validation come from
  the API; it only maps contract values to copy. It never talks to the Simulator.
- [x] **II. Closed Catalog** — the resolution form lists Actions from `/reference/action-catalog`
  and mappings from `/reference/mappings`; there is no free payload field; nothing executes code.
- [x] **III. One Validator** — the Operator's resolution goes through `POST /resolution`; 422
  verdicts are shown, never bypassed.
- [x] **IV. Human Authority** — the dialog freezes `proposalId` + `expectedCaseVersion`; separate
  Approve/Deny; no auto-approve, no "approve all".
- [x] **V. Case as Source of Truth** — no optimistic updates; the screen changes only after an answer
  or a poll.
- [x] **VI. Effects at Most Once** — Approve disabled in flight and after a network error until a
  poll; replay shown as "no new effect".
- [x] **VII. Honest Outcomes** — one `Outcome` mapping for every answer; distinct copy for waiting,
  review and uncertainty; "no interpretation" / "nothing flagged" states.
- [x] **VIII. Honest Measurement** — N/A (Benchmark screen excluded); Replay labelled.
- [x] **IX. Verifiable Increments** — six stories, each with its failing test first.
- [x] **Platform Constraints** — synthetic labels everywhere; no secret in the client.
- [x] **iris-agentic-dev** — static serving verified live on this instance: a web app with `Path` +
  `ServeFiles=1` serves files (200), but its empty path `/app/` returns 404 (research R3), hence the
  redirect app; ObjectScript changes compile and test through iris-agentic-dev.

### Post-design re-check (after Phase 1)

All gates pass. No contract change.

## Project Structure

### Documentation (this feature)

```text
specs/005-operator-console/
├── plan.md  research.md  data-model.md  quickstart.md  tasks.md
├── contracts/ui-contract-binding.md
└── checklists/requirements.md
```

### Source Code (repository root)

```text
ui/
├── package.json  package-lock.json  svelte.config.js  vite.config.ts  tsconfig.json  .gitignore
├── src/
│   ├── app.html  app.css            # DESIGN.md tokens (light/dark), reduced motion
│   ├── routes/+layout.ts            # ssr = false, prerender
│   ├── routes/+layout.svelte        # top bar, operator name, SYNTHETIC badge, connection note, toasts
│   ├── routes/+page.svelte          # hash router: #/cases, #/cases/<id>
│   └── lib/
│       ├── api/types.ts             # contract types (subset used)
│       ├── api/client.ts            # typed calls, base "../api/v1"
│       ├── api/outcome.ts           # HTTP answer -> Outcome (closed union)
│       ├── api/transport.ts         # fetch | fixture transport
│       ├── api/fixtures.ts          # contract fixtures as a fake server (tests, dev:mock)
│       ├── copy.ts                  # state chips/banners, outcome copy, reason-code text
│       ├── format.ts                # BRT time, age, deadline
│       ├── stores/poller.ts         # 1.5 s polling, failure -> stale
│       ├── stores/cases.ts          # list (newer cursor merge, older paging, filters)
│       ├── stores/caseDetail.ts     # detail + incremental timeline
│       ├── stores/operator.ts       # declared name (localStorage)
│       ├── stores/toasts.ts
│       └── components/  CaseList, CaseRow, StateChip, StateBanner, CaseDetail, LayerWhatFailed,
│                        LayerEvidence, EvidenceCard, EvidenceChip, LayerDiagnosis, LayerProposal,
│                        LayerApproval, LayerExecution, Timeline, ApprovalDialog, Dossier,
│                        ResolutionForm, Toasts, ConnectionNote, NotYet
└── tests/  (*.test.ts per story + a11y + keyboard journey)
src/SignalNoir/Api/Console.cls      # %CSP.REST at /signalnoir: "/" -> 302 ui/index.html#/cases
src/SignalNoir/Interop/Bootstrap.cls # registers /signalnoir (redirect) and /signalnoir/ui (static, SN_UI_PATH)
```

**Structure Decision**: a self-contained `ui/` package next to the IRIS sources; its build output is
not committed (`ui/.gitignore`) and is copied into the image by 012.

## Complexity Tracking

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Extra redirect web app `/signalnoir` | A static IRIS web app returns 404 for its empty path on this build (verified), and AD-17 promises `/signalnoir/` | Serving files from a REST dispatch reimplements a static server and needs path-traversal guards |
| Fixture transport in the client package | The decision, resolution and reference endpoints are not served yet (007/009/004); the console must be built and tested against the frozen contract now | Waiting for those features would serialize wave 3 behind them |
