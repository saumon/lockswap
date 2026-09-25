---

description: "Task list for 030 — configurable floors and locker number format"
---

# Tasks: Configurable Floors and Locker Number Format

**Input**: Design documents from `/specs/030-configurable-floors-locker-format/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/danger-zone-locker-settings.md, quickstart.md

**Tests**: Included. The constitution's Principle II is non-negotiable: every change ships with tests
that fail without it. In each story, the test tasks come first and must be seen failing before the
implementation tasks begin.

**Organization**: Grouped by user story (spec.md US1–US4). US2 depends on US1's model, and US4 depends
on US3's model. Otherwise the two pairs are independent of each other.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1–US4 from spec.md

## Conventions for every task

- Every user-facing string is an I18n lookup with a matching entry in **both** `config/locales/en.yml`
  and `config/locales/fr.yml` (Constitution III). Key names are in contracts/danger-zone-locker-settings.md.
- Fixtures: `users(:frank)` is the super admin, `users(:grace)` is a granted admin, and `users(:carol)`
  (or `alice`/`bob`) are standard users. **No fixture rows are added** for `site_floor_lists` or
  `locker_number_formats`: "not configured" stays the baseline for every existing test (research.md R10).
  Tests that need a setting create it with `SiteFloorList.current.update!(floors_text: "…")` or
  `LockerNumberFormat.current.update!(pattern: "…")`.
- Follow CLAUDE.md: no raw hex in ERB, one breakpoint (48rem), one definition per component, no
  uppercase, and `.btn-primary` stays on `<input type="submit">`. Run `bin/rails tailwindcss:build`
  after any stylesheet edit.
- Comment style: match the surrounding code. Each new rule carries a short `# 030 FR-xxx:` note saying
  why, as existing files do.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: The two tables every later phase reads.

- [X] T001 [P] Create migration `db/migrate/<timestamp>_create_site_floor_lists.rb`: `create_table :site_floor_lists` with `t.json :floors, null: true` ("`NULL` means never configured (FR-006)") and `t.timestamps`.
- [X] T002 [P] Create migration `db/migrate/<timestamp>_create_locker_number_formats.rb`: `create_table :locker_number_formats` with `t.string :pattern, null: true`, `t.string :description, null: true` and `t.timestamps`.
- [X] T003 Run `bin/rails db:migrate` (and `bin/rails db:test:prepare`) and confirm both tables appear in `db/schema.rb`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: One loader for the danger zone re-render. Every later controller that re-renders
`admin/danger_zone/show` needs it (research.md R7).

- [X] T004 Create `app/controllers/concerns/loads_danger_zone.rb` (model it on `app/controllers/concerns/loads_homepage_proposals.rb`). It defines a private `load_danger_zone` that assigns `@allowed_email_domains ||= AllowedEmailDomain.order(:domain)`, `@allowed_email_domain ||= AllowedEmailDomain.new` and `@site_language_setting ||= SiteLanguageSetting.current`. The `||=` is load-bearing: the controller whose write was refused keeps its own invalid object for the re-render. Document this in the concern's header comment.
- [X] T005 Refactor `app/controllers/admin/danger_zone_controller.rb` (`#show`, and the failure branch of `#update`) and `app/controllers/admin/allowed_email_domains_controller.rb` (every re-render branch) to `include LoadsDangerZone` and call `load_danger_zone` instead of assigning the three instance variables inline. Behaviour must not change.
- [X] T006 Run `bin/rails test test/controllers/admin/danger_zone_controller_test.rb test/controllers/admin/allowed_email_domains_controller_test.rb` and `bin/rails test:system TEST=test/system/admin_danger_zone_test.rb`. They must pass unchanged, which proves T005 is a pure refactor.

**Checkpoint**: the danger zone renders exactly as before, from one loader.

---

## Phase 3: User Story 1 — The super admin defines the site's floors (Priority: P1) 🎯 MVP

**Goal**: A super-admin-only "Floors" card on the danger zone saves an ordered, cleaned list.

**Independent Test**: As `frank`, save "0, 1, 2, 3", reload, and see exactly "0, 1, 2, 3". As `grace`,
`PATCH /admin/floor_list` is refused.

