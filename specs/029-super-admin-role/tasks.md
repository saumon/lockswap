---

description: "Task list for feature implementation"
---

# Tasks: Super Admin Role and Exclusive Danger Zone Access

**Input**: Design documents from `/specs/029-super-admin-role/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md,
contracts/super-admin-access.md, quickstart.md (all present)

**Tests**: Included and REQUIRED. This repository's constitution (`.specify/memory/constitution.md`,
Principle II, NON-NEGOTIABLE) mandates a failing-first automated test for every new feature and bug
fix; nothing in this feature's spec exempts it.

**Organization**: Tasks are grouped by user story (spec.md's US1–US4, in priority order — US1/US2 are
P1, US3/US4 are P2) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)
- Every task names its exact file path(s)

## Path Conventions

Single Rails monolith at the repository root (`app/`, `config/`, `test/`) — unchanged from every prior
feature.

---

## Phase 1: Setup

No setup tasks are needed. This feature adds no new dependency, no migration, and no fixture the
existing suite lacks — `frank` (the site's sole bootstrap administrator, i.e. today's un-named super
admin), `grace` (a granted, standard admin) and `carol` (a standard, non-admin account) already cover
every account state every user story below needs (quickstart.md Prerequisites; data-model.md).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The one derived fact every other user story reads — `User#super_admin?` — must exist before
US2, US3, or US4 can be implemented or tested. US1 itself is delivered here (research.md R1: no
migration, no new column; the predicate alone is the whole of "the first registrant is the super
admin").

**⚠️ CRITICAL**: No later phase can begin until T001–T002 are complete.

- [X] T001 [P] In `test/models/user_test.rb`, immediately after the existing `"the first account ever
  created is the administrator"` test (around line 260), add: `super_admin?` is `true` for the account
  created on an empty site (`User.destroy_all; first = User.create!(...); assert_predicate first,
  :super_admin?`), and `false` for the next account created afterward (mirrors the existing `"an account
  created after the first is not an administrator"` test immediately below it, FR-002/FR-003). Also add,
  near the existing `grant_admin_rights!`/`admin_rights_granted?` tests (around line 480): granting
  admin rights to a standard account (e.g. `users(:carol).grant_admin_rights!(by: users(:frank))`)
  leaves `super_admin?` `false` on that account (FR-001 — granted rights are never super admin rights).
  Also add: `users(:frank).super_admin?` is `true` and `users(:grace).super_admin?` is `false` on the
  fixtures as loaded, with a comment noting this is the retroactive-promotion claim (FR-013) holding
  with zero code path executed beyond the predicate itself, since `frank` is fixture data, not a runtime
  registration (data-model.md, research.md R1).
- [X] T002 In `app/models/user.rb`, add `super_admin?` immediately after `admin_rights_granted?` (around
  line 165):
  ```ruby
  # 029 FR-001/FR-003: the account index_users_on_bootstrap_admin already guarantees is unique —
  # admin_granted_at is nil only for the account claim_administrator_if_first promoted, never for one
  # grant_admin_rights! promoted (research.md R1). No new column: this predicate is the existing
  # invariant, named.
  def super_admin? = admin? && admin_granted_at.nil?
  ```
  (data-model.md "New derived attribute"; contracts/super-admin-access.md "The predicate".)

**Checkpoint**: `super_admin?` exists and is proven correct in isolation — every later phase can now
call it.

---

## Phase 3: User Story 1 - The first account becomes the site's super admin automatically (Priority: P1) 🎯 MVP

**Goal**: The account created by the very first registration on the site is, from that moment, both a
standard admin and the super admin — automatically, with no manual step — and no later registration is
ever a candidate for the role. On the already-running site, the account that already holds bootstrap
administrator status becomes the super admin the instant this feature ships.

**Independent Test**: On a site with zero accounts, register once; the resulting account answers `true`
to both `admin?` and `super_admin?`. Register a second account; it answers `false` to both. Separately,
confirm today's existing bootstrap-administrator fixture (`frank`) already answers `true` to
`super_admin?` with no data migration run (quickstart.md Scenarios 1–2).

### Tests for User Story 1 ⚠️ Write first; confirm they fail before implementing

- [X] T003 [US1] T001 above already is this story's test coverage — `super_admin?` true for the first
  registrant, false for the second, true for the existing bootstrap fixture with no migration. No
  additional test file or case is needed: US1's entire acceptance criteria is the predicate's own
  definition (research.md R1 — there is no separate "assignment" step to test beyond `super_admin?`
  itself and the unchanged `claim_administrator_if_first` callback it reads). Confirm T001's new
  assertions fail before T002 lands (`super_admin?` is undefined) and pass once it does.

### Implementation for User Story 1

- [X] T004 [US1] No implementation task beyond T002 (Phase 2) — this is what Phase 2/3 sharing the same
  deliverable looks like when a "role" is a predicate over existing, unchanged columns rather than a new
  write path (research.md R1, plan.md Summary). Nothing here assigns, migrates, or backfills anything.

**Checkpoint**: User Story 1 is complete and independently verified — every later story can now rely on
exactly one account, ever, answering `true` to `super_admin?`.

---

## Phase 4: User Story 2 - The danger zone is exclusive to the super admin (Priority: P1)

**Goal**: `Admin::DangerZoneController` and `Admin::AllowedEmailDomainsController` refuse anyone who is
not the super admin — including a standard admin who used to be let through — whether reached through
the Admin menu or addressed directly. The Admin menu itself stops offering "Zone de danger" to a
standard admin while continuing to offer "Users" to them.

**Independent Test**: Signed in as `grace` (a standard, granted admin), the Admin menu shows "Users" but
not "Danger Zone"; `GET /admin/danger_zone`, `PATCH /admin/danger_zone`,
`POST /admin/allowed_email_domains`, and `DELETE /admin/allowed_email_domains/:id` are all refused with
the same "administrators only" redirect a non-admin already gets. Signed in as `frank` (the super
admin), all four keep working exactly as before.

### Tests for User Story 2 ⚠️ Write first; confirm they fail before implementing

- [X] T005 [P] [US2] In `test/controllers/admin/danger_zone_controller_test.rb`, replace the existing
  test `"a granted administrator is let through too"` (which currently signs in as `users(:grace)` and
  asserts `assert_response :success` on `GET admin_danger_zone_path`) with
  `"a granted administrator who is not the super admin is refused"`, asserting `assert_redirected_to
  root_path` and `assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, flash[:alert]` for
  the same request signed in as `grace` — this is the test whose premise this feature deliberately
  inverts (FR-005/FR-006, research.md R2/R3). Add the same pattern for `PATCH admin_danger_zone_path`
  (params: `{ site_language_setting: { language: "fr" } }`) signed in as `grace`, asserting the same
  redirect/alert and that `SiteLanguageSetting.current.language` is unchanged (mirrors the existing
  `"a signed-in non-administrator cannot change the language"` test, applied to a standard admin instead
  of a non-admin).
- [X] T006 [P] [US2] In `test/controllers/admin/allowed_email_domains_controller_test.rb`, add two new
  tests under the existing "User Story 3: the refusals" section, mirroring the existing
  `"a signed-in non-administrator cannot add a domain and is told why"` /
  `"a signed-in non-administrator cannot remove a domain and so cannot reopen registration"` tests but
  signed in as `users(:grace)` instead of `users(:carol)`: `"a signed-in standard admin cannot add a
  domain and is told why"` (`assert_no_difference -> { AllowedEmailDomain.count }`,
  `assert_redirected_to root_path`, `assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE,
  flash[:alert]`) and `"a signed-in standard admin cannot remove a domain and so cannot reopen
  registration"` (same refusal, plus the same registration-still-closed follow-through the existing
  non-administrator test performs) (FR-005/FR-006).
- [X] T007 [P] [US2] In `test/system/admin_danger_zone_test.rb`, add
  `"a standard admin sees Users but not Danger Zone in the Admin menu"`: `log_in_as users(:grace)`,
  open the Admin submenu, `assert_link "Users", visible: true`, `assert_no_link "Danger Zone", visible:
  :all` (contrasts with the existing `"a standard account has no Danger Zone entry and no Admin menu at
  all"` test for `carol`, and with `"an administrator's Admin menu carries the Danger Zone beside
  Users"` for `frank` — this is the missing middle case, FR-007). Add a second test,
  `"a standard admin who types the Danger Zone address is refused and told why"`: `log_in_as
  users(:grace)`, `visit admin_danger_zone_path`, `assert_current_path root_path`, `assert_text
  ApplicationController::ADMINISTRATORS_ONLY_MESSAGE` (mirrors the existing
  `"a non-administrator who types the address is refused and told why"` pattern in
  `test/system/admin_users_test.rb`, applied to this screen for a standard admin specifically).

### Implementation for User Story 2

- [X] T008 [US2] In `app/controllers/application_controller.rb`, add `require_super_admin!` immediately
  after `require_admin!`:
  ```ruby
  # 029 FR-006: the danger zone's own admin-only guard, one tier further. Structurally identical to
  # require_admin! above — refuses on its own, same message, same reasoning — differing only in the
  # predicate checked (research.md R2/R3, contracts/super-admin-access.md).
  def require_super_admin!
    return if current_user&.super_admin?

    redirect_to root_path, alert: I18n.t("application.administrators_only")
  end
  ```
- [X] T009 [P] [US2] In `app/controllers/admin/danger_zone_controller.rb`, change
  `before_action :require_admin!` to `before_action :require_super_admin!`, and update the class
  comment's guard description to say so (contracts/super-admin-access.md "Routes protected").
- [X] T010 [P] [US2] In `app/controllers/admin/allowed_email_domains_controller.rb`, change
  `before_action :require_admin!` to `before_action :require_super_admin!`, and update the class
  comment's guard description to say so (contracts/super-admin-access.md "Routes protected").
- [X] T011 [US2] In `app/views/shared/_site_menu_items.html.erb`, narrow only the "Zone de danger" link's
  condition to `current_user.super_admin?`, leaving the outer `<details class="site-submenu">` and the
  "Users" link on `current_user.admin?` unchanged:
  ```erb
  <% if current_user.super_admin? %>
    <%= link_to t(".danger_zone"), admin_danger_zone_path, class: "site-nav-link",
          "aria-current": ("page" if current_page?(admin_danger_zone_path)) %>
  <% end %>
  ```
  wrapped around the existing `link_to` (contracts/super-admin-access.md "Menu"; research.md R4).

**Checkpoint**: User Story 2 is complete and independently testable — a standard admin no longer sees or
can reach the danger zone by any means; a non-admin's refusal is unaffected.

---

## Phase 5: User Story 3 - The super admin keeps full control of the danger zone (Priority: P2)

**Goal**: Confirm User Story 2's new guard changes nothing for the super admin — every existing danger
zone capability (viewing the screen, changing the site language, adding/removing an allowed email
domain) keeps working for `frank` exactly as it did before this feature.

**Independent Test**: Signed in as `frank`, open the danger zone from the Admin menu, change the site
language, and add/remove an allowed email domain — each succeeds exactly as today (quickstart.md
Scenario 4).

### Tests for User Story 3 ⚠️ Write first; confirm they fail before implementing

- [X] T012 [US3] No new test file or case is needed. Every existing test in
  `test/controllers/admin/danger_zone_controller_test.rb`,
  `test/controllers/admin/allowed_email_domains_controller_test.rb`, and
  `test/system/admin_danger_zone_test.rb` that signs in as `users(:frank)` (the majority of both files)
  already is this story's regression coverage — none of them is touched by T005–T011 above beyond the
  one inverted case in T005 (which targets `grace`, not `frank`). Run these three files after T008–T011
  land and confirm every `frank`-signed-in test still passes unchanged — that is User Story 3's
  Independent Test, satisfied by non-regression rather than by new assertions.

### Implementation for User Story 3

- [X] T013 [US3] No implementation task — User Story 2's guard (`require_super_admin!` checking
  `current_user&.super_admin?`) already lets `frank` through, since `frank.super_admin?` is `true`
  (Phase 2). This phase exists to make that continuity an explicit, checked deliverable rather than an
  assumption.

