---

description: "Task list template for feature implementation"
---

# Tasks: Locker Field Lock & Swap History Comment

**Input**: Design documents from `/specs/005-swap-lock-history-comment/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/web-routes.md, quickstart.md

**Tests**: Included — the project constitution's Testing Standards principle is NON-NEGOTIABLE
("every new feature ... MUST include automated tests that fail without the change and pass with
it"), and plan.md commits every functional requirement (FR-001..FR-009) to a Minitest model test,
controller test, or system test, so every FR below has a corresponding test task.

**Organization**: Tasks are grouped by user story (from spec.md) to enable independent
implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies). Several test tasks that share one
  test file are still marked `[P]` when each adds an independent `test "..."` block with no shared
  mutable state — matching 004's own convention.
- **[Story]**: Which user story this task belongs to (US1, US2)
- Exact file paths are included in every task description

## Path Conventions

Single Ruby on Rails monolith at the repository root (`app/`, `config/`, `db/`, `test/`) — see
plan.md's Project Structure section. No frontend/backend split.

---

## Phase 1: Setup

**Purpose**: Add the four snapshot columns User Story 2 needs to `locker_swap_proposals`.

- [X] T001 Generate and apply a migration `db/migrate/<timestamp>_add_resolution_snapshots_to_locker_swap_proposals.rb` that adds four nullable string columns to the existing `locker_swap_proposals` table: `requester_floor_at_resolution`, `requester_locker_number_at_resolution`, `recipient_floor_at_resolution`, `recipient_locker_number_at_resolution` (data-model.md — Entity: Locker Swap Proposal, New fields). Run `bin/rails db:migrate` so `db/schema.rb` reflects the new columns.

**Checkpoint**: `locker_swap_proposals` has the four new nullable columns. (User Story 1 does not depend on this migration — see Dependencies below.)

---

## Phase 2: User Story 1 - Floor and locker number are locked while a swap is active (Priority: P1) 🎯 MVP

**Goal**: A logged-in user who has sent or received a `pending` or `accepted` swap proposal cannot
change an already-saved floor or locker number until it is resolved; providing a floor or locker
number for the first time is always allowed, even while locked.

**Independent Test**: Send or receive a proposal, attempt to edit an already-saved floor or locker
number while it is pending or in progress and confirm it is rejected, then resolve the proposal
(decline, withdraw, or complete) and confirm the edit is allowed again; confirm a user with no
saved floor/locker yet can still provide one for the first time while their own proposal is active.

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T002 [P] [US1] Model test in `test/models/user_test.rb`: `users(:bob)` (saved `floor: "3"`, recipient of the always-loaded pending fixture `locker_swap_proposals(:alice_pending_to_bob)`) is invalid on `:locker_profile_update` when `floor` is changed to a new value, with an error on `:floor` (Acceptance Scenario 1, FR-001).
- [X] T003 [P] [US1] Model test in `test/models/user_test.rb`: `users(:bob)` is invalid on `:locker_profile_update` when `locker_number` is changed to a new value, with an error on `:locker_number` (Acceptance Scenario 2, FR-002).
- [X] T004 [P] [US1] Model test in `test/models/user_test.rb`: reassigning `users(:bob).floor` and `.locker_number` to their own current values (no actual change) is still valid on `:locker_profile_update` — the lock only fires on a real change, not a no-op resubmission (dirty-tracking guard).
- [X] T005 [P] [US1] Model test in `test/models/user_test.rb`: `users(:alice)` (no saved `floor`/`locker_number`; requester of `locker_swap_proposals(:alice_pending_to_bob)`) is valid on `:locker_profile_update` when setting `floor` and `locker_number` for the first time, even though she has an active proposal (Acceptance Scenario 6, "already-saved vs. first-time" clarification).
- [X] T006 [P] [US1] Model test in `test/models/user_test.rb`: a user party to an `accepted` proposal (build inline: `LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob)).accept!`) is also invalid on `:locker_profile_update` when changing an already-saved `floor` or `locker_number` (Acceptance Scenario 3).
- [X] T007 [P] [US1] Model test in `test/models/user_test.rb`: once `locker_swap_proposals(:alice_pending_to_bob)` is declined (`.decline!`), `users(:bob)` changing an already-saved `floor` is valid again on `:locker_profile_update` (Acceptance Scenario 5).
- [X] T008 [P] [US1] Model test in `test/models/locker_swap_proposal_test.rb`: `LockerSwapProposal.active_for?(user)` is `true` for a user party (either role) to a `pending` proposal and for a user party (either role) to an `accepted` proposal, and `false` for a user with no proposal or only `declined`/`withdrawn`/`completed` ones (data-model.md — new class method).
- [X] T009 [P] [US1] Controller test in `test/controllers/locker_profiles_controller_test.rb`: signed in as `bob`, `PATCH /locker_profile` changing `floor` to a new value is rejected (422) with an error naming the field as locked because of an active swap proposal (FR-001, FR-003).
- [X] T010 [P] [US1] Controller test in `test/controllers/locker_profiles_controller_test.rb`: signed in as `alice` (no saved floor/locker, active pending proposal as requester), `PATCH /locker_profile` providing `floor`/`locker_number` for the first time succeeds (FR-001, FR-002).
- [X] T011 [P] [US1] Controller test in `test/controllers/locker_profiles_controller_test.rb`: signed in as `dave` (party only to the resolved `locker_swap_proposals(:dave_declined_to_carol)`, no active proposal), `PATCH /locker_profile` changing his already-saved `floor` succeeds exactly as before this feature — regression guard for the "no active proposal" baseline.
- [X] T012 [P] [US1] System test in `test/system/locker_profile_test.rb`: as `bob` (active pending proposal via the default fixture), visiting `/` shows a locked notice in place of the "Edit locker details" disclosure, while the saved floor and locker number are still displayed as before (Acceptance Scenario 1 & 2; contracts/web-routes.md — Display contract).
- [X] T013 [P] [US1] System test in `test/system/locker_profile_test.rb`: as `bob`, after declining `locker_swap_proposals(:alice_pending_to_bob)` (built/declined directly in the test), reloading `/` shows the "Edit locker details" disclosure again and a floor change now succeeds (Acceptance Scenario 5).
- [X] T014 [P] [US1] System test in `test/system/locker_profile_test.rb`: as `alice` (no saved floor yet, active pending proposal as requester via the default fixture), `/` still shows the plain first-time entry form rather than a locked notice, and submitting a floor value for the first time succeeds (Acceptance Scenario 6).

### Implementation for User Story 1

- [X] T015 [US1] In `app/models/locker_swap_proposal.rb`, add `LockerSwapProposal.active_for?(user)`: `pending.exists?(requester_id: user.id) || pending.exists?(recipient_id: user.id) || in_progress_for?(user)` — true when `user` is a party, in either role, to a `pending` or `accepted` proposal (data-model.md — new class method; research.md — "Detecting active"). Two separate `exists?` calls, not one `OR`, matching the existing `in_progress_for?`'s documented SQLite-planner-fault reasoning.
- [X] T016 [US1] In `app/models/user.rb`, add `validate :floor_and_locker_locked_during_active_swap, on: :locker_profile_update` and a `LOCKED_MESSAGE = "cannot be changed while you have an active swap proposal"` constant; the validation method adds `errors.add(:floor, LOCKED_MESSAGE)` when `floor_changed? && floor_was.present? && LockerSwapProposal.active_for?(self)`, and `errors.add(:locker_number, LOCKED_MESSAGE)` under the equivalent condition for `locker_number` (FR-001, FR-002, FR-003; data-model.md — Entity: User Locker Profile). Depends on: T015.
- [X] T017 [US1] In `app/views/home/index.html.erb`, within the `current_user.saved_floor.present?` branch, replace the unconditional "Edit locker details" `<details>` disclosure with: when `LockerSwapProposal.active_for?(current_user)` is true **and** `current_user.errors.empty?`, render a locked notice (plain explanatory text stating the floor and locker number cannot be changed while an active swap proposal exists, matching 004's "already has an exchange in progress" style — Constitution Principle III); otherwise render the existing disclosure unchanged (open when `current_user.errors.any?`, covering a bypassed-UI rejected submission so the error is never a dead end) (FR-003; contracts/web-routes.md — Display contract). Depends on: T016.
- [X] T018 [US1] Update the pre-existing 002 system tests in `test/system/locker_profile_test.rb` that exercise editing via `bob` — "submitting a blank floor is rejected and leaves the saved floor untouched," "changing only the floor leaves the locker number alone," "clearing the locker number leaves the floor alone," "the form stays out of the way until the user asks to edit," and "a rejected edit reopens the form with the error and the saved values intact" — to log in as `dave` instead (floor `"4"`, locker `"D07"`, no active proposal), updating the expected floor/locker values in each assertion accordingly. `bob` is now permanently locked by the always-loaded `locker_swap_proposals(:alice_pending_to_bob)` fixture, so these five pre-existing tests would otherwise regress once T017 lands; the read-only "sees both on the homepage" test stays on `bob` since it never opens the editor. Depends on: T017.

**Checkpoint**: User Story 1 is fully functional and independently testable — the profile-lock rule
works end-to-end and the full pre-existing suite still passes.

---

## Phase 3: User Story 2 - Proposal history shows what was proposed or exchanged without typing it in (Priority: P2)

**Goal**: Every proposal history entry shows a system-generated comment — separate from the
existing, user-entered decline comment — stating the floor and locker number being proposed
(`pending`/`accepted`/`declined`/`withdrawn`) or actually exchanged (`completed`), with no manual
entry required, and frozen at whatever it said once the proposal was resolved.

**Independent Test**: Create proposals ending in each status (pending, in progress, declined,
withdrawn, completed) and open the history screen for both users; confirm each status shows an
automatically-filled comment with the correct wording, that it does not require manual entry, and
that a resolved entry's comment does not change after either party later edits their profile.

### Tests for User Story 2

- [X] T019 [P] [US2] Model test in `test/models/locker_swap_proposal_test.rb`: `withdraw!` on a `pending` proposal sets the four `..._at_resolution` columns to the requester's and recipient's current `floor`/`locker_number` (FR-009).
- [X] T020 [P] [US2] Model test in `test/models/locker_swap_proposal_test.rb`: `decline!(comment)` on a `pending` proposal sets the four `..._at_resolution` columns the same way, alongside the existing `decline_comment` behavior (FR-009).
- [X] T021 [P] [US2] Model test in `test/models/locker_swap_proposal_test.rb`: `accept!`'s auto-decline path (`decline_competing_proposals`) populates the four `..._at_resolution` columns correctly, per row, for each of several competing proposals it declines — each competing proposal's own requester/recipient values, not the accepted proposal's (build two separate pending proposals sharing one party, accept one, and check the other's snapshot columns) (FR-009; research.md — bulk snapshot via correlated subquery).
- [X] T022 [P] [US2] Model test in `test/models/locker_swap_proposal_test.rb`: `confirm!` on an `accepted` proposal between two users with distinct floor/locker values sets the four `..._at_resolution` columns to each side's **pre-swap** values, while `requester.floor`/`recipient.floor` (etc.) afterward hold the post-swap, already-exchanged values (FR-009; data-model.md — pre-swap, not post-swap).
- [X] T023 [P] [US2] Model test in `test/models/locker_swap_proposal_test.rb`: `#floor_and_locker_summary` on a `pending` or `accepted` proposal reads the live `requester`/`recipient` `floor`/`locker_number` (not the still-nil snapshot columns) and states both sides' values as *proposed* (FR-006).
- [X] T024 [P] [US2] Model test in `test/models/locker_swap_proposal_test.rb`: `#floor_and_locker_summary` on a `declined` or `withdrawn` proposal (built and resolved inline) reads the four `..._at_resolution` columns and states both sides' values as *proposed*, not *exchanged* (FR-006).
- [X] T025 [P] [US2] Model test in `test/models/locker_swap_proposal_test.rb`: `#floor_and_locker_summary` on a `completed` proposal reads the four `..._at_resolution` columns and states both sides' values as *exchanged* (FR-006).
- [X] T026 [P] [US2] Model test in `test/models/locker_swap_proposal_test.rb`: `#floor_and_locker_summary` renders a side with a `nil` locker number (live or snapshotted) with the same "no locker assigned" wording `home/_locker_profile.html.erb` already uses, rather than blank or `nil` text (Edge Cases).
- [X] T027 [P] [US2] Model test in `test/models/locker_swap_proposal_test.rb`: after a proposal is resolved (e.g. `decline!`ed) and the involved user's `floor`/`locker_number` is later changed via `save(context: :locker_profile_update)`, `#floor_and_locker_summary` still returns exactly what it returned right after resolution — unaffected by the later edit ("no drift" clarification).
- [X] T028 [P] [US2] System test in `test/system/locker_swap_proposal_test.rb`: visiting `/locker_swap_proposals` shows a new "Locker details" column populated on every row regardless of status (pending, declined, withdrawn, completed, built/extended within the test), with no manual entry required (FR-005; Acceptance Scenario 3).
- [X] T029 [P] [US2] System test in `test/system/locker_swap_proposal_test.rb`: on a declined proposal with both a user-entered `decline_comment` and the new automatic summary, `/locker_swap_proposals` shows both, side by side, neither replacing or hiding the other (FR-008, Acceptance Scenario 4).

