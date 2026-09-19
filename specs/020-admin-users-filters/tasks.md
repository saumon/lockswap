# Tasks: Users Screen — Locker Details and Filters

**Input**: Design documents from `/specs/020-admin-users-filters/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/admin-users-filter.md](./contracts/admin-users-filter.md), [quickstart.md](./quickstart.md)

**Tests**: Included — Constitution Principle II (Testing Standards, NON-NEGOTIABLE) requires every new
feature to include automated tests that fail without the change and pass with it. Write each test task
first and confirm it fails before its paired implementation task.

**Organization**: Tasks are grouped by user story (spec.md: US1 "See each account's locker, floor and
wish at a glance" — P1; US2 "Narrow the list to a specific locker, floor, role or email" — P1; US3
"Recognise that a filter combination matches nobody" — P3) so each can be implemented, tested, and
shipped independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- File paths are exact and relative to the repository root

## Path Conventions

Single Rails monolith (unchanged by this feature): `app/`, `test/` at the repository root, following
the layout already used by features 002, 003, 013, 015, 017.

---

## Phase 1: Setup (Shared Test Data)

**Purpose**: Fixture variety every story's tests will read from.

- [X] T001 [P] In `test/fixtures/users.yml`, add fixture rows so the following states each have at
      least one account: two different saved floors, one account with a locker number and one with a
      floor but no locker, one account that has never saved a floor, at least one administrator and
      one standard account beyond the existing pair, and one account whose email contains a literal
      `_` or `%` character (needed by research.md R4's escaping test).
- [X] T002 [P] In `test/fixtures/locker_wishes.yml`, add an active wish tied to one of the new
      `users.yml` fixtures, and confirm at least one fixture account has none — so the new "Wish"
      column (spec.md US1 Acceptance Scenarios 4–5) has both states to render.

---

## Phase 2: Foundational (Blocking Prerequisites)

No blocking prerequisites beyond the Phase 1 fixtures. This feature adds no migration, no new route,
and no shared infrastructure that more than one user story depends on — User Story 1 can begin as
soon as Phase 1 is done.

---

## Phase 3: User Story 1 - See each account's locker, floor and wish at a glance (Priority: P1) 🎯 MVP

**Goal**: Every row on Admin → Users shows that account's current floor, current locker, and active
locker search wish (or the absence of each), matching what the same account shows on its own
homepage and the locker wishes screen.

**Independent Test**: With accounts in each floor/locker/wish state from Phase 1, open Admin → Users
and confirm every row shows the right value or the right "not set"/"no locker"/"not looking" state —
no filter is needed to observe this.

### Tests for User Story 1 ⚠️ Write first; confirm they fail before implementing

- [X] T003 [P] [US1] In `test/controllers/admin/users_controller_test.rb`, assert the index response
      shows, per account: the saved floor or "Not set" when never saved; the saved locker number or
      "No locker assigned" when the account has a floor but no locker; and "Looking for floor
      `<floor>`" or "Not looking for a locker" depending on whether `user.locker_wish` is present
      (contracts/admin-users-filter.md "New Row Content").
- [X] T004 [P] [US1] In `test/system/admin_users_filter_test.rb` (new file), assert that opening
      Admin → Users shows each fixture account's floor, locker and wish state correctly, and that the
      values match what that same account's homepage and the locker wishes screen show (spec.md US1
      Acceptance Scenarios 1–6).

### Implementation for User Story 1

- [X] T005 [P] [US1] In `app/controllers/admin/users_controller.rb`, change `index`'s eager-load from
      `User.includes(:admin_granted_by)` to `User.includes(:admin_granted_by, :locker_wish)` so the
      new Wish column costs no per-row query (data-model.md "Query Composition").
- [X] T006 [US1] In `app/views/admin/users/index.html.erb`, add "Floor", "Locker" and "Wish" cells to
      each row: Floor shows `user.saved_floor` or `"Not set"` with the `detail-value-empty` class;
      Locker shows `user.saved_locker_number` or `"No locker assigned"` with `detail-value-empty`;
      Wish shows `"Looking for floor #{user.locker_wish.saved_floor}"` when
      `user.locker_wish.present?`, else `"Not looking for a locker"` with `detail-value-empty`. Give
      each cell the id `admin-user-row-<%= user.id %>-floor` / `-locker` / `-wish`
      (contracts/admin-users-filter.md "New Row Content").
- [X] T007 [US1] In `app/views/admin/users/index.html.erb`, add "Floor", "Locker" and "Wish"
      `<th scope="col" role="columnheader">` headers to the table's `<thead>`, in the same order as
      the cells added in T006.

**Checkpoint**: User Story 1 is fully functional and independently testable/shippable — richer
columns, no filters yet.

---

## Phase 4: User Story 2 - Narrow the list to a specific locker, floor, role or email (Priority: P1)

**Goal**: Four independent, combinable filters (current locker: exact match; current floor and role:
choice lists; email: partial match) narrow the Users list in place, and the "grant administrator
rights" action (015) preserves whatever filters were set when it redirects back (FR-016).

**Independent Test**: Apply each filter alone and confirm the list narrows to exactly the matching
accounts; combine two or more and confirm only accounts matching all of them remain; grant rights to
an account from a filtered list and confirm the same filters are still applied afterward.

### Tests for User Story 2 ⚠️ Write first; confirm they fail before implementing

- [X] T008 [P] [US2] In `test/models/role_filter_test.rb` (new file), assert `RoleFilter.new(selection:
      nil).choices == ["Admin", "Standard"]`, `filtering?` is false when `selection` is blank, and
      `current?("Admin")` is true only when that value was selected (data-model.md `RoleFilter`).
- [X] T009 [P] [US2] In `test/models/user_test.rb`, add tests for `User.with_role("admin")` /
      `("standard")` / blank, `User.on_floor(floor)` exact match, `User.with_locker_number(number)`
      exact match (FR-007 — not a substring match), `User.email_containing(text)` partial and
      case-insensitive match, including a search term containing a literal `%` or `_` matching only
      accounts whose email contains that literal character (research.md R4), and
      `User.saved_floors` returning every distinct non-blank floor across all registered users.
- [X] T010 [US2] In `test/controllers/admin/users_controller_test.rb`, assert each of the four filter
      params narrows the index on its own, that setting several at once narrows to accounts matching
      all of them (FR-009), that an unrecognized `role` value is treated as no restriction rather than
      erroring, and that the filtered index issues no more SQL queries than the unfiltered one
      (Principle IV — plan.md Constitution Check). Also assert: filtered results stay in the same
      registration-order sequence as the unfiltered list, with no reordering of the rows that remain
      (FR-015); and that exercising all four filters (setting, changing, and clearing each) leaves
      every account's `email`, `floor`, `locker_number`, `admin` and `locker_wish` attributes
      byte-for-byte unchanged from before the requests (FR-012).
- [X] T011 [US2] In `test/controllers/admin/users_controller_test.rb`, assert `grant_admin` redirects
      to `admin_users_path` carrying whatever filter params were submitted with it (FR-016), and that
      a non-administrator's request for `index` or `grant_admin` is refused even with filter query
      parameters attached (FR-014).
- [X] T012 [US2] In `test/system/admin_users_filter_test.rb`, assert: the current-floor and role link
      filters update the list in place without a full page reload, `aria-current` marks the active
      choice, moving keyboard focus through the choices without activating one does not re-filter the
      list; the current-locker and email text filters narrow the list shortly after typing stops,
      with no separate "Apply" control; granting rights to an account from a filtered list leaves
      the same filters applied on the page it redirects back to; returning a set filter to "All"/blank
      widens the list back to everyone still matching the remaining filters (spec.md US2 Acceptance
      Scenario 6); and a fresh visit to the screen with no query parameters shows every registered
      account unfiltered (spec.md US2 Acceptance Scenario 7).

### Implementation for User Story 2

- [X] T013 [P] [US2] In `app/models/user.rb`, add scopes `with_role`, `on_floor`,
      `with_locker_number`, `email_containing` and class method `self.saved_floors`, exactly per
      data-model.md's "User" table. `with_role` MUST match case-insensitively
      (`role.to_s.downcase`) since `RoleFilter::CHOICES` sends the capitalized values `"Admin"`/
      `"Standard"` as the filter's own query values. `email_containing` MUST include the
      `ESCAPE '\\'` clause alongside `sanitize_sql_like` — SQLite will not otherwise treat the
      escaped `%`/`_` as literal characters (research.md R4; see analyze findings F1, C1).
- [X] T014 [P] [US2] Create `app/models/role_filter.rb` implementing the `RoleFilter` class from
      data-model.md verbatim: `CHOICES = %w[Admin Standard].freeze`, `selection`, `filtering?`,
      `current?(choice)`, `choices`.
- [X] T015 [US2] In `app/controllers/admin/users_controller.rb`, extend `index` to read the four
      filter params, build a `FloorFilter.new(selection: ..., available: User.saved_floors)` and a
      `RoleFilter.new(selection: ...)`, and compose
      `User.includes(:admin_granted_by, :locker_wish).with_role(...).on_floor(...).with_locker_number(...).email_containing(...).order(:created_at)`
      (data-model.md "Query Composition"). *(depends on T013, T014)*
- [X] T016 [US2] In `app/controllers/admin/users_controller.rb`, add a `FILTER_AXES` constant and
      private `filter_selection`/`filter_selections` methods mirroring
      `LockerWishesController`'s pattern (research.md R5), so the query composition in T015, the
      `grant_admin` redirect (T017), and the hidden filter fields (T024) all read from one place.
      *(depends on T015)*
- [X] T017 [US2] In `app/controllers/admin/users_controller.rb`, change `grant_admin`'s redirect from
      `admin_users_path` to `admin_users_path(filter_selections)` (FR-016, research.md R5). *(depends
      on T016)*
- [X] T018 [P] [US2] Create `app/helpers/admin/users_helper.rb` with a path helper for one link-filter
      choice that preserves the other three axes' current values, mirroring
      `LockerWishesHelper#locker_wish_filter_path`.
