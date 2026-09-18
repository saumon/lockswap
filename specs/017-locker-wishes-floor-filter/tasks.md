---

description: "Task list for 017 — Filter locker wishes by floor"
---

# Tasks: Filter locker wishes by floor

**Input**: Design documents from `/specs/017-locker-wishes-floor-filter/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/locker-wish-filter.md](./contracts/locker-wish-filter.md)

**Tests**: Included and non-optional. Constitution Principle II is marked NON-NEGOTIABLE — every new
behaviour must carry automated tests that fail without the change and pass with it — and `research.md`
R7 assigns each requirement to a level. Test tasks are written before the implementation they cover.

**Organization**: Tasks are grouped by user story so each can be implemented, tested and shipped on
its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

Server-rendered Rails monolith, single project at the repository root: `app/`, `config/`, `test/`.
No migration, no route change — see `data-model.md`.

---

## Phase 1: Setup (Shared Test Data)

**Purpose**: Give every suite below something to filter. The existing fixtures have looked-for floors
`7` and `5` only, which cannot demonstrate the ordering rule or the no-saved-floor case.

- [X] T001 [P] Add two accounts to `test/fixtures/users.yml`: `judy` (`floor: "10"`, `locker_number: "J-10"`) and `karl` (no `floor`, no `locker_number`), each with an explicit `created_at` continuing the existing one-day-apart sequence, and a comment naming 017 as the feature that needed them — matching the file's existing convention of explaining why each fixture exists. (`frank` and `grace` are taken: they are the 013/015 administrator fixtures)
- [X] T002 [P] Add two wishes to `test/fixtures/locker_wishes.yml`: `judy_wish` (`floor: "10"`) and `karl_wish` (`floor: "3"`), with a comment noting that `10` against `3`/`5`/`7` is what makes FR-007's numeric ordering observable, and that `karl` is the wisher with no saved floor that FR-012 is asserted against
- [X] T003 Run `bin/rails test` and `bin/rails test:system` and confirm the two new fixtures break nothing — `test/system/admin_users_test.rb` lists every registered account, and the homepage and wish-list suites assert on row counts and ordering; fix any fixture-count assumption surfaced here before writing a line of feature code

**Checkpoint**: The suites are green on the enlarged fixture set, so any later red is the feature's own.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The query vocabulary, the shared filter object, and the frame/markup both axes render
into. Nothing here is specific to one axis.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T004 Extract the "exclude people with an exchange in progress" rule out of `all_locker_wishes` in `app/controllers/locker_wishes_controller.rb` into a `LockerWish.active` scope in `app/models/locker_wish.rb` — `where.not(user_id: LockerSwapProposal.in_progress_user_ids).includes(:user).order(created_at: :asc)` — and call it from the controller. Pure refactor: no behaviour change, and `test/system/locker_wish_test.rb` must stay green without edits
- [X] T005 [P] Add tests for `LockerWish.active` in `test/models/locker_wish_test.rb`: it excludes the wish of a user with an accepted proposal in either the requester or the recipient role, includes everyone else, and returns oldest declaration first
- [X] T006 [P] Create the `FloorFilter` PORO in `app/models/floor_filter.rb` (plain Ruby, no Active Record). Constructor takes the raw selection and the available floors; a `nil`, empty or whitespace-only selection normalises to `nil` so `?looking_for=` means "all floors" (FR-003). Public surface per `data-model.md`: `#selection`, `#filtering?`, `#current?(floor)`, `#choices`
- [X] T007 [P] Create `test/models/floor_filter_test.rb` covering FR-007's ordering key `[integer?(v) ? 0 : 1, integer_value_or_0, v]` where `integer?` is `Integer(v, exception: false)` being non-nil: `"-1"` sorts before `"1"`; `"3"` before `"10"`; `"RDC"` after every number; `"3.5"` lands in the alphabetical group because it is not an Integer; `"3"` and `"03"` sit adjacent in a stable, repeatable order
- [X] T008 [P] Add tests to `test/models/floor_filter_test.rb` for FR-015/FR-020: a selection absent from the available floors is appended to `#choices` and reports `#current?` true; a blank selection gives `#filtering?` false and no appended choice; a selection already present is not duplicated
- [X] T009 Add the filter bar styles to `app/assets/tailwind/application.css` inside an existing `@layer components` block: `.filter-bar`, `.filter-choice`, and the current state via `.filter-choice[aria-current]`, reusing the existing colour and spacing tokens rather than new values. Include `turbo-frame { display: block; }` — a custom element is `display: inline` by default, which would disturb the card layout. Any media query must use only `48rem` or `47.999rem`, enforced by `test/stylesheet_breakpoint_test.rb`
- [X] T010 Create `app/helpers/locker_wishes_helper.rb` with a method returning the path for one filter choice while preserving the *other* axis's current value, omitting any blank value entirely so that clearing both yields the bare `locker_wishes_path` (FR-017, contract "Redirect contract")
- [X] T011 [P] Create `app/views/locker_wishes/_floor_filter.html.erb` rendering one axis from a `FloorFilter`: a `<nav>` with its own `aria-label` naming what it filters (FR-002, FR-021) — the visible labels are the list's own column terms, "Looking for floor" and "Their floor"; "current floor" is the parameter name only and must not reach the screen — an "All floors" link first (FR-003), then one link per `#choices` in order, each carrying `aria-current="true"` when `#current?` (FR-015). Links only — no `<select>`, no submit control, no JavaScript (FR-008, research R2)
- [X] T012 Wrap the list card in `app/views/locker_wishes/_locker_wish_list.html.erb` in `<turbo-frame id="locker-wish-list" data-turbo-action="advance">`, moving the existing `id="locker-wish-list"` from the inner `div` onto the frame so `test/system/accessibility_test.rb` and `test/system/motion_test.rb` keep matching it, and add the `#locker-wish-filters` container that the two groups render into, positioned with the list and clear of the declare control (FR-001). `locker_wishes/_locker_wish_panel` stays outside the frame in `app/views/locker_wishes/index.html.erb` so a filter change never replaces it (FR-009). Then give the one form now inside the frame — the "Propose swap" `button_to` — `data: { turbo_frame: "_top" }`. Without it, `LockerSwapProposalsController#create`'s redirect to `locker_wishes_path` renders back into the frame: the "Swap proposal sent." toast never appears (007) and the frame drops both selections from the address (FR-014)
- [X] T013 Run `bin/rails test:system test/system/locker_wish_test.rb` plus `test/system/locker_swap_proposal_test.rb`, `test/system/notification_test.rb`, and the accessibility and motion suites, and confirm the frame wrapper changed nothing visible — this is the moment a stray `display: inline`, a moved id, or a form submitting into the frame instead of `_top` would show up, before any filtering exists to blame it on

