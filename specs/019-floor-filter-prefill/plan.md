# Implementation Plan: Pre-fill "Their Floor" filter from the viewer's wish

**Branch**: `019-floor-filter-prefill` | **Date**: 2026-09-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/019-floor-filter-prefill/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

The "Their Floor" filter (017) gains a second source for its selection, alongside the query string it
already reads: on a request that carries no `current_floor` key at all, the selection is derived from
the viewer's own active wish (`current_user.locker_wish&.saved_floor`) instead of defaulting to "All
floors." A request that does carry the key — from a filter click, a redirect this feature issues, or a
Back/Forward restoration of either kind — is respected exactly as 017 already respects it. No new
table, column, route, or Turbo mechanism; the existing `#locker-wish-list` frame, its link-based filter
bar, and its redirect-carries-the-filters pattern (017 R5) are all reused unchanged in shape.

The one real design problem this feature has to solve is *not* the derivation itself (a one-line
`||`-style fallback) but telling "fresh screen entry" (FR-001/FR-002) apart from "already decided this
visit" (FR-008/FR-009) without adding session state — 017's Assumptions section rules that out, and the
obvious request-type signal (`turbo_frame_request?`) turns out to be unreliable for exactly the
Back/Forward case that matters most, per 017's own research (R1 there measured Turbo's native
restoration visit hitting the server as a genuine full-page request "roughly two runs in five"). The
resolution (research R1) is to let the query string alone carry the distinction: every link this
feature's filter renders now encodes `current_floor` explicitly, including an empty string for "All
floors" rather than omitting it, so a single click makes the choice durable — through further clicks on
either axis and through Back/Forward — without needing to know how any given request arrived. This
comes with one accepted, documented limitation: a bookmarked link that already encodes `current_floor`
is indistinguishable from a Back/Forward visit and will reproduce its value rather than being
overridden (research R1, "Known limitation, accepted").

`#create`'s redirect explicitly sets `current_floor` to the newly saved wish's floor, and `#destroy`'s
redirect drops the key entirely — both are immediate, visible effects of those actions (FR-003/FR-004),
not left to the general fallback rule to produce the right answer a request later (research R3). This
changes two existing 017 controller tests on purpose, since they currently assert the previous meaning
of "the filter survives the redirect" for this one axis (research R3).

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged)

**Primary Dependencies**: Rails 8.1.3, Devise 5.0, Turbo/Stimulus via importmap (unchanged — no new
gem, no new route, no new Turbo Frame or Stimulus controller; this feature changes what value flows into
the `#locker-wish-list` frame 017 already introduced, not the frame mechanism itself)

**Storage**: SQLite through Active Record (unchanged) — **no migration**. Reads only
`locker_wishes.floor` (via the existing `saved_floor` accessor), already loaded by
`current_user.locker_wish` wherever this feature needs it.

**Testing**: Minitest + Rails system tests (Capybara, headless Chrome), axe-core accessibility audits
(unchanged — extends the existing suites for the locker wishes screen; no new markup, so no new
accessibility surface)

**Target Platform**: Linux server, deployed via Docker + Kamal (unchanged)

**Project Type**: Web — server-rendered Rails monolith, single project (unchanged)

