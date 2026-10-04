# Research: Change Password from the Account Page

**Feature**: 035-password-change | **Date**: 2026-10-04 | **Spec**: [spec.md](spec.md)

Every finding below was read from the code or from the installed gem source (devise 5.0.4, Rails 8.1.4), not
recalled. Where a line number is given it is the gem's own.

---

## R1 — Where the action lives: a member of `RegistrationsController`

**Decision**: Add `RegistrationsController#update_password`, routed with
`devise_scope :user { patch "users/password", … }` under a distinct path (see contract), and have it
re-render `devise/registrations/edit` on refusal. Add it to Devise's `authenticate_scope!` prepend so it gets
`self.resource = current_user` exactly as `#edit`/`#update` do.

**Rationale**: The refusal must re-render the account page with both sections (FR-002, FR-012). That view
uses Devise's controller helpers (`resource`, `resource_name`, `devise_mapping`), which only exist in a
`DeviseController`. A member action of the controller that already owns the page keeps one controller, one
view, no helper shims.

**Alternatives considered**:
- *A separate `PasswordChangesController < ApplicationController`*: would need `resource`/`devise_mapping`
  reimplemented to render the account page, or a second page — and the spec puts the form on the account
  page.
- *Keep Devise's `#update` and its combined form*: it is the thing FR-002 and US4 replace, and its
  `update_with_password` treats a blank new password as "keep the current one" (database_authenticatable.rb
  :90–93), which the spec rules out.

## R2 — The email form must stop accepting a password

**Decision**: Override `account_update_params` in `RegistrationsController` to permit only `:email` and
`:current_password`.

**Rationale**: Devise's default `account_update` sanitizer permits `password` and `password_confirmation`.
If only the view drops those fields, a hand-made request to `PUT /users` still changes the password through
the old path — bypassing the throttle (FR-008), the "differs from current" rule (FR-009) and the session
handling (R4). The rule has to be in the parameter list, not in the markup.

## R3 — A form object for the three fields: `PasswordChange`

**Decision**: `app/models/password_change.rb`, an `ActiveModel::Model` (like `FloorFilter`, `RoleFilter`)
holding `user`, `current_password`, `password`, `password_confirmation`, with `#save` returning true/false
and errors keyed to its own three attributes.

**Rationale**: The page has two forms. The email form's errors live on `resource` (the User); the password
form's must not appear on the email form and vice versa. A separate object gives the password form its own
`errors`, its own error summary (the existing `devise/shared/_error_messages` partial takes any `resource:`),
and one place where every rule is checked together (FR-011). The User model keeps the length and
confirmation validations it already has (`:validatable`); the form object adds only what is specific to this
flow: presence of all three, current password, throttle, differs-from-current.

**Order of checks in `#save`**:
1. Throttled? → error on `current_password` ("too many attempts, wait N minutes"), stop. The password is
   **not** checked (FR-008).
2. Presence of the three values; `valid_password?(current_password)`; then
   `user.assign_attributes(password:, password_confirmation:)` + `user.valid?` for length and match — all
   errors collected, none short-circuiting (FR-011). **New ≠ current is checked only when the current
   password was verified correct.** Checked unconditionally, it is a second password oracle: with a wrong
   current password X and a new password Y, `same_as_current` would appear exactly when Y is the real
   password — revealing it (FR-013) and doubling the guesses each throttled attempt allows (SC-007).
3. Wrong current password → increment the counter (R5). Correct → reset it.
4. No errors → `user.save` (R6).

## R4 — Signing out other sessions, keeping this one (FR-016, FR-017)

**Finding — sessions**: Warden stores `[id, authenticatable_salt]` in the session; on each request
`serialize_from_session` returns the user only if `record.authenticatable_salt == salt`
(authenticatable.rb:229–232). `authenticatable_salt` is `encrypted_password[0,29]`
(database_authenticatable.rb:158–160) — the bcrypt salt, which is new on every password change. So **every
other browser session is already rejected on its next request** once the password changes. Nothing to build;
it needs a test that proves it (SC-002).

**Finding — persistent sessions**: `users` has **no `remember_token` column** (db/schema.rb), so
`rememberable_value` falls back to `authenticatable_salt` (rememberable.rb:73–77). Every remember-me cookie,
**including this browser's**, stops working after the change. Other browsers: correct (FR-016). This browser:
wrong (FR-017) — it would be signed out at its next browser restart.