### Tests for User Story 1 ⚠️ (write first, see them fail)

- [X] T007 [P] [US1] Create `test/models/site_floor_list_test.rb`. It covers:
  - `.current` creates one row with `floors: nil`, and `configured?` is false;
  - a second `create` is refused (`only_one_row_may_exist`);
  - `floors_text = " 1, ,2, 2 , RDC"` gives `floors == ["1", "2", "RDC"]` (order kept, spaces trimmed, blanks dropped, first duplicate kept, FR-002), and `floors_text` reads back `"1, 2, RDC"`;
  - `floors_text = " , "` is invalid with `floor_list.messages.required` (FR-003);
  - 51 floors are invalid (`too_many`: "at most 50 entries");
  - a 21-character floor is invalid (`floor_too_long`: "each entry at most 20 characters");
  - `offers?("2")` is true and `offers?("7")` is false.
- [X] T008 [P] [US1] Create `test/controllers/admin/floor_list_controller_test.rb`. It covers:
  - `frank`: a valid PATCH redirects to `admin_danger_zone_path` with the notice `admin.floor_list.update.saved` and persists the list;
  - `frank`: a blank list returns 422 and the saved list is unchanged;
  - `grace` and `carol` are redirected to `root_path` with `application.administrators_only`, and the list is unchanged;
  - signed out, the request redirects to sign-in;
  - an unpermitted param (e.g. `site_floor_list[floors]`) is ignored.
- [X] T009 [P] [US1] Extend `test/system/admin_danger_zone_test.rb`. As `frank`:
  - `#danger-zone-floors` states that no list is configured and floors are free text;
  - filling `site_floor_list_floors_text` with "RDC, 1, 2, 2, , 3" and saving shows the notice, and the field then reads "RDC, 1, 2, 3";
  - submitting blank shows the error inside `#danger-zone-floors` (not in the other cards), and the old list is kept;
  - the card order is language, floors, locker format (added in US3), domains. Assert language before floors before domains here.

### Implementation for User Story 1

- [X] T010 [US1] Create `app/models/site_floor_list.rb`, following `app/models/site_language_setting.rb`'s structure and comments. It needs:
  - `.current` → `first_or_create!(floors: nil)`;
  - the virtual `floors_text` reader and writer from data-model.md;
  - `configured?` → `floors.present?` and `offers?(floor)` → `Array(floors).include?(floor)`, each documented;
  - validations: `floors` present whenever it is being saved (`floor_list.messages.required`), "at most 50 entries" (`floor_list.messages.too_many`), "each entry at most 20 characters" (`floor_list.messages.floor_too_long`, interpolating `%{floor}`), all on `:base` or `:floors_text` so `full_messages` reads cleanly;
  - `only_one_row_may_exist` on `:create`;
  - the constants `MAX_FLOORS = 50` and `MAX_FLOOR_LENGTH = 20`.
- [X] T011 [US1] Add `resource :floor_list, only: :update, controller: "floor_list"` inside `namespace :admin` in `config/routes.rb`, next to `resource :danger_zone`, with a `# 030` comment.
- [X] T012 [US1] Create `app/controllers/admin/floor_list_controller.rb`. It has `before_action :authenticate_user!` and `before_action :require_super_admin!` (header comment as in `danger_zone_controller.rb`) and `include LoadsDangerZone`. `#update` sets `@site_floor_list = SiteFloorList.current`, calls `update(params.expect(site_floor_list: [:floors_text]))`, redirects to `admin_danger_zone_path` with the notice `t(".saved")` on success (no conformance count, clarification Q4), and otherwise calls `load_danger_zone` and renders `"admin/danger_zone/show", status: :unprocessable_entity`.
- [X] T013 [US1] Add `@site_floor_list ||= SiteFloorList.current` to `load_danger_zone` in `app/controllers/concerns/loads_danger_zone.rb`.
- [X] T014 [US1] Add the `#danger-zone-floors` card to `app/views/admin/danger_zone/show.html.erb`, between the language card and the domains card. It is `class="card card--alert stack-tight"` and contains:
  - a `.meta` explanation;
  - when not configured, a `.detail-value-empty` statement that floors are free text today;
  - `render "devise/shared/error_messages", resource: @site_floor_list`;
  - `form_with model: @site_floor_list, url: admin_floor_list_path, method: :patch, html: { class: "stack-tight", novalidate: true }`;
  - a labelled `text_field :floors_text` (`field-input`, `autocomplete: "off"`) with an `aria-describedby` hint: comma-separated, no comma inside a floor, offered in the order typed;
  - `f.submit t(".save_floors_button"), class: "btn btn-primary"`.
