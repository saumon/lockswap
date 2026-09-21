# Phase 0 Research: Site Language Setting (French/English)

**Feature**: [spec.md](./spec.md) | **Branch**: `025-multilingual-support` | **Date**: 2026-09-21

Six questions stood between the clarified spec and a design. Today, no view in this application calls
`I18n.t`/`t()` anywhere — every English string is written directly into its ERB template, and
`config/locales/en.yml` holds only the Rails-generated `hello: "Hello world"` stub. Devise's own
messages are the one exception: `config/locales/devise.en.yml` already carries LockSwap's
overrides of Devise's built-in English strings (007's uniform "Invalid email or password.", etc.).
That is the starting point every decision below has to account for.

## R1 — How the current language is persisted

**Decision**: A new table, `site_language_settings`, holding exactly one row, with a `language`
column constrained to `"en"`/`"fr"` — not a column on `users`, not a generic `key`/`value` `Setting`
table.

**Rationale**: 016's R1 rejected a generic `Setting` table because nothing in that feature needed more
than one value and a generic key/value layer would have existed for a problem the spec did not ask it
to solve. That reasoning still applies here for the *shape* of storage (skip the generic layer) but not
for the *table*: the spec's own Key Entities section names "Site Language Setting" as a single,
site-wide value distinct from `AllowedEmailDomain`, so it gets its own small table named for what it
holds, the same way `allowed_email_domains` was named for what it holds rather than `danger_zone_settings`.
Singleton-ness is enforced the way this codebase already enforces other invariants that a plain
column type cannot — a model-level `validate` (see data-model.md) — rather than trusted to callers.

**Alternatives considered**:

- *A column on some existing model (e.g. `User#preferred_language`).* Rejected outright by FR-004 and
  the Clarifications answer: the setting is explicitly site-wide, not per-user, and no `User` row is
  guaranteed to exist (a signed-out visitor still sees the site in the configured language).
- *A generic `key`/`value` `Setting` table.* Rejected for the same reason 016 rejected it: it is a layer
  with no second user in this codebase, solving a "we might need more settings later" problem the spec
  does not ask for.
- *`Rails.application.config.x` or an environment variable.* Rejected: FR-001/FR-011 require an
  administrator to change the value from the Danger Zone screen and have it persist without a
  redeploy; environment variables and boot-time config are not writable from a running request.

## R2 — How the configured language takes effect on every request

**Decision**: `ApplicationController` wraps every action in `I18n.with_locale(SiteLanguageSetting.current.language) { ... }`
via an `around_action`, rather than assigning `I18n.locale =` directly.

**Rationale**: FR-008 requires a saved change to reach every user by their next page load, with no
per-user action — reading the current value fresh on every request, with no session/cookie/per-user
cache of it, is what makes that true by construction. `I18n.with_locale` (block form) is deliberate
over a bare assignment: Puma serves requests on a thread pool, and `I18n.locale=` mutates a
thread-local for the rest of that thread's life, including whatever unrelated request that thread
picks up next if the assignment is never reset. The block form scopes the change to exactly the
current request and restores the prior value afterward even if an exception is raised partway through,
so one request can never leak its language into another.

**Alternatives considered**:

- *`I18n.locale = ...` set once, relying on Rails' own per-request locale reset.* Rejected: Rails does
  not reset `I18n.locale` between requests on its own (that is exactly what `ActionController::Base`'s
  own missing default-locale guarantee does not cover) — this is the documented reason Rails guides
  recommend the block/around-filter form for anything read from outside the request itself.
- *A cookie or session-stored locale per browser.* Rejected by the Clarifications-adjacent Assumption
  that there is no per-user override; a site-wide setting is read the same way for everyone, signed in
  or not.

## R3 — Caching the current setting

**Decision**: No caching layer. `SiteLanguageSetting.current` performs one indexed `SELECT ... LIMIT 1`
per request, the same cost class as the session/user lookup Devise already performs on every request.

