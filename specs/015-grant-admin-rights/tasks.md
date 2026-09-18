---

description: "Task list template for feature implementation"
---

# Tasks: Grant Administrator Rights

**Input**: Design documents from `/specs/015-grant-admin-rights/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/grant-admin.md, quickstart.md (all present)

**Tests**: NOT optional for this feature. The project constitution's Testing Standards principle is
marked NON-NEGOTIABLE and requires that every new feature include automated tests that fail without
the change and pass with it. Test tasks below are therefore mandatory, not illustrative, and each is
ordered before the implementation it constrains.

**Organization**: Tasks are grouped by user story (spec.md) to enable independent implementation and
testing. One phase (Phase 6) carries no story label because the requirement it implements — FR-016,
the last-administrator guard — came out of clarification and belongs to no single story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Single Rails project at repository root: `app/`, `config/`, `db/`, `test/`. Paths below are exact.

---

## Phase 1: Setup

**Purpose**: Create the migration file this feature needs. No new dependency, gem or tooling is
required — the confirmation reuses Turbo, already present.

- [X] T001 Generate the migration skeleton: `bin/rails generate migration AddAdminGrantProvenanceToUsers`, creating `db/migrate/<timestamp>_add_admin_grant_provenance_to_users.rb`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Make a second administrator possible at all, without losing 013's guarantee that the
automatic bootstrap reaches exactly one account. Every user story depends on this.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 In `db/migrate/<timestamp>_add_admin_grant_provenance_to_users.rb`, add the two provenance columns and swap the index. Columns, verbatim from data-model.md: `admin_granted_at` is `datetime`, **null: yes, no default** — "When administrator rights were granted. NULL means the rights were not granted... Never cleared once set"; `admin_granted_by_id` is `integer` (FK → `users.id`), **null: yes, no default**, declared with `foreign_key: { to_table: :users }` and a plain non-unique index — "Nullified when that account is deleted, so the grant survives its grantor". Then `remove_index :users, name: "index_users_on_admin"` and `add_index :users, :admin, unique: true, where: "admin = 1 AND admin_granted_at IS NULL", name: "index_users_on_bootstrap_admin"` (data-model.md "Index changed"; research.md R1)
- [X] T003 Run `bin/rails db:migrate` to apply the migration and regenerate `db/schema.rb`; confirm the new index appears as `index_users_on_bootstrap_admin` with the two-condition `WHERE` clause and that `index_users_on_admin` is gone
- [X] T004 [P] In `test/fixtures/users.yml`, add one granted-administrator fixture (not `alice` — she is signed in by most of the suite, and none of it is about administration; follow the reasoning already recorded above `frank`). Set `admin: true`, `admin_granted_at:` an explicit timestamp and `admin_granted_by_id:` pointing at `frank`, because fixtures are inserted straight into the database and run no callbacks (research.md R6). Setting `admin_granted_at` is also what keeps the row outside the bootstrap index — omit it and the whole suite fails at fixture load
- [X] T005 [P] Write failing model tests in `test/models/user_test.rb`: (a) two accounts may both be `admin?` when one carries `admin_granted_at` — the narrowed index permits it (FR-013); (b) two accounts with `admin: true` and `admin_granted_at` NULL still cannot coexist — the bootstrap slot is still unique (013 FR-002)
- [X] T006 [P] Write a failing regression test in `test/models/user_test.rb`: two `User` records saved concurrently on an empty table, each computing `admin: true`, still leave exactly one `admin?` true — the retry in `User#save` must fire against the **renamed** index. This is the sharpest edge in the feature: `ADMINISTRATOR_INDEX_CONFLICT` matches the index by name, so a rename without a matching regex update turns a lost race into a 500 at signup, visible only under concurrency (research.md R1)
- [X] T007 In `app/models/user.rb`, add `belongs_to :admin_granted_by, class_name: "User", optional: true, inverse_of: :admin_grants_made` and `has_many :admin_grants_made, class_name: "User", foreign_key: :admin_granted_by_id, dependent: :nullify, inverse_of: :admin_granted_by` (`:nullify` is what FR-019 rests on — `:destroy` here would delete every account an outgoing administrator ever promoted), and update `ADMINISTRATOR_INDEX_CONFLICT` to match `index_users_on_bootstrap_admin` alongside `users.admin` — makes T005 and T006 pass

**Checkpoint**: Several administrators can coexist, exactly one can still be minted automatically at first registration, and the signup race is still settled. User stories can now proceed.