- [X] T015 [US1] Add every US1 key to `config/locales/en.yml` and `config/locales/fr.yml`:
  - `admin.danger_zone.show.*`: the floors explanation, not-configured statement, label, hint and save button;
  - `admin.floor_list.update.saved`;
  - `floor_list.messages.required|too_many|floor_too_long`;
  - `activerecord.attributes.site_floor_list.floors_text` ("Floors" / "Étages").
- [X] T016 [US1] Run T007–T009 until they pass, then run `bin/rails test test/i18n_completeness_test.rb`.

**Checkpoint**: the super admin can save and edit the floor list. The rest of the site is unchanged, since
nothing reads the list yet.

---

## Phase 4: User Story 2 — Every floor field becomes a choice from that list (Priority: P1)

**Goal**: The three floor entry forms offer a select in typed order once a list exists, and every save path
refuses unlisted floors. A floor that is still on file but has been removed stays re-savable.

**Independent Test**: With "0, 1, 2, 3" saved, each floor field offers exactly those. A crafted request
with floor "7" is refused on every save path. With no list saved, every field is still a text box.

**Depends on**: US1 (T010).

### Tests for User Story 2 ⚠️

- [X] T017 [P] [US2] Create `test/validators/site_floor_validator_test.rb`, using a tiny `ActiveModel` test class that declares `validates :floor, site_floor: true`. It covers:
  - no-op when the list is not configured (any value is valid, FR-006);
  - no-op on a blank value;
  - an unlisted, changed value is invalid with `errors.messages.floor_not_offered`;
  - a listed value is valid.
  Keep the "unchanged value" case for the model tests (T018/T019), since it needs dirty tracking.
- [X] T018 [P] [US2] Extend `test/models/user_test.rb`. With the list "0, 1, 2, 3":
  - `valid?(:locker_profile_update)` is false for floor "7" and true for "2";
  - a user whose saved floor is "5" (set with `update_columns`) stays valid when re-saved with floor "5" unchanged (FR-007/FR-011), but is invalid when changed to "6";
  - with no list configured, floor "anything" is valid;
  - the floor rule does not fire on non-`:locker_profile_update` saves.
- [X] T019 [P] [US2] Extend `test/models/locker_wish_test.rb` with the same cases for `LockerWish#floor`: unlisted and changed is refused, listed is accepted, unchanged removed floor is accepted, not configured is anything accepted.
- [X] T020 [P] [US2] Extend `test/controllers/locker_profiles_controller_test.rb`, `test/controllers/locker_wishes_controller_test.rb` and `test/controllers/admin/user_locker_profiles_controller_test.rb` (create any that are missing, following the existing controller test style). With the list configured, a direct PATCH/POST with `floor: "7"` returns 422 and nothing is persisted (FR-005, "including values submitted directly").
- [X] T021 [P] [US2] Extend `test/system/locker_profile_test.rb`. With the list "RDC, 1, 2, 3", as `carol`:
  - the first-entry form's `Floor` is a `<select>` whose options are exactly the blank prompt, RDC, 1, 2, 3, in that order;
  - `select "2", from: "Floor"` saves;
  - the pencil editor offers the same;
  - leaving the prompt selected reports the existing "floor is required" error;
  - with a saved floor "5" not in the list, the editor shows "5 (no longer offered)" selected, and saving unchanged succeeds.
  Also assert that with **no** list, `fill_in "Floor"` still works (FR-006). Finally, save the list as `frank` through the danger zone and then, in the same test, sign in as `carol` and assert the select (FR-020, analysis G2).