**Checkpoint**: The screen looks and behaves exactly as before, but now has a frame, a filter object and a query vocabulary to build on.

---

## Phase 3: User Story 1 — Narrow by the floor people are looking for (Priority: P1) 🎯 MVP

**Goal**: One working filter on the screen's headline column, so a viewer can isolate the people
searching for a given floor — and, by picking their own floor, the people a swap with them could suit.

**Independent Test**: With wishes across looked-for floors `3`, `5`, `7` and `10`, choose `3` and
confirm only the `3` rows remain, with row content, order and swap controls untouched. The second
axis does not exist yet and is not needed.

### Tests for User Story 1 ⚠️

> Write these first and watch them fail.

- [X] T014 [P] [US1] Create `test/system/locker_wish_filter_test.rb` covering User Story 1 scenarios 1–6: selecting a floor leaves exactly the matching rows; a shown row keeps its person, floors, locker and swap cell; the viewer's own row appears when it matches; the choices read `3`, `5`, `7`, `10` with `10` last (FR-007); and moving across the choices by keyboard without activating one does not re-filter (FR-008)
- [X] T015 [P] [US1] Add tests to `test/models/locker_wish_test.rb` for `LockerWish.looking_for`: an exact match returns only those wishes; a blank or nil argument is a no-op returning all of `active`, which is FR-010's "one filter set, the other on all floors"; a value nobody wants returns empty. Add tests for `looked_for_floors`: distinct values only, blanks dropped, derived from `active` rather than from any filtered relation (FR-006)
- [X] T016 [P] [US1] Add tests to `test/controllers/locker_wishes_controller_test.rb`: `GET /locker_wishes?looking_for=3` renders only matching rows; `?looking_for=` behaves as unfiltered; and for FR-019, a successful `POST /locker_wish`, a rejected `POST` (blank floor, re-rendering `:index` with status `422`) and a `DELETE /locker_wish` each keep the selection in force, with the redirect carrying it and a blank selection omitted from the redirect entirely

