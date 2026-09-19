# Phase 1 Data Model: Pre-fill "Their Floor" filter from the viewer's wish

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

No schema change. No migration. No new table, column, or model. This feature reads two fields that
already exist (`locker_wishes.floor` via `LockerWish#saved_floor`, and the `current_floor` query
parameter already defined by 017) and changes how one of them — the `current_floor` filter selection —
is computed for a given request.

## The one thing that changes shape: how `current_floor`'s selection is derived

017 defined a filter's `selection` as simply "what arrived in the query string" (`FloorFilter`'s
`selection:` argument, read via `LockerWishesController#filter_selection(axis)`). This feature adds a
second source for the `current_floor` axis specifically, chosen by which of two states the request is
in:

| State | Condition | Selection used |
|---|---|---|
| Fresh screen entry | `current_floor` key absent from the query string | `current_user.locker_wish&.saved_floor` (nil if no active wish) |
| Already decided this visit | `current_floor` key present (any value, including blank) | The value from the query string, exactly as 017 already reads it |

`looking_for` is entirely unaffected — it keeps 017's single-source behaviour (query string only, blank
key dropped) throughout.

This is not a new entity or a new persisted concept. It is a computed value, read fresh on every
request from state that already exists (the viewer's own `LockerWish`, if any) — the same shape 018
already established for `reciprocal_match?`'s inputs: nothing stored, nothing new to keep consistent,
re-evaluated every time the screen renders.

## Existing entities this feature reads (unchanged)

- **Locker wish** (`LockerWish`, from 003/017/018): unchanged. This feature reads `saved_floor` — the
  same accessor 018 already relies on for the same reason (it reads past an unsaved, not-yet-committed
  edit) — and reads it exactly once per request, from the association the controller already loads.
- **"Their Floor" filter selection** (`current_floor`, a `FloorFilter` instance, from 017): unchanged in
  shape — still `selection:` plus `available:`, still exposes `filtering?`, `current?`, `choices`. Only
  the *value passed in* as `selection:` for this one axis gains the derivation rule above; the class
  itself, its ordering rule, and its "keep an in-force-but-absent selection visible" behaviour
  (017 FR-015/FR-020) are untouched.
- **"Looking for floor" filter selection** (`looking_for`, from 017): unchanged in every respect,
  including its value source. Included here only to record explicitly that this feature does not touch
  it (spec FR-007).

## Validation rules

None introduced. Floor values continue to be matched as exact free text, per 017/018; this feature adds
no format, presence, or uniqueness rule of its own — it only decides which of two already-valid sources
a `current_floor` selection is read from for a given request.

## State transitions

There is no persisted state to transition. The three actions the spec names — declare, change, cancel —
each result in an ordinary write to the existing `LockerWish` record (unchanged from 003/017), followed
by a redirect whose target address explicitly encodes the resulting `current_floor` value (R3 in
research.md); the *next* request's rendering then re-derives or re-reads that value the same way every
other request does. Nothing is written that was not already being written before this feature.
