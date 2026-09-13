# Phase 1 Data Model: Locker Search Wish

## Entity: Locker Wish (new `locker_wishes` table)

See [research.md](./research.md) for why this is a new table rather than a column on `users`.

| Field | Type | Notes |
| - | - | - |
| `id` | primary key | |
| `user_id` | integer, not null, FK → `users.id` | The owning user (spec's "the owning user"). Unique DB index — enforces at most one active wish per user (FR-003) even under concurrent writes. |
| `floor` | string, not null | Free-form, self-reported target floor. Required (non-blank) — FR-006, FR-007, FR-008. |
| `created_at` / `updated_at` | datetime | Standard Active Record timestamps. `created_at` also drives wish-list ordering (research.md). |

### Associations

- `LockerWish belongs_to :user`
- `User has_one :locker_wish, dependent: :destroy` — a wish cannot outlive its user.

### Validation rules

- `floor`: required (`presence: true`) — FR-007. Blank/whitespace-only input is rejected (Rails'
  `blank?` already treats whitespace-only strings as blank) — Edge Case ("blank or only
  whitespace").
- `user_id`: enforced unique via a DB index (FR-003). The application never relies on this as the
  primary "already has a wish" check — it looks up `current_user.locker_wish` first — but the index
  is the actual correctness guarantee under concurrent submissions (see research.md — race backstop).

### Persistence-layer backstop

- A unique DB index on `locker_wishes.user_id` guarantees FR-003/SC-003 even under two concurrent
  "declare" submissions for the same user. `LockerWishesController#create` rescues the resulting
  `ActiveRecord::RecordNotUnique` by re-fetching the row the winning request just created and
  updating its `floor` to the value just submitted — the loser's outcome is identical to the
  non-race update-in-place path (FR-004), not an error.

### State transitions

```text
[no locker_wish row for this user]                (never declared, or previously cancelled)
  --(declare a floor via "I'm looking for a locker")--> [locker_wish: floor set]        (US1 scenarios 1-2)

[locker_wish: floor set]
  --(declare again with a new floor)-->            [locker_wish: floor updated, same row] (US1 scenario 6, FR-004)
  --(cancel)-->                                    [no locker_wish row for this user]     (US3 scenario 1)

[no locker_wish row for this user]
  --(submit blank/whitespace-only floor)-->        rejected, no row created (US1 scenario 5, Edge Case)

[no locker_wish row for this user]
  --(cancel)-->                                    no-op — nothing to cancel (US3 scenario 2)
```

- Having or not having a locker assigned (the existing `users.floor`/`users.locker_number` from
  002) never blocks or is affected by any of the above — the two entities are read together for
  display only (see below), never coupled by a validation (FR-002, Edge Cases).

## Relationship to User Locker Profile (existing, from 002 — unchanged, read-only here)

The wish list (User Story 2) displays, for each `LockerWish` row, the owning user's *current* floor
and locker number alongside the floor they are seeking:

| Displayed as | Source | When absent |
| - | - | - |
| Wishing user's identifier | `wish.user.email` | n/a (always present) |
| Floor sought | `wish.floor` | n/a (always present — required field) |
| Current floor | `wish.user.saved_floor` | Rendered as "Not set" — distinct from "no locker assigned" (Edge Case) |
| Current locker number | `wish.user.saved_locker_number` | Rendered as "No locker assigned" (existing 002 wording, reused verbatim) |

This feature adds no columns to `users` and performs no writes to `User` — strictly a read of the
existing 002 accessors (`saved_floor`, `saved_locker_number`), which already return `nil` for
"not set"/"no locker assigned" without raising.

## Relationships

- `locker_wishes.user_id` → `users.id` (many-to-one at the schema level; one-to-one in practice,
  enforced by the unique index — FR-003).
- No other table or entity is introduced or referenced.