**Performance Goals**: No swap/lock execution path is touched. The feature adds **zero** additional
queries: `current_user.locker_wish` is read from an association the controller already loads on every
path that needs the derivation (index, and a rejected create's re-render of index — research R2).
Target, asserted in the controller test: the index issues no more queries with an active wish present
than without.

**Constraints**: Must not change `looking_for`'s behaviour in any respect (spec FR-007). Must not
introduce session or account-level storage for filter state — 017's Assumptions section commits this
screen to keeping selections in the page address and nowhere else, and this feature's one accepted
limitation (research R1) exists specifically to honour that commitment rather than work around it. Must
reuse the existing filter-bar/link vocabulary (Constitution III) — no new visual component.

**Scale/Scope**: No migration, no new route, no new model table, no new PORO, no new Stimulus
controller. One new controller method (`current_floor_selection`), two controller methods edited
(`build_floor_filters`'s current_floor branch, `create`'s and `destroy`'s redirect targets), one helper
method edited (`locker_wish_filter_path`), one view partial edited
(`_locker_wish_list.html.erb`'s hidden-field loop). Two existing controller tests updated to their new,
intentional assertions (research R3).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|---|---|
| I. Code Quality | PASS, with an asymmetry the PR must carry. `current_floor` and `looking_for` are no longer handled identically — only `current_floor` gets a wish-derived fallback and an unconditionally-rendered hidden field. This is new: 017 deliberately treated both axes uniformly, and this feature breaks that symmetry for one of them. The justification is that the requirement itself is asymmetric — nothing asks `looking_for` to track anything — so making both axes handle it identically would mean writing dead branching into the axis that does not need it. The derivation logic lives in one controller method (`current_floor_selection`), not duplicated between the index render and the redirect-building code, and `FloorFilter` itself needs no change at all (research R1/R4). |
| II. Testing Standards | PASS. Every requirement gets a failing-first test at the controller level, where both the request-derivation rule and the redirect behaviour live (research R5); two existing 017 tests are edited to their new, correct assertions rather than left red, with the reason recorded in research R3 so a reviewer does not mistake an intentional behaviour change for dropped coverage. System-level coverage extends the existing filter test file for the in-browser, Back/Forward-inclusive scenarios research R1 exists to get right. |
| III. User Experience Consistency | PASS. No new visual component, no new interaction pattern — the same filter bar and links 017 already shipped, now sometimes pre-selected rather than always starting on "All floors." The one behaviour a user could perceive as a "pattern change" — a bookmarked filtered link not always reproducing exactly what it encoded — is called out explicitly in research R1 rather than left for someone to discover later, per this principle's "breaking changes to user-facing behaviour... MUST be called out explicitly." |
| IV. Performance Requirements | PASS. Zero queries added on any path (research R2); the evidence is a query-count assertion in the controller test, matching the shape 017 and 018 already established. No unbounded loop or query is introduced. |

No unjustified violations. Complexity Tracking is not needed — the one deliberate asymmetry above is
Principle I's concern, not a gate failure, and is justified in place.

### Post-Design Re-Check (after Phase 1)

Re-evaluated against `research.md`, `data-model.md`, `contracts/current-floor-sync.md` and
`quickstart.md`. All four principles still **PASS**:

- **Principle I** — `data-model.md` records that this feature introduces no new entity and no schema
  change; the only new "shape" is a two-row decision table (fresh entry vs. already-decided) for one
  existing value, which `contracts/current-floor-sync.md` now pins down precisely enough that the
  asymmetry from the pre-design pass is fully specified rather than left to interpretation during
  implementation.
- **Principle II** — `research.md` R5 now names the file and level for every requirement, including the
  two existing tests being changed on purpose (R3) and the one existing system suite
  (`locker_wish_test.rb`) that stays a regression check rather than gaining new assertions, since this
  feature adds no new markup for it to cover.
- **Principle III** — `research.md` R1's "Known limitation, accepted" is the concrete, written-down form
  of the disclosure this principle asks for; there is nothing further design surfaced beyond it.
- **Principle IV** — `contracts/current-floor-sync.md`'s "Query budget" section and `quickstart.md`'s
  targeted test list turn the zero-added-queries claim into a concrete, runnable assertion rather than a
  design intention.

Design added no new violation and no further justified exception; Complexity Tracking remains empty.

## Project Structure

### Documentation (this feature)

```text
specs/019-floor-filter-prefill/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output — five decisions
├── data-model.md        # Phase 1 output — no schema change; the derivation table
├── quickstart.md        # Phase 1 output — manual validation of both user stories
├── contracts/
│   └── current-floor-sync.md   # Phase 1 output — request/redirect/link contract
├── checklists/
│   └── requirements.md  # From /speckit-specify, re-validated by /speckit-clarify
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── controllers/
│   └── locker_wishes_controller.rb   # + current_floor_selection (NEW private method)
│                                     #   ~ build_floor_filters: current_floor axis uses it
│                                     #   ~ create: redirect sets current_floor explicitly
│                                     #   ~ destroy: redirect drops current_floor
├── helpers/
│   └── locker_wishes_helper.rb      # ~ locker_wish_filter_path: current_floor kept as ""
│                                     #   rather than dropped when blank; looking_for unchanged
└── views/locker_wishes/
    └── _locker_wish_list.html.erb   # ~ hidden-field loop: current_floor unconditional,
                                     #   looking_for keeps its existing guard

# Unchanged: app/models/floor_filter.rb, app/models/locker_wish.rb, routes.rb,
# app/assets/tailwind/application.css, _floor_filter.html.erb, _locker_wish_panel.html.erb,
# _locker_wish_form.html.erb — none of this feature's changes touch what these files do.

test/
├── controllers/
│   └── locker_wishes_controller_test.rb   # + fresh-entry derivation (wish present/absent),
│                                         #   explicit current_floor respected unchanged,
│                                         #   create/destroy redirect targets, rejected-declare
│                                         #   preservation, query-count evidence
│                                         #   ~ two existing tests updated (research R3)
└── system/
    └── locker_wish_filter_test.rb        # + Story 1 (declare narrows list, fresh reload
                                         #   keeps it narrowed), manual override holding
                                         #   across an unrelated interaction and across
                                         #   Back/Forward, Story 2 (cancel resets, reload
                                         #   keeps it reset)
```

**Structure Decision**: Single server-rendered Rails project, unchanged. This feature edits three files
that already exist (one controller, one helper, one view partial) and adds no new file to `app/` at
all — no new model, PORO, route, view, CSS component, or JavaScript. It is the smallest of the three
`019`/`018`/`017` changes to this screen in terms of files touched, despite the design problem (research
R1) being the most involved of the three.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Not applicable — no Constitution Check violations. The asymmetry between the two filter axes noted
under Principle I is a deliberate design choice justified in place, not a gate violation requiring
tracking here.