**Checkpoint**: User Stories 1–3 are complete. The danger zone now has exactly the access the feature
asks for: the super admin unchanged, everyone else refused.

---

## Phase 6: User Story 4 - The super admin role cannot be granted, transferred, or taken away (Priority: P2)

**Goal**: No control anywhere grants the super admin role to a second account, revokes it from the
account holding it, or lets that account be cancelled while any other account exists — closing the two
gaps that exist in the current codebase (a different admin could revoke the bootstrap administrator's
rights; the bootstrap administrator could cancel their own account while another admin remained) and
replacing 015's "last administrator" protection with the stronger guarantee the super admin's own
permanence now provides (spec.md FR-009/FR-010/FR-014, research.md R5/R6).

**Independent Test**: As `grace` (a different, standard admin), attempting `PATCH
/admin/users/:id/revoke_admin` against `frank`'s id is refused, and `frank.super_admin?` is still `true`
afterward; `frank`'s own detail screen never renders a "Revoke admin rights" button, even when viewed by
`grace`. Signed in as `frank`, account cancellation is refused while any other account exists and
succeeds once `frank` is the sole remaining account; signed in as `grace`, account cancellation succeeds
unconditionally regardless of how many other admins remain (quickstart.md Scenarios 5–6).

### Tests for User Story 4 ⚠️ Write first; confirm they fail before implementing

