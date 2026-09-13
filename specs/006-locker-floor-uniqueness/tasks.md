---

description: "Task list template for feature implementation"
---

# Tasks: Per-Floor Locker Number Uniqueness

**Input**: Design documents from `/specs/006-locker-floor-uniqueness/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/web-routes.md, quickstart.md

**Tests**: Included — the project constitution's Testing Standards principle is NON-NEGOTIABLE
("every new feature and every bug fix MUST include automated tests that fail without the change and
pass with it"), so every functional requirement below has a corresponding test task. This feature is
a scope correction to an existing rule (002's global locker-number uniqueness), so several tasks
**replace or update an existing test** rather than add a brand-new one — each such task says so
explicitly and cites research.md's rationale.

**Organization**: Tasks are grouped by user story (from spec.md) to enable independent
implementation and testing of each story. Because the entire behavior change is one shared
validation-scope change (see plan.md Summary), no user story phase below needs its own
implementation task beyond the Foundational phase — each story phase is tests only, proving that
shared change satisfies that story's acceptance scenarios.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies). Several test tasks below share
  one test file but are still marked `[P]` when each adds an independent `test "..."` block with no
  shared mutable state, per the same convention 002's tasks.md established.
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Exact file paths are included in every task description

## Path Conventions

Single Ruby on Rails monolith at the repository root (`app/`, `config/`, `db/`, `test/`) — see
plan.md's Project Structure section. No frontend/backend split.

---

## Phase 1: Setup

**Purpose**: Re-scope the DB-level uniqueness guarantee from `locker_number` alone to the
`(floor, locker_number)` pair.

- [X] T001 Generate and apply a migration `db/migrate/<timestamp>_scope_locker_number_uniqueness_to_floor.rb` that removes the existing unique index `index_users_on_locker_number` and adds a new unique index on `[:floor, :locker_number]` (per data-model.md: SQLite treats a row with a `NULL` in either indexed column as distinct from every other row, so this preserves "many users, no floor and/or no locker, no collision" exactly as the single-column index did). Run `bin/rails db:migrate` so `db/schema.rb` reflects the new composite index in place of the old one.

**Checkpoint**: `users` table's `locker_number` uniqueness is now backed by a composite `(floor, locker_number)` index instead of a single-column one.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The one model-layer change that delivers all three user stories below — re-scoping the application-level uniqueness validation to match the new DB index.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 In `app/models/user.rb`, change `validates :locker_number, uniqueness: { message: LOCKER_NUMBER_TAKEN_MESSAGE }, allow_nil: true, on: :locker_profile_update` to add `scope: :floor` (FR-001, FR-002, FR-003 — Rails' uniqueness validator checks uniqueness only among rows sharing the same `floor`, matching the new composite index from T001; `allow_nil: true` is unchanged and still exempts every "no locker" user regardless of floor). Re-word `LOCKER_NUMBER_TAKEN_MESSAGE` from `"is not available — another account already has this locker"` to `"is not available on that floor — another account already has this locker"` so the message names the correct scope without disclosing who holds it (FR-003). Note: `validates :floor, presence: true, on: :locker_profile_update` is unchanged and already requires a floor on every save through this path regardless of whether `locker_number` is set, which is what already satisfies FR-007/FR-008 ("a locker number MUST NOT be stored without a floor") with no new validation — this is verified by the pre-existing test "requires a floor on the locker profile save path" in `test/models/user_test.rb`, which needs no change. Depends on: T001.

**Checkpoint**: The uniqueness rule is now scoped per floor everywhere it is enforced (model validation and DB index). User story implementation can now begin — each story phase below adds only tests.

---

## Phase 3: User Story 1 - Claim a locker number already used on another floor (Priority: P1) 🎯 MVP

**Goal**: A user can save a locker number that is already saved by a different user, as long as that other user is on a different floor.

**Independent Test**: Save locker number "001" on floor 1 for one account, then save locker number "001" on floor 2 for a different account, and confirm both saves succeed and each account still shows its own floor/locker afterward.

**Implementation**: None beyond the Foundational change (T002) — `scope: :floor` on its own means two different floors can never collide, so this story is delivered entirely by T001/T002. This phase only proves it.

### Tests for User Story 1

- [X] T003 [P] [US1] In `test/models/user_test.rb`, replace the existing test `"rejects a locker number another account already holds"` (currently: `carol.locker_number = users(:bob).locker_number`, asserted invalid — this passed only because carol's fixture floor, `"2"`, happens to differ from bob's, `"3"`; under the new rule this exact setup must now succeed, per research.md's "Existing tests that encode the old (global) rule") with a test named `"allows the same locker number on a different floor"` asserting `carol.valid?(:locker_profile_update)` is `true` with `carol.locker_number` set to `users(:bob).locker_number` and `carol.floor` left at its own fixture value (FR-002, Acceptance Scenario 1).
- [X] T004 [P] [US1] In `test/controllers/locker_profiles_controller_test.rb`, add a test that signs in as `carol`, `PATCH /locker_profile` with `floor: "9"` (a floor bob does not have) and `locker_number: users(:bob).locker_number`, and asserts a redirect to `root_path` with carol's `locker_number` and `floor` persisted as submitted — proving the real save path (not just the model in isolation) allows the cross-floor claim end-to-end (FR-002, Acceptance Scenario 1).

**Checkpoint**: User Story 1 is independently verified — the core defect (blocking a valid cross-floor locker number) is fixed and tested.

---

## Phase 4: User Story 2 - Blocked from claiming a locker already taken on the same floor (Priority: P1)

**Goal**: A user attempting to save a locker number already held by a different user on that same floor is still rejected, without disclosing who holds it; a user resubmitting their own unchanged pair is never blocked.

**Independent Test**: Save locker number "001" on floor 1 for one account, attempt to save locker number "001" on floor 1 for a different account and confirm it is rejected without naming the first account, then confirm the first account can resubmit its own "001"/floor 1 unchanged without being rejected.

**Implementation**: None beyond the Foundational change (T002) — this is the collision-preserving half of the same `scope: :floor` validation. This phase only proves it.

### Tests for User Story 2

- [X] T005 [P] [US2] In `test/models/user_test.rb`, add a test `"rejects a locker number another account already holds on the same floor"`: set `carol.locker_number = users(:bob).locker_number` **and** `carol.floor = users(:bob).floor`, assert `carol.valid?(:locker_profile_update)` is `false` and `carol.errors[:locker_number]` includes `User::LOCKER_NUMBER_TAKEN_MESSAGE` (FR-003, Acceptance Scenario 1).
- [X] T006 [P] [US2] In `test/models/user_test.rb`, update the existing test `"the database rejects a duplicate locker number even when validation is skipped"` to also set `carol.floor = users(:bob).floor` before `carol.locker_number = users(:bob).locker_number` and `carol.save(validate: false)` — without this, the two fixtures' differing floors would no longer collide under the new composite index from T001, so the test would silently stop proving anything (research.md — "Existing tests that encode the old (global) rule"). Keep the `assert_raises ActiveRecord::RecordNotUnique` assertion (FR-003, SC-003).
- [X] T007 [P] [US2] In `test/models/user_test.rb`, add a test `"allows a user to resubmit their own current floor and locker number unchanged"`: reload `bob`, reassign `bob.floor = bob.floor` and `bob.locker_number = bob.locker_number` with no other change, and assert `bob.valid?(:locker_profile_update)` is `true` — a user is never blocked by their own existing claim (FR-004, Acceptance Scenario 2).
- [X] T008 [P] [US2] In `test/controllers/locker_profiles_controller_test.rb`, add a test that signs in as `carol`, `PATCH /locker_profile` with `floor: users(:bob).floor` and `locker_number: users(:bob).locker_number` (an un-forced, real collision on the same floor), and asserts a `422` response whose body includes the "not available on that floor" message from T002 and does **not** include `"bob@example.com"` or any other identifier of bob's account (FR-003).

**Checkpoint**: User Story 1 and User Story 2 both hold together — the same-floor collision is still blocked while the cross-floor case from US1 remains allowed.

---

## Phase 5: User Story 3 - Change floor while keeping the same locker number (Priority: P2)

**Goal**: A user who changes their floor while keeping their locker number is re-checked against the new floor, not the old one; a pair they move away from becomes claimable by someone else.

**Independent Test**: With locker "001" saved on floor 1, change that account's floor to floor 2 (with floor 2's "001" free) and confirm it succeeds; then confirm a different account can now save floor 1 / locker "001", since that pair was vacated.

**Implementation**: None beyond the Foundational change (T002) — `scope: :floor` naturally re-evaluates against whichever floor value is current at save time. This phase only proves it.

### Tests for User Story 3

- [X] T009 [P] [US3] In `test/models/user_test.rb`, add a test `"allows moving a locker number to a different floor when that floor's slot is free"`: reload `dave` (floor `"4"`, locker `"D07"` — **not** `bob`, who is the recipient of the always-loaded `alice_pending_to_bob` pending fixture and so is swap-locked by `locker_details_held_by_active_swap`; `dave`'s only proposal, `dave_declined_to_carol`, is declined and therefore inactive), set `dave.floor = "9"` with `dave.locker_number` unchanged, assert `dave.save(context: :locker_profile_update)` succeeds, and assert `dave.reload.floor == "9"` with `dave.locker_number == "D07"` (FR-005, Acceptance Scenario 1).
- [X] T010 [P] [US3] In `test/models/user_test.rb`, add a test `"rejects moving a locker number onto a floor where another user already holds that same number"`: first save `carol.floor = "9"` and `carol.locker_number = "D07"` under `:locker_profile_update` (carol is unlocked; this establishes the destination collision on floor `"9"`), then reload `dave` (floor `"4"`, locker `"D07"`), set `dave.floor = "9"` with `dave.locker_number` unchanged, and assert `dave.valid?(:locker_profile_update)` is `false` with `dave.errors[:locker_number]` including `User::LOCKER_NUMBER_TAKEN_MESSAGE` (FR-005, Acceptance Scenario 2).
- [X] T011 [P] [US3] In `test/models/user_test.rb`, add a test `"frees a vacated floor-and-locker pair for another user to claim"`: reload `dave` (floor `"4"`, locker `"D07"`), move him off it (`dave.floor = "9"`, `dave.save(context: :locker_profile_update)`), then set `carol.floor = "4"` and `carol.locker_number = "D07"` (the pair dave just vacated) and assert `carol.valid?(:locker_profile_update)` is `true` (FR-006, Acceptance Scenario 3).

**Checkpoint**: All three user stories are independently verified; the full per-floor uniqueness rule (claim across floors, block within a floor, re-check on floor change, free on vacate) is proven end-to-end.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Correct documentation left stale by the scope change, and run the project's quality gates.

- [X] T012 [P] In `app/models/locker_swap_proposal.rb`, correct the comment above `swap_lockers` (currently: "locker_number is unique across users, and the check is immediate, so the two rows cannot simply be written over each other...") to describe the uniqueness key as the `(floor, locker_number)` pair rather than `locker_number` alone, per research.md's "Effect on 004/005's swap execution" — the vacate-the-requester-first sequencing itself is unchanged and needs no code edit, only the explanation of why it is needed.
- [X] T013 [P] In `test/models/locker_swap_proposal_test.rb`, correct the comment near line 206 (currently: "which is the case that has to get past the unique index on locker_number") to reflect the composite `(floor, locker_number)` index instead of a single-column one.
- [X] T014 [P] Run `bin/rubocop` and fix any offenses in the files touched by this feature (`app/models/user.rb`, `app/models/locker_swap_proposal.rb`, the new migration) — zero-warning gate per Constitution Principle I.
- [X] T015 Walk through all 4 scenarios in `quickstart.md` manually against a running `bin/rails server` instance and confirm each matches its expected outcome. **Verified against the development database** (real dev data: `toto@toto.com` holding floor `"1"`, locker `"1"`), driving the same path `LockerProfilesController#update` uses (`assign_attributes` + `save(context: :locker_profile_update)`): cross-floor claim accepted, same-floor claim refused with the holder anonymous, vacated pair re-claimable, blank floor refused. Throwaway accounts were removed afterwards, leaving the dev database as found. Browser-level confirmation of the same flows comes from the headless-Chrome system tests in `test/system/locker_profile_test.rb` (T016); a hands-on click-through in a visible browser was not possible in this session because the Chrome extension was not connected.
- [X] T016 Run `bin/rails test` and `bin/rails test:system` and confirm the full suite passes, including all pre-existing 001–005 tests (no regressions — in particular the reworded message from T002 must still satisfy the existing controller test `"a locker number that loses the database race is reported like any other conflict"`, whose assertion `assert_includes response.body, "Locker number is not available"` remains a substring of the new wording) alongside all new/updated tests from T003–T011 and T017.
- [X] T017 [P] In `test/models/user_test.rb`, add a test `"rejects saving a locker number when no floor is on file or supplied"`: take `users(:alice)` (no floor, no locker on file), set only `locker_number = "Z99"` leaving `floor` blank, and assert `alice.valid?(:locker_profile_update)` is `false` with `alice.errors[:floor]` including `"can't be blank"` (FR-007, FR-008, Edge Case). This is a self-contained regression for this feature's own suite: FR-007/FR-008 are already satisfied by the pre-existing `:floor, presence: true` validation (unchanged by T002) and by the pre-existing 002 test `"requires a floor on the locker profile save path"`, but until this task that guarantee had no test living inside this feature's own tasks.md.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 (T002's validation scope pairs with T001's DB index). Blocks all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational. No dependency on User Story 2 or 3.
- **User Story 2 (Phase 4)**: Depends on Foundational. Independent of User Story 1 and 3.
- **User Story 3 (Phase 5)**: Depends on Foundational. Independent of User Story 1 and 2.
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### Within Each User Story

