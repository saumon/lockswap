---

description: "Task list for feature implementation"
---

# Tasks: Admin User Detail View

**Input**: Design documents from `/specs/027-admin-user-detail-view/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/admin-user-detail.md, quickstart.md (all present)

**Tests**: Included and REQUIRED. This repository's constitution (`.specify/memory/constitution.md`,
Principle II, NON-NEGOTIABLE) mandates a failing-first automated test for every new feature and bug
fix; nothing in this feature's spec exempts it.

**Organization**: Tasks are grouped by user story (spec.md's US1–US4, in priority order) to enable
independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)
- Every task names its exact file path(s)

## Path Conventions

Single Rails monolith at the repository root (`app/`, `config/`, `db/`, `test/`) — unchanged from
every prior feature; no new top-level directory.

---

## Phase 1: Setup

**Purpose**: The one shared schema change every later phase's audit-trail work depends on.

- [X] T001 Generate and write the migration: run
  `bin/rails generate migration AddAdminActionProvenanceToUsers` (timestamp will sort after the
  existing `20260921120000_create_site_language_settings.rb`), then fill it per data-model.md exactly:
  `add_reference :users, :locker_edited_by, foreign_key: { to_table: :users }`,
  `add_column :users, :locker_edited_at, :datetime`,
  `add_reference :users, :search_cancelled_by, foreign_key: { to_table: :users }`,
  `add_column :users, :search_cancelled_at, :datetime` — the same plain `add_reference` shape (no
  `on_delete:` option) `db/migrate/20260918113055_add_admin_grant_provenance_to_users.rb` already uses
  for `admin_granted_by_id`, since nullify-on-delete for these two new pairs is enforced at the
  application level in T002, not the database level (consistent with how `admin_granted_by_id`'s own
  nullify is already enforced via `has_many :admin_grants_made, dependent: :nullify` rather than a DB
  `ON DELETE`). Run `bin/rails db:migrate` and confirm `db/schema.rb` gained all four columns.

**Checkpoint**: Schema ready.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Model surface and the shared history-table partial that every user story phase below
either directly needs (US3, US4) or renders (US2).

**⚠️ CRITICAL**: No user story phase 3+ may begin until this phase is complete.

- [X] T002 [P] In `app/models/user.rb`, add:
  `belongs_to :locker_edited_by, class_name: "User", optional: true` and
  `belongs_to :search_cancelled_by, class_name: "User", optional: true` (the two new nullable
  provenance references, data-model.md), plus their inverse collections —
  `has_many :locker_edits_made, class_name: "User", foreign_key: :locker_edited_by_id, dependent: :nullify, inverse_of: :locker_edited_by`
  and
  `has_many :search_cancellations_made, class_name: "User", foreign_key: :search_cancelled_by_id, dependent: :nullify, inverse_of: :search_cancelled_by`
  — this pairing is what actually makes "an admin's account being later cancelled must not erase the
  fact that they once acted" (data-model.md, mirroring 015 FR-019) true; without it, deleting a `User`
  referenced by either new `_by_id` column raises a foreign-key violation instead of nullifying it,
  exactly the failure mode `admin_grants_made` already exists to prevent for `admin_granted_by_id`.
- [X] T003 [P] Extract the existing six-column table body (Direction/Person/Sent/Status/Comment/Locker
  details) out of `app/views/locker_swap_proposals/index.html.erb` into a new partial
  `app/views/locker_swap_proposals/_history_table.html.erb`, parameterized by three locals:
  `proposals:` (the collection), `viewer:` (replaces every `current_user` reference inside the table,
  e.g. `sent = proposal.requester_id == viewer.id`), and `dom_id_prefix:` (replaces the hardcoded
  `swap-proposal-history` in every row/cell/empty-state id, e.g.
  `id="<%= dom_id_prefix %>-row-#{proposal.id}"`, `id="<%= dom_id_prefix %>-empty"`). Update
  `app/views/locker_swap_proposals/index.html.erb` to render it as
  `render "locker_swap_proposals/history_table", proposals: @proposals, viewer: current_user, dom_id_prefix: "swap-proposal-history"`
  in place of the extracted markup (research.md R4). Run the existing
  `test/system/locker_swap_proposal_history_test.rb` (or whichever suite covers this screen) and
  confirm every assertion still passes unchanged — this is the regression evidence that the extraction
  changed no ids and no behavior on the self-service screen.

**Checkpoint**: Foundation ready — user story implementation can now begin.

---

## Phase 3: User Story 1 - Open a registered user's detail screen from the Users list (Priority: P1) 🎯 MVP

**Goal**: An admin-only detail screen exists and is reachable from a link on each Users-list row.

**Independent Test**: Sign in as an admin, click a row's link in `/admin/users`, confirm the detail
screen for that exact account opens; sign in as a non-admin (or sign out entirely) and confirm the
same address is refused.

### Tests for User Story 1 ⚠️

> Write these first; they must fail (route/action do not exist yet) before the implementation tasks below.

- [X] T004 [P] [US1] In `test/controllers/admin/users_controller_test.rb` (extend the existing file),
  add tests for `#show`: an admin viewing another account gets `200` with that account's data loaded;
  an admin viewing their own account also works (Edge Case: "the same ... capabilities apply to the
  administrator's own account"); a non-admin is redirected with `application.administrators_only`; a
  signed-out request is redirected to sign in; a request for a vanished (deleted) id is redirected to
  `admin_users_path` with the `account_gone` alert, not a 404.
- [X] T005 [P] [US1] Create `test/system/admin_user_detail_test.rb` with: an admin clicking a row's
  link in `/admin/users` lands on that specific account's detail screen (Acceptance Scenario 1); a
  non-admin requesting the detail address directly is refused (Scenario 2); a signed-out visitor
  requesting it directly is redirected to sign in (Scenario 3).

### Implementation for User Story 1

- [X] T006 [US1] In `config/routes.rb`, change `resources :users, only: :index do` to
  `resources :users, only: [ :index, :show ] do` inside the `namespace :admin do` block
  (contracts/admin-user-detail.md route table) — the existing `member { patch :grant_admin }` block is
  unchanged.
- [X] T007 [US1] In `app/controllers/admin/users_controller.rb`, add a `#show` action: `@user =
  User.includes(:admin_granted_by, :locker_edited_by, :search_cancelled_by,
  :locker_wish).find_by(id: params[:id])`; if `nil`, `redirect_to admin_users_path, alert:
  t(".account_gone")` (reuses the existing `ACCOUNT_GONE_MESSAGE`/`t(".account_gone")` pattern
  `#grant_admin` already uses on this same controller).
- [X] T008 [P] [US1] In `app/views/admin/users/index.html.erb`, change the email cell's content from
  plain `<%= user.email %>` to
  `<%= link_to user.email, admin_user_path(user), id: "admin-user-row-#{user.id}-detail-link" %>`
  (contracts/admin-user-detail.md "Row link" section; FR-001 — a distinct link, not a whole-row click
  handler, per Clarifications).
- [X] T009 [US1] Create `app/views/admin/users/show.html.erb` with a `.page-head`/`.page-title` (the
  account's email) and a `<div id="admin-user-detail" class="card stack-tight">` body containing a
  `<dl class="detail-grid">` (mirrors `home/_locker_profile.html.erb`'s `dt`/`dd` pattern) showing:
  email, role (reuse the exact badge + grant-provenance markup block already in
  `app/views/admin/users/index.html.erb`'s Role cell, including its `granted_by`/
  `granted_account_removed`/`first_registration` branches), registration date (`l user.created_at,
  format: :long`), current floor (`user.saved_floor.presence || t(".not_set")`, `detail-value-empty`
  when blank), current locker (`user.saved_locker_number.presence || t("home.locker_profile.no_locker_assigned")`,
  `detail-value-empty` when blank) — FR-003. Leave clear insertion points (HTML comments naming the
  requirement) for the search-status, editor, and history sections US2–US4 add.
- [X] T010 [P] [US1] Add `admin.users.show.*` keys (`title` reusing the account's email as an
  interpolated value or a static "User details" per existing heading conventions, `not_set`,
  `role_choices.admin`/`standard`, `granted_by`, `granted_account_removed`, `first_registration`,
  `joined_label`, `floor_label`, `locker_label`) to `config/locales/en.yml` and
  `config/locales/fr.yml`, following the nesting `admin.users.index.*` already uses one level up.

**Checkpoint**: User Story 1 is fully functional and independently testable — the screen exists, is
admin-only, and shows the same facts the Users list already shows.

---

## Phase 4: User Story 2 - See a user's full profile, locker search and proposal history in one place (Priority: P1)

**Goal**: The detail screen also shows the account's current search status (wish / active proposal(s)
/ neither) and its complete sent-and-received proposal history.

**Independent Test**: With one account holding a standing wish and another holding a full mix of
proposal statuses (sent and received), open each detail screen and confirm every fact is visible
without navigating elsewhere.

### Tests for User Story 2 ⚠️

- [X] T011 [P] [US2] In `test/controllers/admin/users_controller_test.rb`, add assertions that `#show`
  exposes the viewed account's standing wish (or its absence), every pending/accepted proposal it is
  party to in either role, and its complete sent+received proposal history sorted newest-first,
  including all five statuses (pending, accepted, declined, withdrawn, completed) — build the fixture
  data the existing fixtures don't already cover (a pending-or-accepted proposal and a
  wish-and-proposal-free account) directly in the test, per quickstart.md's note. Assert the query
  count for `#show` does not scale with the number of *other* accounts' proposals (Principle IV;
  research.md R5/R6 — two bounded queries per collection, unioned in Ruby, not one `OR`).