---

## Phase 3: User Story 1 - An administrator promotes a standard account (Priority: P1) 🎯 MVP

**Goal**: From the Users list, an administrator grants rights to a standard account through a
confirmation naming that account, and the list then shows it as an administrator and records where
the rights came from.

**Independent Test**: With an administrator and one standard account registered, open Admin → Users,
activate the grant control, validate the confirmation, and observe the account marked administrator
with its provenance line — verifiable without ever signing in as the promoted person.

### Tests for User Story 1

- [X] T008 [P] [US1] Write a failing model test in `test/models/user_test.rb`: `User#grant_admin_rights!(by:)` sets `admin`, `admin_granted_at` and `admin_granted_by_id` in one write (FR-006, FR-017); called a second time on an account that is already an administrator it leaves `admin_granted_at` at its original value, so the recorded origin stays the first grant (FR-012, data-model.md "Transitions")
- [X] T009 [P] [US1] Write failing controller tests in `test/controllers/admin/users_controller_test.rb`: `PATCH /admin/users/:id/grant_admin` as an administrator promotes the target, redirects to `admin_users_path` and sets `flash[:notice]` (FR-006, FR-010, contracts/grant-admin.md); the granting administrator is still `admin?` afterwards (FR-013)
- [X] T010 [P] [US1] Write a failing controller test in `test/controllers/admin/users_controller_test.rb` asserting the query count of `GET /admin/users` does not grow with the number of granted administrators — the provenance line must not cost a query per row (plan.md Post-Design Constitution Check, Principle IV; research.md R5)
- [X] T011 [P] [US1] Write failing system tests in `test/system/admin_users_test.rb`: a grant button appears on every standard row and on no administrator row (FR-001, FR-002); its accessible name includes the account's email address rather than relying on row position (FR-015); the confirmation text names the account and states the grant cannot be undone (FR-003, FR-004); validating it promotes the account, shows a success notification, leaves no grant button on that row, and asks for no password (FR-006, FR-010, FR-020); the promoted row then reads `Granted by <email> on <date>` while the bootstrap administrator's reads `First registration` (FR-018); and the page offers no control that removes administrator rights, edits an account or deletes one — the negative assertion 013 carried (its T016) and which matters more now that the screen is no longer read-only (FR-014)

### Implementation for User Story 1

- [X] T012 [P] [US1] In `config/routes.rb`, add the member action to the existing admin users resource: `namespace :admin do resources :users, only: :index do member { patch :grant_admin } end end` (contracts/grant-admin.md "Route"; research.md R2 — the same named-member-action shape `locker_swap_proposals` already uses)
- [X] T013 [P] [US1] In `app/models/user.rb`, implement `grant_admin_rights!(by:)`: return self unchanged when already `admin?` (FR-012), otherwise `update!(admin: true, admin_granted_at: Time.current, admin_granted_by: by)`, recording both which administrator granted the rights and when (FR-017) — makes T008 pass
- [X] T014 [US1] In `app/controllers/admin/users_controller.rb`, add the `grant_admin` action calling `grant_admin_rights!(by: current_user)` and redirecting to `admin_users_path` with a `notice`. It inherits the existing `before_action :authenticate_user!` and `before_action :require_admin!`, so the write cannot drift from the read (contracts/grant-admin.md) — makes T009 pass
- [X] T015 [US1] In `app/controllers/admin/users_controller.rb`, change `index` to `@users = User.includes(:admin_granted_by).order(:created_at)` — makes T010 pass, and keeps the page two queries whether it lists three accounts or three hundred (research.md R5)
- [X] T016 [US1] In `app/views/admin/users/index.html.erb`, add a grant control to each row where `user.admin?` is false: a `button_to` to `grant_admin_admin_user_path(user)` with `method: :patch`, `data: { confirm: ..., turbo_confirm: ... }` carrying a message that names `user.email` and states the grant cannot be undone, and an `aria-label` naming the account. Mirror the existing "Cancel my account" button in `app/views/devise/registrations/edit.html.erb`, which emits both `confirm` and `turbo_confirm` (research.md R3; FR-001 to FR-005, FR-015)
- [X] T017 [US1] In `app/views/admin/users/index.html.erb`, extend the Role cell with the provenance line beneath the existing `Admin` badge — which stays exactly as 013 defines it, unchanged by how the rights were obtained (FR-008). Three cases, per contracts/grant-admin.md: `admin_granted_at` NULL → "First registration"; grantor present → "Granted by <email> on <date>"; grantor gone → "Granted on <date> (account removed)" (FR-018, FR-019). Use `l ..., format: :long`, as the Joined column already does, and keep the `data-label` attribute the responsive card form depends on (012 FR-005)
- [X] T018 [US1] Rewrite the header comment of `app/controllers/admin/users_controller.rb`: it currently states the screen is read-only "because there is no capability behind one" and routes to index alone (013 FR-009). That is now false. Replace it with what is true — granting is the one write, and it is the only one (FR-014)