**Rationale**: Constitution IV bars unbounded loops and unbounded queries on critical paths, not every
query — this one is bounded to exactly one row by definition (R1's singleton guarantee) and is not on
the swap/lock execution path the constitution is protecting. Adding a cache (Rails.cache, a class
variable, etc.) would introduce an invalidation problem — the very risk FR-008 exists to avoid — to
save a query cheaper than the request's own database connection checkout.

**Alternatives considered**:

- *Memoize in a class variable, invalidated in the `update` action.* Rejected: correct only as long as
  every process that can change the value also invalidates every other process's copy; with more than
  one Puma worker this either needs a broadcast mechanism (real complexity for a one-row `SELECT`) or
  silently reintroduces the "some users see the old language" bug FR-008 forbids.

## R4 — Translating the interface: key convention and coverage

**Decision**: Adopt Rails' standard lazy-lookup convention — `t(".key")` inside a view resolves against
that view's own path (e.g. `t(".title")` in `app/views/admin/danger_zone/show.html.erb` resolves
`admin.danger_zone.show.title`) — and require every string currently hardcoded in a `.erb` file to move
behind a `t()`/`t(".…")` call with a matching entry added to both `config/locales/en.yml` and
`config/locales/fr.yml`. `config/environments/test.rb` additionally sets
`config.i18n.raise_on_missing_translations = true`, which catches an entirely **unextracted** string —
a `t()` call whose key exists in *no* locale at all, which is what the suite hits by default since most
tests run under `I18n.default_locale` (`:en`).

**Rationale**: This is the only way to satisfy FR-006/FR-007/SC-003 given the codebase's current state
— there is no partial shortcut, since every hardcoded string is by definition not following the
configured language. Lazy lookup is Rails' own recommended convention specifically because it keeps a
key colocated with its one call site, which matters here: with ~34 view templates each needing full
extraction, a flat/global key namespace would need a naming scheme invented from scratch, while lazy
lookup gets one for free from the file structure that already exists.

`raise_on_missing_translations` is **not**, on its own, a French-completeness check: with
`config.i18n.fallbacks = true` (data-model.md), a key present in `en.yml` but never added to `fr.yml`
resolves silently through the fallback chain and raises nothing, under any locale — so it would not
catch an incomplete French translation, only a completely missing key. R9 covers the dedicated check
this feature actually needs for that.

**Alternatives considered**:

- *Translate only new/changed views going forward, leave existing ones hardcoded.* Rejected: fails
  SC-003 ("100% of site-authored interface text ... matches the currently configured site language")
  outright and leaves permanently-English islands on a French-configured site.
- *A flat/global key namespace (e.g. `en.strings.some_label`) instead of lazy lookup.* Rejected: with
  ~34 view templates each needing full extraction, a flat namespace would need a naming scheme invented
  from scratch, while lazy lookup gets one for free from the file structure that already exists.

## R5 — Devise's own strings (sign in, sign up, password, confirmation, failures)

**Decision**: Add the `devise-i18n` gem (the community-maintained translation pack for Devise, shipping
a `config/locales/devise.fr.yml`) as a new dependency, then re-apply this application's existing
LockSwap-specific overrides — the ones already sitting in `config/locales/devise.en.yml` for
`failure.invalid`, `failure.not_found_in_database`, etc. — translated to French, in a new
`config/locales/devise.fr.yml.erb`-free override placed after the gem's own file in the locale load
path (Rails loads all of `config/locales/**/*.yml`; this app's own override file is the one that
already exists for English and gains a French twin).

**Rationale**: Devise ships only an English locale file out of the box; hand-translating roughly forty
Devise-internal keys (confirmations, registrations, passwords, unlocks, session timeouts, mailer
subjects) inside this application would duplicate work a maintained, widely-used gem already does
correctly and keeps current as Devise itself changes. The handful of keys this app has already
overridden for its own uniform-failure-message policy (007) still need this app's own French version —
the gem's defaults are the baseline for everything else, not a replacement for a deliberate product
decision already made once in English.

**Alternatives considered**:

- *Hand-write `devise.fr.yml` from scratch.* Rejected: ~40 keys covering flows this feature does not
  otherwise touch (mailer subjects, unlock instructions, timeout messages) is a translation project of
  its own, with no domain expert already in this codebase to word it as carefully as devise-i18n's
  maintained set already has been.

## R6 — Where the control lives and how it is submitted

**Decision**: Extend the existing `Admin::DangerZoneController#show` with a sibling `#update` action —
`resource :danger_zone, only: [:show, :update]` — rather than a new controller. The screen gains one
more field group above the existing allowed-domains section: a `select` (French/English) inside a
`form_with model: @site_language_setting, url: admin_danger_zone_path, method: :patch`, using the
`.field`/`.field-label`/`.field-input` classes the domain form already uses (the app's first `select`
element, but not its first form field — no new visual pattern is introduced, per Constitution III).

