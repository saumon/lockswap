---

description: "Task list for 018 — \"It's a match!\" tag on locker wishes"
---

# Tasks: "It's a match!" tag on locker wishes

**Input**: Design documents from `/specs/018-wishes-match-tag/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/match-tag.md](./contracts/match-tag.md),
[quickstart.md](./quickstart.md)

**Tests**: Included and non-optional. Constitution Principle II is marked NON-NEGOTIABLE — every new
behaviour must carry automated tests that fail without the change and pass with it. Test tasks are
written before the implementation they cover.

**Organization**: This feature has a single user story (spec.md lists only User Story 1, P1), so all
implementation tasks carry the `[US1]` label and there is no cross-story sequencing to reason about.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1)
- Include exact file paths in descriptions

## Path Conventions

Server-rendered Rails monolith, single project at the repository root: `app/`, `test/`. No migration,
no route change — see `data-model.md`.

---

## Phase 1: Setup (Shared Test Data)

**Purpose**: Close the fixture gaps `research.md` R4 identifies — none of the current fixtures
reciprocate, and none of the four `/speckit-analyze` findings around FR-007 (more than one row tagged
at once) can be tested without a second reciprocating account.

> `research.md` R4 also records why the name `erin` was rejected here: she already exists in
> `test/fixtures/users.yml` (floor `"5"`, no locker, no wish) and is load-bearing for feature 010's
> `test/system/homepage_locker_wish_test.rb`. `henry` and `iris` are unused names in both fixture
> files.

- [X] T001 [P] Add two fixture users to `test/fixtures/users.yml`: `henry` (`floor: "7"`, no `locker_number`) and `iris` (`floor: "7"`, no `locker_number`), each with an explicit `created_at` continuing the file's existing one-day-apart sequence, and a comment naming 018 and explaining that both floor/wish pairs are chosen to reciprocate exactly with `bob` (`floor: "3"`, wish `"7"`) — two accounts rather than one so a test can show more than one row tagged at once for the same viewer (FR-007)
- [X] T002 [P] Add two fixture wishes to `test/fixtures/locker_wishes.yml`: `henry_wish` (`user: henry`, `floor: "3"`) and `iris_wish` (`user: iris`, `floor: "3"`), each with an explicit `created_at` continuing the file's existing sequence, and a comment noting that `bob` (floor `3`, wish `7`) reciprocates with both `henry` and `iris` (floor `7`, wish `3` each) — the pair(s) this feature's tests key off
- [X] T003 Run `bin/rails test` and `bin/rails test:system` and confirm the two new fixtures break nothing — `test/system/admin_users_test.rb` lists every registered account and `test/system/locker_wish_filter_test.rb`/`homepage_locker_wish_test.rb` assert on row counts; fix any fixture-count assumption surfaced here before writing a line of feature code

**Checkpoint**: The suites are green on the enlarged fixture set, so any later red is the feature's own.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: N/A — this feature has exactly one user story, so there is no shared prerequisite work
that sits *between* Setup and that story. Proceed directly to Phase 3.

---

## Phase 3: User Story 1 - Spot a reciprocal swap at a glance (Priority: P1) 🎯 MVP

**Goal**: Tag any row in the locker wishes list with "It's a match!" when that row's person is on the
floor the viewer wants, and that same person wants the floor the viewer is currently on.

**Independent Test**: With the viewer's own current floor and wish floor recorded, and one row whose
person's current floor and wish floor reciprocate exactly, open the locker wishes screen and confirm
only that row carries the tag.

### Tests for User Story 1 ⚠️

> Write these first and watch them fail.

- [X] T004 [P] [US1] Add tests to `test/models/locker_wish_test.rb` for `reciprocal_match?(viewer_current_floor, viewer_wish_floor)` per `data-model.md`'s formula: true only when **both** directions hold (`floor == viewer_current_floor` AND `user.saved_floor == viewer_wish_floor`); false when only one direction holds; false when `viewer_current_floor` is blank or nil; false when `viewer_wish_floor` is blank or nil; false when the wish's own `user.saved_floor` is blank ("Not set"); and exact string equality only — `"3"` does not match `"03"` or `" 3"`, matching every other floor comparison in the codebase (`looking_for`, `owner_on_floor`)
- [X] T005 [P] [US1] Add tests to `test/controllers/locker_wishes_controller_test.rb`: signed in as `bob`, `GET /locker_wishes` renders `It's a match!` inside **both** `henry`'s and `iris`'s rows and nowhere else — proving FR-007/Acceptance Scenario 8, that more than one row can carry the tag at once, not just a single hard-coded row; signed in as an account with no wish of its own, no row carries the tag however the floors line up; signed in as an account with a wish but no saved current floor, no row carries the tag; the tag is absent from the viewer's own row even when it would otherwise qualify; with `?looking_for=3` narrowing the list to `henry`'s and `iris`'s rows only, the tag still renders on both (contract "Filter interaction contract"); and a query-count assertion that `GET /locker_wishes` issues the same number of queries whether or not a reciprocal match is present (contract "Query-budget contract", Principle IV)
- [X] T006 [P] [US1] Add a test to `test/system/locker_wish_test.rb`: signed in as `bob`, visiting the locker wishes screen shows the visible text "It's a match!" inside `henry`'s row, positioned alongside the "Propose swap" button; after proposing a swap to `henry` and reloading, the same text still shows alongside "Proposal pending" rather than being replaced by it (contract "DOM contract", Acceptance Scenarios 9–10)
- [X] T007 [P] [US1] Add a test to `test/controllers/locker_wishes_controller_test.rb` for FR-009 (spec Edge Cases): signed in as `bob` with `henry`'s row currently tagged, cancel `bob`'s own wish (`DELETE /locker_wish`), then `GET /locker_wishes` again and assert the tag is gone from every row — the predicate is re-evaluated fresh each render, not remembered from before the cancellation
- [X] T008 [P] [US1] Extend `test/system/accessibility_test.rb` with an `assert_axe_clean` pass on the locker wishes list rendered with at least one "It's a match!" badge present, introducing no new axe exemption

