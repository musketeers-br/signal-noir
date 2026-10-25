# Quickstart: Operator Console

## Install and test

```sh
cd ui
npm ci
npm run check      # svelte-check (types)
npm test           # vitest: stories, honesty, a11y, keyboard journey
npm run build      # static output in ui/build
```

## Run against the contract fixtures (no backend)

```sh
cd ui && npm run dev:mock     # http://localhost:5173/#/cases, data from contracts/fixtures
```

## Run on IRIS

1. `npm run build` in `ui/` (the dev container mounts the repo, so `ui/build` is visible at
   `/home/irisowner/dev/ui/build/`).
2. Compile `src/SignalNoir/Api/Console.cls` and `src/SignalNoir/Interop/Bootstrap.cls`, run
   `##class(SignalNoir.Interop.Bootstrap).OnStart()`.
3. Open `http://localhost:<web port>/signalnoir/` → redirects to `/signalnoir/ui/index.html#/cases`.

## Manual walk-through (real browser)

| Check | Expect |
|---|---|
| Needs you | default filter; `SYNTHETIC` on every row |
| P5/P8b detail (mock) | six layers; claim chip focuses the mapping-catalog card; conflict side by side |
| Approve | 201 toast; approve again → "Already approved … No new effect." |
| Stale | 409 keeps dialog open, "Nothing was recorded", "Review the new version" |
| Dossier | empty unknowns → "Nothing flagged"; 422 reasons inline, values kept |
| Keyboard | Tab/Enter/Esc complete the approval journey |
| Reduced motion | no flash, no smooth scroll |
| Dark mode | tokens switch, contrast holds |