- [X] T014 [P] [US4] In `test/controllers/admin/users_controller_test.rb`, add
  `"an administrator cannot revoke the super admin's rights"`: `sign_in users(:grace)`,
  `assert_no_changes -> { users(:frank).reload.admin? }`, `patch
  revoke_admin_admin_user_path(users(:frank))`, `assert_redirected_to admin_user_path(users(:frank))`,
  `assert_not_nil flash[:alert]`, placed alongside the existing "an administrator cannot revoke their
  own rights" / "a granted administrator cannot revoke their own rights either" tests (FR-009,
  research.md R5).
- [X] T015 [P] [US4] In `test/system/admin_user_detail_test.rb`, add "no revoke control appears on the
  super admin's own detail screen, even viewed by a different administrator": `log_in_as
  users(:grace)`, `visit admin_user_path(users(:frank))`, `assert_no_button "Revoke admin rights"` —
  distinct from the existing `"an administrator never sees a revoke control on their own detail
  screen"` test, which only covers `frank` viewing his own screen, not a *different* admin viewing it
  (FR-009, contracts/super-admin-access.md "view guard added").
- [X] T016 [P] [US4] In `test/models/user_test.rb`:
  - Add `"the super admin cannot be deleted while any other account remains, admin or not"`:
    `assert_not users(:frank).destroy` with the full default fixture set still loaded (no destroys
    staged first), and `assert_includes users(:frank).errors[:base],
    I18n.t("user.messages.super_admin_uncancellable")` (FR-010).
  - Add `"the super admin cannot be deleted even when every other admin has been removed, as long as a
    non-admin account remains"`: destroy `users(:grace)` first (so `frank` is the only admin), assert
    `users(:frank).destroy` is still refused with the same message, because `carol`/other non-admin
    accounts remain (FR-010 — stricter than the retired "no other admin remains" condition).
  - Add `"the super admin can be deleted once it is the sole remaining account"`: stage exactly as the
    existing `"the sole account on the site can be deleted even though it is the administrator"` test
    already does (destroy `grace`, then `User.where(admin: false).destroy_all`), then assert
    `users(:frank).destroy` succeeds and the next `User.create!` is both `admin?` and `super_admin?`
    (spec.md Clarifications exception; this may already be fully covered by the existing test of that
    name — extend it with the `super_admin?` assertion on the successor rather than duplicating it if
    so).
  - Add `"a granted administrator can always be deleted, regardless of how many other admins remain"`:
    with `frank` and `grace` both present and `carol`/others also present, `assert
    users(:grace).destroy` succeeds (FR-014 — the retired rule no longer restricts a non-super admin at
    all).
