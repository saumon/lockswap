# Implementation Plan: Admin User Detail View

**Branch**: `027-admin-user-detail-view` | **Date**: 2026-09-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/027-admin-user-detail-view/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Admin → Users (013/015/020) gains a `show` destination: a link on each row (not the row itself, per
Clarifications) opens a dedicated, admin-only detail screen for that one account. The screen surfaces
everything the Users list already shows for that row, plus what it does not — the account's standing
locker-search wish or active swap proposal, and its complete sent/received proposal history (reusing
the exact six-column shape `locker_swap_proposals/index.html.erb` already renders for a signed-in
user's own history, extracted into a shared partial rather than duplicated).

Two admin-only writes are added, both scoped to a single account and both reusing existing model
behavior rather than inventing new rules: editing floor/locker through the same
`save(context: :locker_profile_update)` path (and therefore the same swap-lock refusal) the
self-service edit already uses, and cancelling a standing wish through the same "destroy the row"
effect the self-service "Cancel wish" action already has, gated behind an explicit confirmation step
(Clarifications). Both writes record which administrator performed them and when, in two new
independent provenance pairs on `users` — the same shape already kept for who granted administrator
rights and when (015).

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged)

**Primary Dependencies**: Rails 8.1.3, Devise 5.0, Turbo/Stimulus via importmap, Tailwind v4 through
`tailwindcss-rails` (unchanged — no new gem, no new Stimulus controller: this feature adds no dynamic
client behavior beyond the `data-confirm`/`data-turbo-confirm` dialog the Grant-admin-rights control
on this same screen already uses).

**Storage**: SQLite through Active Record. **One migration**: two new independent nullable provenance
pairs on `users` — `locker_edited_by_id`/`locker_edited_at` and
`search_cancelled_by_id`/`search_cancelled_at` — mirroring the existing
`admin_granted_by_id`/`admin_granted_at` pair (015) exactly, including nullify-on-delete for both
`_by` foreign keys (an admin's account being later cancelled must not erase the fact that they once
acted, same reasoning as 015 FR-019).

**Testing**: Minitest + Rails system tests (Capybara, headless Chrome), axe-core accessibility audits
(unchanged — extends the existing suites, adds one model test file (the two new provenance pairs and
their nullify-on-delete behavior), one controller test file per new controller, and one system test
file for the detail screen).

**Target Platform**: Linux server, deployed via Docker + Kamal (unchanged).

**Project Type**: Web — server-rendered Rails monolith, single project (unchanged).

**Performance Goals**: No swap/lock execution path is touched by this feature's writes (editing
floor/locker still runs through the identical, already-measured `locker_profile_update` validation
path; cancelling a search still runs through the identical `LockerWish#destroy`). The detail screen
itself is a single-record read: one `User` row plus its proposal history, bounded by that one
account's own proposal count — not the site's total user or proposal count — so no query scales with
the number of registered accounts the way the Users list's own queries are already bounded
(research.md R5 covers the exact query shape).

**Constraints**: Must reuse the screen's existing card/table/badge/`detail-value-empty`/confirm-dialog
vocabulary and the pencil-icon disclosure pattern (009) rather than invent a parallel one
(Constitution III) — no new UI pattern is introduced by this feature. Must stay within the site's
single 48rem breakpoint (`test/stylesheet_breakpoint_test.rb`, 012 FR-018). Must not touch the
existing "Admin" badge, "grant administrator rights" control, filters, or row order on the Users list
itself (013/015/020) beyond adding the one new per-row link (FR-001).

**Scale/Scope**: One migration (two provenance pairs), two new columns' worth of model surface on
`User` (attributes + two `belongs_to` associations), one new controller action
(`Admin::UsersController#show`), two new single-action controllers
(`Admin::UserLockerProfilesController#update`, `Admin::UserLockerWishesController#destroy`), three new
routes, one new view (`admin/users/show.html.erb`) plus small partials for the pencil-icon editor and
the audit-provenance line, one extracted shared partial for the six-column proposal-history table (used
by both this screen and the existing `locker_swap_proposals/index.html.erb`, which is edited to use
it rather than duplicating its markup), one new link added to `admin/users/index.html.erb`, one new
model test file, two new controller test files, one new system test file.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|---|---|
| I. Code Quality | PASS. The floor/locker edit and the swap-lock refusal are not reimplemented — the new controller calls the exact same `User#save(context: :locker_profile_update)` the self-service controller calls, on the viewed account instead of `current_user`. The six-column proposal-history table is extracted into one shared partial instead of being duplicated between the self-service history screen and this one — duplicating it would be exactly the "duplicated logic... refactored rather than repeated" case the principle names. Each new controller (`Admin::UserLockerProfilesController`, `Admin::UserLockerWishesController`) has the single responsibility its self-service sibling (`LockerProfilesController`, `LockerWishesController`) already established for the analogous concern. |
| II. Testing Standards | PASS. Every new requirement gets a failing-first test at the level that can reach it: a model test for the two new provenance pairs (set on success, left alone on an unrelated self-service edit, nullified when the acting admin's own account is later cancelled — mirroring 015's `admin_granted_by` test); a controller test per new action (admin-only guard, account-gone handling, validation refusal incl. the swap-lock case, confirmation-gated cancellation, provenance recorded on success); a system test for the detail screen (row link, all displayed sections, the pencil-icon edit round-trip, the confirm-then-cancel round-trip, non-admin/signed-out refusal) plus an accessibility audit of the new screen. |
| III. User Experience Consistency | PASS. Every visual/interaction element reused verbatim: `card`/`data-table`/`badge`/`detail-value-empty` (008/020), the `<details>` pencil-icon disclosure (009), the `data-confirm`/`data-turbo-confirm` pattern already on this same screen's "Grant admin rights" control (015), and the swap-lock refusal message the user already sees on their own edit (`user.messages.locked_by_swap`). No new pattern is introduced, so this PR needs no consistency justification beyond citing the four precedents above. Every new string goes through Rails I18n in both locale files (Constitution III's i18n bullet), enforced unchanged by `test/i18n_completeness_test.rb`. |
| IV. Performance Requirements | PASS. No swap/lock execution path is touched. The detail screen's proposal-history query is bounded by the single viewed account's own `sent_swap_proposals`/`received_swap_proposals` counts (mirrors the self-service history action exactly, including its documented reason for two queries unioned in Ruby rather than one `OR` — research.md R5), not by the site's total account or proposal count. No new per-row query is introduced anywhere, including on the Users list, which gains exactly one static link per row and no new column or query. |

