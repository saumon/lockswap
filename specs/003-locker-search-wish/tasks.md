---

description: "Task list template for feature implementation"
---

# Tasks: Locker Search Wish

**Input**: Design documents from `/specs/003-locker-search-wish/`

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

**Purpose**: Create the new `locker_wishes` table.

- [X] T001 Generate and apply a migration `db/migrate/<timestamp>_create_locker_wishes.rb` that creates a `locker_wishes` table with `user_id` (integer, not null, foreign key reference to `users`) and `floor` (string, not null), plus a unique index on `user_id` (data-model.md: the DB unique index is what actually guarantees "at most one active wish per user" — FR-003 — even under two concurrent declare submissions for the same user; the application-level lookup alone is not race-safe). Run `bin/rails db:migrate` so `db/schema.rb` reflects the new table.

**Checkpoint**: `locker_wishes` table exists with `user_id` uniquely indexed and `floor` required.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Model-layer rules, association, and controller shell shared by every user story below. No user story can be implemented until this phase is done.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 Create `app/models/locker_wish.rb` with `belongs_to :user` and `validates :floor, presence: true` (data-model.md: floor is "Required (non-blank)"; Rails' `blank?` already treats a whitespace-only string as blank, so no extra trimming is needed to satisfy FR-007 and the "blank or only whitespace" Edge Case). Depends on: T001.
- [X] T003 [P] In `app/models/user.rb`, add `has_one :locker_wish, dependent: :destroy` (data-model.md — Associations: "a wish cannot outlive its user"). Depends on: T001.
- [X] T004 [P] Create `app/controllers/locker_wishes_controller.rb` with only `before_action :authenticate_user!` for now (no actions yet — each user story below adds its own), so FR-013 ("declaring, cancelling, and viewing MUST all be restricted to logged-in, registered users") is true from this controller's very first commit.
- [X] T005 [P] In `test/fixtures/locker_wishes.yml` (new file), add two fixtures reused across the user-story tests below: `bob_wish` (`user: bob`, `floor: "7"` — a wisher who already has both a floor and a locker number on file, per the existing `bob` fixture) and `carol_wish` (`user: carol`, `floor: "5"` — a wisher who has a floor but no locker, per the existing `carol` fixture). Depends on: T001 (table must exist).

**Checkpoint**: Table, model, association, controller shell, and shared fixtures are ready — user story implementation can now begin.

---

## Phase 3: User Story 1 - Declare that I'm looking for a locker on a floor (Priority: P1) 🎯 MVP

**Goal**: A logged-in user can click "I'm looking for a locker", be asked which floor, and submit it to record a wish — whether or not they have a locker assigned — with re-declaring updating the existing wish rather than creating a second one, and a blank floor rejected.

**Independent Test**: Log in as the `alice` fixture (no floor/locker on file) and as the `bob` fixture (floor + locker already on file); declare a wish as each and confirm both succeed and each account ends up with exactly one recorded wish; declare again as a user with an existing wish and confirm it updates in place; submit a blank floor and confirm it is rejected.

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T006 [P] [US1] System test in `test/system/locker_wish_test.rb`: logging in as `alice` (no floor/locker on file) and visiting `/locker_wishes` shows a "I'm looking for a locker" button with no floor field visible; clicking it reveals the floor field (Acceptance Scenario 1, FR-005, FR-006).
- [X] T007 [P] [US1] System test in `test/system/locker_wish_test.rb`: as `alice`, submitting the revealed form with a floor value (e.g. `"4"`) redirects back to `/locker_wishes` and shows her own wish recorded for floor `"4"` (Acceptance Scenario 2, FR-001).
- [X] T008 [P] [US1] System test in `test/system/locker_wish_test.rb`: logging in as `bob` (floor `"3"`, locker `"B12"` already on file) and declaring a wish for a different floor succeeds — already having a locker assigned does not block it (Acceptance Scenarios 3 & 4, FR-002).
- [X] T009 [P] [US1] System test in `test/system/locker_wish_test.rb`: submitting the form with the floor field left blank is rejected, the user is told the floor is required, and no wish is recorded (Acceptance Scenario 5, FR-007, Edge Case).
- [X] T010 [P] [US1] System test in `test/system/locker_wish_test.rb`: logging in as `carol` (fixture `carol_wish`, an existing wish for floor `"5"`) and declaring a new floor (`"6"`) via "Change floor" leaves exactly one wish for `carol`, now at `"6"` — never two (Acceptance Scenario 6, FR-004).
- [X] T011 [P] [US1] Model test in `test/models/locker_wish_test.rb`: a `LockerWish` with a blank or whitespace-only `floor` fails validation with an error on `:floor` (data-model.md — "Required (non-blank)"; FR-007, Edge Case).
- [X] T012 [P] [US1] Model test in `test/models/locker_wish_test.rb`: inserting two `LockerWish` rows for the same `user_id` while bypassing application validations (e.g. `insert_all`/direct SQL) raises `ActiveRecord::RecordNotUnique` — proving the DB unique index on `user_id` from T001, not just the controller's lookup, is the real guarantee behind FR-003/SC-003 (data-model.md — Persistence-layer backstop).
- [X] T013 [P] [US1] Test in `test/controllers/locker_wishes_controller_test.rb` (new file, `ActionDispatch::IntegrationTest`): with a signed-in user who has no wish yet, force the `create` action's save to raise `ActiveRecord::RecordNotUnique` (temporarily redefine `LockerWish#save` for the duration of the test, restoring it afterward — no mocking gem is present, mirroring `test/controllers/locker_profiles_controller_test.rb`), then `POST /locker_wish`, and assert the user ends up with exactly one `LockerWish` row holding the submitted floor rather than an error response — proving the rescue path folds the race into an update instead of surfacing a failure (data-model.md — Persistence-layer backstop, FR-004).

### Implementation for User Story 1

- [X] T014 [US1] In `config/routes.rb`, add `resources :locker_wishes, only: :index` and `resource :locker_wish, only: :create` (contracts/web-routes.md — `GET /locker_wishes`, `POST /locker_wish`). Depends on: T004.
- [X] T015 [US1] In `app/controllers/locker_wishes_controller.rb`, add an `index` action setting `@locker_wish = current_user.locker_wish || current_user.build_locker_wish`, and a `create` action: look up `current_user.locker_wish || current_user.build_locker_wish`, assign the submitted floor via `params.expect(locker_wish: [:floor])`, and save; on success redirect to `locker_wishes_path` with a confirmation flash; on validation failure, render `index` with status `:unprocessable_entity`; rescue `ActiveRecord::RecordNotUnique` by re-fetching `current_user.reload.locker_wish` and updating its `floor` to the submitted value instead of erroring (FR-001, FR-002, FR-004, FR-007; verified by T013). Depends on: T002, T014.
- [X] T016 [US1] Create `app/views/locker_wishes/_locker_wish_form.html.erb`: a single required `floor` text field, `form_with model: @locker_wish, url: locker_wish_path, method: :post`, pre-filled when editing an existing wish, rendering any validation errors from `@locker_wish.errors` (FR-006, FR-007). Depends on: T015.
- [X] T017 [US1] Create `app/views/locker_wishes/_locker_wish_panel.html.erb`: when `@locker_wish` is not persisted, a "I'm looking for a locker" `<details>`/`<summary>` disclosure that reveals `_locker_wish_form` only once clicked (FR-005); when it is persisted, show the wish's floor plus a "Change floor" disclosure around the same form partial — forced `open` when `@locker_wish.errors.any?`, mirroring 002's rejected-edit pattern so a rejected submission always has a visible form to correct it in (FR-004). Depends on: T016.
- [X] T018 [US1] Create `app/views/locker_wishes/index.html.erb` rendering `_locker_wish_panel` (the all-wishes list from User Story 2 is added in Phase 4). Depends on: T017.
- [X] T019 [US1] In `app/views/layouts/application.html.erb`, add a "Locker wishes" nav link to `locker_wishes_path`, shown only when `user_signed_in?`, so the page containing the "I'm looking for a locker" button is reachable from anywhere in the app (FR-005). Depends on: T014.

**Checkpoint**: User Story 1 is fully functional and independently testable — a user can declare, and re-declare, a wish from a reachable page.

---

## Phase 4: User Story 2 - See who is looking for a locker and where (Priority: P1)

**Goal**: A logged-in user can view every active wish, with the floor sought, the wishing user's email, and that user's current floor/locker number, so people can find each other and coordinate a swap.

**Independent Test**: With fixture wishes `bob_wish` and `carol_wish` present, plus a wish declared by `alice` (via User Story 1), log in as any user and confirm the list shows all three wishes with the correct floor, email, current floor, and current locker for each — including "Not set" and "No locker assigned" where applicable — and that an empty wish set renders as an empty list, not an error.

### Tests for User Story 2

- [X] T020 [P] [US2] System test in `test/system/locker_wish_test.rb`: logging in as any user and visiting `/locker_wishes` shows `carol_wish`'s row — floor `"5"` sought, `carol`'s email, current floor `"2"`, current locker "No locker assigned" (Acceptance Scenario 1, FR-011).
- [X] T021 [P] [US2] System test in `test/system/locker_wish_test.rb`: the same page shows `bob_wish`'s row with current floor `"3"` and current locker `"B12"` — the full-data case (Acceptance Scenario 1, FR-011).
- [X] T022 [P] [US2] System test in `test/system/locker_wish_test.rb`: logging in as `alice`, declaring a wish (reusing the User Story 1 flow), and reloading `/locker_wishes` shows her own row alongside `carol`'s and `bob`'s, with her current floor shown as "Not set" and current locker as "No locker assigned" — never as errors (Acceptance Scenarios 3 & 4, Edge Case).
- [X] T023 [P] [US2] System test in `test/system/locker_wish_test.rb`: with every `LockerWish` destroyed (`LockerWish.destroy_all` in the test setup), visiting `/locker_wishes` renders the list empty, not as an error (Acceptance Scenario 2).
- [X] T038 [P] [US2] System test in `test/system/locker_wish_test.rb`: after `carol` (fixture `carol_wish`, floor `"5"`) changes her floor to `"6"` via "Change floor", a different logged-in user (e.g. `bob`) reloading `/locker_wishes` sees carol's row updated to floor `"6"`, not the original `"5"` (FR-012 — "updated wishes show the new floor"). Depends on: T015, T024.

### Implementation for User Story 2

- [X] T024 [US2] In `app/controllers/locker_wishes_controller.rb`, extend the `index` action to add `@locker_wishes = LockerWish.includes(:user).order(created_at: :asc)` (research.md — Ordering the wish list; `includes` avoids N+1 queries across an unbounded number of rows, per Constitution Principle IV). Depends on: T015.
- [X] T025 [US2] Create `app/views/locker_wishes/_locker_wish_list.html.erb`: a table iterating `@locker_wishes`, showing the floor sought, `wish.user.email`, `wish.user.saved_floor.presence || "Not set"`, and `wish.user.saved_locker_number.presence || "No locker assigned"` per row (FR-011, Edge Case; reuses the exact 002 "No locker assigned" wording). Depends on: T024.
- [X] T026 [US2] In `app/views/locker_wishes/index.html.erb`, render `_locker_wish_list` below `_locker_wish_panel` (contracts/web-routes.md — Display contract). Depends on: T018, T025.

**Checkpoint**: User Stories 1 and 2 both work end-to-end together — a user can declare a wish and immediately see it, and everyone else's, in the list.

---

## Phase 5: User Story 3 - Cancel my locker search wish (Priority: P2)

**Goal**: A logged-in user with an active wish can cancel it, removing it from the list for every viewer; a user with no wish has nothing to cancel; a cancelled user can declare again as if for the first time.

**Independent Test**: Log in as `carol` (fixture `carol_wish`), cancel it, and confirm it no longer appears in the list for any viewer; confirm `carol` can then declare a new wish exactly as a first-time declare.

### Tests for User Story 3

- [X] T027 [P] [US3] System test in `test/system/locker_wish_test.rb`: logging in as `carol` (fixture `carol_wish`) and clicking "Cancel wish" redirects to `/locker_wishes` with her row no longer shown, whether viewed as herself or as any other user (Acceptance Scenario 1, FR-009, FR-010).
- [X] T028 [P] [US3] System test in `test/system/locker_wish_test.rb`: after cancelling, `carol` sees the original "I'm looking for a locker" button again (not "Change floor" / "Cancel wish"), and declaring a new floor succeeds exactly as a first-time declare (Acceptance Scenario 3).
- [X] T029 [P] [US3] Test in `test/controllers/locker_wishes_controller_test.rb`: `DELETE /locker_wish` for a signed-in user with no active wish (e.g. `alice` before declaring) is a no-op — no error raised, no `LockerWish` row affected, and the response still redirects to `/locker_wishes` (Acceptance Scenario 2).

### Implementation for User Story 3

- [X] T030 [US3] In `config/routes.rb`, extend the existing `resource :locker_wish` line to `only: [:create, :destroy]` so `DELETE /locker_wish` routes to `LockerWishesController#destroy` (contracts/web-routes.md). Depends on: T014.
- [X] T031 [US3] In `app/controllers/locker_wishes_controller.rb`, add the `destroy` action: `current_user.locker_wish&.destroy`, then redirect to `locker_wishes_path` with a confirmation flash (FR-009, FR-010; safe no-op verified by T029). Depends on: T030.
- [X] T032 [US3] In `app/views/locker_wishes/_locker_wish_panel.html.erb`, add a "Cancel wish" `button_to locker_wish_path, method: :delete` alongside the "Change floor" disclosure, shown only when the viewer has an active wish (FR-009). Depends on: T017, T031.

**Checkpoint**: All three user stories are independently functional; the full declare/view/cancel lifecycle works end-to-end.

---

## Phase 5b: Access Control Coverage (FR-013)

**Why**: FR-013 and its Edge Case ("anonymous visitor ... unavailable") require this feature's
declare/cancel/view actions to be unreachable by an unauthenticated visitor. No prior task
verifies this directly — `before_action :authenticate_user!` (T004) is trusted but never asserted
against. This needs all three routes to exist, so it runs after Phase 5.

- [X] T037 [P] System test in `test/system/access_control_test.rb` (extend the existing file, matching its style): an unauthenticated visitor who attempts `GET /locker_wishes`, `POST /locker_wish`, or `DELETE /locker_wish` is redirected to the login page for each (FR-013, Edge Case). Depends on: T014, T030 (all three routes must exist).

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Quality gates from the project constitution that span all three stories above.

- [X] T033 [P] Run `bin/rubocop` and fix any offenses in the files touched by this feature (`app/models/locker_wish.rb`, `app/models/user.rb`, `app/controllers/locker_wishes_controller.rb`, `app/views/locker_wishes/*`, `app/views/layouts/application.html.erb`, `config/routes.rb`, the new migration) — zero-warning gate per Constitution Principle I.
- [X] T034 [P] Review `app/views/locker_wishes/_locker_wish_form.html.erb` and `_locker_wish_panel.html.erb` for accessible field labels and keyboard operability of the `<details>` disclosures and the "Cancel wish" button, per Constitution Principle III.
- [X] T035 Walk through all 4 scenarios in `quickstart.md` manually against a running `bin/rails server` instance and confirm each matches its expected outcome.
- [X] T036 Run `bin/rails test` and `bin/rails test:system` and confirm the full suite passes, including all pre-existing 001/002 tests (no regressions) alongside all new tests from T006–T013, T020–T023, T027–T029, T037, T038.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 (T002 and T005 need the migrated table). Blocks all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational. No dependency on User Story 2 or 3.
- **User Story 2 (Phase 4)**: Depends on Foundational and on User Story 1's `index` action/view existing (T015, T018) since it extends both — same file, incremental build, not a hard behavioral coupling.
- **User Story 3 (Phase 5)**: Depends on Foundational and on User Story 1's routes/panel (T014, T017) since it extends both.
- **Access Control Coverage (T037)**: Depends on User Story 1 (T014) and User Story 3 (T030) — all three routes must exist to test all three redirects together.
- **Polish (Phase 6)**: Depends on all desired user stories being complete, plus T037.

### Within Each User Story

- Tests are written before the implementation tasks they cover, and MUST fail until the corresponding implementation task lands. T013 in particular must fail (no rescue exists yet) until T015 adds the `rescue ActiveRecord::RecordNotUnique` clause; T029 must fail until T031 adds the `destroy` action.
- Model/route changes before controller; controller before views that submit to it.

### Parallel Opportunities

- T002, T003, T004, T005 (Phase 2) can all run in parallel with each other — four different files.
- All test tasks within a phase (T006–T013, T020–T023, T038, T027–T029) are marked `[P]` and can be written in parallel — most touch only their shared test file but describe independent `test "..."` blocks with no shared mutable state; T013 and T029 are in their own new file so they are trivially parallel-safe.
- T037 is marked `[P]` and can be drafted in parallel with T038 (different files) once their respective dependencies land.
- T033 and T034 (Polish) can run in parallel.

---

## Parallel Example: User Story 1

```bash
# Once Foundational (Phase 2) is done, these tests can be drafted together (all touch
# test/system/locker_wish_test.rb but as independent `test` blocks):
Task: "System test: button reveals the floor field only once clicked"
Task: "System test: declaring a wish with no locker assigned succeeds"
Task: "System test: declaring a wish while already having a locker assigned succeeds"
Task: "System test: blank floor is rejected"
Task: "System test: re-declaring updates the existing wish rather than duplicating it"

# And these model/controller tests together (independent files/blocks):
Task: "Model test: blank/whitespace-only floor fails validation"
Task: "Model test: a validation-bypassed duplicate user_id still hits the DB unique index"
Task: "Controller test: a forced RecordNotUnique still leaves exactly one wish, updated"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (migration).
2. Complete Phase 2: Foundational (model, association, controller shell, fixtures).
3. Complete Phase 3: User Story 1 — a user can declare, and re-declare, a wish from a reachable page.
4. **STOP and VALIDATE**: Run T006–T013 independently.

### Incremental Delivery

1. Setup + Foundational → table and rules ready.
2. Add User Story 1 → validate independently → users can already record their own wish (not yet visible to others).
3. Add User Story 2 → validate independently → the list makes every declared wish useful to everyone (full MVP loop, since both are P1).
4. Add User Story 3 → validate independently → users can keep the wish list accurate over time.
5. Polish → lint, accessibility, full suite, manual quickstart pass.
