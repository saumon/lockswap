---

description: "Task list for feature implementation"
---

# Tasks: Admin Rights Controls on the User Detail Screen

**Input**: Design documents from `/specs/028-move-admin-grant-button/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md,
contracts/admin-user-rights-controls.md, quickstart.md (all present)

**Tests**: Included and REQUIRED. This repository's constitution (`.specify/memory/constitution.md`,
Principle II, NON-NEGOTIABLE) mandates a failing-first automated test for every new feature and bug
fix; nothing in this feature's spec exempts it.

**Organization**: Tasks are grouped by user story (spec.md's US1–US3, in priority order — all P1) to
enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US3)
- Every task names its exact file path(s)

## Path Conventions

Single Rails monolith at the repository root (`app/`, `config/`, `test/`) — unchanged from every prior
feature.

---

## Phase 1: Setup

No setup tasks are needed. This feature adds no new dependency, no migration, and no fixture the
existing suite lacks — `frank` (bootstrap admin), `grace` (granted admin, `admin_granted_by: frank`)
and `carol` (standard) already cover every account state every user story below needs (quickstart.md
Prerequisites).

---

## Phase 2: Foundational (Blocking Prerequisites)

No blocking prerequisites beyond Phase 1. This feature adds no shared schema, route, or partial that
more than one user story depends on before it can start — User Story 1 can begin immediately.

---

## Phase 3: User Story 1 - Grant admin rights from the account detail screen (Priority: P1) 🎯 MVP

**Goal**: The "Grant admin rights" control moves off `admin/users` (the list) onto `admin/users/:id`
(the detail screen). The list's Actions column is removed entirely, not left empty.

**Independent Test**: With an administrator account and a standard account registered, open the
standard account's detail screen, activate the grant control, validate the confirmation, and observe
the account is now marked as an administrator on both its own detail screen and its row back on the
Users list — which itself never showed the control.

### Tests for User Story 1 ⚠️ Write first; confirm they fail before implementing

- [X] T001 [P] [US1] In `test/system/admin_users_test.rb`, replace the existing grant-control tests
  (currently the tests at "the screen offers no control but the grant and its own filters", "the grant
  control is offered on standard rows...", "each grant control names the account...", "the confirmation
  names the account...", "declining the confirmation...", "accepting the confirmation grants the
  rights...", "a granted administrator reaches the screen and can grant rights onwards",
  "rights reach an account that is already signed in...", "a non-administrator who types the address is
  refused...", "the last administrator is stopped from cancelling...", "a grant survives the deletion of
  the administrator who made it") with a single assertion that **no row on the list carries any grant,
  revoke, or other administrator-rights control, and the table has no "Actions" column header at all**
  (spec.md FR-001, Acceptance Scenario 1) — the grant-flow coverage itself moves to T003 below. Keep
  every other existing test in this file unrelated to the grant control (row ordering, Admin label on
  the bootstrap administrator's own row, filters) unchanged.
- [X] T002 [P] [US1] In `test/controllers/admin/users_controller_test.rb`, update the existing
  `#grant_admin` tests (currently asserting `assert_redirected_to admin_users_path`) to assert
  `assert_redirected_to admin_user_path(users(:carol))` (or the relevant target) instead, for: "an
  administrator grants rights and is told it took effect", "granting to an account that is already an
  administrator reports success". The "granting to an account that no longer exists says so" test keeps
  asserting `assert_redirected_to admin_users_path` unchanged (there is no valid detail screen to return
  to). Delete the "the screen offers no control but the grant and its own filters" `#index` markup test
  from this file if a duplicate exists here (it is `test/system/admin_users_test.rb`'s job per T001); if
  this file has no such duplicate, skip that part.
- [X] T003 [P] [US1] In `test/system/admin_user_detail_test.rb` (extend the existing file), add the
  grant-flow coverage relocated from T001's removed tests, adapted to the detail screen: a grant control
  is offered on a standard account's detail screen and absent on an already-administrator account's
  detail screen (FR-002/FR-003); activating it presents a confirmation naming the account, stating it
  will gain administrator rights, **with no claim that this cannot be undone** (FR-004, research.md R7);
  declining leaves the account's rights unchanged and the control still usable; confirming promotes the
  account, and both its own detail screen and its row on `/admin/users` show the "Admin" badge
  afterward, with "Granted by `<granting admin's email>` on `<date>`" beneath it (Acceptance Scenario
  4).

### Implementation for User Story 1

- [X] T004 [US1] In `app/views/admin/users/index.html.erb`, delete the
  `<th scope="col" role="columnheader"><%= t(".actions_header") %></th>` header and its corresponding
  `<td role="cell" data-label="...">` cell (currently holding the "Grant admin rights" `button_to` or an
  em dash) from the row markup entirely — the table has six columns (Email, Joined, Floor, Locker, Wish,
  Role), not seven (research.md R6; contracts/admin-user-rights-controls.md "Users list").
- [X] T005 [P] [US1] In `app/views/admin/users/show.html.erb`, add the grant control next to the
  existing role `dt`/`dd` pair, shown only when `!@user.admin?`:
  `button_to t(".grant_button"), grant_admin_admin_user_path(@user), method: :patch, data: { confirm: t(".grant_confirm", email: @user.email), turbo_confirm: t(".grant_confirm", email: @user.email) }, aria: { label: t(".grant_aria_label", email: @user.email) }, class: "btn btn-secondary btn-sm"`
  (contracts/admin-user-rights-controls.md "Grant and revoke controls" — no
  `form: { data: { turbo_frame: "_top" } }` needed here, since this screen is not itself inside a
  turbo-frame, unlike the list).
- [X] T006 [US1] In `app/controllers/admin/users_controller.rb`: change `#grant_admin`'s success
  redirect from `redirect_to admin_users_path(filter_selections), notice: t(".granted", email:
  user.email)` to `redirect_to admin_user_path(user), notice: t(".granted", email: user.email)` (the
  account-gone branch's `redirect_to admin_users_path(filter_selections), alert: t(".account_gone")`
  becomes `redirect_to admin_users_path, alert: t(".account_gone")` — unchanged target, only the
  now-empty `filter_selections` call is dropped). Delete the private `filter_selections` method
  entirely — it has no remaining caller (research.md R2, data-model.md "Removed behavior"; Constitution
  I — dead code left in place is exactly the "unjustified complexity" the principle asks to refactor
  away).
- [X] T007 [P] [US1] In `config/locales/en.yml` and `config/locales/fr.yml`: delete
  `admin.users.index.actions_header`; move `admin.users.index.grant_confirm`, `grant_button`,
  `grant_aria_label` to `admin.users.show.*`; reword `grant_confirm` from
  `"Grant administrator rights to %{email}? This cannot be undone."` to
  `"Grant administrator rights to %{email}?"` (research.md R7 — the "cannot be undone" clause is no
  longer true once revoke exists) in both locales' equivalent wording.

**Checkpoint**: User Story 1 is fully functional and independently testable — the grant control lives
only on the detail screen, and the Users list carries no administrator-rights control at all.

---

## Phase 4: User Story 2 - Revoke admin rights from the account detail screen (Priority: P1)

**Goal**: An administrator can revoke another account's administrator rights from that account's detail
screen, behind a confirmation, with no audit trail of the revoke retained (self-exclusion is Phase 5,
US3 — this phase's controller/view logic offers the control to any currently-admin account, refined by
the next phase to exclude the signed-in administrator's own).

**Independent Test**: With two administrator accounts (`frank` and `grace`), sign in as `frank`, open
`grace`'s detail screen, activate the revoke control, validate the confirmation, and observe that
`grace`'s detail screen and her row on the Users list now show her as a standard account, with no grant
provenance line at all.

### Tests for User Story 2 ⚠️ Write first; confirm they fail before implementing

- [X] T008 [P] [US2] In `test/models/user_test.rb`, add tests for `User#revoke_admin_rights!`: calling
  it on an administrator account (e.g. `users(:grace)`) sets `admin` to `false` and clears both
  `admin_granted_at` and `admin_granted_by` to `nil` in one write (data-model.md, FR-009/FR-018); calling
  it on an account that is not currently an administrator (e.g. `users(:carol)`) is a no-op that raises
  no error and leaves the account a standard account (FR-014, mirrors `grant_admin_rights!`'s own
  already-admin no-op test); calling it on one account leaves every other account's `admin`/
  `admin_granted_at`/`admin_granted_by` untouched (FR-016). Also add: granting rights
  (`grant_admin_rights!`) to an account, revoking them (`revoke_admin_rights!`), then granting them
  again produces a *fresh* `admin_granted_at`/`admin_granted_by` — not the original grant's stale
  values — proving the clear-then-regrant cycle actually resets provenance rather than merely
  appearing to (spec.md Edge Cases, Assumptions; quickstart.md Scenario 2 steps 7–8).
- [X] T009 [P] [US2] In `test/controllers/admin/users_controller_test.rb`, add tests for
  `#revoke_admin`: an administrator (`frank`) revoking a different administrator's rights (`grace`)
  redirects to `admin_user_path(users(:grace))` with a non-nil `flash[:notice]`, and
  `users(:grace).reload.admin?` becomes `false` with `admin_granted_at`/`admin_granted_by` both `nil`
  afterward (FR-009, FR-012, FR-018); revoking rights from an account that is not currently an
  administrator (e.g. `users(:carol)`) redirects with a non-nil notice and no `flash[:alert]`, and
  leaves the account a standard account — not reported as a failure (FR-014); revoking a vanished
  account's rights redirects to `admin_users_path` with `Admin::UsersController::ACCOUNT_GONE_MESSAGE`
  (mirrors the existing `#grant_admin` "no longer exists" test, FR-013); a signed-out request to
  `revoke_admin_admin_user_path` redirects to sign in with no account's rights changed (FR-010); a
  signed-in non-administrator (`carol`) requesting it against another administrator is refused with
  `ApplicationController::ADMINISTRATORS_ONLY_MESSAGE` and no account's rights changed (FR-010). Also
  add a dedicated `"the revoke asks for no credential"` test, mirroring the existing `"the grant asks
  for no credential"` test (`test/controllers/admin/users_controller_test.rb:388`):
  `patch revoke_admin_admin_user_path(users(:grace))` with no password or other parameter beyond the
  target id succeeds and `users(:grace).reload.admin?` becomes `false` (FR-007).
- [X] T010 [P] [US2] In `test/system/admin_user_detail_test.rb`, add: a revoke control is offered on a
  different administrator's detail screen (viewing `grace`'s screen while signed in as `frank`) and
  absent on a standard account's detail screen (FR-005/FR-006, Acceptance Scenarios 1 and 6);
  activating it presents a confirmation naming the account and stating it will lose administrator rights
  (FR-007, Acceptance Scenario 2); declining or dismissing it leaves the account's rights unchanged
  (Acceptance Scenario 3); confirming revokes the rights, and both the target's own detail screen and
  its row on `/admin/users` show it as a standard account afterward, with no grant-provenance line
  remaining (Acceptance Scenario 4, FR-018).

### Implementation for User Story 2

- [X] T011 [US2] In `config/routes.rb`, inside the admin `resources :users do member do` block, add
  `patch :revoke_admin` alongside the existing `patch :grant_admin`
  (contracts/admin-user-rights-controls.md "Routes").
- [X] T012 [US2] In `app/models/user.rb`, add `revoke_admin_rights!` immediately after
  `grant_admin_rights!`/`admin_rights_granted?`, exactly as data-model.md specifies:
  ```ruby
  def revoke_admin_rights!
    return self unless admin?

    update!(admin: false, admin_granted_at: nil, admin_granted_by: nil)
    self
  end
  ```
- [X] T013 [US2] In `app/controllers/admin/users_controller.rb`, add `#revoke_admin`:
  `user = User.find_by(id: params[:id])`; `return redirect_to admin_users_path, alert:
  t(".account_gone") if user.nil?`; then `user.revoke_admin_rights!` followed by
  `redirect_to admin_user_path(user), notice: t(".revoked", email: user.email)` (the self-check that
  refuses revoking one's own rights is added in T017, Phase 5 — do not add it here).
- [X] T014 [P] [US2] In `app/views/admin/users/show.html.erb`, add the revoke control next to the grant
  control from T005, shown when `@user.admin?` (the `@user != current_user` exclusion is added in T018,
  Phase 5 — do not add it here):
  `button_to t(".revoke_button"), revoke_admin_admin_user_path(@user), method: :patch, data: { confirm: t(".revoke_confirm", email: @user.email), turbo_confirm: t(".revoke_confirm", email: @user.email) }, aria: { label: t(".revoke_aria_label", email: @user.email) }, class: "btn btn-secondary btn-sm"`
  (contracts/admin-user-rights-controls.md).
- [X] T015 [P] [US2] In `config/locales/en.yml` and `config/locales/fr.yml`, add under
  `admin.users.show.*`: `revoke_confirm: "Revoke %{email}'s administrator rights?"`,
  `revoke_button: "Revoke admin rights"`, `revoke_aria_label: "Revoke administrator rights from
  %{email}"`; add a new `admin.users.revoke_admin.*` namespace with `account_gone: "That account no
  longer exists."` and `revoked: "%{email}'s administrator rights have been revoked."`
  (`self_forbidden` is added in T019, Phase 5) — matching wording/nesting in both locale files
  (contracts/admin-user-rights-controls.md "i18n keys").

**Checkpoint**: User Story 2 is functional and testable against its own Acceptance Scenarios — an
administrator can revoke a *different* administrator's rights. (Self-revoke is not yet blocked; that
closes in Phase 5, required before this feature is complete end-to-end.)

---

## Phase 5: User Story 3 - An administrator cannot revoke their own rights (Priority: P1)

**Goal**: The revoke control refuses to act on the signed-in administrator's own account, both in the
view (never rendered) and in the controller (refused even by direct request) — closing the one path
that could otherwise leave the site with zero administrators.

**Independent Test**: Signed in as an administrator, open your own account's detail screen and confirm
no revoke control is present; separately, request `PATCH .../revoke_admin` directly against your own
account and confirm it is refused with your rights unchanged — verified for both the bootstrap
administrator and a granted one, so the rule is not special-cased to either.

### Tests for User Story 3 ⚠️ Write first; confirm they fail before implementing

- [X] T016 [P] [US3] In `test/controllers/admin/users_controller_test.rb`, add: `frank` (bootstrap
  admin) requesting `revoke_admin_admin_user_path(users(:frank))` against his own account is refused —
  redirected to `admin_user_path(users(:frank))` with a non-nil `flash[:alert]`, and
  `users(:frank).reload.admin?` stays `true` (FR-011, Acceptance Scenario 2); repeat the same request
  signed in as `grace` (granted admin) targeting her own account, with the same refusal, showing the
  rule is not special-cased to the bootstrap administrator (Acceptance Scenario 3 — "no special case
  that would let them remove the site's last administrator" generalizes to any administrator, not only
  a sole one).
- [X] T017 [P] [US3] In `test/system/admin_user_detail_test.rb`, add: an administrator viewing their own
  detail screen never sees a revoke control, even though the account is an administrator (Acceptance
  Scenario 1); this holds the same way whether they are the only administrator on the site or one of
  several (build both states in-test rather than assuming fixture order, per quickstart.md Scenario 3).

### Implementation for User Story 3

- [X] T018 [US3] In `app/controllers/admin/users_controller.rb#revoke_admin` (from T013), add the
  self-check before calling `revoke_admin_rights!`:
  ```ruby
  return redirect_to admin_user_path(user), alert: t(".self_forbidden") if user == current_user
  ```
  placed between the `account_gone` guard and the `revoke_admin_rights!` call
  (contracts/admin-user-rights-controls.md `#revoke_admin` body; research.md R3 — enforced
  independently of what the view renders).
- [X] T019 [P] [US3] In `app/views/admin/users/show.html.erb`, change the revoke control's condition
  from `@user.admin?` (T014) to `@user.admin? && @user != current_user` (research.md R3 — a
  view-level mirror of T018's controller check, not a substitute for it).
- [X] T020 [P] [US3] In `config/locales/en.yml` and `config/locales/fr.yml`, add
  `admin.users.revoke_admin.self_forbidden: "You cannot revoke your own administrator rights."` (and
  the French equivalent) to the namespace T015 created.

**Checkpoint**: All three user stories are independently functional. Combined, the feature is complete:
grant lives only on the detail screen, revoke works on any other administrator, and neither the view
nor the controller ever lets an administrator revoke their own rights.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verification the constitution requires beyond any single story's own tests.

- [X] T021 [P] Run the project's existing axe-core accessibility audit helper against
  `/admin/users/<id>` for an account showing both the grant and revoke controls in turn (extend
  whichever existing system test already calls it in `test/system/admin_user_detail_test.rb`) —
  confirms both new `button_to` controls carry accessible names and are keyboard-operable.
- [X] T022 Run `bin/rails tailwindcss:build`; confirm it completes with no new CSS component required
  (research.md R5 — every visual element this feature uses, `.btn`/`.btn-secondary`/`.btn-sm` and the
  `data-confirm`/`turbo_confirm` pattern, already exists). Per CLAUDE.md's "How to check the work,"
  write a throwaway system test that logs in as `frank`, visits `grace`'s detail screen (so both the
  role badge and the revoke control are visible), calls `wait_for_entrance`, and
  `page.save_screenshot`s to `tmp/design/`; look at the image; delete the throwaway test.
- [X] T023 Run `test/i18n_completeness_test.rb` and confirm it passes with no changes needed beyond the
  keys added/moved in T007/T015/T020 (Constitution III's i18n gate).
- [X] T024 Run the full test suite (`bin/rails test` and `bin/rails test:system`) and confirm no
  regression in `test/system/admin_users_test.rb`'s remaining (non-grant) coverage — row ordering, the
  bootstrap administrator's own Admin label, the four filters (013/015/020) — or in
  `test/controllers/admin/users_controller_test.rb`'s `#index`/`#show` coverage (013/027), which this
  feature does not touch.
- [X] T025 Walk through `quickstart.md` Scenarios 1–5 manually (`bin/rails server`, sign in as `frank`)
  as final end-to-end validation before calling the feature done.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** / **Foundational (Phase 2)**: No tasks — start User Story 1 immediately.
- **User Story 1 (Phase 3)**: No dependency on US2/US3. Independently shippable as the MVP.
- **User Story 2 (Phase 4)**: Depends on nothing from US1 functionally, but T005/T014 both edit
  `app/views/admin/users/show.html.erb` and T007/T015 both edit the same two locale files — sequence
  Phase 4 after Phase 3 to avoid the two phases conflicting on the same lines in the same PR.
- **User Story 3 (Phase 5)**: Depends on User Story 2 (T018 edits the `#revoke_admin` method T013
  created; T019 edits the condition T014 added) — must come after Phase 4.
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### Within Each User Story

- Tests (marked ⚠️) MUST be written and confirmed failing before that story's implementation tasks.
- Route → model → controller action → view → i18n, in that order within each story that has all five
  (US2); US1 and US3 omit whichever of those layers they do not touch.

### Parallel Opportunities

- Within each story's Tests subsection, every task is marked [P] (disjoint test files) — run together.
- T005 (show.html.erb grant control) and T007 (i18n) are [P] within US1's implementation; T006
  (controller) touches a third file and can run alongside them.
- T012 (model method), T014 (view), T015 (i18n) are [P] within US2's implementation; T011 (routes) and
  T013 (controller) are not [P] since T013 calls the route T011 adds and the model method T012 adds —
  sequence T011 → T012 → T013, with T014/T015 running alongside T012/T013.
- T019 (view) and T020 (i18n) are [P] within US3's implementation; T018 (controller) touches a third
  file and can run alongside them.

---

## Parallel Example: User Story 2

```bash
# Tests together:
Task: "Model tests for revoke_admin_rights! in test/models/user_test.rb"
Task: "Controller tests for #revoke_admin in test/controllers/admin/users_controller_test.rb"
Task: "System tests for the revoke control in test/system/admin_user_detail_test.rb"

# Implementation, once tests are failing:
Task: "Add revoke_admin_rights! to app/models/user.rb"
Task: "Add revoke control to app/views/admin/users/show.html.erb"
Task: "Add show.revoke_* and revoke_admin.* i18n keys to config/locales/en.yml and fr.yml"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 + 2: none.
2. Phase 3: User Story 1 (T001–T007).
3. **STOP and VALIDATE**: the Users list carries no administrator-rights control at all, and granting
   still works — now from the detail screen. Independently demoable even before revoke exists.

### Incremental Delivery

1. + User Story 1 → grant relocated, list lightened (MVP).
2. + User Story 2 → revoke works between different administrators.
3. + User Story 3 → self-revoke closed off; the feature is complete and safe to ship together with US2
   (US2 alone, without US3, is a real but intentionally incomplete increment — do not deploy Phase 4
   without Phase 5 behind it).

---

## Notes

- [P] tasks touch different files, or the same file at disjoint, non-overlapping edits, with no unmet
  dependency within their phase.
- Every implementation task cites the exact contracts/data-model.md/research.md decision it satisfies,
  so none of it is left to implementation-time discretion.
- Constitution Principle II is NON-NEGOTIABLE: do not skip the ⚠️ test tasks or reorder them after their
  story's implementation tasks.
- T005/T014/T019 all edit `app/views/admin/users/show.html.erb`; T006/T013/T018 all edit
  `app/controllers/admin/users_controller.rb`; T007/T015/T020 all edit both locale files. None of these
  same-file edits touch the same lines across phases (each phase adds to or narrows what the previous
  phase left), but commit each phase's edits before starting the next to keep the diff attributable to
  one user story at a time, consistent with how this repository's git history reads.
- **Found during implementation, not anticipated by this task list**: three test files outside the
  ones named above (`test/system/accessibility_test.rb`, `test/system/responsive_test.rb`,
  `test/system/admin_users_filter_test.rb`) also asserted against the old list-based "Grant admin
  rights" control (015/020's own coverage of it) and needed the same relocation treatment as T001/T002 —
  discovered by running the full suite (T024) rather than by the plan/contracts, since none of Phase
  0/1's design docs enumerated every existing test file touching this control. Fixed alongside T024:
  `accessibility_test.rb`'s list-only audit dropped its stale button assertion and its
  "distinguishable by name" test moved (as two focused aria-label assertions) to
  `admin_user_detail_test.rb`; `responsive_test.rb`'s phone-width list test dropped the button
  assertion and gained two new detail-screen phone-width tests (grant, revoke); `admin_users_filter_test.rb`'s
  "filters survive the grant redirect" test was deleted outright, since that capability (020 FR-016
  applied to grant) no longer exists once grant carries no filter state (research.md R2).
- A "granted administrator" (`grace`) system-test scenario is intermittently flaky in this environment
  — reproduced identically against the pre-028 codebase and in an unrelated, untouched test
  (`navigation_test.rb`), so it is a pre-existing environmental issue (headless Chrome/Selenium,
  confirmed not content- or logic-related), not a regression from this feature. A full `bin/rails
  test:system` run immediately after showed 0 failures. Controller-level coverage of the same scenario
  (e.g. "a granted administrator can grant rights in turn") is deterministic and passes every run.
