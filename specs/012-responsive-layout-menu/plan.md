# Implementation Plan: Responsive Site Layout and Signed-In Menu

**Branch**: `feature/012-responsive-layout-menu` | **Date**: 2026-09-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/012-responsive-layout-menu/spec.md`

## Summary

Make every screen work from 320 CSS pixels upward, and give the signed-in menu
two forms around a single breakpoint at **48rem (768px)**: a `<details>`
disclosure with a toggle below it, the current full bar at and above it.

The approach is deliberately narrow in surface area. One breakpoint, declared
once. The menu is rendered **once** and neutralised into a plain row on wide
screens by CSS, so no control exists twice ([research R1](./research.md#r1--rendering-one-menu-that-is-a-disclosure-below-48rem-and-a-plain-bar-above)).
The two data tables keep their `<table>` markup and gain `data-label` attributes
plus explicit ARIA roles, so the same rows render as labelled stacked cards below
the breakpoint without a second rendering path ([R2](./research.md#r2--restacking-the-two-tables-as-cards-without-losing-table-semantics)).
Touch targets rise to 44px inside the narrow-width block only, leaving desktop
density untouched ([R3](./research.md#r3--meeting-the-44px-touch-target-floor-below-the-breakpoint)).
Verification comes from a CDP viewport helper that mirrors the `execute_cdp`
pattern the test case already uses for reduced motion ([R4](./research.md#r4--driving-the-test-suite-at-two-viewport-widths)).

Almost all of this is CSS. The only new JavaScript is a small Stimulus
controller that adds Escape and outside-click dismissal on top of a menu that
already opens and closes without it.

## Technical Context

**Language/Version**: Ruby 3.4.6, Rails 8.1.3.1

**Primary Dependencies**: Propshaft 1.3.2 (assets), tailwindcss-rails 4.6.0
(Tailwind v4, `@theme` + `@layer components`), stimulus-rails 1.3.4,
turbo-rails 2.0.23, Devise (auth)

**Storage**: N/A for this feature — no schema change, no new query, no model
change. The feature is presentation and navigation only.

**Testing**: Minitest; system tests via `ActionDispatch::SystemTestCase` driven
by Selenium headless Chrome; `axe-core-api` for accessibility, wired into
`assert_axe_clean` and already run against every screen

**Target Platform**: Server-rendered web, current evergreen browsers on iOS,
Android, macOS and Windows

**Project Type**: Rails monolith with server-rendered ERB views. No separate
frontend build beyond the Tailwind CLI.

**Performance Goals**: No new runtime cost on any request path — the change is
stylesheet and markup attributes. The measurable cost is CI time: the system
suite runs `parallelize(workers: 1)`, so the added two-width sweep is budgeted
explicitly (see Constitution Check, Principle IV).

**Constraints**: Single breakpoint at 48rem (768px), applied site-wide
(FR-018). Menu must open and close with no script (FR-010b). No desktop
regression (FR-020). Existing accessibility posture is a floor, not a target
(FR-024). All colour, spacing, type and motion values must come from the
existing `@theme` tokens — a raw hex in a template is already a defect in this
codebase.

**Scale/Scope**: 6 screens (sign-in, sign-up, account edit, homepage, locker
wishes, proposal history), 1 layout, 2 data lists, ~10 view/partial files,
1 stylesheet, 1 new Stimulus controller, 4 test files.

## Constitution Check

*GATE: evaluated before Phase 0, re-evaluated after Phase 1 design. Both passes
recorded below.*

### I. Code Quality — **PASS**

| Rule | How this plan satisfies it |
|---|---|
| Lint/static analysis clean | Only ERB, CSS and one JS file change; `bin/rubocop` covers the Ruby side, `bin/importmap audit` the JS. No suppressions planned. |
| Single responsibility, no duplication | R1 and R2 were both decided *specifically* to avoid a second rendering path. One menu, one row renderer. |
| Public interfaces documented | Every new CSS block and partial carries a comment naming the requirement it serves, matching the surrounding density. The class-name and DOM contracts are written down in [contracts/](./contracts/). |

### II. Testing Standards (NON-NEGOTIABLE) — **PASS**

| Rule | How this plan satisfies it |
|---|---|
| Tests fail without the change | Each responsive assertion fails against today's stylesheet: there are no width-based rules today beyond one `.detail-grid` query, so overflow, menu-treatment and card-form checks all fail first. |
| Full suite in CI, failure blocks merge | `.github/workflows/ci.yml` runs system tests on every PR in a dedicated `system-test` job (`bin/rails test:system`), separate from the unit `test` job. Note that the local `bin/ci` convenience script leaves system tests commented out — CI is the gate, `bin/ci` is not sufficient on its own for this feature. |
| Deterministic | The CDP viewport override is exact and cleared in `teardown`, following the established `emulate_reduced_motion` precedent; no sleeps, no retries. |
| Coverage must not regress below `dev` | Net new tests only; nothing is deleted. The one criterion being *removed* (the old SC-005 user study) was never executable, and is replaced by four automated requirements (FR-022–FR-025). |

### III. User Experience Consistency — **PASS**

| Rule | How this plan satisfies it |
|---|---|
| Reuse existing patterns | `<details>` is already the site's disclosure in three features. `.data-table`, `.card`, `.btn`, `--spacing-*` and `--color-*` are all reused. The one genuinely new component is the menu toggle. |
| Consistent messages | No user-facing copy changes. FR-005e explicitly holds the empty states identical across both list forms. |
| Accessibility verified before merge | Stronger than the baseline: `assert_axe_clean` now also runs at the phone width and with the panel open (FR-024), and keyboard operability is asserted at both widths (FR-023). |
| Breaking changes called out | The menu gains a toggle below 768px — a visible change for anyone on a narrow window. Flagged for the PR description. |

### IV. Performance Requirements — **PASS, with a recorded cost**

| Rule | How this plan satisfies it |
|---|---|
| Before/after measurement on sensitive paths | No request-path, query or transaction change: nothing to measure server-side. |
| No unexplained regression | The real cost is **CI wall-clock**. The system suite is single-worker by deliberate decision in feature 003. Running every existing system test twice would roughly double it. |
| Mitigation | Only the *sweep* checks (overflow, axe, menu treatment, list form) run at both widths. Existing behavioural tests stay at their current width; new narrow-width behavioural tests are added only for genuinely width-specific behaviour (the panel, the card restack). Expected addition is a single-digit number of new browser sessions, not a doubling. |
| Where the cost lands | The `system-test` job runs on its own runner, in parallel with the unit `test` job, so the added time extends that job's wall-clock but not the unit suite's. Record the before/after `system-test` job duration in the PR. |
| Animation discipline | The stylesheet's Motion section already restricts animation to transform and opacity. Any panel transition obeys it, and the global `prefers-reduced-motion` block covers FR-016 with no new code. |

### Post-Phase-1 re-evaluation — **PASS, unchanged**

The Phase 1 design introduced no new dependency, no new data, and no new
request path. The two identified risks (R1's `::details-content` support, R2's
axe verdict on the restacked table) are both **detected by gates this plan
already requires**, and each has a documented fallback that stays inside the
same principles. No entry is needed in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/012-responsive-layout-menu/
├── plan.md              # This file
├── spec.md              # Feature specification (6 clarifications resolved)
├── research.md          # Phase 0 — R1..R4
├── data-model.md        # Phase 1 — presentational state, no persisted data
├── quickstart.md        # Phase 1 — how to run and validate
├── contracts/
│   ├── menu-dom.md      # DOM + ARIA contract for the signed-in menu
│   ├── list-forms.md    # table ⇄ card contract for the two data lists
│   └── breakpoint.md    # the single breakpoint and the narrow/wide contract
├── checklists/
│   └── requirements.md  # Spec quality checklist (16/16)
└── tasks.md             # Phase 2 — created by /speckit-tasks, NOT by this command
```

