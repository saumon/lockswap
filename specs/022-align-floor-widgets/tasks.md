---

description: "Task list for feature implementation"
---

# Tasks: Compact floor/locker label alignment

**Input**: Design documents from `/specs/022-align-floor-widgets/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md (N/A), quickstart.md

**Tests**: Included. Constitution Principle II (Testing Standards, NON-NEGOTIABLE)
requires automated tests for every feature; each user story below adds/extends
Minitest system tests before its markup/CSS change.

**Organization**: Tasks are grouped by user story (spec.md) to enable
independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Single Rails project — views under `app/views/`, the one stylesheet at
`app/assets/tailwind/application.css`, system tests under `test/system/`, per
plan.md's Project Structure.

---

## Phase 1: Setup

**Purpose**: Confirm a clean baseline before any change.

- [X] T001 Run `bin/rails tailwindcss:build` and then `bin/rails test test/system/homepage_locker_wish_test.rb test/system/locker_wish_test.rb test/system/locker_profile_test.rb test/system/responsive_test.rb test/stylesheet_breakpoint_test.rb` to confirm all pass before any change in this feature (baseline check only — no file changes)

---

## Phase 2: Foundational

**Not applicable.** All three user stories below build directly on existing,
already-shared components (`.detail-value`, `.detail-grid`/`.detail-term`, the
`.card`/`.card--you` system) with no new scaffolding, model, route, or shared
service required first. Each story's tasks list its own CSS/markup work.

---

## Phase 3: User Story 1 - Read the searched floor at a glance (Priority: P1) 🎯 MVP

**Goal**: The floor number in "Your locker search" reads on the same line as
"Looking for a locker on floor", on both the homepage and the dedicated
locker wishes page.

**Independent Test**: Sign in as a user with a saved locker wish, open the
homepage (and the locker wishes page), and confirm the floor number appears
inline with the sentence rather than on the line below it.

### Tests for User Story 1 ⚠️

> Write these first; confirm they fail against the current stacked markup.

- [X] T002 [P] [US1] In `test/system/homepage_locker_wish_test.rb`, add an assertion that the "Looking for a locker on floor" text and the floor value (`#home-locker-wish-floor`) sit within the same inline statement/line (e.g. assert the text node containing the sentence also contains the floor number, or assert `#home-locker-wish-floor` is not a block-level sibling below the sentence) — keep the existing `#home-locker-wish-floor` id and its `.detail-value` styling assertions intact
- [X] T003 [P] [US1] In `test/system/locker_wish_test.rb`, add the equivalent assertion for the "Your locker search" panel on the dedicated locker wishes page, using the existing `#locker-wish-floor` id

### Implementation for User Story 1

- [X] T004 [US1] In `app/assets/tailwind/application.css`, adjust the rule(s) so a `.detail-value` used inside the "Your locker search" sentence flows inline (e.g. `display: inline` / inline-block with no `margin-top`) instead of the current block/stacked layout, per `research.md` §1 — do not touch `.detail-value`'s use elsewhere (e.g. inside `.detail-grid`, which stays block per User Story 2/3)
- [X] T005 [P] [US1] In `app/views/home/_locker_wish.html.erb`, change the `<dt>`/`<dd id="home-locker-wish-floor">` pair so the floor number renders inline within the "Looking for a locker on floor" sentence (single flowing statement), keeping the `home-locker-wish-floor` id and `.detail-value` class on the number
- [X] T006 [P] [US1] In `app/views/locker_wishes/_locker_wish_panel.html.erb`, make the identical inline change, keeping the `locker-wish-floor` id and `.detail-value` class on the number
- [X] T007 [US1] Run `bin/rails tailwindcss:build` then `bin/rails test test/system/homepage_locker_wish_test.rb test/system/locker_wish_test.rb` and confirm T002/T003 now pass

**Checkpoint**: User Story 1 is fully functional and independently testable/demoable.

---

## Phase 4: User Story 2 - Compact locker details on mobile (Priority: P2)

**Goal**: On mobile-width screens, "Your locker" shows "Floor" + its number on
one line and "Locker number" + its value (or "No locker assigned") on one
line, while the existing desktop side-by-side two-field layout is unchanged.

**Independent Test**: View "Your locker" on a mobile-width screen as a user
with a saved floor and confirm each label and its value share one line; view
it at desktop width and confirm the existing two-column layout is unaffected.

### Tests for User Story 2 ⚠️

> Write these first; confirm they fail against the current stacked-per-field markup.