**Checkpoint**: User Story 1 is fully functional and independently testable — this is the MVP slice.

---

## Phase 4: User Story 2 - The promoted account gains administrator capability (Priority: P2)

**Goal**: An account that was granted rights behaves exactly like any other administrator, including
being able to grant rights itself.

**Independent Test**: Sign in as a promoted account; confirm the "Admin" entry is present, the Users
list opens, and the grant control is offered on the remaining standard accounts.

**Expected to need no new production code.** Everything in the site keys off `current_user.admin?`,
which the grant sets — the navigation entry (`app/views/shared/_site_menu_items.html.erb`),
`require_admin!`, and the grant action itself. These tasks exist to prove that rather than assume it;
if any of them fails, the capability was gated on something narrower than `admin?` and that is exactly
what needs finding.

### Tests for User Story 2

- [X] T019 [P] [US2] Write failing controller tests in `test/controllers/admin/users_controller_test.rb`: a **granted** administrator (the T004 fixture, not the bootstrap one) passes `require_admin!` for both `GET /admin/users` and `PATCH /admin/users/:id/grant_admin`, and can promote a third account (FR-007, FR-013)
- [X] T020 [P] [US2] Write a failing system test in `test/system/admin_users_test.rb` (see Phase 7 note): signed in as a granted administrator, the navigation shows the "Admin" entry, Admin → Users opens and lists every account, and granting rights to a further standard account works end to end (FR-007)
- [X] T021 [P] [US2] Write a failing system test in `test/system/navigation_test.rb` (see Phase 7 note): a granted administrator's navigation carries the "Admin" disclosure at both phone and desktop viewport, indistinguishable from the bootstrap administrator's (FR-007, FR-008)

**Checkpoint**: Rights obtained by grant are proven identical to rights obtained at first registration.

---

## Phase 5: User Story 3 - Backing out, and keeping the control out of the wrong hands (Priority: P3)

**Goal**: The confirmation can be declined with no effect, and nobody who is not an administrator can
grant rights, whether or not they ever saw the control.

**Independent Test**: Decline the confirmation and verify nothing changed; then, signed in as a
standard account, aim the grant route at an account directly and verify it is refused.

### Tests for User Story 3

- [X] T022 [P] [US3] Write failing controller tests in `test/controllers/admin/users_controller_test.rb` for `PATCH /admin/users/:id/grant_admin`: an anonymous visitor is redirected to `new_user_session_path`; a signed-in non-administrator is redirected to `root_path` with `flash[:alert]` equal to `ApplicationController::ADMINISTRATORS_ONLY_MESSAGE`; in both cases the target account is still not an administrator afterwards (FR-009, contracts/grant-admin.md)
- [X] T023 [P] [US3] Write a failing controller test in `test/controllers/admin/users_controller_test.rb`: granting to an account that is already an administrator redirects with a **notice**, not an alert, and changes nothing — a stale list must not produce a failure (FR-012)
- [X] T024 [P] [US3] Write a failing controller test in `test/controllers/admin/users_controller_test.rb`: granting to an id that no longer exists redirects to `admin_users_path` with `flash[:alert]` saying the account no longer exists, and raises no error (FR-011)
- [X] T025 [P] [US3] Write a failing system test in `test/system/admin_users_test.rb` (see Phase 7 note): dismissing the confirmation dialog issues no request and leaves the account standard, and the control can then be used again successfully (FR-005)

### Implementation for User Story 3

- [X] T026 [US3] In `app/controllers/admin/users_controller.rb`, look the target up with `User.find_by(id: params[:id])` and, when it is missing, redirect to `admin_users_path` with an alert rather than letting `RecordNotFound` produce a 404 — makes T024 pass (FR-011)
- [X] T027 [US3] Confirm T022, T023 and T025 pass with no further production change: the refusal comes from the `require_admin!` already inherited from Phase 3, the no-op from the guard clause in `grant_admin_rights!` (T013), and the decline from the browser never issuing the request. If any of them fails, the guard is in the wrong place — fix it in `app/controllers/admin/users_controller.rb` or `app/models/user.rb` rather than adding a second check in the view

