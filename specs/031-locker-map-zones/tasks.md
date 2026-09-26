---

description: "Task list for 031 — Locker Map (zones per floor)"
---

# Tasks: Locker Map (Zones per Floor)

**Input**: Design documents from `/specs/031-locker-map-zones/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/admin-locker-map.md, quickstart.md

**Tests**: Included. The constitution's Principle II is non-negotiable: every change ships with tests
that fail without it. In each story, the test tasks come first and must be seen failing before the
implementation tasks begin.

**Organization**: Grouped by user story (spec.md US1–US3). US2 is independently testable against the
Foundational models alone (it never needs the admin screen). US3 extends the screen US1 builds with
removal/deletion.

**Remediated by `/speckit-analyze`**: this file was revised after analysis found one CRITICAL and several
HIGH/MEDIUM cross-artifact issues. Each fix is marked with its finding ID (C1, H1, M1, M2) at the task it
touches; see research.md R2's correction and contracts/admin-locker-map.md for the corresponding design
changes.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1–US3 from spec.md

## Conventions for every task

- Every user-facing string is an I18n lookup with a matching entry in **both** `config/locales/en.yml`
  and `config/locales/fr.yml` (Constitution III). Key names are in contracts/admin-locker-map.md.
- Fixtures: `users(:grace)` is a granted (non-super) admin — the Locker Map screen's guard, `require_admin!`
  is satisfied by any admin (research.md R7), so `grace` exercises it rather than the super admin. `carol`
  (or `alice`/`bob`) are standard users, for the access-denial and locker-profile-save tests. **No fixture
  rows are added** for `zones` or `locker_map_entries`: the map starts empty, matching FR-013's premise.
  Tests that need a known locker create one directly:
  `Zone.create!(floor: "2", name: "Aile Nord").locker_map_entries.create!(locker_number: "203")`.
- Follow CLAUDE.md: no raw hex in ERB, one breakpoint (48rem), one definition per component (reuse
  `shared/_floor_field`, `.card`, `.data-table`, `field-input` — never a second implementation), no
  uppercase, and the confirmation for a destructive action (`button_to ..., data: { turbo_confirm: … }`)
  lives in the view, the same posture `Admin::UsersController#grant_admin`/`#revoke_admin` already take.
  Run `bin/rails tailwindcss:build` after any stylesheet edit.
- Comment style: match the surrounding code. Each new rule carries a short `# 031 FR-xxx:` note saying why,
  as existing files do.
- Zone cards use the **default** card hinge (no `--you`/`--them` modifier) — a zone belongs to neither side
  of the swap axis (CLAUDE.md). Floor and locker numbers render `.data-value` in `--font-mono`.
- New-screen accessibility coverage is added to `test/system/accessibility_test.rb`, the established home
  for every screen's axe audit (`assert_axe_clean`, from `application_system_test_case.rb`) — never inline
  inside a feature's own system test file (finding M2).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: The two tables every later phase reads.

- [X] T001 [P] Create migration `db/migrate/<timestamp>_create_zones.rb`: `create_table :zones` with `t.string :floor, null: false`, `t.string :name, null: false`, `t.timestamps`, and `add_index :zones, [:floor, :name], unique: true` (FR-004a).
- [X] T002 [P] Create migration `db/migrate/<timestamp>_create_locker_map_entries.rb`: `create_table :locker_map_entries` with `t.references :zone, null: false, foreign_key: true`, `t.string :floor, null: false`, `t.string :locker_number, null: false`, `t.timestamps`, and `add_index :locker_map_entries, [:floor, :locker_number], unique: true` (FR-007/FR-012, research.md R6).
- [X] T003 Run `bin/rails db:migrate` (and `bin/rails db:test:prepare`) and confirm both tables and both unique indexes appear in `db/schema.rb`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The two models and the show-screen loader every user story depends on (US1 to create through
them, US2 to validate against them, US3 to modify/delete through them).

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests for the foundational models ⚠️ (write first, see them fail)

