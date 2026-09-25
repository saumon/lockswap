# Implementation Plan: Configurable Floors and Locker Number Format

**Branch**: `030-configurable-floors-locker-format` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/030-configurable-floors-locker-format/spec.md`

## Summary

The danger zone gets two new super-admin-only settings, each stored in its own singleton model that
follows the `SiteLanguageSetting` shape (research.md R1):

- **`SiteFloorList`**: an ordered JSON array of floor labels, entered as one comma-separated line. It is
  `NULL` until first saved, and while it is `NULL` every floor field stays free text (FR-006).
- **`LockerNumberFormat`**: a regular expression plus an optional plain-language description. It is
  always matched against the whole stripped value, under a 100 ms timeout (R4).

Enforcement is one validator per rule, shared across models: `SiteFloorValidator` for `User` and
`LockerWish`, and `LockerNumberFormatValidator` for `User`. Each validator skips a value that is not
changing, which is how "existing data is kept until next edited" (FR-011, FR-017) holds without
migrating anything.

The three floor entry forms share a new `shared/_floor_field` partial: a text field while the list is not
configured, a `<select>` in typed order once it is, and the saved floor kept as "(no longer offered)" if
it has been removed (R6).

The examples table computes its accepted/refused results with the same matcher that enforces the format,
so the screen cannot claim something the site does not do (R8, SC-004).

Two single-action controllers (`Admin::FloorListController`, `Admin::LockerNumberFormatController`) are
guarded by the existing `require_super_admin!`. The danger zone's per-controller "reload everything for
the re-render" code, which will have four copies, is pulled into a `LoadsDangerZone` concern (R7).

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged). It relies on `Regexp.new(…, timeout:)` (Ruby ≥ 3.2).

**Primary Dependencies**: Rails 8.1.3, Devise 5.0, Turbo/Stimulus via importmap, Tailwind v4 via
`tailwindcss-rails`. **No new gem, no new Stimulus controller**: the floor select is a native control, and
validation stays server-side (the forms are `novalidate`, R4).

**Storage**: SQLite. **Two migrations**: `create_site_floor_lists` (`floors json NULL`) and
`create_locker_number_formats` (`pattern string NULL`, `description string NULL`). There is no data
migration and no seed; both start "not configured" (clarification Q2).

**Testing**: Minitest, Rails system tests (Capybara, headless Chrome), axe-core. New files:
`test/models/site_floor_list_test.rb`, `test/models/locker_number_format_test.rb`,
`test/validators/site_floor_validator_test.rb`, `test/validators/locker_number_format_validator_test.rb`,
`test/controllers/admin/floor_list_controller_test.rb`,
`test/controllers/admin/locker_number_format_controller_test.rb`. Extended: `user_test.rb`,
`locker_wish_test.rb`, `admin_danger_zone_test.rb`, `locker_profile_test.rb`, `locker_wish_test.rb`
(system), `admin_user_detail_test.rb`, `accessibility_test.rb`.

**Target Platform**: Linux server, Docker + Kamal (unchanged).

**Project Type**: Web, server-rendered Rails monolith, single project.

**Performance Goals**: No swap or lock execution path changes. A locker profile or wish save adds at most
two single-row primary-key reads and one bounded regexp match (R9).

**Constraints**: CLAUDE.md design contract: one breakpoint (48rem), no raw hex in templates, one
definition per component, the `.btn-primary` submit stays an `<input type="submit">`, and there is no
uppercase. Every string goes through I18n in `en.yml` and `fr.yml` (Constitution III).

**Scale/Scope**: One building, at most 50 floors, a pattern of at most 200 characters. Six forms or
screens are touched: the danger zone, the home locker profile (first entry and pencil editor), the
locker wish declare and change-floor forms, and the admin account editor.

## Constitution Check

*GATE: must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | How |
|---|---|---|
| I. Code Quality | ✅ | One validator per rule, reused across models. One floor-field partial for three forms. The danger zone loading moves from three copies to one concern instead of five. Public model methods (`.current`, `matches?`, `display`, `offers?`) are documented at their definitions. rubocop and brakeman are clean. |
| II. Testing (non-negotiable) | ✅ | Model, validator and controller tests are written first and fail without the change. System tests cover US1–US4, including direct submissions of refused values. The examples' outcomes are asserted, so a matcher change fails a test. No flaky patterns: fixed fixtures (`frank`, `grace`) and no timing-dependent assertions. The timeout test uses a pattern whose non-linearity is established (back-reference) and asserts refusal, not duration. |
| III. UX Consistency | ✅ | Reuses `.card--alert`, `field-input` (already on a `<select>`), `.data-table`, `.badge-*`, the error-messages partial, and flash notices. The danger zone's per-section form pattern is preserved. The native `<select>` is labelled and keyboard-operable (SC-007). Colour is never the only signal (badges carry words). Every new string is in `en.yml` and `fr.yml`. **Breaking change called out**: once a list is saved, floors can no longer be typed freely. This is intended and will be stated in the PR. |
| IV. Performance | ✅ | Primary-key lookups on single-row tables only. The list is capped at 50, the pattern at 200 characters, and each match has a timeout. There are no new queries in loops and no change on the swap/lock paths, so no benchmark is required. |

**Post-design re-check (after Phase 1)**: no violations. Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/030-configurable-floors-locker-format/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── danger-zone-locker-settings.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks, not created here
```

### Source Code (repository root)

```text
db/migrate/
├── YYYYMMDDHHMMSS_create_site_floor_lists.rb           # new
└── YYYYMMDDHHMMSS_create_locker_number_formats.rb      # new

app/models/
├── site_floor_list.rb                 # new: singleton, floors_text, validations
├── locker_number_format.rb            # new: singleton, matches?, display, EXAMPLES
├── user.rb                            # + two validations, normalizes strips
└── locker_wish.rb                     # + site_floor validation

app/validators/                        # new directory (autoloaded by Rails)
├── site_floor_validator.rb
└── locker_number_format_validator.rb

app/controllers/
├── concerns/loads_danger_zone.rb      # new: one loader for the danger zone re-render
└── admin/
    ├── danger_zone_controller.rb          # uses LoadsDangerZone
    ├── allowed_email_domains_controller.rb # uses LoadsDangerZone
    ├── floor_list_controller.rb           # new
    └── locker_number_format_controller.rb # new

app/views/
├── shared/_floor_field.html.erb       # new: text field or select
├── admin/danger_zone/show.html.erb    # + floors card, + locker format card and examples
├── home/_locker_profile_form.html.erb # floor → shared partial; locker hint states format
├── locker_wishes/_locker_wish_form.html.erb      # floor → shared partial
└── admin/users/_locker_profile_editor.html.erb   # floor → shared partial; locker hint

config/routes.rb                       # + two singular resources under admin
config/locales/en.yml, fr.yml          # every new key, both languages
app/assets/tailwind/application.css    # only if the examples' sample/badge pairing needs a layout rule

test/  (see Technical Context → Testing)
```

**Structure Decision**: The existing Rails monolith layout. The only new directory is `app/validators/`,
which is Rails' conventional home for `EachValidator` classes and is autoloaded without configuration.

## Complexity Tracking

No constitution violations to justify.
