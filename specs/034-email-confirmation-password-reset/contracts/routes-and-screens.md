# Contract: Routes, Controllers and Screens

**Feature**: 034-email-confirmation-password-reset

## Routes

```ruby
devise_for :users, controllers: {
  registrations: "registrations",                 # existing
  confirmations: "users/confirmations",           # new
  passwords:     "users/passwords"                # new
}

namespace :admin do
  resources :users, only: [ :index, :show ] do
    # … existing members and nested resources …
    resource :activation, only: :create, controller: "user_activations"   # new
  end
end

# development only
mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
```

| Verb | Path | Controller#action | Who | Purpose |
|---|---|---|---|---|
| GET | `/users/confirmation/new` | `users/confirmations#new` | anyone | Request a new activation email (FR-011) |
| POST | `/users/confirmation` | `users/confirmations#create` | anyone | Send it — generic answer (FR-013, FR-023) |
| GET | `/users/confirmation?confirmation_token=…` | `users/confirmations#show` | anyone | Follow an activation link (FR-006, FR-008) |
| GET | `/users/password/new` | `users/passwords#new` | anyone | "Forgot your password?" (FR-014) |
| POST | `/users/password` | `users/passwords#create` | anyone | Send reset link — generic answer (FR-015, FR-016, FR-023) |
| GET | `/users/password/edit?reset_password_token=…` | `users/passwords#edit` | anyone | Choose a new password (FR-017) |
| PATCH/PUT | `/users/password` | `users/passwords#update` | anyone | Save it (FR-017 to FR-020, FR-040) |
| POST | `/admin/users/:user_id/activation` | `admin/user_activations#create` | admins | Activate by hand (FR-035 to FR-038) |

## Controller behaviour

### `RegistrationsController` (existing)

- **new** `after_inactive_sign_up_path_for(resource)` → `new_user_session_path` (research R7). The
  existing `after_sign_up_path_for` stays for the (now unreachable at signup) active path.
- Flash on signup: `devise.registrations.signed_up_but_unconfirmed`.

### `Users::ConfirmationsController < Devise::ConfirmationsController`

- `create`: normalise the email (strip, downcase). Look up the account. Call
  `User#resend_activation!` (never Devise's `resend_confirmation_instructions` directly — research R17)
  **only if** the account exists, is not activated, and
  `confirmation_sent_at` is older than `RESEND_COOLDOWN` (5 minutes). Log the outcome (research R16).
  **Always** `redirect_to new_user_session_path, notice: t("devise.confirmations.send_paranoid_instructions")`.
- `show`: Devise's `confirm_by_token`. On success → sign-in screen with `devise.confirmations.confirmed`
  (not signed in automatically — spec US1 says "invites them to sign in"). On failure, render `new` with
  status 422 and a message chosen by the error on `confirmation_token` / `email`:

  | Devise error | Message key | Next step offered |
  |---|---|---|
  | `email: :confirmation_period_expired` | `users.confirmations.expired` | the resend form on the same page |
  | `email: :already_confirmed` | `users.confirmations.already_active` | link to sign in |
  | `confirmation_token: :invalid` / `:blank` | `users.confirmations.unrecognised` | the resend form |

### `Users::PasswordsController < Devise::PasswordsController`

- `create`: normalise the email; send `send_reset_password_instructions` **only if** the account exists and
  `reset_password_sent_at` is older than `RESEND_COOLDOWN`. Always
  `redirect_to new_user_session_path, notice: t("devise.passwords.send_paranoid_instructions")`.
- `edit`: Devise's, unchanged (it does not check the token until submit). The view reuses the signup
  password pair (`devise/shared/_password_field`, `password-confirmation` controller, `password_hint`).
- `update`: `super do |user| … end`; inside the block, when `user.errors.empty?`:
  `user.activate!` then `user.unlock_access!` (research R4). Devise then signs in and redirects via
  `after_sign_in_path_for` (existing — grants the 30-day session). Flash `devise.passwords.updated`.
  On an expired / used / unknown token Devise re-renders `edit` with an error on `reset_password_token`;
  the view turns that into the message + a link to `new_user_password_path` (FR-020). Password errors
  re-render with the token kept (scenario US3-5).

### `Admin::UserActivationsController < ApplicationController`

```text
before_action :authenticate_user!, :require_admin!

create:
  user = User.find_by(id: params[:user_id])
  → nil:          redirect admin_users_path, alert: t(".account_gone")
  → activated_now = user.activate!(by: current_user)
  → true:         redirect admin_user_path(user), notice: t(".activated", email:)
  → false:        redirect admin_user_path(user), notice: t(".already_active", email:)
```

Non-admins get `require_admin!`'s existing refusal (`application.administrators_only`), no new string.

## Screens

All new screens use the existing auth screen shell: `.auth-page`, `shared/brand_stacked`,
`content_for :hide_site_header`, one `.card.stack`, `.page-title` outside no card (auth screens are the
existing exception where the title sits in the card), `.field` / `.field-label` / `.field-input`,
`.btn.btn-primary.w-full` with `turbo_submits_with`, `.meta` + `.auth-link` for secondary links,
`devise/shared/_error_messages` for errors (`role="alert"`). `novalidate` on every form, as on sign-in and
sign-up, so all errors come from the server in one voice.

| Screen | View | Content |
|---|---|---|
| Sign-in (existing) | `devise/sessions/new` | + two `.meta` links under the form: "Forgot your password?" → `new_user_password_path`; "Didn't receive the activation email?" → `new_user_confirmation_path` |
| Forgot password | `devise/passwords/new` | title, one-line lead, email field, submit, link back to sign-in |
| New password | `devise/passwords/edit` | title, hidden token, password + confirmation (signup's partial, hint, live mismatch hint), submit. On token error: the error block + "Request a new link" |
| Resend activation | `devise/confirmations/new` | title, lead, email field, submit, link back to sign-in. Also the failure page for a bad link, with the outcome message above the form |
| Account page (existing) | `devise/registrations/edit` | unchanged: already shows `waiting_confirmation_for` (FR-022). Flash after saving a new address: `devise.registrations.update_needs_confirmation` |

### Admin Users list (`admin/users/index`) — FR-034

In the email cell, when `user.confirmed_at.nil?`, a second line wrapped with the link in a `.cell-stack`:
`<span class="badge badge-neutral">Not activated</span>`. Activated accounts render exactly as today.
The badge carries the words; colour is not the signal.

### Admin user detail (`admin/users/show`) — FR-034 to FR-036

A new `<div>` in the `detail-grid` after "Joined":

- term: "Activation"
- value, one of:
  - not activated → "Not activated" (`detail-value-empty`) and, below the grid, a
    `button_to` "Activate account" (`btn btn-secondary btn-sm`, `method: :post`, confirm +
    turbo_confirm "Activate %{email}? They will be able to sign in without the email.", aria-label naming
    the email) — the exact pattern of the grant/revoke controls on the same screen;
  - activated by an admin → "Activated by %{email} on %{date}"; admin since deleted → "Activated by an
    administrator whose account has since been removed, on %{date}";
  - otherwise → "Activated on %{date}".

## Accessibility (Constitution III)

- Every new form field has a `<label>`; hints are tied with `aria-describedby`.
- Errors render in the existing `role="alert"` block; toasts keep `role="status"`/`"alert"`.
- Each new screen gets an `assert_axe_clean` visit in `test/system/accessibility_test.rb`.
- Tab order: single column, one control per row — satisfies `assert_tab_order_follows_visual_order`.
