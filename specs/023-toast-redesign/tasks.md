---

description: "Task list for feature implementation"
---

# Tasks: Modernized Toast Notifications

**Input**: Design documents from `/specs/023-toast-redesign/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/toast-component.md, quickstart.md (all present)

**Tests**: Included. The project constitution's Testing Standards principle is NON-NEGOTIABLE ("every new feature ... MUST include automated tests that fail without the change and pass with it"), and this feature's Constitution Check (plan.md) explicitly requires extending `test/system/notification_test.rb` rather than only touching styles.

**Organization**: Tasks are grouped by user story (spec.md's P1/P2/P3), each independently implementable and testable, in priority order.

> Revised after `/speckit-analyze` (2026-09-20): added T006 (entrance/exit animation — FR-004/SC-006 had no implementing task) and T013 (short-viewport overlap test — new spec.md edge case). All task IDs below reflect that revision.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no ordering dependency on an incomplete task)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Every task names its exact file path(s)

## Path Conventions

Single Rails monolith (per plan.md's Structure Decision) — no `src/`/`backend/`/`frontend/` split:

- Views: `app/views/layouts/_flash.html.erb`
- Styles: `app/assets/tailwind/application.css`
- Stimulus: `app/javascript/controllers/*_controller.js` (eager-loaded automatically — no manual registration)
- System tests: `test/system/notification_test.rb`
- Design contract: `CLAUDE.md` (repository root)

---

## Phase 1: Setup

**Purpose**: Capture a baseline for the redesign's own success criterion before anything changes.

- [X] T001 Capture "before" screenshots of the current toast (success and error, desktop width and `with_viewport(:phone)`) via a throwaway system test per CLAUDE.md's "How to check the work" (log in as `users(:carol)` for success, submit an invalid sign-in for error), saved to `tmp/design/toast-before-*.png`; delete the test immediately after capturing. This is the baseline evidence SC-001's side-by-side comparison needs.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The one shared DOM hook every later story either repositions (US2) or drives behavior through (US3).

**⚠️ CRITICAL**: Complete before starting any user story phase.

- [X] T002 Create `app/javascript/controllers/toast_layer_controller.js` as an empty Stimulus controller (no behavior yet — it is eager-loaded automatically via `app/javascript/controllers/index.js`, no manual registration needed), and add `data-controller="toast-layer"` to the `.toast-layer` container `<div>` in `app/views/layouts/_flash.html.erb`, matching the DOM structure documented in `contracts/toast-component.md`.

**Checkpoint**: The container US2 repositions and US3 drives cap/queue logic through now exists; user story work can begin.

---

## Phase 3: User Story 1 - A notification looks and feels current (Priority: P1) 🎯 MVP

**Goal**: Redesign the toast's size, spacing, finish, motion, and success/error distinction (color + icon + text) so it reads as part of the current interface — at its existing (unchanged-for-now) placement.

**Independent Test**: Trigger a success and an error notification and visually compare them against the rest of the redesigned app; each should show the right status color, a matching type icon, modern proportions, and a settled (not abrupt) appearance/departure.

### Tests for User Story 1

- [X] T003 [US1] Add three assertions to `test/system/notification_test.rb`: (a) a success toast and an error toast each render a `.toast-icon` `svg[aria-hidden="true"]` matching their type (FR-002); (b) `assert_axe_clean` passes with a toast visible on screen, confirming the new icon is not double-announced to assistive technology and text contrast holds (FR-009); (c) the toast's computed `transition-duration`/`animation-duration` stays within `--motion-entrance` (240ms) on both entrance and exit (FR-004, SC-006).

### Implementation for User Story 1

- [X] T004 [P] [US1] Add the two inline SVG type icons (a check glyph for success, an alert/exclamation glyph for error) into a `.toast-icon` slot in `app/views/layouts/_flash.html.erb`, `aria-hidden="true"` on both, selected by the existing `type`/`palette` local already driving `toast-success`/`toast-error` — different file from T005/T006, safe to do in parallel with them.
- [X] T005 [US1] Redesign the single `.toast` rule in `app/assets/tailwind/application.css` (currently ~L1065-1079): adjust padding/gap to make room for the icon, tighten `border-radius` to `--radius-lg` (12px — "the largest" per CLAUDE.md's Layout section), refine `box-shadow` for a lighter modern elevation, and keep `border-left` on the unchanged `--color-status-success` / `--color-status-error` tokens (research.md §3, so the existing `border-left-color` test assertion stays valid). Edit the existing rule in place — CLAUDE.md: "One definition per component. A second rule for the same element is a defect."
- [X] T006 [US1] Add the entrance/exit animation FR-004 requires (currently missing entirely — `.toast` has no `transition`/`@keyframes` today, only `.toast-dismiss`'s own hover/press feedback does at `application.css:2150-2164`): a fade + small rise on entrance and its reverse on exit, `transform`/`opacity` only, declared inside `@media (prefers-reduced-motion: no-preference)` per CLAUDE.md's Motion section, timed within `--motion-entrance`. Since exit needs to finish its transition before the element disappears, update `app/javascript/controllers/notification_controller.js#dismiss` to wait for the transition (e.g. a `transitionend` listener, with a safety timeout) before calling `this.element.remove()` — this must not change `dismiss()`'s externally observable behavior otherwise (still callable from the button, still clears the timer first).
- [X] T007 [US1] Add a `.toast-icon` rule to `app/assets/tailwind/application.css` (same file as T005/T006 — do sequentially, not in parallel): size and color drawn from the same status token as that toast's `border-left`, `flex: none`, aligned with the message's first line.
- [X] T008 [US1] Confirm FR-008 compliance across T004-T007's changes: no raw hex values anywhere in `_flash.html.erb` or the edited CSS — only existing `--color-*`, `--text-*`, `--spacing-*`, `--radius-*` tokens; and confirm T006's animation only animates `transform`/`opacity` (CLAUDE.md's "animate transform and opacity only" rule).
- [X] T009 [US1] Run `bin/rails tailwindcss:build`, then capture "after" screenshots via a throwaway system test (same scenarios as T001) and compare against the T001 baseline; delete the test after capturing.

**Checkpoint**: A success and an error toast now look and move like a redesigned component (size, spacing, icon, unchanged status color, settled entrance/exit) at every one of the app's ~15 existing trigger points, still at the current placement. Independently testable and demoable.

---

## Phase 4: User Story 2 - A notification never gets in the way (Priority: P2)

**Goal**: Move the notification layer to a fixed bottom-right position (resolved in the 2026-09-20 clarification), decoupled from the header, correct at every supported width and height.

**Independent Test**: Trigger a notification at desktop width, at phone width, and on a short viewport; confirm in every case it is anchored bottom-right, never overlaps navigation, content, or an active control, and re-settles correctly on resize/rotate.

### Tests for User Story 2

- [X] T010 [US2] Add a system test to `test/system/notification_test.rb` asserting that at desktop width a triggered toast's bounding rect sits in the viewport's bottom-right region and never intersects `.site-header`'s rect (acceptance scenario 1).
- [X] T011 [US2] Add a `with_viewport(:phone)` system test asserting the toast stays fully within the viewport (no horizontal scroll — reuse the existing `document.documentElement.clientWidth` bound already used in the "wraps instead of bursting" test) and never covers the header's interactive controls (acceptance scenario 2).
- [X] T012 [US2] Add a system test for the resize/rotate edge case: with a toast visible, resize the browser window across the 48rem boundary (`page.driver.browser.manage.window.resize_to`) and assert the toast re-settles inside the viewport rather than being stranded off-screen or over content.
- [X] T013 [US2] Add a system test for the short-viewport edge case (new in spec.md's Edge Cases): shrink the window's *height* so a page with a bottom-pinned control (e.g. a form's submit button) is taller than the viewport, trigger a toast, and assert it does not cover that control's rect.

### Implementation for User Story 2

- [X] T014 [US2] Change `.toast-layer` in `app/assets/tailwind/application.css` (currently ~L2298-2313) from `position: sticky; top: calc(var(--size-bar) + var(--spacing-4))` to `position: fixed; bottom: var(--spacing-4); right: var(--spacing-4)`, removing the `--size-bar` dependency entirely (research.md §1). Keep `z-index: 50`, the zero-footprint behavior, and the container's `pointer-events: none` with each `.toast`'s own `pointer-events: auto` unchanged. If T013 finds a real overlap risk on short viewports, cap the layer's `max-height` (e.g. against `100vh` minus a margin) so it never grows past the bottom-pinned control rather than silently covering it.
- [X] T015 [US2] Inside the existing `@media (max-width: 47.999rem)` block — do not introduce a new breakpoint width; `test/stylesheet_breakpoint_test.rb` fails on any width besides `48rem`/`47.999rem` — adjust `.toast-layer`'s inset so the toast stays fully visible and clear of the menu toggle at narrow widths. Verified via T011/T013: bottom-anchoring (T014) already keeps the layer clear of the top-anchored header/menu toggle at every width with no breakpoint-specific override needed — `.toast-layer`'s own `max-width: calc(100vw - 2 * var(--spacing-4))` already keeps it fully on-screen down to :phone width. No narrow-width rule added; adding one with nothing for it to fix would be dead weight.
- [X] T016 [US2] Update `CLAUDE.md`'s "Three couplings that break silently" §2 to remove `.toast-layer { top }` from the list of rules depending on `--size-bar` (only `html { scroll-padding-top }` still does), and note why: placement moved to fixed bottom-right, resolved in feature 023's clarification session.

**Checkpoint**: User Stories 1 and 2 both work together — the redesigned toast now appears fixed bottom-right at every width and height, independent of header height.

---

## Phase 5: User Story 3 - Several notifications stay legible together (Priority: P3)

**Goal**: Cap simultaneously visible toasts at 3 and queue any beyond that (FR-010), on top of the existing stacking behavior (FR-005, unchanged).

**Independent Test**: Trigger 2 notifications together (should both be visible, stacked) and trigger 4+ in quick succession (only 3 visible at once, the rest revealed as earlier ones clear).

### Tests for User Story 3

- [X] T017 [US3] Add a system test asserting two notifications triggered for the same page load render stacked inside `.toast-layer` with visible separation, neither obscuring the other (acceptance scenario 1).
- [X] T018 [US3] Add a system test triggering 4+ notifications in quick succession and asserting: at most 3 are visible at once ("visible list, max length 3" per data-model.md), the 4th is not visible until one of the first three clears, and once revealed it runs its own full countdown rather than a partially-elapsed one ("starts its own independent `duration_ms` countdown from that moment, not from when it was queued" per data-model.md's transition rule).

### Implementation for User Story 3

- [X] T019 [US3] Implement the visible/queued cap in `app/javascript/controllers/toast_layer_controller.js` (stub from T002): track child toasts, hold any beyond the 3rd out of the visible set (e.g. not yet inserted, or `hidden`) rather than starting their countdown, keeping a FIFO `queued` list ("oldest queued is promoted first" per data-model.md).
- [X] T020 [US3] Wire `notification_controller.js`'s `dismiss()` to notify `toast_layer_controller.js` (e.g. a Stimulus-dispatched custom event on removal, fired after T006's exit transition completes) so the layer can dequeue and reveal the next queued toast — without changing `notification_controller.js`'s existing countdown/pause/resume/dismiss behavior (FR-006 — no regression).
- [X] T021 [US3] Confirm the stacked layout's `gap` and each toast's entrance animation (from T006: fade + rise, `transform`/`opacity` only, declared inside `@media (prefers-reduced-motion: no-preference)`) apply correctly to a toast revealed from the queue, not only to one shown immediately.

**Checkpoint**: All three user stories are independently functional and work together — redesigned, correctly placed, and legible even under a burst of 4+ notifications.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Confirm nothing existing regressed and the feature matches its own validation guide, including the two qualitative success criteria.

- [X] T022 [P] Run `bin/rails test test/system/notification_test.rb` in full and confirm every pre-existing assertion (auto-dismiss timing, hover/focus pause, manual dismiss, `<main>` rect equality, `border-left-color`) still passes unchanged, alongside the new T003/T010-T013/T017-T018 assertions.
- [X] T023 [P] Run `bin/rails test test/stylesheet_breakpoint_test.rb` to confirm T015 introduced no new media-query width.
- [X] T024 Walk through `quickstart.md`'s full validation guide end-to-end (placement, short-viewport check, type distinction, stacking + cap, preserved behavior, accessibility spot-check, entrance/exit timing). Each §1-3/§4 scenario has a direct automated equivalent in the tests added above (T009-T013, T017-T018, T022-T023, T025) and all pass; §3b (SC-001/SC-002) is human-judgment and tracked separately as T026.
- [X] T025 [P] Run `assert_axe_clean` on at least one page at each of the app's two supported widths with a toast visible, confirming zero new violations from the full redesign.
- [ ] T026 Run quickstart.md §3b's SC-001 and SC-002 measurement steps (reviewer comparison, glance-test spot-check) and record the results in the PR description.
- [X] T027 Confirm no throwaway screenshot-capture test from T001/T009 was left in the working tree.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories.
- **User Story 1 (Phase 3)**: Depends only on Foundational. No dependency on US2/US3.
- **User Story 2 (Phase 4)**: Depends only on Foundational. Independently testable even if US1 were skipped, though in practice it lands on top of US1's already-redesigned `.toast` markup/CSS.
- **User Story 3 (Phase 5)**: Depends only on Foundational (specifically, the `toast_layer_controller.js` stub from T002, and T006/T020's exit-transition-then-dispatch handshake). Independently testable on its own; in practice lands on top of US1+US2's finished layer.
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### Within Each User Story

- Tests are written before their corresponding implementation task and must fail first.
- Within US1: T004 (view) can run parallel to T005-T007 (styles, same file as each other — sequential); T008 depends on T004-T007; T009 depends on T008.
- Within US2: T010-T013 (tests, same file, sequential with each other) before T014-T016; T015 depends on T014; T016 depends on T014-T015 landing.
- Within US3: T017-T018 (tests, same file, sequential with each other) before T019-T021; T020 depends on T019 and on T006 (exit transition must exist before it can be listened for); T021 depends on T019-T020.

### Parallel Opportunities

- T004 (`_flash.html.erb`) can run in parallel with T005-T007 (`application.css`) within US1 — different files.
- T022, T023, and T025 in Polish touch independent test files/commands and can run in parallel.
- Different user story phases (US1/US2/US3) could be split across developers once Phase 2 is done, since each is independently testable — in practice they share `application.css` and `_flash.html.erb`, so sequential (priority order) is the lower-conflict path for a single implementer.

---

## Parallel Example: User Story 1

```bash
# T004 and T005 touch different files and have no ordering dependency:
Task: "Add inline SVG type icons to app/views/layouts/_flash.html.erb"
Task: "Redesign the .toast rule in app/assets/tailwind/application.css"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup) and Phase 2 (Foundational).
2. Complete Phase 3 (User Story 1) — the visual + motion redesign alone is a shippable, independently valuable increment (a modernized toast at the current placement).
3. **STOP and VALIDATE**: run T003's tests, review T009's before/after screenshots against SC-001.
4. Ship if ready; placement (US2) and the cap/queue (US3) can follow as separate increments.

### Incremental Delivery

1. Setup + Foundational → foundation ready.
2. Add User Story 1 → validate independently → ship (MVP: modern look and motion, same placement).
3. Add User Story 2 → validate independently → ship (adds bottom-right fixed placement, including the short-viewport guard).
4. Add User Story 3 → validate independently → ship (adds the burst-of-4+ cap/queue).
5. Polish → full regression pass, quickstart walkthrough, qualitative SC-001/SC-002 measurement, accessibility spot-check.

## Notes

- [P] tasks touch different files and have no ordering dependency on an incomplete task in the same phase.
- This is a single shared component (`_flash.html.erb` + one CSS component + two small Stimulus controllers) used across ~15 existing trigger points — no per-trigger-point task is needed, since none of them change (FR-011: wording and triggers unchanged).
- Commit after each task or logical group, per repository convention.
- Stop at any checkpoint to validate a story independently before continuing.
