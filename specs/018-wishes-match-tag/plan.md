# Implementation Plan: "It's a match!" tag on locker wishes

**Branch**: `018-wishes-match-tag` | **Date**: 2026-09-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/018-wishes-match-tag/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

A purely computed, read-only badge on the existing locker wishes list: a row is tagged
"It's a match!" when that row's person is on the floor the viewer wants, and that same person wants
the floor the viewer is currently on. No new table, no new column, no new route, no persisted state —
the comparison is made fresh from four values that already exist (the viewer's `saved_floor` and their
own wish's `saved_floor`, against each row's `user.saved_floor` and the row wish's `saved_floor`).

The `saved_floor` accessor already defined on both `User` and `LockerWish` — "the value on file,
read past whatever unsaved edit is currently being re-displayed" — is exactly the guard this feature
needs and is reused rather than reading `floor`/`user.floor` directly: after a rejected declare,
`@locker_wish.floor` holds the invalid input being corrected, not what is actually saved, and reading
it here would tag rows against a wish that was never recorded (research R1).

The viewer's own two floors are looked up once per request in the controller, mirroring how
`@viewer_in_progress` and `@pending_recipient_ids` are already computed once rather than per row
(research R2). The comparison itself lives on `LockerWish` as a boolean predicate, since every value
the row side needs is already loaded through `active`'s existing `includes(:user)` — no query is added
per row, and none is added at all beyond what the list already runs.

The tag renders as the existing `.badge.badge-success` component, inside the same "Swap" table cell
that already carries the row's other status text ("This is you", "Proposal pending", "You already
have an exchange in progress") or the "Propose swap" button — per the Clarifications session, it joins
that family rather than opening a new column. No new CSS is introduced.

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged)

**Primary Dependencies**: Rails 8.1.3, Devise 5.0 (unchanged — no new gem, no new route, no new
Turbo Frame; this feature adds content inside the frame 017 already introduced)

**Storage**: SQLite through Active Record (unchanged) — **no migration**. Reads only
`locker_wishes.floor` and `users.floor`, both of which already exist and are already loaded by
`LockerWish.active`'s existing `includes(:user)`.

**Testing**: Minitest + Rails system tests (Capybara, headless Chrome), axe-core accessibility audits
(unchanged — extends the existing suites for the locker wishes screen)

**Target Platform**: Linux server, deployed via Docker + Kamal (unchanged)

**Project Type**: Web — server-rendered Rails monolith, single project (unchanged)

**Performance Goals**: No swap/lock execution path is touched. The feature adds **zero** additional
queries: the viewer's own current floor and wish floor are each read from an association that is
already loaded exactly once per request (`current_user` and `current_user.locker_wish`), and each
row's comparison reads `wish.floor` and `wish.user.saved_floor`, both already present from the list
query's existing eager-loading. Target, asserted in the controller test: the index issues no more
queries with matching rows present than without.

**Constraints**: Must reuse the screen's existing `.badge` vocabulary rather than invent a new visual
component (Constitution III) — no new CSS class. Must not change row content, row order, filtering
behavior, or swap-proposal eligibility; the tag is additive information only (spec Assumptions). Must
sit inside the existing `#locker-wish-list` Turbo Frame so it participates in filtering exactly like
the rest of the row (017), and inside the "Swap" cell per the Clarifications session.

**Scale/Scope**: No migration, no new route, no new model table, no new PORO. One new predicate method
on `LockerWish`, two new controller-level reads (both already-cheap association lookups), one view
edit inside an existing partial, no new CSS. Two new fixture users needed so a genuine reciprocal
match exists in test data, and so a second row can be shown matching at the same time (none of the
current fixtures reciprocate — see research R4).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|---|---|
| I. Code Quality | PASS. The reciprocity rule is one boolean predicate (`LockerWish#reciprocal_match?`) taking the viewer's two floors, colocated with the model that already owns `saved_floor` and the `active` scope this feature depends on — not duplicated logic in the view or the controller. The controller gains one small private method (`viewer_match_floors`) following the exact shape `viewer_in_progress`/`pending_recipient_ids` already use: computed once in `load_wish_list`, exposed as an ivar, read per row in the view. |
| II. Testing Standards | PASS. Model tests cover the predicate directly (both directions required, viewer's own missing floor, row's missing floor, and — since floors are free-text — that equality is exact, not case- or whitespace-insensitive). Controller/integration tests cover presence and absence of the badge per scenario, including that it survives an active floor filter and that it is never shown on the viewer's own row. A system test extends the existing locker-wishes suite to assert the visible text renders in the browser and coexists with the "Proposal pending" state. An axe-core pass is added for a list containing the badge. |
| III. User Experience Consistency | PASS. Reuses `.badge`/`.badge-success` verbatim — the same component already used elsewhere for a positive status — introducing no new pattern. Placement was resolved explicitly in the Clarifications session rather than invented here. |
| IV. Performance Requirements | PASS. No query is added; the predicate reads only attributes already in memory from the list query and from `current_user`. Evidence for the PR: a controller-test query-count assertion comparing a render with at least one matching row against one without. |