**Checkpoint**: All three user stories work, independently and together.

---

## Phase 6: The last administrator cannot walk out (FR-016)

**Purpose**: Granting is now the only way to gain rights and nothing removes them, so cancelling an
account became the only exit. This phase stops the exit that would leave nobody able to administer
the site. It carries no story label: the requirement came from the clarification session and serves
all three stories rather than any one of them.

- [X] T028 [P] Write failing model tests in `test/models/user_test.rb`: destroying the only administrator while other accounts remain is aborted and the record still exists (FR-016); destroying an administrator while another administrator remains succeeds; destroying a non-administrator always succeeds
- [X] T029 [P] Write a failing model test in `test/models/user_test.rb` for the case FR-016 deliberately lets through: the sole account on the site — administrator by definition — **can** be destroyed, because with no accounts left the bootstrap rule applies again to the next signup and there is nothing to be locked out of. Reasoning at research.md R4
- [X] T030 [P] Write a failing controller test in `test/controllers/registrations_controller_test.rb`: `DELETE /users` as the last administrator with other accounts registered leaves the account intact and sets `flash[:alert]` telling them to grant administrator rights to another account first (FR-016, contracts/grant-admin.md "Account cancellation contract")
- [X] T031 In `app/models/user.rb`, add the `before_destroy` guard: `throw :abort` when `admin?` and no other administrator exists and other accounts remain. It must run inside the destroy transaction, which `before_destroy` does — that is what makes the concurrent case safe, since Active Record opens SQLite transactions with `default_transaction_mode: :immediate` and SQLite permits one writer at a time, serializing two simultaneous cancellations (research.md R4). Add the refusal message as a frozen constant beside `LOCKED_BY_SWAP_MESSAGE`, following that precedent — makes T028 and T029 pass
- [X] T032 In `app/controllers/registrations_controller.rb`, override `destroy` to turn the aborted destroy into the site's existing failure notification (007) and a redirect, rather than a blank or misleading success — makes T030 pass
- [X] T033 [P] Write a failing system test in `test/system/admin_users_test.rb` (see Phase 7 note): an administrator cancels their account successfully while another administrator remains; the last one is refused with the reason on screen; after promoting someone, the cancellation succeeds
- [X] T034 [P] Write a failing system test in `test/system/admin_users_test.rb` (see Phase 7 note): after the granting administrator's account is deleted, the account they promoted still shows `Granted on <date> (account removed)` — the grant outlived its grantor (FR-019, exercising the `dependent: :nullify` from T007)

**Checkpoint**: The site cannot be left without an administrator through ordinary use (SC-007).

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: The quality gates the constitution requires before merge (plan.md Constitution Check).

- [X] T035 [P] Add the grant control and the provenance line to the existing per-screen accessibility audit in `test/system/accessibility_test.rb` (Constitution III)
- [X] T036 [P] Add the changed Users screen to the existing phone/desktop responsive-viewport sweep in `test/system/responsive_test.rb` — the Role cell now carries two lines, which is the case most likely to break the card form below the breakpoint (012 FR-005)
- [X] T037 [P] In `specs/013-admin-user-directory/spec.md`, add a note to FR-009 and FR-011 recording that both are superseded by feature 015 — 013 is shipped and still states the Users list is read-only and that a deleted administrator is never replaced, neither of which is true after this branch
- [X] T038 Run `bin/rubocop` and `bin/brakeman` and resolve every finding; a suppressed warning must carry an inline comment explaining why it is safe (Constitution I)
- [X] T039 Run `bin/rails test` and confirm the full suite passes with no regressions, paying particular attention to the fixture load — a mistake in T004 fails every test at once rather than one
- [X] T040 Run `bin/rails test:system` and confirm the whole suite passes. This task was written expecting the wall 013 hit (its T024: Chrome cannot start here), but that note was stale — Selenium Manager holds a working Chrome in `~/.cache/selenium` and `libnspr4.so` is installed, which `test/application_system_test_case.rb` already resolves. The suite runs here in roughly 140 seconds. `bin/ci` does **not** run it (its system step is commented out, `config/ci.rb:16`), so this task and `.github/workflows/ci.yml:122` are the only things that do
- [X] T041 Write `specs/015-grant-admin-rights/PR.md`, following the shape 013's T025 established. It MUST record: (a) the narrowing of FR-016 to the "other accounts remain" case — Governance requires an approved exception to be "recorded in the pull request", and this is the one this branch carries; (b) which Core Principles are engaged and how (Development Workflow); (c) the existing patterns reused rather than replaced — the "Cancel my account" confirmation, the 007 notification component, 013's `Admin` badge — which the Quality Gates' accessibility/consistency check requires in the PR description (Principle III); (d) the query-count evidence from T010, since the Users list gained a per-row association read (Principle IV); (e) before/after test counts (Principle II). Depends on T035–T040, whose results it reports

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)** → **Phase 2 (Foundational)**: the migration must exist before it can be filled in and applied.
- **Phase 2** blocks everything. Until the index is narrowed, a second administrator cannot be written at all, so no story's happy path can even be tested.
- **Phase 3 (US1)** is the MVP and depends only on Phase 2.
- **Phase 4 (US2)** depends on Phase 3 — there is no granted administrator to sign in as until granting works.
- **Phase 5 (US3)** depends on Phase 3 for the route and control, but not on Phase 4.
- **Phase 6 (FR-016)** depends on Phase 2 (for `dependent: :nullify` in T034) and on Phase 3 (promoting someone is the remedy the refusal points at). It is independent of Phases 4 and 5.
- **Phase 7 (Polish)** last. Within it, T041 depends on T035–T040: the PR description reports their results, so it cannot be written first.

