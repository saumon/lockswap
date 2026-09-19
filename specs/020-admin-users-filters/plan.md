# Implementation Plan: Users Screen — Locker Details and Filters

**Branch**: `020-admin-users-filters` | **Date**: 2026-09-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/020-admin-users-filters/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

The existing Admin → Users screen (013/015) grows two things: three new read-only columns per row
(current floor, current locker, active locker search wish — all already recorded on `users` and
`locker_wishes`, no migration), and four independent filters (current locker: exact match; current
floor: choice list; role: choice list; email: partial match).

The two choice-list filters (floor, role) follow the link-based filter pattern feature 017 already
established: a row of links plus "All", `aria-current` on the one in force, no `<select>` (the same
On-Input keyboard failure 017's research (R2) ruled out applies here too). The current-floor filter
reuses the existing `FloorFilter` PORO unchanged, fed the floors saved by *any* registered user
instead of by active wishers. The role filter is a new, deliberately smaller `RoleFilter` PORO — its
choice set is the fixed pair `["Admin", "Standard"]`, never derived or narrowed, so it does not need
`FloorFilter`'s sorting or "keep a vanished selection visible" logic.

The two text filters (locker, email) have no small enumerable choice set, so they are `<input
type="text">` fields rather than links. To keep the same "no Apply control, effect follows the
input" behavior 017 established for its link filters, a new `auto-submit` Stimulus controller
debounces the `input` event and calls `form.requestSubmit()` — the smallest way to reach the same
requirement (Assumptions: "as soon as a value is chosen or typed") without a request per keystroke.
This is the plan's one genuinely new UI pattern, and Principle III requires it to be justified in the
PR: see research R2.

The list is wrapped in the same `<turbo-frame data-turbo-action="advance"
data-controller="frame-history">` shape 017 introduced, reusing `frame_history_controller.js`
unchanged (it is already generic over "whatever frame it is attached to"). All four filter values
travel in the query string of `GET /admin/users`, exactly as 017's two do, which is what makes them
shareable, reachable with back/forward, and — new to this feature — what lets the existing
"grant administrator rights" action (015) carry them through its own redirect (FR-016).

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged)

**Primary Dependencies**: Rails 8.1.3, Devise 5.0, Turbo/Stimulus via importmap, Tailwind v4 through
`tailwindcss-rails` (unchanged — no new gem). Reuses `turbo-rails`'s frame support and
`frame_history_controller.js`, both introduced by feature 017. Adds one small Stimulus controller,
`auto_submit_controller.js` (~15 lines), for the two text filters.

**Storage**: SQLite through Active Record (unchanged) — **no migration**. The feature reads
`users.floor`, `users.locker_number`, `users.admin` (all already surfaced elsewhere) and
`locker_wishes.floor` (already surfaced on the locker wishes screen).

**Testing**: Minitest + Rails system tests (Capybara, headless Chrome), axe-core accessibility audits
(unchanged — extends the existing suites, adds one system test file and one model test file).

**Target Platform**: Linux server, deployed via Docker + Kamal (unchanged).

**Project Type**: Web — server-rendered Rails monolith, single project (unchanged).

**Performance Goals**: No swap/lock execution path is touched. Filtering happens in SQL (`WHERE`
clauses composed from named `User` scopes), so a filtered view reads *fewer* rows than the screen
does today. One additional constant-cost `SELECT DISTINCT` query is added for the current-floor
filter's choice list (bounded by the number of distinct floors on file, independent of user count) —
the same shape as 017's R3. The existing `.includes(:admin_granted_by)` eager-load is preserved
unchanged, so no per-row query is introduced. Target, asserted in the controller test: the filtered
index issues no more queries than the unfiltered one.

**Constraints**: Must reuse the screen's existing card/table/empty-state vocabulary, and 017's
filter-bar/turbo-frame vocabulary, rather than invent a parallel one (Constitution III). The one new
pattern — debounced auto-submit on a text input — must be justified in the PR (research R2). Must not
change the existing "Admin" badge, "grant administrator rights" control, or row order (FR-013,
FR-015). Must stay within the site's single 48rem breakpoint
(`test/stylesheet_breakpoint_test.rb`, 012 FR-018).

