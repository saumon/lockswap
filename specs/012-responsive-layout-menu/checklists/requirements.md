# Specification Quality Checklist: Responsive Site Layout and Signed-In Menu

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-15
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

## Notes

- **Iteration 1 (2026-09-15)**: One open item — FR-010 carried a
  [NEEDS CLARIFICATION] marker on the mobile menu pattern, the one decision with
  genuinely different implications for scope and UX. Everything else was resolved
  with documented defaults in the Assumptions section.
- **Iteration 2 (2026-09-15)**: Resolved. The user selected the collapsed toggle
  panel ("hamburger"). FR-010 was rewritten into FR-010 / FR-010a / FR-010b /
  FR-010c, and FR-015 / FR-016 / FR-017 were changed from conditional ("if the
  menu has a collapsed state") to unconditional obligations. User Story 1's
  narrative and acceptance scenarios, and four edge cases, were updated to match;
  an edge case for crossing the breakpoint while the panel is open was added.
  No [NEEDS CLARIFICATION] markers remain — all checklist items pass.
- **Iteration 3 (2026-09-15, `/speckit-clarify`)**: Five questions asked and
  answered; all 16 items re-validated and all 16 still pass (16/16 → 16/16, no
  state changes, no regressions). Resolved: the mobile table treatment
  (FR-005 → FR-005a–e), touch-target scope (FR-007 → FR-007a–c), the
  verification method (SC-005 rewritten, new FR-022–FR-025), the breakpoint
  value (FR-018 → FR-018a–b), and the no-script baseline (FR-010b →
  FR-010b-i/ii). A terminology pass moved the normative requirements onto
  "below / at and above the breakpoint" and a glossary note was added to
  Assumptions.

## Judgment calls recorded

- **"CSS pixels", "rem", "48rem", "390×844"** are units and measurements of the
  viewport, not framework or tooling choices. They are what make FR-007, FR-018
  and FR-022 testable, so they are not counted as implementation detail.
- **"JavaScript" / "script"** appears in one edge case, one assumption and the
  clarification record. This is judged a user-facing browser condition — the
  same category as "reduce motion enabled" or "screen reader in use" — and not
  an implementation choice: no requirement says to *build* anything in a given
  language. The normative requirements (FR-010b and its sub-items) use the
  generic word "script". Item left checked on that basis.
- **WCAG 2.2 SC 2.5.8** is cited only in the clarification Q&A record. FR-007a
  states the inline-link exception in plain language without naming the
  standard, so the requirement itself stays technology-agnostic.
- The earlier note about "40rem (640px)" is superseded: the breakpoint is now
  fixed at 48rem (768px) in FR-018 and the Assumptions section.

## Known limits of the automated matrix

Both are measurable and remain valid criteria; neither is coverable by the
two-width automated suite, so the plan should route them to manual verification
rather than assume the suite catches them:

- **FR-008** (forms usable with the on-screen keyboard open) — a headless
  browser has no on-screen keyboard.
- **SC-008** (200% text zoom on a desktop-width screen) — outside the viewport
  matrix defined in FR-022.

- Spec is ready for `/speckit-plan`.