### Implementation for User Story 1

- [X] T009 [P] [US1] Add `reciprocal_match?(viewer_current_floor, viewer_wish_floor)` to `app/models/locker_wish.rb` per `data-model.md`: returns true only when `floor.present? && viewer_current_floor.present? && floor == viewer_current_floor` AND `user.saved_floor.present? && viewer_wish_floor.present? && user.saved_floor == viewer_wish_floor`. Reads `user.saved_floor`, never `user.floor`, so it is never fooled by an unsaved edit (research R1)
- [X] T010 [P] [US1] In `app/controllers/locker_wishes_controller.rb#load_wish_list`, compute the viewer's own two floors once, following the exact shape `@viewer_in_progress`/`@pending_recipient_ids` already use: `@viewer_current_floor = current_user.saved_floor` and `@viewer_wish_floor = current_user.locker_wish&.saved_floor` — both read `saved_floor`, never `floor`, for the same reason as T009 (research R1, R2)
- [X] T011 [US1] In `app/views/locker_wishes/_locker_wish_list.html.erb`, inside the Swap cell (`id="<%= row_id %>-swap"`), render `<span class="badge badge-success">It's a match!</span>` as a sibling **before** the cell's existing conditional content, shown only when `wish.user_id != current_user.id && wish.reciprocal_match?(@viewer_current_floor, @viewer_wish_floor)` — it must never replace "This is you", the exchange-in-progress notice, "Proposal pending", or the "Propose swap" button, only sit alongside them (contract "DOM contract"). Depends on T009, T010
- [X] T012 [US1] Run `bin/rails test` and `bin/rails test:system` — T004–T008 green, every pre-existing suite (especially `test/system/locker_wish_test.rb` and `test/system/locker_wish_filter_test.rb`) still green with no edits beyond T006. `bin/rails test` (257 tests) is consistently 100% green. `bin/rails test:system` passed cleanly on the first run after implementation; repeated full-suite runs afterward surfaced a pre-existing, load-dependent flake in `locker_wish_filter_test.rb`'s shared `assert_current_choice` helper (a Turbo-frame `aria-current` async race, hitting a different unrelated test each run) — untouched by this feature and reproduced with 100% pass rate whenever run in isolation or combined with this feature's own system tests

**Checkpoint**: The feature is fully functional and independently testable — this is the entire spec.

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: The evidence the Constitution requires at the point of merge.

