# Implementation Plan: Grant Administrator Rights

**Branch**: `015-grant-admin-rights` | **Date**: 2026-09-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/015-grant-admin-rights/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

An administrator promotes a standard account from a button on its row in the existing Admin → Users
list (013). The button submits a named member action, `PATCH /admin/users/:id/grant_admin`, guarded by
the same `require_admin!` that already guards the listing, and preceded by the site's existing
confirm-before-acting dialog naming the account and stating the grant is permanent. The promoted
account gains rights identical to any other administrator's, and the account row records where those
rights came from — which administrator granted them and when — so provenance survives even the
grantor's own deletion.

The feature turns on one structural change. The `users` table currently carries a partial unique index
that makes a second administrator impossible, and `User#save` depends on it to settle the signup race.
Rather than dropping it and losing 013's guarantee along with its cap, the index is **narrowed** to the
bootstrap case (`WHERE admin = 1 AND admin_granted_at IS NULL`): exactly one account may still claim
rights automatically at first registration, while granted administrators are unlimited. Because
granting is now the only way to gain rights after signup and nothing removes them, cancelling an
account became the only exit — so the last administrator's deletion is refused while other accounts
remain.

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged)

**Primary Dependencies**: Rails 8.1.3, Devise 5.0, Turbo/Stimulus via importmap (unchanged — no new
gem; the confirmation reuses Turbo's existing `data-turbo-confirm`)

**Storage**: SQLite through Active Record (unchanged) — adds two nullable columns to `users`
(`admin_granted_at`, `admin_granted_by_id`) and replaces one partial unique index

**Testing**: Minitest + Rails system tests (Capybara, headless Chrome), axe-core accessibility audits
(unchanged — extends the existing suites)

**Target Platform**: Linux server, deployed via Docker + Kamal (unchanged)

**Project Type**: Web — server-rendered Rails monolith, single project (unchanged)

**Performance Goals**: No swap/lock execution path is touched. The Users listing must stay two queries
regardless of account count: the provenance line reads the grantor through
`includes(:admin_granted_by)` rather than a query per row

**Constraints**: Must reuse the site's existing confirm-before-acting pattern (the "Cancel my account"
button) rather than introduce a modal; must keep the single-breakpoint responsive rule enforced by
`test/stylesheet_breakpoint_test.rb` and the existing table/card duality (012 FR-005); must not break
`User#save`'s bootstrap-race retry, which matches the renamed index by name

**Scale/Scope**: One migration, one model change (two associations, a grant method, a destroy guard),
one new controller action, one route, the Users view, the Devise registrations controller, plus tests
— no new top-level project or service

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|---|---|
| I. Code Quality | PASS. The grant lives as a named member action on the controller that already owns the administrator's view of accounts, matching the `accept`/`decline`/`confirm` shape already used by `locker_swap_proposals` rather than a general update action — which FR-014 forbids existing at all. The grant rule and the deletion guard sit on `User` beside its other invariants. No new dependency; RuboCop and Brakeman run as usual. |
| II. Testing Standards | PASS. Every new behaviour gets a failing-first test at the level that can actually reach it: the controller suite for the refusals, the already-an-administrator no-op and the missing-account case (none of which a browser can reach); the model suite for the grant, the deletion guard and the bootstrap index; the system suite for the confirmation, the button's absence on administrator rows, the provenance line and the accessible name. |
| III. User Experience Consistency | PASS. The confirmation is the same `button_to` + `data-turbo-confirm` construction as "Cancel my account", the site's one existing confirm-before-acting precedent; success and failure reuse the 007 notification component; the promoted row reuses 013's `Admin` badge unchanged. The new control and the refusal message join the existing per-screen accessibility and responsive sweeps rather than being left uncovered. |
| IV. Performance Requirements | PASS. The grant is a single-row update, not a hot path. The one real risk is the listing: reading each administrator's grantor per row would be the unbounded per-row query the principle names, so the controller loads it with `includes`, keeping the page two queries whether it lists three accounts or three hundred. 013's deferral of pagination is inherited unchanged and remains recorded in the spec's Assumptions. |

No unjustified violations. Complexity Tracking is not needed.

## Project Structure

### Documentation (this feature)

```text
specs/015-grant-admin-rights/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output — six decisions, R1 is the structural one
├── data-model.md        # Phase 1 output — the two columns, the narrowed index, the three states
├── quickstart.md        # Phase 1 output — manual validation of the acceptance scenarios
├── contracts/
│   └── grant-admin.md   # Phase 1 output — route, control, row and cancellation contracts
├── checklists/
│   └── requirements.md  # Spec quality checklist (16/16)
├── spec.md
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── controllers/
│   ├── admin/users_controller.rb     # + #grant_admin; #index gains includes(:admin_granted_by)
│   └── registrations_controller.rb   # + #destroy override, turning the guard's abort into a flash
├── models/
│   └── user.rb                       # + associations, #grant_admin_rights!, before_destroy guard,
│                                     #   updated ADMINISTRATOR_INDEX_CONFLICT for the renamed index
└── views/
    └── admin/users/index.html.erb    # + grant button per standard row, + provenance in the Role cell

config/
└── routes.rb                         # + member patch :grant_admin on the admin users resource

db/
├── migrate/<ts>_add_admin_grant_provenance_to_users.rb
└── schema.rb

test/
├── controllers/admin/users_controller_test.rb   # refusals, no-op, missing account, query count
├── controllers/registrations_controller_test.rb # the last-administrator refusal
├── models/user_test.rb                          # grant, guard, bootstrap index still holds
├── fixtures/users.yml                           # + one granted-administrator fixture
└── system/admin_users_test.rb                   # confirmation, decline, badge, provenance, a11y
```

**Structure Decision**: Single Rails project, unchanged. This feature adds no new top-level directory:
it extends the `Admin::Users` controller/view pair 013 created, the `User` model, and the Devise
registrations controller the application already subclasses.

## Post-Design Constitution Check

Re-checked after Phase 1. Still PASS on all four, with two things the design surfaced that are worth
naming rather than leaving in a diff:

- **Code Quality**: `User#save`'s rescue identifies the bootstrap-race conflict by matching the index
  name. Renaming the index without updating `ADMINISTRATOR_INDEX_CONFLICT` in the same commit turns a
  lost signup race into a 500 rather than a retry — silent, and only under concurrency. The model test
  for the race must run against the renamed index, not just the migration.
- **Performance**: `includes(:admin_granted_by)` is the whole of Principle IV's demand here, and it is
  one word that a later edit could drop without any visible symptom on a three-row test database. The
  controller test asserts the query count so the promise is enforced rather than remembered.

## Decisions this plan took back to the spec

One. This plan first read FR-016 more narrowly than it was written: the guard protects the accounts
that would *remain*, rather than firing on the sole account of an otherwise empty site. Read
literally, the requirement refused that last cancellation too, which produces a trap rather than a
guard — with no accounts left, 013's bootstrap rule applies again and the very next signup becomes
administrator, so there is nothing to be locked out of.

Rather than leave the plan diverging from the spec, the reading was carried back into the spec itself:
FR-016 now states the condition, SC-007 no longer promises more than the guard delivers, and the Edge
Cases list carries the sole-account case explicitly. Reasoning in full at
[research.md R4](./research.md). The plan and the spec agree; there is no outstanding divergence to
review.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations. The one structural change — narrowing the bootstrap index instead of dropping it —
exists to keep an existing guarantee (013 FR-002) that FR-013 did not ask to remove, and is simpler
than the alternative of re-implementing race safety in Ruby.
