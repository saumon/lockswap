---

description: "Task list template for feature implementation"
---

# Tasks: Locker and Floor Profile

**Input**: Design documents from `/specs/002-locker-floor-profile/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/web-routes.md, quickstart.md

**Tests**: Included — the project constitution's Testing Standards principle is NON-NEGOTIABLE
("every new feature ... MUST include automated tests that fail without the change and pass with
it"), so every functional requirement below has a corresponding test task.

**Organization**: Tasks are grouped by user story (from spec.md) to enable independent
implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies). Within a phase, several test
  tasks may share one test file but are still marked `[P]` when each adds an independent `test
  "..."` block with no shared mutable state — see "Parallel Opportunities" below.
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Exact file paths are included in every task description

## Path Conventions

Single Ruby on Rails monolith at the repository root (`app/`, `config/`, `db/`, `test/`) — see
plan.md's Project Structure section. No frontend/backend split.

---

## Phase 1: Setup

**Purpose**: Extend the existing `users` table with this feature's two new columns.

- [X] T001 Generate and apply a migration `db/migrate/<timestamp>_add_locker_profile_to_users.rb` that adds a nullable `floor` (`string`) column and a nullable `locker_number` (`string`) column to `users`, plus a unique index on `locker_number` (per data-model.md: SQLite/Rails treats multiple `NULL`s as distinct, so this allows any number of users with no locker while still preventing two users from sharing one). Run `bin/rails db:migrate` so `db/schema.rb` reflects both new columns and the index.

**Checkpoint**: `users` table has `floor` and `locker_number`, both nullable, with `locker_number` uniquely indexed.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Model-layer rules and wiring shared by every user story below. No user story can be implemented until this phase is done.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 In `app/models/user.rb`, add: (a) a `before_validation` callback that normalizes a blank or whitespace-only submitted `locker_number` to `nil` (data-model.md — "no locker" must always be stored as SQL `NULL`, never `""`, so the uniqueness check in (c) below can't be tricked by two blank strings); (b) `validates :floor, presence: true, on: :locker_profile_update` (FR-007, FR-012 — scoped to this context only, per research.md, so it never blocks an unrelated future `User` save such as a Devise email/password change for a user with no floor yet); (c) `validates :locker_number, uniqueness: true, allow_nil: true, on: :locker_profile_update` (FR-011 — `allow_nil: true` is required because Rails' uniqueness validator does not skip `nil` by default and would otherwise treat every "no locker" user as a duplicate of the first one). Depends on: T001.
- [X] T003 [P] In `config/routes.rb`, add `resource :locker_profile, only: :update` so `PATCH /locker_profile` routes to `LockerProfilesController#update` (contracts/web-routes.md).
- [X] T004 [P] In `test/fixtures/users.yml`, add two fixtures reused across the user-story tests below: `bob` (`email: bob@example.com`, same `encrypted_password`/`failed_attempts` pattern as `alice`, `floor: "3"`, `locker_number: "B12"`) and `carol` (same auth fields, `floor: "2"`, no `locker_number` set). Depends on: T001 (columns must exist for these attributes to be valid fixture keys).

**Checkpoint**: Schema, model validations/normalization, route, and shared test fixtures are ready — user story implementation can now begin.

---

## Phase 3: User Story 1 - See my locker and floor on the homepage (Priority: P1) 🎯 MVP

**Goal**: A logged-in user who already has a floor saved sees it (and their locker number, or a clear "no locker assigned" indicator) on the homepage with no extra action.

**Independent Test**: Log in as the `bob` fixture (floor + locker number both set) and as the `carol` fixture (floor set, no locker number); confirm the homepage shows the right information for each without visiting any other page.

### Tests for User Story 1

- [X] T005 [P] [US1] System test in `test/system/locker_profile_test.rb`: logging in as `bob` shows both the floor and the locker number on the homepage (Acceptance Scenario 1).
- [X] T006 [P] [US1] System test in `test/system/locker_profile_test.rb`: logging in as `carol` shows the floor and a clear "no locker assigned" indicator, and the page contains no error styling/text for the missing locker number (Acceptance Scenario 2, FR-004).

### Implementation for User Story 1

- [X] T007 [US1] Create `app/views/home/_locker_profile.html.erb`: a display partial that renders `current_user.floor` and, when `current_user.locker_number` is blank, an explicit "No locker assigned" indicator instead of the locker number (FR-003, FR-004). Depends on: T001.
- [X] T008 [US1] In `app/views/home/index.html.erb`, render `_locker_profile` only when `current_user.floor.present?` (Edge Case: a floor-less user must not see stale/blank display content). Depends on: T007.

