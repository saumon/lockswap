---

description: "Task list template for feature implementation"
---

# Tasks: Admin Role and User Directory

**Input**: Design documents from `/specs/013-admin-user-directory/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/admin-users.md, quickstart.md (all present)

**Tests**: NOT optional for this feature. The project constitution's Testing Standards principle is
marked NON-NEGOTIABLE ("Every new feature ... MUST include automated tests that fail without the
change and pass with it"), so every implementation task below is preceded by the failing test that
justifies it.

**Organization**: Tasks are grouped by user story (spec.md) to enable independent implementation and
testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on an incomplete task)
- **[Story]**: Which user story this task belongs to (US1, US2) — omitted for Setup/Foundational/Polish
- Every task names its exact file path

## Path Conventions

Single Rails monolith (see plan.md Project Structure) — `app/`, `config/`, `db/`, `test/` at the
repository root. No frontend/backend split, no new top-level directory.

---

## Phase 1: Setup

**Purpose**: Create the migration file this feature needs; no new dependency or tooling is required
(plan.md Technical Context — no new gem).

- [X] T001 Generate the migration skeleton: `bin/rails generate migration AddAdminToUsers admin:boolean`, creating `db/migrate/<timestamp>_add_admin_to_users.rb`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish the one durable fact both stories depend on — which account, if any, is the
administrator — race-safely and non-reassignably (research.md R1/R2), and stand up the guarded
`/admin/users` destination so User Story 1's navigation link has something real to point at
(contracts/admin-users.md).

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 In `db/migrate/<timestamp>_add_admin_to_users.rb`, set the column definition to `t.boolean :admin, null: false, default: false` and add the partial unique index `add_index :users, :admin, unique: true, where: "admin = 1"` (data-model.md — "NOT NULL, default false" column plus the partial unique index that is "the database-level guarantee behind FR-001/FR-002 that at most one account can ever be `admin: true` at a time")
- [X] T003 Run `bin/rails db:migrate` to apply the migration and regenerate `db/schema.rb`
- [X] T004 [P] In `test/fixtures/users.yml`, add `admin: true` explicitly to one fixture (e.g. `alice`), since fixtures bypass `before_create` and would otherwise never satisfy `current_user.admin?` in any test (research.md R6)
- [X] T005 [P] Write failing model tests in `test/models/user_test.rb`: the first `User` ever created has `admin?` true; a second, later-created `User` has `admin?` false (FR-001)
- [X] T006 Implement the bootstrap rule in `app/models/user.rb`: a `before_create` callback setting `self.admin = true if User.count.zero?` (FR-001) — makes T005 pass
- [X] T007 Write failing model tests in `test/models/user_test.rb`: (a) two `User` records saved concurrently each attempting `admin: true` leave exactly one `admin?` true, never both, never neither (FR-002, research.md R2); (b) destroying the administrator's account leaves no other account `admin?` true — no automatic reassignment (FR-011)
- [X] T008 In `app/models/user.rb`, rescue `ActiveRecord::RecordNotUnique` from the partial unique index added in T002 and retry the save with `admin: false` for the losing record (research.md R2) — makes the race half of T007 pass; the deletion half of T007 passes because no reassignment logic exists anywhere in the model
- [X] T009 [P] Write failing controller tests in `test/controllers/admin/users_controller_test.rb`: `GET /admin/users` as an anonymous visitor redirects to `new_user_session_path`; as a signed-in non-administrator it redirects to `root_path` with a flash `:alert` (FR-008, contracts/admin-users.md)
- [X] T010 [P] Add the route in `config/routes.rb`: `namespace :admin do resources :users, only: :index end` (contracts/admin-users.md — `GET /admin/users → admin/users#index`)
- [X] T011 [P] Add a protected `require_admin!` method to `app/controllers/application_controller.rb` that redirects to `root_path` with a flash `:alert` when `current_user` is not an administrator (research.md R3)
- [X] T012 Create `app/controllers/admin/users_controller.rb` with `before_action :authenticate_user!` then `before_action :require_admin!` and an empty `index` action, plus a minimal placeholder `app/views/admin/users/index.html.erb` so the route renders — makes T009 pass

