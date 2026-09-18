# Phase 1 Data Model: Filter locker wishes by floor

**Feature**: [spec.md](./spec.md) | **Branch**: `017-locker-wishes-floor-filter` | **Date**: 2026-09-18

## Schema changes

**None.** No migration, no new table, no new column, no new index.

The feature reads two columns that already exist:

| Column | Type | Set by | Used for |
|---|---|---|---|
| `locker_wishes.floor` | `string`, `null: false` | 003 — the wish declaration form | The "looking for floor" axis |
| `users.floor` | `string`, nullable | 002 — the homepage locker profile form | The "current floor" axis |

Both are free text and stay free text: the spec's Assumptions rule out introducing a validated set of
floors or any normalisation, and FR-020 requires an unrecognised value to be handled as an empty
result rather than rejected. Nothing here writes to either column.

### A note on indexes

Neither column is indexed, and this plan does not add an index. The filtered query is a scan over a
table whose row count is bounded by the number of people currently looking for a locker — the same
scan the screen already performs, narrowed. Adding an index to `locker_wishes.floor` would be
speculative at this scale and is left to whoever has a measurement that calls for it (Principle IV
asks for evidence, not for pre-emptive indexing).

---

## Entities

### LockerWish (existing — gains query surface only)

`app/models/locker_wish.rb`. Unchanged as a record: still one row per user, still `belongs_to :user`,
still `validates :floor, presence: true`, still guarded by the unique index on `user_id`. What it
gains is the vocabulary the screen needs to ask for a subset.

| Scope / query | Contract |
|---|---|
| `active` | Every wish whose owner has no exchange in progress — the rule `all_locker_wishes` applies inline today, extracted so the list and both choice queries share one definition. Ordered oldest declaration first, unchanged (FR-013). |
| `looking_for(floor)` | `active` wishes whose own `floor` equals the argument exactly. A blank argument is a no-op, so "all floors" needs no branch at the call site. |
| `owner_on_floor(floor)` | `active` wishes whose **user's** `floor` equals the argument exactly. Joins `users`. Rows whose user has `floor IS NULL` or `''` never match a specific value, which is FR-012 falling out of the join rather than being special-cased. A blank argument is a no-op. |
| `looked_for_floors` | The distinct, non-blank `locker_wishes.floor` values across `active` — **not** across the filtered relation (FR-006). Returns at most one row per floor. |
| `owner_floors` | The distinct, non-blank `users.floor` values across the owners of `active` wishes. Same bound, same independence from the current selection. |

Both choice queries drop blanks: `users.floor` is nullable, and FR-005 says the current-floor filter
offers "no floor on which none of them holds a locker" — an absent floor is not a floor.

The two scopes compose, and composing them is what FR-011 describes: setting both filters is
`active.looking_for(a).owner_on_floor(b)`, an intersection, matching the Assumption that a row must
satisfy every filter that is set.

### User (existing — untouched)

Read for `floor` (the second axis) and for `email`, `saved_floor`, `saved_locker_number` as the list
already does. No new association, validation or method. The feature never writes to a user.

### FloorFilter (new — plain Ruby, not Active Record)

`app/models/floor_filter.rb`. One instance per axis, two per request. It holds no data of its own and
never touches the database — it is given the floors that were found and the value that was asked for,
and answers what the view needs to render one filter bar.

| Member | Contract |
|---|---|
| `selection` | The floor in force, or `nil` when the axis is on "all floors". A blank incoming value is normalised to `nil`, so `?looking_for=` behaves as unfiltered (FR-003). |
| `choices` | The available floors in FR-007 order — values that parse as integers first, ascending, then the rest alphabetically — with the raw string breaking ties so `3` and `03` order consistently. If `selection` is set but absent from the available floors, it is appended so it stays visible (FR-015, FR-020). |
| `filtering?` | Whether a floor is in force. Drives the "no wish matches these filters" wording (FR-016) and distinguishes it from the pre-existing "nobody is looking" empty state. |
| `current?(floor)` | Whether a given choice is the one in force. Drives `aria-current` and the active styling (FR-015). |

**Why a PORO rather than a helper**: both axes need identical ordering, identical
selection-normalisation and the identical "keep an in-force selection visible" rule. Written as helper
methods that rule would be passed four arguments and repeated per axis; as one object instantiated
twice it is written once, and it is unit-testable without a database or a request (Principle I, and
the `floor_filter_test.rb` row in research R7).

**Ordering key**, stated once so the tests and the implementation agree:

```text
[ integer?(value) ? 0 : 1,  integer_value_or_0,  value ]
```

where `integer?` is `Integer(value, exception: false)` being non-nil. `"-1"` sorts before `"1"`;
`"3"` before `"10"`; `"RDC"` after every number; `"3.5"` lands in the alphabetical group because it is
not an Integer (research R4).

---

## Request-level state

Not persisted anywhere. The selections exist only as query parameters and as the two `FloorFilter`
instances built from them for the duration of one render.

| Parameter | Meaning | Absent / blank |
|---|---|---|
| `looking_for` | Exact `locker_wishes.floor` to match | All floors |
| `current_floor` | Exact `users.floor` to match | All floors |

Nothing is written to the session, to a cookie or to the user record — which is what makes the
Assumption true that opening the screen fresh from the navigation shows every wish, while the
selections still survive the declare/cancel redirect that carries them explicitly (FR-019).

---

## What is deliberately not modelled

- **No `Floor` entity.** The spec's Key Entities section is explicit that this feature introduces no
  list of valid floors; the choices are derived from the wishes that exist and vanish when those
  wishes do.
- **No saved filter preference.** Out of scope per the Assumptions; the address is the only carrier.
- **No multi-select.** One floor per axis, per the Assumptions, which is why `selection` is a single
  value rather than a collection.
- **No "not set" pseudo-floor** for people with no saved floor. Out of scope per the Assumptions;
  those rows are reached by leaving the current-floor axis on "all floors", which the `owner_on_floor`
  no-op-on-blank behaviour gives directly.
