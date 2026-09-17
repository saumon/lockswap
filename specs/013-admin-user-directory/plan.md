# Implementation Plan: Admin Role and User Directory

**Branch**: `013-admin-user-directory` | **Date**: 2026-09-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/013-admin-user-directory/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

The first account ever registered is marked administrator at the moment it is created, persisted as
a durable fact on that one `User` row rather than computed on the fly — so it survives every later
change and is never recomputed if that account is deleted (FR-002, FR-011). The administrator alone
sees an "Admin" entry in the existing signed-in navigation, which opens onto a "Users" destination
under it; every other account's navigation is untouched. "Users" is a new read-only, admin-only page
listing every registered account (oldest first, the administrator's own row carrying an explicit
"Admin" label), guarded the same way the rest of the site already guards signed-in-only content: a
server-side check that refuses the request outright, not just a hidden link.

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged)

**Primary Dependencies**: Rails 8.1.3, Devise (unchanged — no new gem needed for this feature)

**Storage**: SQLite through Active Record (unchanged) — adds one `admin:boolean` column to the
existing `users` table

**Testing**: Minitest + Rails system tests (Capybara, headless Chrome), axe-core accessibility audits
(unchanged — this feature extends the existing suites rather than introducing a new one)

**Target Platform**: Linux server, deployed via Docker + Kamal (unchanged)

**Project Type**: Web — server-rendered Rails monolith, single project (unchanged)

**Performance Goals**: No new latency-sensitive path; the Users listing is a single bounded query
per request, not a swap/lock execution path

**Constraints**: Must fit the existing single-breakpoint responsive rule (012, enforced by
`test/stylesheet_breakpoint_test.rb`) and reuse the site's existing `<details>` disclosure pattern
for the nested "Admin → Users" entry rather than introducing a new interaction pattern or any
JavaScript dependency

**Scale/Scope**: One migration (add `admin` to `users`), one model change (bootstrap + guard logic on
`User`), one namespaced controller + view (`Admin::UsersController#index`), one shared nav partial
update, corresponding route and tests — no new top-level project or service

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|---|---|
| I. Code Quality | PASS. The admin bootstrap rule lives on `User` beside its other invariants (locker uniqueness, lock-while-swapping); `Admin::UsersController` is a new, single-purpose, single-action controller rather than added surface on an existing one. No new warnings expected; RuboCop/Brakeman run as usual. |
| II. Testing Standards | PASS. New behavior (bootstrap-on-first-signup, the race case, the nav entry's visibility, the guard on direct access, the listing itself) each gets a failing-first automated test — model, controller, and system level — per Phase 1 design below. |
| III. User Experience Consistency | PASS. The "Admin → Users" entry reuses the existing `<details>` disclosure already used for the site menu itself, the locker editor, the wish panel and the decline form (008/009/012), instead of introducing a new interaction pattern. A refused request reuses the existing flash/notification component (007) rather than a bespoke error page. The new screen is added to the existing per-screen accessibility and responsive-viewport sweeps rather than left uncovered. |
| IV. Performance Requirements | PASS, with a scoped, documented deferral. The Users listing is a single `User.order(:created_at)` query with no per-row queries — not an unbounded loop. Constitution IV asks that a result set able to grow without bound be paginated, batched, or streamed; the spec's own Assumptions section (see spec.md) deliberately defers pagination until the registered-account count makes it matter, since this is an internal, single-company employee list. This is the explicit, written exception the Governance section asks for, recorded here and in the spec rather than bypassed silently. |

No unjustified violations. Complexity Tracking is not needed beyond the Performance note above.

## Project Structure

### Documentation (this feature)

```text
specs/013-admin-user-directory/
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
│   └── admin/
│       └── users_controller.rb        # NEW — GET /admin/users (FR-006..FR-010, FR-012)
├── models/
│   └── user.rb                        # MODIFIED — admin bootstrap + race guard (FR-001, FR-002, FR-011)
└── views/
    ├── admin/
    │   └── users/
    │       └── index.html.erb         # NEW — the Users list (FR-006, FR-007, FR-010, FR-012)
    └── shared/
        └── _site_menu_items.html.erb  # MODIFIED — the Admin → Users entry (FR-003, FR-004, FR-005)

config/
└── routes.rb                          # MODIFIED — `namespace :admin do resources :users, only: :index end`

db/
└── migrate/
    └── <timestamp>_add_admin_to_users.rb   # NEW — `admin:boolean default:false, not null`
                                              #        + partial unique index on (admin) where admin = true

test/
├── controllers/
│   └── admin/
│       └── users_controller_test.rb   # NEW — authorization (FR-004, FR-008) + listing (FR-006, FR-007, FR-010, FR-012)
├── models/
│   └── user_test.rb                   # MODIFIED — bootstrap, race case, no reassignment on delete (FR-001, FR-002, FR-011)
├── system/
│   ├── admin_users_test.rb            # NEW — end-to-end US1 + US2
│   ├── accessibility_test.rb          # MODIFIED — add the Users screen to the per-screen audit
│   ├── navigation_test.rb             # MODIFIED — Admin entry present/absent per role
│   └── responsive_test.rb             # MODIFIED — Users screen at phone + desktop width
└── fixtures/
    └── users.yml                      # MODIFIED — one fixture explicitly carries `admin: true`
                                        #             (fixtures bypass `before_create`, see research.md)
```

**Structure Decision**: Single Rails monolith (unchanged). This feature adds one namespaced
controller/view pair under the existing `app/controllers` and `app/views` trees, following the same
`namespace`/`resources` convention already used for `locker_swap_proposals` and `locker_wishes`; it
extends the existing `User` model and the existing shared navigation partial rather than introducing
a new service, project, or directory layout.

## Post-Design Constitution Check

*Re-evaluated after Phase 1 (research.md, data-model.md, contracts/, quickstart.md).*

Design did not introduce anything the initial Constitution Check above did not already account for:
the race condition is resolved with a partial unique index plus a rescue-and-retry, the same
established pattern as the app's existing uniqueness rules (R2); the admin-only guard is one
`before_action` reused from `ApplicationController`, not a new authorization layer (R3); the nested
menu reuses the site's one existing disclosure pattern (R4); and the Users listing stays a single
bounded query with the pagination question explicitly deferred and recorded rather than ignored (R5).
All four principles remain PASS with no new or changed exceptions.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Not applicable — the Constitution Check above found no unjustified violations. The one documented
exception (deferred pagination on the Users list, Principle IV) is scoped and recorded in that
section and in the spec's Assumptions rather than tracked here as unresolved complexity.