- [X] T017 [US4] In `test/models/user_test.rb`, update the tests whose premise T016's new rule
  contradicts (research.md "R6 fallout" has the full list and reasoning for each):
  - `"deleting an administrator does not promote anyone in their place"` and `"signing up while the
    site has an administrator grants nothing"`: change `users(:frank).destroy` to `users(:grace).destroy`
    (and update each test's comment, which currently explains *why frank* may go — replace with why
    *grace* may go: she is not the super admin, so T016's new rule never restricts her).
  - `"deleting the editor keeps the edit provenance and clears only the editor"` and `"deleting the
    canceller keeps the cancellation provenance and clears only the canceller"`: change the account
    being updated-then-destroyed from `users(:frank)` to `users(:grace)` throughout each test body (the
    `dependent: :nullify` behavior under test does not depend on which admin triggers it).
  - `"the last administrator cannot be deleted while other accounts remain"`: keep the setup (`destroy
    users(:grace)` first) and the `assert_not users(:frank).destroy` assertion — this scenario is still
    correctly refused, just now by T016's rule rather than the retired one; update the test's comment to
    say so.
  - `"an administrator can be deleted while another administrator remains"`: this test's exact claim
    (`assert users(:frank).destroy` while `grace` remains) is now false. Replace it with `"a granted
    administrator can be deleted while the super admin remains"`: `assert users(:grace).destroy` while
    `frank` (and others) remain.
  - `"the refused administrator is told to grant rights to someone else first"`: delete this test — the
    scenario it names (an administrator refused and told to grant rights elsewhere first) no longer
    occurs for anyone (research.md R6). Replace it with `"the refused super admin is told the account
    can never be cancelled"`: same `destroy users(:grace)` setup, `users(:frank).destroy`, then
    `assert_includes users(:frank).errors[:base], I18n.t("user.messages.super_admin_uncancellable")`.
  - **Discovered during implementation, not in the original plan**: `"deleting the grantor keeps the
    grant and clears only the grantor"` (FR-019) also calls `users(:frank).destroy` directly with
    `users(:carol)` and the rest of the fixture set still present — only surfaced once T022 landed and
    this test started failing. Switched to `users(:grace)` as the grantor, same reasoning as the
    editor/canceller pair (research.md "R6 fallout").
- [X] T018 [P] [US4] In `test/controllers/registrations_controller_test.rb`, update `"the last
  administrator cannot cancel their account while others remain"`: keep the request shape (`sign_in
  users(:frank)`, `delete user_registration_path`, `assert_no_difference -> { User.count }`), change the
  assertion from `assert_equal User::LAST_ADMINISTRATOR_MESSAGE, flash[:alert]` to `assert_equal
  I18n.t("user.messages.super_admin_uncancellable"), flash[:alert]`, and rename the test to `"the super
  admin cannot cancel their account while others remain"` (research.md "R6 fallout"). **Also discovered
  during implementation**: `"an administrator can cancel while another administrator remains"` (signed
  in as `frank`, self-cancels via `DELETE /users`, expects success) was not named in the original plan
  either — rewritten as `"a granted administrator can cancel while the super admin remains"`, signed in
  as `grace` instead (FR-014).
- [X] T019 [P] [US4] In `test/system/admin_users_test.rb`:
  - Rewrite `"the last administrator is stopped from cancelling until someone else is promoted"` to stop
    after the refusal: `users(:grace).destroy`, `log_in_as @administrator`, visit
    `edit_user_registration_path`, `accept_confirm { click_button "Cancel my account" }`, `assert_text
    I18n.t("user.messages.super_admin_uncancellable")`, `assert_predicate
    User.find_by(email: @administrator.email), :present?` — delete the subsequent "grant carol admin
    rights, then cancel successfully" tail entirely (that claim no longer holds; `frank` can never
    self-cancel this way while `carol` remains). Rename to `"the super admin is stopped from cancelling
    while any other account remains"`.
  - Rewrite `"a grant survives the deletion of the administrator who made it"` to use `grace` as the
    grantor instead of `frank`: `log_in_as users(:grace)`, visit `admin_user_path(users(:carol))`,
    accept the grant confirmation, then visit `edit_user_registration_path` and cancel `grace`'s own
    account (succeeds unconditionally per T016/FR-014), then `log_in_as users(:carol)` and confirm her
    own row (or `frank`'s admin view of it) shows "Granted on" / "(account removed)" / "Admin" — same
    assertions as today, restaged around `grace` rather than `frank` (research.md "R6 fallout").
- [X] T020 [US4] In `app/controllers/admin/users_controller.rb#revoke_admin`, add the super-admin guard
  immediately after the existing self-forbidden check:
  ```ruby
  return redirect_to admin_user_path(user), alert: t(".super_admin_forbidden") if user.super_admin?
  ```
  (contracts/super-admin-access.md `#revoke_admin`; research.md R5.)
- [X] T021 [P] [US4] In `app/views/admin/users/show.html.erb`, narrow the revoke control's condition
  from `@user != current_user` to `@user != current_user && !@user.super_admin?`
  (contracts/super-admin-access.md "view guard added").
- [X] T022 [US4] In `app/models/user.rb`:
  - Delete `LAST_ADMINISTRATOR_MESSAGE`, the `before_destroy :keep_an_administrator_for_the_remaining_accounts`
    registration, and the `keep_an_administrator_for_the_remaining_accounts` private method entirely
    (research.md R6 — proven unreachable once T023 below lands; Constitution I forbids keeping dead
    code).
  - Add, in its place:
    ```ruby
    before_destroy :prevent_super_admin_cancellation
    ```
    and, in the private section:
    ```ruby
    # 029 FR-010/FR-014, research.md R6: replaces keep_an_administrator_for_the_remaining_accounts,
    # which this makes permanently unreachable. Only the super admin's own row is ever blocked here,
    # and only while at least one other account still exists; as the sole remaining account it may
    # still go, the same exception 013/015 already carved out for "the only account on the site."
    def prevent_super_admin_cancellation
      return unless super_admin?
      return unless User.where.not(id: id).exists?

      errors.add(:base, I18n.t("user.messages.super_admin_uncancellable"))
      throw :abort
    end
    ```
  - Update the comment above `EMAIL_DOMAIN_NOT_ALLOWED_MESSAGE` that currently says
    "`LAST_ADMINISTRATOR_MESSAGE` is on `:base` for the same reason" to reference
    `super_admin_uncancellable` instead (it is a comment-only fix, keeping the surrounding explanation
    accurate).
  (contracts/super-admin-access.md "User#prevent_super_admin_cancellation".)
- [X] T023 [US4] In `app/controllers/registrations_controller.rb#destroy`, change the fallback
  `I18n.t("user.messages.last_administrator")` to `I18n.t("user.messages.super_admin_uncancellable")`,
  and update the method's leading comment (which currently names
  `User#keep_an_administrator_for_the_remaining_accounts`) to name
  `User#prevent_super_admin_cancellation` instead (research.md "R6 fallout").
