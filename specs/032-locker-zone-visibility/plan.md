# Implementation Plan: Locker Zone Visibility Across Screens

**Branch**: `032-locker-zone-visibility` | **Date**: 2026-09-26 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/032-locker-zone-visibility/spec.md`

## Summary

A pure read-only display addition on top of 031's `Zone`/`LockerMapEntry` model: wherever the site already
shows a floor + locker number, it now also shows that locker's zone name, whenever the pair is declared in
the Locker Map. No new table, no new route, no new form. One new batched lookup —
`LockerMapEntry.zone_names_for(pairs)` (and its single-pair convenience wrapper `.zone_name_for`) — is the
one place every touched screen reads from, so the "known zone for this floor + locker" question is answered
identically everywhere and costs exactly one indexed query per screen, never one per row.

Two shapes of caller: single-record screens (the account holder's own locker card, the admin account detail
page, a swap proposal received, the exchange-in-progress card) call `.zone_name_for` directly where the
floor/locker are already read today. List/table screens (the admin account directory, the locker search
list, and the swap-history table shared by the self-service history screen and the admin account detail
page) batch every row's pair through `.zone_names_for` once in the controller and hand the resulting Hash
down, mirroring how `FloorFilter`/`RoleFilter` and `Admin::UsersController#index`'s existing `includes` are
already built to cost one query regardless of row count (Principle IV).

Swap history needs one extra accessor, `LockerSwapProposal#locker_sides`, which exposes the same
requester/recipient `[floor, locker_number]` pairs `floor_and_locker_summary` already computes internally
(preserving its pending/accepted-vs-settled branching) — so the zone can be rendered next to that existing
summary text rather than folded inside it, keeping zone and locker number visually distinct (FR-008) without
touching `floor_and_locker_summary`'s existing, already-tested wording.

Per the 2026-09-26 clarification, history always shows whichever zone currently claims a pair — there is no
snapshot of what zone, if any, applied when the proposal was made, and none is added by this feature.

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged).

**Primary Dependencies**: Rails 8.1.3, Devise 5.0, Turbo/Stimulus via importmap, Tailwind v4 via
`tailwindcss-rails`. **No new gem, no new Stimulus controller, no new migration** — every touched screen is
already server-rendered.

**Storage**: SQLite. **No schema change.** This feature reads the existing `zones` / `locker_map_entries`
tables and their existing unique index on `(floor, locker_number)` (031); it writes nothing new.

**Testing**: Minitest, Rails system tests (Capybara, headless Chrome), axe-core. New file:
`test/models/locker_map_entry_zone_lookup_test.rb` (or extended `test/models/locker_map_entry_test.rb`) for
`.zone_name_for`/`.zone_names_for`, plus a `locker_sides` case added to `test/models/locker_swap_proposal_test.rb`.
Extended: `test/controllers/locker_profiles_controller_test.rb` (or `homepage_locker_wish_test.rb`'s sibling
system coverage), `test/controllers/admin/users_controller_test.rb`, `test/controllers/locker_wishes_controller_test.rb`,
`test/controllers/locker_swap_proposals_controller_test.rb`, `test/system/admin_user_detail_test.rb`,
`test/system/admin_users_test.rb`. No new system test file is required — this feature adds assertions to
screens existing system tests already visit rather than introducing a new user journey.

**Target Platform**: Linux server, Docker + Kamal (unchanged).

**Project Type**: Web, server-rendered Rails monolith, single project.

**Performance Goals**: No swap or lock execution path changes. Every touched screen gains exactly one
additional indexed query (`zone_names_for`/`zone_name_for`, hitting 031's existing `(floor, locker_number)`
unique index), never one per row — the same "bounded regardless of list size" shape
`Admin::UsersController#index`'s existing `includes(:admin_granted_by, :locker_wish)` already establishes.

**Constraints**: CLAUDE.md design contract: no new colour — a zone belongs to neither side of the swap axis,
so its label is rendered in the existing neutral `.meta` treatment (or an equally neutral, reused style),
never `--color-rail-you`/`--color-rail-them`. No raw hex in a template. Every new string (the zone label's
own wording) goes through I18n in `en.yml` and `fr.yml` (Constitution III). Zone display must be visually
distinguishable from the locker number itself (FR-008) — solved by rendering it as a separate, differently
styled element next to the floor/locker value, never concatenated into the same string.

