# Data Model: Locker Map (Zones per Floor)

**Feature**: 031-locker-map-zones

## New: `Zone` (table `zones`)

A named group of lockers, located on exactly one floor, fixed at creation (031 clarification;
research.md R4/R7 for related decisions — floor immutability itself is R-none, it is simply never exposed
on the edit form).

| Column | Type | Null | Notes |
|---|---|---|---|
| `id` | integer | no | |
| `floor` | string | no | Set at creation only; no controller action ever assigns it again |
| `name` | string | no | Admin-entered, editable |
| `created_at` / `updated_at` | datetime | no | |

- **Associations**: `has_many :locker_map_entries, dependent: :destroy` (research.md R4 — deleting a zone
  cascades to its lockers in one action, per 031 clarification).
- **Normalisation**: `normalizes :name, with: ->(value) { value.to_s.strip.presence }` (FR-004a, Assumptions:
  zone names must be non-blank).
- **Validations**:
  - `name`: `presence: true`; `uniqueness: { scope: :floor }` (FR-004a) — case-sensitive exact match
    (research.md R5), message names the floor since the same name is fine on a different floor.
  - `name`: `length: { maximum: MAX_NAME_LENGTH }` (60 — same order of magnitude as `SiteFloorList::MAX_FLOOR_LENGTH`,
    a sane bound rather than a user-facing decision point).
  - `floor`: `presence: true`; `site_floor: true` (FR-011 — a zone can only be declared on a floor the rest
    of the site also recognizes; reuses `SiteFloorValidator` unchanged, with no `on:` restriction — the
    validator already skips whenever `floor` is not changing, and since nothing ever reassigns `floor` after
    creation, it is naturally inert on every later save; no context scoping is needed to achieve that).
- **Instance methods**: `saved_floor = floor_in_database` (research.md R2 — the floor picker on the
  standalone "add a zone" form; see research.md R2's correction for why this form is not nested per floor
  section).
- **Lifecycle**: created with a floor (fixed forever) and a name (editable); deleted, cascading to its
  entries. No other state.

## New: `LockerMapEntry` (table `locker_map_entries`)

The declaration that one floor + locker number pair exists and belongs to one zone — the site's
authoritative "known locker" registry (FR-005 through FR-008, FR-012).

| Column | Type | Null | Notes |
|---|---|---|---|
| `id` | integer | no | |
| `zone_id` | integer | no | FK to `zones`, indexed |
| `floor` | string | no | Copied from `zone.floor` once, at creation (research.md R6) — never reassigned |
| `locker_number` | string | no | Admin-entered |
| `created_at` / `updated_at` | datetime | no | |

- **Indexes**: unique `(floor, locker_number)` — the real, race-safe guarantee behind FR-007/FR-012, the
  same shape as `users`' existing unique `(floor, locker_number)` index (006, research.md R6). A plain
  index on `zone_id` for the belongs_to lookup and cascading delete.
- **Associations**: `belongs_to :zone`.
- **Normalisation**: `normalizes :locker_number, with: ->(value) { value.to_s.strip.presence }` — same shape
  as `User#normalizes :locker_number`, so a value declared here and a value typed on a locker profile are
  compared after the same trimming (spec Edge Cases: whitespace/case handling unchanged).
- **Callbacks**: `before_validation { self.floor = zone&.floor }` — derives `floor` from the parent zone so
  it can never drift from it (the zone's floor is itself immutable after creation, research.md R6).
- **Validations**:
  - `locker_number`: `presence: true`.
  - `locker_number`: `uniqueness: { scope: :floor, message: ->(entry, _data) { names the zone that already
    holds this floor + locker number } }` (FR-008) — the friendly pre-check; the unique index is the actual
    guarantee against two concurrent submissions both passing validation (research.md R6, mirrors
    `User::LOCKER_NUMBER_TAKEN_MESSAGE`'s lambda-message pattern exactly).
- **Class methods**: `.known?(floor, locker_number)` → `exists?(floor:, locker_number:)`, the one query
  `KnownLockerValidator` calls (FR-010) — normalizes its own input the same way (`strip.presence`) so a
  validator call from `User` (already normalized) and a direct call agree.
- **Lifecycle**: created under a zone; deleted individually (FR-006) or cascaded when its zone is deleted
  (FR-006, research.md R4). Deleting one never touches any `User` row that happens to hold the same pair
  (FR-013) — it only stops that pair from being *known* for future saves.

## Changed: `User`

- `validates :locker_number, known_locker: true, on: :locker_profile_update` — added alongside the existing
  `locker_number_format: true` validation (FR-010). Uses the new `KnownLockerValidator`
  (`app/validators/known_locker_validator.rb`).
- No schema change. Existing pairs not yet declared in the Locker Map keep displaying and are not touched
  (FR-013) — the validator only fires when `:locker_number` or `:floor` is actually changing (research.md
  R3).

## Unchanged, on purpose

- `LockerWish`: has no locker number and is not validated against the Locker Map at all (research.md R1).
- `locker_swap_proposals.*_floor_at_resolution` / `*_locker_number_at_resolution`: history snapshots, never
  re-validated (same posture 030 already established for this table).
- The unique index on `users (floor, locker_number)` (006): still the sole identity of a user's locker
  (FR-012); this feature adds a second, independent registry (`LockerMapEntry`) that a save is checked
  *against*, not a change to what makes two users' lockers the same or different.

## New validator (`app/validators/`)

| Validator | Applies to | Skips when | Error key |
|---|---|---|---|
| `KnownLockerValidator` | `User#locker_number`, `on: :locker_profile_update` | value blank; `record.floor` blank; the map has no `LockerMapEntry` at all, site-wide (research.md R8); neither `:locker_number` nor `:floor` is changing (research.md R3) | `errors.messages.locker_number_unknown` |

## State summary

```text
Zone:            created(floor fixed, name set) ──rename──> created(floor fixed, name changed)
                        │
                        └──delete──> gone (cascades to its LockerMapEntry rows)

LockerMapEntry:  created(under a zone) ──delete──> gone
                                        ──(zone deleted)──> gone (cascade)

User#locker_number/#floor: unaffected in shape; save is now checked against LockerMapEntry
  whenever locker_number or floor is part of the change (FR-010, FR-013).
```
