# Implementation Plan: Super Admin Role and Exclusive Danger Zone Access

**Branch**: `029-super-admin-role` | **Date**: 2026-09-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/029-super-admin-role/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

"Super admin" is not a new stored fact — it is the account the codebase already tracks uniquely as the
site's bootstrap administrator (013 FR-001/FR-002: `admin: true` with `admin_granted_at: nil`, enforced
by the partial unique index `index_users_on_bootstrap_admin`). This feature names that existing,
already-unique account and gives it one new, exclusive capability (the danger zone) while closing the
gaps that would otherwise let a second admin strip or replace it. `User#super_admin?` is added as a
derived predicate over the existing columns — no migration, no new column, and the clarified retroactive
promotion (FR-013) is true automatically the instant this ships, because today's bootstrap administrator
already satisfies the predicate. A new `require_super_admin!` guard (mirroring `require_admin!`)
protects `Admin::DangerZoneController` and `Admin::AllowedEmailDomainsController`; the Admin menu hides
the "Zone de danger" link from anyone who is not the super admin; `Admin::UsersController#revoke_admin`
gains a guard so the role can never be revoked or transferred.

Account cancellation is the one place this plan's scope grows beyond "add a role": the clarified answer
(spec.md FR-010/FR-014) makes the super admin's own account permanently uncancellable while any other
account exists — stricter than "would this leave zero admins," the rule 015's
`keep_an_administrator_for_the_remaining_accounts` has enforced since FR-016. Tracing that rule's
condition through shows it can never fire again for anyone once the super admin's own permanence holds
(research.md R6): it is removed and replaced outright by a new, super-admin-specific guard, and a
granted (non-super) admin's own account becomes unconditionally cancellable as a direct, intended
consequence. That removal is why this plan's blast radius includes several existing, previously-passing
tests that exercised the old rule (research.md's "R6 fallout" section names each one and what it
becomes).

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged)

**Primary Dependencies**: Rails 8.1.3, Devise 5.0, Turbo via importmap, Tailwind v4 through
`tailwindcss-rails` (unchanged — no new gem, no new Stimulus controller; this feature adds no dynamic
client behavior).

**Storage**: SQLite through Active Record. **No migration.** `super_admin?` is derived from the existing
`admin`/`admin_granted_at` columns and the existing `index_users_on_bootstrap_admin` partial unique
index (015) — reusing the invariant that index already enforces rather than duplicating it in a new
column that could drift out of sync (data-model.md).

**Testing**: Minitest + Rails system tests (Capybara, headless Chrome), axe-core accessibility audits
(unchanged — extends `test/models/user_test.rb`, `test/controllers/admin/danger_zone_controller_test.rb`,
`test/controllers/admin/allowed_email_domains_controller_test.rb`,
`test/controllers/admin/users_controller_test.rb`, `test/controllers/registrations_controller_test.rb`,
`test/system/admin_danger_zone_test.rb`, `test/system/admin_users_test.rb`,
`test/system/admin_user_detail_test.rb`; no new test file is required, since this feature adds behavior
to screens and controllers that already have dedicated suites).

**Target Platform**: Linux server, deployed via Docker + Kamal (unchanged).

**Project Type**: Web — server-rendered Rails monolith, single project (unchanged).

**Performance Goals**: No swap/lock execution path is touched. `super_admin?` is a boolean expression
over two already-loaded columns (`admin? && admin_granted_at.nil?`), not a query — checking it costs
nothing beyond what `require_admin!` already costs. No query scales with the number of registered
accounts.

