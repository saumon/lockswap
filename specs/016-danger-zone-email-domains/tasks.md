---

description: "Task list template for feature implementation"
---

# Tasks: Danger Zone – Allowed Email Domains

**Input**: Design documents from `/specs/016-danger-zone-email-domains/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/danger-zone.md,
quickstart.md (all present)

**Tests**: NOT optional for this feature. The project constitution's Testing Standards principle is
marked NON-NEGOTIABLE and requires that every new feature include automated tests that fail without
the change and pass with it. Test tasks below are therefore mandatory, not illustrative, and each is
ordered before the implementation it constrains.

**Organization**: Tasks are grouped by user story (spec.md) to enable independent implementation and
testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Single Rails project at repository root: `app/`, `config/`, `db/`, `test/`. Paths below are exact.

---

## Phase 1: Setup

**Purpose**: Create the migration file this feature needs. No new dependency, gem or tooling is
required.

- [X] T001 Generate the migration skeleton: `bin/rails generate migration CreateAllowedEmailDomains`, creating `db/migrate/<timestamp>_create_allowed_email_domains.rb`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The table, the model, and the routes every user story needs to exist before any story's
happy path can be exercised at all.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 In `db/migrate/<timestamp>_create_allowed_email_domains.rb`, per data-model.md: `create_table :allowed_email_domains do |t| t.string :domain, null: false; t.timestamps end` then `add_index :allowed_email_domains, :domain, unique: true`
- [X] T003 Run `bin/rails db:migrate` to apply the migration and regenerate `db/schema.rb`; confirm the new table and its unique index on `domain` appear
- [X] T004 [P] In `config/routes.rb`, inside the existing `namespace :admin do ... end` block (alongside `resources :users`), add `resource :danger_zone, only: :show` and `resources :allowed_email_domains, only: [:create, :destroy]` (contracts/danger-zone.md "Routes")
- [X] T005 [P] Write failing model tests in `test/models/allowed_email_domain_test.rb`: presence — a blank `domain` is invalid; format — `"company.com"` is valid, `"not a domain"` and an email address (`"user@company.com"`) are invalid (data-model.md "must be a domain, like company.com"); normalization — `" Company.COM "` saves as `"company.com"` (`normalizes :domain, with: ->(value) { value.to_s.strip.downcase }`); uniqueness — a second record with a case-different duplicate (`"COMPANY.com"`) of an existing `"company.com"` row is invalid
- [X] T006 [P] In `app/models/allowed_email_domain.rb`, create `AllowedEmailDomain < ApplicationRecord` with `normalizes :domain, with: ->(value) { value.to_s.strip.downcase }` and `validates :domain, presence: true, format: { with: /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+\z/, message: "must be a domain, like company.com" }, uniqueness: true` (data-model.md "AllowedEmailDomain") — makes T005 pass

**Checkpoint**: The table, model and routes exist. User story implementation can now begin.

---

## Phase 3: User Story 1 - An administrator restricts sign-up to specific email domains (Priority: P1) 🎯 MVP

**Goal**: An administrator opens the new Danger Zone screen, adds one or more allowed email domains,
and from then on registration with a non-matching domain is refused with the exact required message
while registration with a matching domain (or, before any domain is added, any domain at all)
continues to succeed.

**Independent Test**: With an administrator account, open Admin → Danger Zone, add one domain, then
attempt to register with an email on a different domain (refused with the exact message) and with an
email on the allowed domain (succeeds).

### Tests for User Story 1

- [X] T007 [P] [US1] Write failing model tests in `test/models/user_test.rb` for `User#email_domain_allowed`: with no `AllowedEmailDomain` rows, a `User.new(email: "anyone@wherever.example", password: ...)` is valid on `:create` (FR-004); with one row `domain: "allowed.example"`, a matching email (`"person@allowed.example"`) is valid, a non-matching email (`"person@other.example"`) is invalid with `errors[:base]` including exactly `"Your email address domain is not allowed"` (FR-005, FR-006); the check is case-insensitive — `"person@Allowed.Example"` is valid against the same configured row (FR-007); a subdomain of an allowed domain (`"person@mail.allowed.example"`) is **invalid** unless `mail.allowed.example` is itself a configured row (Clarifications 2026-09-18, FR-007)
- [X] T008 [P] [US1] Write a failing model test in `test/models/user_test.rb`: the `email_domain_allowed` validation does not fire on `update` — given an existing, saved `User` whose email domain would now fail a freshly configured allow-list, calling `save` on an unrelated attribute change still succeeds (FR-010, data-model.md "`on: :create`")
- [X] T009 [P] [US1] Write failing controller tests in `test/controllers/registrations_controller_test.rb`: `POST /users` with a configured allow-list and a non-matching email is refused, creates no account, and the response body contains exactly "Your email address domain is not allowed" (FR-006, contracts/danger-zone.md "Registration contract"); with a matching email it succeeds exactly as before this feature (FR-005 acceptance scenario 3)
- [X] T010 [P] [US1] Write failing controller tests in `test/controllers/admin/danger_zone_controller_test.rb`: `GET /admin/danger_zone` as an administrator succeeds and lists every configured `AllowedEmailDomain`, ordered by domain (contracts/danger-zone.md "Danger Zone screen contract")
- [X] T011 [P] [US1] Write failing controller tests in `test/controllers/admin/allowed_email_domains_controller_test.rb`: `POST /admin/allowed_email_domains` as an administrator with a valid `domain` param creates the row and redirects to `admin_danger_zone_path` with a `notice`; with an invalid `domain` (e.g. `"not a domain"`) it creates nothing and re-renders the Danger Zone screen with status `422` and the validation error visible (contracts/danger-zone.md "Add form", "Validation failure on add")
- [X] T012 [US1] Write failing system tests in `test/system/admin_danger_zone_test.rb`: signed in as an administrator, Admin → Danger Zone shows an empty list and a line stating registration is open to any domain; adding `allowed.example` shows it in the list; logging out and registering `person@other.example` is refused with the exact error text on screen, while registering `person@allowed.example` succeeds (quickstart.md Section 1)

