# Implementation Plan: Streamlined Locker Entry & Pencil-Icon Edit

**Branch**: `009-locker-entry-pencil-edit` | **Date**: 2026-09-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/009-locker-entry-pencil-edit/spec.md`

## Summary

On the first-time "Add your locker details" screen, replace the single always-shown two-field form with two mutually exclusive views — entering a locker (floor + locker number) or a floor-only "I don't have a locker 😔" view — switchable before submission without losing an entered floor. On the homepage's existing "Your locker" card, replace the standalone `<details>` disclosure labeled "Edit locker details" with an icon-only pencil control nested in the card header, keeping the zero-JS `<details>`/`<summary>` accessibility pattern already used in the codebase but with an `aria-label` accessible name in place of visible text. No schema, route, or controller changes: the existing `PATCH /locker_profile` endpoint and its floor-mandatory / locker-uniqueness-per-floor validations are reused unchanged.

## Technical Context

**Language/Version**: Ruby 3.4.6, Rails 8.1.3

**Primary Dependencies**: Hotwire (Turbo Rails + Stimulus Rails), Devise 5.0 (auth, unaffected), tailwindcss-rails (Tailwind CSS v4, utility classes generated on demand), Propshaft asset pipeline, importmap-rails (no bundler/npm)

**Storage**: SQLite3 via Active Record — no schema changes; reuses `users.floor` and `users.locker_number` (added in 002, uniqueness scoped to floor in 006)

**Testing**: Minitest (unit/controller), Capybara + Selenium headless Chrome for system tests, axe-core accessibility audit run on every system test screen (008 FR-028)

**Target Platform**: Server-rendered web app (evergreen desktop/mobile browsers), deployed as a Docker container via Kamal

**Project Type**: Single Rails monolith (server-rendered views, no separate frontend/backend split)

**Performance Goals**: N/A — this is a presentation-only change on an already-fast page; no new queries, no new perf-sensitive path per Constitution Principle IV

**Constraints**:
- Must preserve the existing floor-mandatory and per-floor locker-number-uniqueness validations unchanged (002, 006)
- Must preserve the existing "locked while a swap proposal is active" behavior (005), which replaces the entire edit control with an explanation
- Every touched screen must remain axe-clean (Constitution Principle III; 008 FR-028 precedent)
- Icon-only control must expose an accessible name (FR-009) — no visible-text regression for screen reader users
- Any interactive toggle must tolerate a Turbo Drive preview snapshot mid-navigation, per the documented 008 lesson (`wait_for_turbo` in system tests)

**Scale/Scope**: One screen (`app/views/home/index.html.erb` and its two partials), one small new Stimulus controller, minor Tailwind additions — no new models, migrations, routes, or controllers

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Code Quality**: No new abstractions beyond one small, single-purpose Stimulus controller for the first-entry view toggle. Reuses existing form partial, existing endpoint, existing validations. PASS.
- **II. Testing Standards (NON-NEGOTIABLE)**: `test/system/locker_profile_test.rb` already covers the flows this feature touches (its `open_locker_editor` helper and several assertions reference the disclosure text/summary being replaced) and must be updated; new tests are needed for the "I don't have a locker 😔" toggle and its edge cases (switch back and forth, floor still required, pencil-icon accessible name). PASS, tracked into tasks.
- **III. User Experience Consistency**: Reuses the established `<details>`/`<summary>` disclosure pattern (keyboard/screen-reader support without JS) and the existing `.tile-disclosure` "small, quiet, nested disclosure" visual language already in the stylesheet, rather than inventing a new interaction pattern. Icon carries an `aria-label` accessible name per FR-009. PASS.
- **IV. Performance Requirements**: No perf-sensitive path touched; no before/after measurement required. PASS.

No violations to record in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/009-locker-entry-pencil-edit/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── locker-profile-update.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── views/
│   └── home/
│       ├── index.html.erb              # First-entry vs. saved-profile branching; disclosure removed from here
│       ├── _locker_profile.html.erb    # "Your locker" card — gains the pencil-icon edit control in its header
│       └── _locker_profile_form.html.erb  # Unchanged fields; reused by both the first-entry view and the pencil-icon edit
├── javascript/
│   └── controllers/
│       ├── index.js                    # Registers the new controller
│       └── locker_entry_choice_controller.js  # NEW: toggles the two first-entry views, clears the locker-number field when "no locker" is chosen
└── assets/
    └── tailwind/
        └── application.css             # New icon-only disclosure-summary modifier + first-entry choice styles

test/
└── system/
    └── locker_profile_test.rb          # Updated helper (pencil icon instead of text summary) + new coverage for the first-entry choice and its edge cases
```

**Structure Decision**: Single Rails monolith, no new directories. All changes live inside the existing `app/views/home/*`, one new Stimulus controller, and existing stylesheet/test files — consistent with how 002, 005, and 008 each extended this same screen.

## Complexity Tracking

*No Constitution Check violations — table omitted.*
