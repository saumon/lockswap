# Implementation Plan: Looping Logo Fade Animation

**Branch**: `011-logo-fade-loop` | **Date**: 2026-09-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/011-logo-fade-loop/spec.md`

## Summary

The sign-in/sign-up logo currently fades in once (`brand-fade-in`, `1 both`) and then sits static; the header's 32px logo has no animation at all today. This feature adds a second, continuously looping opacity pulse (100% ↔ ~60%, ~3s per cycle) to both places: on the sign-in/sign-up mark it starts only after the existing one-shot entrance finishes (chained via `animation-delay`), and on the header mark it runs from first paint since there is no entrance there. The pulse is CSS-only (`opacity` alone, no layout/paint properties), scoped inside the codebase's existing `@media (prefers-reduced-motion: no-preference)` block so it disappears entirely for reduced-motion users, consistent with how every other animation on the site is gated. No JavaScript, no data, and no new dependencies are needed.

The change reverses a previously deliberate, explicitly-tested design decision ("the flourish must play once, never loop" / "the header mark does not fade" in `test/system/motion_test.rb`), and exposes a latent scoping issue in the shared `wait_for_entrance` test helper that assumes no animation on the page ever runs indefinitely. Both are addressed as part of this plan's scope, not deferred, because leaving either unresolved would either leave a contradicted test in the suite or silently make every `assert_axe_clean` call pay a 5s timeout across the system suite.

## Technical Context

**Language/Version**: Ruby 3.4.6, Rails 8.1.3

**Primary Dependencies**: `tailwindcss-rails` (Tailwind v4, `@theme`/`@layer` authoring in `app/assets/tailwind/application.css`), `turbo-rails` / `stimulus-rails` via importmap — this feature needs none of the JS stack, it is pure CSS plus two ERB partial edits.

**Storage**: N/A — no persisted state.

**Testing**: Minitest + Capybara system tests on Selenium headless Chrome (`test/system/motion_test.rb` and friends), `axe-core` accessibility audits via `assert_axe_clean`.

**Target Platform**: Server-rendered web app, evergreen desktop/mobile browsers.

**Project Type**: Single Rails application (no separate frontend/backend split).

**Performance Goals**: No numeric target beyond "does not visibly jank" — the animation only touches `opacity`, which is compositor-only and does not trigger layout or paint, consistent with the stylesheet's existing transform/opacity-only convention (see `research.md` D4).

**Constraints**: Must stay within the codebase's existing motion conventions — reduced-motion must fully suppress it (FR-007), it must not alter layout (FR-008), and it must not regress the accessibility audit's runtime (see `research.md` D7 for a pre-existing test-helper scoping issue this feature exposes).

**Scale/Scope**: Two shared view partials, one shared stylesheet, one system test file, one system-test-case helper — no new files needed in `app/`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Code Quality** — PASS. The change extends an existing, documented pattern (the `flourish` local on `_brand_mark.html.erb`) with a sibling `pulse` local rather than inventing a new mechanism; no new abstraction, no duplicated logic. Public partial locals gain doc-comment updates in place, matching the file's existing convention.
- **II. Testing Standards (NON-NEGOTIABLE)** — PASS, conditioned on scope staying in this plan. Two existing assertions in `test/system/motion_test.rb` currently encode the behavior this feature reverses ("the flourish must play once, never loop", "the header mark does not fade") and must be rewritten, not silently deleted or left failing. New assertions are required for: the pulse looping indefinitely on both surfaces, the 60%/3s values, the entrance-then-loop hand-off, and reduced-motion suppression. This is tracked as required work, not an open question — see `research.md` D8.
- **III. User Experience Consistency** — PASS, with an explicit callout obligation. This is a breaking change to previously documented and tested motion behavior, so per this principle the pull request MUST call it out explicitly rather than treating it as an incidental tweak. The implementation reuses the existing brand-mark/brand-lockup components and the existing reduced-motion mechanism rather than introducing a new pattern.
- **IV. Performance Requirements** — PASS, conditioned on scope staying in this plan. The animation itself is free (opacity-only, GPU-composited, decorative). Its indirect effect on `wait_for_entrance` (used by every `assert_axe_clean` call) is a real regression risk to CI runtime that must be fixed alongside the feature, not left for later — see `research.md` D7.

No principle is violated in a way that requires a documented exception; the Complexity Tracking table below is empty.

## Project Structure

### Documentation (this feature)

```text
specs/011-logo-fade-loop/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── assets/
│   └── tailwind/
│       └── application.css        # new @keyframes brand-fade-pulse, .brand-mark-loop,
│                                   # compound .brand-mark-flourish.brand-mark-loop rule,
│                                   # new --motion-brand-loop token
└── views/
    └── shared/
        ├── _brand_mark.html.erb     # new `pulse` local, sibling to the existing `flourish` local
        ├── _brand_lockup.html.erb   # passes pulse: true to the 32px header mark
        └── _brand_stacked.html.erb  # adds brand-mark-loop alongside brand-mark-flourish

test/
├── application_system_test_case.rb  # wait_for_entrance narrowed to the entrance element's
│                                     # own animations (research.md D7)
└── system/
    └── motion_test.rb               # rewrites the two now-contradicted assertions, adds
                                      # coverage for the loop on both surfaces and its
                                      # reduced-motion suppression
```

**Structure Decision**: No new top-level directories. This is a small, purely presentational change confined to the existing shared brand partials, the single stylesheet, and the existing motion system test file — the same three files the original brand-flourish work (feature 008) touched, extended in place.

## Complexity Tracking

*No entries — no Constitution Check gate was violated in a way requiring justification.*