### Source Code (repository root)

```text
app/
├── assets/tailwind/
│   └── application.css                     # breakpoint token; menu, card-form,
│                                           # touch-target and detail-grid rules
├── javascript/controllers/
│   ├── index.js                            # register the new controller
│   └── site_menu_controller.js             # NEW — Escape + outside-click only
└── views/
    ├── layouts/
    │   └── application.html.erb            # header renders the menu partial
    ├── shared/
    │   └── _site_menu.html.erb             # NEW — the one menu, both forms
    ├── locker_wishes/
    │   └── _locker_wish_list.html.erb      # data-label + explicit roles
    └── locker_swap_proposals/
        └── index.html.erb                  # data-label + explicit roles

test/
├── application_system_test_case.rb         # with_viewport helper + teardown
└── system/
    ├── responsive_test.rb                  # NEW — the two-width sweep
    ├── site_menu_test.rb                   # NEW — panel behaviour, no-script
    ├── navigation_test.rb                  # extended for the wide-width bar
    └── accessibility_test.rb               # extended for phone width + panel
```

**Structure Decision**: Standard Rails monolith layout, unchanged. This feature
adds two files (`_site_menu.html.erb`, `site_menu_controller.js`) and two test
files; everything else is an edit to a file that already exists. No new
directory, no new layer, no new dependency.

