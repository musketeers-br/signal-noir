# Specification Quality Checklist: Liquid Console Redesign

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-10-31
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## View coverage (used by SC-001, filled during implementation)

| View or state | Light | Dark | 360 px | 1440 px |
|---|---|---|---|---|
| Top bar or rail, theme control, connection note | [ ] | [ ] | [ ] | [ ] |
| Case list, rows, filters, empty "Needs you" | [ ] | [ ] | [ ] | [ ] |
| Case header, state banner (every state) | [ ] | [ ] | [ ] | [ ] |
| Six layers, "not yet" and "no interpretation" copy | [ ] | [ ] | [ ] | [ ] |
| Evidence cards, conflicts, obsoleted Evidence | [ ] | [ ] | [ ] | [ ] |
| Diagnosis, Proposal, versions and metrics | [ ] | [ ] | [ ] | [ ] |
| Approval and Execution, revalidation table | [ ] | [ ] | [ ] | [ ] |
| Timeline | [ ] | [ ] | [ ] | [ ] |
| Approval dialog (every server answer of 005 FR-010) | [ ] | [ ] | [ ] | [ ] |
| Review Dossier and resolution form | [ ] | [ ] | [ ] | [ ] |
| Toasts, Case not found | [ ] | [ ] | [ ] | [ ] |

## Notes

- This is a visual feature, so the spec names visual behavior (themes, surfaces, bands, contrast
  ratios) but no framework, stylesheet language or build tool. The plan decides those.
- The reference design in `design/` is non-normative. Its known differences from this spec (sample
  data, quick approve, web fonts, summary numbers, extra navigation) are recorded in Assumptions.
- The old UX spine (`DESIGN.md`) conflicts with this feature on elevation, shape and dark mode. The
  conflict is resolved in FR-020 and the last Assumption, not by silent override.
- The redesign adds one browser-side preference (theme). 005 stated the console keeps only the declared
  name in the browser; Key Entities records the addition.
