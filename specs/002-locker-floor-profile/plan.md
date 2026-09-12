# Implementation Plan: Locker and Floor Profile

**Branch**: `002-locker-floor-profile` | **Date**: 2026-09-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-locker-floor-profile/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

A logged-in user's floor and locker number are shown on the homepage once saved; while either is
missing, the homepage offers two separate fields to fill them in. Floor is mandatory once submitted;
locker number is optional (many users have no locker assigned) but unique across all accounts when
present, and users can come back and change either value later. Technical approach: extend the
existing `User` record in the existing Ruby on Rails 8.1.3 monolith (from 001-user-authentication)
with two new nullable columns (`floor`, `locker_number`), a single new `LockerProfilesController#update`
action, and a homepage that shows the entry form openly to someone who has nothing saved, and for
everyone else shows the saved-values display plus an "Edit locker details" disclosure that reveals
the same pre-filled form (User Story 3) — no new gems, no new table, no new page, and no
hand-written JavaScript.

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged from 001-user-authentication)

**Primary Dependencies**: Ruby on Rails 8.1.3; existing Devise-authenticated `current_user`
(no new gem — this feature adds no authentication behavior of its own)

**Storage**: SQLite via Active Record — two new nullable columns (`floor`, `locker_number`) added to
the existing `users` table, plus a unique index on `locker_number`; no new table (see
[research.md](./research.md) for why a separate table was rejected)

**Testing**: Minitest with fixtures (model-level validation/normalization tests) and Rails system
tests (Capybara, headless Chrome) for the end-to-end display/fill-in/update/conflict scenarios —
identical tooling to 001-user-authentication, no new test dependency

**Target Platform**: Linux server, containerized (Docker), deployed with Kamal — unchanged from
001-user-authentication

**Project Type**: Web application — same single Rails monolith, no separate frontend/backend split

**Performance Goals**: Meet spec Success Criteria as concrete targets — fill-in completable in under
30s end-to-end (SC-003); the save itself is a single indexed-lookup-backed `UPDATE` on `users` (the
same row already loaded for `current_user`), well within the existing general Rails page-response
target of p95 < 300ms established in 001-user-authentication

**Constraints**: SQLite is single-writer/file-based (unchanged constraint from 001); locker-number
uniqueness must therefore be enforced at the DB layer (unique index), not application validation
alone, to stay correct under concurrent submissions (FR-011, SC-005) — see research.md; the floor
presence rule must be scoped to a dedicated validation context so it cannot retroactively block
unrelated `User` saves (e.g. a future Devise email/password change) for a user who hasn't set a
floor yet

**Scale/Scope**: Extends the single `User` model with 2 nullable columns and 1 new controller
action; no new page — folded entirely into the existing authenticated homepage from
001-user-authentication

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Checked against `.specify/memory/constitution.md` v1.0.0:

| Principle | Check | Status |
| - | - | - |
| I. Code Quality | RuboCop (`rubocop-rails-omakase`, already configured) enforced as a zero-warning gate; new `LockerProfilesController` has a single action and single responsibility, kept separate from Devise's authentication controllers precisely to avoid mixing concerns (see research.md); no duplicated validation logic — presence/uniqueness rules live once, on the model, scoped by context | PASS |
| II. Testing Standards (NON-NEGOTIABLE) | Every functional requirement (FR-001..FR-012) gets a Minitest model test or system test before implementation is considered done; CI runs the full suite; the race-condition backstop (DB unique index + `RecordNotUnique` rescue) is covered by two dedicated tests rather than the ordinary-path tests alone — one that bypasses app validation to prove the DB unique index itself rejects a duplicate, and one that forces the controller's rescue branch (via a temporary `User#save` stub, since no mocking gem is present) to prove it produces the same user-facing message as an ordinary conflict (tasks.md T017, T018) | PASS |
| III. User Experience Consistency | Reuses the existing Tailwind layout and flash/error conventions from 001-user-authentication; "no locker assigned" is always rendered as a neutral status, never styled or worded as an error, per FR-004; form labels and error messages follow the same accessible-label pattern already used by the signup/login forms | PASS |
| IV. Performance Requirements | The only new path is a single-row `UPDATE` against an already-loaded, primary-keyed `User` record, guarded by an index on `locker_number` for the uniqueness check — no unbounded query is introduced; no separate before/after benchmark is needed beyond the existing p95 < 300ms general target since this is not a swap/lock execution path | PASS |

No violations identified; Complexity Tracking table is not needed.

**Post-Phase 1 re-check**: Re-evaluated after producing research.md, data-model.md, contracts/, and
quickstart.md. The concrete design (two nullable columns on the existing `users` table, a
context-scoped presence validation, a `nil`-exempt uniqueness validation backed by a DB unique index,
and one new single-action controller) introduces no new dependency, table, or pattern beyond what
was already assessed above. All four principles remain PASS; no Complexity Tracking entries
required.

## Project Structure

### Documentation (this feature)

```text
specs/002-locker-floor-profile/
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
│   └── locker_profiles_controller.rb   # new: update-only, saves floor/locker_number (FR-001, FR-002, FR-006, FR-007, FR-009, FR-011)
├── models/
│   └── user.rb                         # extended: floor/locker_number validations + blank-to-nil normalization
└── views/
    └── home/
        ├── index.html.erb              # updated: form shown openly when nothing is saved; otherwise display partial + <details> edit disclosure
        ├── _locker_profile.html.erb    # new: display partial, rendered only when a floor is on file (User Story 1, FR-003/FR-004)
        └── _locker_profile_form.html.erb  # new: pre-filled entry/edit form partial, shared by both cases (User Story 2/3, FR-005/FR-006)

config/
└── routes.rb                           # + resource :locker_profile, only: :update

db/
├── migrate/
│   └── <timestamp>_add_locker_profile_to_users.rb   # floor, locker_number columns + unique index on locker_number
└── schema.rb

test/
├── models/
│   └── user_test.rb                    # extended: presence-in-context, uniqueness/nil-exemption, blank normalization
├── system/
│   └── locker_profile_test.rb          # new: User Story 1/2/3 acceptance scenarios end-to-end
└── fixtures/
    └── users.yml                       # extended as needed with floor/locker_number fixture data
```

**Structure Decision**: Same single Rails monolith at the repository root established in
001-user-authentication (`app/`, `config/`, `db/`, `test/`) — this feature adds one model extension,
one controller, one migration, and view partials into that existing structure; no new top-level
directory or project is introduced.

## Complexity Tracking

No Constitution Check violations were identified; this section is intentionally empty.
