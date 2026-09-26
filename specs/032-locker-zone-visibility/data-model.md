# Data Model: Locker Zone Visibility Across Screens

This feature introduces **no new entity, no new table, and no new column**. It adds two read-only accessors
to existing models (031's `Zone`/`LockerMapEntry`, and `LockerSwapProposal`), described below as the
"interface" this feature is built on. See `research.md` R1–R3 for the reasoning behind each.

## Existing entities, unchanged

- **Zone** (`app/models/zone.rb`, 031): a named group of lockers, fixed to one floor. Only its `name` is
  newly *read* by more screens; nothing about how a `Zone` is created, renamed, or deleted changes.
- **Locker Map Entry** (`app/models/locker_map_entry.rb`, 031): the declaration that a `(floor,
  locker_number)` pair belongs to a `Zone`, unique on that pair site-wide. This feature adds two new ways to
  *read* it; it adds no new way to write it.

## New accessors

### `LockerMapEntry.zone_names_for(pairs)`

- **Input**: an array of `[floor, locker_number]` pairs (each element a string or `nil`; normalized the same
  way `.known?` already normalizes — stripped, blank → `nil`).
- **Output**: a `Hash` keyed by the normalized `[floor, locker_number]` pair, valued by the owning zone's
  `name` (a `String`). A pair that is not currently declared in the Locker Map is simply absent from the
  Hash (not present with a `nil` value) — callers test with `Hash#[]` returning `nil` for "no zone".
- **Cost**: exactly one query (`joins(:zone).where(floor: ..., locker_number: ...)`), independent of how many
  pairs are requested or how many rows the calling screen renders.
- **Empty input**: an empty array (e.g., a list screen with zero rows) returns `{}` without querying.

### `LockerMapEntry.zone_name_for(floor, locker_number)`

- **Input**: a single floor and locker number.
- **Output**: the zone's `name` (`String`) if the pair is declared, else `nil`.
- **Implementation**: a thin wrapper over `.zone_names_for([[floor, locker_number]])`.

### `LockerSwapProposal#locker_sides`

- **Output**: an array of two `[floor, locker_number]` pairs, `[requester_side, recipient_side]`, computed
  exactly the way `floor_and_locker_summary`'s existing private `sides` method already does — reading the
  live `requester`/`recipient` associations' `floor`/`locker_number` while the proposal is `pending?` or
  `accepted?`, and the frozen `*_at_resolution` columns once it is settled (declined or completed).
- **Purpose**: gives the swap-history table (and any future caller) the same two pairs
  `floor_and_locker_summary` already turns into one joined sentence, so they can also be resolved against
  `LockerMapEntry.zone_names_for` and rendered as a separate, visually distinct element (FR-008) — without
  re-deriving the pending/accepted-vs-settled branching a second time.

## Validation rules

None added. This feature performs no writes and introduces no new validated attribute; `Zone` and
`LockerMapEntry`'s existing validations (031) are untouched.

## State transitions

None added. A `Zone`/`LockerMapEntry` row's lifecycle (create, rename, cascade-delete) is exactly what 031
already defined; this feature only reads whatever that lifecycle currently says.