### Implementation for User Story 2

- [X] T030 [US2] In `app/models/locker_swap_proposal.rb`, add a private `resolution_snapshot` method returning `{ requester_floor_at_resolution: requester.floor, requester_locker_number_at_resolution: requester.locker_number, recipient_floor_at_resolution: recipient.floor, recipient_locker_number_at_resolution: recipient.locker_number }`, and merge its result into the existing `update!` calls inside `withdraw!` and `decline!` (FR-009; research.md — "Keeping the history comment from drifting"). Depends on: T001.
- [X] T031 [US2] In `app/models/locker_swap_proposal.rb`, update `confirm!` to capture `resolution_snapshot` into a local variable **before** calling the existing `swap_lockers`, then merge that already-captured hash (not a fresh call, which would read post-swap values) into the existing `update!(status: :completed, completed_at: Time.current)` call (FR-009; data-model.md — pre-swap, not post-swap; research.md — "Snapshot timing inside confirm!"). Depends on: T030.
- [X] T032 [US2] In `app/models/locker_swap_proposal.rb`, extend `decline_competing_proposals`'s existing single `update_all` call to also set the four new columns via correlated subqueries against `users` (e.g. `requester_floor_at_resolution = (SELECT floor FROM users WHERE users.id = locker_swap_proposals.requester_id)`, and the equivalent for the other three), keeping the whole operation one SQL statement rather than looping per competing proposal (FR-009; research.md — "Populating the snapshot for the bulk auto-decline path"). Depends on: T030.
- [X] T033 [US2] In `app/models/locker_swap_proposal.rb`, add `#floor_and_locker_summary`: for `pending?`/`accepted?`, compose "proposed" text from `requester.floor`/`requester.locker_number`/`recipient.floor`/`recipient.locker_number`; for `declined?`/`withdrawn?`, compose "proposed" text from the four `..._at_resolution` columns; for `completed?`, compose "exchanged" text from the same four columns; render "No locker assigned" (matching `home/_locker_profile.html.erb`'s existing phrase) for a `nil` locker number on either side, live or snapshotted (FR-005, FR-006; data-model.md — "New derived behavior"). Depends on: T030.
- [X] T034 [US2] In `app/views/locker_swap_proposals/index.html.erb`, add a "Locker details" column after the existing "Comment" column, rendering `proposal.floor_and_locker_summary` on every row (FR-005, FR-007; contracts/web-routes.md — Display contract). Depends on: T033.

**Checkpoint**: Both user stories work together — the lock protects an active proposal's fields, and
the history screen self-documents what every proposal, resolved or not, actually involved.

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Quality gates from the project constitution that span both stories above.

- [X] T035 [P] Run `bin/rubocop` and fix any offenses in the files touched by this feature (`app/models/locker_swap_proposal.rb`, `app/models/user.rb`, `app/views/home/index.html.erb`, `app/views/locker_swap_proposals/index.html.erb`, the new migration, and the updated test files) — zero-warning gate per Constitution Principle I.
- [X] T036 [P] Review the locked notice and the new "Locker details" column for accessible labels and keyboard operability (no interactive control changed shape, but the locked notice must not rely on color alone to communicate the restriction), per Constitution Principle III.
- [X] T037 Walk through all 6 scenarios in `quickstart.md` manually against a running `bin/rails server` instance and confirm each matches its expected outcome, including scenario 6's "no drift after resolution" check.
- [X] T038 Run `bin/rails test` and `bin/rails test:system` and confirm the full suite passes, including all pre-existing 001/002/003/004 tests (no regressions — see T018) alongside all new tests from T002–T014 and T019–T029.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **User Story 1 (Phase 2)**: No dependency on Setup — `active_for?` reads only columns that already
  existed before this feature (`status`, `requester_id`, `recipient_id`); it can be implemented and
  tested before, after, or in parallel with the Phase 1 migration.
- **User Story 2 (Phase 3)**: Depends on Setup (Phase 1) — every implementation task in this phase
  reads or writes the four new columns the migration adds. No dependency on User Story 1.
- **Polish (Phase 4)**: Depends on both user stories being complete.

### Within Each User Story

- Tests are written before the implementation tasks they cover, and MUST fail until the
  corresponding implementation task lands.
- US1: T015 (`active_for?`) before T016 (validation, which calls it) before T017 (view, which calls
  it) before T018 (fixing the pre-existing tests T017's view change would otherwise break).
- US2: T030 (`resolution_snapshot`) before T031/T032 (which reuse or mirror it) and before T033
  (`#floor_and_locker_summary`, read by the T034 view change).

### Parallel Opportunities

- T002–T014 (US1 tests) can all be drafted in parallel — each is an independent `test "..."` block,
  even where several share one file.
- T019–T029 (US2 tests) can all be drafted in parallel, for the same reason.
- Once Setup (T001) is done, User Story 1 (Phase 2) and User Story 2 (Phase 3) can be implemented in
  parallel by different developers, since neither's implementation tasks touch a file the other
  writes to (US1: `locker_swap_proposal.rb`'s `active_for?`, `user.rb`, `home/index.html.erb`; US2:
  `locker_swap_proposal.rb`'s `resolution_snapshot`/`confirm!`/`decline_competing_proposals`/
  `floor_and_locker_summary`, `locker_swap_proposals/index.html.erb`) — both do touch
  `locker_swap_proposal.rb`, so a shared branch would want the two sets of model changes merged
  sequentially even though they are logically independent.
- T035 and T036 (Polish) can run in parallel.

---

## Parallel Example: User Story 1

```bash
# Once T001 is done (or even before it, since US1 does not depend on it), these tests
# can be drafted together (test/models/user_test.rb, test/models/locker_swap_proposal_test.rb,
# test/controllers/locker_profiles_controller_test.rb, test/system/locker_profile_test.rb):
Task: "Model test: bob cannot change an already-saved floor while locked"
Task: "Model test: bob cannot change an already-saved locker number while locked"
Task: "Model test: resubmitting the same value is not rejected"
Task: "Model test: alice can still set a floor/locker for the first time while locked"
Task: "Model test: a user in an accepted proposal is also locked"
Task: "Model test: the lock lifts once the proposal resolves"
Task: "Model test: active_for? covers pending and accepted, both roles"
Task: "Controller test: PATCH rejected while locked"
Task: "Controller test: PATCH allowed for a first-time value while locked"
Task: "Controller test: PATCH allowed with no active proposal (regression guard)"
Task: "System test: locked notice replaces the edit disclosure"
Task: "System test: disclosure returns once resolved"
Task: "System test: first-time entry form is unaffected by the lock"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (migration) — or skip ahead, since US1 does not need it.
2. Complete Phase 2: User Story 1 — the profile lock, including the pre-existing-test fix (T018).
3. **STOP and VALIDATE**: User Story 1 alone is a complete, shippable increment — floor/locker
   editing is protected during an active swap, with no regression to the existing suite.

### Incremental Delivery

1. Setup → the four snapshot columns exist.
2. Add User Story 1 → validate independently → floor/locker editing is protected (MVP).
3. Add User Story 2 → validate independently → proposal history self-documents every status.
4. Polish → lint, accessibility, full suite, manual quickstart pass.

### Parallel Team Strategy

With two developers, after Setup:

- Developer A: User Story 1 (`active_for?`, the `User` validation, the homepage view, the
  pre-existing-test fix).
- Developer B: User Story 2 (`resolution_snapshot`, `confirm!`/`decline_competing_proposals`
  updates, `#floor_and_locker_summary`, the history view).
- Both touch `app/models/locker_swap_proposal.rb`; merge the two sets of model changes sequentially
  even though they are logically independent (different methods, no shared state).