**Scale/Scope**: No migration, no new route, no new table. One new PORO (`RoleFilter`), four new
named scopes on `User` plus one choice query, one controller action extended (`index`) and one
redirect widened (`grant_admin`), two new view partials (`_floor_filter`, `_text_filter`) plus edits to
the existing `index.html.erb`, one new Stimulus controller, one new CSS component for the text
filter, one new system test file plus additions to two existing suites and one model test file.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|---|---|
| I. Code Quality | PASS. `FloorFilter` is reused unchanged rather than copied — only what feeds it (the set of floors) differs. `RoleFilter` is kept deliberately small rather than forced to share `FloorFilter`'s sorting/append machinery it does not need, which would be complexity with no requirement behind it. Query composition lives in four named `User` scopes, each answering one filter, so `Admin::UsersController#index` stays a straight read-composition rather than growing conditional branches. |
| II. Testing Standards | PASS. Every requirement gets a failing-first test at the level that can reach it: a model test for `RoleFilter` (no DB needed) and for the four new `User` scopes including the LIKE-escaping edge case (a literal `%` or `_` in a search term); a controller test for parameter handling, AND-combination, the no-match message, the filters-survive-grant-redirect requirement (FR-016), and a query-count assertion; a system test for the frame updating in place, the two link filters' keyboard rule, the two text filters' debounced behavior, and back/forward. |
| III. User Experience Consistency | PASS, with one justification the PR must carry. The screen reuses `card`, `data-table`, `filter-bar`, `filter-group`, `filter-choice`, the turbo-frame pattern, and `frame_history_controller.js` — all unchanged from 017. It introduces one new pattern, the debounced auto-submit text input, justified in research R2: links cannot represent free text, and the requirement (immediate effect, no Apply control) still applies to these two filters. |
| IV. Performance Requirements | PASS. One constant-cost `DISTINCT` query is added (current-floor choices), bounded by distinct-floor count. Filtering is pushed into SQL, so the filtered path reads fewer rows than today's unfiltered one; no query is added per row. Evidence for the PR: the query-count assertion in the controller test, run filtered and unfiltered. |

No unjustified violations. Complexity Tracking is not needed.

### Post-Design Re-Check (after Phase 1)

Re-evaluated against `research.md`, `data-model.md`, `contracts/admin-users-filter.md`, and
`quickstart.md`. All four principles still **PASS**:

- **Principle I** — `data-model.md` records why `RoleFilter` is a separate, smaller class rather than
  a second `FloorFilter` instance: its choice set is fixed and closed, so the "append a vanished
  selection" logic `FloorFilter` needs for a dynamic set would be dead code here.
- **Principle II** — `research.md` R6 names the file and level for every requirement, including the
  two suites that stand as regression evidence: `test/system/locker_wish_filter_test.rb`, unchanged
  in full, and `test/system/admin_users_test.rb`, unchanged except for one assertion the new filter
  fields make literally false (`assert_no_field` — see research R6) and which is narrowed rather than
  deleted or weakened. Every other assertion in both files is untouched, which is the evidence that
  neither this feature nor its reuse of `frame_history_controller.js` disturbed 017, and that nothing
  about the grant control (013/015) changed.
- **Principle III** — `contracts/admin-users-filter.md` fixes the DOM id for the no-match state
  (`#admin-user-directory-no-match`), distinct from any per-row id, so a regression cannot satisfy a
  selector while showing the wrong message.
- **Principle IV** — the query budget is an assertion, not a claim: `data-model.md` states the exact
  query count expected (filtered vs. unfiltered), which the controller test checks directly.

Design added no new violation and no justified exception; Complexity Tracking remains empty.

## Project Structure

### Documentation (this feature)

```text
specs/020-admin-users-filters/
├── plan.md              # This file (/speckit-plan command output)
├── research.md           # Phase 0 output — five decisions
├── data-model.md         # Phase 1 output — no schema change; query surface and POROs
├── quickstart.md         # Phase 1 output — manual validation of the three user stories
├── contracts/
│   └── admin-users-filter.md   # Phase 1 output — URL, frame and DOM contract
├── checklists/
│   └── requirements.md   # From /speckit-specify, re-validated by /speckit-clarify
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── models/
│   ├── role_filter.rb                         # NEW — the role axis: selection, choices (fixed pair)
│   ├── floor_filter.rb                         # unchanged — reused for the current-floor axis
│   └── user.rb                                 # + with_role, on_floor, with_locker_number,
│                                                #   email_containing scopes; + saved_floors choice query
├── controllers/
│   └── admin/
│       └── users_controller.rb                 # index builds the four filters and filters the list;
│                                                #   grant_admin redirect carries the selections (FR-016)
├── helpers/
│   └── admin/
│       └── users_helper.rb                     # NEW — path for one link-filter choice, preserving
│                                                #   the other three axes (mirrors LockerWishesHelper)
├── javascript/controllers/
│   └── auto_submit_controller.js               # NEW — debounces input, submits its form
└── views/admin/users/
    ├── index.html.erb                          # + turbo-cache-control meta tag
    ├── _floor_filter.html.erb                  # NEW — one link-based axis (role reuses this partial)
    ├── _text_filter.html.erb                   # NEW — one debounced text axis (locker, email)
    └── (table markup)                          # + turbo-frame wrapper, filter bar, new columns,
                                                 #   no-match state, hidden filter fields on the grant form
```

**Structure Decision**: Single Rails monolith (unchanged). All new files are scoped to `app/models`
(two POROs), `app/controllers/admin`, `app/helpers/admin`, `app/javascript/controllers`, and
`app/views/admin/users` — no change outside the admin namespace and the shared `User` model. Feature
017's own files (`locker_wishes_controller.rb`, its views, `LockerWishesHelper`) are not touched;
`FloorFilter` and `frame_history_controller.js` are consumed as-is.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations recorded.
