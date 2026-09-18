# Implementation Plan: Filter locker wishes by floor

**Branch**: `017-locker-wishes-floor-filter` | **Date**: 2026-09-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/017-locker-wishes-floor-filter/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Two independent floor filters on the existing locker wishes list: one on the floor each person is
looking for (`locker_wishes.floor`), one on the floor they currently hold a locker on
(`users.floor`). Both are read-only narrowings of the list that already exists — no new table, no new
column, no new route.

The selections travel in the query string of `GET /locker_wishes` (`?looking_for=3&current_floor=1`),
which is what makes them shareable, bookmarkable, reachable with back/forward (FR-018) and easy to
carry through the declare/cancel redirect (FR-019). Each filter renders as a row of links — one per
floor plus "All floors" — rather than a `<select>`, because FR-008 requires that moving through the
choices without committing to one does not re-filter the list, and an auto-submitting select fires on
arrow-key navigation on several platforms (research R2).

The list itself is wrapped in a `<turbo-frame id="locker-wish-list" data-turbo-action="advance">`, and
the filter links target that frame. Turbo replaces the frame alone — the declare panel above it and
the viewer's scroll position stay put (FR-009) — while `advance` pushes the filtered URL into history
so the address still reflects the state (FR-018). This is the first Turbo Frame in the codebase, and
Principle III requires that to be justified in the PR: it is what lets the list change without the
panel above it moving.

Implementation added one thing this plan did not foresee. Turbo's restoration visit for a
frame-advance history entry does not reliably re-render the frame, so Back could leave the address and
the list disagreeing. `frame_history_controller.js` (~15 lines) closes that: it gives Turbo first
refusal and, if the frame is still in the document afterwards, points it at the address. See
research R1.

Filtering happens in SQL through three new `LockerWish` scopes sharing one `active` scope (the
existing "exclude people mid-exchange" rule, extracted so the list query and the two choice queries
cannot drift apart). Each filter's choices come from the **unfiltered** active set, per the
Clarifications session, so setting one filter never changes what the other offers. A small
`FloorFilter` PORO owns the parts both axes share: the ordering rule (numeric floors ascending, then
non-numeric alphabetically — FR-007), and appending a selection that is in force but no longer
present among the wishes so it stays visible and clearable (FR-015, FR-020).

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged)

**Primary Dependencies**: Rails 8.1.3, Devise 5.0, Turbo/Stimulus via importmap, Tailwind v4 through
`tailwindcss-rails` (unchanged — no new gem). Uses `turbo-rails`, already installed, for the first
Turbo Frame in this codebase. One small Stimulus controller (`frame_history_controller.js`) makes Back
and Forward re-render the frame, which Turbo does not do reliably on its own — see research R1.

**Storage**: SQLite through Active Record (unchanged) — **no migration**. The feature reads
`locker_wishes.floor` and `users.floor`, both of which already exist.

**Testing**: Minitest + Rails system tests (Capybara, headless Chrome), axe-core accessibility audits
(unchanged — extends the existing suites, adds one system test file)

**Target Platform**: Linux server, deployed via Docker + Kamal (unchanged)

**Project Type**: Web — server-rendered Rails monolith, single project (unchanged)

**Performance Goals**: No swap/lock execution path is touched. The feature adds exactly **two**
constant-cost `SELECT DISTINCT` queries per render of the list — one per filter axis, each returning
at most one row per distinct floor, independent of how many wishes exist. Filtering happens in SQL, so
a filtered view fetches *fewer* rows than the screen does today; no query is added per row. Target,
asserted in the controller test: the filtered index issues no more queries than the unfiltered one.

**Constraints**: Must reuse the screen's existing card/table/empty-state/button vocabulary rather
than invent a parallel one (Constitution III); the two new patterns it does introduce — a Turbo Frame
and a link-based filter bar — must be justified in the PR. Must not change row content, row order,
which wishes are eligible to appear, or swap-proposal eligibility (FR-013, FR-014). Must stay within
the site's single 48rem breakpoint (`test/stylesheet_breakpoint_test.rb`, 012 FR-018).

**Scale/Scope**: No migration, no new route, no new model table. One new PORO (`FloorFilter`), three
new scopes plus two choice queries on `LockerWish`, one controller action extended and two redirects
widened, one new view partial, two existing partials edited, one new CSS component, one new system
test file plus additions to three existing suites.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|---|---|
| I. Code Quality | PASS. The querying lives on `LockerWish` as named scopes; the presentation logic both axes share — ordering, and keeping an in-force selection visible when no wish carries it — lives in one `FloorFilter` PORO instantiated twice, rather than being written twice in a view helper or branched on an "axis" flag. The controller keeps its existing shape: read params, build the list, render. The pre-existing "exclude people mid-exchange" rule is extracted into an `active` scope so the list query and the two choice queries cannot disagree about what "active" means — deduplication, not new indirection. |
| II. Testing Standards | PASS. Every requirement gets a failing-first test at the level that can reach it: model tests for the three scopes and for `FloorFilter`'s ordering and in-force-selection rules (no DB needed for the latter); integration tests for parameter handling, junk values from the address (FR-020), selections surviving the declare and cancel redirects (FR-019), and a query-count assertion for Principle IV; system tests for the in-place frame update and preserved scroll position (FR-009), the keyboard rule (FR-008), and both empty states (FR-016). |
| III. User Experience Consistency | PASS, with a justification the PR must carry. The screen reuses `card`, `data-table`, `empty-state`, `btn`, `meta` and the existing narrow-width restack unchanged. It introduces two patterns the codebase does not yet have: a Turbo Frame, and a filter bar of links with `aria-current`. Both are justified — the frame is what FR-009 and FR-018 require together, and links are what FR-008's "arrowing through choices must not re-filter" requires (a `<select>` that submits on `change` is exactly the WCAG 2.1 SC 3.2.2 On Input failure that rule describes). The empty-result wording is required by FR-016 to be distinct from the existing "Nobody is looking for a locker right now", so neither message is reused for the other's job. |
| IV. Performance Requirements | PASS. Two constant-cost `DISTINCT` queries are added, each bounded by the number of distinct floors, not by wish count. Filtering is pushed into SQL, so the filtered path reads fewer rows than today's unfiltered one. No query is introduced per row, and no unbounded loop is added. The list query's pre-existing unbounded `SELECT` is left as it is — this feature does not make it worse, and narrowing it is out of scope. Evidence for the PR: the query-count assertion in the controller test, run filtered and unfiltered. |