**Constraints**: Must reuse the existing admin-only refusal message and pattern rather than invent a
second treatment (Constitution III) — `require_super_admin!` reuses
`I18n.t("application.administrators_only")`, the same message a non-admin already sees, so a standard
admin is refused exactly the way spec.md's Edge Cases describe (research.md R3). Every new string this
feature does introduce (the revoke-guard and cancellation-guard refusals) MUST be added to both
`config/locales/en.yml` and `config/locales/fr.yml` (Constitution III, `test/i18n_completeness_test.rb`).
Must not change `Admin::UsersController#index`, its filters, or the Users list's columns (out of scope
per spec.md). Removing `keep_an_administrator_for_the_remaining_accounts`/`LAST_ADMINISTRATOR_MESSAGE`
MUST NOT leave a dangling reference anywhere (`RegistrationsController#destroy`'s fallback, the
`user.messages.last_administrator` locale key, and every test asserting against the removed constant —
research.md's "R6 fallout" section is the checklist).

**Scale/Scope**: No migration. One new model predicate (`User#super_admin?`). One model guard replaced,
not added to (`prevent_super_admin_cancellation` supersedes `keep_an_administrator_for_the_remaining_accounts`
— `LAST_ADMINISTRATOR_MESSAGE` and its locale key are deleted with it). One new controller-level revoke
guard (`Admin::UsersController#revoke_admin`). One new controller method
(`ApplicationController#require_super_admin!`). Two controllers swap `require_admin!` for
`require_super_admin!` (`Admin::DangerZoneController`, `Admin::AllowedEmailDomainsController`). One view
conditional narrows (`shared/_site_menu_items.html.erb`), one view conditional gains a guard
(`admin/users/show.html.erb`'s revoke button). Two new locale key pairs (en/fr), one locale key pair
removed. No new routes, no migration. Eight existing tests across three files are rewritten to match the
replaced rule rather than the removed one (research.md "R6 fallout").

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|---|---|
| I. Code Quality | PASS. `super_admin?` is a single, one-line predicate documented at its definition, mirroring the existing `admin_rights_granted?`. It is defined once on `User` and reused by every caller that needs it — the menu view, `require_super_admin!`, the revoke guard, the cancellation guard — rather than each re-deriving `admin? && admin_granted_at.nil?` independently. No new column duplicates a fact the existing `index_users_on_bootstrap_admin` index already guarantees (research.md R1) — the simpler alternative Constitution I asks for over a second, driftable source of truth. |
| II. Testing Standards | PASS. Every new guard (danger zone access, allowed-domain writes, revoke refusal, cancellation refusal, menu visibility) gets a failing-then-passing test in the existing suites named in Technical Context. `keep_an_administrator_for_the_remaining_accounts` is deleted along with the tests that exercised only it, but every behavioral claim it made is either re-asserted against the new rule (a granted admin can still be deleted; the sole remaining account can still leave) or was itself proven unreachable (research.md R6) — no coverage regresses, a provably dead path is removed instead of tested. |
| III. User Experience Consistency | PASS. Reuses the existing admin-only refusal message (`application.administrators_only`) rather than inventing a second one (research.md R3), and mirrors the existing self-forbidden confirmation/guard shape for the two new refusals (research.md R5, R6). The two genuinely new strings are added to both `config/locales/en.yml` and `config/locales/fr.yml`. |
| IV. Performance Requirements | N/A / PASS. No performance-sensitive path is touched; `super_admin?` is a boolean expression over two already-loaded attributes, not a query. |

No unjustified violations. Complexity Tracking is not needed.

### Post-Design Re-Check (after Phase 1)

Re-evaluated against `research.md`, `data-model.md`, `contracts/super-admin-access.md`, and
`quickstart.md`. All four principles still **PASS**:

- **Principle I** — `data-model.md`'s invariant table and `contracts/super-admin-access.md` fix the
  exact one-line body of `super_admin?` and every place it is called from, with no duplicate
  reimplementation anywhere in the design.
- **Principle II** — `quickstart.md`'s six scenarios each name what a browser can reach versus what
  needs a direct request (Scenario 5 explicitly notes the revoke-by-direct-request case needs a
  controller test, not a system test, since the control is never rendered for that row); `research.md`'s
  "Test strategy" section maps every guard to the specific existing test file that covers it.
- **Principle III** — `contracts/super-admin-access.md` fixes the exact guard bodies, view diffs, and
  the two new locale keys (en/fr) in the same nesting and quoting style as their existing neighbor
  `revoke_admin.self_forbidden`; it also fixes exactly which existing key (`user.messages.last_administrator`)
  is removed rather than left behind.
- **Principle IV** — `data-model.md` confirms `super_admin?` reads only already-loaded columns; no new
  query is added to any request path by `contracts/super-admin-access.md`'s guards.

Design added no new violation and no justified exception; Complexity Tracking remains empty.

## Project Structure

### Documentation (this feature)

```text
specs/029-super-admin-role/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── controllers/
│   ├── application_controller.rb        # + require_super_admin!
│   ├── registrations_controller.rb      # fallback locale key only: last_administrator → super_admin_uncancellable
│   └── admin/
│       ├── danger_zone_controller.rb            # require_admin! → require_super_admin!
│       ├── allowed_email_domains_controller.rb  # require_admin! → require_super_admin!
│       └── users_controller.rb                  # + super-admin guard on #revoke_admin
├── models/
│   └── user.rb                          # + super_admin?, + prevent_super_admin_cancellation (replaces
│                                         #   keep_an_administrator_for_the_remaining_accounts and
│                                         #   LAST_ADMINISTRATOR_MESSAGE, both removed); revoke_admin_rights! unchanged
├── views/
│   ├── shared/_site_menu_items.html.erb # danger zone link gated on super_admin? instead of admin?
│   └── admin/users/show.html.erb        # revoke button hidden for the super admin's own row
└── ...

config/locales/
├── en.yml   # + admin.users.revoke_admin.super_admin_forbidden
│            # user.messages.last_administrator → user.messages.super_admin_uncancellable (replaced)
└── fr.yml   # same two changes, French

test/
├── models/user_test.rb
├── controllers/admin/danger_zone_controller_test.rb
├── controllers/admin/allowed_email_domains_controller_test.rb
├── controllers/admin/users_controller_test.rb
├── controllers/registrations_controller_test.rb
└── system/
    ├── admin_danger_zone_test.rb
    ├── admin_users_test.rb
    └── admin_user_detail_test.rb
```

**Structure Decision**: Single Rails monolith (unchanged from every prior feature in this repo). No new
directories, no new controller, no new model — this feature extends existing files in place, per the
"no unjustified complexity" reading of Constitution I and the fact that every capability it needs already
has a home (`ApplicationController` for the shared guard, `User` for the shared predicate).

## Complexity Tracking

*No violations — table omitted.*
