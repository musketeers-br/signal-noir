# Design Token Contract

The names below are the interface between `tokens.css` and every other style file. Values are decided
in implementation and proved by `tokens-contrast.test.ts`; this contract fixes **names, roles and the
pairs that must pass**. Each color token is defined once as `light-dark(light, dark)`.

## Surfaces

| Token | Role |
|---|---|
| `--paper` | page background |
| `--surface` | cards, layers, rows (opaque) |
| `--surface-raised` | blocks inside a card (effect statement, panels) |
| `--surface-inset` | inputs, segmented filter track, wells |
| `--glass` | translucent fill for floating layers |
| `--glass-solid` | opaque stand-in for `--glass` (no blur, reduced transparency) |
| `--glass-edge` | 1 px light edge of a floating layer |
| `--code-bg` | raw bodies and code |

## Text and lines

| Token | Role |
|---|---|
| `--ink` | primary text |
| `--ink-muted` | metadata only; never for something the Operator must act on |
| `--line` | decorative separators |
| `--line-strong` | control and card boundaries (3:1 against both neighbors) |

## Semantic roles (meaning unchanged from DESIGN.md)

Each role has the color, a `-soft` tint and an `-ink` where it is used as a fill.

| Token | Single meaning |
|---|---|
| `--accent`, `--accent-soft`, `--accent-ink` | "act here": primary actions, current navigation |
| `--fact`, `--fact-soft` | observed Evidence; in-flight states |
| `--interpretation`, `--interpretation-soft` | the Agent's or rules' reading; also "outcome unknown" |
| `--attention`, `--attention-soft` | something waits for the Operator; conflicts; the Dossier |
| `--hold`, `--hold-soft` | Held |
| `--success`, `--success-soft` | Resolved, passed checks, receipts, high confidence |
| `--danger`, `--danger-soft` | failures, blocks, refusals, low confidence |
| `--focus` | keyboard focus ring and Evidence jump highlight |

## Elevation

| Token | Use |
|---|---|
| `--shadow-lo`, `--shadow-hi` | the paired dark and light shadow colors (quieter highlight in dark) |
| `--e1` | flat: border only |
| `--e2` | hover |
| `--e3` | raised: layers and cards |
| `--e4` | modal: approval dialog |
| `--e5` | popover and toast: glass edge plus a long soft shadow |
| `--inset` | inset surfaces |

## Shape, type, space, motion

| Token | Value rule |
|---|---|
| `--r-sm`, `--r-md`, `--r-lg`, `--r-xl` | 8, 12, 20, 28 px |
| `--r-chip` | pill; used only by `.chip` (FR-011) |
| `--sans`, `--mono` | system stacks (FR-021) |
| `--fs-body`, `--fs-small`, `--fs-title`, `--fs-page`, `--fs-action` | the DESIGN.md scale |
| `--sp-1` … `--sp-6` | 4 px base scale |
| `--gutter`, `--gutter-mobile`, `--content-max`, `--timeline-w`, `--rail-w` | layout |
| `--dur-fast`, `--dur-base` | motion; set to 0 under reduced motion |
| `--blur` | background blur radius for glass |

## Contrast pairs that must pass (both themes)

| Pair | Minimum |
|---|---|
| `--ink` on `--paper`, `--surface`, `--surface-raised`, `--surface-inset`, `--glass-solid` | 4.5:1 |
| `--ink-muted` on `--paper`, `--surface`, `--surface-inset`, `--glass-solid` | 4.5:1 |
| each semantic color on its own `-soft` tint and on `--surface` | 4.5:1 |
| `--accent-ink` on `--accent` | 4.5:1 |
| `--line-strong` on `--surface` and on `--paper` | 3:1 |
| `--focus` on `--surface`, `--paper`, `--accent` | 3:1 |

## Class names kept from 005

`.layer .chip .tone-* .tag .badge-synthetic .banner .case-list .case-link .case-row .cell-* .btn .btn-*
.filters .field .inline-error .dialog .toast .toasts .connection-note .evidence-card .ev-chip .conflict
.interpretation-card .kv .raw .table .dossier .next-step .timeline .detail-grid .main .topbar
.wordmark .name-field` stay valid. New classes: `.rail`, `.rail-nav`, `.theme-toggle`, `.glass`,
`.well`, `.seg`.
