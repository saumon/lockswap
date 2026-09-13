# Implementation Plan: Locker Search Wish

**Branch**: `003-locker-search-wish` | **Date**: 2026-09-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-locker-search-wish/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

A logged-in, registered user can declare (and later cancel) a single "I'm looking for a locker on
floor X" wish, whether or not they currently have a locker assigned, and any logged-in user can
browse a list of everyone's active wishes — each row showing the sought floor, the wishing user's
email, and that user's current floor/locker number (from the existing 002 profile) so viewers can
judge a swap. Technical approach: extend the existing Ruby on Rails 8.1.3 monolith with one new
table (`locker_wishes`, `user_id` unique + `floor`), one new `LockerWishesController`
(`index`/`create`/`destroy`), and one new page at `/locker_wishes` — no new gems, no changes to the
existing homepage, no hand-written JavaScript.

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged from 001-user-authentication, 002-locker-floor-profile)

**Primary Dependencies**: Ruby on Rails 8.1.3; existing Devise-authenticated `current_user`
(no new gem — this feature adds no authentication behavior of its own)

**Storage**: SQLite via Active Record — one new table, `locker_wishes` (`user_id` with a unique
index, `floor`), associated to the existing `users` table; no columns added to `users` (see
[research.md](./research.md) for why a separate table was chosen here, unlike 002's columns-on-`users`
approach)

**Testing**: Minitest with fixtures (model-level validation/association/race-backstop tests) and
Rails system tests (Capybara, headless Chrome) for the end-to-end declare/view/cancel scenarios —
identical tooling to 001/002, no new test dependency

**Target Platform**: Linux server, containerized (Docker), deployed with Kamal — unchanged from
001-user-authentication

**Project Type**: Web application — same single Rails monolith, no separate frontend/backend split

**Performance Goals**: Meet spec Success Criteria as concrete targets — declaring a wish
completable in under 30s end-to-end (SC-001); the wish list is a single `LockerWish.includes(:user)`
query bounded by the number of active wishes (never unbounded — every row requires a distinct user
who took an explicit action), well within the existing general Rails page-response target of
p95 < 300ms established in 001-user-authentication

**Constraints**: SQLite is single-writer/file-based (unchanged constraint from 001/002); "at most
one active wish per user" must therefore be enforced at the DB layer (unique index on
`locker_wishes.user_id`), not application validation alone, to stay correct under concurrent
declare submissions (FR-003, SC-003) — see research.md; declaring, cancelling, and viewing must all
sit behind `authenticate_user!`, matching the existing homepage/profile pattern, so an anonymous
visitor is redirected to sign in rather than shown any wish data (FR-013)

**Scale/Scope**: One new table, one new model, one new controller with three actions, one new page;
no changes to `User`, `HomeController`, or the existing homepage views from 001/002

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Checked against `.specify/memory/constitution.md` v1.0.0:

| Principle | Check | Status |
| - | - | - |
| I. Code Quality | RuboCop (`rubocop-rails-omakase`, already configured) enforced as a zero-warning gate; `LockerWishesController` has three actions, each with a single responsibility (declare/list, cancel), kept separate from `HomeController` and `LockerProfilesController` precisely because it owns a different concern (see research.md); no duplicated validation logic — the presence rule lives once, on `LockerWish` | PASS |
| II. Testing Standards (NON-NEGOTIABLE) | Every functional requirement (FR-001..FR-013) gets a Minitest model test or system test before implementation is considered done; CI runs the full suite; the race-condition backstop (DB unique index on `user_id` + `RecordNotUnique` rescue) is covered by a dedicated test that forces the controller's rescue branch (via a temporary `LockerWish#save` stub, matching the pattern already used in `test/controllers/locker_profiles_controller_test.rb`, since no mocking gem is present), proving it still leaves exactly one wish per user rather than raising | PASS |
| III. User Experience Consistency | Reuses the existing Tailwind layout, flash/error conventions, and no-JavaScript `<details>` disclosure pattern from 002; "no locker assigned" and the new "not set" floor state are always rendered as neutral status text, never as errors, per Edge Cases; the "I'm looking for a locker" button/disclosure and "Cancel wish" control follow the same accessible-label pattern already used by the locker-profile form | PASS |
| IV. Performance Requirements | The wish list uses `includes(:user)` to avoid N+1 queries across an unbounded number of rows; declaring/cancelling are single-row writes against an indexed lookup (`user_id`), guarded by a unique index for the uniqueness check — no unbounded query is introduced; no separate before/after benchmark is needed beyond the existing p95 < 300ms general target since this is not a swap/lock execution path | PASS |

No violations identified; Complexity Tracking table is not needed.

**Post-Phase 1 re-check**: Re-evaluated after producing research.md, data-model.md, contracts/, and
quickstart.md. The concrete design (one new table with a unique index on `user_id`, a presence-only
validation on `floor`, one new three-action controller, and one new page reusing the existing
`<details>` disclosure pattern) introduces no new dependency and no pattern beyond what was already
assessed above. All four principles remain PASS; no Complexity Tracking entries required.

## Project Structure

### Documentation (this feature)

```text
specs/003-locker-search-wish/
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
├── controllers/
│   └── locker_wishes_controller.rb     # new: index/create/destroy (FR-001..FR-013)
├── models/
│   ├── locker_wish.rb                  # new: belongs_to :user, floor presence validation
│   └── user.rb                         # extended: has_one :locker_wish, dependent: :destroy (no other change)
└── views/
    └── locker_wishes/
        ├── index.html.erb              # new: viewer's own declare/cancel/edit controls + the wish list table
        ├── _locker_wish_panel.html.erb # new: "I'm looking for a locker" button/disclosure, or current wish + Cancel + "Change floor" disclosure
        ├── _locker_wish_form.html.erb  # new: single floor field, shared by declare and edit
        └── _locker_wish_list.html.erb  # new: table of every active wish (floor sought, email, current floor/locker)

config/
└── routes.rb                           # + resources :locker_wishes, only: :index
                                         # + resource :locker_wish, only: [:create, :destroy]

db/
├── migrate/
│   └── <timestamp>_create_locker_wishes.rb   # user_id (FK, unique index), floor (not null)
└── schema.rb

test/
├── models/
│   └── locker_wish_test.rb             # new: presence validation, association, race-backstop
├── controllers/
│   └── locker_wishes_controller_test.rb  # new: race-condition backstop (mirrors locker_profiles_controller_test.rb)
├── system/
│   └── locker_wish_test.rb             # new: User Story 1/2/3 acceptance scenarios end-to-end
└── fixtures/
    └── locker_wishes.yml               # new: fixture support for model/system tests as needed
```

**Structure Decision**: Same single Rails monolith at the repository root established in
001-user-authentication and extended in 002-locker-floor-profile (`app/`, `config/`, `db/`,
`test/`) — this feature adds one new model, one new table, one new controller, one new page, and a
single `has_one` line on the existing `User` model; no new top-level directory or project, and no
existing 001/002 file is behaviorally changed beyond that one association line.

## Complexity Tracking

No Constitution Check violations were identified; this section is intentionally empty.