- [X] T019 [P] [US2] Create `app/javascript/controllers/auto_submit_controller.js`: on its `field`
      target's `input` event, debounce (~400ms) and then call `this.element.requestSubmit()`
      (research.md R2).
- [X] T020 [US2] Register the new controller in `app/javascript/controllers/index.js` (same pattern as
      the existing `frame_history_controller.js` registration). *(depends on T019)*
- [X] T021 [P] [US2] Create `app/views/admin/users/_floor_filter.html.erb`: a labelled `<nav
      aria-label="...">` of links — "All" plus one choice per `filter.choices`, `aria-current="true"`
      on the one matching `filter.current?`, no `<select>` — rendered once for the current-floor axis
      (backed by `FloorFilter`) and once for the role axis (backed by `RoleFilter`), per
      contracts/admin-users-filter.md "Filter Bar".
- [X] T022 [P] [US2] Create `app/views/admin/users/_text_filter.html.erb`: a `method="get"` form
      targeting `admin_users_path`, with a labelled `<input type="text">` wired to
      `data-controller="auto-submit"` / `data-auto-submit-target="field"` /
      `data-action="input->auto-submit#submit"`, carrying the other three filter values as hidden
      fields, its own value re-populated from the current request — rendered once for current-locker
      and once for email, per contracts/admin-users-filter.md "Filter Bar".