**Scale/Scope**: Six screens/areas touched, all read-only additions: the account holder's own locker card
(`home/_locker_profile.html.erb`), the admin account directory list (`admin/users/index.html.erb`), the
admin account detail page (`admin/users/show.html.erb`), the locker search list
(`locker_wishes/_locker_wish_list.html.erb`), the two homepage swap-proposal cards
(`home/_swap_proposals_received.html.erb`, `home/_swap_exchange_in_progress.html.erb`), and the shared
swap-history table (`locker_swap_proposals/_history_table.html.erb`, rendered from both
`locker_swap_proposals/index.html.erb` and `admin/users/show.html.erb`). No new screen, no new route.

## Constitution Check

*GATE: must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | How |
|---|---|---|
| I. Code Quality | ✅ | One shared lookup (`LockerMapEntry.zone_names_for`/`.zone_name_for`) is the sole place every screen answers "what zone, if any" — no per-screen duplicate query logic. `LockerSwapProposal#locker_sides` reuses `floor_and_locker_summary`'s existing side-computation rather than re-deriving it a second way. Both new public methods documented at their definitions, mirroring `LockerMapEntry.known?`'s existing shape. rubocop and brakeman clean. |
| II. Testing (non-negotiable) | ✅ | Model tests for `.zone_names_for`/`.zone_name_for` (known pair, unknown pair, empty Locker Map, renamed zone, locker removed from its zone) and for `#locker_sides` written first, failing without the change. Every touched controller/view gains assertions for "zone shown when declared" and "zone absent, no error, when not declared" — no new flaky patterns, fixed fixtures throughout. |
| III. UX Consistency | ✅ | Reuses the existing `.meta`/detail-value vocabulary rather than inventing a new component; the swap axis colours are never spent on a zone label, per CLAUDE.md ("colour is never the only signal" — the zone is also always spelled out as text). Every new string in `en.yml` and `fr.yml`. **No breaking change**: an unmapped locker's floor/locker number renders pixel-for-pixel as it did before this feature (FR-005/FR-006). |
| IV. Performance | ✅ | One additional indexed existence-style query per screen, batched for every list/table screen exactly once per request — never a query per row. No swap/lock execution path touched. |

**Post-design re-check (after Phase 1)**: no violations. Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/032-locker-zone-visibility/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── zone-lookup.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks, not created here
```

### Source Code (repository root)

```text
app/models/
├── locker_map_entry.rb        # + .zone_names_for(pairs), .zone_name_for(floor, locker_number)
└── locker_swap_proposal.rb    # + #locker_sides (reuses floor_and_locker_summary's side pairs)

app/controllers/
├── admin/users_controller.rb           # #index, #show: + batched/single zone lookup ivar
├── locker_wishes_controller.rb         # load_wish_list: + batched zone lookup ivar
└── locker_swap_proposals_controller.rb # #index: + batched zone lookup ivar (history table)

app/views/
├── home/_locker_profile.html.erb              # + zone label next to the account holder's own locker
├── home/_swap_proposals_received.html.erb     # + zone label next to the requester's locker
├── home/_swap_exchange_in_progress.html.erb   # + zone label next to the counterpart's locker
├── admin/users/index.html.erb                 # + zone column/label per row
├── admin/users/show.html.erb                  # + zone label next to the viewed account's locker,
│                                               #   passes the batched history lookup down
├── locker_wishes/_locker_wish_list.html.erb   # + zone label per row
└── locker_swap_proposals/_history_table.html.erb # + zone label per side, next to floor_and_locker_summary

config/locales/en.yml, fr.yml    # the zone label's own wording, both languages

test/  (see Technical Context → Testing)
```

**Structure Decision**: No new top-level directory and no new controller/model file — this feature extends
two existing models (`LockerMapEntry`, `LockerSwapProposal`) with read-only accessors and adds a display
line to views/controllers that already render a floor + locker number, exactly the "read-model addition to
an existing screen" shape the constitution's Code Quality principle favours over introducing a parallel
component.

## Complexity Tracking

No constitution violations to justify.