**Rationale**: 016's R3 split the screen (`DangerZoneController`) from the resource it manages
(`AllowedEmailDomainsController`) because `AllowedEmailDomain` is its own collection with its own
identity — many rows, each independently addressable. `SiteLanguageSetting` is the opposite shape: one
value, not a list, and it *is* what the Danger Zone screen's other half of state describes — closer to
how a single settings form updates itself than to a nested resource. Giving the screen its own
`#update` rather than inventing a second single-purpose controller for a one-field, one-row model
avoids the accidental-REST smell 016 explicitly steered away from in the other direction.

**Alternatives considered**:

- *A separate `Admin::SiteLanguageSettingsController`.* Considered for symmetry with
  `AllowedEmailDomainsController`, but rejected: that controller earns its existence by owning
  many independently created/destroyed rows; this one action updates the one row `SiteLanguageSetting.current`
  already guarantees exists, which is exactly the shape `DangerZoneController#show` already reads.

## R7 — The `<html lang>` attribute

**Decision**: `app/views/layouts/application.html.erb`'s hardcoded `<html lang="en">` becomes
`<html lang="<%= I18n.locale %>">`.

**Rationale**: This is a one-line, low-risk change directly implied by "impacte tout le site" — the
`lang` attribute is itself site-authored metadata describing the page's language, not user content, and
leaving it hardcoded to `"en"` while every visible label switches to French would misinform assistive
technology (mismatched `lang` causes screen readers to mispronounce the very French text this feature
produces), which Constitution III already requires this application to get right for any user-facing
change.

## R8 — Framework-level messages (validation defaults, "N errors prohibited this record") and the date-format conflict they create

**Decision**: Add the `rails-i18n` gem (the community-maintained French — and every other locale's —
translation pack for Rails' own bundled strings: `activerecord.errors.messages.*`,
`errors.messages.not_saved`, `activerecord.models.*`, `activerecord.attributes.*`, and more) as a
second new dependency, alongside `devise-i18n`. Immediately after adding it, `config/locales/fr.yml`
explicitly pins `fr.date.formats`, `fr.time.formats`, and — discovered only by testing the pin against
`rails-i18n`'s actual French file, not merely reading it — `fr.date.day_names`/`abbr_day_names`/
`month_names`/`abbr_month_names` to the exact same values already in effect under `:en` (Rails' own
built-in English defaults for `format: :long`, the only format this app uses), overriding whatever
French date/time strings `rails-i18n` ships for those keys specifically. The name arrays matter because
`%B`/`%A`/`%b`/`%a` inside a `strftime` format string are resolved from them, not from the format
string alone — pinning `date.formats.long` to the English pattern still produced `"septembre 21, 2026"`
until the name arrays were pinned too, confirmed with `I18n.with_locale(:fr) { I18n.l(time, format:
:long) }` before and after.