- [X] T024 [P] [US4] In `config/locales/en.yml` and `config/locales/fr.yml`:
  - Remove the `user.messages.last_administrator` key from both files.
  - Add `user.messages.super_admin_uncancellable`: `"The super admin account can never be cancelled."`
    (en) / `"Le compte du super administrateur ne peut jamais être annulé."` (fr).
  - Add `admin.users.revoke_admin.super_admin_forbidden`, alongside the existing
    `admin.users.revoke_admin.self_forbidden` key: `"The super admin's rights cannot be revoked."` (en)
    / `"Les droits du super administrateur ne peuvent pas être révoqués."` (fr).
  (contracts/super-admin-access.md "New locale keys".)

**Checkpoint**: All four user stories are independently functional. Combined: exactly one super admin
exists for the life of the site; nothing grants, revokes, or transfers the role; the account holding it
can never be orphaned by its own cancellation while anyone else remains; every other admin's own
cancellation is unconditional.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Verification that spans every user story above.

- [X] T025 Run `bin/rails test` (full Minitest suite, including `test/i18n_completeness_test.rb`, which
  automatically fails on any locale key T024 leaves out of either file) and `bin/rails test:system`, and
  confirm zero failures — this is what proves research.md's "R6 fallout" rewrites (T016–T019) are
  complete and nothing else in the suite silently depended on `LAST_ADMINISTRATOR_MESSAGE` or
  `keep_an_administrator_for_the_remaining_accounts` beyond what T016–T019 already found.
