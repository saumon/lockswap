# Implementation Plan: Site Language Setting (French/English)

**Branch**: `025-multilingual-support` | **Date**: 2026-09-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/025-multilingual-support/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

A single new administrator-only setting on the existing Danger Zone screen — `SiteLanguageSetting`, a
singleton row holding `"en"` or `"fr"` — read once per request by a new `ApplicationController`
`around_action` that scopes `I18n.locale` to it for the whole application via `I18n.with_locale`.
`Admin::DangerZoneController` gains an `#update` action alongside its existing `#show`, guarded by the
same `authenticate_user!`/`require_admin!` pair 016 already established on that controller.

The larger share of the work is not the setting itself but making the rest of the application actually
respond to it: today no view calls `I18n.t`, so every hardcoded English string across ~34 view
templates moves behind a `t()`/`t(".…")` lazy-lookup call, with a matching key added to both
`config/locales/en.yml` and a new `config/locales/fr.yml`. Devise's own strings (sign in, sign up,
password reset, confirmations, failures) are translated via the `devise-i18n` gem, with this app's
existing English overrides (007's uniform "Invalid email or password.", etc.) given a French twin.
`config.i18n.raise_on_missing_translations = true` in the test environment turns any missed
extraction or incomplete translation into a failing test rather than a silent gap.

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged)

**Primary Dependencies**: Rails 8.1.3, Devise 5.0, Turbo/Stimulus via importmap (unchanged) — adds two
new gems: `devise-i18n` for Devise's own French translations (research.md R5), and `rails-i18n` for
Rails/ActiveModel's own bundled French messages (research.md R8, with its `date`/`time` sections
pinned back to English in `fr.yml` to preserve FR-012). Interface translation itself uses Rails'
built-in `I18n` (already bundled with `rails/all`) — no other new dependency

**Storage**: SQLite through Active Record (unchanged) — adds one new table, `site_language_settings`
(exactly one row, ever); no changes to any existing table

**Testing**: Minitest + Rails system tests (Capybara, headless Chrome), axe-core accessibility audits
(unchanged — extends the existing suites); test environment gains
`config.i18n.raise_on_missing_translations = true` so an unextracted or untranslated string fails the
suite instead of silently falling back

**Target Platform**: Linux server, deployed via Docker + Kamal (unchanged)

**Project Type**: Web — server-rendered Rails monolith, single project (unchanged)

**Performance Goals**: The one setting read added to every request is a single indexed `SELECT ...
LIMIT 1` (research.md R3) — the same cost class as the session lookup Devise already performs on
every request; no swap/lock execution path is touched

**Constraints**: Must reuse the site's existing admin-only navigation guard (`require_admin!`), the
existing Danger Zone screen and form/error-display conventions (Constitution III); the locale switch
must be request-scoped (`I18n.with_locale`, not a bare assignment) so one request can never leak its
language into another on a reused Puma thread (research.md R2); dates/numbers stay in one fixed format
regardless of language (Clarifications, 2026-09-21)