**Checkpoint**: User Story 1 is fully functional and independently testable using only fixture data — no save path is required yet.

---

## Phase 4: User Story 2 - Fill in my floor and locker number from the homepage (Priority: P1)

**Goal**: A logged-in user with no floor saved is offered, on the homepage, two separate fields (floor, locker number) to fill in; floor is mandatory, locker number is optional, and a locker number already held by someone else is rejected without revealing who holds it.

**Independent Test**: Log in as the `alice` fixture (no floor saved), confirm the homepage shows the two-field form, then submit a floor with and without a locker number, submit a blank floor, and submit a locker number already saved on `bob`'s account — confirming the four respective outcomes; separately, confirm saved values survive a fresh login and that the database-level uniqueness safeguard produces the same user-facing outcome as the ordinary validation failure.

### Tests for User Story 2

- [X] T009 [P] [US2] System test in `test/system/locker_profile_test.rb`: logging in as `alice` (no floor saved) shows a form with a floor field and a separate locker number field, not a single combined field (Acceptance Scenario 1, FR-006).
- [X] T010 [P] [US2] System test in `test/system/locker_profile_test.rb`: submitting a floor with the locker number field left blank succeeds; the homepage then shows the floor and "no locker assigned" (Acceptance Scenario 2, FR-008).
- [X] T011 [P] [US2] System test in `test/system/locker_profile_test.rb`: submitting the form with the floor field blank is rejected, the user is told the floor is required, and nothing is saved (Acceptance Scenario 3, FR-007).
- [X] T012 [P] [US2] System test in `test/system/locker_profile_test.rb`: logged in as `alice`, submitting `bob`'s locker number (`"B12"`) is rejected, the user is told that locker number is not available, and `bob`'s email/identity never appears on the page (Acceptance Scenario 4, FR-011).
- [X] T013 [P] [US2] Model test in `test/models/user_test.rb`: a `User` with a blank `floor` saves successfully when `save` is called without the `:locker_profile_update` context, confirming the presence rule does not leak into unrelated saves (research.md — "Floor: presence rule without breaking unrelated User updates").
- [X] T014 [P] [US2] Model test in `test/models/user_test.rb`: two `User` records can both have `locker_number: nil` and save successfully under the `:locker_profile_update` context, but a second record saving the same non-nil `locker_number` under that context fails uniqueness validation (FR-011).
- [X] T015 [P] [US2] Model test in `test/models/user_test.rb`: assigning a whitespace-only string to `locker_number` and saving under the `:locker_profile_update` context results in `locker_number` being persisted as `nil`, not the whitespace string.
- [X] T016 [P] [US2] System test in `test/system/locker_profile_test.rb`: after logging in as `alice`, submitting a floor (and locker number), logging out, and logging back in, the homepage still shows the saved floor/locker number — proving the save is tied to the account and not just the current request/session (FR-010).
- [X] T017 [P] [US2] Model test in `test/models/user_test.rb`: bypassing the application-level uniqueness validation (e.g., `save(validate: false)`, or a direct `insert_all`/SQL insert) to give a second `User` record the same non-nil `locker_number` as an existing one raises `ActiveRecord::RecordNotUnique`. This proves the DB unique index from T001 — not just the `:locker_profile_update` validation from T002 — is the real, race-safe guarantee behind FR-011/SC-005 (data-model.md — Persistence-layer backstop).
- [X] T018 [P] [US2] Test in `test/controllers/locker_profiles_controller_test.rb` (new file, `ActionDispatch::IntegrationTest`): with a signed-in user, force the controller's save call to raise `ActiveRecord::RecordNotUnique` (e.g., temporarily redefine `User#save` for the duration of the test, restoring it afterward — no mocking gem is present in this project, see Gemfile), then `PATCH /locker_profile`, and assert the response re-renders the homepage with the exact same "not available" locker-number message asserted in T012 — proving the rescue path added in T019 is indistinguishable from the ordinary validation-failure path to the user (FR-011).

### Implementation for User Story 2

- [X] T019 [US2] Create `app/controllers/locker_profiles_controller.rb` with `before_action :authenticate_user!` and an `update` action: strong-parameter-permit `:floor` and `:locker_number`, `current_user.assign_attributes(...)`, then `current_user.save(context: :locker_profile_update)`; on success redirect to `root_path` with a confirmation flash; on validation failure, render `home/index` with status `:unprocessable_entity` so the errors are shown inline. Rescue `ActiveRecord::RecordNotUnique` around the save and add the same "has already been taken" style error to `current_user.errors[:locker_number]` before re-rendering, so the rare concurrent-submission race produces the identical user-facing message as the ordinary validation failure (data-model.md — Persistence-layer backstop, FR-011; verified by T018). Depends on: T002, T003.
- [X] T020 [US2] Create `app/views/home/_locker_profile_form.html.erb`: a form (via `form_with model: current_user, url: locker_profile_path, method: :patch`) with two separate, labeled fields — a required `floor` text field and an optional `locker_number` text field — pre-filled from `current_user`'s current values, and rendering any validation errors from `current_user.errors` (FR-005, FR-006). Depends on: T019.
- [X] T021 [US2] In `app/views/home/index.html.erb`, always render `_locker_profile_form` (in addition to `_locker_profile` from User Story 1, which only appears when a floor is already saved) so the same form serves both the empty and already-filled states. Depends on: T008, T020.