- [X] T012 [P] [US2] In `test/system/admin_user_detail_test.rb`, add: floor/locker shown match the
  Users list and the account's own homepage (Scenario 1); a standing wish shows which floor (Scenario
  2); an account with neither a wish nor an active proposal shows that plainly, not a blank area
  (Scenario 3); an account with proposals in every status shows each one with direction, counterparty,
  date, status, and outcome details, newest first (Scenario 4); an account with no proposals shows the
  "none" empty state, not an empty table (Scenario 5).

### Implementation for User Story 2

- [X] T013 [US2] In `app/controllers/admin/users_controller.rb#show`, add:
  `@active_proposals = (@user.sent_swap_proposals.where(status: [:pending, :accepted]).includes(:recipient).to_a + @user.received_swap_proposals.where(status: [:pending, :accepted]).includes(:requester).to_a)`
  and
  `@proposal_history = (@user.sent_swap_proposals.includes(:recipient).to_a + @user.received_swap_proposals.includes(:requester).to_a).sort_by(&:created_at).reverse`
  — the exact expression shape `LockerSwapProposalsController#index` already uses for `current_user`,
  applied to `@user` (research.md R5/R6; never a single `.or(...)` query on this table).
  (data-model.md "State shown on the detail screen").
- [X] T014 [P] [US2] Create `app/views/admin/users/_search_status.html.erb`: given `user:` and
  `active_proposals:` locals, render inside `<div id="admin-user-search-status">` — the standing wish
  (`t(".looking_for_floor", floor: user.locker_wish.saved_floor)`, reusing the exact wording
  `admin/users/index.html.erb` already uses) when `user.locker_wish` is present; each active proposal's
  `floor_and_locker_summary` when `active_proposals` is non-empty; otherwise
  `t(".no_search_in_progress")` with the `detail-value-empty` class (contracts/admin-user-detail.md
  "No-wish / no-active-proposal state").
