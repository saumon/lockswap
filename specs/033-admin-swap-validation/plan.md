# Implementation Plan: Administrator Validation of Locker Swap Exchanges

**Branch**: `033-admin-swap-validation` | **Date**: 2026-09-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/033-admin-swap-validation/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

The recipient's own "confirm exchange completed" button (004 FR-013,
`LockerSwapProposalsController#confirm` → `LockerSwapProposal#confirm!`) is retired and replaced with a
new admin-only screen that lists every `accepted` proposal — an accepted proposal already *is* "awaiting
validation"; no new status is introduced. From that screen an administrator either validates a listed
exchange (calls the existing `confirm!`, unchanged in what it does: swap the two parties' floor/locker
details, mark `completed`) or refuses it (extends the existing `decline!`, whose guard widens from
`pending?` to `pending? || accepted?` so it can also close out an already-accepted exchange, with no
locker-detail change). Both model methods gain an optional `by:` keyword so the acting administrator can be
recorded (clarified FR-014 audit trail) via one new nullable column,
`locker_swap_proposals.admin_decided_by_id`, following the exact `admin_granted_by_id` /
`locker_edited_by_id` / `search_cancelled_by_id` self-referential-FK-on-`User`-nullify pattern this codebase
already uses three times (013/027). The two clarified decisions (specs.md Clarifications) both fall out of
reusing the existing `accepted` scope as-is: an exchange accepted before this feature shipped is already
`accepted` in the database, so it appears in the new queue with no migration of data or special-case code;
and since neither `confirm!`/`decline!` nor the new controller's `require_admin!` guard checks whether the
signed-in administrator is one of the exchange's own two parties, self-validation is simply what happens
when nothing is added to forbid it — no extra guard to write.

On the user-facing side, `home/_swap_exchange_in_progress.html.erb`'s two-branch view (recipient sees a
button and instructions; requester sees a waiting message) collapses to one unconditional message, because
neither party retains any action once accepted. Four retired locale keys
(`confirm_instructions`/`confirm_button`/`confirming`/`waiting_for_their_confirmation`) are replaced by one
new key carrying the exact French copy the spec quotes, in both `en.yml` and `fr.yml` (Constitution III).
"Échange en cours"/"Exchange in progress" is retired in **both** places it appears, not only the one the
spec quotes: the homepage's `swap_exchange_in_progress.title` and the proposal-history table's own
`locker_swap_proposals.index.exchange_in_progress` badge (shown on the self-service history screen and,
unmodified, on the admin user-detail screen) — the same underlying `accepted?` fact, read from two keys, so
both change together or the two screens contradict each other (research.md R12). The now-unreachable
`locker_swap_proposals.confirm.confirmed` flash key is deleted outright, not reworded.

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged)

**Primary Dependencies**: Rails 8.1.3, Devise 5.0, Turbo via importmap, Tailwind v4 through
`tailwindcss-rails` (unchanged — no new gem; the refusal comment box reuses the existing no-JavaScript
`<details>` disclosure pattern `home/_swap_proposals_received.html.erb` already uses for the recipient's own
decline, so no new Stimulus controller is needed either).

**Storage**: SQLite through Active Record. **One migration**: `locker_swap_proposals` gains a nullable
`admin_decided_by_id` (references `users`, indexed, foreign key), the same shape as the three existing
self-referential admin-attribution columns on `User` (`admin_granted_by_id`, `locker_edited_by_id`,
`search_cancelled_by_id` — 013/027, data-model.md). No column is added for "awaiting validation" — that
state is the existing `accepted` enum value, reused rather than duplicated (Constitution I).

**Testing**: Minitest + Rails system tests (Capybara, headless Chrome), axe-core accessibility audits
(unchanged). New: `test/models/locker_swap_proposal_test.rb` (widened `decline!` guard, `admin_decided_by`
on both `confirm!` and `decline!`), `test/controllers/admin/swap_validations_controller_test.rb` (index
scoping, access control, validate, refuse, the race-condition double-decision case), a new
`test/system/admin_swap_validation_test.rb`. Updated: `test/controllers/locker_swap_proposals_controller_test.rb`
(the removed `#confirm` action), `test/system/locker_swap_proposal_test.rb` and any homepage system test
asserting the retired "Exchange in progress" copy or the confirm button, `test/i18n_completeness_test.rb`
coverage (automatic — it diffs the locale files directly, nothing to hand-maintain).

