# Phase 1 Data Model: Locker and Floor Profile

## Entity: User Locker Profile (extends `User`, spec's "User Locker Profile")

No new table is introduced. `floor` and `locker_number` are added directly to the existing `users`
table (see [research.md](./research.md) for why).

| Field | Type | Notes |
| - | - | - |
| `floor` | string, nullable | Free-form, self-reported value (e.g. "3", "RDC"). `nil` means "not yet provided" — a valid, expected state before User Story 2 completes. Required (non-blank) only on the locker-profile save path — FR-001, FR-007, FR-012. |
| `locker_number` | string, nullable | Free-form, self-reported value identifying the user's currently assigned locker. `nil` means "no locker assigned" — a valid, expected, and common state (FR-002). Unique across all users when present — FR-011. |

### Validation rules

All validations below apply on the `:locker_profile_update` context only (see research.md — this
context is used exclusively by `LockerProfilesController#update`, so it never blocks unrelated
`User` saves such as a future Devise email/password change made by a user who hasn't set a floor
yet):

- `floor`: required (`presence: true`) — FR-007. Blank/whitespace-only input is rejected — Edge
  Case ("blank or only whitespace").
- `locker_number`: optional; when present, unique across all `User` records
  (`uniqueness: true, allow_nil: true`) — FR-011. A `before_validation` callback normalizes a
  submitted blank/whitespace-only `locker_number` to `nil` before this check runs, so "no locker" is
  always represented consistently and never collides with another user's blank value.

### Persistence-layer backstop

- A unique DB index on `users.locker_number` (allowing multiple `NULL`s, per SQLite/SQL-standard
  semantics) guarantees FR-011/SC-005 even under concurrent submissions, where the application-level
  uniqueness check alone is not race-safe. `LockerProfilesController` rescues the resulting
  `ActiveRecord::RecordNotUnique` and re-presents the same user-facing "not available" message as the
  ordinary validation-failure path, so the two race outcomes are indistinguishable to the user.

### State transitions

```text
[floor: nil, locker_number: nil]                  (new user, User Story 2 not yet completed)
  --(submit floor, no locker number)-->            [floor: set, locker_number: nil]      "no locker assigned" (US2, US1 scenario 2)
  --(submit floor + locker number)-->              [floor: set, locker_number: set]      (US1 scenario 1)

[floor: set, locker_number: nil]
  --(submit a locker number)-->                    [floor: set, locker_number: set]      (US3)
  --(submit a different floor)-->                  [floor: new value, locker_number: unchanged] (US3 scenario 1)

[floor: set, locker_number: set]
  --(clear locker number)-->                       [floor: unchanged, locker_number: nil] (US3 scenario 2 — locker reassigned away)
  --(submit locker number already held by another user)--> rejected, no state change (US2 scenario 4, Edge Case)

[floor: nil]  (submit blank/whitespace-only floor) --> rejected, no state change (US2 scenario 3, Edge Case)
```

- Once `floor` has been set at least once, an empty `locker_number` is always displayed as
  "no locker assigned," never re-prompted as if it were the still-outstanding, mandatory field — the
  mandatory prompt is keyed off `floor.blank?` only (Edge Case: distinguishing "no locker assigned"
  from "not yet asked").

## Relationships

None beyond the single `User` record these two fields live on — no other entity is introduced or
referenced by this feature.
