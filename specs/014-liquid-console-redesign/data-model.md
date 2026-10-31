# Data Model: Liquid Console Redesign

The redesign owns no server data and adds no contract type. It adds one browser-side preference and a
fixed vocabulary of design tokens.

## ThemeChoice (browser only)

| Field | Type | Rule |
|---|---|---|
| `signalnoir.theme` (localStorage key) | `'light'` \| `'dark'` \| absent | Any other stored value is ignored as absent (FR-006). |

- **Absent** means "follow the system", live (spec Edge Cases).
- **Effective theme** (derived, not stored): the choice when set, else the system preference.
- Written only when the Operator uses the toggle. Never written on load.
- Reads and writes are guarded; failure leaves the session theme working and stores nothing.
- Applied to the document as `data-theme="light|dark"` on `<html>`; absent when following the system.
- The theme choice is not sent to the server and is not part of any Case, export or log.

### Transitions

```text
absent  --toggle--> opposite of the current effective theme
light   --toggle--> dark
dark    --toggle--> light
```

The toggle never returns to "absent"; following the system again means clearing the browser's site data.
(A "follow system" option is deliberately out of scope: the spec asks for one switch.)

## Operator name (unchanged)

`signalnoir.operator` in `localStorage`, as in 005. Unaffected by this feature.

## Design tokens

A token is a named CSS custom property defined once in `ui/src/styles/tokens.css`. The full list and
roles are in [contracts/design-tokens.md](./contracts/design-tokens.md). Rules:

- A token that differs by theme is written `light-dark(<light>, <dark>)`.
- Component styles use `var(--token)` only. Literal colors, shadows, radii and font stacks outside
  `tokens.css` fail the token audit.
- A tinted pair (`--x` on `--x-soft`) is a tested contrast pair.