- [X] T015 [US2] In `app/views/admin/users/show.html.erb`, render
  `<%= render "admin/users/search_status", user: @user, active_proposals: @active_proposals %>` and
  `<%= render "locker_swap_proposals/history_table", proposals: @proposal_history, viewer: @user, dom_id_prefix: "admin-user-detail-history" %>`
  (the partial extracted in T003) at the insertion points left by T009.
- [X] T016 [P] [US2] Add `admin.users.show.no_search_in_progress` and any section-heading keys the
  `_search_status` partial needs to `config/locales/en.yml` and `config/locales/fr.yml`.
- [X] T017 [US2] Update `test/fixtures/locker_swap_proposals.yml` only if T011/T012 need a
  pending-or-accepted proposal fixture the file doesn't already provide and building it in-test (per
  T011's own note) proves awkward to reuse across both the controller and system test — prefer
  building it in each test file first; only add a fixture if it removes real duplication between the
  two.

**Checkpoint**: User Stories 1 AND 2 both work independently — the screen is the single place to see
everything about an account.

---

## Phase 5: User Story 3 - Correct a user's current floor and assigned locker (Priority: P2)

**Goal**: An admin can edit an account's floor/locker from the detail screen via a pencil-icon control,
under the exact same validation rules (including the swap-lock) as a self-service edit, with the
change attributed to the acting admin.

**Independent Test**: Open an account's detail screen, activate the pencil icon, change floor and/or
locker, submit, and confirm the detail screen (and the Users list) reflect the new values and the
edit's provenance.

### Tests for User Story 3 ⚠️