- [X] T013 [P] Run `bin/rubocop` and resolve every offence with no suppressions; any `rubocop:disable` needs an inline comment justifying it (Principle I)
- [X] T014 Review the new code against Principle I: `reciprocal_match?` lives once, on the model that already owns `saved_floor`; the controller keeps its existing read-params/build-list/render shape with one more once-per-request read; no comparison logic is duplicated in the view. Confirmed by re-reading the diff: 8 lines in `locker_wish.rb` (one documented predicate), 7 lines in the controller (two attribute reads following the exact `@viewer_in_progress` pattern), 7 lines in the view (one conditional, all comparison logic delegated to the model). No new CSS, no new class, no logic duplicated across files
- [ ] T015 Walk `quickstart.md` end to end against a running `bin/dev` — **NOT DONE**: needs a human at a browser. The same scenarios are covered automatically by T004–T008, but a few minutes in a real browser is still worth it before merge
- [X] T016 Write the PR description (`PR.md`) carrying what the constitution requires: the Principle III note that `.badge`/`.badge-success` is reused verbatim with no new visual pattern, the accessibility evidence from T008's axe-core pass, and the Principle IV query-count evidence from T005. Target branch `dev`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: N/A for this feature — nothing sits between Setup and the one user story
- **User Story 1 (Phase 3)**: Depends on Setup (needs the two reciprocating fixture pairs)
- **Polish (Phase 4)**: Depends on Phase 3 being complete

### Within User Story 1

- Tests (T004–T008) are written first and must fail before implementation lands (Principle II)
- The model method (T009) and the controller read (T010) are independent of each other and can be
  written in either order or in parallel; the view (T011) depends on both
- The story ends with a full-suite run (T012) before Polish begins

### Parallel Opportunities

- **Phase 1**: T001 and T002 touch different fixture files — parallel. T003 gates on both
- **Phase 3 tests**: T004, T005, T006, T007 and T008 touch four distinct files (T005 and T007 share
  `locker_wishes_controller_test.rb`, so those two serialise on each other; the rest are independent)
- **Phase 3 implementation**: T009 (`locker_wish.rb`) and T010 (the controller) touch different files
  and neither reads the other's code, only the ivars/method they each expose — parallel. T011 (the
  view) depends on both and is not parallel with them
- **Phase 4**: T013 is independent of the others; T014–T016 are sequential review/writing steps

---

## Parallel Example: User Story 1 tests

```bash
# Independent files, expected to fail:
Task: "Add reciprocal_match? tests to test/models/locker_wish_test.rb"
Task: "Add the visible-text system test to test/system/locker_wish_test.rb"
Task: "Extend test/system/accessibility_test.rb with a badge-present axe pass"

# These two share one file and serialise on each other:
Task: "Add badge presence/absence, multi-match and query-count tests to test/controllers/locker_wishes_controller_test.rb"
Task: "Add the cancel-then-reload re-evaluation test to test/controllers/locker_wishes_controller_test.rb"
```

## Parallel Example: User Story 1 implementation

```bash
# Two independent files:
Task: "Add reciprocal_match? to app/models/locker_wish.rb"
Task: "Add @viewer_current_floor / @viewer_wish_floor to LockerWishesController#load_wish_list"
```

---

## Implementation Strategy

### MVP First (and only)

1. Phase 1 — the two reciprocating fixture pairs, suites green
2. Phase 3 — the predicate, the controller reads, the badge in the view
3. **STOP and VALIDATE**: `quickstart.md` sections 1–4
4. Phase 4 — rubocop, review, PR description
5. Shippable: the entire feature

There is no incremental-delivery ladder here — one user story is the whole spec.

---

## Notes

- **No migration, no route change.** If either appears, something has diverged from `data-model.md`
- The badge is a sibling of the cell's existing content, never a replacement (T011). If a test starts
  asserting the "Propose swap" button or "Proposal pending" text is gone when the badge appears, the
  bug is in T011, not the test
- **`erin` is off-limits for this feature.** She already exists (floor `"5"`, no locker, no wish) and
  is asserted against by feature 010's homepage test. Use `henry`/`iris` for anything this feature adds
- `test/system/locker_wish_test.rb` gains one test (T006) and is otherwise unedited — that is the
  standing evidence that this feature changes nothing about row content, order, or swap eligibility
- `[P]` means different files and no dependency on an unfinished task
- Commit after each task or logical group; target `dev`, never push to it directly