- [X] T004 [P] Create `test/models/zone_test.rb`. It covers:
  - `name` presence: blank is invalid ("must have a name" via the standard presence message, Assumptions);
  - `name` uniqueness scoped to `floor`: two zones named "Aile Nord" on floor "2" — the second is invalid with `zone.messages.name_taken` (FR-004a); the same name on floor "3" is valid;
  - `name` length: a 61-character name is invalid ("at most 60 characters", `MAX_NAME_LENGTH`), a 60-character name is valid;
  - `floor` presence: blank is invalid;
  - `floor` must be one of `SiteFloorList.current`'s floors once one is configured (reuses `SiteFloorValidator` — mirror the "not configured → any floor accepted" and "listed floor accepted" cases from `test/models/user_test.rb`'s existing `site_floor` coverage);
  - `saved_floor` reads `floor_in_database` and is `nil` on a new, unpersisted `Zone` (research.md R2 — this is solely what lets the new-zone form reuse `shared/_floor_field`);
  - deleting a zone with locker map entries destroys them too (`dependent: :destroy`, research.md R4) — create a zone with two entries, `zone.destroy`, assert both `LockerMapEntry` rows are gone.
- [X] T005 [P] Create `test/models/locker_map_entry_test.rb`. It covers:
  - `locker_number` presence: blank is invalid;
  - `locker_number` uniqueness scoped to `floor`: a second entry for floor "2" / locker "203" in a *different* zone is invalid with a message naming the zone that already holds it (`locker_map_entry.messages.locker_taken`, FR-008); the same locker number on floor "3" is valid;
  - `floor` is derived from the parent zone, not settable directly: creating an entry under a zone on floor "2" gives the entry `floor == "2"` even if the caller never assigns it (`before_validation`, research.md R6);
  - `normalizes :locker_number`: `" 203 "` saves as `"203"` (same shape as `User#normalizes :locker_number`);
  - `.known?(floor, locker_number)`: true for a declared pair, false for an undeclared one, false when the floor matches but the locker number does not (and vice versa), and it normalizes its own input the same way (`.known?("2", " 203 ")` is true when `"203"` is declared).
- [X] T006 Create `app/models/zone.rb`. It needs:
  - `has_many :locker_map_entries, dependent: :destroy` (FR-006, research.md R4);
  - `normalizes :name, with: ->(value) { value.to_s.strip.presence }`;
  - `MAX_NAME_LENGTH = 60`;
  - validations: `name` — `presence: true`, `uniqueness: { scope: :floor, message: ->(_record, _data) { I18n.t("zone.messages.name_taken") } }` (FR-004a), `length: { maximum: MAX_NAME_LENGTH }`; `floor` — `presence: true`, `site_floor: true` (FR-011 — reuses `SiteFloorValidator` unchanged, with no `on:` restriction: it already no-ops once `floor` stops changing, and nothing ever reassigns `floor` after creation, so it is naturally inert on every later save);
  - `saved_floor = floor_in_database` (research.md R2 — the floor picker on the standalone "add a zone" form, T020).
  - Document at the top, in the file's own style, why floor has no `on:` restriction (see above).
- [X] T007 Create `app/models/locker_map_entry.rb`. It needs:
  - `belongs_to :zone`;
  - `before_validation { self.floor = zone&.floor }` (research.md R6 — derives `floor` from the parent zone so it can never drift from it);
  - `normalizes :locker_number, with: ->(value) { value.to_s.strip.presence }`;
  - validations: `locker_number` — `presence: true`, `uniqueness: { scope: :floor, message: ->(entry, _data) { the name of the zone currently holding entry.floor + entry.locker_number, via LockerMapEntry.joins(:zone).find_by(floor: entry.floor, locker_number: entry.locker_number)&.zone&.name, interpolated into locker_map_entry.messages.locker_taken } }` (FR-008);
  - `def self.known?(floor, locker_number)`: normalizes both arguments the same way `normalizes` does (`.to_s.strip.presence`) and returns `exists?(floor:, locker_number:)` — `false` if either normalized argument is blank.
- [X] T008 Create `app/controllers/concerns/loads_locker_map.rb` (model it on `app/controllers/concerns/loads_danger_zone.rb`). It defines a private `load_locker_map` that assigns `@floors ||=` the floors to render read-only sections for — `SiteFloorList.current.floors` when configured, otherwise `Zone.distinct.order(:floor).pluck(:floor)` so an already-declared zone is never orphaned off the screen when no floor list is configured (contracts/admin-locker-map.md) — and `@zones_by_floor ||= Zone.includes(:locker_map_entries).order(:name).group_by(&:floor)`. These sections are display-only groupings; they do not gate where a new zone can be created (see T018/T020, finding C1). Document the `||=` the same way `LoadsDangerZone` does: it must not clobber a controller's own invalid, unsaved object on a rejected write's re-render.
- [X] T009 Run T004–T005 until they pass.

