# Phase 1 Data Model: Homepage Locker Wish Block

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-15

**No schema change.** This feature adds no table, column, index, or validation. It is a
read-only view over data 002, 003 and 006 already established. What follows records the
fields the block reads and the rule that turns them into one of three states.

## Entities read

### LockerWish (003, `locker_wishes`)

| Field | Type | Used for |
|-------|------|----------|
| `user_id` | integer, unique index | The `has_one :locker_wish` association on User; uniqueness is what guarantees at most one wish per user |
| `floor` | string, required | The only value the block displays (FR-002) |

Read via `current_user.locker_wish`. `nil` means no wish has been declared, or the wish
was cancelled — cancelling destroys the row outright (003), so there is no inactive
state to filter for.

The block reads `floor` through the model's `saved_floor` reader
(`floor_in_database`), not the attribute, so a rejected change being re-displayed
elsewhere cannot leak an uncommitted value into the homepage.

### User (002/006, `users`)

| Field | Type | Used for |
|-------|------|----------|
| `floor` | string, required on `:locker_profile_update` | Whether the user has saved their locker details at all — the block's precondition (FR-001a) |
| `locker_number` | string, nullable, unique per floor | Whether the user has a locker — chooses between the two invitations (FR-004 vs FR-005) |

Read via `current_user.saved_floor` and `current_user.saved_locker_number`, both of which
return the database values rather than the in-memory attributes, for the same reason.
`locker_number` is normalized so that "no locker" is `NULL`, never `""`.

## State derivation

The block's state is a pure function of three reads. Evaluated in this order, the states
are mutually exclusive and total (SC-002):

| # | Condition | State | Content | Control |
|---|-----------|-------|---------|---------|
| 0 | `current_user.saved_floor.blank?` | **Not shown** | — | — |
| 1 | wish present | **Declared wish** | Floor sought, and nothing else (FR-002) | "Review locker wishes! 🥷" |
| 2 | no wish **and** `saved_locker_number.present?` | **Invite to switch** | No wish details | "I want to switch my locker! 👀" |
| 3 | no wish **and** `saved_locker_number.blank?` | **Invite to ask** | No wish details | "I want a locker! 🙏" |

All three controls point at the same destination, `locker_wishes_path` (FR-006).

State 0 is decided by the caller — the block is rendered from inside the template branch
that already asks this question — so the partial itself only ever chooses between 1, 2
and 3.

## What does not affect the state

- **An active swap proposal** (FR-013). `LockerSwapProposal.active_for?(current_user)`
  freezes the locker details card below the block; the block ignores it entirely.
- **Other users' wishes.** The block never loads or counts them (FR-008).
- **The user's own floor and locker number in state 1.** Read for state 2/3 selection
  only; never displayed by the block, since the card below already shows them.

## Queries

| Read | Cost |
|------|------|
| `current_user.locker_wish` | One lookup on the unique `user_id` index, memoized on the user object for the request |
| `current_user.saved_floor`, `current_user.saved_locker_number` | In-memory, on the already-loaded `current_user` |

No collection load, no join, no per-row query, nothing unbounded (Principle IV).