- [X] T023 [US2] In `app/views/admin/users/index.html.erb`, wrap the existing table in
      `<turbo-frame id="admin-user-directory-list" data-turbo-action="advance"
      data-controller="frame-history">`, add `<meta name="turbo-cache-control" content="no-cache">`
      to the page, and render the filter bar (`_floor_filter` for current-floor, `_floor_filter` for
      role, `_text_filter` for current-locker, `_text_filter` for email) above the table
      (research.md R1, contracts/admin-users-filter.md "Frame" and "Filter Bar"). *(depends on T021,
      T022)*
- [X] T024 [US2] In `app/views/admin/users/index.html.erb`, add hidden fields for the four current
      filter values and `data: { turbo_frame: "_top" }` to the existing "Grant admin rights"
      `button_to` form, so its redirect (a) renders as a full-page navigation (making the flash
      notice, which lives outside the frame, visible) and (b) lands filtered the same way
      (research.md R5, FR-016). *(depends on T023, T017)*
- [X] T025 [US2] In `test/system/admin_users_test.rb`, update the existing "the screen offers no
      control but the grant" test: its `assert_no_field` becomes false once the two text filters
      exist. Narrow it to assert the only fields on screen are `input[name='current_locker']` and
      `input[name='email']` — nothing that edits an account. Every other assertion in the file is
      unaffected (analyze finding D1). *(depends on T023, T024)*
- [X] T026 [P] [US2] Add a `.filter-text` component to `app/assets/tailwind/application.css`, sized to
      sit inside `.filter-bar`/`.filter-group` next to the link-based filters, reusing
      `.field-input`'s existing appearance.

**Checkpoint**: User Stories 1 and 2 both work independently — filtering narrows the enriched list
from Phase 3, in place, and survives the existing grant-rights round trip.

---

## Phase 5: User Story 3 - Recognise that a filter combination matches nobody (Priority: P3)

**Goal**: A filter combination matching no account shows a clear "no account matches the current
filters" message instead of an apparently broken or blank screen, with every filter still visible.

**Independent Test**: Choose a filter combination matching nobody and confirm the message appears
with every filter selection intact; relax one filter and confirm the list returns.

### Tests for User Story 3 ⚠️ Write first; confirm they fail before implementing

- [X] T027 [P] [US3] In `test/controllers/admin/users_controller_test.rb`, assert that a filter
      combination matching no account renders the "no account matches the current filters" message
      (not an empty table with no explanation), with every submitted filter value still present in
      the response (e.g., echoed in the filter controls).