No unjustified violations. Complexity Tracking is not needed.

### Post-Design Re-Check (after Phase 1)

Re-evaluated against the artifacts actually produced — `research.md`, `data-model.md`,
`contracts/locker-wish-filter.md`, `quickstart.md`. All four principles still **PASS**, with two
things the design surfaced that the pre-design pass had not yet pinned down:

- **Principle I** — the design adds one new class (`FloorFilter`) and one new helper. The PORO earns
  its place by being the single home for behaviour both axes need identically; `data-model.md` records
  why it is not a set of helper methods, so the choice is reviewable rather than assumed.
- **Principle II** — `research.md` R7 now names the file and level for every requirement, including
  the one suite that must pass **unchanged** (`test/system/locker_wish_test.rb`) as the evidence for
  FR-013/FR-014. That "nothing else moved" check is easy to omit and is now written down.
- **Principle III** — the contract fixes two separate DOM ids for the two empty states
  (`#locker-wish-list-empty`, `#locker-wish-list-no-match`) rather than one id whose text changes, so
  a regression cannot satisfy the selector while showing the wrong message. No new axe exemption is
  introduced.
- **Principle IV** — the query budget is now an assertion rather than a claim: the filtered index must
  issue no more queries than the unfiltered one, checked in the controller test and quoted in the PR.

Design added no new violation and no justified exception; Complexity Tracking remains empty.

## Project Structure

### Documentation (this feature)

```text
specs/017-locker-wishes-floor-filter/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output — seven decisions
├── data-model.md        # Phase 1 output — no schema change; the query and filter surface
├── quickstart.md        # Phase 1 output — manual validation of the four user stories
├── contracts/
│   └── locker-wish-filter.md   # Phase 1 output — URL, frame and DOM contract
├── checklists/
│   └── requirements.md  # From /speckit-specify, re-validated by /speckit-clarify
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── models/
│   ├── floor_filter.rb                       # NEW — one filter axis: selection, choices, ordering
│   └── locker_wish.rb                        # + active, looking_for, owner_on_floor scopes
│                                             #   + looked_for_floors, owner_floors choice queries
├── controllers/
│   └── locker_wishes_controller.rb           # index builds two FloorFilters and filters the list;
│                                             #   create/destroy redirect carrying the selections
├── helpers/
│   └── locker_wishes_helper.rb               # NEW — path for one choice, preserving the other axis
└── views/locker_wishes/
    ├── index.html.erb                        # unchanged
    ├── _locker_wish_form.html.erb            # + two hidden fields carrying the selections
    ├── _locker_wish_panel.html.erb           # + the cancel control carries the selections
    ├── _floor_filter.html.erb                # NEW — one axis rendered as a group of links
    └── _locker_wish_list.html.erb            # + turbo-frame wrapper, filter bar, no-match state

app/assets/tailwind/application.css           # NEW component: .filter-bar / .filter-choice

config/routes.rb                              # unchanged — the selections are query parameters

test/
├── models/
│   ├── floor_filter_test.rb                  # NEW — ordering, in-force selection, no DB
│   └── locker_wish_test.rb                   # + the three scopes and the two choice queries
├── controllers/
│   └── locker_wishes_controller_test.rb      # + params, junk values, redirect preservation,
│                                             #   query-count evidence for Principle IV
├── system/
│   ├── locker_wish_filter_test.rb            # NEW — User Stories 1–4 in the browser
│   ├── locker_wish_test.rb                   # unchanged behaviour must still pass
│   ├── accessibility_test.rb                 # + axe on a filtered list and on the no-match state
│   └── responsive_test.rb                    # + the filter bar at narrow width
└── fixtures/
    ├── users.yml                             # + one account on a floor that sorts numerically late
    └── locker_wishes.yml                     # + wishes giving at least three looked-for floors
```

**Structure Decision**: Single server-rendered Rails project, unchanged. The feature adds one PORO
under `app/models` (plain Ruby, no Active Record — it holds no data of its own), one helper, one view
partial and one CSS component; everything else is an edit to a file the locker wishes screen already
owns. No new namespace, service layer or front-end build step is introduced.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Not applicable — no Constitution Check violations. The two new UI patterns noted under Principle III
are permitted by that principle when justified, and their justification is recorded there and
required in the PR description; they are not gate violations.
