---

description: "Task list for 035 — change password from the account page"
---

# Tasks: Change Password from the Account Page

**Input**: Design documents from `specs/035-password-change/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/routes-and-screens.md](contracts/routes-and-screens.md),
[quickstart.md](quickstart.md)

**Tests**: required — constitution Principle II (non-negotiable). Every story writes its tests first and
watches them fail.

**Organization**: by user story (spec.md US1–US4). Research items are cited as R1–R12, requirements as
FR-nnn; read them before starting a task that cites them.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: US1–US4 from spec.md

## Conventions every task follows

- Comments cite the FR/research item at the site of the rule, matching the density of
  `app/controllers/users/passwords_controller.rb` and `app/models/user.rb`.
- Every user-facing string goes through `t()` with an entry in **both** `config/locales/en.yml` and
  `config/locales/fr.yml` (keys listed in the contract's "Strings" section). No literal text in views,
  controllers, models or JS.
- No raw hex in templates. Only the 48rem breakpoint. `.btn-primary` on `<input type="submit">`.
- System tests: `log_in_as(users(:carol))`, `fill_in_reliably`, `wait_for_turbo`, `VALID_PASSWORD`
  (`"password123"`). Scope fills with `within` a card, because "Current password" appears in both cards.
- Never put a password value in a log line, flash, URL or rendered `value=` attribute (FR-013, FR-026).

---

## Phase 1: Setup

**Purpose**: schema and route that every story needs

- [X] T001 Create migration `db/migrate/20261004090000_add_password_change_throttle_to_users.rb` adding to
  `users`: `password_change_failed_attempts` — integer, `null: false`, `default: 0`; and
  `password_change_locked_at` — datetime, nullable. Run `bin/rails db:migrate` and commit the updated
  `db/schema.rb` (data-model.md, R5).
- [X] T002 [P] In `config/routes.rb`, below the `devise_for :users` block, add
  `devise_scope :user do patch "users/account/password", to: "registrations#update_password", as:
  :user_account_password end`. Add a comment that `/users/password` belongs to the 034 reset flow (contract
  "Routes"). Confirm with `bin/rails routes -g account_password`.

---

## Phase 2: Foundational

**Purpose**: the form object and the controller skeleton that US1–US3 all build on

**⚠️ No story work starts until this phase is done**

- [X] T003 Create `app/models/password_change.rb`: an `ActiveModel::Model` with `attr_accessor :user,
  :current_password, :password, :password_confirmation` and constants `MAXIMUM_ATTEMPTS = 5`,
  `LOCK_DURATION = 15.minutes`. `#save` returns false until US1 fills it in. Add `to_key` → `nil`, so
  `form_with model:` posts rather than patches by id. Add the `activemodel.models.password_change` and
  `activemodel.attributes.password_change.{current_password,password,password_confirmation}` keys in en/fr
  (R3).
- [X] T004 In `app/controllers/registrations_controller.rb`, add `update_password` to Devise's
  `authenticate_scope!` prepend (`prepend_before_action :authenticate_scope!, only: [:edit, :update,
  :destroy, :update_password]`). Add a `public` `update_password` action that builds
  `@password_change = PasswordChange.new(user: resource, **password_change_params)`, and a private
  `password_change_params` permitting only `:current_password, :password, :password_confirmation` under
  `:password_change`. Never read a user id from params (FR-007, R1). Also make `#edit` assign
  `@password_change ||= PasswordChange.new(user: resource)`.

**Checkpoint**: routes resolve, `/users/edit` still renders unchanged, full suite green.

---

## Phase 3: User Story 1 — Change my password from my account (P1) 🎯 MVP

**Goal**: from the menu, reach the account page's "Change password" card. Change the password and see the
three-part success panel, staying signed in.

**Independent Test**: sign in, open the account page from the menu, change the password. The panel names
three outcomes, the old password is refused at sign-in, the new one works, and this browser is still
signed in.

### Tests for User Story 1 (write first, see them fail)