- [X] T022 [P] [US2] Extend `test/system/locker_wish_test.rb` (the declare form) and `test/system/homepage_locker_wish_test.rb` (the "Change floor" disclosure, where autofocus must still land on the select). With the list configured, the floor field is a select with the configured options in order, and choosing one declares or changes the wish.
- [X] T023 [P] [US2] Extend `test/system/admin_user_detail_test.rb`. As `frank`, with the list configured, the `#admin-user-locker-editor` floor field is a select with the configured floors, and saving a listed floor succeeds.
- [X] T024 [P] [US2] Extend `test/system/accessibility_test.rb`: run the axe audit on the homepage locker profile form and on the locker wish form **with a floor list configured**, so the new select is audited, and check that the select can be reached and changed with the keyboard alone (SC-007).

### Implementation for User Story 2

- [X] T025 [US2] Create `app/validators/site_floor_validator.rb` (`class SiteFloorValidator < ActiveModel::EachValidator`). In `validate_each(record, attribute, value)`, return early if `value.blank?`, if `!SiteFloorList.current.configured?`, or if the record responds to `will_save_change_to_attribute?` and it is false for `attribute`. Otherwise add `:floor_not_offered` unless `SiteFloorList.current.offers?(value)`. Its header comment cites FR-005/FR-006/FR-007/FR-011 and research.md R3.
- [X] T026 [US2] In `app/models/user.rb`, add `validates :floor, site_floor: true, on: :locker_profile_update` directly beneath the existing `validates :floor, presence: true, on: :locker_profile_update`, extending that block's comment.
- [X] T027 [US2] In `app/models/locker_wish.rb`, add `validates :floor, site_floor: true` beneath the existing presence validation, with a `# 030` comment.
- [X] T028 [US2] Add `errors.messages.floor_not_offered` to `config/locales/en.yml` ("is not one of the site's floors") and `config/locales/fr.yml` ("ne fait pas partie des étages du site").
- [X] T029 [US2] Create `app/views/shared/_floor_field.html.erb`. It declares strict locals: `<%# locals: (form:, hint_id: nil, autofocus: false) %>`.
  - When `SiteFloorList.current.configured?` is false, it renders exactly today's `form.text_field :floor, autofocus:, autocomplete: "off", aria: { describedby: hint_id }.compact, class: "field-input"`.
  - Otherwise it renders `form.select :floor`. The options are the configured floors in typed order. If `form.object.saved_floor` is present and not offered, that option is prepended, labelled `t("shared.floor_field.no_longer_offered", floor:)`. It uses `include_blank: t("shared.floor_field.prompt")`, the same `autofocus`, `aria` and `class: "field-input"`, and the saved or submitted value is selected.
  - Read `SiteFloorList.current` once into a local variable at the top of the partial (analysis U1).
  - The header comment explains why this is a `<select>` here although 017 rejected one for filters: it sits inside a form with an explicit submit, so arrowing through it commits nothing (research.md R6).
- [X] T030 [US2] Replace the floor `text_field` in `app/views/home/_locker_profile_form.html.erb` with `render "shared/floor_field", form: f`. Keep the label and the `locker-entry-choice` markup untouched.
- [X] T031 [US2] Replace the floor `text_field` in `app/views/locker_wishes/_locker_wish_form.html.erb` with `render "shared/floor_field", form: f, hint_id: "locker_wish_floor_hint", autofocus: autofocus`. Keep the hint paragraph and the 026 autofocus comment, which now applies to the partial's control.
- [X] T032 [US2] Replace the floor `text_field` in `app/views/admin/users/_locker_profile_editor.html.erb` with `render "shared/floor_field", form: f`.
- [X] T033 [US2] Add `shared.floor_field.prompt` ("Choose a floor" / "Choisissez un étage") and `shared.floor_field.no_longer_offered` ("%{floor} (no longer offered)" / "%{floor} (n'est plus proposé)") to both locale files.
- [X] T034 [US2] Check the select's appearance: confirm `select.field-input` already renders like the danger zone's language select in `app/assets/tailwind/application.css` (research.md R6). Edit the existing `.field-input` rule only if the chevron or height visibly differs; do not add a second definition.
- [X] T035 [US2] Run T017–T024 until they pass. Then run the untouched floor-related system tests (`locker_swap_proposal_test.rb`, `locker_wish_entry_test.rb`, `homepage_locker_wish_test.rb`) to confirm the free-text baseline is intact.