### Implementation for User Story 1

- [X] T017 [US1] Add `looking_for(floor)` and `looked_for_floors` to `app/models/locker_wish.rb` per `data-model.md`: the scope matches `locker_wishes.floor` exactly and is a no-op on a blank argument; the choice query returns the distinct non-blank floors across `active`, at most one row per floor
- [X] T018 [US1] In `app/controllers/locker_wishes_controller.rb#index`, read `params[:looking_for]`, build a `FloorFilter` from it and `LockerWish.looked_for_floors`, and apply `looking_for` to the list. Keep `locker_wish_params` as `params.expect(locker_wish: [ :floor ])` — the filter value is read separately and never reaches the record (research R5)
- [X] T019 [US1] Render the "looking for floor" group in `app/views/locker_wishes/_locker_wish_list.html.erb` by passing that `FloorFilter` to `locker_wishes/_floor_filter`, inside `#locker-wish-filters` and above the table (FR-001)
- [X] T020 [US1] Implement FR-019 generically over *all* filter parameters so the second axis needs no rework: carry the current selections as hidden fields in `app/views/locker_wishes/_locker_wish_form.html.erb`, as `params:` on the "Cancel wish" `button_to` in `app/views/locker_wishes/_locker_wish_panel.html.erb`, and on both redirects in `LockerWishesController#create` and `#destroy`, omitting blank values
- [X] T021 [US1] Make the rejected-declare path keep the filters: `#create`'s `render :index, status: :unprocessable_entity` must rebuild the same `FloorFilter`s and the same filtered list as `#index` (spec Edge Cases, last bullet)
- [X] T022 [US1] Run `bin/rails test` and `bin/rails test:system` — T014–T016 green, every pre-existing suite still green

**Checkpoint**: A shippable filter. One axis, working end to end, surviving the viewer's own writes.

---

## Phase 4: User Story 2 — Narrow by the floor people currently occupy (Priority: P2)

**Goal**: The other direction — who currently holds a locker on the floor the viewer wants.

**Independent Test**: With the first axis left on "All floors" throughout, choose a current floor and
confirm only people whose saved locker is on it remain, and that the wisher with no saved floor is
excluded without an error.

### Tests for User Story 2 ⚠️

- [X] T023 [P] [US2] Add User Story 2 scenarios 1–3 to `test/system/locker_wish_filter_test.rb`: selecting a current floor leaves only people saved on it; the wisher with no saved floor is absent and nothing errors; returning that group to "All floors" brings them back with their "Not set" cell intact
- [X] T024 [P] [US2] Add tests to `test/models/locker_wish_test.rb` for `LockerWish.owner_on_floor`: matches on the joined `users.floor` exactly; a user with `floor` nil or `''` never matches a specific value (FR-012); blank argument is a no-op (FR-010). Add tests for `owner_floors`: distinct non-blank `users.floor` values across the owners of `active` wishes, with a floor nobody holds absent from the result

### Implementation for User Story 2