### Implementation for User Story 1

- [X] T013 [US1] In `app/models/user.rb`, add `EMAIL_DOMAIN_NOT_ALLOWED_MESSAGE = "Your email address domain is not allowed".freeze`, `validate :email_domain_allowed, on: :create`, and the private method: `allowed_domains = AllowedEmailDomain.pluck(:domain); return if allowed_domains.empty?; submitted_domain = email.to_s.split("@").last.to_s.downcase; return if allowed_domains.include?(submitted_domain); errors.add(:base, EMAIL_DOMAIN_NOT_ALLOWED_MESSAGE)` (data-model.md "User") — makes T007, T008, T009 pass
- [X] T014 [P] [US1] Create `app/controllers/admin/danger_zone_controller.rb`: `Admin::DangerZoneController < ApplicationController` with `before_action :authenticate_user!` and `before_action :require_admin!` (matching `Admin::UsersController`), and `#show` setting `@allowed_email_domains = AllowedEmailDomain.order(:domain)` and `@allowed_email_domain = AllowedEmailDomain.new` — makes T010 pass
- [X] T015 [P] [US1] Create `app/controllers/admin/allowed_email_domains_controller.rb`: `Admin::AllowedEmailDomainsController < ApplicationController` with the same `before_action` pair, and `#create` building `AllowedEmailDomain.new(params.expect(allowed_email_domain: [:domain]))`; on success, redirect to `admin_danger_zone_path` with `notice: "Domain added."`; on failure, set `@allowed_email_domains = AllowedEmailDomain.order(:domain)` and `render "admin/danger_zone/show", status: :unprocessable_entity` — makes T011 pass
- [X] T016 [US1] Create `app/views/admin/danger_zone/show.html.erb`: a card titled "Danger Zone" containing (a) `render "devise/shared/error_messages", resource: @allowed_email_domain` for validation failures, (b) a message shown only when `@allowed_email_domains.empty?` stating registration is currently open to any email domain (FR-004, contracts/danger-zone.md), (c) a `data-table` listing each `@allowed_email_domains` row's domain, matching the existing `admin/users/index.html.erb` table markup, and (d) a `form_with model: @allowed_email_domain, url: admin_allowed_email_domains_path` with a `domain` text field and a submit button "Add domain" (FR-003, matching the `field`/`field-label`/`field-input` classes from `home/_locker_profile_form.html.erb`)
- [X] T017 [US1] In `app/views/shared/_site_menu_items.html.erb`, inside the existing `<% if current_user.admin? %>` submenu block, add `<%= link_to "Danger Zone", admin_danger_zone_path, class: "site-nav-link" %>` beneath the existing "Users" link

**Checkpoint**: User Story 1 is fully functional and independently testable — this is the MVP slice.

---