**Checkpoint**: Foundation ready — `Zone` and `LockerMapEntry` exist, validate, and cascade correctly. No
screen and no enforcement yet.

---

## Phase 3: User Story 1 — Admin declares the locker map (Priority: P1) 🎯 MVP

**Goal**: A new admin-only screen where an admin creates zones on any floor (even a brand-new one), renames
them, and adds locker numbers to them, with duplicate names and duplicate locker numbers refused.

**Independent Test**: As `grace`, with nothing configured or declared yet, create a zone on a floor typed
freely, with three locker numbers, and see them shown back. As `carol`, `GET /admin/locker_map` is refused.

### Tests for User Story 1 ⚠️ (write first, see them fail)

- [X] T010 [P] [US1] Create `test/controllers/admin/locker_map_controller_test.rb`. It covers:
  - `grace`: `GET /admin/locker_map` is `200`;
  - `carol` and a signed-out request: redirected with `application.administrators_only` (FR-001, mirrors `Admin::UsersController#index`'s existing guard test) / to sign-in;
  - a zone with entries appears grouped under its floor in the response body.
- [X] T011 [P] [US1] Create `test/controllers/admin/zones_controller_test.rb`. It covers:
  - `grace`: `POST /admin/zones` with `zone: { floor: "2", name: "Aile Nord" }` redirects to `admin_locker_map_path` with notice `admin.zones.create.saved` and persists the zone;
  - a blank name, and a name duplicating an existing zone on the same floor, both return `422` and re-render the Locker Map screen with the error inline, no zone persisted (FR-004a);
  - a floor not in the site's configured list (once one is configured) is refused the same way (FR-011);
  - `PATCH /admin/zones/:id` with `zone: { name: "New Name" }` renames it and redirects with `admin.zones.update.saved`; a submitted `zone[floor]` is silently ignored — the zone's floor is unchanged (FR-003/FR-004);
  - `PATCH` to a zone id that no longer exists redirects with `admin.zones.update.zone_gone`;
  - `carol` and signed-out are refused as in T010.
- [X] T012 [P] [US1] Create `test/controllers/admin/locker_map_entries_controller_test.rb`. It covers:
  - `grace`: `POST /admin/zones/:zone_id/locker_map_entries` with `locker_map_entry: { locker_number: "203" }` redirects with `admin.locker_map_entries.create.saved` and persists it under that zone, with `floor` copied from the zone;
  - a blank locker number, and a locker number already claimed by a different zone on the same floor, both return `422` with the error inline, naming the claiming zone in the second case (FR-008);
  - `POST` to a `:zone_id` that does not exist (e.g. a deleted zone's id) redirects with `admin.locker_map_entries.create.zone_gone`, nothing persisted (finding H1);
  - `carol` and signed-out are refused.
- [X] T013 [P] [US1] Create `test/system/admin_locker_map_test.rb`. As `grace`:
  - **with `SiteFloorList` unconfigured and no zone declared at all (the documented baseline)**, the standalone new-zone form's floor field is a plain text box (not a select — nothing is configured yet); typing a brand-new floor and a name creates the zone, which then appears in its own new floor section (finding C1 — the scenario the original, per-floor-form design could never satisfy);
  - creating zone "Aile Nord" on floor "2" with lockers 201, 202, 203 shows all three under that zone (US1 scenario 1);
  - renaming it to "Aile Nord Rénovée" shows the new name with the same three lockers (US1 scenario 2);
  - creating a second zone named "Aile Nord Rénovée" on floor "2" is refused inline (FR-004a); the same name on floor "3" succeeds;
  - declaring locker "203" on floor "2" in a different zone is refused, naming "Aile Nord Rénovée" (US1 scenario 3);
  - as `carol`, visiting `/admin/locker_map` redirects home with the administrators-only alert (US1 scenario 4).
  Accessibility coverage for this screen is added separately, in T023, to `test/system/accessibility_test.rb` — not inline here (finding M2).

### Implementation for User Story 1

- [X] T014 [US1] In `config/routes.rb`, inside `namespace :admin`, add `resource :locker_map, only: :show, controller: "locker_map"` and `resources :zones, only: [:create, :update] do resources :locker_map_entries, only: :create end`, with a `# 031 FR-001/FR-002` comment explaining the singular `resource` and the explicit `controller:` (a bare `resource :locker_map` would pluralize to `LockerMapsController`).
- [X] T015 [US1] Create `app/controllers/admin/locker_map_controller.rb`. `before_action :authenticate_user!`, `before_action :require_admin!` (header comment matching `Admin::UsersController`'s, citing FR-001), `include LoadsLockerMap`. `#show` calls `load_locker_map` and additionally assigns `@new_zone ||= Zone.new` for the one standalone new-zone form (T018, finding C1 — not per-floor).
- [X] T016 [US1] Create `app/controllers/admin/zones_controller.rb`. Same guards, `include LoadsLockerMap`. `#create` builds `Zone.new(zone_params)`, saves it, redirects to `admin_locker_map_path` with `t(".saved")` on success, otherwise calls `load_locker_map`, assigns `@new_zone = @zone` (so the standalone form re-appears with its errors — no "right floor" bookkeeping needed, since there is only one such form, finding C1) and renders `"admin/locker_map/show", status: :unprocessable_entity`. `#update` finds the zone by id (`find_by`, redirecting with `t(".zone_gone")` if `nil`, mirroring `Admin::UsersController#grant_admin`'s vanished-record handling), assigns only `zone_params.except(:floor)` — **never** `:floor` (FR-003/FR-004) — and follows the same success/failure shape. Private `zone_params = params.expect(zone: [:floor, :name])`. Both `#create` and `#update` rescue `ActiveRecord::RecordNotUnique` the same way T017 does below — adds a generic name-already-taken error on `:name` and re-renders `422` instead of raising (`zones(floor, name)`'s unique index, research.md R6, applied symmetrically to zones and entries; found missing by `/speckit-analyze`, finding M1). This race path is acceptable to leave without a dedicated automated test (T011), the same way `LockerProfilesController`'s own race rescue is untested directly — it needs two genuinely concurrent requests to trigger.
- [X] T017 [US1] Create `app/controllers/admin/locker_map_entries_controller.rb`. Same guards, `include LoadsLockerMap`. `#create` finds the zone by `params[:zone_id]` (`find_by`, `t(".zone_gone")` if `nil`), builds `zone.locker_map_entries.new(locker_map_entry_params)`, saves it, redirects with `t(".saved")` on success, otherwise `load_locker_map` + re-render `422` as above. Rescues `ActiveRecord::RecordNotUnique` the same way `LockerProfilesController#save_locker_profile` does — adds a generic "already claimed" error on `:locker_number` and re-renders `422` instead of raising (research.md R6). Private `locker_map_entry_params = params.expect(locker_map_entry: [:locker_number])`.
- [X] T018 [US1] Create `app/views/admin/locker_map/show.html.erb`. First, `render "admin/zones/new_zone_form", zone: @new_zone` — **once, standalone, not inside any floor loop** (research.md R2's correction, finding C1: nesting it per floor section makes the first zone on an unconfigured, zone-less floor uncreatable). Then, for each floor in `@floors`: a heading naming the floor, then each of `@zones_by_floor[floor]`'s zones rendered via `render "admin/zones/zone", zone:`. A floor with no zones yet still gets its heading (an empty-floor statement, `admin.locker_map.show.no_zones`).
- [X] T019 [US1] Create `app/views/admin/zones/_zone.html.erb`. `<%# locals: (zone:) %>`. A `class="card stack-tight"` (default/system hinge — CLAUDE.md, this is neither "you" nor "them"), containing: `render "devise/shared/error_messages", resource: zone` when it is the one that failed; an inline rename `form_with model: zone, url: admin_zone_path(zone), method: :patch, html: { class: "stack-tight", novalidate: true }` with a `text_field :name` (`field-input`) and `f.submit t("admin.zones.form.rename_button"), class: "btn btn-secondary"`; a `.data-table` (or `stack-tight` list, matching an existing small-list component) of `zone.locker_map_entries`, each locker number in `.data-value` (`--font-mono`); an add-locker `form_with model: LockerMapEntry.new, url: admin_zone_locker_map_entries_path(zone), html: { class: "stack-tight", novalidate: true }` with a `text_field :locker_number` (`field-input data-value`) and `f.submit t("admin.locker_map_entries.form.add_button"), class: "btn btn-primary"`. (Remove-locker and delete-zone controls are added in US3 — T040.)
- [X] T020 [US1] Create `app/views/admin/zones/_new_zone_form.html.erb`. `<%# locals: (zone:) %>`. `render "devise/shared/error_messages", resource: zone` when it carries errors; `form_with model: zone, url: admin_zones_path, html: { class: "stack-tight", novalidate: true }` with `render "shared/floor_field", form: f` for the floor — **this is the floor picker research.md R2 built `Zone#saved_floor` for**: a free-text field while `SiteFloorList` is unconfigured, a `<select>` once it is, exactly like every other floor field on the site, and the only thing that lets an admin declare a zone on a floor that has no section yet (finding C1) — a `text_field :name` (`field-input`), and `f.submit t("admin.zones.form.create_button"), class: "btn btn-primary"`.
- [X] T021 [US1] In `app/views/shared/_site_menu_items.html.erb`, add `<%= link_to t(".locker_map"), admin_locker_map_path, class: "site-nav-link", "aria-current": ("page" if current_page?(admin_locker_map_path)) %>` beside the existing `t(".users")` link, inside the `<% if current_user.admin? %>` block (**not** the nested `current_user.super_admin?` block — research.md R7).
- [X] T022 [US1] Add every US1 key to `config/locales/en.yml` and `config/locales/fr.yml`: `admin.locker_map.show.*` (floor heading, empty-floor statement); `admin.zones.form.rename_button|create_button`; `admin.zones.create.saved`; `admin.zones.update.saved|zone_gone`; `admin.locker_map_entries.form.add_button`; `admin.locker_map_entries.create.saved`; **`admin.locker_map_entries.create.zone_gone`** (a *distinct* key from `admin.zones.update.zone_gone` — Rails' lazy `t(".zone_gone")` in T017 resolves relative to `Admin::LockerMapEntriesController#create`, not to `ZonesController#update`, even though the wording matches; found missing by `/speckit-analyze`, finding H1); `zone.messages.name_taken`; `locker_map_entry.messages.locker_taken` (`%{zone}`); `activerecord.attributes.zone.name|floor`; `activerecord.attributes.locker_map_entry.locker_number`; `shared.site_menu_items.locker_map`.
- [X] T023 [US1] Add `test "the locker map is accessible"` and `test "the locker map's new-zone form shows an accessible error"` to `test/system/accessibility_test.rb` (finding M2 — this is the established per-screen-audit home for every feature, e.g. 030's floor-select audits; `assert_axe_clean` comes from `application_system_test_case.rb`, not from a helper local to this file). As `grace`, visit `/admin/locker_map` with a zone already declared and audit the default view; then submit the new-zone form blank and audit the `422` re-render (the `devise/shared/error_messages` state).
- [X] T024 [US1] Run T010–T013 and T023 until they pass, then run `bin/rails test test/i18n_completeness_test.rb`.

**Checkpoint**: an admin can build and view the locker map (create zones on any floor, even a brand-new one,
rename them, add locker numbers, with duplicates refused). Nothing on the existing locker-profile screens
enforces it yet, and nothing can be removed yet.

---

## Phase 4: User Story 2 — Existing screens reject unknown locker numbers (Priority: P2)

**Goal**: `User#save(context: :locker_profile_update)` refuses a floor + locker number pair that is not a
known `LockerMapEntry`, on both the self-service locker profile and the admin locker profile editor. The
locker number field itself stays free text everywhere.

**Independent Test**: With `Zone`/`LockerMapEntry` rows created directly (no UI needed — this story is
independently testable against the Foundational models alone), saving an undeclared pair is refused and a
declared one succeeds, on both save paths.

**Depends on**: Foundational (T007's `LockerMapEntry.known?`). Does not depend on US1's screen or
controllers.

### Tests for User Story 2 ⚠️

- [X] T025 [P] [US2] Create `test/validators/known_locker_validator_test.rb`, using a tiny `ActiveModel` test class (mirrors `test/validators/site_floor_validator_test.rb`'s shape) declaring `validates :locker_number, known_locker: true` and a `floor` attribute. It covers:
  - no-op on a blank `locker_number`;
  - no-op when `floor` is blank;
  - no-op when neither `locker_number` nor `floor` is changing (dirty-tracking case — keep this one for the `User` model tests below, since a plain `ActiveModel` class has no persistence to make "unchanged" meaningful; cover it there instead, as `site_floor_validator_test.rb`'s own comment already does for the equivalent case);
  - an undeclared pair is invalid with `errors.messages.locker_number_unknown`;
  - a declared pair (stub `LockerMapEntry.known?` or create a real row) is valid.
- [X] T026 [P] [US2] Extend `test/models/user_test.rb`. With `Zone.create!(floor: "2", name: "Aile Nord").locker_map_entries.create!(locker_number: "203")`:
  - `valid?(:locker_profile_update)` is false for floor "2" / locker "999" and true for floor "2" / locker "203";
  - a user whose saved floor **and** locker number are both "2"/"203" (set with `update_columns`) stays valid when re-saved unchanged (FR-013), and stays valid when only some *other* attribute changes;
  - the same user becomes invalid if only the floor changes to "3" while the locker-number text stays "203" (US2 acceptance scenario 4 — the pair, not either half alone, is checked; research.md R3's OR-of-two-attributes);
  - the same user becomes invalid if only the locker number changes to "999" while the floor stays "2";
  - with no zones/entries declared anywhere on the site, any floor + locker number pair is valid — the check is a no-op while the map is empty (FR-013a, research.md R8, corrected during implementation);
  - the rule does not fire on non-`:locker_profile_update` saves.
- [X] T027 [P] [US2] Extend `test/controllers/locker_profiles_controller_test.rb`. With the same declared pair as T026: a direct `PATCH` with `locker_number: "999"` returns `422` and nothing is persisted (FR-010); `locker_number: "203"` on floor "2" succeeds.
- [X] T028 [P] [US2] Extend `test/controllers/admin/user_locker_profiles_controller_test.rb`, the same way, as `grace` editing another user's locker (US2 acceptance scenario 3).
- [X] T029 [P] [US2] Extend `test/system/locker_profile_test.rb`. With floor "2" / locker "203" declared (create the `Zone`/`LockerMapEntry` directly in the test, not through the UI): as `carol`, the locker number field is still a plain text box (no dropdown, FR-009); saving "999" on floor "2" shows "not a recognized locker"; saving "203" on floor "2" succeeds; with a saved "2"/"203", changing only the floor to "3" (where "203" is not declared) and re-submitting is refused (scenario 4).

### Implementation for User Story 2

- [X] T030 [US2] Create `app/validators/known_locker_validator.rb` (`class KnownLockerValidator < ActiveModel::EachValidator`). In `validate_each(record, attribute, value)`: return if `value.blank?`; return if `record.floor.blank?`; return unless `LockerMapEntry.exists?` (FR-013a, research.md R8 — corrected during implementation: permissive while the map is empty site-wide, mirroring `SiteFloorList`/`LockerNumberFormat`); return if `record.respond_to?(:will_save_change_to_attribute?)` and **both** `!record.will_save_change_to_attribute?(attribute)` **and** `!record.will_save_change_to_attribute?(:floor)` are true (research.md R3 — the OR, not the single-attribute skip `SiteFloorValidator`/`LockerNumberFormatValidator` use). Otherwise add `attribute, :locker_number_unknown` unless `LockerMapEntry.known?(record.floor, value)`. Header comment cites FR-010/FR-013/FR-013a and research.md R3/R8.
- [X] T031 [US2] In `app/models/user.rb`, add `validates :locker_number, known_locker: true, on: :locker_profile_update` directly beneath the existing `validates :locker_number, locker_number_format: true, on: :locker_profile_update`, extending that block's comment to explain the new check is over the pair, not the number alone.
- [X] T032 [US2] Add `errors.messages.locker_number_unknown` to `config/locales/en.yml` ("is not a recognized locker — ask an administrator to add it to the locker map") and `config/locales/fr.yml` ("n'est pas un casier reconnu — demandez à un administrateur de l'ajouter à la cartographie").
- [X] T033 [US2] Run T025–T029 until they pass, then run `bin/rails test test/i18n_completeness_test.rb`.

**Checkpoint**: enforcement is live on both existing screens. Combined with US1, the feature's core value
(spec Success Criteria SC-002, SC-003) is complete.

---

## Phase 5: User Story 3 — Admin keeps the map current (Priority: P3)

**Goal**: An admin can remove a single locker number from a zone, and delete a zone entirely — deleting a
non-empty zone removes it and every locker number in it in one action.

**Independent Test**: Remove a locker number from a zone (or delete a non-empty zone outright) and confirm
it no longer appears in the map.

**Depends on**: US1 (the screen and its controllers, T014–T020).

### Tests for User Story 3 ⚠️

- [X] T034 [P] [US3] Extend `test/controllers/admin/zones_controller_test.rb`. As `grace`: `DELETE /admin/zones/:id` on a zone with two locker map entries redirects with `admin.zones.destroy.deleted`, and both the zone and its two entries are gone (FR-006, research.md R4, no separate emptying step); deleting an already-deleted zone id redirects with the same notice rather than erroring (idempotent, mirrors `Admin::UsersController#grant_admin`'s "arriving second" posture); `carol` and signed-out are refused.
- [X] T035 [P] [US3] Extend `test/controllers/admin/locker_map_entries_controller_test.rb`. `DELETE /admin/zones/:zone_id/locker_map_entries/:id` redirects with `admin.locker_map_entries.destroy.deleted` and removes only that entry, leaving the zone and its other entries intact; deleting an already-gone entry redirects with the same notice.
- [X] T036 [P] [US3] Extend `test/system/admin_locker_map_test.rb`. As `grace`, with zone "Aile Nord" on floor "2" holding lockers 201–203: removing 203 leaves 201/202 and the zone in place (US3 scenario 1); deleting the zone (non-empty) removes it and 201/202 in one action, with no confirmation-blocking "empty it first" step (US3 scenario 2, FR-006). Then, as `carol` with floor "2" / locker "201" already saved on her profile (set directly, not through the deleted zone), confirm her profile still displays "2"/"201" after the zone's deletion (FR-013), but re-saving that same pair unchanged-in-value-but-resubmitted is now refused until a zone declares it again (cross-check with US2's enforcement, spec Edge Cases). Accessibility coverage for the destroy controls is added separately, in T042, to `test/system/accessibility_test.rb` — not inline here (finding M2).

### Implementation for User Story 3

- [X] T037 [US3] In `config/routes.rb`, change `resources :zones, only: [:create, :update]` to `resources :zones, only: [:create, :update, :destroy]`, and the nested `resources :locker_map_entries, only: :create` to `only: [:create, :destroy]`.
- [X] T038 [US3] Add `#destroy` to `app/controllers/admin/zones_controller.rb`: `find_by(id: params[:id])`; if found, `zone.destroy` (cascades per `dependent: :destroy`); redirect to `admin_locker_map_path` with `t(".deleted")` whether or not it was found (idempotent, same "already the desired end state" posture as `Admin::UsersController#grant_admin`'s vanished-record handling, applied here to a *destroy* instead of a *not-found update*).
- [X] T039 [US3] Add `#destroy` to `app/controllers/admin/locker_map_entries_controller.rb`, the same shape, scoped by `params[:zone_id]`/`params[:id]`, notice `t(".deleted")`.
- [X] T040 [US3] In `app/views/admin/zones/_zone.html.erb`, add: a `button_to t("admin.locker_map_entries.form.remove_button"), admin_zone_locker_map_entry_path(zone, entry), method: :delete, class: "btn btn-sm btn-secondary"` beside each listed locker number; a `button_to t("admin.zones.form.delete_button"), admin_zone_path(zone), method: :delete, class: "btn btn-sm btn-alert", data: { turbo_confirm: t("admin.zones.form.delete_confirm") }` for the zone itself — the confirmation text names the zone and, when it has entries, states how many locker numbers will go with it (FR-006, "confirmation lives in the view" — the same posture `revoke_admin`'s control already takes).
- [X] T041 [US3] Add `admin.zones.destroy.deleted`, `admin.zones.form.delete_button|delete_confirm`, `admin.locker_map_entries.destroy.deleted`, `admin.locker_map_entries.form.remove_button` to both locale files.
- [X] T042 [US3] Add `test "the locker map's destroy controls are accessible"` to `test/system/accessibility_test.rb` (finding M2). As `grace`, with a zone holding at least one locker number, audit the default view (remove/delete buttons present) and confirm the delete-zone confirmation dialog is reachable and operable by keyboard alone.
- [X] T043 [US3] Run T034–T036 and T042 until they pass, then run `bin/rails test test/i18n_completeness_test.rb`.

**Checkpoint**: all three stories are functional and independently verified — the full feature, matching
spec.md, is complete.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T044 [P] Run `bin/rails test test/i18n_completeness_test.rb` and fix any key missing in either
  language. Switch the site to French and walk quickstart.md's manual scenarios 1–3 and 9 again, reading
  every new label, hint, and error message.
- [X] T045 [P] Check the design visually, following CLAUDE.md "How to check the work". Write a throwaway
  system test under `test/system/` that signs in as `grace`, populates a zone with a couple of locker
  numbers, and visits the Locker Map. It calls `wait_for_entrance` and `page.save_screenshot` into
  `tmp/design/`, at desktop and `with_viewport(:phone)`. Read the images and confirm: zone cards hang on
  the default (system, navy) hinge, never `--you`/`--them`; floor and locker numbers render in
  `--font-mono` `.data-value`; the page stays single-column with no side-by-side controls at any width
  (CLAUDE.md's "no content side by side if both columns contain controls" rule); the destroy buttons are
  visually distinct (`.btn-alert`) from the add/rename ones. Then delete the test.
- [X] T046 [P] Run `bin/rubocop` and `bin/brakeman --no-pager`. Both must be clean.
- [X] T047 Run the full suite: `bin/rails test && bin/rails test:system`. It must be green, with no new
  skips and no coverage regression on the models.
- [X] T048 Walk quickstart.md scenarios 1–10 by hand in development.
- [X] T049 Draft the PR description. It covers:
  - the relevant principles (I–IV);
  - **no breaking change to existing UX**: the locker number field stays free text everywhere (FR-009) —
    only its acceptance rule changes, and only once an admin has populated at least one zone on that floor;
    call this out explicitly since a fresh deployment's empty map means every locker-profile save is
    refused until the map is populated (FR-013's premise) — note this as a rollout step in the PR;
  - the corrected assumption from planning: `LockerWish` has no locker number and is untouched by this
    feature (research.md R1);
  - the reused patterns (`shared/_floor_field`, `.card`, `.data-table`, `field-input`, the error-messages
    partial, the "confirmation lives in the view" destructive-action pattern);
  - accessibility checks (T023's and T042's additions to `test/system/accessibility_test.rb`, keyboard
    operability of the destroy confirmations);
  - a performance note (one new indexed existence check per locker-profile save, `includes` on the map
    screen, no swap/lock path touched).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (T001–T003)**: none.
- **Foundational (T004–T009)**: after Setup. Blocks all three user stories.
- **US1 (T010–T024)**: after Foundational.
- **US2 (T025–T033)**: after Foundational (T007). Independent of US1 — does not need the screen.
- **US3 (T034–T043)**: after US1 (T014–T020, the screen and its controllers).
- **Polish (T044–T049)**: after every story it covers.

### User Story Dependencies

```text
Setup ─► Foundational ─┬─► US1 ─► US3
                       └─► US2
```

### Within Each User Story

- Tests first, and they must fail.
- Models/concern already exist (Foundational); routes, then controllers, then views, then locales.
- Story checkpoint, then the next story.

### Shared-file hotspots (serialise edits)

- `config/locales/en.yml` / `fr.yml`: T022, T032, T041.
- `config/routes.rb`: T014, T037.
- `app/controllers/admin/zones_controller.rb`: T016, T038.
- `app/controllers/admin/locker_map_entries_controller.rb`: T017, T039.
- `app/views/admin/zones/_zone.html.erb`: T019, T040.
- `test/controllers/admin/zones_controller_test.rb`: T011, T034.
- `test/controllers/admin/locker_map_entries_controller_test.rb`: T012, T035.
- `test/system/admin_locker_map_test.rb`: T013, T036.
- `test/system/accessibility_test.rb`: T023, T042 (finding M2).
- `app/models/user.rb`: T031 (only this feature touches it).

## Parallel Examples

```text
# Setup
T001 migration zones  ∥  T002 migration locker_map_entries

# Foundational tests
T004 zone_test.rb  ∥  T005 locker_map_entry_test.rb

# US1 tests (all different files)
T010 ∥ T011 ∥ T012 ∥ T013

# US2 tests (all different files, and independent of US1 entirely)
T025 ∥ T026 ∥ T027 ∥ T028 ∥ T029

# After Foundational, two tracks:
Track A: US1 → US3        Track B: US2 (parallel to both)
```

## Implementation Strategy

### MVP (US1 + US2)

1. Setup, then Foundational.
2. US1: an admin can build the locker map, including on a floor nothing knows about yet. Validate with its
   independent test.
3. US2: existing screens enforce it. **Stop, validate, and ship if wanted.** This alone delivers the
   feature's core value (SC-002, SC-003) — only removal (US3) is still missing.

### Incremental Delivery

4. US3: removal and cascading deletion, completing the feature.
5. Polish.

### Notes

- [P] means different files and no unfinished dependency.
- Commit after each checkpoint.
- Never pre-seed `zones`/`locker_map_entries` fixtures: the map starts empty on every fresh test database,
  matching FR-013's premise for a real deployment.
