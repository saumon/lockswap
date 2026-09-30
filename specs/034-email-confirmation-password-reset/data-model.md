# Data Model: Email Confirmation of New Accounts and Password Reset by Email

**Feature**: 034-email-confirmation-password-reset | **Date**: 2026-09-29

One table changes: `users`. No new table. Tokens are stored as Devise stores them — as a **digest** for
the reset token, and as Devise's own confirmation token — never recoverable from the database into a
working link for a different account.

## `users` — new columns

| Column | Type | Null | Default | Source | Meaning |
|---|---|---|---|---|---|
| `confirmation_token` | string | yes | — | Devise `:confirmable` | Newest activation token; replaced on every resend (FR-012). Kept after activation so a re-click reads "already active" (research R6) |
| `confirmed_at` | datetime | yes | — | Devise `:confirmable` | When the account became active; NULL = not activated (FR-004) |
| `confirmation_sent_at` | datetime | yes | — | Devise `:confirmable` | When the newest activation token was issued. Drives the 24 h expiry (FR-007) and the 5-minute resend window (FR-023) |
| `unconfirmed_email` | string | yes | — | Devise `:confirmable`, `reconfirmable` | New address awaiting confirmation (FR-021/FR-022) |
| `reset_password_token` | string | yes | — | Devise `:recoverable` | Digest of the newest reset token; cleared on successful reset (single use, FR-018) |
| `reset_password_sent_at` | datetime | yes | — | Devise `:recoverable` | When the newest reset token was issued. Drives the 6 h expiry and the 5-minute window |
| `confirmed_by_id` | integer, FK → `users.id` | yes | — | this feature | The administrator who activated the account by hand (FR-036). NULL for activation by link, by reset, or by the release migration |

### Indexes and constraints

- `index_users_on_confirmation_token` — **unique** (Devise's lookup key for `confirm_by_token`).
- `index_users_on_reset_password_token` — **unique** (lookup key for `reset_password_by_token`).
- `index_users_on_confirmed_by_id` — plain, plus `foreign_key :users, column: :confirmed_by_id`. Same shape
  as `admin_granted_by_id`, `locker_edited_by_id`, `search_cancelled_by_id`.

### Migrations

1. `AddDeviseConfirmableAndRecoverableToUsers` — the six Devise columns and two unique indexes; in `up`,
   `UPDATE users SET confirmed_at = CURRENT_TIMESTAMP WHERE confirmed_at IS NULL` (FR-010, research R15).
   `down` removes the columns (the backfill needs no reversal).
2. `AddConfirmedByToUsers` — `add_reference :users, :confirmed_by, foreign_key: { to_table: :users }`.

(Two migrations, not one: the first is Devise's, generic and reversible on its own; the second is this
application's attribution and follows the 027 precedent of one migration per `*_by` reference.)

## `User` model changes

```text
devise :database_authenticatable, :registerable, :recoverable, :confirmable,
       :rememberable, :lockable, :validatable

belongs_to :confirmed_by,  class_name: "User", optional: true, inverse_of: :activations_made
has_many   :activations_made, class_name: "User", foreign_key: :confirmed_by_id,
           dependent: :nullify, inverse_of: :confirmed_by
```

| Method | Contract |
|---|---|
| `activate!(by: nil)` → `Boolean` | One conditional `UPDATE … SET confirmed_at = now, confirmed_by_id = by&.id WHERE id = ? AND confirmed_at IS NULL`. Returns `true` when this call activated the account, `false` when it was already active. Does **not** touch `email`/`unconfirmed_email` (a pending change stays pending) and does not send mail. Reloads `confirmed_at`/`confirmed_by_id` on self. Used by the reset path (`by: nil`) and the admin path (`by: current_user`) |
| `resend_activation!` | Clears `confirmation_token`, then `resend_confirmation_instructions` — forcing a fresh token and `confirmation_sent_at`, because Devise otherwise re-sends the unexpired old one (research R17, FR-012). No-op for an activated account (Devise's `pending_any_confirmation` guard) |
| `activated_by_admin?` → `Boolean` | `confirmed_at.present? && confirmed_by_id.present?` — lets the admin screen say "by whom" only when there was a whom (FR-036) |
| `send_devise_notification(notification, *args)` | Override: `devise_mailer.send(notification, self, *args).deliver_later` (FR-028, research R8) |

`validatable`'s rules, the 016 domain allow-list (`on: :create`), and every `:locker_profile_update`
validation are untouched. `activate!` bypasses validation by design: it writes two columns the user never
edits.

## State transitions

```text
                       signup (email sent)
                              │
                              ▼
┌──────────────────── NOT ACTIVATED ─────────────────────┐
│ confirmed_at = NULL                                    │
│ sign-in with right password → refused "unconfirmed"    │
│ resend (≥5 min since last) → new token, old ones dead  │
└──────┬───────────────────┬────────────────────┬────────┘
       │ link (≤24 h)      │ reset completed    │ admin activates
       │ confirmed_by=NULL │ confirmed_by=NULL  │ confirmed_by=admin
       ▼                   ▼                    ▼
┌─────────────────────────── ACTIVATED ─────────────────────────────┐
│ confirmed_at set; signs in normally                                │
│ old activation link → "already active"                             │
│                                                                    │
│   change email on account page ──► PENDING EMAIL CHANGE            │
│     unconfirmed_email = new; email unchanged; still ACTIVATED      │
│     link sent to new address (≤24 h) → email := unconfirmed_email  │
└────────────────────────────────────────────────────────────────────┘

Release migration: every existing row → ACTIVATED (confirmed_by = NULL).
```

Reset token lifecycle (independent of activation):

```text
request (≥5 min since last) → token issued, older token dead
   ├─ used within 6 h with valid passwords → password changed, token cleared,
   │     activate!(by: nil), unlock_access!, signed in, password_change mail
   ├─ used with invalid passwords → errors shown, token still valid
   └─ used after 6 h / after clearing → refused, offer new request
```

## Validation rules carried from the spec

| Rule | Where enforced |
|---|---|
| New password ≥ 8 chars, confirmation matches (FR-017) | Existing `validatable` + `password_length = 8..128` |
| Activation link ≤ 24 h (FR-007) | `config.confirm_within = 24.hours` |
| Reset link ≤ 6 h, single use, newest only (FR-018) | `config.reset_password_within = 6.hours` (existing); Devise clears/replaces the digest |
| ≤ 1 email of each kind per address per 5 min (FR-023) | `confirmation_sent_at` / `reset_password_sent_at` checked in the two `create` overrides |
| Manual activation only when not activated (FR-035) | View shows the control only when `confirmed_at` is NULL; `activate!`'s `WHERE confirmed_at IS NULL` makes it idempotent regardless |
