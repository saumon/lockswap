# Implementation Plan: Admin Rights Controls on the User Detail Screen

**Branch**: `028-move-admin-grant-button` | **Date**: 2026-09-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/028-move-admin-grant-button/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

The "Grant admin rights" control (015) moves off `admin/users` (the list) onto `admin/users/:id` (the
detail screen, 027) — the list's Actions column is deleted outright, not left empty. The detail screen
gains a second, new control: "Revoke admin rights," offered on any account that currently holds
administrator rights other than the signed-in administrator's own. Both controls reuse the existing
plain, no-password `data-confirm`/`turbo_confirm` pattern this screen family already has (grant itself,
and 027's "Cancel search"). Revoking is implemented as `User#revoke_admin_rights!`, the direct
counterpart of the existing `#grant_admin_rights!`, clearing `admin`/`admin_granted_at`/
`admin_granted_by` rather than recording a separate "revoked by" fact — the Clarifications session
settled that no revoke audit trail is kept. Self-revoke is refused at the controller
(`Admin::UsersController#revoke_admin`), independent of what the view renders, which is also what
guarantees the site can never reach zero administrators through this feature (spec.md Edge Cases).

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged)

**Primary Dependencies**: Rails 8.1.3, Devise 5.0, Turbo via importmap, Tailwind v4 through
`tailwindcss-rails` (unchanged — no new gem, no new Stimulus controller: this feature adds no dynamic
client behavior beyond the `data-confirm`/`data-turbo-confirm` dialog already used three times on this
screen family — grant on the old list, "Cancel search" on the detail screen, and now revoke).

**Storage**: SQLite through Active Record. **No migration** — reuses the existing `admin`,
`admin_granted_at`, `admin_granted_by_id` columns (015) for both the relocated grant and the new
revoke (data-model.md).

**Testing**: Minitest + Rails system tests (Capybara, headless Chrome), axe-core accessibility audits
(unchanged — extends `test/controllers/admin/users_controller_test.rb`, `test/models/user_test.rb`,
`test/system/admin_users_test.rb`, and `test/system/admin_user_detail_test.rb`; no new test file is
required, since this feature adds behavior to two screens that already have dedicated suites).

**Target Platform**: Linux server, deployed via Docker + Kamal (unchanged).

**Project Type**: Web — server-rendered Rails monolith, single project (unchanged).

**Performance Goals**: No swap/lock execution path is touched. Both actions remain single-record
writes (`find_by(id:)` + one `update!`) exactly as `#grant_admin` already is — no query scales with the
number of registered accounts, and the Users list loses a column rather than gaining one, so its
existing query shape (`Admin::UsersController#index`, three fixed queries regardless of row count) is
unaffected.

**Constraints**: Must reuse the existing confirm-dialog and button vocabulary rather than invent a
second treatment (Constitution III) — no new UI pattern is introduced (research.md R5). Must stay
within the site's single 48rem breakpoint (`test/stylesheet_breakpoint_test.rb`). Must not touch
`Admin::UsersController#index`'s filters, row order, or the columns it still shows (Floor, Locker,
Wish, Role) beyond removing the one Actions column (research.md R6). `grant_confirm`'s copy must no
longer claim the grant "cannot be undone," since revoke makes that false (research.md R7).

