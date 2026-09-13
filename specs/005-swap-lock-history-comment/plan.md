# Implementation Plan: Locker Field Lock & Swap History Comment

**Branch**: `005-swap-lock-history-comment` | **Date**: 2026-09-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-swap-lock-history-comment/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

While a user is a party (requester or recipient) to a `pending` or `accepted` swap proposal, they
can no longer change an *already-saved* floor or locker number — only providing one for the first
time stays allowed, so a requester with no locker yet is never trapped. Every proposal history
entry additionally gets a system-generated summary — separate from the existing, user-entered
decline comment — stating the floor and locker number being proposed (`pending`/`accepted`,
`declined`, `withdrawn`) or actually exchanged (`completed`); once a proposal leaves
`pending`/`accepted`, those values are snapshotted and frozen so later profile edits never make old
history entries drift. Technical approach: extend the existing Ruby on Rails 8.1.3 monolith with
four new nullable snapshot columns on `locker_swap_proposals`
(`requester_floor_at_resolution`, `requester_locker_number_at_resolution`,
`recipient_floor_at_resolution`, `recipient_locker_number_at_resolution`), a new `User` validation
(scoped to `:locker_profile_update`, mirroring 002's existing floor/uniqueness rules) that blocks
changing an already-saved floor/locker number while `LockerSwapProposal.active_for?(current_user)`,
a new `LockerSwapProposal#floor_and_locker_summary` method the history view renders in a new column,
and snapshot-capture added to `withdraw!`/`decline!`/`confirm!`/`decline_competing_proposals` — no
new gems, no new table, no hand-written JavaScript.

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged from 001/002/003/004)

**Primary Dependencies**: Ruby on Rails 8.1.3; extends the existing `LockerSwapProposal` model and
`User`'s existing `:locker_profile_update` validation context from 002/004 — no new gem

**Storage**: SQLite via Active Record — one migration adding four nullable string columns to the
existing `locker_swap_proposals` table (see [data-model.md](./data-model.md)); no new table, no
change to `users` or `locker_wishes` schema, though this feature reads `users.floor` /
`users.locker_number` (for the live, unresolved-status summary and for the pre-swap snapshot) and
reads/writes the new `locker_swap_proposals` columns

**Testing**: Minitest with fixtures (model-level validation, snapshot-on-transition, and summary-text
tests; controller test for the new profile-lock rejection) and Rails system tests (Capybara, headless
Chrome) for the end-to-end lock and history-comment scenarios — identical tooling to 001/002/003/004,
no new test dependency

**Target Platform**: Linux server, containerized (Docker), deployed with Kamal — unchanged from
001-user-authentication

**Project Type**: Web application — same single Rails monolith, no separate frontend/backend split

**Performance Goals**: Meet spec Success Criteria as concrete targets — every edit-lock check
(SC-001/SC-002) is two-to-four indexed `exists?` lookups against `locker_swap_proposals`, on the same
order as the existing `in_progress_for?` check already on this path; the history page's new summary
column adds no additional query per row (it reads columns already loaded on `@proposals`, or, for
unresolved rows, the already-`includes`d counterparty). The bulk auto-decline path
(`decline_competing_proposals`) keeps its existing "one statement regardless of how many rows"
property (Principle IV) by populating the four new snapshot columns via correlated subqueries in the
same `update_all` statement, rather than looping — see research.md.

**Constraints**: SQLite is single-writer/file-based (unchanged constraint from 001-004); the lock
validation must distinguish "changing an already-saved value" from "providing a first-time value"
using Active Record dirty-tracking (`floor_was`/`locker_number_was`), since the spec (clarified)
requires the latter to always be allowed even while locked; the four snapshot columns must be
populated exactly once, at the transition into `declined`/`withdrawn`/`completed`, and for
`completed` specifically *before* `confirm!`'s existing `swap_lockers` call mutates the two users'
records (Assumptions: pre-swap values), never recomputed afterward.

**Scale/Scope**: One migration (four new nullable columns, no new table); one new `User` validation
method; four small changes to `LockerSwapProposal` (`active_for?` class method,
`floor_and_locker_summary` instance method, snapshot capture added to three existing instance
methods and one existing private method); a `Locker details` column added to
`locker_swap_proposals/index.html.erb`; the existing `home/index.html.erb` "Edit locker details"
disclosure replaced by a locked notice when appropriate.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Checked against `.specify/memory/constitution.md` v1.0.0:

