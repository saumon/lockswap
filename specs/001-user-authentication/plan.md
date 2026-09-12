# Implementation Plan: User Signup and Login

**Branch**: `001-user-authentication` | **Date**: 2026-09-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-user-authentication/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Users can create an account (email + password, 8-char minimum) and log in; a successful login lands
them on the site's homepage, and the session persists up to 30 days until logout. Accounts are
temporarily locked for 15 minutes after 5 consecutive failed login attempts. Technical approach: a
monolithic Ruby on Rails 8.1.3 application (Ruby 3.4.6) using the Devise gem for authentication
(`:database_authenticatable`, `:registerable`, `:rememberable`, `:lockable` modules configured to
match the spec's exact thresholds), SQLite via Active Record for storage, Tailwind CSS v4.3 for
styling, Puma as the app server, and Docker/Kamal for deployment — all per stakeholder mandate.

## Technical Context

**Language/Version**: Ruby 3.4.6

**Primary Dependencies**: Ruby on Rails 8.1.3; Devise (authentication); tailwindcss-rails (Tailwind
CSS v4.3 integration); Puma (app server)

**Storage**: SQLite via Active Record (Rails 8 default adapter; single `users` table for this feature)

**Testing**: Minitest with fixtures (Rails 8 default) for model/controller tests; Rails system tests
(Capybara, bundled by default) for end-to-end signup/login/lockout/redirect flows

**Target Platform**: Linux server, containerized (Docker), deployed with Kamal

**Project Type**: Web application — single Rails monolith (server-rendered views, no separate
frontend/backend split)

**Performance Goals**: Meet spec Success Criteria as the concrete targets — login-to-homepage in
under 10s (SC-002), signup under 2 minutes (SC-001); general Rails page responses targeted at p95 <
300ms under expected low/moderate single-server load (no separate load-testing infra introduced for
this feature's scope)

**Constraints**: SQLite is single-writer/file-based — acceptable at this project's expected scale but
constrains write concurrency; session/lockout state (`remember_created_at`, `failed_attempts`,
`locked_at`) must live on the `users` table rather than a separate session store, per Devise defaults

**Scale/Scope**: Small initial scope — 3 pages (signup, login, homepage), single `User` model, no
multi-tenancy or role differentiation

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Checked against `.specify/memory/constitution.md` v1.0.0:

| Principle | Check | Status |
| - | - | - |
| I. Code Quality | RuboCop (Rails 8 default `rubocop-rails-omakase` config) enforced as a zero-warning lint gate; PR review required before merge; Devise/Rails conventions keep controllers/models single-responsibility | PASS |
| II. Testing Standards (NON-NEGOTIABLE) | Every functional requirement (FR-001..FR-011) gets a Minitest/system-test case before implementation is considered done; CI runs the full suite; Devise's own well-tested modules reduce custom logic that would otherwise need bespoke security tests | PASS |
| III. User Experience Consistency | Single Tailwind-based layout shared by signup/login/homepage; Devise's generic "incorrect email or password" message (FR-006) enforced via Devise's default flash i18n keys, kept consistent app-wide; accessibility (labels, keyboard nav) checked on the three generated views | PASS |
| IV. Performance Requirements | Login/signup are the only performance-sensitive paths in this feature; targets are the spec's own measurable SC-001/SC-002; no unbounded queries introduced (single-record lookups by unique indexed email) | PASS |

No violations identified; Complexity Tracking table is not needed.

**Post-Phase 1 re-check**: Re-evaluated after producing research.md, data-model.md, contracts/, and
quickstart.md. The concrete design (Devise module configuration, `tailwindcss-rails` gem choice,
`rubocop-rails-omakase` lint gate, Minitest/system-test coverage per functional requirement)
introduces no new dependency, pattern, or data store beyond what was already assessed above. All
four principles remain PASS; no Complexity Tracking entries required. Performance evidence for
Principle IV is produced by tasks.md T035, which records signup/login timing against SC-001/SC-002
and the p95<300ms target for inclusion in the PR.

## Project Structure

### Documentation (this feature)

```text
specs/001-user-authentication/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── controllers/
│   ├── application_controller.rb
│   ├── registrations_controller.rb # customized Devise registrations (post-signup redirect, FR-001/FR-005)
│   └── home_controller.rb          # authenticated homepage (FR-005, FR-008)
├── models/
│   └── user.rb                     # Devise-enabled Account entity
└── views/
    ├── layouts/
    │   └── application.html.erb    # shared Tailwind layout + sign-out control (FR-009)
    ├── devise/
    │   ├── registrations/          # customized signup form/view
    │   └── sessions/                # customized login form/view
    └── home/
        └── index.html.erb

config/
├── routes.rb                       # devise_for :users + root to home#index
├── initializers/
│   └── devise.rb                   # password_length, remember_for, lockable settings
├── locales/
│   └── devise.en.yml               # generic failure message + actionable signup errors (FR-002/003/006)
├── database.yml                    # sqlite3 adapter
└── deploy.yml                      # Kamal deployment config

db/
├── migrate/                        # users table + Devise trackable/lockable/rememberable columns
└── schema.rb

test/
├── models/
│   └── user_test.rb
├── system/
│   ├── signup_test.rb              # User Story 1 acceptance scenarios
│   ├── login_test.rb               # User Story 2 acceptance scenarios
│   ├── access_control_test.rb      # FR-008/FR-010 redirect rules
│   ├── login_failure_test.rb       # User Story 3 generic-error scenarios
│   └── account_lockout_test.rb     # User Story 3 lockout/cooldown scenario
└── fixtures/
    └── users.yml

Dockerfile
Gemfile
```

**Structure Decision**: Single Rails monolith at the repository root, following standard Rails
conventions (`app/`, `config/`, `db/`, `test/`) rather than a generic `src/` layout — this is a
server-rendered monolith with no separate frontend project, matching the mandated
"Application web Rails monolithique" target.

## Complexity Tracking

No Constitution Check violations were identified; this section is intentionally empty.
