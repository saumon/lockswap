# Implementation Plan: Locker Swap Proposals

**Branch**: `004-locker-swap-proposal` | **Date**: 2026-09-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-locker-swap-proposal/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

A logged-in, registered user proposes a locker swap, from the existing Locker Wishes screen (003),
to another user who has an active wish there. The recipient accepts or declines (optionally with a
comment) from the homepage, where both sent and received proposals are surfaced; acceptance marks
the exchange "in progress" and auto-declines any other pending proposals either party was part of;
the requester can withdraw a still-pending proposal; the recipient later confirms the exchange
actually happened, which swaps floor and locker number between the two users and clears both their
wishes. A separate, read-only history screen lists every proposal a user sent or received. Technical
approach: extend the existing Ruby on Rails 8.1.3 monolith with one new table
(`locker_swap_proposals` — `requester_id`, `recipient_id`, enum `status`, `decline_comment`,
`decided_at`, `completed_at`, `requester_acknowledged_at`), one new
`LockerSwapProposalsController` (`create`/`destroy`/`accept`/`decline`/`confirm`/`index`),
additions to the existing Locker Wishes list and homepage views, and a new `/locker_swap_proposals`
history page — no new gems, no hand-written JavaScript.

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged from 001/002/003)

**Primary Dependencies**: Ruby on Rails 8.1.3; existing Devise-authenticated `current_user` (no new
gem — this feature adds no authentication behavior of its own)

**Storage**: SQLite via Active Record — one new table, `locker_swap_proposals`
(`requester_id`/`recipient_id` FKs to `users`, enum `status`, plus the fields above), with three
partial unique indexes enforcing the concurrency rules (see [research.md](./research.md) and
[data-model.md](./data-model.md)); no columns added to `users` or `locker_wishes`, though this
feature reads and writes `users.floor`/`users.locker_number` (on confirmation) and reads/destroys
`locker_wishes` rows (on eligibility check and on confirmation)

**Testing**: Minitest with fixtures (model-level validation/enum/race-backstop tests, controller
authorization-scoping tests) and Rails system tests (Capybara, headless Chrome) for the end-to-end
propose/respond/withdraw/confirm/history scenarios — identical tooling to 001/002/003, no new test
dependency

**Target Platform**: Linux server, containerized (Docker), deployed with Kamal — unchanged from
001-user-authentication

**Project Type**: Web application — same single Rails monolith, no separate frontend/backend split

**Performance Goals**: Meet spec Success Criteria as concrete targets — sending a proposal completable
in under 30s end-to-end (SC-001); the homepage's new proposal queries and the history page are each
a handful of indexed, `includes`-scoped lookups against a table whose size is bounded by the number
of users who have ever proposed or been proposed to (never unbounded independent of user action),
well within the existing p95 < 300ms general target established in 001-user-authentication. The
`confirm!` swap is a constitution-designated swap/lock execution path (Principle IV) and its PR must
carry a before/after measurement even though it is a small, bounded transaction (two row updates,
at most two row deletes).

**Constraints**: SQLite is single-writer/file-based (unchanged constraint from 001/002/003); "at
most one pending proposal per requester→recipient pair" and "at most one exchange in progress per
user" must be enforced with DB-level partial unique indexes as the correctness backstop, not
application validation alone, to stay correct under concurrent submissions (FR-018, FR-003/FR-004;
see research.md for why two same-column partial indexes plus a transaction-scoped re-check were
chosen over a join table for the cross-role case); every proposal action (create, withdraw, accept,
decline, confirm) and the history page must sit behind `authenticate_user!` and be scoped through
`current_user`'s own associations, so no user can act on or discover another user's proposal by
guessing an id (FR-016)