- Every task in Phases 3–5 is a test task; there is no separate "implementation before tests" ordering within these phases, since the implementation already landed in Phase 2. Each test task is independently written and independently verifiable against the Phase 2 result.

### Parallel Opportunities

- All Phase 3–5 test tasks are marked `[P]`: T003, T005, T006, T007, T009, T010, T011 share `test/models/user_test.rb` but each is an independent `test "..."` block; T004 and T008 share `test/controllers/locker_profiles_controller_test.rb` the same way. All can be drafted in parallel.
- T012 and T013 (Polish) touch different files and can run in parallel with each other and with T014; T017 shares `test/models/user_test.rb` with several Phase 3–5 tasks but is an independent `test "..."` block, so it can be drafted in parallel with those too.

---

## Parallel Example: User Story 1 and User Story 2 together

```bash
# Once Foundational (Phase 2 / T002) is done, these can all be drafted together:
Task: "Replace the cross-floor uniqueness test to assert success (US1) in test/models/user_test.rb"
Task: "Add the cross-floor controller test (US1) in test/controllers/locker_profiles_controller_test.rb"
Task: "Add the same-floor rejection test (US2) in test/models/user_test.rb"
Task: "Update the DB-level race test to same floor (US2) in test/models/user_test.rb"
Task: "Add the resubmit-own-pair test (US2) in test/models/user_test.rb"
Task: "Add the same-floor controller collision test (US2) in test/controllers/locker_profiles_controller_test.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001)
2. Complete Phase 2: Foundational (T002) — CRITICAL, this is also the entire functional fix
3. Complete Phase 3: User Story 1 tests (T003–T004)
4. **STOP and VALIDATE**: Confirm the core defect (blocking a valid cross-floor locker number) is fixed
5. Continue with User Story 2 and 3 for full regression coverage before merging

### Incremental Delivery

1. Complete Setup + Foundational → the fix is live
2. Add User Story 1 tests → prove the fix (MVP validation)
3. Add User Story 2 tests → prove the collision case is preserved
4. Add User Story 3 tests → prove floor changes re-check correctly
5. Polish → correct stale comments, run full suite, confirm no regressions

---

## Notes

- [P] tasks = different files, or independent test blocks in a shared file with no shared mutable state
- [Story] label maps task to specific user story for traceability
- Because this feature is a validation-scope correction rather than new functionality, "implementation" for every story is the single Phase 2 change — this is expected and correct, not a sign of missing work
- Commit after each task or logical group
- Avoid: vague tasks, same-file conflicts within a single task, cross-story dependencies that break independence
