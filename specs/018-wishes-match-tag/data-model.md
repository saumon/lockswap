# Data Model: "It's a match!" tag on locker wishes

No schema change. No migration. This feature reads two columns that already exist
(`locker_wishes.floor`, `users.floor`) and adds one computed, non-persisted concept derived from them.

## Existing entities touched (read-only)

### `User`

| Field | Already exists? | Used here as |
|---|---|---|
| `saved_floor` (reads `floor_in_database`) | Yes | The viewer's own current floor, and each row's person's current floor |

No new field, no new validation, no new association.

### `LockerWish`

| Field | Already exists? | Used here as |
|---|---|---|
| `saved_floor` (reads `floor_in_database`) | Yes | The viewer's own desired floor, and each row's desired floor |
| `user` (`belongs_to`) | Yes | Already eager-loaded by `LockerWish.active`'s `includes(:user)` — the source of each row's person's current floor |

No new field, no new validation, no new association.

## New concept: Reciprocal Match (computed, not persisted)

A **Reciprocal Match** is not a database row or a new entity — it is a boolean fact about a
`LockerWish` relative to a viewer's own two floors, true exactly when both directions hold:

```
reciprocal_match?(viewer_current_floor, viewer_wish_floor) =
      floor.present? && viewer_current_floor.present? && floor == viewer_current_floor
  AND user.saved_floor.present? && viewer_wish_floor.present? && user.saved_floor == viewer_wish_floor
```

Where, for a given `LockerWish` row:
- `floor` — the row's own desired floor (already shown as "Looking for floor")
- `user.saved_floor` — the row's person's current floor (already shown as "Their floor")

And for the viewer:
- `viewer_current_floor` — `current_user.saved_floor`
- `viewer_wish_floor` — `current_user.locker_wish&.saved_floor` (`nil` when the viewer has not
  declared a wish)

**Comparison rule**: exact string equality, matching every other floor comparison already in the
codebase (`looking_for`, `owner_on_floor`) — floors are free text, and this feature introduces no
normalization the rest of the app does not already have.

**Exclusion, not part of the formula**: a row belonging to the viewer themselves is never tagged,
regardless of what the formula would return. This is checked separately (`wish.user_id ==
current_user.id`), the same way the view already distinguishes "This is you" from every other row's
Swap-cell content — it is a display-time exclusion, not a property of the match formula itself, so the
formula stays a pure function of two `LockerWish`-and-floor comparisons and does not need to know who
the viewer is as a person.

**Where it's implemented**: `LockerWish#reciprocal_match?(viewer_current_floor, viewer_wish_floor)`.

**Lifecycle**: Recomputed on every render of the list from whatever is currently saved on both sides —
nothing about a match is stored, cached across requests, or notified on. Editing or cancelling either
wish, or either person changing their saved floor, changes the outcome on the very next render (spec
Edge Cases).

## State transitions

None — this is a pure function of current state, not a stateful entity. There is no "becomes a match"
event to record; there is only "is currently a match, evaluated fresh."