No unjustified violations. Complexity Tracking is not needed.

### Post-Design Re-Check (after Phase 1)

Re-evaluated against `research.md`, `data-model.md`, `contracts/match-tag.md` and `quickstart.md`.
All four principles still **PASS**:

- **Principle I** — `data-model.md` records why the predicate takes the viewer's two floors as
  arguments rather than the whole `User` object: it keeps `LockerWish` from needing to know anything
  about `User` beyond the `saved_floor` value it already reads through `user.saved_floor` for display.
- **Principle II** — `research.md` R4 names the exact fixture gap (no two existing wishes reciprocate,
  and the name first considered for the fix collided with an existing fixture load-bearing for feature
  010) and the two fixture pairs added to close it, so a test author is not left to discover either
  mid-task.
- **Principle III** — `contracts/match-tag.md` fixes the badge's exact text, its id pattern, and its
  position relative to the cell's other conditional content, so a regression cannot satisfy a loose
  text-only assertion while rendering in the wrong place or duplicating across states.
- **Principle IV** — the "zero added queries" claim is now a concrete assertion in
  `contracts/match-tag.md` and `quickstart.md`, not just a design intention.

Design added no new violation and no justified exception; Complexity Tracking remains empty.

## Project Structure

### Documentation (this feature)

```text
specs/018-wishes-match-tag/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output — four decisions
├── data-model.md        # Phase 1 output — no schema change; the computed match predicate
├── quickstart.md        # Phase 1 output — manual validation of the one user story
├── contracts/
│   └── match-tag.md     # Phase 1 output — badge text, id, placement and query-budget contract
├── checklists/
│   └── requirements.md  # From /speckit-specify, re-validated by /speckit-clarify
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── models/
│   └── locker_wish.rb                        # + reciprocal_match?(viewer_floor, viewer_wish_floor)
├── controllers/
│   └── locker_wishes_controller.rb           # load_wish_list: + viewer_match_floors, exposed as
│                                             #   @viewer_current_floor / @viewer_wish_floor
└── views/locker_wishes/
    └── _locker_wish_list.html.erb            # Swap cell: + badge when the row's wish matches

config/routes.rb                              # unchanged
app/assets/tailwind/application.css           # unchanged — reuses .badge / .badge-success

test/
├── models/
│   └── locker_wish_test.rb                   # + reciprocal_match? — both directions, one-sided
│                                             #   match, blank viewer floor, blank row floor
├── controllers/
│   └── locker_wishes_controller_test.rb      # + badge shown/hidden per scenario, survives a floor
│                                             #   filter, never on the viewer's own row, query-count
│                                             #   evidence for Principle IV
├── system/
│   ├── locker_wish_test.rb                   # + the badge is visible and reads "It's a match!"
│   │                                         #   alongside "Proposal pending"
│   └── accessibility_test.rb                 # + axe on a list containing the badge
└── fixtures/
    ├── users.yml                              # + two accounts (henry, iris) whose floor/wish each
    │                                         #   reciprocate with bob, since none currently do
    │                                         #   (research R4)
    └── locker_wishes.yml                      # + henry_wish, iris_wish
```

**Structure Decision**: Single server-rendered Rails project, unchanged. The feature adds one method
to a model that already exists, extends one controller method that already exists, and edits one view
partial that already exists — no new file, no new namespace, no new CSS component, no new dependency.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Not applicable — no Constitution Check violations.
