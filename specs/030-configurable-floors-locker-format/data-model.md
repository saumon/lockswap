# Data Model: Configurable Floors and Locker Number Format

**Feature**: 030-configurable-floors-locker-format

## New: `SiteFloorList` (table `site_floor_lists`)

A singleton: at most one row, read only through `.current` (research.md R1).

| Column | Type | Null | Notes |
|---|---|---|---|
| `id` | integer | no | |
| `floors` | json | **yes** | An ordered array of strings. `NULL` means never configured (FR-006) |
| `created_at` / `updated_at` | datetime | no | |

- **Virtual attribute** `floors_text` (string): on write, split on `,`, strip, drop blanks, keep the first
  occurrence of a duplicate, and assign `floors`. On read, `Array(floors).join(", ")`.
- **Validations**:
  - `floors` must not be empty whenever it is being saved (FR-003): `floor_list.messages.required`.
  - at most 50 entries: `floor_list.messages.too_many`.
  - each entry at most 20 characters: `floor_list.messages.floor_too_long`.
  - `only_one_row_may_exist`, on `:create`.
- **Class methods**: `.current` → `first_or_create!(floors: nil)`.
- **Instance methods**: `configured?` → `floors.present?`; `offers?(floor)` → `floors.include?(floor)`.
- **State**: *not configured* (`floors` is `NULL`) → *configured* (a non-empty array). There is no way
  back: a blank submission is refused.

## New: `LockerNumberFormat` (table `locker_number_formats`)

A singleton, like the above.

| Column | Type | Null | Notes |
|---|---|---|---|
| `id` | integer | no | |
| `pattern` | string | yes | The regular expression source as typed. `NULL` means no format (any value accepted) |
| `description` | string | yes | Plain-language text shown to users in place of the pattern (clarification Q1) |
| `created_at` / `updated_at` | datetime | no | |

- **Normalisation**: `pattern` and `description` are stripped, and blank becomes `nil`. A `nil` pattern
  clears the description (FR-009).
- **Validations**:
  - `pattern`: at most 200 characters, and its **anchored** form (`\A(?:pattern)\z`, the same one
    `matches?` uses) must compile. A `RegexpError` gives `locker_number_format.messages.invalid_pattern`
    (FR-010).
  - `description`: at most 100 characters.
  - `only_one_row_may_exist`, on `:create`.
- **Constants**: `EXAMPLES`, the fixed examples table (research.md R8); `MATCH_TIMEOUT = 0.1` seconds.
- **Instance methods**:
  - `in_force?` → `pattern.present?`.
  - `matches?(value)`: strips the value, matches it against `\A(?:pattern)\z` with the timeout, and
    returns false on `Regexp::TimeoutError` or `RegexpError` (FR-014, FR-018).
  - `display` → `description.presence || pattern`.
- **State**: *no format* ⇄ *format in force*. Either transition is allowed at any time (User Story 3,
  scenario 4).

## Changed: `User`

- `normalizes :locker_number` becomes strip-then-blank-to-`nil` (research.md R5).
- `validates :floor, site_floor: true, on: :locker_profile_update`.
- `validates :locker_number, locker_number_format: true, on: :locker_profile_update`.
- No schema change. Existing non-conforming values stay in place (FR-011, FR-017).

## Changed: `LockerWish`

- `validates :floor, site_floor: true`.
- No schema change.

## New validators (`app/validators/`)

| Validator | Skips when | Error key |
|---|---|---|
| `SiteFloorValidator` | the list is not configured, the value is blank, or the attribute is not changing | `errors.messages.floor_not_offered` |
| `LockerNumberFormatValidator` | no format is in force, the value is `nil`, or the attribute is not changing | `errors.messages.locker_number_format_mismatch` (with `%{format}`) |

The error keys live under the shared `errors.messages` namespace, so both models use one entry per
language rather than one per model.

## Unchanged, on purpose

- `locker_swap_proposals.*_floor_at_resolution` / `*_locker_number_at_resolution`: history is never
  rewritten (FR-021).
- `FloorFilter`, `User.saved_floors`, `LockerWish.looked_for_floors` / `.owner_floors`: the filters keep
  reading the floors found in the data, in their existing sort (FR-008, clarification Q3).
- The unique index on `users (floor, locker_number)` (006).
