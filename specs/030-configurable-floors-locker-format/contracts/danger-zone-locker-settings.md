# Contract: Danger zone locker settings — routes, parameters, responses, copy

**Feature**: [../spec.md](../spec.md) | **Branch**: `030-configurable-floors-locker-format`

This is not a network API. It lists the routes, parameters, responses and locale keys that the
controllers, views and tests all refer to, in the same way 029's `super-admin-access.md` does.

## Routes (new, inside `namespace :admin`)

| Verb | Path | Helper | Controller#action | Guard |
|---|---|---|---|---|
| PATCH | `/admin/floor_list` | `admin_floor_list_path` | `Admin::FloorListController#update` | `authenticate_user!`, `require_super_admin!` |
| PATCH | `/admin/locker_number_format` | `admin_locker_number_format_path` | `Admin::LockerNumberFormatController#update` | `authenticate_user!`, `require_super_admin!` |

Both are shown on `GET /admin/danger_zone` (unchanged route, super admin only since 029).

## `PATCH /admin/floor_list`

- **Params**: `site_floor_list[floors_text]` (string, comma-separated). Nothing else is permitted.
- **Success**: `302 → admin_danger_zone_path`, notice `admin.floor_list.update.saved`. It contains no
  conformance count (clarification Q4).
- **Refused (validation)**: `422`. It renders `admin/danger_zone/show`, with the error inside the
  `#danger-zone-floors` card, and the field keeps the submitted text. The saved list is unchanged.
- **Not the super admin**: `302 → root_path`, alert `application.administrators_only` (existing, 029).

## `PATCH /admin/locker_number_format`

- **Params**: `locker_number_format[pattern]`, `locker_number_format[description]` (both strings,
  optional).
- **Success**: `302 → admin_danger_zone_path`, notice `admin.locker_number_format.update.saved`, or
  `…update.cleared` when the pattern was blank.
- **Refused**: `422`. It renders `admin/danger_zone/show`, with the error inside the
  `#danger-zone-locker-format` card. The saved format is unchanged.
- **Not the super admin**: as above.

## Danger zone screen — new sections (order: language, floors, locker format, domains)

| Element id | Content |
|---|---|
| `#danger-zone-floors` | `.card.card--alert`: an explanation, the current list or the "not configured — floors are free text" statement, a text field `site_floor_list_floors_text` with a hint (comma-separated, no comma inside a floor), and the submit `admin.danger_zone.show.save_floors_button` |
| `#danger-zone-locker-format` | `.card.card--alert`: an explanation, the pattern field `locker_number_format_pattern` (mono), the description field `locker_number_format_description`, the submit `…save_format_button`, and the examples table `#locker-format-examples` |
| `#locker-format-examples` | `.data-table` with columns Pattern / Meaning / Samples. Each sample is a `.data-value` plus a `.badge-success` ("Accepted") or a `.badge-error` ("Refused"), computed with `LockerNumberFormat#matches?` |

## Floor field (shared partial `shared/_floor_field`) — used by the three entry forms

| List state | Renders |
|---|---|
| Not configured | `<input type="text" name="…[floor]">`, as today |
| Configured | `<select name="…[floor]">`: a blank prompt `shared.floor_field.prompt`, then the configured floors in typed order |
| Configured, and the record's saved floor is not in the list | as above, plus the saved floor selected, with label `shared.floor_field.no_longer_offered` (`%{floor} (no longer offered)`) |

The field id and label stay the same as today (`user_floor`, `locker_wish_floor`), so
`select "0", from: "Floor"` works the same way `fill_in` did.

## Locker number field hint

When a format is in force, `user.locker_number_format_hint` (`Required format: %{expected}`) is added to the
field's `aria-describedby` hint, with `%{expected}` = `LockerNumberFormat#display` (not `%{format}`, which I18n reserves).

## Model errors

| Key | en | fr |
|---|---|---|
| `errors.messages.floor_not_offered` | is not one of the site's floors | ne fait pas partie des étages du site |
| `errors.messages.locker_number_format_mismatch` | must match the required format: %{expected} | doit respecter le format requis : %{expected} |
| `floor_list.messages.required` | must list at least one floor | doit contenir au moins un étage |
| `floor_list.messages.too_many` | A maximum of 50 floors can be listed | 50 étages au maximum peuvent être saisis |
| `floor_list.messages.floor_too_long` | "%{floor}" is longer than 20 characters | « %{floor} » dépasse 20 caractères |
| `locker_number_format.messages.invalid_pattern` | is not a valid regular expression | n'est pas une expression régulière valide |

The final wording is settled in the locale files. `test/i18n_completeness_test.rb` enforces that both
languages have every key.
