---
name: Signal Noir
description: Operator console for resolving interoperability exceptions with an AI agent under deterministic governance. Svelte 5 SPA served statically by IRIS; no component library, so this file is the whole visual system.
status: final
updated: 2026-10-31
revision: 'Feature 014 (liquid console redesign) supersedes Elevation & Depth, Shapes, and the theme rule of Colors. The values in tokens.css are the source of truth.'
colors:
  paper: '#ECE5D8'
  surface: '#F5F0E5'
  surface-raised: '#EFE8DA'
  surface-inset: '#E6DECF'
  code-bg: '#E6DECF'
  ink: '#172C32'
  ink-muted: '#4F5F63'
  line: '#CFC6B3'
  line-strong: '#857E70'
  accent: '#0B5A60'
  accent-ink: '#F4FBFA'
  accent-soft: '#D9E8E3'
  fact: '#285BB0'
  fact-soft: '#E3EBF8'
  interpretation: '#6B3FA0'
  interpretation-soft: '#EDE4F6'
  attention: '#8A4D09'
  attention-soft: '#F8E8CC'
  hold: '#6A5A2E'
  hold-soft: '#EDE6D2'
  success: '#1F6F3A'
  success-soft: '#DDEEDF'
  danger: '#A03535'
  danger-soft: '#F6E0DC'
  danger-ink: '#FFFFFF'
  focus: '#9A5A00'
  paper-dark: '#0A1012'
  surface-dark: '#131B1D'
  surface-raised-dark: '#182426'
  surface-inset-dark: '#0D1517'
  code-bg-dark: '#0D1517'
  ink-dark: '#E8EFEE'
  ink-muted-dark: '#9FB1B2'
  line-dark: '#26373B'
  line-strong-dark: '#5E7478'
  accent-dark: '#4FD0C6'
  accent-ink-dark: '#04201F'
  accent-soft-dark: '#14343A'
  fact-dark: '#8DB3F2'
  fact-soft-dark: '#1B2A44'
  interpretation-dark: '#C6A6F0'
  interpretation-soft-dark: '#2C2140'
  attention-dark: '#F0B867'
  attention-soft-dark: '#3A2A12'
  hold-dark: '#D9C58F'
  hold-soft-dark: '#2F2A1C'
  success-dark: '#7FD39B'
  success-soft-dark: '#173826'
  danger-dark: '#F29A9A'
  danger-soft-dark: '#3D1D1D'
typography:
  page-title:
    fontFamily: 'system-ui, -apple-system, "Segoe UI", sans-serif'
    fontSize: 28px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  section-title:
    fontFamily: 'system-ui, -apple-system, "Segoe UI", sans-serif'
    fontSize: 19px
    fontWeight: '700'
    lineHeight: '1.2'
  body:
    fontFamily: 'system-ui, -apple-system, "Segoe UI", sans-serif'
    fontSize: 15px
    fontWeight: '400'
    lineHeight: '1.55'
  body-small:
    fontFamily: 'system-ui, -apple-system, "Segoe UI", sans-serif'
    fontSize: 13px
    fontWeight: '400'
    lineHeight: '1.5'
  overline:
    fontFamily: 'ui-monospace, "Cascadia Mono", Consolas, monospace'
    fontSize: 11px
    fontWeight: '700'
    lineHeight: '1.4'
    letterSpacing: 0.1em
  data:
    fontFamily: 'ui-monospace, "Cascadia Mono", Consolas, monospace'
    fontSize: 13px
    fontWeight: '400'
    lineHeight: '1.45'
  action-name:
    fontFamily: 'ui-monospace, "Cascadia Mono", Consolas, monospace'
    fontSize: 20px
    fontWeight: '700'
    lineHeight: '1.2'
rounded:
  sm: 8px
  md: 12px
  lg: 20px
  xl: 28px
  full: 9999px
spacing:
  '1': 4px
  '2': 8px
  '3': 12px
  '4': 16px
  '5': 20px
  '6': 24px
  gutter-mobile: 16px
  gutter-desktop: 20px
  content-max: 1240px
  timeline-width: 330px
