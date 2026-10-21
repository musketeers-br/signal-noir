---
name: Signal Noir
description: Operator console for resolving interoperability exceptions with an AI agent under deterministic governance. Svelte 5 SPA served statically by IRIS; no component library, so this file is the whole visual system.
status: final
updated: 2026-10-20
colors:
  paper: '#F4F2EC'
  surface: '#FFFEFB'
  surface-raised: '#F7F6F1'
  ink: '#172C32'
  ink-muted: '#56686E'
  line: '#D7DFDC'
  code-bg: '#EEF1EF'
  accent: '#006E65'
  accent-ink: '#FFFFFF'
  accent-soft: '#E3F1EB'
  fact: '#285BB0'
  fact-soft: '#E9EFFB'
  interpretation: '#6B3FA0'
  interpretation-soft: '#F1EAFA'
  attention: '#8A4D09'
  attention-soft: '#FFF0D8'
  hold: '#6A5A2E'
  hold-soft: '#F1ECDC'
  success: '#1F6F3A'
  success-soft: '#E2F2E7'
  danger: '#A03535'
  danger-soft: '#FBEAEA'
  focus: '#C57D12'
  paper-dark: '#0F1A1D'
  surface-dark: '#16252A'
  surface-raised-dark: '#1B2D32'
  ink-dark: '#E5EEEC'
  ink-muted-dark: '#9FB1B2'
  line-dark: '#2B4046'
  code-bg-dark: '#1F3338'
  accent-dark: '#3FB8A9'
  accent-ink-dark: '#062320'
  accent-soft-dark: '#173A37'
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
  sm: 4px
  md: 8px
  lg: 12px
  xl: 14px
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

Each color has a `-dark` twin. Dark mode follows `prefers-color-scheme`; the same meaning maps to the same role.

## Typography

System fonts only: the SPA is served by IRIS and must work offline, so no webfonts. Two families with distinct jobs:

- **Sans (`{typography.body}`)** for everything a person reads: titles, banners, diagnosis text, dossier prose.
- **Mono (`{typography.data}`)** for everything that is an identifier or a literal value: case and proposal IDs, action names, exam codes, idempotency keys, HTTP statuses, precondition names, raw bodies. Mono means "this is exactly what the system has". The action name in the proposal card uses `{typography.action-name}`, so the verb is the first thing the eye lands on.
- **Overline (`{typography.overline}`)** for small uppercase labels (`FACT`, `SYNTHETIC`, section eyebrows).

Times show in BRT on screen (`HH:MM:SS BRT`); the API stays in UTC.

## Layout & Spacing

A 4-px base scale (`{spacing.1}` to `{spacing.6}`). Content is capped at `{spacing.content-max}`.

- **Case list**: one row per case, a fixed grid of state, order and last exception, partner, proposal, age. Below 1100 px partner and labels drop; below 640 px each row becomes a stacked card.
- **Case detail**: two columns above 1100 px: the six numbered layers on the left and the timeline (`{spacing.timeline-width}`) on the right, sticky. Below 1100 px the timeline moves under the layers. The grid column is `minmax(0, 1fr)` so wide tables scroll inside their own container and never widen the page.
- **Gutters**: `{spacing.gutter-desktop}` on desktop, `{spacing.gutter-mobile}` on phones. No horizontal page scroll at 360 px.

## Elevation & Depth

Flat. Hierarchy comes from borders and the semantic left-border, not shadows. Shadows exist only on overlays that sit above the page: the approval dialog (with a dark backdrop) and toasts.

## Shapes

`{rounded.sm}` for tags and chips, `{rounded.md}` for buttons, inputs and evidence cards, `{rounded.lg}` for cards, banners and the dossier, `{rounded.xl}` for the dialog. `{rounded.full}` only for state chips, so a pill always means "case state".

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
