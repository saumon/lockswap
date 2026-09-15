# Implementation Plan: Homepage Locker Wish Block

**Branch**: `010-homepage-locker-wish-block` | **Date**: 2026-09-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/010-homepage-locker-wish-block/spec.md`

## Summary

Add one card to the homepage, between the swap-proposal sections and the "Your locker" card, that reports the signed-in user's locker wish and offers a single way in to the wish page. The card renders in exactly one of three states — the declared wish plus "Review locker wishes! 🥷", or the invitation "I want to switch my locker! 👀" for someone who has a locker, or "I want a locker! 🙏" for someone who has none — and is withheld entirely from a user who has not yet saved their locker details, so the first-time screen keeps the single-task shape 009 gave it.

The whole feature is one new partial plus three lines in `home/index.html.erb`. All three states read state that is already loaded (`current_user.locker_wish`, `current_user.saved_locker_number`), the control is a plain `link_to` styled as a button pointing at the existing `GET /locker_wishes`, and every visual class it needs already exists in the stylesheet. No migration, no route, no controller, no model change, no JavaScript.

## Technical Context

**Language/Version**: Ruby 3.4.6, Rails 8.1.3

**Primary Dependencies**: Hotwire (Turbo Rails + Stimulus Rails — no Stimulus controller added here), Devise 5.0 (supplies `current_user`, unchanged), tailwindcss-rails (Tailwind CSS v4), Propshaft, importmap-rails

**Storage**: SQLite3 via Active Record — read-only use of existing tables. `locker_wishes` (003) and `users.floor` / `users.locker_number` (002, 006). No schema change.

**Testing**: Minitest (unit/controller), Capybara + Selenium headless Chrome for system tests, axe-core audit on every screen (008 FR-028)

**Target Platform**: Server-rendered web app (evergreen desktop/mobile browsers), Docker container deployed via Kamal

**Project Type**: Single Rails monolith, server-rendered views

**Performance Goals**: No new query on the homepage in the common case — `current_user.locker_wish` is a single indexed lookup on a `has_one`, memoized on the user object for the rest of the request. No per-row work, no collection load (Principle IV)

**Constraints**:

- The homepage has two renderers: `HomeController#index` and `LockerProfilesController#update` re-rendering `home/index` after a rejected edit. The block must appear identically in both, so it must not depend on an instance variable only one of them sets.
- Button labels are exact strings including their emoji (FR-003, FR-004, FR-005); they are assertion targets.
- The block must stay axe-clean, like every other screen (Constitution Principle III, 008 FR-028).
- An active swap proposal must not alter the block (FR-013), even though the card directly below it is frozen for editing in that state.
- System tests must call `wait_for_turbo` before asserting on the block after a navigation — Turbo Drive paints a cached snapshot first, which can carry the previous state of this exact card (the documented 008 lesson).

**Scale/Scope**: One new partial, one edited template, one new test file, one new fixture user. No new models, migrations, routes, controllers, stylesheets, or JavaScript.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Code Quality**: One partial with a three-branch conditional and no new abstraction. Reuses the existing route, the existing `has_one :locker_wish` association, and the existing `saved_locker_number` reader. No helper, no concern, no service object introduced for what is a presentation branch. PASS.
- **II. Testing Standards (NON-NEGOTIABLE)**: Purely presentational, so system tests are the primary evidence: one new file covering all three states, the withheld-block case, the wish-wins-over-invitation precedence, navigation from each state, and FR-013's active-proposal case. A new fixture is required — no current fixture user has saved details, no locker, and no wish. The existing homepage accessibility tests already cover two of the three states and gain the block for free. PASS, tracked into tasks.
- **III. User Experience Consistency**: Reuses `.card` / `.card-title` / `.card-lead` / `.detail-term` / `.detail-value` / `.row` / `.btn .btn-primary` exactly as the neighbouring homepage cards do; introduces no new visual pattern and no new stylesheet rule. The control is a real link, so keyboard and screen-reader behaviour is the browser's and needs nothing added (FR-010). PASS.
- **IV. Performance Requirements**: Adds at most one indexed single-row lookup to a page that already issues several; no loop, no unbounded query, no N+1 (the block never renders other users' wishes). No before/after measurement required. PASS.

Re-checked after Phase 1 design: unchanged, all four PASS. No violations to record in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/010-homepage-locker-wish-block/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── homepage-locker-wish-block.md
├── checklists/
│   └── requirements.md  # Spec quality checklist (/speckit-specify output)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
└── views/
    └── home/
        ├── index.html.erb           # Renders the new partial inside the saved-details branch,
        │                            # immediately above "home/locker_profile" (FR-001a, FR-012)
        └── _locker_wish.html.erb    # NEW: the block — three mutually exclusive states,
                                     # each with one link_to locker_wishes_path

test/
├── fixtures/
│   └── users.yml                    # NEW fixture: saved floor, no locker number, no wish
│                                    # — the "I want a locker! 🙏" state
└── system/
    ├── homepage_locker_wish_test.rb # NEW: all three states, the withheld case, precedence,
    │                                # navigation, and the active-proposal case (FR-013)
    └── accessibility_test.rb        # Existing homepage audits now cover the block; add the
                                     # third state's audit if not already reachable
```

**Structure Decision**: Single Rails monolith, no new directories. The feature lives entirely in `app/views/home/` — the same screen 002, 004, 005, 008 and 009 each extended — plus test files. No `app/models`, `app/controllers`, `config/routes.rb`, `db/`, `app/javascript/` or stylesheet change is expected; if one becomes necessary, that is a signal the design drifted and should be re-examined rather than absorbed.

## Complexity Tracking

*No Constitution Check violations — table omitted.*
