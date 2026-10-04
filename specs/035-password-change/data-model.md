# Data Model: Change Password from the Account Page

**Feature**: 035-password-change | **Date**: 2026-10-04

## User *(existing table `users`, two new columns)*

| Column | Type | Null | Default | Purpose |
|---|---|---|---|---|
| `password_change_failed_attempts` | integer | no | 0 | Consecutive wrong current passwords on the password-change form (FR-008) |
| `password_change_locked_at` | datetime | yes | — | When the form was throttled; `nil` when not throttled |

Unchanged but relied on: `encrypted_password` (its salt is what binds sessions and remember-me cookies, research
R4), `reset_password_token` (cleared on change, R6), `failed_attempts`/`locked_at` (sign-in lockout — **not**
touched by this feature).

**Throttle states**

```
open ──wrong current pw (count < 5)──▶ open (count+1)
open ──5th consecutive wrong──▶ throttled (locked_at = now)
throttled ──any submission < 15 min──▶ throttled (refused, password not checked)
throttled ──submission ≥ 15 min later──▶ open (count = 0, then judged normally)
any ──correct current pw──▶ open (count = 0, locked_at = nil)
```

## PasswordChange *(new, not persisted — `ActiveModel::Model`)*

| Attribute | Rules (all checked together, FR-011) |
|---|---|
| `user` | the signed-in user; never taken from params (FR-007) |
| `current_password` | present; matches the user's password; refused outright while throttled |
| `password` | present; 8–128 characters (Devise `password_length`); different from the current password |
| `password_confirmation` | present; equal to `password` |

`#save` → `true` after the user row is updated, else `false` with `errors` on the three attributes.
`#throttled?`, `#minutes_until_unthrottled` for the throttle message.

## Effects of a successful save

| Effect | Mechanism | Requirement |
|---|---|---|
| Other browser sessions rejected | new bcrypt salt ≠ salt stored in their session | FR-016 |
| Other remember-me cookies rejected | no `remember_token` column → cookie carries the salt | FR-016 |
| This session kept | `bypass_sign_in` + `remember_me` in the controller | FR-017 |
| Outstanding reset link void | Devise `before_update :clear_reset_password_token` | FR-018 |
| Notification sent once | Devise `after_update :send_password_change_notification` | FR-020 |
| Throttle reset | same transaction | FR-008 |
