# Implementation Plan: Per-Floor Locker Number Uniqueness

**Branch**: `006-locker-floor-uniqueness` | **Date**: 2026-09-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/006-locker-floor-uniqueness/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

002 enforced `locker_number` as unique across every account, which incorrectly blocks two different
users from holding the same locker number on two different floors — a valid state, since floor and
locker number together identify a physical locker, not locker number alone. This feature re-scopes
the existing uniqueness rule from "unique across all users" to "unique per (floor, locker_number)
pair," with no new column, no new controller, no new page, and no new validation context: it changes
the scope of the uniqueness check already running on `LockerProfilesController#update`'s existing
`:locker_profile_update` context, and the backing DB index, from `locker_number` alone to the
composite pair. The existing, unconditional `floor` presence requirement on that same save path
already guarantees a locker number is never stored without a floor (FR-007/FR-008), so no new
validation is needed there either.

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged from 001-user-authentication / 002-locker-floor-profile)

**Primary Dependencies**: Ruby on Rails 8.1.3; the existing `User` model and
`LockerProfilesController` from 002-locker-floor-profile (no new gem, no new controller, no new
route)

**Storage**: SQLite via Active Record — the existing `users.floor` and `users.locker_number`
nullable columns are unchanged; the existing unique index on `locker_number` alone is replaced with
a composite unique index on `[floor, locker_number]` (see research.md)

**Testing**: Minitest with fixtures (model-level uniqueness/scope tests) and the existing Rails
system test for the locker profile flow (Capybara, headless Chrome) — identical tooling to
001/002, no new test dependency

**Target Platform**: Linux server, containerized (Docker), deployed with Kamal — unchanged

**Project Type**: Web application — same single Rails monolith, no separate frontend/backend split

**Performance Goals**: No new query shape is introduced — the uniqueness check remains a single
indexed lookup (now on two columns instead of one) backing the same single-row `UPDATE` on `users`
already established in 002; stays within the existing general p95 < 300ms target

**Constraints**: SQLite is single-writer/file-based (unchanged constraint from 001/002); the
composite unique index is still the race-safe guarantee under concurrent submissions (mirroring
002's FR-011/SC-005 approach, now scoped to the pair) — see research.md; `LockerSwapProposal#swap_lockers`
(004/005) already vacates the requester's `(floor, locker_number)` before writing the recipient's,
specifically because the previous global unique index could not hold two rows with the same
`locker_number` even momentarily — that same vacate-first sequencing remains required and correct
under the new composite index (a swap can still momentarily need to hold the same floor OR the same
locker number, if not both together, on two rows at once), so no code change is needed there, only a
comment correction (see research.md)

**Scale/Scope**: One migration changing an index, one model validation scope change, one error
message re-wording, and one comment correction in an unrelated model — no new table, column,
controller, or page

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Checked against `.specify/memory/constitution.md` v1.0.0:

| Principle | Check | Status |
| - | - | - |
| I. Code Quality | RuboCop (`rubocop-rails-omakase`) enforced as a zero-warning gate; the change is a scope adjustment to one existing validation and one existing index — no duplicated logic is introduced, and the stale "unique across users" comment in `locker_swap_proposal.rb` is corrected in place rather than left contradicting the new rule | PASS |
| II. Testing Standards (NON-NEGOTIABLE) | Every functional requirement (FR-001..FR-008) gets a Minitest model test before implementation is considered done, including: same locker number on two different floors succeeds (FR-002), same pair on the same floor is rejected (FR-003), a user resubmitting their own pair succeeds (FR-004), changing floor alone re-checks against the new floor (FR-005), a vacated pair becomes claimable (FR-006), and a locker number cannot be saved without a floor (FR-007/FR-008); the existing DB-level race test from 002 is updated to prove the composite index (not the old single-column index) is what now rejects a same-floor duplicate | PASS |
| III. User Experience Consistency | Reuses the exact error-message and non-disclosure pattern already established in 002 (FR-003 here mirrors 002 FR-011) — only the wording changes to mention "on that floor"; no new UI, form, or flow is introduced | PASS |
| IV. Performance Requirements | The composite index keeps the uniqueness check a single indexed lookup; no unbounded query or additional round-trip is introduced | PASS |

No violations identified; Complexity Tracking table is not needed.

**Post-Phase 1 re-check**: Re-evaluated after producing research.md, data-model.md, contracts/, and
quickstart.md. The concrete design (one migration re-scoping the existing unique index, one
`scope:` addition to the existing uniqueness validation, one message re-wording, one comment
correction) introduces no new dependency, table, controller, or pattern beyond what was already
assessed above. All four principles remain PASS; no Complexity Tracking entries required.

## Project Structure

### Documentation (this feature)

```text
specs/006-locker-floor-uniqueness/
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
├── models/
│   ├── user.rb                         # updated: locker_number uniqueness scoped to :floor;
│   │                                    #   LOCKER_NUMBER_TAKEN_MESSAGE re-worded to mention the floor
│   └── locker_swap_proposal.rb         # updated: comment on swap_lockers corrected to describe
│                                        #   per-floor (not global) uniqueness — no behavior change
└── controllers/
    └── locker_profiles_controller.rb   # unchanged (existing rescue of RecordNotUnique still applies)

db/
├── migrate/
│   └── <timestamp>_scope_locker_number_uniqueness_to_floor.rb   # drops the single-column unique
│       index on locker_number, adds a composite unique index on [floor, locker_number]
└── schema.rb

test/
├── models/
│   └── user_test.rb                    # updated: existing global-uniqueness test replaced with
│                                        #   same-floor-rejected / different-floor-allowed tests;
│                                        #   DB-level race test updated to the composite index
└── controllers/
    └── locker_profiles_controller_test.rb  # updated: new tests proving the cross-floor claim
                                              #   (US1) and the same-floor collision (US2) over the
                                              #   real PATCH /locker_profile path, not just the model
```

No fixture file changes are needed: `alice`, `bob`, `carol`, and `dave` already cover every combination
this feature's tests require, assigned dynamically per test rather than added as new fixture rows.

**Structure Decision**: Same single Rails monolith at the repository root established in
001-user-authentication and extended by 002/003/004/005 — this feature is a scope change to
existing files only; no new top-level directory, model, controller, or route is introduced.

## Complexity Tracking

No Constitution Check violations were identified; this section is intentionally empty.
