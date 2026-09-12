---

description: "Task list for User Signup and Login"
---

# Tasks: User Signup and Login

**Input**: Design documents from `/specs/001-user-authentication/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/web-routes.md, quickstart.md

**Tests**: Included — the project constitution's Testing Standards principle (NON-NEGOTIABLE) requires
automated tests for every functional requirement, written before the implementation they verify.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of
each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Exact file paths are included in every description

## Path Conventions

Single Rails monolith at the repository root (`app/`, `config/`, `db/`, `test/`), per plan.md's
Project Structure — no separate frontend/backend split.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [X] T001 Initialize the Rails 8.1.3 app (Ruby 3.4.6) via `rails new . --database=sqlite3 --css=tailwind --skip-jbuilder` at the repository root, producing the `app/`, `config/`, `db/`, `test/` layout from plan.md
- [X] T002 Add the `devise` gem to `Gemfile`, run `bundle install`, then run `rails generate devise:install`
- [X] T003 [P] Confirm `.rubocop.yml` uses Rails 8's default `rubocop-rails-omakase` config as the zero-warning lint gate (research.md, constitution Code Quality)
- [X] T004 [P] Configure `config/database.yml` for the `sqlite3` adapter across development/test/production, with the production database file path on a persistent volume (plan.md Constraints)
- [X] T005 [P] Configure `Dockerfile` and `config/deploy.yml` (Kamal) for the containerized Linux target, mounting a persistent volume for the SQLite database file across deploys
- [X] T006 [P] Add a CI workflow (`.github/workflows/ci.yml`) that runs `bin/rails test`, `bin/rails test:system`, and `rubocop` on every pull request (constitution Quality Gates)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The `User` model, Devise configuration, routing, and shared layout that every user story depends on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T007 Run `rails generate devise User` to create the Devise migration and `app/models/user.rb`
- [X] T008 Edit the generated migration in `db/migrate/*_devise_create_users.rb` to match data-model.md exactly: `email` string, not null, with a unique (case-insensitive) index; `encrypted_password` string, not null; `remember_created_at` datetime, nullable (`:rememberable`); `failed_attempts` integer, not null, default `0`, and `locked_at` datetime, nullable (`:lockable`)
- [X] T009 Run `rails db:migrate` for the development and test environments
- [X] T010 Configure `config/initializers/devise.rb`: `config.password_length = 8..128` (FR-002); `config.lock_strategy = :failed_attempts`, `config.maximum_attempts = 5`, `config.unlock_strategy = :time`, `config.unlock_in = 15.minutes` (FR-011); `config.remember_for = 30.days` (FR-007)
- [X] T011 In `app/models/user.rb`, declare `devise :database_authenticatable, :registerable, :rememberable, :lockable, :validatable`
- [X] T012 [P] Configure `config/routes.rb` with `devise_for :users`
- [X] T013 [P] Build the shared Tailwind layout in `app/views/layouts/application.html.erb` (nav, flash messages, consistent styling — constitution User Experience Consistency)
- [X] T014 [P] Add a base test fixture in `test/fixtures/users.yml` with one valid account (email + a password hash valid for `:database_authenticatable`) for use across story tests

**Checkpoint**: Foundation ready — user story implementation can now begin

---

## Phase 3: User Story 1 - Create an account (Priority: P1) 🎯 MVP

**Goal**: A new visitor can create an account with an email address and a password of at least 8 characters; duplicate emails and short passwords are rejected with a clear message.

**Independent Test**: Submit the signup form with a new, valid email and an 8+ character password and confirm an account now exists; resubmitting the same email is rejected without creating a duplicate.

### Tests for User Story 1 ⚠️

> Write these tests FIRST; confirm they fail before the corresponding implementation task.

- [X] T015 [P] [US1] Write `test/models/user_test.rb`: email is required and must be a valid format; email must be unique case-insensitively (FR-003); password must be at least 8 characters (FR-002)
- [X] T016 [P] [US1] Write `test/system/signup_test.rb`: Acceptance Scenario 1 (valid signup creates the account and signs the user in) and Scenario 2 (duplicate email is rejected, no second account is created) from spec.md User Story 1

### Implementation for User Story 1

- [X] T017 [US1] Run `rails generate devise:views` to scaffold `app/views/devise/*`
- [X] T018 [US1] Build the Tailwind-styled signup form in `app/views/devise/registrations/new.html.erb`, extending the shared layout from T013
- [X] T019 [US1] Add `app/controllers/registrations_controller.rb` (subclassing `Devise::RegistrationsController`) and wire it via `devise_for :users, controllers: { registrations: "registrations" }` in `config/routes.rb`, confirming the post-signup redirect targets the homepage (FR-001, FR-005)
- [X] T020 [US1] Adjust `config/locales/devise.en.yml` so the duplicate-email and password-too-short messages are specific and actionable, per Acceptance Scenario 3 (FR-002, FR-003)

**Checkpoint**: User Story 1 is fully functional and independently testable — accounts can be created.

---

## Phase 4: User Story 2 - Log in and reach the homepage (Priority: P1)

**Goal**: A visitor with an existing account logs in and is taken straight to the homepage; the session persists up to 30 days; logging out ends it.

**Independent Test**: Using a fixture account, submit correct credentials on the login page and confirm the homepage renders immediately; confirm the session survives a reload; confirm logout then blocks homepage access.

### Tests for User Story 2 ⚠️

- [X] T021 [P] [US2] Write `test/system/login_test.rb`: Acceptance Scenario 1 (correct login → immediate homepage), Scenario 2 (session persists across reload/browser restart, up to 30 days — FR-007), Scenario 3 (logout ends the session — FR-009)
- [X] T022 [P] [US2] Write `test/system/access_control_test.rb`: an unauthenticated visit to `/` redirects to the login page (FR-008); an already-logged-in visitor hitting `/users/sign_up` or `/users/sign_in` is redirected to the homepage (FR-010, via Devise's default `require_no_authentication`)

### Implementation for User Story 2

- [X] T023 [US2] Create `app/controllers/home_controller.rb` with `before_action :authenticate_user!` and an `index` action (FR-008)
- [X] T024 [US2] Add `root to: "home#index"` in `config/routes.rb` and confirm Devise's default post-sign-in redirect targets the homepage (FR-005)
- [X] T025 [US2] Build `app/views/home/index.html.erb` using the shared Tailwind layout (constitution User Experience Consistency)
- [X] T026 [US2] Add a sign-out control to the shared layout in `app/views/layouts/application.html.erb` — `button_to "Log out", destroy_user_session_path, method: :delete`, rendered only when `user_signed_in?` (FR-009)
- [X] T027 [US2] Build the Tailwind-styled login form in `app/views/devise/sessions/new.html.erb`

**Checkpoint**: User Stories 1 and 2 both work independently — signup and login-to-homepage are complete.

---

## Phase 5: User Story 3 - Handle incorrect login attempts (Priority: P2)

**Goal**: Wrong credentials are rejected with a generic message; 5 consecutive failures lock the account for 15 minutes.

**Independent Test**: Submit an unknown email, then a correct email with a wrong password 5 times in a row, and confirm the account is locked to further attempts (including the correct password) until the cooldown elapses.

### Tests for User Story 3 ⚠️

- [X] T028 [P] [US3] Write `test/system/login_failure_test.rb`: Acceptance Scenario 1 (unknown email) and Scenario 2 (wrong password) both render the identical generic "Invalid Email or password." message (FR-006)
- [X] T029 [P] [US3] Write `test/system/account_lockout_test.rb`: Acceptance Scenario 3 — 5 consecutive failed attempts lock the account; a 6th attempt with the *correct* password still fails during the cooldown (FR-011, SC-006); use Rails time-travel helpers to verify the Edge Case that the account accepts logins again, with the failure count reset, once the 15-minute cooldown elapses

### Implementation for User Story 3

- [X] T030 [US3] Adjust `config/locales/devise.en.yml` so the `devise.failure.invalid` and `devise.failure.locked` keys render the same generic message, so a locked account never reveals more than "Invalid Email or password." (FR-006 applied to the locked case)
- [X] T031 [US3] Style the login form's failure/lockout flash message in `app/views/devise/sessions/new.html.erb` consistently with the rest of the form (constitution User Experience Consistency)

**Checkpoint**: All three user stories are independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that span multiple user stories

- [X] T032 [P] Run `rubocop` across the app and resolve every warning (constitution Code Quality gate — zero unresolved warnings)
- [X] T033 [P] Accessibility pass on the signup, login, and homepage views: label associations, keyboard navigation, sufficient contrast (constitution User Experience Consistency)
- [X] T034 Run the full `specs/001-user-authentication/quickstart.md` validation checklist end-to-end
- [X] T035 Record signup and login-to-homepage timing (manual stopwatch or `bin/rails runner` script) against SC-001 (<2 min), SC-002 (<10s), and the plan.md p95<300ms target; include the results in the pull request description per the constitution's Performance Requirements gate
- [X] T036 [P] Add a setup section to `README.md` (bundle install, `db:prepare`, `bin/dev`) referencing quickstart.md
- [X] T037 Verify the Docker image builds (`docker build .`) and that `kamal deploy` mounts a persistent volume for the SQLite file across deploys (plan.md Constraints)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - US1 and US2 are both P1 and have no dependency on each other's UI, but share the Foundational `User` model/routes
  - US3 (P2) builds on the login flow introduced by US2 (reuses `app/views/devise/sessions/new.html.erb`)
- **Polish (Phase 6)**: Depends on all three user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) — no dependency on US2/US3
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) — independently testable with a fixture account, though it shares the login view file with US3
- **User Story 3 (P2)**: Can start after Foundational (Phase 2); its implementation tasks (T030-T031) edit the same login view/locale file US2 creates (T027), so within a single-developer workflow, complete US2 first to avoid rework

### Within Each User Story

- Tests are written first and MUST fail before their implementation task
- Model/config tasks before view tasks; view tasks before controller-behavior verification

### Parallel Opportunities

- T003, T004, T005, T006 (Setup) can run in parallel
- T012, T013, T014 (Foundational) can run in parallel once T007-T011 are done
- T015 and T016 (US1 tests) can run in parallel
- T021 and T022 (US2 tests) can run in parallel
- T028 and T029 (US3 tests) can run in parallel
- T032, T033, T036 (Polish) can run in parallel
- Once Foundational (Phase 2) is complete, US1 and US2 can be staffed in parallel by different developers; US3 is best sequenced after US2 since it edits the same login view

---

## Parallel Example: User Story 1

```bash
# Launch both tests for User Story 1 together:
Task: "Write test/models/user_test.rb per T015"
Task: "Write test/system/signup_test.rb per T016"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Run T015-T016, confirm signup works end-to-end
5. Deploy/demo if ready — note that without US2, there is no way to log back in via the UI yet, so the MVP here is "accounts can be created," not a full login loop

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → account creation works
3. Add User Story 2 → Test independently → full signup-to-homepage loop works (MVP for the feature as specified)
4. Add User Story 3 → Test independently → brute-force protection in place
5. Polish → lint, accessibility, quickstart validation, deployment verification

---

## Notes

- [P] tasks touch different files with no unmet dependencies
- [Story] label maps each task to its user story for traceability
- Verify each story's tests fail before implementing that story
- Commit after each task or logical group
- Stop at any checkpoint to validate a story independently