- [X] T026 Work through `quickstart.md` Scenarios 1–6 by hand (`bin/rails server` + a browser, plus the
  `bin/rails runner` snippets in Scenarios 1–2) and confirm each matches what it describes, per
  `CLAUDE.md`'s "look at the page" guidance — screenshot any screen actually touched
  (`admin/danger_zone`, the Admin menu, `admin/users/:id`) to `tmp/design/` with a throwaway system test
  if a visual check is warranted, then delete the test.
- [X] T027 [P] Re-read `app/models/user.rb` end to end and confirm no other comment still refers to
  `LAST_ADMINISTRATOR_MESSAGE` or `keep_an_administrator_for_the_remaining_accounts` by name beyond the
  one T022 already updates (a stale cross-reference in an unrelated comment is easy to miss in a
  targeted diff).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: None — no tasks.
- **Foundational (Phase 2)**: No dependencies — BLOCKS every user story (T003–T024 all read
  `super_admin?`).
- **User Story 1 (Phase 3)**: Depends on Phase 2 only. Delivered by Phase 2; Phase 3 is verification.
- **User Story 2 (Phase 4)**: Depends on Phase 2 only. Independent of Phase 3/US1's own tasks (though
  logically it relies on the same predicate).
- **User Story 3 (Phase 5)**: Depends on Phase 2 and Phase 4 (T008–T011) — it verifies Phase 4's guard
  does not regress the super admin's own access, so it must follow Phase 4.
