# Implementation Plan: Compact floor/locker label alignment

**Branch**: `022-align-floor-widgets` | **Date**: 2026-09-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/022-align-floor-widgets/spec.md`

## Summary

Three small display fixes to compact the homepage: (1) inline the floor number
into the "Looking for a locker on floor" sentence in the "Your locker search"
section (`home/_locker_wish.html.erb` and `locker_wishes/_locker_wish_panel.html.erb`),
(2) on mobile, put each "Your locker" field's label and value on one line instead
of stacked (`home/_locker_profile.html.erb`, via the shared `.detail-grid` /
`.detail-term` / `.detail-value` rules in `application.css`), and (3) drop the
card border/background from the "Your locker" block specifically on the
homepage (`home/index.html.erb` / `home/_locker_profile.html.erb`), while every
other homepage card keeps its current treatment. No new dependencies, no data
model changes, no new routes — this is a Tailwind CSS + ERB markup change
inside the existing view layer.

## Technical Context

**Language/Version**: Ruby 3.4.6, Rails 8.1

**Primary Dependencies**: `tailwindcss-rails` (compiled from
`app/assets/tailwind/application.css`), `turbo-rails` / `stimulus-rails`
(unchanged — no new JS behavior needed), ERB views

**Storage**: N/A — no persisted data changes; floor/locker number values are
already read from `current_user` / `current_user.locker_wish`

**Testing**: Minitest system tests (Capybara + Selenium, `test/system/`),
`test/stylesheet_breakpoint_test.rb` (enforces the single 48rem breakpoint),
`rubocop-rails-omakase` lint

**Target Platform**: Web (Rails monolith), responsive at the site's one
breakpoint (48rem / 47.999rem)

**Project Type**: Single Rails web application (no frontend/backend split)

**Performance Goals**: N/A — pure markup/CSS layout change on an
already-rendered page; no new queries, network calls, or loops

**Constraints**: Must follow the LockSwap design contract in `CLAUDE.md`: no
raw hex in templates, one definition per component (reuse `.detail-grid` /
`.detail-term` / `.detail-value` rather than inventing a second label+value
pattern), no new width value in a media query beyond the existing 48rem, never
remove a focus outline, keep the swap-axis meaning of card hinges intact where
cards remain

**Scale/Scope**: 4 view/partial files + 1 stylesheet (`application.css`); no
new routes, controllers, or models. Existing system tests
(`homepage_locker_wish_test.rb`, `locker_profile_test.rb`, `responsive_test.rb`,
`motion_test.rb`) assert against element IDs that are unaffected, but need new
assertions for the changed layout/markup.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Code Quality**: PASS. The plan reuses the existing `.detail-grid` /
  `.detail-term` / `.detail-value` component rather than adding a second
  label+value pattern (avoids duplicated logic per Principle I). No new
  public interface is introduced.
- **II. Testing Standards (NON-NEGOTIABLE)**: PASS, contingent on adding
  system-test coverage for all three visible changes (inline floor sentence,
  mobile inline label/value, no-card "Your locker" on the homepage) before
  merge — tracked in Phase 1 / tasks. Existing ID-based assertions
  (`#locker-profile-floor`, etc.) are preserved so current tests keep passing.
- **III. User Experience Consistency**: PASS. Reuses established visual
  vocabulary (`.detail-grid` pattern, existing card system) rather than
  introducing new UI patterns; the "Your locker" heading text continues to
  identify the block as the user's own, per the spec's Assumptions, so no new
  visual affordance is required. Accessibility: `dt`/`dd` semantics and DOM
  reading order are preserved — only visual layout (CSS) changes, not the
  underlying announced structure.
- **IV. Performance Requirements**: PASS — not applicable. No performance-
  sensitive path (swap/lock execution, queries, network calls) is touched.

No violations. Complexity Tracking is not needed.

## Project Structure

### Documentation (this feature)

```text
specs/022-align-floor-widgets/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output — N/A, documented as not applicable
├── quickstart.md         # Phase 1 output (/speckit-plan command)
├── contracts/            # Phase 1 output — N/A, documented as not applicable
└── tasks.md              # Phase 2 output (/speckit-tasks command — NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── assets/
│   └── tailwind/
│       └── application.css        # .detail-grid/.detail-term/.detail-value tweaks;
│                                   # new (or adjusted) rule for the card-less
│                                   # "Your locker" homepage presentation
└── views/
    ├── home/
    │   ├── _locker_wish.html.erb   # inline floor number in the sentence
    │   └── _locker_profile.html.erb # inline label+value on mobile;
    │                                # root element loses .card/.card--you
    │                                # (its one call site is home/index.html.erb,
    │                                # so no rendering-flag is needed — see research.md §3)
    └── locker_wishes/
        └── _locker_wish_panel.html.erb  # inline floor number in the sentence
                                          # (standalone locker wishes page)

test/
└── system/
    ├── homepage_locker_wish_test.rb  # add/adjust assertions for inline floor sentence
    ├── locker_profile_test.rb        # add/adjust assertions for mobile inline layout
    └── responsive_test.rb            # (or a new throwaway/permanent test) for the
                                       # card-less "Your locker" homepage presentation
```

**Structure Decision**: Single Rails application — this feature only touches
the existing `app/views` (ERB) and `app/assets/tailwind` (CSS) layers plus
their `test/system` coverage. No new directories, services, or projects are
introduced.

## Complexity Tracking

*No Constitution Check violations — this section is not applicable.*