**Scale/Scope**: One migration (new table), one model (`SiteLanguageSetting`), one new controller
action (`Admin::DangerZoneController#update`), one new route, one new `ApplicationController`
around_action, two new gems, two new/extended locale files (`en.yml`, `fr.yml`, the latter pinning
`date`/`time`/`number` back to English) plus a new `devise.fr.yml`, and — the bulk of the diff — every
existing `.erb` view (~33 files) and `devise.en.yml`'s existing keys re-expressed as `t()` lookups with
French counterparts

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|---|---|
| I. Code Quality | PASS. The new setting follows the single-responsibility split already established: `SiteLanguageSetting` owns its own validation (data-model.md), `Admin::DangerZoneController#update` owns persisting it, `ApplicationController`'s `around_action` owns applying it — no action does more than one of these. The large volume of the change (string extraction across ~34 views) is mechanical and repetitive by nature, not complex; `raise_on_missing_translations` is itself a static-analysis-style gate catching exactly the class of defect (a missed or incomplete key) this principle exists to prevent, satisfying "zero unresolved warnings" for translation coverage specifically. |
| II. Testing Standards | PASS. New behavior gets failing-first tests at the level that can reach it: model tests for `SiteLanguageSetting` (the two-value constraint, the singleton guard, `.current`'s create-on-first-call behavior); controller tests for the admin-only guard on `#update` and the persist/redirect/flash behavior; a system test switching the language and asserting representative screens (not just Danger Zone) render in French; and a dedicated `test/i18n_completeness_test.rb` (research.md R9) that diffs `en.yml`/`fr.yml` and `devise.en.yml`/`devise.fr.yml` directly, which is what actually proves every extracted string has a French counterpart — `raise_on_missing_translations` alone only catches a string that was never extracted at all (research.md R4), not one translated to English only, so it cannot carry that claim by itself. |
| III. User Experience Consistency | PASS. The language control reuses the existing `.field`/`.field-label`/`.field-input` form vocabulary (this app's first `select` element, but not a new visual pattern) and the existing Devise-partial error display. The `<html lang>` attribute update (research.md R7) is itself an accessibility correction the principle already requires for any user-facing change producing new-language content. |
| IV. Performance Requirements | PASS. The per-request setting read is one bounded, indexed query (research.md R3), not on the swap/lock hot path; no unbounded loop or query is introduced. No caching layer is added specifically because a cache-invalidation bug would risk violating FR-008 (every user sees a change by their next request), which the constitution's own performance-vs-correctness framing favors avoiding over a micro-optimization that saves one cheap query. |

No unjustified violations. Complexity Tracking is not needed.

## Project Structure

### Documentation (this feature)

```text
specs/025-multilingual-support/
├── plan.md                          # This file (/speckit-plan command output)
├── research.md                      # Phase 0 output — nine decisions
├── data-model.md                    # Phase 1 output — SiteLanguageSetting, locale files
├── quickstart.md                    # Phase 1 output — manual validation of the acceptance scenarios
├── contracts/
│   └── danger-zone-language.md      # Phase 1 output — routes, screen contract, site-wide contract
├── checklists/
│   └── requirements.md              # Spec quality checklist (16/16)
├── spec.md
└── tasks.md                         # Phase 2 output (/speckit-tasks — NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── controllers/
│   ├── application_controller.rb              # + around_action :switch_locale (I18n.with_locale)
│   └── admin/
│       └── danger_zone_controller.rb           # + #update (existing #show extended to read @site_language_setting)
├── models/
│   └── site_language_setting.rb                # NEW — .current, language inclusion + singleton guard
└── views/
    ├── layouts/application.html.erb             # <html lang="en"> → <html lang="<%= I18n.locale %>">
    ├── admin/danger_zone/show.html.erb           # + language section; existing content moves behind t()
    ├── devise/**/*.html.erb                      # existing hardcoded strings moved behind t()
    └── **/*.html.erb                              # every other view (~34 total) — same treatment

config/
├── routes.rb                        # resource :danger_zone, only: :show → only: [:show, :update]
├── application.rb                   # + config.i18n.available_locales, default_locale, fallbacks
├── environments/test.rb             # + config.i18n.raise_on_missing_translations = true
└── locales/
    ├── en.yml                       # extended — every t()/t(".…") key used across the app
    ├── fr.yml                       # NEW — French counterpart of en.yml
    ├── devise.en.yml                # unchanged (existing overrides)
    └── devise.fr.yml                # NEW — this app's French overrides, layered over devise-i18n's own French file

Gemfile / Gemfile.lock                # + devise-i18n

db/
├── migrate/<ts>_create_site_language_settings.rb
└── schema.rb

test/
├── i18n_completeness_test.rb                                 # NEW — diffs en.yml/fr.yml and devise.en.yml/devise.fr.yml directly (research.md R9)
├── models/site_language_setting_test.rb                      # inclusion, singleton guard, .current — no fixture file (research.md R9)
├── controllers/admin/danger_zone_controller_test.rb          # + #update: admin-only guard, persist, flash
└── system/
    ├── admin_danger_zone_test.rb                             # + language section: select, save, persisted
    └── site_language_test.rb                                 # NEW — French pass across representative screens
```

**Structure Decision**: Single Rails project, unchanged. This feature adds one new table/model, one
new controller action on an existing controller, one new cross-cutting `around_action`, one new gem,
and (the bulk of the change) moves existing hardcoded view strings behind Rails' own `I18n`, following
the same `namespace :admin` / `require_admin!` conventions 013 and 016 already established. No new
top-level directory or service.

## Post-Design Constitution Check

Re-checked after Phase 1. Still PASS on all four; one thing worth naming rather than leaving buried in
the diff:

- **Code Quality / Testing**: `raise_on_missing_translations` alone is not sufficient evidence that
  FR-006/FR-007/SC-003 hold — it catches an unextracted string, not an incomplete French translation,
  since `config.i18n.fallbacks = true` lets a French-missing/English-present key resolve silently under
  any locale. The dedicated `test/i18n_completeness_test.rb` (research.md R9) is what actually closes
  that gap, by diffing this app's own locale file pairs directly rather than relying on incidental view
  coverage from the one system test that switches locale. (Found during `/speckit-analyze`, finding C1.)

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations.
