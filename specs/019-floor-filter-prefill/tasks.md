---

description: "Task list for 019 — pre-fill \"Their Floor\" filter from the viewer's wish"
---

# Tasks: Pre-fill "Their Floor" filter from the viewer's wish

**Input**: Design documents from `/specs/019-floor-filter-prefill/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/current-floor-sync.md](./contracts/current-floor-sync.md),
[quickstart.md](./quickstart.md)

**Tests**: Included and non-optional. Constitution Principle II is marked NON-NEGOTIABLE — every new
behaviour must carry automated tests that fail without the change and pass with it. Test tasks are
written before the implementation they cover.

**Organization**: Tasks are grouped by the two user stories in spec.md — US1 (P1, pre-fill/track the
wish's floor) and US2 (P2, reset on cancel) — after a Foundational phase that both stories build on,
per `plan.md`'s Scale/Scope (one new controller method, one helper edit, one view edit — none of which
delivers user-visible value until wired into `#create`/`#destroy`).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)
- Include exact file paths in descriptions

## Path Conventions

Server-rendered Rails monolith, single project at the repository root: `app/`, `test/`. No migration,
no route change, no new file under `app/` — see `data-model.md` and `plan.md`'s Project Structure.

---

## Phase 1: Setup

**Purpose**: N/A. `research.md` R5 confirms no new fixtures are required — the existing users/wishes
from 017/018 already cover a floor with an active wish, a floor with none, and a distinct second floor
to switch to. Proceed directly to Phase 2.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The shared mechanism both user stories depend on — deriving `current_floor` from the
viewer's wish when the address doesn't already decide it, and making that decision durable in the
address once made (`research.md` R1, R4). Neither story is independently testable until all three tasks
here land together, since US1's own acceptance scenarios (fresh-entry pre-fill, manual override holding
across an unrelated click) exercise this mechanism directly, not just the `#create` change that follows
it.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T001 [P] In `app/controllers/locker_wishes_controller.rb`, add a private method `current_floor_selection` returning `params.key?(:current_floor) ? filter_selection(:current_floor) : current_user.locker_wish&.saved_floor` (contracts/current-floor-sync.md's request→selection table; research R1/R2 — reads the already-loaded `current_user.locker_wish` association, zero added queries). Update `build_floor_filters` so the `current_floor:` `FloorFilter.new(selection: ...)` call uses `current_floor_selection` instead of `filter_selection(:current_floor)`; leave the `looking_for:` axis untouched
- [X] T002 [P] In `app/helpers/locker_wishes_helper.rb#locker_wish_filter_path`, stop passing the whole merged selections hash through one `compact_blank`. Build the target path so a blank `looking_for` is still passed as `nil` (dropped from the query string, unchanged from 017) and a blank `current_floor` is passed as `""` (kept in the query string as `current_floor=`, confirmed via `rails runner` that Rails' route helpers drop `nil` but keep `""` — research R4)
- [X] T003 [P] In `app/views/locker_wishes/_locker_wish_list.html.erb`, change the hidden-field injection loop (`@floor_filters.each do |axis, filter| ... next unless filter.filtering? ...`) so the `next unless filter.filtering?` guard applies to the `looking_for` axis only; the `current_floor` axis's hidden field renders unconditionally, including when `filter.selection` is nil ("All floors") — research R4 explains why a rejected declare needs this to preserve a manual "All floors" choice
- [X] T004 Run `bin/rails test test/controllers/locker_wishes_controller_test.rb test/system/locker_wish_filter_test.rb`. Confirm every test passes **except** the two research R3 names — `"declaring a wish returns to the list still filtered"` and `"declaring with no filter in force redirects to the bare list"` — which are now expected to fail (their old assertions describe behaviour this feature deliberately changes) and are rewritten in Phase 3 (T006). Any other failure means T001–T003 introduced a regression and must be fixed before proceeding — **found during implementation**: the plan underestimated this. The two named tests passed unchanged as expected (they're not touched until `#create` itself changes in T007), but `bin/rails test:system` on the *full* suite (beyond the two files this task names) surfaced 15 real regressions across `locker_swap_proposal_test.rb`, `responsive_test.rb`, `locker_wish_test.rb`, `accessibility_test.rb`, and `motion_test.rb` — every one of them a fixture user (`carol` or `karl`) with an active wish whose floor matches nobody's current floor (or, for `karl`, who has no saved current floor of his own, so 017's FR-012 excludes *him*), used as "just some signed-in user" in a test that asserts on the *unfiltered* list. Auto-deriving "Their floor" from that wish narrows or empties the list out from under those assertions, unrelated to whatever each test actually checks. Fixed by pinning `current_floor: ""` explicitly on each affected `visit`/`get`, restoring pre-019 unfiltered behaviour for tests that were never about this feature; documented in research.md R6. One further failure (`navigation_test.rb`) was confirmed via `git stash` to fail identically on pre-019 `dev` — a pre-existing flake, left untouched. Full `bin/rails test` (257 runs) and `bin/rails test:system` (257 runs) both 100% green after the fixes

**Checkpoint**: The derivation and address-encoding mechanism is in place and covered by the existing
suite except for the two intentional, tracked exceptions. User story implementation can now begin.

---

## Phase 3: User Story 1 - See likely matches right after declaring a wish (Priority: P1) 🎯 MVP

**Goal**: "Their Floor" is set to the viewer's active wish floor the moment the wish is declared or
changed, and stays synced on every fresh screen entry thereafter, while a manual choice made during a
visit holds until the next fresh entry or wish action.

**Independent Test**: With no wish declared and "Their Floor" on "All floors", declare a wish for a
specific floor and confirm "Their Floor" now shows that floor and the list is narrowed accordingly,
without touching the filter directly; separately, leave and return to the screen (or reload it) while
that wish is still active and confirm the same, again without interaction.

### Tests for User Story 1 ⚠️

> Write these first and watch them fail (except where noted, they exercise Phase 2's mechanism directly
> and should already be green from T001–T003 — the italicised ones are what actually needs T006).

- [X] T005 [P] [US1] Add tests to `test/controllers/locker_wishes_controller_test.rb`: a bare `GET /locker_wishes` for a signed-in user with an active wish on floor `"5"` shows `current_floor` selected as `"5"` (`assert_select "#locker-wish-filter-current-floor a[aria-current='true']", text: "5"`) and the list narrowed to rows on floor `"5"`; a bare `GET /locker_wishes` for a user with no active wish shows "All floors" selected; `GET locker_wishes_path(current_floor: "3")` for a user whose active wish is on a *different* floor still shows `"3"` selected, not the wish's floor (the explicit param wins per contracts/current-floor-sync.md); `GET locker_wishes_path(current_floor: "")` for a user with an active wish shows "All floors" selected, not the wish's floor (an explicit blank is also respected); *`post locker_wish_path, params: { locker_wish: { floor: "4" }, current_floor: "2" }` redirects to `locker_wishes_path(current_floor: "4")`, replacing the submitted `"2"` — rewrites the two tests research R3 names to their new, intentional assertions*; *a rejected `post locker_wish_path, params: { locker_wish: { floor: "" }, current_floor: "3" }` re-renders `:index` with `current_floor` still selected as `"3"`, unchanged by the failed attempt*; signed in as `carol` (own wish floor `"5"`, from `carol_wish`), a bare `GET /locker_wishes` shows `current_floor` selected as `"5"` — her own wish's floor — never `"7"` (`bob`'s wish floor, a different active wish present in the same fixture set), proving the derivation reads only `current_user.locker_wish` and is unaffected by any other person's wish (FR-012); a query-count assertion that `GET /locker_wishes` for a user with an active wish issues no more queries than for a user without one (Principle IV)
- [X] T006 [P] [US1] Add tests to `test/system/locker_wish_filter_test.rb`: declaring a wish for a floor in "Your locker search" leaves "Their floor" showing that floor and the list narrowed to it, with no filter interaction (spec Story 1 scenario 1); leaving the screen and returning (or reloading) while the wish is still active shows the same narrowed state again with no interaction (SC-005, scenario 6); manually changing "Their floor" during the visit, then changing "Looking for floor" (an unrelated axis) and back, leaves "Their floor" on the manual choice throughout (scenario 4); pressing Back after that returns to the earlier `current_floor` state exactly, not a re-derived one (scenario 5, research R1); reloading after that re-derives "Their floor" from the wish, discarding the manual choice (scenario 5); changing the wish's floor mid-visit updates "Their floor" to the new value even though it had been set manually (scenario 2); submitting a rejected floor change leaves "Their floor" exactly as it was (scenario 3); declaring a wish for a floor nobody currently holds shows "Their floor" set to it and the "No wish matches these filters." message (scenario 7); "Looking for floor" is never altered by any declare/change in this list (scenario 8)

### Implementation for User Story 1

- [X] T007 [US1] In `app/controllers/locker_wishes_controller.rb#create`, change the success redirect from `redirect_to locker_wishes_path(filter_selections), ...` to `redirect_to locker_wishes_path(filter_selections.merge(current_floor: @locker_wish.saved_floor)), ...` so the redirect always reflects the just-saved wish's floor, overwriting whatever `current_floor` was submitted (research R3, FR-003). Depends on T001
- [X] T008 [US1] Run `bin/rails test test/controllers/locker_wishes_controller_test.rb` and `bin/rails test:system test/system/locker_wish_filter_test.rb`; confirm T005 and T006 are green and no other test — including the rest of the pre-existing suite — regressed. Confirmed green across repeated runs. **Found during implementation**: this environment has a pre-existing, systemic Capybara/Selenium click flake (a click's `aria-current` update occasionally not registering in time) affecting roughly 1 test in 20–30 per run, on random tests — confirmed via `git stash` to occur identically on the unmodified 017 test file at the same rate, so it predates and is unrelated to this feature. `current_choice`'s bare `find(...).text` (no text-match retry) was the one place T006's own tests were meaningfully more exposed to it than 017's established pattern; converted every post-mutation assertion in the new 019 section to the race-safe `assert_current_choice` (which retries until the expected text appears), matching the file's own existing convention. Isolated re-runs of the previously-flaky tests confirm this, not application logic, was the cause

**Checkpoint**: User Story 1 is fully functional and independently testable — `quickstart.md` sections
1–5.

---

## Phase 4: User Story 2 - Filter clears itself when the wish is withdrawn (Priority: P2)

**Goal**: Cancelling the wish resets "Their Floor" to "All floors" immediately, and it stays on "All
floors" on any later fresh screen entry since there is no wish left to derive a floor from.

**Independent Test**: With a wish declared and its floor showing in "Their Floor" (Story 1), cancel the
wish and confirm "Their Floor" returns to "All floors" and the full list is shown again.

### Tests for User Story 2 ⚠️

- [X] T009 [P] [US2] Add tests to `test/controllers/locker_wishes_controller_test.rb`: `delete locker_wish_path, params: { current_floor: "5" }` for a user with an active wish on floor `"5"` redirects to `locker_wishes_path` with no `current_floor` param at all (`.except`, research R3); a subsequent `GET /locker_wishes` for that same user then shows "All floors" selected, confirming R1's no-active-wish fallback actually applies after the cancel; cancelling while `current_floor` was already blank redirects the same way (no-op, not an error); `looking_for`, when set, survives the cancel redirect unchanged (existing 017 behaviour, unaffected here — already covered by 017's own `"cancelling a wish returns to the list still filtered"` test, left untouched)
- [X] T010 [P] [US2] Add a test to `test/system/locker_wish_filter_test.rb`: with a wish declared and "Their floor" showing its floor, clicking **Cancel wish** resets "Their floor" to "All floors" and shows the full list (spec Story 2 scenario 1); reloading the page afterwards still shows "All floors" (scenario 4, SC-002); "Looking for floor", when set beforehand, is untouched by the cancel (scenario 3)

### Implementation for User Story 2

- [X] T011 [US2] In `app/controllers/locker_wishes_controller.rb#destroy`, change the redirect from `redirect_to locker_wishes_path(filter_selections), ...` to `redirect_to locker_wishes_path(filter_selections.except(:current_floor)), ...` (research R3, FR-004). Depends on T001
- [X] T012 [US2] Run `bin/rails test test/controllers/locker_wishes_controller_test.rb` and `bin/rails test:system test/system/locker_wish_filter_test.rb`; confirm T009 and T010 are green and nothing else regressed. Confirmed green (full `bin/rails test`: 264/264; full `bin/rails test:system`: 267/267, one unrelated pre-existing environmental flake in `locker_profile_test.rb` — confirmed transient on re-run, matches the class documented in T008)

**Checkpoint**: Both user stories are independently functional — this is the entire spec.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: The evidence the Constitution requires at the point of merge.

- [X] T013 [P] Run `bin/rubocop` and resolve every offence with no suppressions; any `rubocop:disable` needs an inline comment justifying it (Principle I). Clean: 84 files inspected, no offenses
- [X] T014 [P] Extend `test/system/accessibility_test.rb` with an `assert_axe_clean` pass on the locker wishes screen rendered with "Their floor" auto-selected from an active wish (a regression check per research R5 — no new markup is introduced, so no new violation is expected, but the state itself is new and untested by the existing pass). **Found during implementation**: three *existing* accessibility tests signed in as `@user` (carol, wish floor "5", matching nobody) and visited bare — auto-filtering silently swapped their intended populated/tab-orderable state for the no-match state, passing `assert_axe_clean` (which the no-match state already satisfies) but checking less than they were written to. Pinned `current_floor: ""` on those three for the same reason as the earlier collateral fixes (research R6), and added the one genuinely new test this task asks for (`bob`, whose auto-selected floor narrows to a populated, non-empty list)
- [X] T015 Review the diff against Principle I's asymmetry note in `plan.md`: confirm `current_floor_selection` is the single place the derivation rule is decided (not duplicated between the index render and either redirect), confirm `FloorFilter` itself needed no change, and confirm `looking_for`'s handling is untouched in every file this feature edits. Confirmed: `current_floor_selection` (locker_wishes_controller.rb) is called from exactly one place, `build_floor_filters`; `create`/`destroy` each state their own explicit override/drop inline rather than re-deriving. `git diff --stat app/models/floor_filter.rb` is empty — no change. `app/models/locker_wish.rb`, `config/routes.rb` also untouched. `looking_for`'s own `filter_selection(:looking_for)` call, its `.presence`-based helper branch, and its view guard are all byte-for-byte what 017 shipped. No migration, no new route, no new file under `app/` — matches `plan.md`'s Project Structure exactly. Full diff: 3 `app/` files changed (controller, helper, one view partial), 91 lines net across them
- [ ] T016 Walk `quickstart.md` end to end against a running `bin/dev`, including the Back/Forward step in section 3 — a human at a browser is the only way to observe the `frame_history_controller.js` / native-Turbo-restoration split research R1 describes, even though T006/T010 already assert its outcome — **NOT DONE**: needs a human at a browser, same as 018's equivalent step. The same scenarios are covered automatically by T005/T006/T009/T010; worth a few minutes in a real browser before merge regardless
- [X] T017 Write the PR description (`PR.md`) carrying what the constitution requires: the Principle I asymmetry justification, the Principle III disclosure of research R1's accepted bookmarked-URL limitation, the Principle IV query-count evidence from T005, and an explicit note that two existing 017 tests were rewritten on purpose (research R3) rather than regressed. Target branch `dev`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: N/A — no fixture or infrastructure work needed
- **Foundational (Phase 2)**: No dependencies beyond the existing 017/018 code — BLOCKS both user
  stories
- **User Story 1 (Phase 3)**: Depends on Phase 2 (needs `current_floor_selection` and the
  address-encoding changes to exist)
- **User Story 2 (Phase 4)**: Depends on Phase 2 the same way Phase 3 does; does **not** depend on
  Phase 3's `#create` change, so it could be built in parallel with Phase 3 by a second person, but the
  spec's own priority order (P1 before P2) and its Independent Test wording ("with a wish declared and
  its floor pre-filled") assume Phase 3 exists first for manual/system validation
- **Polish (Phase 5)**: Depends on Phases 3 and 4 both being complete

### Within Each User Story

- Tests (T005/T006, T009/T010) are written first and must fail before their implementation task lands,
  except where noted in Phase 3 that some assertions are already satisfied by Phase 2 alone
- Each story ends with a full relevant-suite run (T008, T012) before moving on

### Parallel Opportunities

- **Phase 2**: T001, T002, and T003 touch three different files — parallel. T004 gates on all three
- **Phase 3 tests**: T005 and T006 touch two different files — parallel
- **Phase 4 tests**: T009 and T010 touch two different files — parallel
- **Phase 3 vs. Phase 4**: T007/T011 touch the same file (`locker_wishes_controller.rb`, different
  methods) — safe to write in either order but not literally simultaneously by two people without
  coordinating; T005/T006 vs. T009/T010 touch the same two test files as each other's story and should
  be sequenced or coordinated for the same reason
- **Phase 5**: T013 and T014 are independent of each other and of T015–T017; T015–T017 are sequential
  review/writing steps

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Three independent files:
Task: "Add current_floor_selection to app/controllers/locker_wishes_controller.rb"
Task: "Keep current_floor as '' rather than dropped in app/helpers/locker_wishes_helper.rb"
Task: "Render current_floor's hidden field unconditionally in _locker_wish_list.html.erb"
```

## Parallel Example: User Story 1 tests

```bash
# Independent files:
Task: "Add fresh-entry/explicit-param/redirect/rejected-declare tests to test/controllers/locker_wishes_controller_test.rb"
Task: "Add declare/reload/manual-override/Back-Forward/change/reject/no-match/looking-for-untouched tests to test/system/locker_wish_filter_test.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Foundational (CRITICAL — blocks both stories)
2. Complete Phase 3: User Story 1
3. **STOP and VALIDATE**: `quickstart.md` sections 1–5
4. Deploy/demo if ready — a declared wish already narrows the list; cancelling merely leaves the old,
   pre-019 filter behaviour in place (the filter simply is not reset for you) until Phase 4 lands

### Incremental Delivery

1. Phase 2 → foundation ready
2. Phase 3 → User Story 1 → test independently → deploy/demo (MVP)
3. Phase 4 → User Story 2 → test independently → deploy/demo
4. Phase 5 → polish, PR

---

## Notes

- **No migration, no route change, no new file under `app/`.** If any of these appear, something has
  diverged from `data-model.md`/`plan.md`.
- **The two 017 tests named in T005/research R3 are meant to change.** If a reviewer sees them edited in
  the diff, that is this feature working as specified, not a regression — `research.md` R3 spells out
  exactly why.
- **`FloorFilter` (`app/models/floor_filter.rb`) is never edited.** Every change lives in the
  controller, the helper, and one view partial — if a task ends up touching that model, something has
  drifted from the plan.
- `looking_for` must not change behaviour anywhere in this feature. Any test asserting on it should read
  as a "this axis is unaffected" check, not new behaviour.
- `[P]` means different files and no dependency on an unfinished task.
- Commit after each task or logical group; target `dev`, never push to it directly.