**Decision**: On success, `bypass_sign_in(user, scope: :user)` (what Devise's own `#update` does, line 54) to
re-serialize this session with the new salt, **then** `remember_me(user)` to re-issue this browser's
persistent cookie with the new salt. `ApplicationController` already includes
`Devise::Controllers::Rememberable` and remembers every sign-in (001 FR-007), so re-issuing it
unconditionally matches how the cookie was set in the first place.

**Alternatives considered**: adding a `remember_token` column — would decouple remember-me from the password,
which is exactly what FR-016 needs coupled.

## R5 — The throttle: two columns on `users` (FR-008)

**Decision**: Migration adding `password_change_failed_attempts` (integer, default 0, not null) and
`password_change_locked_at` (datetime, nullable). Constants on `PasswordChange`: `MAXIMUM_ATTEMPTS = 5`,
`LOCK_DURATION = 15.minutes` — the same numbers as the sign-in lockout, deliberately separate counters.

- Wrong current password → atomic SQL increment (`update_counters`), then if the reloaded count ≥ 5 set
  `password_change_locked_at = now`. Atomic so two tabs submitting at once cannot both read 4.
- Correct current password (whatever else fails) → reset both to 0 / nil.
- Locked and `locked_at` older than 15 minutes → treated as unlocked; the count starts again from zero.

**Rationale**: `config.cache_store` is `:null_store` in test (config/environments/test.rb:23), so a
cache-based counter cannot be tested at all, and Solid Cache in production can evict. Rails 8's controller
`rate_limit` counts every request (not consecutive failures), keys by IP by default and also uses the cache
store. Devise's `:lockable` columns (`failed_attempts`, `locked_at`) must not be reused: the spec says this
throttle does not affect sign-in.

## R6 — All-or-nothing and the notification (FR-020, FR-021, FR-022)

**Finding**: Devise's `after_update :send_password_change_notification` fires when `encrypted_password`
changed (database_authenticatable.rb:36, 187–189), and `config.send_password_change_notification = true`.
`User#send_devise_notification` (034) logs `[account_mail] event=password_change_notified` and
`deliver_later`s. **So the notification already happens, once per saved change, and never on a refused
one.** Delivery failure is already recorded (034 FR-031).

**Finding**: `clear_reset_password_token?` is true whenever `encrypted_password` will change
(recoverable.rb:102–108), and runs `before_update`. **FR-018 is already met**; it needs a test.

**Decision**: `PasswordChange#save` wraps the user update and the throttle reset in one transaction; the
password row is the only domain write. Sessions are invalidated *by* the write (R4), so they cannot diverge
from it. The job is enqueued inside the transaction (as for every 034 email); with the only other statement
being the counter reset on the same row, a rollback after enqueue is not a realistic path and is not worth a
second mechanism. An exception in `#update_password` is rescued for `ActiveRecord::ActiveRecordError`, logged,
and turned into the generic "could not be changed, try again" message (FR-024).

## R7 — Live checks in the browser (FR-015, clarification Q2)

**Finding**: `password_confirmation_controller.js` already shows the "doesn't match" error live on signup and
reset, with the server's own message rendered into a hidden `hint` target. Nothing checks length live; the
signup form is `novalidate`, so the browser's native checks never run — deliberately, because native
messages follow the *browser's* language, not the site language (025).

**Decision**: Extend `password_confirmation_controller` (one definition per component) with an optional
`lengthHint` target and `minimum`/`maximum` values: shown when the new password is outside 8–128 after the
field has been left once, re-checked on input. On `submit`, if either check fails, `preventDefault()`, reveal
both hints and focus the first failing field — nothing typed is lost. The targets are optional, so signup and
reset are unaffected unless they opt in (they may; not required by this feature). The hint texts are rendered
server-side from the same I18n keys as the server errors, so they cannot drift.

**Server refusals clear all three fields**: the form object's attributes are never rendered back
(`password_field` renders no `value` by default; `clean_up_passwords` on the user). Matches Q2.

## R8 — The success message: an in-page status panel, not a toast (FR-014, SC-006)

**Finding**: `notice` renders as a toast that auto-dismisses after `NOTIFICATION_AUTO_DISMISS_MS` (_flash
partial). Three statements in a self-dismissing toast is the message most likely to be gone before it is
read.

**Decision**: Redirect to the account page with `flash[:password_changed] = true`; the password section
renders a persistent `role="status"` panel at its top with the three sentences as a list, and focus moves to
it. The toast is not used for this message. This is a new use of the existing status pair
(`--color-success` text on its tint, already ≥ 4.5:1), not a new component; justified in the PR as required
by Principle III.

## R9 — Expired session at submission returns to the account page (FR-019)

**Finding**: Devise's failure app only stores the return location for GET requests, so an expired session
submitting a PATCH would land on the homepage after sign-in.

**Decision**: In `RegistrationsController`, a `prepend_before_action` on `update_password` only, ahead of
`authenticate_scope!`, that calls `store_location_for(:user, edit_user_registration_path)` when no user is
signed in. Nothing is changed (the action never runs); the user signs in and lands on the account page.

## R10 — Double submission (FR-023)

**Decision**: `data: { turbo_submits_with: … }` on the submit button, as on every form in the app, disables
it for the duration. Server side, a second request that reaches the site after the first succeeded carries
the old session salt and is rejected by Warden (R4) → treated as R9. **Accepted consequence**: if two
requests are genuinely in flight at once (no JavaScript, double click), the second can sign this browser out;
the password change itself still happened once and one notification was sent. Turbo prevents this in every
supported browser; the edge is documented, not engineered around.

## R11 — Menu entry (FR-001)

**Decision**: In `shared/_site_menu_items`, the `.site-nav-identity` email becomes a `link_to` to
`edit_user_registration_path` with `aria-current` on that page, labelled by the email plus a visually hidden
"— account settings". One partial feeds both menu containers (012), so FR-001 holds at every width.

## R12 — Logging (FR-025, FR-026)

**Decision**: `Rails.logger.info("[password_change] event=changed user_id=…")` and
`event=refused user_id=… reasons=current_password_invalid,password_too_short,…` (error *types*, never values),
plus `event=throttled`. `config.filter_parameters` already includes `:passw`, which matches `password`,
`password_confirmation` and `current_password` in request logs.