No unjustified violations. Complexity Tracking is not needed.

### Post-Design Re-Check (after Phase 1)

Re-evaluated against `research.md`, `data-model.md`, `contracts/admin-user-detail.md`, and
`quickstart.md`. All four principles still **PASS**:

- **Principle I** — `data-model.md` records the exact two provenance pairs and why they are
  independent of each other and of `admin_granted_by`/`admin_granted_at` (three separate facts about
  an account, not one generalized "last touched by an admin" log); `research.md` R4 records the
  proposal-history partial extraction and which existing view is edited to use it instead of keeping
  its own copy.
- **Principle II** — `research.md` names the file and level for every requirement, including that the
  existing `test/system/admin_users_test.rb` and `test/system/locker_swap_proposal_history_test.rb`
  (or equivalent existing suite covering `locker_swap_proposals/index.html.erb`) are extended/asserted
  unchanged rather than replaced, which is the regression evidence that neither the new row link nor
  the partial extraction disturbed either existing screen.
- **Principle III** — `contracts/admin-user-detail.md` fixes the DOM ids and confirmation-dialog
  copy for the new screen, matching the vocabulary named above exactly, so a regression cannot satisfy
  a test selector while presenting a different pattern.
- **Principle IV** — `data-model.md` and `research.md` R5 state the exact query shape expected for the
  detail screen's proposal history (two bounded queries, unioned in Ruby — not one `OR`), which the new
  controller test asserts directly, mirroring the existing self-service history action's own query
  shape.

Design added no new violation and no justified exception; Complexity Tracking remains empty.

## Project Structure

### Documentation (this feature)

```text
specs/027-admin-user-detail-view/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/            # Phase 1 output (/speckit-plan command)
│   └── admin-user-detail.md
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── controllers/
│   └── admin/
│       ├── users_controller.rb                 # +show action (existing index/grant_admin unchanged)
│       ├── user_locker_profiles_controller.rb   # NEW — #update, admin-on-behalf-of edit
│       └── user_locker_wishes_controller.rb     # NEW — #destroy, admin-on-behalf-of cancel
├── models/
│   └── user.rb                                  # +locker_edited_by/at, +search_cancelled_by/at
├── views/
│   ├── admin/
│   │   └── users/
│   │       ├── index.html.erb                   # +one link per row to the new detail screen
│   │       ├── show.html.erb                     # NEW — the detail screen
│   │       ├── _locker_profile_editor.html.erb    # NEW — pencil-icon disclosure, admin variant
│   │       └── _search_status.html.erb            # NEW — wish / active-proposal / neither
│   └── locker_swap_proposals/
│       ├── index.html.erb                        # edited to render the extracted partial
│       └── _history_table.html.erb                # NEW — extracted, shared with the detail screen
└── assets/tailwind/application.css                # no new component expected (research.md R2)

config/
├── routes.rb                                     # +show, +nested locker_profile/locker_wish routes
└── locales/
    ├── en.yml                                     # +admin.users.show.*, +confirm/notice copy
    └── fr.yml                                     # same keys, French

db/
└── migrate/
    └── <timestamp>_add_admin_action_provenance_to_users.rb   # NEW

test/
├── controllers/
│   └── admin/
│       ├── user_locker_profiles_controller_test.rb   # NEW
│       └── user_locker_wishes_controller_test.rb      # NEW
├── models/
│   └── user_test.rb                              # + provenance pair assertions
└── system/
    └── admin_user_detail_test.rb                  # NEW
```

**Structure Decision**: Single Rails monolith (unchanged). The two new writes each get their own
single-action controller under `app/controllers/admin/`, mirroring how the self-service equivalents
(`LockerProfilesController`, `LockerWishesController`) are already split by concern rather than folded
into a shared controller — `Admin::UsersController` itself gains only the read (`show`), keeping its
existing single responsibility (013's comment: "routes to index and a single named action rather than
a full resource") extended by exactly one more read action, not diluted by two on-behalf-of writes.

## Complexity Tracking

*No violations to justify — table intentionally omitted.*