- [X] T018 [P] [US3] In `test/models/user_test.rb`, add: assigning and saving `locker_edited_by`/
  `locker_edited_at` persists both; deleting the account referenced by another account's
  `locker_edited_by` nullifies that reference rather than raising or cascading (mirrors the existing
  `admin_granted_by` nullify test).
- [X] T019 [P] [US3] Create `test/controllers/admin/user_locker_profiles_controller_test.rb`: a valid
  `#update` changes the target account's floor/locker and sets `locker_edited_by`/`locker_edited_at` to
  the acting admin and now; a blank floor is refused with no data changed (FR-009, Acceptance Scenario
  4); a locker number already held on the same floor is refused with the exact
  `user.messages.locker_number_taken` message (Scenario 3); an account with a pending or accepted swap
  proposal is refused with the exact `user.messages.locked_by_swap` message — no admin bypass
  (Scenario 5, Clarifications); a vanished target account redirects with `account_gone`; a non-admin or
  signed-out request is refused.
- [X] T020 [P] [US3] In `test/system/admin_user_detail_test.rb`, add: the pencil icon reveals a form
  pre-filled with the account's current floor/locker (Scenario 1); submitting valid values updates the
  screen immediately and shows the edit's provenance line naming the acting admin and a timestamp
  (Scenario 2, FR-009a); the pencil icon and its form are operable by keyboard and the icon carries an
  accessible name (FR-012), mirroring the existing 009 axe-core coverage pattern for the homepage's own
  pencil icon.

### Implementation for User Story 3