## Phase 4: User Story 2 - An administrator lifts the restriction (Priority: P2)

**Goal**: An administrator can remove a previously configured domain, and once none remain,
registration is open to any domain again — exactly like the site's behavior before this feature.

**Independent Test**: With one domain configured, remove it from the Danger Zone screen and confirm
registration with any email domain now succeeds.

### Tests for User Story 2

- [X] T018 [P] [US2] Write failing controller tests in `test/controllers/admin/allowed_email_domains_controller_test.rb`: `DELETE /admin/allowed_email_domains/:id` as an administrator removes the row and redirects to `admin_danger_zone_path` with a `notice`; given the removed row was the only configured domain, a subsequent `POST /users` with a previously-disallowed email domain now succeeds (FR-004, contracts/danger-zone.md)
- [X] T019 [P] [US2] Write a failing system test in `test/system/admin_danger_zone_test.rb`: with `allowed.example` configured, the Danger Zone screen offers a "Remove" control on its row; activating it shows a confirmation naming the domain; declining leaves the domain in place; confirming removes it, and the "open to any domain" line reappears once the list is empty (quickstart.md Section 2)

### Implementation for User Story 2

- [X] T020 [US2] In `app/controllers/admin/allowed_email_domains_controller.rb`, add `#destroy`: `AllowedEmailDomain.find_by(id: params[:id])&.destroy` then redirect to `admin_danger_zone_path` with `notice: "Domain removed."` (contracts/danger-zone.md) — makes T018 pass
- [X] T021 [US2] In `app/views/admin/danger_zone/show.html.erb`, add a "Remove" `button_to` on each domain row, submitting `admin_allowed_email_domain_path(allowed_email_domain)` with `method: :delete` and `data: { confirm: ..., turbo_confirm: ... }` naming the domain, mirroring the "Grant admin rights" confirmation construction in `admin/users/index.html.erb` (contracts/danger-zone.md "Remove control") — makes T019 pass

**Checkpoint**: Both adding and removing domains work, and the empty-list state genuinely reopens
registration.

---

## Phase 5: User Story 3 - Only administrators can reach the Danger Zone (Priority: P3)

**Goal**: A non-administrator, signed in or signed out, cannot see the Danger Zone entry in
navigation and cannot view or change the allowed-domains configuration by any route.

**Independent Test**: Signed in as a standard user, confirm no "Danger Zone" entry appears and that
visiting `/admin/danger_zone` directly, or posting/deleting against the allowed-email-domains routes
directly, is refused.

**Expected to need no new production code.** `Admin::DangerZoneController` and
`Admin::AllowedEmailDomainsController` already carry `before_action :authenticate_user!` /
`before_action :require_admin!` from Phase 3 (T014, T015), and the menu link from T017 already sits
inside the existing `if current_user.admin?` block. These tasks exist to prove that rather than
assume it; if any of them fails, a guard is missing or misplaced.

### Tests for User Story 3

- [X] T022 [P] [US3] Write failing controller tests in `test/controllers/admin/danger_zone_controller_test.rb`: an anonymous visitor requesting `GET /admin/danger_zone` is redirected to `new_user_session_path`; a signed-in non-administrator is redirected to `root_path` with `flash[:alert]` equal to `ApplicationController::ADMINISTRATORS_ONLY_MESSAGE`; in both cases no configuration is shown (contracts/danger-zone.md "Access contract")
- [X] T023 [P] [US3] Write failing controller tests in `test/controllers/admin/allowed_email_domains_controller_test.rb`: the same two callers hitting `POST /admin/allowed_email_domains` and `DELETE /admin/allowed_email_domains/:id` directly are both refused with no change to the configured domains (contracts/danger-zone.md "Access contract")
- [X] T024 [P] [US3] Write a failing system test in `test/system/admin_danger_zone_test.rb`: a standard user's navigation shows no "Admin" entry at all (or, if signed in with an existing "Admin" entry from another feature, no "Danger Zone" link within it); an administrator's navigation does show "Danger Zone" inside "Admin" (quickstart.md Section 3, FR-002)

### Implementation for User Story 3

- [X] T025 [US3] Confirm T022, T023 and T024 pass with no further production change: the refusals come from the `require_admin!` pair already added in Phase 3, and the menu visibility from the existing `if current_user.admin?` wrapper. If any fails, fix the guard in `app/controllers/admin/danger_zone_controller.rb`, `app/controllers/admin/allowed_email_domains_controller.rb`, or `app/views/shared/_site_menu_items.html.erb` rather than adding a second check elsewhere