## Implementation Approach

Ordered so that the two identified risks are resolved before anything is built
on top of them.

### Stage 1 — Prove the two mechanisms (risk first)

1. Add the `with_viewport` CDP helper and its teardown to
   `ApplicationSystemTestCase`; prove it by asserting that a known width
   produces a known `matchMedia` result.
2. Write the failing test for R1's desktop neutralisation: at 1400px the menu
   toggle is absent and the destinations are present. This is the
   `::details-content` spike — it either passes with the two declarations or the
   R1 fallback is adopted immediately, at a cost of one partial.

### Stage 2 — The breakpoint and the menu (User Story 1, P1)

3. Declare the breakpoint once and move the existing `.detail-grid` rule from
   40rem to 48rem (FR-018a).
4. Extract the header's signed-in block into `shared/_site_menu.html.erb` as a
   `<details>` with a summary toggle and a panel.
5. Style both forms; hide the toggle and force the panel open above 48rem.
6. Add `site_menu_controller.js` for Escape and outside-click dismissal, and for
   leaving the panel closed after a Turbo navigation (FR-010c).
7. Raise touch targets inside the narrow-width block (FR-007, FR-007b).

### Stage 3 — The two lists (User Story 2, P2)

8. Add `data-label` attributes and explicit ARIA roles to both tables.
9. Add the narrow-width card-form rules to `.data-table`.
10. Run axe at phone width against both list screens — the R2 gate. Adopt the
    R2 fallback here if it objects.

### Stage 4 — The remaining screens and the sweep (User Story 2 & 3)

11. Audit homepage, account edit, sign-in and sign-up at 320px and 390px; fix
    overflow, stacking and form reachability (FR-002, FR-003, FR-004, FR-008).
12. Write the two-width sweep: overflow at 320/390/1400, axe at both widths
    including with the panel open, keyboard reachability, and the touch-target
    measurement (FR-022–FR-025).

### Stage 5 — Non-regression

13. Confirm the existing suite is green at the original width, and that the
    desktop rendering of every screen is unchanged (FR-020, SC-007).

## Deferred to manual verification

Recorded in the spec's checklist and repeated here so `/speckit-tasks` does not
try to automate them:

- **FR-008** (forms usable with the on-screen keyboard open) — headless Chrome
  has no soft keyboard. Verify on a real device; note the result in the PR.
- **SC-008** (200% text zoom at desktop width) — outside the FR-022 viewport
  matrix. Verify by hand at 200% zoom.

## Complexity Tracking

> No Constitution Check violations. This section is intentionally empty.