### Within Each Phase

Test tasks come before the implementation they constrain, per Testing Standards. Inside Phase 2, T005
and T006 must fail before T007 is written, or the regression guard proves nothing.

### Parallel Opportunities

- T004, T005, T006 touch three different files with no dependency between them.
- T008 to T011 are four test files' worth of failing tests, all independent.
- T012 and T013 touch `config/routes.rb` and `app/models/user.rb` — parallel; T014 needs both.
- T019, T020, T021 are independent test files.
- T022, T023, T024, T025 are independent.
- T028, T029, T030 are independent; T033 and T034 are independent of each other.
- T035, T036, T037 touch three unrelated files.

**Not parallel, despite appearances**: T016 and T017 both edit
`app/views/admin/users/index.html.erb`. T014 and T015 both edit
`app/controllers/admin/users_controller.rb`, as does T018.

## Parallel Example: Foundational Phase

```sh
# Once T003 (migration applied) is done, these three touch different files:
#   T004  test/fixtures/users.yml
#   T005  test/models/user_test.rb   (narrowed index)
#   T006  test/models/user_test.rb   (race regression)
# T005 and T006 share a file — write them in one pass, or sequence them.
# T004 is genuinely parallel to both.
```

## Implementation Strategy

### MVP First (User Story 1 Only)

Phases 1 → 2 → 3 deliver the whole of what was asked for: a button on the Users list, a confirmation,
and the grant. Stopping there leaves a working, demonstrable feature. What it would lack is the proof
that promoted rights are real (Phase 4), the refusal tests (Phase 5), and the guard against the site
losing its last administrator (Phase 6) — the last of which is the one not to skip, because it is the
only irreversible state this feature can reach.

### Incremental Delivery

1. Phases 1–2: the schema can hold a second administrator. Nothing visible yet.
2. Phase 3: **MVP** — demo-able end to end.
3. Phase 4: proof the rights are real, no production code expected.
4. Phase 5: the refusals and the decline path.
5. Phase 6: the lockout guard.
6. Phase 7: gates, then PR.

## Notes

- [P] tasks touch different files and have no dependency on another incomplete task in the same batch.
- Every FR-xxx / SC-xxx reference above traces back to `spec.md`; every R-prefixed reference traces to `research.md`.
- Commit after each task or logical group, per repository convention (see recent commit history).
- T006 turned out to matter for a different reason than it was written for. On SQLite the error
  message names the column (`users.admin`), not the index, so the retry in `User#save` keeps working
  whether or not the pattern was updated — the risk is real only on another adapter. That is exactly
  why the pattern is tested directly rather than through a race.
- 013's T024 recorded that system tests could not run on this machine. That was no longer true, and
  checking rather than inheriting it is what turned 14 unverified tests into 14 verified ones — four
  of which were wrong.
- FR-016 deliberately lets one case through — the sole account on an otherwise empty site can still
  be cancelled. It is carried by T029 and reasoned at research.md R4. This began as a reading the
  plan imposed on the spec; the spec was amended to state it, so no divergence remains to review.