**Scale/Scope**: No migration. One new model method (`User#revoke_admin_rights!`). One changed
controller action (`#grant_admin`'s redirect target and dropped `filter_selections` call) and one new
one (`#revoke_admin`) on the existing `Admin::UsersController` — no new controller. One new route
(`revoke_admin` member action) alongside the existing `grant_admin` one. Two views edited
(`admin/users/index.html.erb` loses its Actions column; `admin/users/show.html.erb` gains the grant and
revoke controls, relocated/new). Six i18n keys relocated or added, in both locale files. One private
controller method deleted (`filter_selections`, now dead — research.md R2). Existing test files
extended; no new test file.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|---|---|
| I. Code Quality | PASS. `revoke_admin_rights!` is the direct structural counterpart of the existing `grant_admin_rights!` (same guard-clause/idempotence shape) rather than a divergent new pattern. The now-unused `filter_selections` private method is deleted rather than left as dead code once `#grant_admin` stops calling it (research.md R2) — leaving it would be exactly the "unjustified complexity" the principle asks to refactor away. `#revoke_admin` has the single responsibility its sibling `#grant_admin` already established for this controller; no new controller is introduced where the existing one already fits (015's own reasoning for staying off a general `#update`, narrowed here to admit revoke as its own named action rather than a generic toggle — research.md R1). |
| II. Testing Standards | PASS. Every new/changed requirement gets a failing-first test at the level that can reach it: model tests for `revoke_admin_rights!` (clears all three fields, idempotent on an already-standard account, leaves other accounts untouched); controller tests for `#revoke_admin` (success, self-refusal — both through the interface and by direct request, non-admin refusal, account-gone handling, idempotence) and for `#grant_admin`'s changed redirect target; system tests for both screens (the list shows no Actions column and no grant/revoke control anywhere on it; the detail screen offers exactly the right control for each of the three states — not-admin, admin-other-account, admin-self — with the confirm/decline round-trip for each). |
| III. User Experience Consistency | PASS. Every visual/interaction element reused verbatim: `.btn`/`.btn-secondary`/`.btn-sm`, the `data-confirm`/`data-turbo-confirm` pattern already on this exact screen twice over (grant, "Cancel search"), the existing role-badge/grant-provenance markup untouched in its rendering logic (only its screen location and, on revoke, its disappearance, change). No new UI pattern is introduced, so this PR needs no consistency justification beyond citing the precedents above. Every new or relocated string goes through Rails I18n in both locale files (`config/locales/en.yml`/`fr.yml`), enforced unchanged by `test/i18n_completeness_test.rb`. |
| IV. Performance Requirements | PASS. No swap/lock execution path is touched. Both writes remain single-record, `find_by` + one `update!`, exactly the shape `#grant_admin` already has — no new per-row or per-request query is introduced on either screen, and the list's own three-query shape (`Admin::UsersController#index`) is unaffected by removing a column that held no query of its own. |

No unjustified violations. Complexity Tracking is not needed.

### Post-Design Re-Check (after Phase 1)

Re-evaluated against `research.md`, `data-model.md`, `contracts/admin-user-rights-controls.md`, and
`quickstart.md`. All four principles still **PASS**:

- **Principle I** — `data-model.md` fixes `revoke_admin_rights!`'s exact body (mirrors
  `grant_admin_rights!` line for line in shape) and records that `filter_selections` is deleted, not
  merely left unused; `research.md` R1/R2 record why grant/revoke stay on the existing controller
  rather than spawning a new one.
- **Principle II** — `quickstart.md`'s five scenarios each name the level (system vs. controller test)
  that can actually reach them, including Scenario 3's explicit note that the self-revoke-by-direct-
  request case needs a controller test, not a system test, since the control is never rendered for a
  browser to click.
- **Principle III** — `contracts/admin-user-rights-controls.md` fixes the exact `button_to` markup,
  confirmation copy, and i18n key layout for both controls, matching the vocabulary named above exactly
  — including the specific wording change to `grant_confirm` (drops "cannot be undone") so the shipped
  copy stays truthful once revoke exists.
- **Principle IV** — `contracts/admin-user-rights-controls.md`'s `#revoke_admin` body is the same
  `find_by` + single `update!` shape as `#grant_admin`, asserted directly by the controller tests
  `research.md` and this plan's Testing Standards row both name.

Design added no new violation and no justified exception; Complexity Tracking remains empty.

## Project Structure

### Documentation (this feature)

```text
specs/028-move-admin-grant-button/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/            # Phase 1 output (/speckit-plan command)
│   └── admin-user-rights-controls.md
├── checklists/
│   └── requirements.md
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── controllers/
│   └── admin/
│       └── users_controller.rb       # #grant_admin redirect target + dropped filter_selections;
│                                      # +#revoke_admin; filter_selections private method deleted
├── models/
│   └── user.rb                       # +revoke_admin_rights! (beside grant_admin_rights!)
├── views/
│   └── admin/
│       └── users/
│           ├── index.html.erb        # Actions column (<th>/<td>) removed entirely
│           └── show.html.erb         # +grant control (relocated), +revoke control

config/
├── routes.rb                         # +patch :revoke_admin member route
└── locales/
    ├── en.yml                        # actions_header removed; grant_* moved index→show (reworded);
    │                                  # +show.revoke_*; +revoke_admin.* action namespace
    └── fr.yml                        # same keys, French

test/
├── controllers/
│   └── admin/
│       └── users_controller_test.rb  # grant redirect-target assertions updated; +revoke_admin tests
├── models/
│   └── user_test.rb                  # +revoke_admin_rights! tests
└── system/
    ├── admin_users_test.rb           # grant-control tests removed/replaced with "no Actions column"
    └── admin_user_detail_test.rb     # +grant tests (moved from admin_users_test.rb), +revoke tests
```

**Structure Decision**: Single Rails monolith (unchanged). Both writes stay on `Admin::UsersController`
rather than moving to or gaining a new single-action controller — unlike 027's two on-behalf-of writes
(which each touch a different resource, `LockerProfile`/`LockerWish`, and so got their own controller
each), grant and revoke both mutate the same three columns on the same `User` row that `#grant_admin`
already owns, so they are two named actions on one controller rather than a controller each
(research.md R1). No new controller, no new model, no migration.

## Complexity Tracking

*No violations to justify — table intentionally omitted.*
