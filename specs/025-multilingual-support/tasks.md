---

description: "Task list for Site Language Setting (French/English)"
---

# Tasks: Site Language Setting (French/English)

**Input**: Design documents from `/specs/025-multilingual-support/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/danger-zone-language.md, quickstart.md

**Tests**: Constitution II (NON-NEGOTIABLE) requires automated tests for every new feature, so test
tasks are included throughout.

**Organization**: Tasks are grouped by user story (spec.md) to enable independent implementation and
testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Every description includes its exact file path

---

## Phase 1: Setup

**Purpose**: New dependencies and I18n configuration, before any code depends on them

- [X] T001 Add `gem "devise-i18n"` and `gem "rails-i18n"` to `Gemfile`, run `bundle install`, and commit the updated `Gemfile.lock`
- [X] T002 [P] In `config/application.rb`, set `config.i18n.available_locales = [:en, :fr]`, `config.i18n.default_locale = :en`, and `config.i18n.fallbacks = true`
- [X] T003 [P] In `config/environments/test.rb`, set `config.i18n.raise_on_missing_translations = true`

**Checkpoint**: Gems installed, I18n configured — safe to write locale files and `t()` calls next.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The `SiteLanguageSetting` model and the per-request locale switch every user story depends on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Create migration `db/migrate/<timestamp>_create_site_language_settings.rb` for table `site_language_settings` with column `language` (string, not null, default `"en"`) and standard timestamps; run `bin/rails db:migrate` and confirm `db/schema.rb` updates
- [X] T005 [P] Create `app/models/site_language_setting.rb`: `DEFAULT_LANGUAGE = "en"` constant; `validates :language, presence: true, inclusion: { in: %w[en fr] }` (data-model.md — "constrained to `\"en\"` / `\"fr\"`"); a `validate :only_one_row_may_exist, on: :create` that adds an error if `SiteLanguageSetting.exists?` is already true; class method `self.current` implemented as `first_or_create!(language: DEFAULT_LANGUAGE)` (depends on T004)
- [X] T006 [P] Model tests in `test/models/site_language_setting_test.rb`: `language` rejects any value other than `"en"`/`"fr"`; a second row is refused by `only_one_row_may_exist`; `.current` creates a row with `language: "en"` on a first call against an empty table; `.current` returns the existing row (does not create a second one) on a subsequent call (depends on T005)
- [X] T007 Add `around_action :switch_locale` to `app/controllers/application_controller.rb`, implemented as `I18n.with_locale(SiteLanguageSetting.current.language.to_sym) { yield }` in a `protected` method — request-scoped, not a bare `I18n.locale=` assignment (research.md R2, so one request can never leak its language into the next on a reused Puma thread) (depends on T005)
- [X] T008 [P] In `app/views/layouts/application.html.erb`: change `<html lang="en">` to `<html lang="<%= I18n.locale %>">`, and move the `aria-label="Main"` nav landmark to `aria-label="<%= t(".main_nav") %>"` with matching `en.yml`/`fr.yml` entries (research.md R7)
- [X] T009 [P] In `app/views/shared/_site_menu.html.erb`, move `aria-label="Menu"` behind `t(".menu")` with matching `en.yml`/`fr.yml` entries
- [X] T010 [P] In `config/locales/fr.yml` (new file), pin `fr.date.formats`, `fr.time.formats`, `fr.date.day_names`/`abbr_day_names`/`month_names`/`abbr_month_names` (the `%B`/`%A` arrays `strftime` actually reads), and `fr.number.format` to English's values — overriding whatever `rails-i18n` ships for French, so the eight existing `l(record.created_at, format: :long)` call sites never reformat under French (research.md R8, FR-012, verified directly with `I18n.with_locale(:fr) { I18n.l(...) }`); leave the root `fr:` key otherwise ready to receive the per-view entries added in later tasks
- [X] T051 [P] Added during `/speckit-analyze` remediation (finding C1) — create `test/i18n_completeness_test.rb`: read `config/locales/en.yml`/`fr.yml` directly off disk, flatten into dot-path key sets, assert `en.yml`'s keys ⊆ `fr.yml`'s (excluding T010's pinned date/time/number keys). For `devise.en.yml`/`devise.fr.yml`, refined during T020 once real data existed: a plain subset check wrongly flagged the many keys `devise.en.yml` merely restates from Devise's own stock text, so a `devise.en.yml` key is satisfied by *either* `devise.fr.yml` or `devise-i18n`'s own bundled `rails/locales/fr.yml` (`Gem.loaded_specs.fetch("devise-i18n").gem_dir`) — independent of `I18n.backend`/`raise_on_missing_translations`/fallback behavior either way (research.md R4, R9); this is what actually verifies SC-003, independent of which views T043's system test happens to visit (depends on T002; starts failing, ends passing as T013-T041/T020 land)
- [X] T052 [P] Added during `/speckit-analyze` remediation (finding M1) — confirm no `test/fixtures/site_language_settings.yml` is added anywhere in this feature; `test_helper.rb` declares `fixtures :all`, so a seeded row would silently fix the language for every test in the suite and defeat T044's "empty table defaults to English" assertion, the same risk 016 R5 avoided for `allowed_email_domains` (research.md R9) — no code to write, just a check to run before considering T004-T006 done

**Checkpoint**: Foundation ready — `SiteLanguageSetting.current` exists and is applied to every
request; date/time formatting is protected from the locale switch; the completeness test exists and
will start passing as User Story 1's translation tasks land; user story work can begin.

---

## Phase 3: User Story 1 - An administrator sets the site's language (Priority: P1) 🎯 MVP

**Goal**: An administrator changes the language on the Danger Zone screen and it applies, in French or
English, across every screen for every user.

**Independent Test**: Sign in as an administrator, open Admin → Danger Zone, switch the language to
French, save, then browse several different screens (as the administrator and as a standard/signed-out
user) and observe every label is in French; switch back to English and confirm the same screens
return to English.

### Screen and persistence for User Story 1

- [X] T011 [US1] In `config/routes.rb`, change `resource :danger_zone, only: :show, controller: "danger_zone"` to `resource :danger_zone, only: [:show, :update], controller: "danger_zone"`
- [X] T012 [US1] In `app/controllers/admin/danger_zone_controller.rb`: set `@site_language_setting = SiteLanguageSetting.current` in `#show`; add `#update` that assigns `params.require(:site_language_setting).permit(:language)` onto `SiteLanguageSetting.current`, saves it, and on success redirects to `admin_danger_zone_path` with a flash notice naming the newly active language, or on failure re-renders `#show` (re-setting both instance variables) with status `422` (depends on T005, T011)
- [X] T013 [US1] In `app/views/admin/danger_zone/show.html.erb`: add a language section above the existing allowed-domains section — a `select` with exactly two options, "French" and "English", pre-selected to `@site_language_setting.language`, inside a `form_with model: @site_language_setting, url: admin_danger_zone_path, method: :patch` reusing the `.field`/`.field-label`/`.field-input` classes the domain form already uses; move this view's own existing hardcoded strings (the page title, the meta explanation, table headers, button labels, the field hint) behind `t(".…")` lazy lookups, with matching entries added to `config/locales/en.yml` and `config/locales/fr.yml` (depends on T012)

### Devise views and strings for User Story 1

- [X] T014 [P] [US1] Extract every hardcoded string in `app/views/devise/sessions/new.html.erb` (page title "Log in", field labels, submit button and its `turbo_submits_with` text, "Don't have an account? Sign up") behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T015 [P] [US1] Extract every hardcoded string in `app/views/devise/registrations/new.html.erb` behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T016 [P] [US1] Extract every hardcoded string in `app/views/devise/registrations/edit.html.erb` behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T017 [P] [US1] Extract every hardcoded string in `app/views/devise/shared/_error_messages.html.erb` behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T018 [P] [US1] Extract every hardcoded string in `app/views/devise/shared/_links.html.erb` behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T019 [P] [US1] Extract every hardcoded string in `app/views/devise/shared/_password_field.html.erb` (including any visibility-toggle label) behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T020 [US1] Create `config/locales/devise.fr.yml`: for each key this app already overrides in `config/locales/devise.en.yml` (`failure.*` × 8, `confirmations.*` × 3 — the originally-scoped 11), add the same key under `fr:` with LockSwap's own French wording. Widened during implementation, discovered by reading `devise.en.yml` line by line: it also overrides `errors.messages.not_saved` (pluralized), `activerecord.attributes.user.password_confirmation`, and four `activerecord.errors.models.user.attributes.*` messages (`email.taken`, `email.invalid`, `password.too_short`, `password_confirmation.confirmation`) — none coverable by `devise-i18n`/`rails-i18n` since they're LockSwap-specific wording, so all were added too. Everything else in `devise.en.yml` (mailer subjects, `passwords.*`, `registrations.*`, `sessions.*`, `unlocks.*`, `omniauth_callbacks.*`, the remaining `errors.messages.*`) is left uncovered by design — it merely restates Devise's stock English text, which `devise-i18n`'s own French file already translates (research.md R9) (depends on T001)
- [X] T021 [US1] In `config/locales/fr.yml`, add `fr.errors.messages.blank`, `fr.errors.messages.inclusion`, and `fr.errors.messages.not_saved` (the generic ActiveModel keys reached by `User#floor`, `AllowedEmailDomain#domain`, `LockerWish#floor`, and `SiteLanguageSetting#language`'s unmessaged validations, and by the `devise/shared/_error_messages.html.erb` partial's header — research.md R8), and `fr.activerecord.models.user`, `.allowed_email_domain`, `.locker_wish`, `.site_language_setting` plus `fr.activerecord.attributes.user.floor`, `.allowed_email_domain.domain`, `.locker_wish.floor`, `.site_language_setting.language` so `full_messages` reads correctly in French

### Remaining application views for User Story 1

- [X] T022 [P] [US1] Extract every hardcoded string in `app/views/home/index.html.erb` behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T023 [P] [US1] Extract every hardcoded string in `app/views/home/_locker_profile_form.html.erb` behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T024 [P] [US1] Extract every hardcoded string in `app/views/home/_locker_profile.html.erb` behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T025 [P] [US1] Extract every hardcoded string in `app/views/home/_locker_wish.html.erb` behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T026 [P] [US1] Extract every hardcoded string in `app/views/home/_swap_exchange_in_progress.html.erb` behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T027 [P] [US1] Extract every hardcoded string in `app/views/home/_swap_proposals_declined.html.erb` behind `t(".…")` — leaving `l proposal.decided_at, format: :long` itself untouched (date, not a label) — with matching `en.yml`/`fr.yml` entries
- [X] T028 [P] [US1] Extract every hardcoded string in `app/views/home/_swap_proposals_received.html.erb` behind `t(".…")` — leaving `l proposal.created_at, format: :long` untouched — with matching `en.yml`/`fr.yml` entries
- [X] T029 [P] [US1] Extract every hardcoded string in `app/views/home/_swap_proposals_sent.html.erb` behind `t(".…")` — leaving `l proposal.created_at, format: :long` untouched — with matching `en.yml`/`fr.yml` entries
- [X] T030 [P] [US1] Extract every hardcoded string in `app/views/locker_swap_proposals/index.html.erb` behind `t(".…")` — leaving `l proposal.created_at, format: :long` untouched — with matching `en.yml`/`fr.yml` entries
- [X] T031 [P] [US1] Extract every hardcoded string in `app/views/locker_wishes/index.html.erb` behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T032 [P] [US1] Extract every hardcoded string in `app/views/locker_wishes/_floor_filter.html.erb` (including the "All floors" choice) behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T033 [P] [US1] Extract every hardcoded string in `app/views/locker_wishes/_locker_wish_form.html.erb` behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T034 [P] [US1] Extract every hardcoded string in `app/views/locker_wishes/_locker_wish_list.html.erb` behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T035 [P] [US1] Extract every hardcoded string in `app/views/locker_wishes/_locker_wish_panel.html.erb` behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T036 [P] [US1] Extract every hardcoded string in `app/views/admin/users/index.html.erb` behind `t(".…")` — leaving `l user.created_at, format: :long` and `l user.admin_granted_at, format: :long` untouched — with matching `en.yml`/`fr.yml` entries
- [X] T037 [P] [US1] Extract every hardcoded string in `app/views/admin/users/_floor_filter.html.erb` (including the "All ..." choice) behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T038 [P] [US1] Extract every hardcoded string in `app/views/admin/users/_text_filter.html.erb` behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T039 [P] [US1] Extract every hardcoded string in `app/views/shared/_site_menu_items.html.erb` (Admin, Users, Danger Zone, Log out, and every other nav label) behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T040 [P] [US1] Extract every hardcoded string in `app/views/layouts/_flash.html.erb` behind `t(".…")`, with matching `en.yml`/`fr.yml` entries
- [X] T041 [P] [US1] In `app/views/pwa/manifest.json.erb`, move the `"description"` field's text behind `t("pwa.manifest.description")` with matching `en.yml`/`fr.yml` entries; leave `"name"`/`"short_name"` ("LockSwap") as literal strings — it is the brand name, not translated (spec Assumptions)

### Tests for User Story 1

- [X] T042 [US1] Extend `test/controllers/admin/danger_zone_controller_test.rb` with `#update` coverage: an administrator's valid `language` param persists and redirects with a flash notice; anonymous and non-administrator requests are redirected per the existing admin-only guard with the configured language unchanged; an invalid `language` value re-renders `#show` with status `422` and leaves the configured language unchanged (depends on T012)
- [X] T043 [US1] New system test `test/system/site_language_test.rb`, three tests. "switching the language applies across the site and is reversible" drives the actual admin UI end to end (Danger Zone → French → sign-in/registration screens → back to English), reusing the same session throughout rather than a second login (Devise's own `require_no_authentication` redirects an authenticated visitor away from sign-in/registration, so a *second* `log_in_as` mid-test cannot work either way). The other two tests (date format unchanged, user comment unchanged) set `SiteLanguageSetting.current.update!(language: "fr")` directly rather than through the admin UI — deliberately, once the UI path was already proven by the first test, to avoid a fragile sign-out/sign-in chain across two languages and two users. Two real bugs surfaced and were fixed along the way: (1) `log_in_as`/`click_on "Log out"` assume English copy, so a small `log_out_under(language)`/`sign_in_under_current_locale` pair was added, looking button text up via `I18n.t(key, locale:)` instead of a literal; (2) Selenium's native click intermittently no-ops on the logout button specifically, reproduced directly (the element at its own click-point coordinates is itself — not a hit-testing/overlay problem), worked around with a JS-dispatched click (depends on T013, T041, all extraction tasks above)

**Checkpoint**: User Story 1 is fully functional and independently testable — the language can be
changed from Danger Zone and it visibly applies everywhere.

---

## Phase 4: User Story 2 - A fresh installation starts in English (Priority: P2)

**Goal**: Before any administrator configures anything, the site is in English by default.

**Independent Test**: On a freshly reset database, view any screen without signing in and observe it
is in English; open the Danger Zone screen as an administrator and confirm the language setting shows
"English".

- [X] T044 [P] [US2] Add a test to `test/models/site_language_setting_test.rb` asserting `SiteLanguageSetting.current.language == SiteLanguageSetting::DEFAULT_LANGUAGE` (`"en"`) when the table holds zero rows, independent of any other test's setup (depends on T006)
- [X] T045 [US2] Add a system test to `test/system/site_language_test.rb`: against a database with no `SiteLanguageSetting` row ever created, visit the sign-in screen signed out and confirm it renders in English, then sign in as an administrator and confirm the Danger Zone screen's language section shows "English" as the current selection (depends on T013, T043)

**Checkpoint**: User Story 1 and User Story 2 both independently pass.

---

## Phase 5: User Story 3 - Only administrators can change the language (Priority: P3)

**Goal**: No non-administrator can see or change the site language, and the site-wide setting is
followed regardless of a user's own browser/account locale.

**Independent Test**: Signed in as a standard user, confirm the Admin menu (or its Danger Zone entry)
is not shown, confirm the language setting is neither visible nor editable anywhere in the product,
and confirm the screens they view follow the site-wide setting regardless of their own locale.

- [X] T046 [P] [US3] Add a test to `test/controllers/admin/danger_zone_controller_test.rb`'s `#update` coverage confirming a signed-in non-administrator's `PATCH` request is redirected with `ApplicationController::ADMINISTRATORS_ONLY_MESSAGE` and the configured language is unchanged, distinct from the anonymous case already added in T042 (depends on T042)
- [X] T047 [US3] Add a system test to `test/system/site_language_test.rb`: signed in as a standard user, confirm no "Admin"/"Danger Zone" entry appears in navigation and no language control is offered anywhere in the product; with the site language set to French and the test's simulated browser/OS locale left at its English default, confirm the standard user's screens still render in French — proving the site-wide setting, not the visitor's own locale, is what is followed (depends on T043, T045)

**Checkpoint**: All three user stories are independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verification that spans all three stories

- [X] T048 [P] Run `bin/rubocop` and `bin/brakeman`, fixing any new offense introduced by this feature (Constitution I Quality Gates)
- [X] T049 Run `bin/rails test` and `bin/rails test:system` in full; a clean run confirms no unextracted string remains (`raise_on_missing_translations`, T003) and — together with `test/i18n_completeness_test.rb` (T051) passing — is what actually evidences SC-003, since `raise_on_missing_translations` alone cannot detect an English-only key (research.md R4, R9)
- [X] T050 Execute `quickstart.md`'s manual validation walkthrough end-to-end, including its "Edge cases worth confirming by hand" section

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup (T001 for the `rails-i18n`/`devise-i18n` gems that later
  tasks build on) — BLOCKS all user stories.
- **User Stories (Phase 3–5)**: All depend on Foundational (Phase 2) completion.
  - User Story 1 (P1) has no dependency on User Story 2 or 3.
  - User Story 2 (P2) reuses infrastructure and views User Story 1 builds (the Danger Zone language
    section, the sign-in screen's translated strings) for its own tests, so it is sequenced after US1
    here, though its own production code (T044) has none of that dependency.
  - User Story 3 (P3) similarly reuses US1's system-test file and US1/US2's admin-only guard tests as
    its base, so it is sequenced last, though the guard itself (`require_admin!`) already exists from
    prior features.
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### Within User Story 1

- T011 (route) before T012 (`#update` action) before T013 (view, which submits to the new route/action).
- T014–T041 (view string extraction) have no dependency on each other or on T011–T013 — all `[P]`.
- T020 (`devise.fr.yml`) depends only on T001 (gem installed).
- T042 (controller test) depends on T012. T043 (system test) depends on T013, T041, and effectively on
  the extraction tasks it asserts against, since the assertions name specific French strings.

### Parallel Opportunities

- T002 and T003 (Setup) in parallel.
- T005, T006, T008, T009, T010, T051, T052 (Foundational) in parallel once T004 (migration) is applied
  and T005 exists for T006/T007 to build on.
- T014–T019, T022–T041 (28 view-extraction tasks across Devise, home, swap proposals, locker wishes,
  admin users, shared nav/flash, and the PWA manifest) are all `[P]` — different files, no shared state
  — the single largest parallelization opportunity in this feature.
- T044 and T046 in parallel with each other (different test files, no shared state), once their
  respective prerequisite tasks (T006, T042) are done.

---

## Parallel Example: User Story 1 view extraction

```bash
# Once Foundational (Phase 2) is complete, launch the Devise view extractions together:
Task: "Extract app/views/devise/sessions/new.html.erb behind t(), en.yml/fr.yml entries"
Task: "Extract app/views/devise/registrations/new.html.erb behind t(), en.yml/fr.yml entries"
Task: "Extract app/views/devise/registrations/edit.html.erb behind t(), en.yml/fr.yml entries"

# And, independently, the home/locker-wishes/admin-users views:
Task: "Extract app/views/home/index.html.erb behind t(), en.yml/fr.yml entries"
Task: "Extract app/views/locker_wishes/index.html.erb behind t(), en.yml/fr.yml entries"
Task: "Extract app/views/admin/users/index.html.erb behind t(), en.yml/fr.yml entries"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories).
3. Complete Phase 3: User Story 1 — the language can be changed and takes effect everywhere.
4. **STOP and VALIDATE**: run T042/T043, then the "1" and "2" sections of `quickstart.md` by hand.
5. Deploy/demo if ready — this alone is the shippable core of the feature.

### Incremental Delivery

1. Setup + Foundational → foundation ready (setting exists, defaults to English, applies everywhere).
2. Add User Story 1 → test independently → deploy/demo (MVP).
3. Add User Story 2 → test independently → deploy/demo (confirms the default, no new production code).
4. Add User Story 3 → test independently → deploy/demo (confirms the access boundary already enforced
   by existing guards, with tests specific to the language setting).
5. Polish → full-suite and quickstart confirmation.

### Notes

- [P] tasks touch different files with no shared state.
- Commit after each task or logical group (e.g., all of one story's view-extraction tasks together).
- Every `t()` call added anywhere in this feature is verified for both locales by T003's
  `raise_on_missing_translations` the next time `bin/rails test`/`test:system` runs — do not defer that
  run to the end; run it after each story's phase to catch a missed key early.