**Checkpoint**: MVP complete. Floors are a closed list everywhere once configured.

---

## Phase 5: User Story 3 — The super admin sets the locker number format, guided by examples (Priority: P2)

**Goal**: A super-admin-only "Locker number format" card saves a pattern and an optional description,
refuses invalid patterns, and shows an examples table whose results are computed.

**Independent Test**: As `frank`, save `\d{3}` with the description "3 chiffres, ex. 042", reload and
see both. The examples table shows `\d{3}`: 042 Accepted, 42 Refused, 1234 Refused. `[0-9` is refused
and the previous format is kept.

**Independent of**: US1 and US2 (it needs only T002 and T004).

### Tests for User Story 3 ⚠️

- [X] T036 [P] [US3] Create `test/models/locker_number_format_test.rb`. It covers:
  - `.current` gives `pattern: nil`, `in_force?` false, and a singleton guard;
  - `[0-9`, `(\d`, `*`, `\d{3}(?#` and **`(?x)\d{3} #`** (compiles on its own, fails once anchored) are invalid with `locker_number_format.messages.invalid_pattern`;
  - a row written with `update_columns(pattern: "(?x)\\d{3} #")` does not raise: `matches?("042")` returns false;
  - `\d{3` is **valid** (Ruby reads it as a literal, research.md R4);
  - a 201-character pattern is invalid ("at most 200 characters");
  - a 101-character description is invalid ("at most 100 characters");
  - a blank pattern normalises to `nil` and also clears the description;
  - `matches?`: for `\d{3}`, "042" and " 042 " are true, "42", "0421", "A42" and "12345" are false; `^\d{3}$` behaves identically; for `\d{3}|A\d{2}`, "A12" is true and "A123" is false (whole-value grouping); "042\n999" is false;
  - a timeout: stub `MATCH_TIMEOUT` very small, or use a back-reference pattern where `Regexp.linear_time?` is false, and assert `matches?` returns false rather than raising;
  - `display` is the description when present, otherwise the pattern;
  - **every entry of `EXAMPLES`** has the expected outcome: `\d{3}` accepts 042 and refuses 42 and 1234; `\d{1,3}` accepts 7 and 042 and refuses 1234; and so on for all five (SC-004).
- [X] T037 [P] [US3] Create `test/controllers/admin/locker_number_format_controller_test.rb`. It covers:
  - `frank`: a valid PATCH redirects with the notice `…update.saved`, and a blank pattern redirects with `…update.cleared` and clears both columns;
  - an invalid pattern returns 422 and the old pattern is kept;
  - `grace` and `carol` are refused with `application.administrators_only`;
  - signed out, the request redirects to sign-in.
- [X] T038 [P] [US3] Extend `test/system/admin_danger_zone_test.rb`. As `frank`:
  - `#danger-zone-locker-format` sits between `#danger-zone-floors` and `#danger-zone-allowed-domains`;
  - `#locker-format-examples` lists five patterns, each sample with an "Accepted" or "Refused" badge carrying the text;
  - saving `\d{3}` and "3 chiffres, ex. 042" shows the notice, and both fields keep their values;
  - saving `[0-9` shows the error inside `#danger-zone-locker-format` only;
  - clearing the pattern shows the "no format" statement.

### Implementation for User Story 3

- [X] T039 [US3] Create `app/models/locker_number_format.rb`, with a structure and comments like `site_language_setting.rb`. It needs:
  - `.current` → `first_or_create!`;
  - `normalizes :pattern, :description` (strip, blank becomes `nil`), plus a `before_validation` that clears `description` when `pattern` is `nil`;
  - validations: `length: { maximum: 200 }` on the pattern, `length: { maximum: 100 }` on the description, and `pattern_compiles`, which calls the private `anchored_regexp` and turns a `RegexpError` into `:invalid_pattern`. It must compile the anchored form, **not** the raw source (research.md R4, analysis C1);
  - `only_one_row_may_exist` on `:create`;
  - `MATCH_TIMEOUT = 0.1`;
  - `in_force?`;
  - a private `anchored_regexp` → `Regexp.new("\\A(?:#{pattern})\\z", timeout: MATCH_TIMEOUT)`;
  - `matches?(value)` goes through the same `anchored_regexp`. It strips the value and returns false on `Regexp::TimeoutError` **or** `RegexpError`, and is documented as the **only** matcher on the site;
  - `display`;
  - `EXAMPLES`, a frozen array of `{ pattern:, key:, samples: [...] }` for `\d{3}` (042, 42, 1234), `\d{1,3}` (7, 042, 1234), `[A-Z]\d{2}` (B12, b12, B123), `\d{2}-\d{2}` (01-15, 0115) and `(A|B)\d{3}` (A042, C042).