**Checkpoint**: `User#admin?` is reliable and race-safe and never reassigned on deletion; `/admin/users` exists, is gated, and resolves for an administrator. Both user stories can now proceed.

---

## Phase 3: User Story 1 - The first account becomes the administrator (Priority: P1) 🎯 MVP

**Goal**: The administrator, and only the administrator, sees an "Admin" entry in the signed-in
navigation, opening onto a "Users" link — at every viewport (spec.md US1).

**Independent Test**: Register a first account, then a second, on an instance with no accounts yet;
confirm the first sees the Admin → Users entry and the second does not (spec.md US1 Independent Test).

### Tests for User Story 1

- [X] T013 (written; NOT EXECUTED — Chrome cannot start here, see T024. Verified instead at the rendering layer.) [P] [US1] Write failing system tests in `test/system/navigation_test.rb`: an administrator's navigation contains an "Admin" disclosure that reveals a "Users" link, at both phone and desktop viewport (FR-003, FR-005); a non-administrator's navigation contains no "Admin" entry at either viewport (FR-004)

### Implementation for User Story 1

- [X] T014 [US1] In `app/views/shared/_site_menu_items.html.erb`, add a nested `<details><summary>Admin</summary>` disclosure containing a single `Users` link to `admin_users_path`, rendered only when `current_user.admin?` is true (FR-003, FR-004, FR-005; research.md R4 — reuses the site's existing disclosure pattern) — makes T013 pass

**Checkpoint**: User Story 1 is fully functional and independently testable — this is the MVP slice.

---

## Phase 4: User Story 2 - The administrator reviews every registered account (Priority: P2)

**Goal**: Admin → Users lists every registered account, oldest first, the administrator's own row
carrying an explicit "Admin" label, with no way to edit, delete, promote, or demote anyone from the
screen (spec.md US2).

**Independent Test**: Signed in as the administrator, with several accounts registered, open
Admin → Users and confirm every account appears, identified by email, administrator's row included
and labeled (spec.md US2 Independent Test).

### Tests for User Story 2

- [X] T015 [P] [US2] Write failing controller tests in `test/controllers/admin/users_controller_test.rb`: `GET /admin/users` as the administrator returns every registered `User` (FR-006), ordered oldest first (FR-010), each identified by email (FR-007), with the administrator's own entry flagged distinctly from the rest (FR-012)
- [X] T016 (written; NOT EXECUTED — see T024) [P] [US2] Write a failing system test in `test/system/admin_users_test.rb`: Admin → Users displays every registered account oldest-first, each row showing its email, the administrator's row carrying a visible "Admin" label no other row has, and no edit/delete/promote/demote control anywhere on the page (FR-006, FR-007, FR-009, FR-010, FR-012)

### Implementation for User Story 2

- [X] T017 [US2] In `app/controllers/admin/users_controller.rb`, implement `index` to set `@users = User.order(:created_at)` — a single bounded query with no per-row queries (data-model.md — "List order (FR-010)") — contributes to T015 passing
- [X] T018 [US2] Build `app/views/admin/users/index.html.erb`: one row per entry in `@users`, each showing its email (FR-007), an explicit "Admin" label on the row where `admin?` is true (FR-012), in the order `@users` is already sorted in (FR-010), with no form, link, or button that edits, deletes, promotes, or demotes any account (FR-009) — makes T015 and T016 pass
- [X] T019 (written; NOT EXECUTED — see T024) [US2] Add the Users screen to the existing per-screen accessibility audit in `test/system/accessibility_test.rb` (Constitution III — "every screen is checked for accessibility on every test run")
- [X] T020 (written; NOT EXECUTED — see T024) [US2] Add the Users screen to the existing phone/desktop responsive-viewport sweep in `test/system/responsive_test.rb` (012 pattern — single breakpoint, no sideways scroll, real tap targets)

**Checkpoint**: User Stories 1 and 2 both work, independently and together.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Quality gates the constitution requires before merge (plan.md Constitution Check).

- [X] T021 [P] Run `bin/rubocop` and resolve any warning introduced by this feature (Constitution I — zero unresolved warnings)
- [X] T022 [P] Run `bin/brakeman` and resolve any new finding introduced by this feature (Constitution I / security)
- [X] T023 (PARTIAL — no browser available. Scenarios 1-2 verified headlessly through the real Devise signup path in test/controllers/registrations_controller_test.rb; scenario 3 by test/models/user_test.rb. The visual walkthrough remains undone.) Walk all three scenarios in `specs/013-admin-user-directory/quickstart.md` by hand against a running `bin/dev` instance
- [X] T024 (PARTIAL — `bin/rails test`: 124 runs, 0 failures. `bin/rails test:system` CANNOT RUN in this environment: Chrome and chromedriver are both missing libnspr4.so and installing it needs a root password, so all 190 system tests error at browser startup, including ones this branch never touched. CI is the first place they will execute.) Run `bin/rails test && bin/rails test:system` and confirm the full suite passes with no regressions
- [X] T025 Write `specs/013-admin-user-directory/PR.md` covering: which Core Principles from `.specify/memory/constitution.md` are engaged and how (call out Principle IV's recorded pagination-deferral exception explicitly, per Governance's requirement that an exception be "recorded in the pull request"), which existing UI patterns were reused (Principle III — the `<details>` disclosure, the flash/notification component), and before/after test counts (Principle II)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup (needs the migration file T001 created). Blocks both user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational only. Delivers the MVP.
- **User Story 2 (Phase 4)**: Depends on Foundational only — not on User Story 1 (the nav entry and the
  page it points to are separable; T015/T016 can be exercised by visiting `/admin/users` directly even
  before T014 exists). May run in parallel with Phase 3 if staffed separately.
- **Polish (Phase 5)**: Depends on both user stories being complete. T025 depends on T021-T024 (lint/security/quickstart/suite results feed the PR description).

### Within Each Phase

- Tests are written and confirmed failing before the implementation task that follows them.
- Within Foundational: the migration (T002-T003) precedes anything that reads the `admin` column
  (T004 onward); the model bootstrap (T005-T008) and the routing/controller skeleton (T009-T012) are
  otherwise independent of each other.

### Parallel Opportunities

- T004 and T005 (different files: fixtures vs. model test) once T003 has run.
- T009, T010, T011 (different files: controller test, routes, application controller) can proceed together. T012 requires T010 and T011 to exist (route + guard method); T009 must additionally be written and observed failing first, per TDD, not because T012 reads that file.
- T013 (US1) and T015/T016 (US2) can be written in parallel by different people once Foundational is done, since they touch different files.
- T021 and T022 (independent quality tools) can run together.

---

## Parallel Example: Foundational Phase

```bash
# Once T003 (migration applied) is done:
Task: "Add admin: true to a fixture in test/fixtures/users.yml"
Task: "Write failing model tests for first/second signup in test/models/user_test.rb"

# Independently, once T001 is done (route/controller skeleton doesn't need the model bootstrap):
Task: "Write failing controller guard tests in test/controllers/admin/users_controller_test.rb"
Task: "Add the admin namespace route in config/routes.rb"
Task: "Add require_admin! to app/controllers/application_controller.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational — this alone already proves the hardest, riskiest part (the
   race-safe, non-reassignable admin fact) works.
3. Complete Phase 3: User Story 1.
4. **STOP and VALIDATE**: run `test/system/navigation_test.rb`, confirm the Admin entry appears only
   for the first account — the MVP is a working recognition-and-visibility feature even though the
   destination it points to is still a placeholder.

### Incremental Delivery

1. Setup + Foundational → the admin fact and the guarded destination both exist.
2. Add User Story 1 → nav entry visible only to the administrator → demoable MVP.
3. Add User Story 2 → the Users destination now shows real content → full feature complete.
4. Polish → lint, security scan, quickstart walkthrough, full suite.

---

## Notes

- [P] tasks touch different files and have no dependency on another incomplete task in the same batch.
- Every FR-xxx / SC-xxx reference above traces back to `spec.md`; every R-prefixed reference traces to
  `research.md`.
- Commit after each task or logical group, per repository convention (see recent commit history).
- The single documented Constitution exception (deferred pagination on the Users list, Principle IV)
  needs no task here — it is a decision recorded in `plan.md`, not an outstanding piece of work.
