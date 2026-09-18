# Implementation Plan: Danger Zone – Allowed Email Domains

**Branch**: `016-danger-zone-email-domains` | **Date**: 2026-09-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/016-danger-zone-email-domains/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

A new administrator-only screen, "Danger Zone", reachable from the existing "Admin" submenu next to
"Users". It manages a new, independent resource — `AllowedEmailDomain`, one row per domain — through
its own small controller (`Admin::AllowedEmailDomainsController#create`/`#destroy`), while the screen
itself is a read-only `Admin::DangerZoneController#show` that lists the current domains and offers the
add form. Both controllers are guarded by the site's existing `authenticate_user!` / `require_admin!`
pair.

The actual gate lives on `User`: a `validate :email_domain_allowed, on: :create` reads every
configured domain (a handful of rows, one query, `pluck`), and — only when at least one exists —
refuses the save unless the submitted email's domain exactly matches one of them (case-insensitive,
no automatic subdomain inclusion, per the Clarifications session). The refusal is added to `:base` so
Devise's existing error partial renders the required exact sentence, "Your email address domain is
not allowed", with no attribute name prepended. An empty table means unrestricted, satisfying FR-004
without a separate "restriction enabled" flag: the presence of any row *is* the restriction.

No other signup behavior changes — the validation is scoped `on: :create`, so it cannot reach any
existing account or any flow other than registration (FR-010).

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged)

**Primary Dependencies**: Rails 8.1.3, Devise 5.0, Turbo/Stimulus via importmap (unchanged — no new
gem; the new screen is a plain server-rendered form, no Turbo Stream or Stimulus controller needed)

**Storage**: SQLite through Active Record (unchanged) — adds one new table, `allowed_email_domains`
(one row per configured domain); no changes to the `users` table

**Testing**: Minitest + Rails system tests (Capybara, headless Chrome), axe-core accessibility audits
(unchanged — extends the existing suites)

**Target Platform**: Linux server, deployed via Docker + Kamal (unchanged)

**Project Type**: Web — server-rendered Rails monolith, single project (unchanged)

**Performance Goals**: No swap/lock execution path is touched. The signup-time check is one `pluck`
query against a table expected to hold a handful of rows at most, not a per-row query against
anything that grows with user count

**Constraints**: Must reuse the site's existing admin-only navigation guard (`require_admin!`) and
form/error-display conventions (`devise/shared/error_messages`, `field`/`field-label`/`field-input`
classes) rather than introduce new ones (Constitution III); must not affect existing accounts or any
flow other than registration (FR-010, spec Assumptions)

**Scale/Scope**: One migration (new table), one model (`AllowedEmailDomain`), one small addition to
`User`, two new controllers, two new routes, one new view, one link added to the existing admin
submenu partial — no new top-level project or service

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|---|---|
| I. Code Quality | PASS. The mutation (`AllowedEmailDomain` create/destroy) and the read (`DangerZone#show`) are split along the same "screen vs. the resource it manages" line the admin namespace already implies; each controller stays single-purpose. The signup gate is one small, named `User` validation beside its other invariants (`locker_details_held_by_active_swap`, the administrator-deletion guard), not a special case bolted onto `RegistrationsController`. |
| II. Testing Standards | PASS. New behavior gets failing-first tests at the level that can reach it: model tests for `AllowedEmailDomain` validations and `User#email_domain_allowed` (including the empty-table "unrestricted" case and the exact-match/case-insensitive/no-subdomain rules); controller tests for the admin-only guard on both new controllers and the add/remove flows; a system test for the full Danger Zone screen and for a refused registration showing the exact error text. |
| III. User Experience Consistency | PASS. The screen reuses the existing card/table/field/button vocabulary from Admin → Users and the locker-profile form, and the existing Devise error partial for validation failures — no new UI pattern is introduced. The "Admin" submenu gains one more entry, in the same disclosure already used for "Users". |
| IV. Performance Requirements | PASS. The signup check is a single bounded `pluck` (row count is administrator-configured, not user-count-scaled); the Danger Zone list query is likewise unbounded-loop-free and not on any swap/lock path. |

No unjustified violations. Complexity Tracking is not needed.

## Project Structure

### Documentation (this feature)

```text
specs/016-danger-zone-email-domains/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output — five decisions
├── data-model.md        # Phase 1 output — the new table, the User validation
├── quickstart.md        # Phase 1 output — manual validation of the acceptance scenarios
├── contracts/
│   └── danger-zone.md   # Phase 1 output — routes, screen contract, registration contract
├── checklists/
│   └── requirements.md  # Spec quality checklist (16/16)
├── spec.md
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── controllers/
│   └── admin/
│       ├── danger_zone_controller.rb          # NEW — #show only
│       └── allowed_email_domains_controller.rb # NEW — #create, #destroy
├── models/
│   ├── allowed_email_domain.rb                 # NEW — domain string, format + uniqueness
│   └── user.rb                                 # + EMAIL_DOMAIN_NOT_ALLOWED_MESSAGE,
│                                                #   #email_domain_allowed (validate on: :create)
└── views/
    ├── admin/danger_zone/show.html.erb         # NEW — list + add form
    └── shared/_site_menu_items.html.erb        # + "Danger Zone" link in the Admin submenu

config/
└── routes.rb   # + resource :danger_zone, only: :show
                 # + resources :allowed_email_domains, only: [:create, :destroy]
                 #   (both inside namespace :admin)

db/
├── migrate/<ts>_create_allowed_email_domains.rb
└── schema.rb

test/
├── models/allowed_email_domain_test.rb                     # format, uniqueness, normalization
├── models/user_test.rb                                     # + email_domain_allowed cases
├── controllers/admin/danger_zone_controller_test.rb         # admin-only guard, listing
├── controllers/admin/allowed_email_domains_controller_test.rb # admin-only guard, create/destroy
├── controllers/registrations_controller_test.rb            # + refused-domain case, exact message
└── system/admin_danger_zone_test.rb                          # NEW — full screen + a11y sweep
                                                                # (deliberately NO fixtures/allowed_email_domains.yml —
                                                                #  test_helper.rb's `fixtures :all` would apply any
                                                                #  configured row to every test in the suite; see
                                                                #  research.md R5)
```

**Structure Decision**: Single Rails project, unchanged. This feature adds one new table/model and one
new admin screen split across two small controllers, following the same `namespace :admin` and
`require_admin!` conventions 013 and 015 already established; no new top-level directory or service.

## Post-Design Constitution Check

Re-checked after Phase 1. Still PASS on all four; one thing worth naming rather than leaving buried in
a diff:

- **Code Quality / Testing**: the empty-table case ("no restriction") is not a separate boolean flag —
  it falls out of `AllowedEmailDomain.pluck(:domain).empty?` being true. This means there is exactly one
  thing to test to cover FR-004 (an empty table) and exactly one thing to test to cover FR-005 (a
  non-empty table), rather than a flag and a list that could theoretically disagree.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations.