**Scale/Scope**: One new table, one new model, one new controller with six actions, one new page;
additions to the existing homepage view and the existing Locker Wishes list view/controller from
002/003; no changes to `User`'s or `LockerWish`'s schema (only new associations/class methods on
`User`, and a read-only exclusion added to `LockerWishesController`'s list query)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Checked against `.specify/memory/constitution.md` v1.0.0:

| Principle | Check | Status |
| - | - | - |
| I. Code Quality | RuboCop (`rubocop-rails-omakase`, already configured) enforced as a zero-warning gate; `LockerSwapProposalsController` owns exactly the proposal lifecycle (create/withdraw/accept/decline/confirm/history), kept separate from `HomeController` and `LockerWishesController`, which each gain only the minimal read-side additions needed to surface proposals (a query and a display block), not proposal logic itself; the state-transition rules (auto-decline cascade, in-progress checks, the swap itself) live once, as methods on `LockerSwapProposal`, not duplicated across controller actions | PASS |
| II. Testing Standards (NON-NEGOTIABLE) | Every functional requirement (FR-001..FR-020) gets a Minitest model test, controller test, or system test before implementation is considered done; CI runs the full suite; both concurrency backstops (the duplicate-pending unique index and the two in-progress unique indexes) get a dedicated test forcing the relevant race via a temporary stub, matching 002/003's established pattern, proving each still leaves the system in the state the relevant FR requires rather than raising an unhandled error | PASS |
| III. User Experience Consistency | Reuses the existing Tailwind layout, flash/error conventions, and no-JavaScript `<details>` disclosure pattern (002/003) for the Decline-with-comment form; "no active wish"/"already in an exchange" ineligibility is always rendered as plain explanatory text on the Locker Wishes list, never as a dead-end error; the homepage's new proposal sections follow the same card layout already used for the locker-profile prompt (002) | PASS |
| IV. Performance Requirements | `confirm!`'s floor/locker swap — the one swap/lock execution path this feature introduces — gets a before/after measurement in its PR per Principle IV, even though it is a small bounded transaction; the homepage and history queries use `includes` to avoid N+1s across an unbounded number of rows; no unbounded loop or query is introduced elsewhere | PASS |

No violations identified; Complexity Tracking table is not needed.

**Post-Phase 1 re-check**: Re-evaluated after producing research.md, data-model.md, contracts/, and
quickstart.md. The concrete design (one new table with three partial unique indexes, an enum status
column, one new six-action controller, minimal read-side additions to two existing controllers, and
one new page) introduces no new dependency and no pattern beyond what was already assessed above.
The cross-role "in progress" concurrency gap (documented in research.md as a deliberate,
proportionate trade-off rather than a full join-table guarantee) does not change any principle's
PASS status — it is a scoped, justified design decision, not a Code Quality or Testing Standards
shortcut. All four principles remain PASS; no Complexity Tracking entries required.

## Project Structure

### Documentation (this feature)

```text
specs/004-locker-swap-proposal/
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
│   ├── locker_swap_proposals_controller.rb  # new: create/destroy(withdraw)/accept/decline/confirm/index (FR-001..FR-020)
│   ├── locker_wishes_controller.rb           # extended: exclude wishes of users with an exchange in progress; expose per-row proposal eligibility to the view
│   └── home_controller.rb                    # extended: load pending/accepted/recently-declined proposals for the viewer
├── models/
│   ├── locker_swap_proposal.rb               # new: belongs_to :requester/:recipient, enum status, validations, accept!/decline!/withdraw!/confirm!
│   ├── user.rb                                # extended: has_many :sent_swap_proposals, :received_swap_proposals (no other change)
│   └── locker_wish.rb                         # unchanged (003)
└── views/
    ├── locker_swap_proposals/
    │   └── index.html.erb                    # new: read-only history — sent + received, dates, status, decline comments
    ├── locker_wishes/
    │   ├── index.html.erb                    # unchanged wrapper
    │   └── _locker_wish_list.html.erb         # extended: "Propose swap" control (or ineligibility note) per row
    └── home/
        └── index.html.erb                    # extended: pending received (Accept/Decline), pending sent (Withdraw), exchange in progress (Confirm for recipient), recently-declined-sent

config/
└── routes.rb                                  # + resources :locker_swap_proposals, only: [:create, :destroy, :index] with member accept/decline/confirm

db/
├── migrate/
│   └── <timestamp>_create_locker_swap_proposals.rb   # requester_id/recipient_id (FK), status (integer, default 0), decline_comment (text), decided_at, completed_at, requester_acknowledged_at (datetime); 3 partial unique indexes
└── schema.rb

test/
├── models/
│   └── locker_swap_proposal_test.rb           # new: validations, enum transitions, auto-decline cascade, confirm swap, both race backstops
├── controllers/
│   └── locker_swap_proposals_controller_test.rb  # new: authorization scoping (wrong user/role/state), races
├── system/
│   └── locker_swap_proposal_test.rb           # new: User Story 1-5 acceptance scenarios end-to-end
└── fixtures/
    └── locker_swap_proposals.yml              # new: fixture support (pending/accepted/declined examples) for model/system tests
```

**Structure Decision**: Same single Rails monolith established in 001-user-authentication and
extended in 002-locker-floor-profile / 003-locker-search-wish (`app/`, `config/`, `db/`, `test/`) —
this feature adds one new model, one new table, one new controller, one new page, two new
associations on the existing `User` model, and minimal read-side additions to
`HomeController`/`LockerWishesController`'s existing actions; no new top-level directory or project.

## Complexity Tracking

No Constitution Check violations were identified; this section is intentionally empty.