components:
  button-primary:
    background: '{colors.accent}'
    foreground: '{colors.accent-ink}'
    radius: '{rounded.md}'
    minHeight: 36px
  button-secondary:
    background: '{colors.surface}'
    foreground: '{colors.ink}'
    border: '1px solid {colors.line}'
    radius: '{rounded.md}'
  button-danger:
    background: '{colors.danger}'
    foreground: '#FFFFFF'
    radius: '{rounded.md}'
  state-chip:
    radius: '{rounded.full}'
    border: '1px solid currentColor'
    typography: '{typography.body-small}'
  state-banner:
    radius: '{rounded.lg}'
    border: '1px solid currentColor'
  evidence-card:
    background: '{colors.surface}'
    borderLeft: '4px solid {colors.fact}'
    radius: '{rounded.md}'
  interpretation-card:
    background: '{colors.surface}'
    border: '1px dashed {colors.interpretation}'
    radius: '{rounded.lg}'
  evidence-chip:
    background: '{colors.fact-soft}'
    foreground: '{colors.fact}'
    radius: '{rounded.sm}'
    typography: '{typography.data}'
  dossier:
    background: '{colors.surface}'
    border: '2px solid {colors.attention}'
    radius: '{rounded.lg}'
  next-step:
    background: '{colors.accent-soft}'
    radius: '{rounded.md}'
  label-tag:
    background: '{colors.accent-soft}'
    foreground: '{colors.accent}'
    radius: '{rounded.sm}'
    typography: '{typography.overline}'
  approval-dialog:
    background: '{colors.surface}'
    radius: '{rounded.xl}'
    maxWidth: 640px
---

> **Revised by feature 014 (2026-10-31).** The console now uses soft raised and inset surfaces, liquid-glass
> layers for what floats, and a light and dark theme the Operator can switch. The color values above are the
> ones shipped in `ui/src/styles/tokens.css`, which is the source of truth. Sections marked
> **Superseded by 014** replace the 2026-10-20 text. See `specs/014-liquid-console-redesign/`.

## Brand & Style

Signal Noir is an operations console, not a chat product. Its premise is that a failure becomes a **verifiable decision**: the operator can see what failed, which facts support the proposal, exactly what will change, and what was confirmed. The visual system serves that premise. It is calm, dense enough for an operator's working day, and strict about one distinction above all: **observed facts look different from interpretation**.

The palette comes from the team's decision notebook of 19/10 and was tested in the throwaway prototype (`../prototype-signal-noir/`): warm paper, dark teal-ink text, one teal accent for "act here", and semantic colors that each carry exactly one meaning. There is no logo work and no illustration; the brand is the lowercase wordmark `signal noir.` with an accent-colored period.

## Colors

Every semantic color answers a single question. If a color appears, the operator should be able to say why without a legend.

- **Paper / surface / surface-raised (`{colors.paper}`, `{colors.surface}`, `{colors.surface-raised}`)**: background layers. Paper is the page, surface holds cards, surface-raised holds secondary blocks inside a card (effect statement, panels).
- **Ink / ink-muted / line**: text, secondary text, separators. `{colors.ink-muted}` is for metadata only (times, IDs, "by agent"), never for anything the operator must act on.
- **Accent (`{colors.accent}`)**: "act here". Primary buttons, current navigation, layer numbers, the next-step box. Never used for state.
- **Fact (`{colors.fact}`)**: observed evidence. The left border of evidence cards, the `FACT` tag, evidence chips inside claims. Also the `info` tone for in-flight states (Investigating, Approved, Executing).
- **Interpretation (`{colors.interpretation}`)**: the agent's or rules' reading of the facts. The dashed border of the diagnosis card and the `INTERPRETATION` tag. The same hue marks **outcome unknown** (`reconciling`), because both mean "not established as fact".
- **Attention (`{colors.attention}`)**: something waits for the operator (PendingApproval, ReviewRequired, Rejected), evidence conflicts, the dossier border.
- **Hold (`{colors.hold}`)**: Held. Deliberately muted and earthy, so it does not compete with attention: nothing is asked of the operator yet.
- **Success (`{colors.success}`)**: Resolved and ResolvedByPriorReceipt, passed checks, receipts, high confidence.
- **Danger (`{colors.danger}`)**: failed checks, validator blocks, server refusals, Failed, low confidence. Never decorative.
- **Focus (`{colors.focus}`)**: keyboard focus ring and the brief highlight when an evidence chip jumps to its evidence.

Each color has a `-dark` twin, defined once with it as `light-dark(light, dark)` in `tokens.css`; the same meaning maps to the same role in both themes.

**Theme (014, replaces "dark mode follows `prefers-color-scheme`").** The console starts in the system preference and follows it live. A switch in the top bar changes the theme; the choice is kept in the browser (`signalnoir.theme`) and wins over the system. The theme is applied before first paint. Every state, message and view is designed in both themes, and the contrast pairs are tested (`ui/tests/tokens-contrast.test.ts`): text 4.5:1, boundaries and the focus ring 3:1.

## Typography

System fonts only: the SPA is served by IRIS and must work offline, so no webfonts. Two families with distinct jobs:

- **Sans (`{typography.body}`)** for everything a person reads: titles, banners, diagnosis text, dossier prose.
- **Mono (`{typography.data}`)** for everything that is an identifier or a literal value: case and proposal IDs, action names, exam codes, idempotency keys, HTTP statuses, precondition names, raw bodies. Mono means "this is exactly what the system has". The action name in the proposal card uses `{typography.action-name}`, so the verb is the first thing the eye lands on.
- **Overline (`{typography.overline}`)** for small uppercase labels (`FACT`, `SYNTHETIC`, section eyebrows).