- [X] T025 [US2] Add `owner_on_floor(floor)` and `owner_floors` to `app/models/locker_wish.rb` per `data-model.md`, joining `users` so that `floor IS NULL` or `''` simply fails to match rather than being special-cased (FR-012)
- [X] T026 [US2] In `app/controllers/locker_wishes_controller.rb#index`, read `params[:current_floor]`, build the second `FloorFilter` from `LockerWish.owner_floors`, and compose `owner_on_floor` onto the relation
- [X] T027 [US2] Render the "current floor" group in `app/views/locker_wishes/_locker_wish_list.html.erb` as the second `locker_wishes/_floor_filter` inside `#locker-wish-filters` (FR-001), with the label wording matching the list's own "Their floor" column (FR-002)
- [X] T028 [US2] Run `bin/rails test` and `bin/rails test:system`; confirm FR-019 already carries the new parameter with no change to T020's code, and fix T020 generically rather than per-axis if it does not

**Checkpoint**: Both axes work on their own.

---

## Phase 5: User Story 3 — Combine both filters, and clear them (Priority: P2)

**Goal**: The two filters combine into a shortlist, each clears independently, and changing one costs
no scrolling and leaves the address correct.

**Independent Test**: Set both, confirm only rows matching both remain, then clear each in turn and
watch the list widen back to identical-to-unfiltered.

### Tests for User Story 3 ⚠️

- [X] T029 [P] [US3] Add User Story 3 scenarios 1–4 to `test/system/locker_wish_filter_test.rb`: both set shows only rows matching both and hides a row matching one (FR-011); clearing one shows everything matching the other; clearing both restores the original list and order; a first visit has neither set
- [X] T030 [P] [US3] Add User Story 3 scenarios 5–6: with the page scrolled down to the list, changing a filter leaves the declare panel and the scroll position untouched and replaces only the list region (FR-009, SC-006); and opening one group after the other is set shows the same floors in the same order as before (FR-006, scenario 6)
- [X] T031 [P] [US3] Add a browser back/forward assertion to `test/system/locker_wish_filter_test.rb`: after two filter changes, Back returns the previous filter state with list and controls in agreement, and the address matches (FR-018)
- [X] T032 [P] [US3] Add a test to `test/controllers/locker_wishes_controller_test.rb` that `?looking_for=X&current_floor=Y` returns the intersection (FR-011), and that each parameter alone behaves as the corresponding single-axis request (FR-010)

### Implementation for User Story 3

- [X] T033 [US3] Verify FR-017 needs no code beyond T010, T018 and T026: from a view with both filters set, each "All floors" link must clear only its own axis and leave the other's value in the path, and clearing both must land on the bare `locker_wishes_path` with no empty parameters. If any of this fails, fix `app/helpers/locker_wishes_helper.rb` rather than adding a branch in the view — combining is emergent from the two axes, not a third mechanism
- [X] T034 [US3] Run `bin/rails test` and `bin/rails test:system`. If T030 fails on scroll position or on the panel being replaced, the cause is the frame boundary from T012, not the filtering — check that `_locker_wish_panel` is rendered outside the frame and that `data-turbo-action="advance"` is on the frame itself

**Checkpoint**: The feature is functionally complete for anyone who finds a match.

---

## Phase 6: User Story 4 — Recognise that a selection matches nobody (Priority: P3)

**Goal**: An empty result reads as an ordinary outcome, says so in its own words, and is one click
away from being undone.

**Independent Test**: Pick a combination nobody satisfies and confirm the no-match message appears,
worded differently from "Nobody is looking for a locker right now", with both selections still shown.

### Tests for User Story 4 ⚠️

- [X] T035 [P] [US4] Add User Story 4 scenarios 1–2 to `test/system/locker_wish_filter_test.rb`: a selection matching nothing shows `#locker-wish-list-no-match` and **not** `#locker-wish-list-empty`, with both selections still marked current; and with no active wishes at all, `#locker-wish-list-empty` shows and neither group offers a floor
- [X] T036 [P] [US4] Add a test to `test/controllers/locker_wishes_controller_test.rb` for FR-020: `?looking_for=NOPE` renders `200` with an empty list, does not fall back to the unfiltered list, and echoes `NOPE` back as the current selection
- [X] T037 [P] [US4] Add a test covering the spec's edge case where every wish matching a selection is cancelled: the floor is gone from the choices offered afresh, yet stays visible as the current selection for the viewer on it (FR-015, FR-004/FR-005 — this is the pair the clarify pass found in conflict)