- [X] T008 [P] [US2] In `test/system/locker_profile_test.rb`, using `with_viewport(:phone)`, add an assertion (as a user with both a floor and a locker number, e.g. `users(:bob)`) that `#locker-profile-floor`'s label ("Floor") and value sit on the same line, and likewise for `#locker-profile-locker-number` and its "Locker number" label
- [X] T009 [P] [US2] In `test/system/locker_profile_test.rb`, using `with_viewport(:phone)`, add the same-line assertion for the "No locker assigned" placeholder case (e.g. `users(:carol)`, who has a floor and no locker number), reusing the existing `detail-value-empty` selector
- [X] T010 [US2] In `test/system/responsive_test.rb` (or `locker_profile_test.rb`), add an assertion at desktop width that the two field groups inside `#locker-profile .detail-grid` still render side by side (existing two-column behavior unchanged) — this must pass both before and after the CSS change in T011, guarding FR-003

### Implementation for User Story 2

- [X] T011 [US2] In `app/assets/tailwind/application.css`, change the base (mobile, below 48rem) rule for the field groups inside `.detail-grid` so each group's `.detail-term` and `.detail-value` sit on the same line (e.g. `display: flex; align-items: baseline; gap: var(--spacing-2)` on `.detail-grid > div`, removing `.detail-value`'s `margin-top` in that context), and add the reverse (label above value, as today) inside the existing `@media (min-width: 48rem) { .detail-grid { ... } }` block so desktop is unaffected — do not introduce a new media query; reuse the single existing 48rem breakpoint pair, per `research.md` §2
- [X] T012 [US2] Run `bin/rails tailwindcss:build` then `bin/rails test test/system/locker_profile_test.rb test/system/responsive_test.rb` and confirm T008–T010 now pass

**Checkpoint**: User Stories 1 and 2 both work independently; desktop "Your locker" layout is unchanged.

---

## Phase 5: User Story 3 - A lighter-weight "Your locker" block on the homepage (Priority: P3)

**Goal**: On the homepage, "Your locker" renders as plain content (no card
border/background/hinge) while every other homepage card, including "Your
locker search" and "Add your locker details", is unaffected.

**Independent Test**: Sign in as a user with a saved floor, open the
homepage, and confirm "Your locker" has no card border/background while
"Your locker search" above it still does.

### Tests for User Story 3 ⚠️

> Write these first; confirm they fail while `#locker-profile` still carries `.card`.

- [X] T013 [P] [US3] In `test/system/locker_profile_test.rb`, add an assertion that `#locker-profile` does not have the `card` class (e.g. `assert_no_selector ".card#locker-profile"` or equivalent), while its heading text "Your locker" and field values remain present and correctly labeled
- [X] T014 [P] [US3] In `test/system/homepage_locker_wish_test.rb`, add an assertion that `#home-locker-wish` (the "Your locker search" card) still has the `card` and `card--you` classes, guarding FR-006 (other homepage cards unaffected)

### Implementation for User Story 3

- [X] T015 [US3] In `app/views/home/_locker_profile.html.erb`, remove the `card` and `card--you` classes (and the now-unnecessary `card`-specific spacing, if any) from the partial's root element (`#locker-profile`), leaving its heading, `.detail-grid` content, and the locker-details `<details>` editor unchanged — no rendering-context flag is introduced, since this partial's only call site is `home/index.html.erb:53` (confirmed in `research.md` §3); adjust surrounding spacing only if needed so the block still reads cleanly inside the homepage's `.stack`
- [X] T016 [US3] Run `bin/rails tailwindcss:build` then `bin/rails test test/system/locker_profile_test.rb test/system/homepage_locker_wish_test.rb` and confirm T013/T014 now pass

**Checkpoint**: All three user stories are independently functional; the homepage reads more compactly end to end.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation across all three stories together.

- [X] T017 Follow `quickstart.md` Step 2: write a throwaway system test that screenshots the homepage as `users(:carol)` (default viewport, for US1) and as `users(:bob)` (default viewport for US3/desktop US2, and `with_viewport(:phone)` for mobile US2), call `wait_for_entrance` before each `page.save_screenshot`, save to `tmp/design/`, visually confirm all three acceptance criteria, then delete the test
- [X] T018 Run the full regression suite: `bin/rails test test/system/homepage_locker_wish_test.rb test/system/locker_wish_test.rb test/system/locker_profile_test.rb test/system/responsive_test.rb test/stylesheet_breakpoint_test.rb test/system/motion_test.rb` and confirm everything passes together
- [X] T019 [P] Run `bin/rubocop` on any touched test files and fix any offenses

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — run first to confirm a clean baseline.
- **Foundational (Phase 2)**: N/A — nothing blocks the user stories.
- **User Stories (Phase 3–5)**: Each can start immediately after Setup. They
  are independent in scope (US1 touches `_locker_wish.html.erb` +
  `_locker_wish_panel.html.erb`; US2 and US3 both touch
  `_locker_profile.html.erb`, so if worked in parallel by different people,
  coordinate on that one file — see below) and can be delivered in priority
  order (P1 → P2 → P3) or in parallel by separate contributors.
