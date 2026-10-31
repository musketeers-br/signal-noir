# Quickstart: Liquid Console Redesign

How to run and verify the new look. Automated checks come first; the browser checks cover what jsdom
cannot (layout, blur, forced colors, print).

## Automated

```bash
cd ui && npm ci && npm run check && npm test
```

Expected: every 005 test passes unedited, plus `theme`, `tokens-contrast`, `token-audit` and
`a11y-themes`.

## In the browser (mock data)

```bash
cd ui && npm run dev:mock
```

Open the printed address at `/signalnoir/ui/`. The mock transport serves the contract fixtures.

1. **Theme follows the system.** With no `signalnoir.theme` in storage, switch the OS appearance: the console
   changes live, no reload.
2. **Toggle and memory.** Use the top-bar switch with mouse and with Tab + Enter. Its accessible name
   names the theme it switches to. Reload: the choice holds, with no flash. In devtools set `signalnoir.theme`
   to `banana`: it is ignored.
3. **Storage blocked.** Block site data and toggle: the theme still changes for the session.
4. **Every view, both themes.** List (each filter and the empty "Needs you"), a Case in each state
   (fixtures cover them), Evidence with a conflict and an obsoleted item, a Proposal with versions,
   the approval dialog with each server answer of 005 FR-010, a Dossier and its resolution form,
   toasts, "Case not found". Tick the coverage table in `checklists/requirements.md`.
5. **Meaning without color.** In devtools emulate "vision deficiency: achromatopsia" and disable
   shadows (`box-shadow: none !important`). Every state still has a glyph and a label; fact and
   interpretation are still different; failed and passed checks differ by glyph.
6. **Widths.** Check 360, 640, 1100 and 1440 px: rail at 1100+, compact bar below, Timeline beside
   then under the layers, stacked cards under 640, no horizontal page scroll at 360, targets at least
   44 px, the dialog scrolls inside itself on a phone.
7. **Fallbacks.** Emulate in turn: reduced motion, reduced transparency (or disable
   `backdrop-filter` in devtools), forced colors, `prefers-contrast: more`. Glass becomes opaque and
   legible; nothing animates; every boundary and the focus ring stay visible.
8. **Zoom and text size.** 200% text size and 400% browser zoom keep every view usable.
9. **Static script on IRIS (iris-agentic-dev).** Build and serve through the real instance:

   ```bash
   cd ui && npm run build
   ```

   Then request `/signalnoir/ui/theme-init.js` on the running instance and confirm status 200 and a
   JavaScript content type. Record the result in `research.md` R7.
10. **Offline.** Load once, block the network, reload: the console renders completely (SC-008).
11. **Print.** Print a Case: no glass, blur or shadow; black on white; state glyphs, labels and
    `SYNTHETIC` present.
12. **Real-browser accessibility.** Run axe with contrast enabled on the list, a Case, the dialog and
    the Dossier, in light and in dark, at 360, 768 and 1440 px. No AA violation (SC-003).

## Done when

- Success criteria SC-001 to SC-009 hold.
- `DESIGN.md` is updated and its superseded sections are marked.
- The coverage table in `checklists/requirements.md` is fully ticked.