### Implementation for User Story 4

- [X] T038 [US4] Add the no-match branch to `app/views/locker_wishes/_locker_wish_list.html.erb`: when either filter is `#filtering?` and the list is empty, render `#locker-wish-list-no-match` with wording distinct from the existing `#locker-wish-list-empty` (FR-016). Two separate ids, not one id with swapped text — a regression must not be able to satisfy the selector while saying the wrong thing (contract, "DOM contract")
- [X] T039 [US4] Confirm the T006 `FloorFilter` already appends an in-force selection missing from the available floors, so FR-020 and T037 need no view-level special case; if a branch is creeping into the view, move it into the PORO
- [X] T040 [US4] Run `bin/rails test` and `bin/rails test:system`

**Checkpoint**: All four user stories independently functional.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: The evidence the Constitution requires at the point of merge, plus the cross-screen
suites. These are merge gates, not nice-to-haves — Quality Gates in the constitution blocks the PR
without them.

- [X] T041 [P] Extend `test/system/accessibility_test.rb`: `assert_axe_clean` on the filtered list and on the no-match state, and assert the two groups carry distinct `aria-label`s and that the choice in force carries `aria-current="true"` (FR-021, SC-008). No new axe exemption may be added
- [X] T042 [P] Extend `test/system/responsive_test.rb`: below the 48rem breakpoint the filter bar wraps, the page does not scroll sideways, and the list still restacks into one card per wish (FR-023)
- [X] T043 Add the Principle IV evidence to `test/controllers/locker_wishes_controller_test.rb`: assert a filtered `GET /locker_wishes` issues no more queries than an unfiltered one, and that the added cost is the two constant `DISTINCT` queries rather than anything per row (plan, "Performance Goals")
- [X] T044 [P] Confirm `test/system/locker_wish_test.rb` and `test/system/locker_swap_proposal_test.rb` still pass **unedited** — that is the evidence for FR-013 and FR-014 that row content, ordering, eligibility and the swap flow are untouched (research R7). `test/system/access_control_test.rb` passing unedited is likewise the standing evidence for FR-022: the feature adds query parameters to an existing action, not a new route, so the existing `authenticate_user!` guard still covers it
- [X] T045 Run `bin/rubocop` and resolve every offence with no suppressions; any `rubocop:disable` needs an inline comment justifying it (Principle I)
- [ ] T046 Walk `quickstart.md` end to end against a running `bin/dev`, including the keyboard pass in section 7 and the narrow-width pass in section 8 — **NOT DONE**: needs a human at a browser. The same scenarios are covered automatically by `test/system/locker_wish_filter_test.rb`, `accessibility_test.rb` and `responsive_test.rb`, but a few minutes in a real browser is still worth it before merge
- [X] T047 Review the new code against Principle I: the ordering rule, the selection normalisation and the append-if-missing rule each live in `FloorFilter` once, not duplicated per axis in the view or the helper; the controller still reads as read-params-build-list-render
- [X] T048 Write the PR description (`PR.md`) carrying what the constitution requires: the Principle III justification for the two new patterns (first Turbo Frame; link-based filter bar instead of a `<select>`, because FR-008 forbids re-filtering on arrow-key traversal — WCAG 2.1 SC 3.2.2), the Principle IV query-count evidence from T043, and the accessibility note from T041. Target branch `dev`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup — **blocks every user story**
- **User Stories (Phases 3–6)**: All depend on Foundational
  - US1 (P1) is the MVP and ships alone
  - US2 (P2) is independent of US1 at the code level but shares the controller action and the list partial, so the two are best done in sequence by one person
  - US3 (P2) depends on **both** US1 and US2 existing — it is about combining them, so it is the one story that is not independent
  - US4 (P3) depends only on at least one axis existing; it can follow US1 directly if US2 slips