| Principle | Check | Status |
| - | - | - |
| I. Code Quality | The lock rule is one more `User` validation in the same `:locker_profile_update` context 002 already established (not a controller-level guard, not duplicated between `LockerProfilesController` and any future save path); the summary-text and snapshot logic live once, as methods on `LockerSwapProposal` (`floor_and_locker_summary`, `resolution_snapshot`), reused by `withdraw!`/`decline!`/`confirm!`/`decline_competing_proposals` and by the history view — no duplication across controller actions or views | PASS |
| II. Testing Standards (NON-NEGOTIABLE) | Every functional requirement (FR-001..FR-009) gets a Minitest model test (lock validation: already-saved vs. first-time, each status transition's snapshot, `floor_and_locker_summary` wording for every status) or system test (locked notice replacing the edit disclosure, history page's new column) before implementation is considered done; CI runs the full suite | PASS |
| III. User Experience Consistency | The lock is surfaced the same way 004 already surfaces "no active wish" / "already has an exchange in progress" — plain explanatory text, never a dead-end error — by replacing the "Edit locker details" `<details>` disclosure with a locked notice while `LockerSwapProposal.active_for?(current_user)`; a bypassed-UI submission still re-renders the existing form with `devise/shared/error_messages`, so the rejection is never a dead end even off the happy path; the new history column reuses the existing table's typography (`text-slate-600`/`text-slate-400` conventions already used for the decline-comment column) | PASS |
| IV. Performance Requirements | The lock check is 2-4 additional indexed `exists?` lookups on the same table/columns `in_progress_for?` already queries on this path — no new index required beyond the ones 004 already added. The bulk auto-decline statement stays a single `update_all` (via correlated subqueries for the four new columns) rather than becoming an N-query loop, preserving the property the existing code comment on `decline_competing_proposals` already calls out as a deliberate Principle IV choice; no unbounded loop or query is introduced | PASS |

No violations identified; Complexity Tracking table is not needed.

**Post-Phase 1 re-check**: Re-evaluated after producing research.md, data-model.md, contracts/, and
quickstart.md. The concrete design (four new nullable columns on the existing table, one new `User`
validation reusing an existing context, two new `LockerSwapProposal` methods, snapshot capture added
to four existing code paths, one new history column, one existing view branch replaced) introduces no
new dependency, no new table, and no pattern beyond what was already assessed above. All four
principles remain PASS; no Complexity Tracking entries required.

## Project Structure

### Documentation (this feature)

```text
specs/005-swap-lock-history-comment/
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
│   ├── locker_profiles_controller.rb          # unchanged: the new validation surfaces through its existing save/re-render flow
│   └── locker_swap_proposals_controller.rb     # unchanged: #index already loads @proposals; the view reads the new summary method off each one
├── models/
│   ├── user.rb                                  # extended: new validation blocking a changed *already-saved* floor/locker_number while LockerSwapProposal.active_for?(self) (FR-001, FR-002)
│   └── locker_swap_proposal.rb                  # extended: LockerSwapProposal.active_for?(user); #floor_and_locker_summary; snapshot capture added to withdraw!/decline!/confirm!/decline_competing_proposals (FR-005..FR-009)
└── views/
    ├── locker_swap_proposals/
    │   └── index.html.erb                       # extended: new "Locker details" column rendering proposal.floor_and_locker_summary (FR-005..FR-007)
    └── home/
        └── index.html.erb                       # extended: the "Edit locker details" <details> disclosure is replaced by a locked notice while LockerSwapProposal.active_for?(current_user) and no pending re-render error; unchanged for a user with no saved floor yet (FR-001..FR-004)

db/
├── migrate/
│   └── <timestamp>_add_resolution_snapshots_to_locker_swap_proposals.rb   # 4 nullable string columns
└── schema.rb

test/
├── models/
│   ├── user_test.rb                             # new: already-saved-vs-first-time lock validation cases
│   └── locker_swap_proposal_test.rb             # extended: active_for?, snapshot-on-transition (withdraw/decline/auto-decline/confirm, pre- vs. post-swap timing), floor_and_locker_summary wording per status
├── controllers/
│   └── locker_profiles_controller_test.rb        # extended: update rejected while locked (already-saved value), update allowed while locked (first-time value)
├── system/
│   ├── locker_profile_test.rb                    # extended: locked notice replaces the edit disclosure; first-time entry still works while locked
│   └── locker_swap_proposal_test.rb              # extended: history page shows the new column with correct wording per status
└── fixtures/
    └── locker_swap_proposals.yml                 # extended: fixtures covering each resolved status with its snapshot columns populated, for summary-text tests
```

**Structure Decision**: Same single Rails monolith established in 001-user-authentication and
extended in 002/003/004 (`app/`, `config/`, `db/`, `test/`) — this feature adds one migration (four
columns on an existing table), one new validation method on the existing `User` model, two new
methods on the existing `LockerSwapProposal` model, and a bounded set of changes to two existing
views; no new controller, no new route, no new top-level directory or project.

## Complexity Tracking

No Constitution Check violations were identified; this section is intentionally empty.