- [X] T040 [US3] Add `resource :locker_number_format, only: :update, controller: "locker_number_format"` inside `namespace :admin` in `config/routes.rb`, beside T011's route.
- [X] T041 [US3] Create `app/controllers/admin/locker_number_format_controller.rb`. It mirrors T012: the same guards and `include LoadsDangerZone`. `#update` uses `params.expect(locker_number_format: [:pattern, :description])`. On success it redirects with `t(".cleared")` when `!in_force?`, otherwise `t(".saved")`. On failure it calls `load_danger_zone` and renders `"admin/danger_zone/show", status: :unprocessable_entity`.
- [X] T042 [US3] Add `@locker_number_format ||= LockerNumberFormat.current` to `load_danger_zone` in `app/controllers/concerns/loads_danger_zone.rb`.
- [X] T043 [US3] Add the `#danger-zone-locker-format` card to `app/views/admin/danger_zone/show.html.erb`, after `#danger-zone-floors`. It is `class="card card--alert stack-tight"` and contains:
  - a `.meta` explanation;
  - the current state (a `.detail-value-empty` "no format — any locker number is accepted" when not in force);
  - the error-messages partial for `@locker_number_format`;
  - `form_with … url: admin_locker_number_format_path, method: :patch, html: { class: "stack-tight", novalidate: true }` with a labelled `text_field :pattern` (`field-input data-value`, `autocomplete: "off"`, `spellcheck: false`, a hint explaining it must match the whole value) and a labelled `text_field :description` (hint: shown to users in place of the pattern);
  - `f.submit t(".save_format_button"), class: "btn btn-primary"`;
  - the examples: a `.table-scroll` > `table.data-table#locker-format-examples` with `role` attributes and `data-label` exactly as the domains table does. The columns are Pattern (`.data-value`), Meaning (`t(".format_examples.#{key}")`) and Samples, where each sample is `.data-value` plus a `span.badge.badge-success` / `.badge-error` with `t(".format_examples.accepted")` / `.refused`, computed with `LockerNumberFormat.new(pattern: example[:pattern]).matches?(sample)`. Nothing is hard-coded.
- [X] T044 [US3] Add every US3 key to both locale files:
  - `admin.danger_zone.show.*`: the format explanation, no-format statement, pattern and description labels and hints, save button, example column headers, the five meanings, and accepted/refused;
  - `admin.locker_number_format.update.saved|cleared`;
  - `locker_number_format.messages.invalid_pattern`;
  - `activerecord.attributes.locker_number_format.pattern|description`.
- [X] T045 [US3] If the samples cell needs the value and its badge laid out as pairs (and it does not fall out of the existing `.data-table` / `.badge` rules), extend the existing component rule in `app/assets/tailwind/application.css` with a comment, then run `bin/rails tailwindcss:build`. Use no new media query other than 48rem / 47.999rem.
- [X] T046 [US3] Run T036–T038 until they pass, plus `test/i18n_completeness_test.rb` and `test/stylesheet_breakpoint_test.rb`.

**Checkpoint**: the format can be configured and is explained, but nothing enforces it yet.

---

## Phase 6: User Story 4 — Every locker number entry respects the format (Priority: P2)

**Goal**: Once a format is in force, the user's own locker profile and the admin editor refuse
non-conforming numbers, naming the description (or the raw pattern). Hints state the format. Empty
numbers and unchanged legacy numbers stay accepted.

**Independent Test**: With `\d{3}` and "3 chiffres, ex. 042" saved, "42" is refused with a message naming
"3 chiffres, ex. 042", "042" saves, " 042 " saves as "042", and clearing the number is accepted. The same
holds in the admin editor.