- [X] T028 [P] [US3] In `test/system/admin_users_filter_test.rb`, assert that setting a non-matching
      filter combination shows the `#admin-user-directory-no-match` message with all filter controls
      still showing what was selected/typed, and that relaxing one filter restores the matching rows
      (spec.md US3 Acceptance Scenarios 1–2).

### Implementation for User Story 3

- [X] T029 [US3] In `app/views/admin/users/index.html.erb`, render
      `<p id="admin-user-directory-no-match" class="empty-state">No account matches the current
      filters.</p>` in place of the table when `@users.none?` and at least one filter is set
      (contracts/admin-users-filter.md "No-Match State", data-model.md "No-Match State"). *(depends
      on T023)*

**Checkpoint**: All three user stories are independently functional; the feature is complete.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Accessibility/responsive coverage and regression evidence that this feature did not
disturb 013/015/017.

- [X] T030 [P] Extend `test/system/accessibility_test.rb` with an axe-core pass on a filtered Admin →
      Users list, the no-match state, and the two text-filter inputs' labels.
- [X] T031 [P] Extend `test/system/responsive_test.rb` to assert the four-filter bar wraps at narrow
      width with no sideways page scroll, against the site's single 48rem breakpoint (012 FR-018).
- [X] T032 Run `test/system/admin_users_test.rb` (T025 already updated its one affected assertion) and
      `test/system/locker_wish_filter_test.rb` (unchanged in full), and confirm both pass — the
      regression evidence that this feature did not disturb features 013/015's existing screen or
      017's filter feature (research.md R6).
- [X] T033 Walk through `specs/020-admin-users-filters/quickstart.md` end to end against a running
      server.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Empty — nothing blocks User Story 1 beyond Phase 1's fixtures.
- **User Story 1 (Phase 3)**: Depends on Phase 1. Independent of US2 and US3.
- **User Story 2 (Phase 4)**: Depends on Phase 1. Builds on the same `index.html.erb`/table US1
  touches, so in practice implement after US1 lands, even though its filtering logic does not depend
  on US1's new columns existing.
- **User Story 3 (Phase 5)**: Depends on US2 (T023's frame/table structure and T015's filtered query)
  — there is no "no match" state to report until filtering exists.
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### Within Each User Story

- Tests are written first and must fail before their paired implementation task.
- Model/PORO changes before controller changes; controller changes before the view changes that
  depend on them.

### Parallel Opportunities

- T001 and T002 (Setup, different fixture files).
- T003 and T004 (US1 tests, different files).
- T005 (US1, controller) alongside T003/T004 once they exist as failing tests.
- T008 and T009 (US2 model tests, different files).
- T013 and T014 (US2 models, different files).
- T018, T019, T021, T022, T026 (US2 implementation, five independent new files). T025 (the
  `admin_users_test.rb` update) is sequential — it depends on T023/T024 landing first.
- T027 and T028 (US3 tests, different files).
- T030 and T031 (Polish, different files).

---

## Parallel Example: User Story 2

```bash
# Tests, once Phase 3 is done:
Task: "Model test for RoleFilter in test/models/role_filter_test.rb"
Task: "Model tests for the four User scopes and saved_floors in test/models/user_test.rb"

# Independent new files, once T015-T017 land:
Task: "Create app/helpers/admin/users_helper.rb"
Task: "Create app/javascript/controllers/auto_submit_controller.js"
Task: "Create app/views/admin/users/_floor_filter.html.erb"
Task: "Create app/views/admin/users/_text_filter.html.erb"
Task: "Add .filter-text component to app/assets/tailwind/application.css"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (fixtures).
2. Phase 2 is empty — proceed straight to Phase 3.
3. Complete Phase 3: User Story 1 — richer columns, no filters.
4. **STOP and VALIDATE**: run the quickstart.md US1 steps against a real server.
5. Ship if ready — this is already a complete, useful increment on its own.

### Incremental Delivery

1. Setup → User Story 1 → validate → ship (MVP).
2. Add User Story 2 → validate (including the FR-016 grant-redirect cross-check) → ship.
3. Add User Story 3 → validate → ship.
4. Phase 6 polish can land alongside US3 or immediately after.

### Notes

- Every implementation task in US2 that edits `app/views/admin/users/index.html.erb` (T023, T024) is
  sequential with the others in that file — do not run them in parallel with each other, even though
  they are both `[US2]`.
- `app/models/floor_filter.rb` (feature 017) is reused unchanged — no task edits it.
- `app/controllers/locker_wishes_controller.rb`, its views, and `LockerWishesHelper` are not touched
  by any task in this file.