**Checkpoint**: All three user stories work, independently and together.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: The quality gates the constitution requires before merge (plan.md Constitution Check).

- [X] T026 [P] Add the Danger Zone screen (empty state, populated list, add form, remove confirmation) to the existing per-screen accessibility audit in `test/system/accessibility_test.rb` (Constitution III)
- [X] T027 [P] Add the Danger Zone screen to the existing phone/desktop responsive-viewport sweep in `test/system/responsive_test.rb` (012 FR-005's table/card duality)
- [X] T028 Run `bin/rubocop` and `bin/brakeman` and resolve every finding; a suppressed warning must carry an inline comment explaining why it is safe (Constitution I)
- [X] T029 Run `bin/rails test` and confirm the full suite passes with no regressions — in particular, that no existing registration/signup test anywhere in the suite was affected by this feature (research.md R5: no fixture file was added for `allowed_email_domains`, so the table is empty by default in every test)
- [X] T030 Run `bin/rails test:system` and confirm the whole suite passes
- [X] T031 Write `specs/016-danger-zone-email-domains/PR.md`, following the shape 015's PR.md established. It MUST record: (a) which Core Principles are engaged and how (Development Workflow); (b) the existing patterns reused rather than replaced — the Admin submenu, the Devise error partial, the "Grant admin rights" confirmation construction, the `admin/users` table/card markup (Principle III); (c) that the signup-time check is a single bounded `pluck`, not a per-row query (Principle IV); (d) before/after test counts (Principle II). Depends on T026–T030, whose results it reports

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)** → **Phase 2 (Foundational)**: the migration must exist before it can be filled in and applied.
- **Phase 2** blocks everything: without the table, model and routes, no story's happy path can be exercised at all.
- **Phase 3 (US1)** is the MVP and depends only on Phase 2.
- **Phase 4 (US2)** depends on Phase 3 — there is nothing to remove until adding works, and the screen/controller it extends is created there.
- **Phase 5 (US3)** depends on Phase 3 (the controllers and the menu link it tests) but not on Phase 4.
- **Phase 6 (Polish)** last; within it, T031 depends on T026–T030.

### Within Each Phase

Test tasks come before the implementation they constrain, per Testing Standards.

### Parallel Opportunities

- T004 and T005 touch different files with no dependency between them; T006 depends on T005 existing (to have something to make pass) but not on T004.
- T007 through T012 are five independent test files.
- T014 and T015 are independent controller files; T013 (the `User` model) is independent of both.
- T018 and T019 are independent files.
- T022, T023, T024 are independent files.
- T026 and T027 touch different files.

**Not parallel, despite appearances**: T016, T021, and later view edits all touch
`app/views/admin/danger_zone/show.html.erb` — sequence them rather than running in parallel. T014 and
T015 are parallel to each other, but T016 depends on both existing.

## Parallel Example: Foundational Phase

```sh
# Once T003 (migration applied) is done, these touch different files:
#   T004  config/routes.rb
#   T005  test/models/allowed_email_domain_test.rb
# T006 (app/models/allowed_email_domain.rb) depends on T005 being written first.
```

## Implementation Strategy

### MVP First (User Story 1 Only)

Phases 1 → 2 → 3 deliver the whole of what was asked for: an admin screen to add allowed domains, and
registration refusing non-matching ones with the exact required message. Stopping there leaves a
working, demonstrable feature, but with one real gap: there is no way to undo a restriction once
added except by hand in a console (Phase 4), and the admin-only guard, while already in place, has no
test proving it (Phase 5).

### Incremental Delivery

1. Phases 1–2: the table, model and routes exist. Nothing visible yet.
2. Phase 3: **MVP** — demo-able end to end (add a domain, see it enforced).
3. Phase 4: the escape hatch — remove a domain, restriction lifts.
4. Phase 5: proof the admin-only guard holds, no production code expected.
5. Phase 6: gates, then PR.

## Notes

- [P] tasks touch different files and have no dependency on another incomplete task in the same batch.
- Every FR-xxx / SC-xxx reference above traces back to `spec.md`; every R-prefixed reference traces to
  `research.md`.
- Commit after each task or logical group, per repository convention.
- Deliberately no `test/fixtures/allowed_email_domains.yml` (research.md R5) — `fixtures :all` in
  `test/test_helper.rb` would otherwise apply any configured row to every test in the suite. Tests
  that need a configured domain create it inline.