**Target Platform**: Linux server, deployed via Docker + Kamal (unchanged).

**Project Type**: Web — server-rendered Rails monolith, single project (unchanged).

**Performance Goals**: No swap/lock execution path changes shape — `confirm!`'s transaction (snapshot,
swap, mark completed) is untouched, only gains one extra column write. The new admin list
(`LockerSwapProposal.accepted.includes(:requester, :recipient)`) is naturally bounded: the two partial
unique indexes (`index_swap_proposals_accepted_requester`/`_recipient`) already guarantee at most one
`accepted` row per user in either role, so the list can never exceed roughly half the user count — the same
unbounded-by-construction-but-naturally-small shape the existing, unpaginated `Admin::UsersController#index`
already relies on (Principle IV precedent). Both parties' locker-map zones are resolved with one batched
`LockerMapEntry.zone_names_for(pairs)` call across the whole list (032 research.md R3's pattern), not one
query per row.

**Constraints**: Every new user-facing string (the admin screen's labels, the two retired-then-replaced
homepage strings) MUST be added to both `config/locales/en.yml` and `config/locales/fr.yml` (Constitution
III, `test/i18n_completeness_test.rb`). The admin-only refusal for a non-administrator MUST reuse the
existing `I18n.t("application.administrators_only")` message via `require_admin!`, not a new string
(mirrors 029's `require_super_admin!` precedent — research.md R2). Removing the self-confirm route/action/
view is a breaking change to a user-facing flow and MUST be called out as such (Constitution III) — it is,
in spec.md User Story 3 and this plan's Summary.

**Scale/Scope**: One migration (one column, one index, one foreign key). One model file touched
(`LockerSwapProposal`: widen `decline!`'s guard, add `by:` to `confirm!`/`decline!`, add the
`admin_decided_by` association) plus one `User` association addition for the inverse. One new controller
(`Admin::SwapValidationsController`, three actions). One new view directory
(`app/views/admin/swap_validations/`). One existing controller shrinks by one action
(`LockerSwapProposalsController#confirm` removed). One existing view simplifies
(`home/_swap_exchange_in_progress.html.erb` loses its two-branch button/instructions split). One route
block added, one route removed. One admin nav link added. Two locale files gain the admin screen's strings
and the one replacement key, and lose four retired keys.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|---|---|
| I. Code Quality | PASS. No new proposal status, no new "awaiting validation" concept — `accepted` is reused as-is (research.md R1). `confirm!`/`decline!` are extended in place with an optional `by:` rather than duplicated into admin-specific variants. The retired `#confirm` action, its route, its view branch, and its four now-dead locale keys are deleted outright rather than left behind guarded-but-unreachable. |
| II. Testing Standards | PASS. Every new behavior (widened `decline!` guard, `admin_decided_by` attribution, the three new controller actions, the race-condition double-decision case, the collapsed homepage copy) gets a failing-then-passing test in the files listed under Testing above. The removed `#confirm` action's existing tests are deleted along with it, not left asserting dead code. |
| III. User Experience Consistency | PASS. The admin screen reuses existing components verbatim: `.data-table` (`locker_swap_proposals/_history_table.html.erb`'s shape), the `<details>`-disclosure decline-with-comment pattern (`home/_swap_proposals_received.html.erb`), and `shared/_zone_label` for zone display — no new visual pattern is introduced (contracts/admin-swap-validation.md). Every new/changed string ships in both `en.yml` and `fr.yml`. The breaking change (self-confirm removed) is called out explicitly here and in spec.md rather than discovered later. |
| IV. Performance Requirements | PASS. The admin list is naturally bounded by the existing partial unique indexes (see Performance Goals) and resolves zones in one batched call, matching the existing 032 pattern rather than querying per row. No change to the swap-execution critical path's shape. |

No unjustified violations. Complexity Tracking is not needed.

### Post-Design Re-Check (after Phase 1)

Re-evaluated against `research.md`, `data-model.md`, `contracts/admin-swap-validation.md`, and
`quickstart.md`. All four principles still **PASS**:

- **Principle I** — `data-model.md` fixes `admin_decided_by_id` as the single new column, mirroring the
  three existing self-referential admin-attribution columns exactly; no parallel "resolved by" concept is
  introduced anywhere else. `contracts/admin-swap-validation.md` fixes the exact `confirm!(by:)`/
  `decline!(comment, by:)` signatures, extending rather than replacing the two existing methods.
- **Principle II** — `quickstart.md`'s scenarios cover the browser-reachable flows (validate, refuse with
  and without a comment) and name which case needs a controller test rather than a system test (the
  race-condition "already decided" refusal, since it requires two requests racing rather than anything a
  single browser session can reproduce).
- **Principle III** — `contracts/admin-swap-validation.md` fixes the exact reused component classes
  (`.data-table`, `.tile-disclosure`, `shared/_zone_label`) and the exact locale key names/values, in both
  locales, including the one new key that carries the spec's quoted French text verbatim.
- **Principle IV** — `data-model.md`'s index confirms `admin_decided_by_id` is indexed (consistent with its
  three siblings), and the list query in `contracts/admin-swap-validation.md` is unchanged from the
  Performance Goals shape — no new N+1, no new unbounded scan.

Design added no new violation and no justified exception; Complexity Tracking remains empty.

## Project Structure

### Documentation (this feature)

```text
specs/033-admin-swap-validation/
├── plan.md                              # This file (/speckit-plan command output)
├── research.md                          # Phase 0 output (/speckit-plan command)
├── data-model.md                        # Phase 1 output (/speckit-plan command)
├── quickstart.md                        # Phase 1 output (/speckit-plan command)
├── contracts/
│   └── admin-swap-validation.md         # Phase 1 output (/speckit-plan command)
└── tasks.md                             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
db/
├── migrate/
│   └── <timestamp>_add_admin_decided_by_to_locker_swap_proposals.rb   # new
└── schema.rb                                                          # regenerated

app/
├── models/
│   ├── locker_swap_proposal.rb    # decline! guard widened; confirm!/decline! gain by: ; + admin_decided_by
│   └── user.rb                    # + belongs_to inverse (swap_decisions_made, dependent: :nullify)
├── controllers/
│   ├── locker_swap_proposals_controller.rb   # #confirm removed
│   └── admin/
│       └── swap_validations_controller.rb    # new: index, validate, refuse
├── views/
│   ├── home/
│   │   └── _swap_exchange_in_progress.html.erb   # collapses to one unconditional message, no button
│   ├── admin/
│   │   └── swap_validations/
│   │       └── index.html.erb                    # new
│   └── shared/
│       └── _site_menu_items.html.erb             # + admin nav link to the new screen

config/
├── routes.rb          # + admin/swap_validations (index, validate, refuse); - locker_swap_proposals#confirm
└── locales/
    ├── en.yml          # + admin.swap_validations.*, + 1 replacement key; - 4 retired confirm keys;
    │                   #   - locker_swap_proposals.confirm.confirmed; "exchange_in_progress" reworded
    │                   #   in both swap_exchange_in_progress.title and locker_swap_proposals.index.*
    └── fr.yml          # same, French (research.md R12)

test/
├── models/locker_swap_proposal_test.rb
├── controllers/
│   ├── locker_swap_proposals_controller_test.rb        # #confirm tests removed
│   └── admin/swap_validations_controller_test.rb        # new
└── system/
    ├── admin_swap_validation_test.rb                     # new
    └── locker_swap_proposal_test.rb                      # confirm-button assertions replaced
```

**Structure Decision**: Single Rails monolith (unchanged from every prior feature in this repo). No new
top-level directory; the new controller and view live at the existing `app/controllers/admin/` and
`app/views/admin/` locations every other admin-only screen already uses (013, 016, 027, 029, 030, 031).

## Complexity Tracking

*No violations — table omitted.*
