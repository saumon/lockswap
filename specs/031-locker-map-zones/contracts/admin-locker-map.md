# Contract: Locker Map screen — routes, parameters, responses, copy

**Feature**: [../spec.md](../spec.md) | **Branch**: `031-locker-map-zones`

Not a network API — the routes, parameters, responses and locale keys the controllers, views and tests all
refer to, the same way 030's `danger-zone-locker-settings.md` does.

## Routes (new, inside `namespace :admin`)

| Verb | Path | Helper | Controller#action | Guard |
|---|---|---|---|---|
| GET | `/admin/locker_map` | `admin_locker_map_path` | `Admin::LockerMapController#show` | `authenticate_user!`, `require_admin!` |
| POST | `/admin/zones` | `admin_zones_path` | `Admin::ZonesController#create` | `authenticate_user!`, `require_admin!` |
| PATCH | `/admin/zones/:id` | `admin_zone_path` | `Admin::ZonesController#update` | `authenticate_user!`, `require_admin!` |
| DELETE | `/admin/zones/:id` | `admin_zone_path` | `Admin::ZonesController#destroy` | `authenticate_user!`, `require_admin!` |
| POST | `/admin/zones/:zone_id/locker_map_entries` | `admin_zone_locker_map_entries_path` | `Admin::LockerMapEntriesController#create` | `authenticate_user!`, `require_admin!` |
| DELETE | `/admin/zones/:zone_id/locker_map_entries/:id` | `admin_zone_locker_map_entry_path` | `Admin::LockerMapEntriesController#destroy` | `authenticate_user!`, `require_admin!` |

All six use `require_admin!` (research.md R7) — a standard user gets `302 → root_path`, alert
`application.administrators_only`, same as every other `require_admin!`-guarded destination.

## `GET /admin/locker_map`

- Loads every floor the site currently offers (`SiteFloorList.current`, falling back to the distinct floors
  already used by a `Zone` when the list is not configured, so existing zones are never orphaned off the
  screen), each with its `Zone`s (`includes(:locker_map_entries)`, ordered by name) and each zone's locker
  numbers (FR-002). These per-floor sections are read-only groupings — they do not gate zone creation.
- **One standalone "add a zone" form** (not nested in any floor section) offers `shared/_floor_field` for
  the floor and a name field (FR-003) — this is what lets an admin declare the first zone on a brand-new
  floor with nothing configured yet (research.md R2, correcting an earlier draft that nested this form per
  floor section and could never bootstrap the first zone). Each zone card offers its rename form (FR-004),
  its add-locker form (FR-005), a remove control per locker number (FR-006), and a delete-zone control
  (FR-006).

## `POST /admin/zones`

- **Params**: `zone[floor]`, `zone[name]`.
- **Success**: `302 → admin_locker_map_path`, notice `admin.zones.create.saved`.
- **Refused (validation)**: `422`, re-renders `admin/locker_map/show` with the new-zone form's error inline
  under the floor it was submitted for (blank name, duplicate name on that floor — FR-004a — or a floor not
  in the site's list — FR-011).
- **Refused (race)**: `ActiveRecord::RecordNotUnique` rescued the same way locker-entry creation rescues it
  below — adds a generic name-already-taken error on `:name` and re-renders `422` rather than a `500`
  (`zones(floor, name)`'s unique index, research.md R6, applied symmetrically; found missing by
  `/speckit-analyze`, finding M1).

## `PATCH /admin/zones/:id`

- **Params**: `zone[name]` only — no `zone[floor]` is ever accepted; a submitted one is ignored (FR-003,
  FR-004: a zone's floor is fixed at creation).
- **Success**: `302 → admin_locker_map_path`, notice `admin.zones.update.saved`.
- **Refused**: `422`, re-renders with the rename error inline on that zone's card (blank or duplicate name),
  including the same `RecordNotUnique` race rescue as `POST /admin/zones` above.
- **Zone gone** (deleted by someone else since the page loaded): `302 → admin_locker_map_path`, alert
  `admin.zones.update.zone_gone`.

## `DELETE /admin/zones/:id`

- **Success**: `302 → admin_locker_map_path`, notice `admin.zones.destroy.deleted` — the zone and every
  locker number in it are gone in one action (FR-006, research.md R4), whatever it contained.
- **Zone gone already**: `302 → admin_locker_map_path`, notice `admin.zones.destroy.deleted` anyway (already
  the desired end state — mirrors `Admin::UsersController#grant_admin`'s "arriving second reports success").

## `POST /admin/zones/:zone_id/locker_map_entries`

- **Params**: `locker_map_entry[locker_number]`.
- **Success**: `302 → admin_locker_map_path`, notice `admin.locker_map_entries.create.saved`.
- **Refused (validation)**: `422`, re-renders with the error inline on that zone's card — blank number, or
  the floor + number pair already claimed by another zone, naming that zone (FR-008).
- **Refused (race)**: `ActiveRecord::RecordNotUnique` rescued the same way
  `LockerProfilesController#save_locker_profile` rescues it — adds a generic "already claimed" error and
  re-renders `422`, rather than a 500 (research.md R6).
- **Zone gone**: `302 → admin_locker_map_path`, alert `admin.locker_map_entries.create.zone_gone` — a
  **distinct key** from `admin.zones.update.zone_gone` (Rails' lazy `t(".zone_gone")` resolves relative to
  the current controller#action, so the two save paths need their own keys even though the wording matches;
  found missing by `/speckit-analyze`, finding H1).

## `DELETE /admin/zones/:zone_id/locker_map_entries/:id`

- **Success**: `302 → admin_locker_map_path`, notice `admin.locker_map_entries.destroy.deleted`.
- **Already gone**: notice `…deleted` anyway (same "arriving second" posture as zone deletion).

## Existing screens — new refusal on `User#save(context: :locker_profile_update)`

Both `LockerProfilesController#update` and `Admin::UserLockerProfilesController#update` already share this
context and its `422` re-render behavior; nothing about their routes, params or response shapes changes.
`KnownLockerValidator` adds one more possible field error on `:locker_number`.

| Screen | Field the error attaches to | Copy key |
|---|---|---|
| `home/_locker_profile_form.html.erb` | `user_locker_number` | `errors.messages.locker_number_unknown` |
| `admin/users/_locker_profile_editor.html.erb` | `user_locker_number` | `errors.messages.locker_number_unknown` |

The locker number field itself is unchanged in both forms — still `form.text_field :locker_number` (FR-009).

## Model errors

| Key | en | fr |
|---|---|---|
| `errors.messages.locker_number_unknown` | is not a recognized locker — ask an administrator to add it to the locker map | n'est pas un casier reconnu — demandez à un administrateur de l'ajouter à la cartographie |
| `zone.messages.name_taken` | is already used by another zone on this floor | est déjà utilisé par une autre zone sur cet étage |
| `locker_map_entry.messages.locker_taken` | is already claimed by zone "%{zone}" on this floor | est déjà attribué à la zone « %{zone} » sur cet étage |
| `admin.locker_map_entries.create.zone_gone` | That zone no longer exists. | Cette zone n'existe plus. |
| `admin.zones.update.zone_gone` | That zone no longer exists. | Cette zone n'existe plus. |

The final wording is settled in the locale files. `test/i18n_completeness_test.rb` enforces that both
languages have every key.
