# Phase 1 Data Model: Site Language Setting (French/English)

**Feature**: [spec.md](./spec.md) | **Branch**: `025-multilingual-support` | **Date**: 2026-09-21

## `SiteLanguageSetting`

The spec's Key Entity, "Site Language Setting" (spec.md), made concrete. One table, one row, ever.

| Column | Type | Notes |
|---|---|---|
| `id` | integer, PK | standard Rails primary key |
| `language` | string, not null, default `"en"` | constrained to `"en"` / `"fr"` (FR-003) |
| `created_at` / `updated_at` | datetime | standard Rails timestamps |

### Validations

- `validates :language, presence: true, inclusion: { in: %w[en fr] }` — FR-003's "exactly two
  choices" made unrepresentable any other way, the same way `AllowedEmailDomain#domain`'s format
  validation makes an invalid domain unrepresentable rather than merely undesired.
- `validate :only_one_row_may_exist, on: :create` — refuses to create a second row if one already
  exists, mirroring how the codebase already guards other "there can only be one/last of this" facts
  (e.g. `User`'s last-administrator destroy guard) with a named validation rather than trusting every
  future caller to remember the rule.

### Class-level access

- `SiteLanguageSetting.current` — `first_or_create!(language: DEFAULT_LANGUAGE)`, where
  `DEFAULT_LANGUAGE = "en"` is the constant FR-005/SC-002 point to. This is the **only** way any other
  code reads or creates this row; no controller or view queries `SiteLanguageSetting` directly.
  On a fresh install (empty table), the very first call creates the row with `"en"` — this is what
  makes User Story 2 true without a separate migration-time seed.

### Why no `language` enum via a Rails `enum`

A Rails `enum` backed by an integer column would need a separate mapping table or a hardcoded
integer↔symbol table kept in sync with the two-item list FR-003 already states in full; a string
column with an `inclusion` validation says the same constraint once, in the one place it is
enforced, and reads directly as `"en"`/`"fr"` in the database for anyone inspecting it without the
Rails layer.

### Relationships

None. `SiteLanguageSetting` is not referenced by, and does not reference, any other model — it is
read once per request by `ApplicationController` (research.md R2) and written only by
`Admin::DangerZoneController#update`.

### State transitions

Two states, `"en"` and `"fr"`, with no ordering or lifecycle between them — either is reachable from
the other in one `update` (FR-011), and there is no third "unset" state once `.current` has run once
(which happens on the very first request/boot, since every request reads it).

## Locale files (not a database entity, but part of this feature's data)

| File | Status | Content |
|---|---|---|
| `config/locales/en.yml` | extended | every key referenced by `t()`/`t(".…")` across all views, replacing the current `hello: "Hello world"` stub |
| `config/locales/fr.yml` | new | the French translation of every key in `en.yml`, same key structure — **plus** `fr.date.formats` / `fr.time.formats` / `fr.number.format` pinned verbatim to their English values, overriding `rails-i18n`'s own French formats (research.md R8, FR-012) |
| `config/locales/devise.en.yml` | unchanged | already carries this app's overrides of Devise's English strings (007) |
| `config/locales/devise.fr.yml` | new (this app's own file, layered over the `devise-i18n` gem's own French file) | this app's French translations of the same overridden keys — the failure messages, mailer subjects unchanged from the gem's own French set |

`config.i18n.available_locales = [:en, :fr]` and `config.i18n.default_locale = :en` are set in
`config/application.rb`. `config.i18n.fallbacks = true` is set so any key present in `en.yml` but
temporarily missing from `fr.yml` at runtime resolves to its English text rather than raising or
rendering blank (FR-010) — a safety net, not the normal path, since `config.i18n.raise_on_missing_translations = true`
in the test environment (research.md R4) is what keeps `fr.yml` complete before merge.

`devise-i18n` and `rails-i18n` (research.md R5, R8) add their own bundled `devise.fr.yml` and
Rails-framework `fr.yml` to the locale load path; this app's own `config/locales/*.yml` files load
after them, so the app's overrides (including the date/time/number pin above) win for any key both
define.