**Depends on**: US3 (T039).

### Tests for User Story 4 ⚠️

- [X] T047 [P] [US4] Create `test/validators/locker_number_format_validator_test.rb`, using a tiny ActiveModel class. It covers:
  - no-op when no format is in force;
  - no-op on `nil`;
  - a mismatch adds `errors.messages.locker_number_format_mismatch` interpolating `display`, as the description when present and as the pattern when the description is blank;
  - a match is valid.
- [X] T048 [P] [US4] Extend `test/models/user_test.rb`. With `\d{3}`:
  - "42" is invalid on `:locker_profile_update`, and "042" is valid;
  - " 042 " is saved as "042" (the normalizes strip) and collides with another user's "042" on the same floor under uniqueness (006);
  - a blank value becomes `nil` and is valid (FR-015);
  - a legacy "42" set with `update_columns` stays valid when the floor alone changes (FR-017), and is invalid when the number is changed to "43";
  - after the floor list and the format change, a resolved proposal's `*_floor_at_resolution` / `*_locker_number_at_resolution` values are unchanged (FR-021, analysis G1).
- [X] T049 [P] [US4] Extend `test/controllers/locker_profiles_controller_test.rb` and `test/controllers/admin/user_locker_profiles_controller_test.rb`. With a format in force, a direct PATCH with `locker_number: "42"` returns 422 and nothing is persisted (FR-013).
- [X] T050 [P] [US4] Extend `test/system/locker_profile_test.rb`. With `\d{3}` and "3 chiffres, ex. 042", as `carol`:
  - the locker number hint contains "3 chiffres, ex. 042";
  - saving "42" shows an error containing "3 chiffres, ex. 042";
  - saving "042" succeeds;
  - "I don't have a locker" still saves.
  Then clear the description and assert the hint and error show `\d{3}`. Also assert that with no format the hint is unchanged.
- [X] T051 [P] [US4] Extend `test/system/admin_user_detail_test.rb`. As `frank`, with `\d{3}`, saving "42" in `#admin-user-locker-editor` shows the format error, and "042" saves.

### Implementation for User Story 4

- [X] T052 [US4] Create `app/validators/locker_number_format_validator.rb` (`class LockerNumberFormatValidator < ActiveModel::EachValidator`). It returns early on `value.nil?`, on `!LockerNumberFormat.current.in_force?`, or when `will_save_change_to_attribute?(attribute)` is false. Otherwise it adds `:locker_number_format_mismatch, format: format.display` unless `format.matches?(value)`. The header comment cites FR-013/FR-015/FR-017 and research.md R5.
- [X] T053 [US4] In `app/models/user.rb`, change `normalizes :locker_number, with: ->(value) { value.blank? ? nil : value }` to strip first (`value.to_s.strip.presence`), extending its comment with FR-014/research.md R5. The comment also notes that stripping applies to `where(locker_number:)` lookups, so the admin locker search matches " 042 " to "042"; add one assertion for that in `test/system/admin_users_filter_test.rb` (analysis U2). Add `validates :locker_number, locker_number_format: true, on: :locker_profile_update` beside the existing uniqueness validation.
- [X] T054 [US4] Add `errors.messages.locker_number_format_mismatch` ("must match the required format: %{format}" / "doit respecter le format requis : %{format}") and `user.locker_number_format_hint` ("Required format: %{format}" / "Format requis : %{format}") to both locale files.
- [X] T055 [US4] In `app/views/home/_locker_profile_form.html.erb`, when `LockerNumberFormat.current.in_force?`, append the format sentence to the existing `#locker_number_hint` paragraph so the field's single `aria-describedby` still points at one hint.
- [X] T056 [US4] In `app/views/admin/users/_locker_profile_editor.html.erb`, give the locker number field a hint paragraph `#admin_locker_number_hint` with `aria-describedby`, shown only when a format is in force, using the same key.
- [X] T057 [US4] Run T047–T051 until they pass. Then run the full `test/system/locker_profile_test.rb` and `test/system/locker_swap_proposal_test.rb` to confirm the normalizes change broke nothing.

