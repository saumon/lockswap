# Implementation Plan: Locker Map (Zones per Floor)

**Branch**: `031-locker-map-zones` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/031-locker-map-zones/spec.md`

## Summary

A new admin-only screen (`GET /admin/locker_map`, `require_admin!` — not the stricter
`require_super_admin!` the Danger Zone uses, research.md R7) lets an admin declare, per floor, the zones
that exist and, per zone, the locker numbers in it. Two new models carry this: `Zone` (a name, fixed to one
floor at creation) and `LockerMapEntry` (a floor + locker number pair, belonging to one zone, unique
site-wide on `(floor, locker_number)` — the same shape as the existing `users` unique index).

The two existing save paths that write a `User`'s floor + locker number together —
`LockerProfilesController#update` and `Admin::UserLockerProfilesController#update`, both already sharing
`User#save(context: :locker_profile_update)` — gain one more validator, `KnownLockerValidator`, which
refuses a save unless the resulting pair is `LockerMapEntry.known?`. It skips exactly when neither
`:locker_number` nor `:floor` is changing (research.md R3), which is what makes an already-saved,
not-yet-declared pair (FR-013) keep displaying without being touched. (`LockerWish` has no locker number at
all — research.md R1 — so it is untouched by this feature, correcting an assumption in the spec's first
draft.)

Deleting a zone cascades to its locker numbers in one action (`dependent: :destroy`, research.md R4/R6). A
zone's floor is fixed at creation and never re-editable; its name must be unique among the zones on its
floor.

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged).

**Primary Dependencies**: Rails 8.1.3, Devise 5.0, Turbo/Stimulus via importmap, Tailwind v4 via
`tailwindcss-rails`. **No new gem, no new Stimulus controller** — every write is a plain form post; the
Locker Map screen is server-rendered like every other admin screen.

**Storage**: SQLite. **Two migrations**: `create_zones` (`floor string NOT NULL`, `name string NOT NULL`,
unique index `(floor, name)`) and `create_locker_map_entries` (`zone_id` FK, `floor string NOT NULL`,
`locker_number string NOT NULL`, unique index `(floor, locker_number)`, index on `zone_id`). No data
migration and no seed — both tables start empty, and FR-013 defines what that means for existing `User`
rows.

**Testing**: Minitest, Rails system tests (Capybara, headless Chrome), axe-core. New files:
`test/models/zone_test.rb`, `test/models/locker_map_entry_test.rb`,
`test/validators/known_locker_validator_test.rb`, `test/controllers/admin/locker_map_controller_test.rb`,
`test/controllers/admin/zones_controller_test.rb`,
`test/controllers/admin/locker_map_entries_controller_test.rb`. Extended:
`test/models/user_test.rb`, `test/controllers/locker_profiles_controller_test.rb`,
`test/controllers/admin/user_locker_profiles_controller_test.rb`, a new
`test/system/admin_locker_map_test.rb`, and `test/system/accessibility_test.rb`.

**Target Platform**: Linux server, Docker + Kamal (unchanged).

**Project Type**: Web, server-rendered Rails monolith, single project.

**Performance Goals**: No swap or lock execution path changes. A locker profile save adds exactly one more
indexed existence check (`LockerMapEntry.known?`, hitting the new `(floor, locker_number)` unique index) —
the same order of cost 030 already added for the format-pattern check.

**Constraints**: CLAUDE.md design contract: one breakpoint (48rem), no raw hex in templates, one definition
per component (the new-zone form reuses `shared/_floor_field` rather than a second floor picker,
research.md R2), the swap-axis colours are never spent on a screen that is neither "you" nor "them" — zone
cards hang on the default navy (`--color-rail-system`) hinge, not `--you`/`--them`. Every string goes
through I18n in `en.yml` and `fr.yml` (Constitution III).