Times show in BRT on screen (`HH:MM:SS BRT`); the API stays in UTC.

## Layout & Spacing

A 4-px base scale (`{spacing.1}` to `{spacing.6}`). Content is capped at `{spacing.content-max}`.

- **Shell (014)**: a side rail at 1100 px and up (Cases only: no entry for a screen that does not exist), a compact top bar below. Touch targets are at least 44 px.
- **Case list**: one row per case, a fixed grid of state, order and last exception, partner, proposal, age. Below 1100 px partner and labels drop; below 640 px each row becomes a stacked card.
- **Case detail**: two columns above 1100 px: the six numbered layers on the left and the timeline (`{spacing.timeline-width}`) on the right, sticky. Below 1100 px the timeline moves under the layers. The grid column is `minmax(0, 1fr)` so wide tables scroll inside their own container and never widen the page.
- **Gutters**: `{spacing.gutter-desktop}` on desktop, `{spacing.gutter-mobile}` on phones. No horizontal page scroll at 360 px.

## Elevation & Depth

**Superseded by 014.** The 2026-10-20 text said "Flat... shadows only on overlays". The console now has five levels, all from tokens:

- **e1** flat: a border only.
- **e2** hover and small controls: a soft paired shadow (dark below and right, light above and left).
- **e3** raised: layers, cards, rows.
- **e4** modal: the approval dialog.
- **e5** popover and toast.
- **Inset**: inputs, the segmented filter and wells.

Floating layers (rail or top bar, dialog, toasts, connection note) are **liquid glass**: a translucent fill, a background blur and a 1 px light edge. Everything the Operator reads to decide (Evidence, Diagnosis, Proposal, Dossier) sits on **opaque** surfaces. Shadows are never the only boundary: every control also has a 3:1 border (`--line-strong`). Without blur support, with reduced transparency, in forced colors or in print, glass becomes opaque and shadows disappear.

## Shapes

**Superseded by 014.** Radii are `{rounded.sm}` 8 px for tags and small chips, `{rounded.md}` 12 px for buttons, inputs and evidence cards, `{rounded.lg}` 20 px for layers, banners, rows and the dossier, `{rounded.xl}` 28 px for the dialog. **The pill (`{rounded.full}`) is still only for Case state chips; buttons are not pills**, so a pill still means "case state".

## Components

- **State chip**: pill with a glyph, a human label and the raw enum in its tooltip. Tone = the semantic color of the state (see EXPERIENCE.md, State Patterns). The glyph makes the state readable without color.
- **State banner**: full-width, under the case header, tinted with the state's tone, a circular glyph, one sentence, and at most one primary action. It is the single place that tells the operator what is happening and what, if anything, they must do.
- **Evidence card**: `{components.evidence-card}`, with a `FACT` tag, source name, who called it, time, duration and ID; the query; the raw result as a key/value list. Obsolete evidence fades to 60% opacity with an "obsoleted by" tag; it is never removed.
- **Conflict block**: attention-tinted box above the evidence list, with the two conflicting results side by side.
- **Interpretation card**: `{components.interpretation-card}` holding the diagnosis summary, the claims (each ending in evidence chips) and the hypotheses (chosen in success tone, discarded in muted).
- **Proposal card**: action name in `{typography.action-name}`, plain-language action text, confidence badge (success/attention/danger for High/Medium/Low), the **effect statement** on surface-raised, preconditions re-checked before sending, validator verdict, and collapsed versions and metrics.
- **Approval dialog**: `{components.approval-dialog}`; effect statement, field diff table (changed row in accent-soft), proposal ID and case version, preconditions, validity, declared-name field, and the actions.
- **Dossier**: `{components.dossier}`; reason, "what was checked", "what we don't know", colliding records (divergent cells in attention-soft with a `≠` marker), next-step box (`{components.next-step}`), and the resolution form.
- **Revalidation table**: one row per precondition with expected, observed and result; a failed row is danger-soft.
- **Timeline**: compact list, newest first: seq, time (mono, muted), event type (state changes in accent, blocks in attention), actor, one-line summary.
- **Label tags**: `SYNTHETIC` on every case, `REPLAY` when applicable.

## Do's and Don'ts

| Do | Don't |
|---|---|
| Keep facts in fact blue and interpretation in violet everywhere | Put agent text inside an evidence card, or raw data inside the diagnosis |
| Show identifiers, codes and actions in mono | Paraphrase an action name or an exam code in prose only |
| Give every state a glyph and a label, not just a color | Rely on color alone to show state, conflict or failure |
| Use danger only for a real refusal, failure or block | Use red for emphasis or for "important" |
| Let wide tables scroll inside their container | Let any element widen the page at 360 px |
| Mark synthetic data on every case | Show any data without its `SYNTHETIC` label |