- **Polish (Phase 6)**: Depends on all three stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: No dependency on US2/US3. Touches
  `home/_locker_wish.html.erb`, `locker_wishes/_locker_wish_panel.html.erb`,
  and a `.detail-value`-in-sentence CSS rule that does not overlap with the
  `.detail-grid` rules US2 touches.
- **User Story 2 (P2)**: No dependency on US1. Shares
  `app/views/home/_locker_profile.html.erb` with US3 (US2 edits the
  `.detail-grid` CSS only, no markup change is required in that file for
  US2) — if both are worked at once, land T011 (CSS) before or independently
  of T015 (US3's markup change), since they touch different files
  (`application.css` vs. `_locker_profile.html.erb`) and don't conflict.
- **User Story 3 (P3)**: No dependency on US1/US2. Its only file
  (`_locker_profile.html.erb`) is not touched by US1, and is touched by US2
  only in a different file (`application.css`), so US3 can proceed in
  parallel with US2 without merge conflicts.

### Within Each User Story

- Tests are written first and must fail before the corresponding
  implementation task.
- CSS rule changes precede the markup changes that rely on them, where
  applicable (US1).
- Each story ends with a task that rebuilds Tailwind and reruns that story's
  tests to confirm the checkpoint is green.

### Parallel Opportunities

- T002 and T003 (US1 tests, different files) in parallel.
- T005 and T006 (US1 markup, different files) in parallel, once T004 (shared CSS) lands.
- T008 and T009 (US2 tests, same file but independent assertions) can be written together.
- T013 and T014 (US3 tests, different files) in parallel.
- Once Setup (T001) is done, US1, US2, and US3 implementation work can proceed in parallel by different contributors (see User Story Dependencies above for the one shared file to coordinate on).
- T019 (lint) can run in parallel with T018 (test run) in Phase 6.

---

## Parallel Example: User Story 1

```bash
# Tests together:
Task: "Add inline-floor assertion in test/system/homepage_locker_wish_test.rb"
Task: "Add inline-floor assertion in test/system/locker_wish_test.rb"

# Markup changes together, once the shared CSS rule (T004) lands:
Task: "Inline the floor sentence in app/views/home/_locker_wish.html.erb"
Task: "Inline the floor sentence in app/views/locker_wishes/_locker_wish_panel.html.erb"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001).
2. Complete Phase 3: User Story 1 (T002–T007).
3. **STOP and VALIDATE**: confirm the floor sentence reads inline on both the homepage and the locker wishes page.
4. Ship this alone if desired — it is the most visible of the three fixes and fully independent of US2/US3.

### Incremental Delivery

1. Setup (T001) → baseline confirmed.
2. Add User Story 1 (T002–T007) → validate → ship (MVP).
3. Add User Story 2 (T008–T012) → validate (mobile compaction, desktop unchanged) → ship.
4. Add User Story 3 (T013–T016) → validate (homepage "Your locker" un-boxed, other cards unaffected) → ship.
5. Phase 6 (T017–T019): full visual + regression pass once all three are in.

### Parallel Team Strategy

With multiple contributors:

1. One person takes Setup (T001) — quick, blocks nothing else once confirmed.
2. Then in parallel:
   - Contributor A: User Story 1 (own files, no overlap).
   - Contributor B: User Story 2 (CSS-only in `application.css`).
   - Contributor C: User Story 3 (markup-only in `_locker_profile.html.erb`).
3. B and C touch different files from each other (CSS vs. markup) despite both being "about" the same partial, so they can land independently; merge either order.

---

## Notes

- [P] tasks = different files, no dependencies.
- [Story] label maps task to specific user story for traceability.
- No new components, breakpoints, or rendering-context flags are introduced — every task reuses an existing pattern (`.detail-value`, `.detail-grid`, the single 48rem breakpoint, direct partial edits) per `research.md`.
- Verify each story's tests fail before implementing, then pass after.
- Stop at any checkpoint to validate that story independently before moving to the next.