**Checkpoint**: User Story 1 and User Story 2 both work end-to-end together — a brand-new user can fill in their profile and immediately see it displayed.

---

## Phase 5: User Story 3 - Update my floor or locker number later (Priority: P2)

**Goal**: A logged-in user who already has a floor and/or locker number saved can change either value independently at any later time.

**Independent Test**: Log in as the `bob` fixture (floor + locker number already saved), change only the floor and confirm the locker number is untouched, then clear the locker number and confirm the floor is untouched.

**Note**: This story needs no new implementation — the always-present, pre-filled form and the single `PATCH /locker_profile` action built in User Story 2 (T019–T021) were designed from the start to double as the edit path (see research.md — "Where it's displayed and entered"). This phase adds the regression coverage that proves that reuse actually holds.

### Tests for User Story 3

- [X] T022 [P] [US3] System test in `test/system/locker_profile_test.rb`: logging in as `bob`, changing only the floor field and submitting updates the displayed floor while the displayed locker number (`"B12"`) is unchanged (Acceptance Scenario 1).
- [X] T023 [P] [US3] System test in `test/system/locker_profile_test.rb`: logging in as `bob`, clearing the locker number field and submitting makes the homepage show "no locker assigned" while the displayed floor (`"3"`) is unchanged (Acceptance Scenario 2).

**Checkpoint**: All three user stories are independently functional; the full fill-in/display/edit lifecycle works end-to-end.

---

## Phase 5b: Edit control follow-up (stakeholder change, post-review)

**Why**: After reviewing the delivered feature, the stakeholder asked that the "Update your locker
details" form not sit open on the homepage for users who have already answered — it should appear
only after clicking an edit control. This reverses the "always-present form" decision originally
recorded in research.md; that file and contracts/web-routes.md have been updated to match.

**Scope**: Only the already-answered state changes. A user with nothing saved still gets the form
openly, untouched, because FR-005 requires the prompt to be unmissable for them.

- [X] T028 In `app/models/user.rb`, add `saved_floor` / `saved_locker_number` reading `floor_in_database` / `locker_number_in_database`, so anything reporting what is on file is not fooled by the rejected input the attributes hold while a failed edit is re-rendered.
- [X] T029 In `app/views/home/_locker_profile.html.erb`, read the saved values from T028 so a rejected edit shows the error beside what is actually still on file (FR-003, FR-004).
- [X] T030 In `app/views/home/_locker_profile_form.html.erb`, drop the card wrapper and heading so the partial is just errors + fields, letting the caller present it either openly or inside the disclosure.
- [X] T031 In `app/views/home/index.html.erb`, branch on `current_user.saved_floor.present?`: render the form openly under an "Add your locker details" heading when nothing is saved (FR-005), otherwise render the display partial followed by a `<details>` whose `<summary>` is "Edit locker details" and whose body is the form (FR-009). Mark the `<details>` `open` when `current_user.errors.any?` so a rejected edit still has a visible form to correct.
- [X] T032 In `test/system/locker_profile_test.rb`, add an `open_locker_editor` helper and use it in the three existing tests that edit an already-saved profile (blank floor rejected, floor-only change, locker cleared), which now have to open the disclosure first.
- [X] T033 [P] In `test/system/locker_profile_test.rb`, add a test that a user with saved details sees no form fields until the edit control is clicked, and that both fields appear once it is.
- [X] T034 [P] In `test/system/locker_profile_test.rb`, add a test that a rejected edit re-renders with the form open, the error shown, and the saved values still displayed.

**Checkpoint**: Verified in a browser in both states, and by the full suite below.

### Flaky-suite fix (reported by the stakeholder after this phase landed)

The suite went intermittently red — roughly one failure per two full runs, in a different test each
time. Root cause was **not** the feature: `log_in_as` was occasionally asserting on the login page
before the login round trip had landed, because Capybara's 2-second default wait is tight for
Selenium + Puma + Turbo. The failing test was simply whichever one lost the race.