- [X] T005 [P] [US1] `test/models/password_change_test.rb`: with `users(:carol)`, a correct current password
  plus a valid matching new password → `save` is true, `user.reload.valid_password?(new)`. Exactly one
  `password_change` mail is enqueued (`assert_enqueued_emails 1`). `reset_password_token` is cleared if it
  was set (FR-018, R6). A wrong current password → `save` false, error on `:current_password`, password
  unchanged, no mail enqueued.
- [X] T006 [P] [US1] `test/controllers/registrations_controller_test.rb`, new section headed `# 035`:
  `sign_in users(:carol)`. A valid `patch user_account_password_path` → `assert_response :see_other`,
  redirect to `edit_user_registration_path`, `flash[:password_changed]` set. A follow-up `get
  edit_user_registration_path` → 200 (still signed in, FR-017). Not signed in → redirect to
  `new_user_session_path`, password unchanged.
- [X] T007 [P] [US1] `test/system/password_change_test.rb`, new: log in, open the menu, click the identity
  link, land on `/users/edit`. `within` the password card, fill all three and submit. Assert that the
  `role="status"` panel shows the three sentences (`password_changed_active`, `password_changed_sessions`,
  `password_changed_notified` with carol's email) and has focus. Log out, then sign-in with the old
  password is refused and the new one succeeds (US1 scenarios 1–5). Double submission (FR-023): before the
  click, slow the request (`page.driver.browser.network_conditions = { latency: 1000 }`, or
  `execute_script` delaying the Turbo submit). Click submit, assert the button is `disabled` and reads
  `t("devise.registrations.edit.password_submitting")`, click again, and assert exactly one mail across both
  clicks (`assert_enqueued_emails 1`, or one mail in `emails_to(carol.email)` under
  `perform_enqueued_jobs`).
- [X] T008 [P] [US1] `test/system/site_menu_test.rb`: the identity email is a link to
  `edit_user_registration_path`, with `aria-current="page"` there. Check at the default viewport and under
  `with_viewport(:phone)` (FR-001).

### Implementation for User Story 1

- [X] T009 [US1] `PasswordChange#save` in `app/models/password_change.rb`:
  - check `user.valid_password?(current_password)`; if wrong, `errors.add(:current_password, :invalid)`;
  - `user.assign_attributes(password:, password_confirmation:)`, then if `user.invalid?` copy its
    `:password` and `:password_confirmation` errors onto self (length 8–128 and match come from Devise
    `:validatable`);
  - **on refusal, leave `user` as it was found**: `user.errors.clear` and
    `user.restore_attributes(%i[encrypted_password])`. `user` is the controller's `resource`, which the
    email card renders on a 422. Errors left on it would show the password errors in both cards' summaries;
  - with no errors, `user.save` inside `ActiveRecord::Base.transaction`;
  - always `user.clean_up_passwords` before returning.

  Collect every error before returning; don't short-circuit (FR-011).
- [X] T010 [US1] Fill in `RegistrationsController#update_password` (R4):
  - on `@password_change.save`, call `bypass_sign_in(resource, scope: :user)` and then `remember_me(resource)`.
    The second call is required: without a `remember_token` column, this browser's own remember-me cookie
    dies with the old salt.
  - then `flash[:password_changed] = true` and `redirect_to edit_user_registration_path, status: :see_other`.
  - on failure, `render :edit, status: :unprocessable_content`.
  - log `Rails.logger.info("[password_change] event=changed user_id=#{resource.id}")` (R12).
- [X] T011 [P] [US1] Create `app/views/devise/registrations/_password_form.html.erb`, a `.card` with an `h2`
  `t(".password_section_title")`:
  - when `flash[:password_changed]`, a success panel: `role="status"`, `tabindex="-1"`, `autofocus`, titled
    `password_changed_title`, with a `<ul>` of the three sentences. Turbo focuses the first `[autofocus]`
    element after every visit and render, so no JavaScript is needed;
  - `render "devise/shared/error_messages", resource: password_change, focus: true`;
  - `form_with model: password_change, url: user_account_password_path, method: :patch, html: { novalidate:
    true, class: "stack-tight" }`;
  - three fields via `render "devise/shared/password_field"`, with subjects and
    `autocomplete` `current-password` / `new-password` / `new-password` (FR-003, FR-004, FR-006). The
    partial hardcodes `autocomplete: "new-password"`, so add an optional `autocomplete:` local to it,
    defaulting to `"new-password"`;
  - the rule hint `t("devise.shared.password_hint", count: 8)` under the new password (FR-005);
  - `f.submit t(".password_submit"), class: "btn btn-primary", data: { turbo_submits_with:
    t(".password_submitting") }` (FR-023).
- [X] T012 [US1] In `app/views/devise/registrations/edit.html.erb`, render `_password_form` (local
  `password_change: @password_change`) as its own card after the existing email form card and before the
  cancel-account card. Keep a single column (contract "Screen").
- [X] T013 [P] [US1] In `app/views/shared/_site_menu_items.html.erb`, replace the `.site-nav-identity` span
  with `link_to edit_user_registration_path, class: "site-nav-identity site-nav-link"`. Its content is
  `current_user.email` plus a `<span class="sr-only">` holding `t(".account_settings")`, with `aria-current`
  set as the other links do (R11). Add the key in en/fr.
- [X] T014 [P] [US1] Success-panel styling in `app/assets/tailwind/application.css`, **only if** no existing
  rule already renders success text on its tint inside a card. Edit the existing rule rather than add a
  second one (CLAUDE.md "One definition per component"). Use the `success` token pair only. Run
  `bin/rails tailwindcss:build` (R8).
- [X] T015 [US1] Add the US1 strings from the contract to `config/locales/en.yml` and `config/locales/fr.yml`
  under `devise.registrations.edit` and `shared.site_menu_items`. Run `bin/rails test
  test/i18n_completeness_test.rb`.

**Checkpoint**: T005–T008 green. The MVP works end to end.

---

## Phase 4: User Story 2 — Other devices are signed out (P1)

**Goal**: prove (and where needed, guarantee) that every other session dies and this one survives.

**Independent Test**: two browsers on one account, one with only a remember-me cookie. Change the password
in the first. The second is sent to sign-in; the first survives even after its session cookie is dropped.

### Tests for User Story 2 (write first)

- [X] T016 [P] [US2] `test/system/password_change_test.rb`: `Capybara.using_session(:other)` logs in as carol.
  Change the password in the default session, then `visit root_path` in `:other` → sign-in page (FR-016,
  US2 scenario 1).
- [X] T017 [P] [US2] Same file: in `:other`, log in, then `restart_browser_session`-style drop of the session
  cookie so only the remember-me cookie remains. After the change in the default session, `:other` is not
  signed in (US2 scenario 2).
- [X] T018 [P] [US2] Same file: after the change in the default session, drop that session's
  `_lockswap_session` cookie (keep `remember_user_token`). Visit `/users/edit` → still signed in (FR-017,
  R4 — this test fails without the `remember_me` call in T010).
- [X] T019 [P] [US2] `test/models/password_change_test.rb`: issue a reset token with
  `user.send_reset_password_instructions`, change the password, and `User.reset_password_by_token` with
  the raw token returns errors (FR-018).

### Implementation for User Story 2

- [X] T020 [US2] If T016–T019 pass on T010 as written, there is nothing more to build. Add a comment block
  above `bypass_sign_in`/`remember_me` in `RegistrationsController#update_password` explaining R4: the
  session and remember cookies both carry `authenticatable_salt`. If any of them fails, fix the cause in
  the controller, never by weakening the test.

**Checkpoint**: US1 + US2 green.

---

## Phase 5: User Story 3 — Understand and fix a refused change (P1)

**Goal**: every refusal is explained on its field. Length and match are caught live with nothing lost.
Wrong current passwords are throttled at 5 per 15 minutes. Nothing about the current password leaks.

**Independent Test**: one submission per failure. Each gives its own field message, the password is
unchanged, and no mail is sent. Five wrong current passwords throttle the form, while the user stays
signed in.

### Tests for User Story 3 (write first)

- [X] T021 [P] [US3] `test/models/password_change_test.rb` (rules):
  - each blank field → `:blank` on that field, with all three blank reported together (FR-011);
  - new password of 7 characters → `:too_short`, and of 129 → `:too_long` (`password` "8 to 128 characters",
    FR-009);
  - new == current → `:same_as_current` on `:password`;
  - mismatch → `:confirmation` on `:password_confirmation`;
  - wrong current password and too short at once → both errors present;
  - wrong current password **and** new password equal to the real current one → `:invalid` on
    `:current_password` only; **no** `:same_as_current` error, and `valid_password?` is called once,
    not twice (FR-013, research R3).
- [X] T022 [P] [US3] `test/models/password_change_test.rb` (throttle, R5, data-model "Throttle states"):
  - 4 wrong → count 4, not throttled;
  - the 5th wrong → `password_change_locked_at` set;
  - while throttled, even the correct password → `:throttled` error, and `valid_password?` is not called
    (stub it to raise);
  - `travel 15.minutes + 1.second` → the correct password succeeds, and the count and `locked_at` are reset;
  - a correct current password with another error → count reset to 0;
  - `users.failed_attempts` and `locked_at` are untouched throughout.
- [X] T023 [P] [US3] `test/controllers/registrations_controller_test.rb` (035): a refused PATCH →
  `:unprocessable_content`. The response body contains none of the submitted values (assert that each
  password string is absent) and no `value=` on the three inputs. Capture `Rails.logger` output → contains
  `event=refused` and no password value (FR-013, FR-025, FR-026). When `User#save` raises
  `ActiveRecord::ActiveRecordError` (stubbed) → 422 with `password_change_failed`, password unchanged
  (FR-024).
- [X] T024 [P] [US3] `test/system/password_change_test.rb` (live checks, Q2):
  - type a 5-character new password, tab away → the length hint is visible;
  - type a mismatched confirmation, tab away → the mismatch hint is visible;
  - click submit → no request is sent (still on the page with no error summary), focus is on the first
    failing field, and every typed value is still present.
- [X] T025 [P] [US3] Same file (server refusal): submit a wrong current password → the error summary has
  focus and `role="alert"`, the current-password field shows the error, all three fields are empty
  (US3 scenarios 1, 5, 6). The email card shows no error summary (`within` the email card,
  `assert_no_selector "#error_explanation"`). Then submit 5 wrong ones in a row → the 6th shows the throttle message with
  minutes, and the user can still visit `root_path` signed in (US3 scenario 7).
- [X] T026 [P] [US3] Same file: sign in, then sign the session out from another `using_session` by changing
  the password there. Submit the form in the first → sign-in page. After signing in with the new password,
  the user lands on `/users/edit` (FR-019, R9).

### Implementation for User Story 3

- [X] T027 [US3] Complete `PasswordChange#save` in `app/models/password_change.rb`, in the order of R3:
  - throttled check first (`password_change_locked_at` within `LOCK_DURATION`) → add `:throttled` with
    `count:` = minutes remaining (rounded up), then return false without checking the password;
  - `:blank` on each empty field;
  - `:same_as_current` when `user.valid_password?(password)` — **evaluated only after the current password
    has been verified correct**, never alongside a wrong one (research R3: otherwise it reveals the current
    password, FR-013);
  - on a wrong current password, an atomic `User.update_counters(user.id,
    password_change_failed_attempts: 1)`, reload the count, and when it is ≥ `MAXIMUM_ATTEMPTS` set
    `password_change_locked_at: Time.current` with `update_columns`;
  - on a correct current password, `update_columns(password_change_failed_attempts: 0,
    password_change_locked_at: nil)`;
  - a lock older than `LOCK_DURATION` is treated as expired: reset it before judging.

  Add `activemodel.errors.models.password_change.attributes.{current_password.invalid,
  current_password.throttled, password.same_as_current}` in en/fr. `invalid` says only "is incorrect"
  (FR-013).
- [X] T028 [US3] In `RegistrationsController#update_password`:
  - log `event=refused user_id=… reasons=…` from `@password_change.errors.details` (types only), or
    `event=throttled`;
  - `rescue ActiveRecord::ActiveRecordError` around the save: log `event=failed`, add `:base`
    `t(".password_change_failed")`, render 422 (FR-024);
  - add a `prepend_before_action :store_password_change_return, only: :update_password`, declared **after**
    the `authenticate_scope!` prepend so it runs first. It calls
    `store_location_for(:user, edit_user_registration_path)` unless `user_signed_in?` (R9).
- [X] T029 [US3] Extend `app/javascript/controllers/password_confirmation_controller.js` (R7):
  - an optional `lengthHint` target and `minimum` (8) / `maximum` (128) values, checked on blur of the
    password target after first touch and re-checked on input;
  - a `guard(event)` action for `submit`: when length or match fails, `preventDefault()`, reveal both hints,
    and focus the first failing input.

  Guard every new target with `has…Target`, so `devise/registrations/new` and `devise/passwords/edit` keep
  working unchanged. Keep the existing `confirm`/`recheck`/`render` behaviour.
- [X] T030 [US3] Wire it in `app/views/devise/registrations/_password_form.html.erb`:
  - on the form, `data-controller="password-confirmation"`, `data-action="submit->password-confirmation#guard"`
    and `data-password-confirmation-minimum-value`/`-maximum-value` from `Devise.password_length`;
  - the password and confirmation targets and actions, as in `devise/registrations/new.html.erb`;
  - hidden `field-error` hints whose text is rendered from the same error messages the server uses, so they
    cannot drift;
  - `aria-describedby` linking each field to its hint;
  - in `app/views/devise/shared/_error_messages.html.erb`, add an opt-in local: when
    `local_assigns.fetch(:focus, false)`, render `tabindex="-1" autofocus` on `#error_explanation`. Other
    callers pass nothing and are unchanged. No existing screen moves focus to its summary (checked: no
    `focus()` in `app/javascript/controllers` outside the menu and locker entry), so this is the mechanism.
- [X] T031 [US3] Add the remaining US3 strings (length hint, throttle message, `password_change_failed`) in
  en/fr and run `bin/rails test test/i18n_completeness_test.rb`.

**Checkpoint**: US1–US3 green. All P1 stories are done.

---

## Phase 6: User Story 4 — Password change kept apart from email change (P2)

**Goal**: the email card asks only for email + current password, and the server refuses to change a
password through it.

**Independent Test**: change the email without any password field present. `PUT /users` carrying `password`
leaves the password unchanged.

### Tests for User Story 4 (write first)

- [X] T032 [P] [US4] `test/controllers/registrations_controller_test.rb` (035): `put user_registration_path`
  with `user: { email: carol's, current_password: VALID_PASSWORD, password: "newpassword1",
  password_confirmation: "newpassword1" }` → `users(:carol).reload.valid_password?(VALID_PASSWORD)` is still
  true, and no `password_change` mail is enqueued (R2).
- [X] T033 [P] [US4] `test/system/email_change_test.rb`: wrap the existing fills in `within` the email card
  (the "Current password" label is now on the page twice). Add an assertion that the email card contains
  no "New password" field (US4 scenario 1).

### Implementation for User Story 4

- [X] T034 [US4] In `app/controllers/registrations_controller.rb`, override `account_update_params` to
  `params.require(:user).permit(:email, :current_password)`. Add a comment citing R2: hiding the fields is
  not enough.
- [X] T035 [US4] Move the email part of `app/views/devise/registrations/edit.html.erb` into
  `app/views/devise/registrations/_email_form.html.erb`:
  - a card with `h2` `t(".email_section_title")`, the email field, the pending-confirmation hint and the
    current password (now through `devise/shared/password_field` with `autocomplete: "current-password"`);
  - **remove** the new-password, confirmation and `leave_blank` hint.

  Render it as the first card in `edit.html.erb`. Delete the unused `leave_blank` key from en/fr and add
  `email_section_title`. **Drop `autofocus: true` from the email field.** It is the first `[autofocus]` in
  the page, so Turbo would give it focus ahead of the password card's success panel or error summary
  (FR-012, FR-014). The page then has at most one `[autofocus]`, and only after an outcome.

**Checkpoint**: all stories green; the account page has two forms with no overlapping fields.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T036 [P] `docs/features.md`: add a row to the table and a short "035 — Change password" entry linking
  `../specs/035-password-change/spec.md`. Mention that the account page is now in the menu. No README
  section. Run `bin/rails test test/documentation_links_test.rb`.
- [X] T037 [P] Accessibility in `test/system/password_change_test.rb`:
  - `assert_axe_clean` on the empty form, the refused form and the success panel;
  - `assert_tab_order_follows_visual_order` on `/users/edit`;
  - `assert_no_horizontal_overflow` under `with_viewport(:phone)`.
- [X] T038 Look at the page (CLAUDE.md "How to check the work"):
  - write a throwaway system test as `users(:carol)` that screenshots `/users/edit` (empty, refused,
    success) to `tmp/design/` at desktop and phone width;
  - read the images, fix anything off-contract, then delete the test.
- [X] T039 Run `bin/rubocop` and `bin/brakeman --no-pager` with zero new warnings, then the full suite with
  `bin/rails test && bin/rails test:system`.
- [ ] T040 Walk through every row of the [quickstart.md](quickstart.md) table, including the manual
  two-browser check and `/letter_opener` in development, and tick each one.

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (T001–T002)** → **Foundational (T003–T004)** → stories.
- **US1 (T005–T015)** is the base for the others: US2 and US3 test and extend `update_password`,
  `PasswordChange` and `_password_form` from US1.
- **US2 (T016–T020)** depends only on US1. It is mostly tests.
- **US3 (T021–T031)** depends on US1. It is independent of US2 and can run alongside it, but both add to
  `test/system/password_change_test.rb`, so merge them carefully.
- **US4 (T032–T035)** depends only on Foundational. It touches `edit.html.erb`, which US1's T012 also edits,
  so do it after T012.
- **Polish (T036–T040)** comes after every story.

### Within each story

Tests first and failing, then the model, then the controller, then the view and JS, then strings.

## Parallel Examples

```text
# US1 tests together:
T005 test/models/password_change_test.rb
T006 test/controllers/registrations_controller_test.rb
T007 test/system/password_change_test.rb
T008 test/system/site_menu_test.rb

# US1 independent implementation files:
T011 _password_form.html.erb  |  T013 _site_menu_items.html.erb  |  T014 application.css

# After US1: US2 tests (T016–T019) alongside US3 model tests (T021–T022) and US4 tests (T032–T033)
```

## Implementation Strategy

1. **MVP** = Phases 1–3: a reachable, working password change with a clear confirmation. Notification,
   reset-link invalidation and other-session sign-out already come from Devise and 034 at this point (R4,
   R6); US2 proves them.
2. Add **US2** to prove the session guarantees, including this browser's remember-me cookie.
3. Add **US3** for the throttle, the live checks and the failure handling. The feature is **not shippable
   before US3**: without the throttle, a hijacked session can guess the current password without limit.
4. Add **US4** to close the old combined-form path (R2). This is also required before release, since the
   old path bypasses US3's throttle.
5. Polish, then open a PR against `dev` that states which Core Principles apply. Name the success panel as
   the one new pattern (R8).
