# Phase 1 Data Model: User Signup and Login

## Entity: User (implements spec's "Account")

Backed by a single `users` table (SQLite via Active Record), managed by Devise.

| Field | Type | Notes |
| - | - | - |
| `id` | integer (PK) | Rails default primary key |
| `email` | string | Unique (case-insensitive), indexed, not null — identity for FR-003 |
| `encrypted_password` | string | Devise `:database_authenticatable`; bcrypt hash, never plaintext |
| `remember_created_at` | datetime, nullable | Devise `:rememberable`; set on login, drives the 30-day persistent session (FR-007) |
| `failed_attempts` | integer, default 0, not null | Devise `:lockable`; consecutive failed login counter (FR-011) |
| `locked_at` | datetime, nullable | Devise `:lockable`; set when `failed_attempts` reaches 5, cleared on unlock |
| `created_at` / `updated_at` | datetime | Rails timestamps |

### Validation rules

- `email`: required, valid email format, unique (case-insensitive) — FR-002, FR-003.
- `password`: required on creation, minimum length 8 characters (`config.password_length = 8..128`)
  — FR-002.
- Uniqueness violation on `email` at signup MUST surface as a user-facing validation error, not a
  server error — Acceptance Scenario 2 (User Story 1).

### State transitions

```text
[no account] --(signup with valid, unused email + 8+ char password)--> Active
Active --(5 consecutive failed logins)--> Locked (locked_at set, cooldown = 15 minutes)
Locked --(15 minutes elapse)--> Active (failed_attempts reset to 0 on next successful login)
Active --(successful login)--> Active, logged in (remember_created_at refreshed, session valid ≤30 days)
Active, logged in --(logout, or 30 days since last login)--> Active, logged out
```

- A `Locked` account MUST reject login attempts (even with the correct password) until the
  15-minute cooldown elapses — Acceptance Scenario 3 (User Story 3), SC-006.
- `failed_attempts` resets to 0 on the next successful login after unlock — Edge Case (cooldown
  reset).

## Entity: Session (spec-level concept)

There is no separate `sessions` database table. "Session" in the spec maps to Devise/Warden's
signed, encrypted session cookie plus the `:rememberable` cookie, both scoped to one `User` row via
`remember_created_at`. This is documented here to make the mapping from spec language to
implementation explicit, not because a new table is needed.

| Spec attribute | Implementation |
| - | - |
| Which account it belongs to | `user_id` embedded in the signed Warden session / remember cookie |
| When it started | Cookie issue time; refreshed on each login |
| When it expires | `remember_created_at + 30.days` (FR-007) |
| When it ends via logout | Devise `sign_out` clears the session and remember cookie (FR-009) |

## Relationships

None beyond the single `User` entity — this feature introduces no associated child records.