- [X] T035 In `test/system/locker_profile_test.rb`, cut the redundant first save out of the rejected-edit test. It drove the disclosure through two Turbo navigations purely as setup — behaviour already covered by T023 and the model tests — and made the test fragile for no added coverage.
- [X] T036 In `test/system/locker_profile_test.rb`, have `open_locker_editor` wait for the revealed field so a caller cannot type into a disclosure that has not opened yet.
- [X] T037 In `test/application_system_test_case.rb`, raise `Capybara.default_max_wait_time` to 5 seconds, with a comment recording why. Measured 6/6 clean full-suite runs afterwards, against roughly 1-in-2 before.
- [X] T038 In `config/database.yml`, raise the **test-only** SQLite `timeout` to 15s. A separate, pre-existing flake (`SQLite3::BusyException: database is locked`, hit by a 001 lockout test) surfaced once during verification: system tests write from the server thread while the test thread holds a transaction open.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Quality gates from the project constitution that span all three stories above.

- [X] T024 [P] Run `bin/rubocop` and fix any offenses in the files touched by this feature (`app/models/user.rb`, `app/controllers/locker_profiles_controller.rb`, `app/views/home/*`, `config/routes.rb`, the new migration) — zero-warning gate per Constitution Principle I.
- [X] T025 [P] Review `app/views/home/_locker_profile_form.html.erb` for accessible field labels (each input has an associated `<label>`) and keyboard operability, per Constitution Principle III.
- [X] T026 Walk through all 4 scenarios in `quickstart.md` manually against a running `bin/rails server` instance and confirm each matches its expected outcome.
- [X] T027 Run `bin/rails test` and `bin/rails test:system` and confirm the full suite passes, including the pre-existing 001-user-authentication tests (no regressions) alongside all new tests from T005–T006, T009–T018, T022–T023.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 (T002 and T004 need the migrated columns). Blocks all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational. No dependency on User Story 2 or 3.
- **User Story 2 (Phase 4)**: Depends on Foundational. Its view task T021 builds on US1's T008, so in practice implement US1 first even though US2's controller/model work (T019) could start in parallel.
- **User Story 3 (Phase 5)**: Depends on User Story 2 being complete (T019–T021) — it adds tests only, no new code.
- **Polish (Phase 6)**: Depends on all desired user stories being complete.

### Within Each User Story

- Tests are written before the implementation tasks they cover, and MUST fail until the corresponding implementation task lands. T018 in particular must fail (no rescue exists yet) until T019 adds the `rescue ActiveRecord::RecordNotUnique` clause.
- Model/route changes before controller; controller before views that submit to it.

### Parallel Opportunities

- T003 and T004 (Phase 2) can run in parallel with each other and with T002 finishing, since they touch different files.
- All test tasks within a phase (e.g., T005–T006, T009–T018, T022–T023) are marked `[P]` and can be written in parallel — most touch only the shared test file but describe independent `test "..."` blocks with no shared mutable state; T018 is in its own new file so it is trivially parallel-safe.
- T024 and T025 (Polish) can run in parallel.

---

## Parallel Example: User Story 2

```bash
# Once Foundational (Phase 2) is done, these tests can be drafted together (all touch
# test/system/locker_profile_test.rb but as independent `test` blocks):
Task: "System test: two separate fields shown when no floor is saved"
Task: "System test: floor-only submission saves with no locker number"
Task: "System test: blank floor submission is rejected"
Task: "System test: duplicate locker number is rejected without disclosing the other user"
Task: "System test: saved values survive logout/login"

# And these model tests together (independent `test` blocks in test/models/user_test.rb):
Task: "Model test: blank floor doesn't block a save outside the locker_profile_update context"
Task: "Model test: nil locker_number never collides; a real duplicate does"
Task: "Model test: whitespace-only locker_number normalizes to nil"
Task: "Model test: a validation-bypassed duplicate still hits the DB unique index"

# This one is independent of the above (new file, no shared state):
Task: "Controller test: a forced RecordNotUnique produces the same user-facing message as a normal conflict"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (migration).
2. Complete Phase 2: Foundational (model rules, route, fixtures).
3. Complete Phase 3: User Story 1 — a user with existing data (e.g., seeded directly, no UI yet) sees it on the homepage.
4. **STOP and VALIDATE**: Run T005–T006 independently.

### Incremental Delivery

1. Setup + Foundational → schema and rules ready.
2. Add User Story 1 → validate independently → this alone already delivers visible value once any floor/locker data exists.
3. Add User Story 2 → validate independently → now a brand-new user can self-serve their own data (full MVP loop, since both are P1).
4. Add User Story 3 → validate independently → users can keep their profile accurate over time.
5. Polish → lint, accessibility, full suite, manual quickstart pass.