- **User Story 4 (Phase 6)**: Depends on Phase 2 only for T014/T015/T020/T021 (the revoke/view guards);
  T016–T019, T022–T024 (the cancellation-path replacement) are independent of Phase 4/5 and could be
  done in parallel with them by a different contributor, but are grouped here because they share
  spec.md's US4 narrative ("cannot be taken away").
- **Polish (Phase 7)**: Depends on every prior phase being complete.

### Parallel Opportunities

- T001 (test) and T002 (implementation) in Phase 2 touch different files but T001 must be written and
  confirmed failing before T002 lands, per Constitution II — not truly parallel despite different files.
- Within Phase 4: T005, T006, T007 (three different test files) can run in parallel; T009 and T010
  (different controllers) can run in parallel once T008 lands; T011 is independent of T009/T010.
- Within Phase 6: T014, T015, T016, T018, T019 (different test files) can run in parallel; T017 shares
  `test/models/user_test.rb` with T016 and must not run concurrently with it. T021 and T024 can run in
  parallel with T020/T022/T023 once those land, since they touch different files (view, locales) from
  the controller/model changes.
- Phase 4 and the cancellation half of Phase 6 (T016–T019, T022–T024) touch disjoint files
  (`admin/danger_zone_controller.rb`/`allowed_email_domains_controller.rb`/the menu partial vs.
  `user.rb`/`registrations_controller.rb`/the locale files/the model+system tests) and could be staffed
  in parallel by two contributors after Phase 2, with Phase 5 and the revoke half of Phase 6 (T014/T015/
  T020/T021) following once Phase 4 lands.

---

## Parallel Example: Phase 4 tests

```bash
# Launch all three test-file updates for User Story 2 together:
Task: "Invert the danger-zone-controller admin refusal test in test/controllers/admin/danger_zone_controller_test.rb"
Task: "Add standard-admin refusal tests to test/controllers/admin/allowed_email_domains_controller_test.rb"
Task: "Add the menu/direct-access system tests to test/system/admin_danger_zone_test.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Foundational (`super_admin?`, proven correct).
2. Complete Phase 3: User Story 1 (verification only — nothing further to build).
3. **STOP and VALIDATE**: `super_admin?` is true for exactly the right account, in every scenario
   spec.md's US1 names, with no danger-zone restriction live yet.
4. This is a real, if narrow, MVP: it proves the role exists and is assigned correctly before any access
   control changes ship on top of it.

### Incremental Delivery

1. Phase 2 + Phase 3 → the role exists and is provably correct (MVP).
2. Phase 4 → the danger zone actually narrows to the super admin (the feature's headline behavior).
3. Phase 5 → proven no regression for the super admin.
4. Phase 6 → the role becomes tamper-proof (no grant, no revoke, no orphaning cancellation) — required
   before this feature is complete end-to-end, since without it a second admin could still strip or
   outlive the super admin.
5. Phase 7 → full-suite and manual confirmation.

### Parallel Team Strategy

With two contributors, after Phase 2:

- Contributor A: Phase 4 (danger zone access) → Phase 5 (regression check).
- Contributor B: Phase 6's cancellation half (T016–T019, T022–T024) — independent files throughout.
- Either contributor: Phase 6's revoke/view-guard half (T014/T015/T020/T021) once free.
- Both converge on Phase 7.

---

## Notes

- [P] tasks = different files, no dependencies (except where called out above, e.g. T001/T002's
  write-test-first ordering despite different files).
- [Story] label maps task to specific user story for traceability.
- Every user story is independently completable and testable, per its own Independent Test above.
- Verify tests fail before implementing (Constitution II, NON-NEGOTIABLE).
- Commit after each task or logical group.
- Stop at any checkpoint to validate a story independently.
- Phase 6's cancellation-path work (T016–T023) is the largest single risk in this feature: it replaces a
  previously-shipped, well-tested rule (015 FR-16) rather than merely adding to it. research.md's "R6
  fallout" sections (both the test list and the code/locale removal list) are the authoritative checklist
  for this phase — work through them in order rather than improvising from the diff alone.