- **Polish (Phase 7)**: Depends on every story intended for this PR

### User Story Dependencies

- **US1 (P1)**: After Phase 2. No dependency on other stories. Shippable alone
- **US2 (P2)**: After Phase 2. No dependency on US1 in principle; in practice edits the same controller action and list partial
- **US3 (P2)**: After US1 **and** US2 — combining two filters requires two filters
- **US4 (P3)**: After US1 (or US2). Its "both selections" assertions need both axes; its single-axis assertions do not

### Within Each User Story

- Tests are written first and must fail before the implementation lands (Principle II)
- Model scopes before the controller; controller before the view
- Each story ends with a full-suite run before the next begins

### Parallel Opportunities

- **Phase 1**: T001 and T002 touch different fixture files — parallel. T003 gates on both
- **Phase 2**: T005, T006, T007, T008 and T011 are all separate files — parallel. T004 must land before T005 is meaningful; T009, T010 and T012 each touch a file of their own but T012 depends on T009's `turbo-frame { display: block; }` to look right
- **Phase 3–6**: The test tasks within each story (T014–T016, T023–T024, T029–T032, T035–T037) touch three distinct files and run in parallel. The implementation tasks within a story mostly serialise on `locker_wish.rb`, the controller and the list partial
- **Phase 7**: T041, T042 and T044 are separate files — parallel. T043 shares a file with earlier controller tests, so it lands after them
- **Across stories**: US1 and US2 could go to two people, but both edit `LockerWishesController#index` and `_locker_wish_list.html.erb`; the merge cost usually outweighs the parallelism on a change this size

---

## Parallel Example: Phase 2 Foundational

```bash
# Three independent files, no shared state:
Task: "Create FloorFilter PORO in app/models/floor_filter.rb"
Task: "Create test/models/floor_filter_test.rb ordering tests"
Task: "Create app/views/locker_wishes/_floor_filter.html.erb"
```

## Parallel Example: User Story 1 tests

```bash
# Three distinct test files, all expected to fail:
Task: "Create test/system/locker_wish_filter_test.rb — US1 scenarios 1-6"
Task: "Add looking_for / looked_for_floors tests to test/models/locker_wish_test.rb"
Task: "Add filter-param and FR-019 tests to test/controllers/locker_wishes_controller_test.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Phase 1 — fixtures, suites green
2. Phase 2 — `active` scope, `FloorFilter`, frame, filter partial, CSS
3. Phase 3 — the "looking for floor" axis end to end
4. **STOP and VALIDATE**: sections 1, 4, 6 and 7 of `quickstart.md`
5. Shippable: one filter on the screen's headline column, surviving declare and cancel

### Incremental Delivery

1. Setup + Foundational → the screen is unchanged but ready
2. + US1 → **MVP**, demo it
3. + US2 → the second axis, demo it
4. + US3 → combining, clearing, in-place updating
5. + US4 → the empty result reads correctly
6. Phase 7 → accessibility, responsive, performance evidence, PR

Each step leaves the screen working; none breaks the step before it.

---

## Notes

- **No migration, no route change.** If either appears, something has diverged from `data-model.md`
- The two empty states are two ids on purpose (T038) — `#locker-wish-list-empty` and
  `#locker-wish-list-no-match`. FR-016 requires distinct wording, and one id would let a regression
  pass the selector while showing the wrong message
- The filter is links, not a `<select>` (T011). If a `<select>` reappears, FR-008's keyboard rule and
  SC-008 go with it — see `research.md` R2
- `test/system/locker_wish_test.rb` must never need editing. The day it does, FR-013 or FR-014 has
  been broken
- `[P]` means different files and no dependency on an unfinished task
- Commit after each task or logical group; target `dev`, never push to it directly