- [X] T021 [US3] In `config/routes.rb`, inside the admin `resources :users` block, add
  `resource :locker_profile, only: :update, controller: "user_locker_profiles"` (nested under the
  member's `:user_id`, contracts/admin-user-detail.md route table).
- [X] T022 [US3] Create `app/controllers/admin/user_locker_profiles_controller.rb` with the same
  `before_action :authenticate_user!` / `before_action :require_admin!` pair as
  `Admin::UsersController`, and `#update`: `user = User.find_by(id: params[:user_id])`; redirect with
  `account_gone` alert if `nil`; `user.assign_attributes(params.expect(user: [ :floor, :locker_number
  ]))`; `user.locker_edited_by = current_user; user.locker_edited_at = Time.current`; then
  `user.save(context: :locker_profile_update)` inside a rescue for `ActiveRecord::RecordNotUnique` that
  adds `user.messages.locker_number_taken` to `errors` (mirrors
  `LockerProfilesController#save_locker_profile` exactly, target account instead of `current_user`).
  On success, `redirect_to admin_user_path(user), notice: t(".saved")`; on failure, re-render
  `admin/users/show` with `@user = user` and the editor `<details>` forced open, `status:
  :unprocessable_entity` (contracts/admin-user-detail.md).
- [X] T023 [P] [US3] Create `app/views/admin/users/_locker_profile_editor.html.erb`, adapted from
  `home/_locker_profile_form.html.erb` (009): a `<details>`/pencil-icon `<summary
  aria-label="<%= t('.edit_locker_details') %>">` disclosure, `open` when `user.errors.any?`,
  containing `form_with model: user, url: admin_user_locker_profile_path(user), method: :patch` with
  `floor`/`locker_number` fields pre-filled from `user.saved_floor`/`user.saved_locker_number`
  (no "I don't have a locker" shortcut — plain two-field form, same choice 009 made for its own pencil
  editor) and the `devise/shared/error_messages`-equivalent error partial for `user`.
- [X] T024 [US3] In `app/views/admin/users/show.html.erb`, render
  `<%= render "admin/users/locker_profile_editor", user: @user %>` next to the floor/locker fields from
  T009, and a `<p id="admin-user-locker-edit-provenance" class="meta">` shown only when
  `@user.locker_edited_at.present?`, reading (when `locker_edited_by` present)
  "Edited by `<email>` on `<date>`" and (when the editor account is gone) an "(account removed)"
  fallback — mirroring `granted_by`/`granted_account_removed` exactly (data-model.md).
- [X] T025 [P] [US3] Add `admin.users.show.edit_locker_details`,
  `admin.user_locker_profiles.update.saved`, and the provenance-line keys (`locker_edited_by`,
  `locker_edited_account_removed`) to `config/locales/en.yml` and `config/locales/fr.yml`.

**Checkpoint**: User Stories 1, 2 AND 3 all work independently.

---

## Phase 6: User Story 4 - Cancel a user's locker search on their behalf (Priority: P2)

**Goal**: An admin can cancel an account's standing wish from the detail screen, behind an explicit
confirmation step, with the cancellation attributed to the acting admin.

**Independent Test**: Open the detail screen of an account with a standing wish, confirm the
cancel-search action, and confirm the wish is gone from that screen, the account's own homepage, and
the locker wishes list.

### Tests for User Story 4 ⚠️

- [X] T026 [P] [US4] In `test/models/user_test.rb`, add: assigning `search_cancelled_by`/
  `search_cancelled_at` persists both; deleting the referenced admin account nullifies
  `search_cancelled_by` rather than raising or cascading.
- [X] T027 [P] [US4] Create `test/controllers/admin/user_locker_wishes_controller_test.rb`: `#destroy`
  on an account with a standing wish destroys it and sets `search_cancelled_by`/`search_cancelled_at`
  to the acting admin and now; on an account with no wish, is a no-op that still redirects with the
  success notice, not an error (Edge Cases: "already accomplished, not... an error"); leaves any
  pending/accepted swap proposal the account is party to completely unchanged (FR-011, Acceptance
  Scenario 4 — assert the proposal's `status`/`updated_at` are untouched); a vanished target account
  redirects with `account_gone`; a non-admin or signed-out request is refused.
- [X] T028 [P] [US4] In `test/system/admin_user_detail_test.rb`, add: the cancel-search button is
  visible only when the account has a standing wish, and absent otherwise (Acceptance Scenario 3);
  clicking it and dismissing the confirmation dialog leaves the wish untouched (Scenario 2a); clicking
  it and confirming removes the wish, updates the detail screen, and shows the cancellation's
  provenance (Scenario 2, FR-011a) — also assert the wish is gone from the account's own homepage and
  from `/locker_wishes`; the button is operable by keyboard and carries an accessible name (FR-012).

### Implementation for User Story 4

- [X] T029 [US4] In `config/routes.rb`, inside the admin `resources :users` block, add
  `resource :locker_wish, only: :destroy, controller: "user_locker_wishes"` (contracts/admin-user-detail.md
  route table).
- [X] T030 [US4] Create `app/controllers/admin/user_locker_wishes_controller.rb` with the same
  `authenticate_user!`/`require_admin!` guard pair, and `#destroy`: `user = User.find_by(id:
  params[:user_id])`; redirect with `account_gone` alert if `nil`; `if user.locker_wish` then
  `user.locker_wish.destroy` followed by `user.update_columns(search_cancelled_by_id: current_user.id,
  search_cancelled_at: Time.current)` (`update_columns`, not `save` — this is a plain audit-fact write
  that must not run through, or be blocked by, the `:locker_profile_update` validation context, per
  contracts/admin-user-detail.md); always `redirect_to admin_user_path(user), notice: t(".cancelled")`
  regardless of whether a wish existed.
- [X] T031 [US4] In `app/views/admin/users/show.html.erb`, add (only when `@user.locker_wish` present)
  a `button_to t(".cancel_search_button"), admin_user_locker_wish_path(@user), method: :delete, data: {
  confirm: t(".cancel_search_confirm", email: @user.email), turbo_confirm: t(".cancel_search_confirm",
  email: @user.email) }, aria: { label: t(".cancel_search_aria_label", email: @user.email) }, class:
  "btn btn-secondary btn-sm"` (mirrors the existing "Grant admin rights" confirm pattern on
  `admin/users/index.html.erb`, 015), and a `<p id="admin-user-search-cancel-provenance" class="meta">`
  shown only when `@user.search_cancelled_at.present?`, with the same present/account-removed fallback
  shape as the locker-edit provenance line (T024).
- [X] T032 [P] [US4] Add `admin.users.show.cancel_search_button`, `cancel_search_confirm`,
  `cancel_search_aria_label`, `admin.user_locker_wishes.destroy.cancelled`, and the provenance-line
  keys (`search_cancelled_by`, `search_cancelled_account_removed`) to `config/locales/en.yml` and
  `config/locales/fr.yml`.

**Checkpoint**: All four user stories are independently functional.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Verification the constitution requires beyond any single story's own tests.

- [X] T033 [P] Run the project's existing axe-core accessibility audit helper against
  `/admin/users/<id>` (extend whichever existing system test already calls it, e.g. alongside T020/T028,
  or add a dedicated assertion in `test/system/admin_user_detail_test.rb`) — quickstart.md Scenario 5.
- [X] T034 Run `bin/rails tailwindcss:build`; confirm it completes with no new CSS component required
  (research.md R2 — every visual element this feature uses already exists in
  `app/assets/tailwind/application.css`). Per CLAUDE.md's "How to check the work," write a throwaway
  system test that logs in as a fixture admin, visits a user's detail screen, calls
  `wait_for_entrance`, and `page.save_screenshot`s to `tmp/design/`; look at the image; delete the
  throwaway test.
- [X] T035 Run `test/i18n_completeness_test.rb` and confirm it passes with no changes needed beyond the
  keys added in T010/T016/T025/T032 (Constitution III's i18n gate).
- [X] T036 Run the full test suite (`bin/rails test` and `bin/rails test:system`) and confirm no
  regression in `test/system/admin_users_test.rb` (013/015/020), `test/controllers/admin/users_controller_test.rb`'s
  existing `#index`/`#grant_admin` coverage, or the proposal-history self-service suite touched by T003.
- [X] T037 Walk through `quickstart.md` Scenarios 1–4 manually (`bin/rails server`, sign in as `frank`)
  as final end-to-end validation before calling the feature done.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup (T001's migration must be applied before T002's
  associations reference the new columns). BLOCKS all user story phases.
- **User Stories (Phase 3–6)**: All depend on Foundational completion.
  - US1 (Phase 3) has no dependency on US2/US3/US4.
  - US2 (Phase 4) renders inside the screen US1 creates (`show.html.erb`) and reuses the partial T003
    extracted — implement after US1's T009 exists, but its own tests/logic are independent of US3/US4.
  - US3 (Phase 5) and US4 (Phase 6) each add their own section to `show.html.erb` and their own route
    +controller — independent of each other, both depend on US1's `show.html.erb` existing (T009) and
    Foundational's T002 (the columns they write to).
- **Polish (Phase 7)**: Depends on all four user stories being complete.

### Within Each User Story

- Tests (marked ⚠️) MUST be written and confirmed failing before that story's implementation tasks.
- Route → controller action → view partial → view wiring → i18n, in that order within each story,
  matching each phase's task ordering above.

### Parallel Opportunities

- T002 and T003 (Foundational) touch disjoint files — run in parallel.
- Within each story's Tests subsection, every task is marked [P] (disjoint test files) — run together.
- T008 (index.html.erb link) is independent of T007 (show action) — both [P] within US1's implementation.
- T023 (US3 editor partial) is independent of T022 (US3 controller) until T024 wires them together.
- i18n tasks (T010, T016, T025, T032) are each [P] within their own story, since each touches the same
  two locale files but at disjoint keys — sequence them relative to each other if the same PR touches
  more than one story at once, to avoid a merge conflict on the same two files.

---

## Parallel Example: User Story 1

```bash
# Tests together:
Task: "Controller test for Admin::UsersController#show in test/controllers/admin/users_controller_test.rb"
Task: "System test for row-link navigation and access control in test/system/admin_user_detail_test.rb"

# Implementation, once tests are failing:
Task: "Add row-link to app/views/admin/users/index.html.erb"
Task: "Add admin.users.show.* i18n keys to config/locales/en.yml and fr.yml"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup (T001).
2. Phase 2: Foundational (T002–T003).
3. Phase 3: User Story 1 (T004–T010).
4. **STOP and VALIDATE**: the detail screen exists, is admin-only, and shows the same facts the Users
   list already does — independently demoable even before US2–US4 land.

### Incremental Delivery

1. Setup + Foundational → schema and shared partial ready.
2. + User Story 1 → admin-only detail screen reachable (MVP).
3. + User Story 2 → the screen's actual point: search status + full proposal history in one place.
4. + User Story 3 → admin can fix a wrong floor/locker on the spot.
5. + User Story 4 → admin can cancel a stale search on the spot.

Each story adds a self-contained section to the same screen without breaking any prior story's tests —
the Dependencies section above names exactly which prior task each story's implementation touches.

---

## Notes

- [P] tasks touch different files and have no unmet dependency within their phase.
- Every implementation task cites the exact contracts/data-model.md decision it satisfies, so none of
  it is left to implementation-time discretion beyond what research.md already deferred (e.g. "where in
  the row" for FR-001, resolved here as the email cell — T008).
- Constitution Principle II is NON-NEGOTIABLE: do not skip the ⚠️ test tasks or reorder them after their
  story's implementation tasks.
- Commit after each task or logical group, consistent with how this repository's git history reads
  (one focused commit per requirement slice) rather than one commit per phase.