**Rationale**: Three of this application's model validations declare no custom `message:` (`User#floor`,
`AllowedEmailDomain#domain`'s `presence:`, `LockerWish#floor`), so their errors resolve through
ActiveModel's own default message keys (`errors.messages.blank`, etc.) — and the shared
`devise/shared/_error_messages.html.erb` partial (reused by every form on the site per 016's own
precedent, including this feature's new Danger Zone form) renders `I18n.t("errors.messages.not_saved",
...)` and `resource.class.model_name.human`, none of which this application defines a French
translation for on its own. Hand-authoring a French counterpart for every generic Rails/ActiveModel
key any current or future validation might reach is an open-ended, easy-to-miss list; `rails-i18n` is
the maintained, standard answer to exactly this problem, the same class of reasoning R5 used for
Devise's own strings.

Pulling in a general Rails locale pack, however, also imports its `date`/`time`/`number` sections —
and this application already calls `l(record.created_at, format: :long)` in eight places (the Danger
Zone domain list, swap-proposal timestamps, the admin user directory's "Joined"/"Granted on" columns).
`I18n.l` resolves its format string from the *current* `I18n.locale`, so without this override,
switching the site to French would silently reformat every one of those dates to `rails-i18n`'s French
convention — directly reopening the question the Clarifications session already closed (2026-09-21:
dates and numbers keep one fixed format regardless of language) and violating FR-012. Rails loads an
app's own `config/locales/**/*.yml` after any gem's locale files for the same locale, and the Simple
backend deep-merges by key — so this app's `fr.yml` entries for `date.formats`/`time.formats` are
guaranteed to be the ones actually in effect, without needing to touch or fork the gem's file.
`number.format` is pinned defensively for the same reason even though nothing in the app currently
calls a `number_to_*` helper — cheap insurance against the same class of regression the moment one is
added.

**Alternatives considered**:

- *Hand-write only the handful of generic keys this app's four unmessaged validations happen to reach
  today (`errors.messages.blank`, `errors.messages.inclusion`, `errors.messages.not_saved`, the three
  affected `activerecord.attributes.*`/`activerecord.models.*` entries).* Rejected: correct today, but
  silently incomplete the next time anyone adds a `validates` call without a custom `message:` —
  exactly the kind of gap `raise_on_missing_translations` (R4) cannot catch, because ActiveModel's
  *English* default would still silently satisfy the lookup; only French would be missing, and nothing
  in the test suite runs the full suite under the French locale.
- *Add `rails-i18n` without overriding `date`/`time`, accepting localized date formats in French mode.*
  Rejected outright: contradicts the Clarifications session's explicit answer and FR-012 verbatim.

## R9 — Verifying French completeness on its own terms, and not repeating 016's fixture lesson

**Decision**: Two small additions, both added during `/speckit-analyze` remediation.

First, a dedicated test, `test/i18n_completeness_test.rb`, that reads this app's own locale file pairs
directly off disk and flattens each into a set of dot-path keys.

For `config/locales/en.yml`/`fr.yml`, it asserts the English file's key set is a subset of the French
file's (excluding the `date`/`time`/`number` keys R8 deliberately pins to English-only values in
`fr.yml`).

For `config/locales/devise.en.yml`/`devise.fr.yml`, a plain subset check turned out to be the wrong
check, discovered by actually running it during implementation: `devise.en.yml` mostly *restates*
Devise's own stock English strings verbatim (mailer subjects, `passwords.*`, `registrations.*`,
`sessions.*`, `unlocks.*`, `omniauth_callbacks.*`, most of `errors.messages.*`) — only a handful of
keys are genuine LockSwap overrides (007's uniform failure messages, 014's `password_confirmation`
wording, the custom `User` validation messages, `errors.messages.not_saved`'s pluralization). A
restated-but-unchanged key does not need this app's own French translation, because `devise-i18n`
(R5) already speaks French for it — only the genuinely-overridden keys are this app's responsibility,
and only those are what `devise.fr.yml` contains. So the devise check treats a key as satisfied if it
appears in *either* `devise.fr.yml` or `devise-i18n`'s own bundled `rails/locales/fr.yml` (read from
`Gem.loaded_specs.fetch("devise-i18n").gem_dir`), rather than requiring this app to re-author strings
the gem already owns.

Both checks stay independent of `I18n.backend`, `raise_on_missing_translations`, and fallback behavior
— they diff files directly, not the merged runtime translation set (which would also pull in
`rails-i18n`'s own upstream file for the main pair, a gem whose completeness is not this test's
concern).

Second, no `test/fixtures/site_language_settings.yml` file is added, for the same reason 016's R5
added none for `allowed_email_domains`: `test_helper.rb` declares `fixtures :all`, so any fixture file
placed under `test/fixtures/` loads for **every** test in the suite unconditionally. A seeded
`site_language_settings` row would silently fix the language every test in the application runs under
— including tests written long before this feature existed — and would specifically defeat T044's
"an empty table defaults to English" assertion. Tests that need a specific language set it explicitly,
inline: `SiteLanguageSetting.current.update!(language: "fr")`.

**Rationale**: R4's `raise_on_missing_translations` answers "was this string extracted at all?" but
cannot answer "is the French translation actually present?", because `config.i18n.fallbacks = true`
makes a French-missing/English-present key resolve silently under any locale (see R4's revised
Decision). Without a check that diffs the two files directly, an incomplete `fr.yml` — a key
translated to English only — would ship undetected by anything in this feature's test suite, which
would otherwise leave SC-003 ("100% of site-authored interface text ... matches the currently
configured language") unverified for any view the one French-mode system test (T043) does not happen
to visit. Reading the files directly, rather than `I18n.backend`'s merged translation set, keeps the
test scoped to exactly what this feature is responsible for authoring.

**Alternatives considered**:

- *Run the entire existing test suite twice, once under each locale (e.g. via a test-environment
  matrix or a global `around` hook wrapping every test in both locales).* Rejected: turns every future
  test run in this application slow and doubles CI time to answer a question a direct two-file key diff
  answers in milliseconds, and would still only catch views that some existing test happens to render —
  the same incidental-coverage problem this decision exists to avoid.
- *Rely on `I18n.backend.send(:translations)` (the full merged runtime set) instead of reading the YAML
  files directly.* Rejected: would also assert on `devise-i18n`/`rails-i18n`'s own bundled locale files,
  which this application does not own and should not be failing its suite over.