**Checkpoint**: all four stories are functional and independently verified.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T058 [P] Run `bin/rails test test/i18n_completeness_test.rb` and fix any key missing in either language. Switch the site to French and walk quickstart.md scenario 8.
- [X] T059 [P] Check the design visually, following CLAUDE.md "How to check the work". Write a throwaway system test under `test/system/` that signs in as `frank`, configures both settings, and visits the danger zone, the homepage locker profile (pencil editor open) and the locker wish form. For each it calls `wait_for_entrance` and `page.save_screenshot` into `tmp/design/`, at desktop and `with_viewport(:phone)`. Read the images and confirm:
  - both new cards hang on the alert hinge;
  - the examples table becomes labelled cards below 48rem;
  - the badges carry words;
  - pattern and sample values are mono;
  - the select matches the other inputs.
  Then delete the test.
- [X] T060 [P] Run `bin/rubocop` and `bin/brakeman --no-pager`. Both must be clean. Brakeman may flag `Regexp.new` with user input: justify it inline, citing the super-admin-only guard, the length cap and the timeout (research.md R4), rather than suppressing it silently.
- [X] T061 Run the full suite: `bin/rails test && bin/rails test:system`. It must be green, with no new skips and no coverage regression on the models.
- [X] T062 Walk quickstart.md scenarios 1–9 by hand in development.
- [X] T063 Draft the PR description. It covers:
  - the relevant principles (I–IV);
  - the **breaking change**: once a floor list is saved, floors are no longer free text;
  - the reused patterns (`.card--alert`, `.data-table`, `.badge-*`, `field-input` select, the error-messages partial);
  - accessibility checks (the native labelled select, and badges with text);
  - a performance note (single-row lookups, bounded regex).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (T001–T003)**: none.
- **Foundational (T004–T006)**: after Setup. Blocks US1 and US3, which extend `LoadsDangerZone`.
- **US1 (T007–T016)**: after Foundational.
- **US2 (T017–T035)**: after US1's model (T010). It does not need US1's screen.
- **US3 (T036–T046)**: after Foundational. Independent of US1 and US2.
- **US4 (T047–T057)**: after US3's model (T039).
- **Polish (T058–T063)**: after every story it covers.

### User Story Dependencies

```text
Setup ─► Foundational ─┬─► US1 ─► US2
                       └─► US3 ─► US4
```

### Within Each User Story

- Tests first, and they must fail.
- Model or validator, then routes, controller, views, locales.
- Story checkpoint, then the next story.

### Shared-file hotspots (serialise edits)

- `config/locales/en.yml` / `fr.yml`: T015, T028, T033, T044, T054.
- `app/views/admin/danger_zone/show.html.erb`: T014, T043.
- `app/controllers/concerns/loads_danger_zone.rb`: T004, T013, T042.
- `app/models/user.rb`: T026, T053.
- `test/system/admin_danger_zone_test.rb`: T009, T038.
- `test/models/user_test.rb`: T018, T048.
- `test/system/locker_profile_test.rb`: T021, T050.
- `test/system/admin_user_detail_test.rb`: T023, T051.

## Parallel Examples

```text
# Setup
T001 migration site_floor_lists     ∥  T002 migration locker_number_formats

# US1 tests
T007 site_floor_list_test.rb  ∥  T008 floor_list_controller_test.rb  ∥  T009 admin_danger_zone_test.rb

# US2 tests (all different files)
T017 ∥ T018 ∥ T019 ∥ T020 ∥ T021 ∥ T022 ∥ T023 ∥ T024

# After Foundational, two tracks:
Track A: US1 → US2        Track B: US3 → US4
```

## Implementation Strategy

### MVP (US1 + US2)

1. Setup, then Foundational.
2. US1: the super admin saves floors. Validate with its independent test.
3. US2: floors become a closed list everywhere. **Stop, validate, and ship if wanted.** This alone fixes
   the "1" vs "01" matching problem (SC-005).

### Incremental Delivery

4. US3: the format is configurable, with its examples (no enforcement yet, so it is safe to ship alone).
5. US4: enforcement, which completes the feature.
6. Polish.

### Notes

- [P] means different files and no unfinished dependency.
- Commit after each checkpoint.
- Never pre-fill a floor list or format (clarification Q2). Never report conformance counts
  (clarification Q4).
