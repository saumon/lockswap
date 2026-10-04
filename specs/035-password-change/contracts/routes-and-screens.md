# Contract: Routes and Screens

**Feature**: 035-password-change

## Routes

| Verb | Path | Action | Name | Notes |
|---|---|---|---|---|
| GET | `/users/edit` | `registrations#edit` | `edit_user_registration` | existing account page; now two sections |
| PUT/PATCH | `/users` | `registrations#update` | `user_registration` | existing; **email only** from now on (research R2) |
| PATCH | `/users/account/password` | `registrations#update_password` | `user_account_password` | new |

`/users/password` is **not** used: Devise's reset flow already owns `PATCH /users/password`
(`users/passwords#update`, 034). Declared inside `devise_scope :user`.

### `PATCH /users/account/password`

**Params**: `password_change[current_password]`, `password_change[password]`,
`password_change[password_confirmation]`. Nothing else is read; in particular no user id (FR-007).

| Situation | Response |
|---|---|
| Not signed in / session no longer valid | 302 → sign-in, "please sign in"; return location stored as the account page (R9). No change. |
| Throttled | 422, account page, error on current password: wait N minutes. Password not checked. Fields empty. |
| Any rule fails | 422, account page, error summary (focused, `role="alert"`) + per-field errors. Fields empty. |
| Unexpected persistence error | 422, account page, generic "could not be changed, please try again". No change. |
| Success | 303 → `/users/edit`, `flash[:password_changed]`; this session re-signed and re-remembered (R4). |

### `PUT /users` (changed)

Permitted: `user[email]`, `user[current_password]`. `user[password]` and `user[password_confirmation]` are
dropped by the sanitizer — a request carrying them changes no password.

## Screen: account page (`devise/registrations/edit`)

Two cards, top to bottom (single column — both contain controls, CLAUDE.md "Layout"):

1. **Email** — email field, current password (with show/hide), submit. Pending-confirmation hint as today.
   The "leave blank" password hint and the two new-password fields are removed.
2. **Change password** — `h2` heading naming it.
   - Success panel (only right after a change): `role="status"`, focused, three items:
     new password active · other sessions signed out · notification sent to `<email>`.
   - Error summary (only after refusal): existing `devise/shared/_error_messages` with `resource:` the
     `PasswordChange`.
   - Current password — `autocomplete="current-password"`, show/hide.
   - New password — `autocomplete="new-password"`, show/hide, rule hint always visible, live length error
     (hidden until the field has been left once).
   - Confirm new password — `autocomplete="new-password"`, show/hide, live mismatch error.
   - Submit — `.btn-primary` on `<input type="submit">`, `turbo_submits_with` "Changing…".
   - Form `novalidate`, `data-controller="password-confirmation"`.

The "Cancel my account" card stays after both.

## Menu (`shared/_site_menu_items`)

The identity email becomes a link to `/users/edit`, `aria-current="page"` there, with a visually hidden
suffix naming the destination ("account settings" / "paramètres du compte").

## Strings (en + fr, constitution III)

`devise.registrations.edit.*`: `email_section_title`, `password_section_title`, `current_password_label`,
`new_password_label`, `new_password_confirmation_label`, `password_submit`, `password_submitting`,
`password_changed_title`, `password_changed_active`, `password_changed_sessions`,
`password_changed_notified` (`%{email}`), `password_change_failed`.
`activemodel.models.password_change`, `activemodel.attributes.password_change.*`,
`activemodel.errors.models.password_change.attributes.*` (`invalid`, `same_as_current`, `throttled`
with `%{count}` minutes). `shared.site_menu_items.account_settings`.
Obsolete after the split: `devise.registrations.edit.leave_blank`.