**Scale/Scope**: One building, at most 50 floors (existing `SiteFloorList::MAX_FLOORS`), zone names capped
at 60 characters (data-model.md `MAX_NAME_LENGTH`). Four screens/flows touched: the new Locker Map screen,
the home locker profile form, the locker wish form is **not** touched (research.md R1), and the admin
account editor.

## Constitution Check

*GATE: must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | How |
|---|---|---|
| I. Code Quality | ✅ | One validator (`KnownLockerValidator`) shared by both save paths, mirroring `SiteFloorValidator`/`LockerNumberFormatValidator`'s existing shape. `Zone`/`LockerMapEntry` follow the singleton-adjacent, well-documented style of `SiteFloorList`/`LockerNumberFormat` (this time a real one-to-many, not a singleton). The new-zone form reuses `shared/_floor_field` rather than duplicating it. Public methods (`.known?`, `saved_floor`) documented at their definitions. rubocop and brakeman clean. |
| II. Testing (non-negotiable) | ✅ | Model, validator and controller tests written first, failing without the change. System test covers US1–US3 including the cascading delete and the "pair, not either half" refusal (US2 scenario 4). No flaky patterns: fixed fixtures (`grace`, `carol`), no timing-dependent assertions. |
| III. UX Consistency | ✅ | Reuses `.card`, `.data-table`, `field-input`, the error-messages partial, flash notices, and `shared/_floor_field`. Nav link placed beside "Users" in the existing admin submenu (`current_user.admin?`), not the super-admin-only section. Zone cards use the default (system) hinge, never `--you`/`--them` — a zone belongs to neither side. Every new string in `en.yml` and `fr.yml`. **No breaking change to existing UX**: the locker number field stays free text everywhere (FR-009) — only its *acceptance* rule changes, and only once an admin has populated at least one zone on that floor. |
| IV. Performance | ✅ | One new indexed existence check per locker profile save; no new queries in a loop. The Locker Map screen itself loads all zones/entries with `includes`, bounded by real building size, and is admin-only (no hot path). No swap/lock execution path touched. |

**Post-design re-check (after Phase 1)**: no violations. Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/031-locker-map-zones/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── admin-locker-map.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks, not created here
```

### Source Code (repository root)

```text
db/migrate/
├── YYYYMMDDHHMMSS_create_zones.rb                # new
└── YYYYMMDDHHMMSS_create_locker_map_entries.rb   # new

app/models/
├── zone.rb                    # new: floor (fixed), name (unique per floor), cascades to entries
├── locker_map_entry.rb        # new: floor (derived from zone), locker_number, .known?
└── user.rb                    # + one validation (known_locker)

app/validators/
└── known_locker_validator.rb  # new

app/controllers/admin/
├── locker_map_controller.rb        # new: #show — the one screen
├── zones_controller.rb             # new: #create #update #destroy
└── locker_map_entries_controller.rb # new: #create #destroy, nested under zones

app/views/admin/
├── locker_map/show.html.erb        # new: per-floor sections of zone cards
└── zones/
    ├── _zone.html.erb              # new: one zone card — rename form, locker list, add/remove, delete
    └── _new_zone_form.html.erb     # new: per-floor "add a zone" form (reuses shared/_floor_field)

app/views/shared/_site_menu_items.html.erb  # + "Locker Map" link, admin? section (not super_admin?)

config/routes.rb                       # + admin locker_map/zones/locker_map_entries routes
config/locales/en.yml, fr.yml          # every new key, both languages
app/assets/tailwind/application.css    # only if the per-floor zone-card layout needs a new rule

test/  (see Technical Context → Testing)
```

**Structure Decision**: The existing Rails monolith layout. No new top-level directory — `zones_controller.rb`
and `locker_map_entries_controller.rb` join `app/controllers/admin/`, alongside `floor_list_controller.rb`
and `user_locker_profiles_controller.rb`, which already establish "one small controller per write."

## Complexity Tracking

No constitution violations to justify.
