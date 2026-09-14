---

description: "Task list template for feature implementation"
---

# Tasks: Auto-Dismissing Popup Notifications

**Input**: Design documents from `/specs/007-toast-notifications/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/notification-ui-contract.md, quickstart.md (all present)

**Tests**: Included as mandatory tasks, not optional — the project constitution's Testing Standards principle is NON-NEGOTIABLE ("Every new feature ... MUST include automated tests that fail without the change and pass with it"), and plan.md's Constitution Check explicitly requires system tests for this feature's acceptance behavior.

**Organization**: Tasks are grouped by user story (from spec.md: US1 = success popup, P1; US2 = error popup, P2; US3 = manual dismiss, P3) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Exact file paths are included in every task description

## Path Conventions

Single Rails project (no frontend/backend split) — paths are under `app/` and `test/` at the repository root, per plan.md's Project Structure.

---

## Phase 1: Setup

**Purpose**: Minimal scaffolding — no new dependencies are needed (Stimulus/Turbo/Tailwind are already in the Gemfile/importmap per research.md Decision 1).

- [X] T001 Create the Stimulus controller skeleton at `app/javascript/controllers/notification_controller.js`: `import { Controller } from "@hotwired/stimulus"` and an empty `export default class extends Controller {}`. It is auto-registered by the existing `eagerLoadControllersFrom("controllers", application)` call in `app/javascript/controllers/index.js` — no other config changes are needed.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared markup/container structure every user story renders into. No user story is independently testable until this is done.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T002 Rewrite `app/views/layouts/_flash.html.erb`: replace the two static inline `<p class="mb-6 ...">` blocks with a `position: fixed` stacking container (e.g. `<div class="pointer-events-none fixed inset-x-0 top-4 z-50 flex flex-col items-center gap-3 px-4">`) wrapping the per-message elements, per contracts/notification-ui-contract.md. Each rendered notice element keeps `role="status"` and each alert element keeps `role="alert"` (per data-model.md: `type` is "Derived from which flash key it came from (`notice` → `success`, `alert` → `error`)"). Both element kinds get `data-controller="notification"` and `data-notification-duration-value` (data-model.md: `duration_ms` is a "fixed" constant, "3000" — **implemented as `config.x.notification_auto_dismiss_ms`**, 3000 in every environment but test, per the C1 Option A note below). Remove the old `mb-6` inline-flow spacing so the container never shifts `<main>`'s layout (FR-005). Preserve the existing emerald/rose Tailwind color classes (FR-002). *(depends on T001)*

**Checkpoint**: Foundation ready — notices/alerts render as fixed popups (without auto-dismiss yet); user story implementation can now begin.

---

## Phase 3: User Story 1 - Success message pops and disappears automatically (Priority: P1) 🎯 MVP

**Goal**: A "Signed in successfully."/"Locker details saved."-style success message appears as a popup and disappears on its own after 3 seconds, pausing if the user hovers/focuses it.

**Independent Test**: Sign in with valid credentials (or save valid locker details); observe the confirmation appear as a popup and disappear by itself after a few seconds without any page reload or click.

### Implementation for User Story 1

- [X] T003 [US1] In `app/javascript/controllers/notification_controller.js`, add `static values = { duration: Number }` and implement `connect()` to schedule dismissal: store `this.remaining = this.durationValue` and start a `setTimeout` that calls `dismiss()` after `this.remaining` ms (FR-003: "System MUST automatically dismiss each popup notification 3 seconds after it appears"). *(depends on T002)*
- [X] T004 [US1] In the same file, implement `dismiss()`: clear any pending timeout, then `this.element.remove()` so the element is fully removed from the DOM (not merely hidden), per research.md Decision 3 and the contract's DOM-removal requirement. *(depends on T003)*
- [X] T005 [US1] In the same file, implement `pause()` and `resume()` plus `disconnect()`: `pause()` clears the pending timeout and records elapsed time (`this.remaining -= (Date.now() - this.startedAt)`); `resume()` restarts a timeout for the stored `this.remaining` (not a full reset to 3000ms — per spec Clarifications: "Pause the 3-second timer on hover/focus, resume ... it once the user moves away"); `disconnect()` clears any pending timeout defensively (covers Turbo removing the element via navigation, per spec Edge Cases). *(depends on T004)*
- [X] T006 [US1] In `app/views/layouts/_flash.html.erb`, add `data-action="mouseenter->notification#pause mouseleave->notification#resume focusin->notification#pause focusout->notification#resume"` to each notification element so hovering or keyboard-focusing a popup pauses its countdown (FR-003, Edge Cases). *(depends on T005)*
- [X] T007 [US1] Create `test/system/notification_test.rb` with system tests covering: (a) signing in with valid credentials shows a `[role=status]` popup containing "Signed in successfully." that is still present about 1 second later (guards against a too-early dismissal bug, per FR-003/SC-002's ~3-second duration), then disappears on its own — use `Capybara.using_wait_time(5) { assert_no_selector "[role=status]", text: "Signed in successfully." }` for the eventual-disappearance check, since the default Capybara wait is shorter than the 3-second dismiss window; (b) hovering over (`find("[role=status]").hover`) or focusing a popup for longer than 3 seconds keeps it present, and it disappears shortly after the pointer/focus moves away (verifies research.md Decision 4's pause/resume behavior). *(depends on T006)*
- [X] T008 [US1] Review `test/system/login_test.rb` and update any assertion that locates the sign-in confirmation message by its old static-banner position/markup so it matches the new popup structure from T002/T006 (message text and `role="status"` are unchanged; only the container/positioning changed). *(depends on T006)* — **Reviewed: no change needed.** Its assertions use `assert_text "Signed out successfully."`, which matches the message wherever it renders; the file passes unchanged.

**Checkpoint**: At this point, User Story 1 is fully functional and independently testable — success popups appear, auto-dismiss, and pause on hover/focus.

---

## Phase 4: User Story 2 - Error message pops and disappears automatically (Priority: P2)

**Goal**: Error/alert messages (e.g. a rejected locker save, a refused swap proposal) use the same popup mechanism as success messages, visually distinct, also auto-dismissing.

**Independent Test**: Trigger a failing action (e.g. submit an invalid swap proposal or sign in with a wrong password) and confirm the error appears as a popup, visually distinguishable from a success popup, and disappears automatically.

### Implementation for User Story 2

- [X] T009 [P] [US2] Add system tests to `test/system/notification_test.rb`: trigger a failing/refused action (e.g. an invalid or duplicate swap proposal, or a wrong-password sign-in attempt) and assert a `[role=alert]` element appears styled distinctly (rose/red Tailwind classes) from a `[role=status]` success popup, then assert it also disappears automatically using the same extended-wait pattern as T007 (FR-002, SC-004). *(depends on T007)*
- [X] T010 [P] [US2] Verify `test/system/login_failure_test.rb` and `test/system/locker_profile_test.rb` — both already assert on `find("[role='alert']")` / `assert_no_selector "[role=alert]"`; confirm these pass unchanged against the new popup markup from T002 (per contracts/notification-ui-contract.md, the role attributes and full DOM removal on dismiss are preserved), adjusting only if the new fixed-position container nesting breaks element lookup. *(depends on T002)* — **Verified: both pass unchanged.**
- [X] T011 [P] [US2] Run `test/controllers/locker_swap_proposals_controller_test.rb` to confirm it still passes unchanged — it asserts `flash[:alert]`/`flash[:notice]` values directly, which FR-009 keeps untouched by this feature; no controller code changes are expected. *(depends on T002)* — **Verified: whole non-system suite passes (101 runs, 0 failures).**

**Checkpoint**: User Stories 1 AND 2 both work independently — success and error popups both auto-dismiss and are visually distinguishable.

---

## Phase 5: User Story 3 - Manually dismiss a notification early (Priority: P3)

**Goal**: A user who has already read a popup can close it immediately instead of waiting out the automatic timeout.

**Independent Test**: Trigger any popup notification and click its close control; confirm it disappears immediately instead of waiting out the full delay.

### Implementation for User Story 3

- [X] T012 [US3] In `app/views/layouts/_flash.html.erb`, add a manual dismiss control to each notification element: `<button type="button" aria-label="Dismiss notification" data-action="click->notification#dismiss" class="...">` (reuses the `dismiss()` action implemented in T004). *(depends on T004, T006)*
- [X] T013 [US3] In `app/javascript/controllers/notification_controller.js`, confirm `dismiss()` (from T004/T005) clears any pending timeout before removing the element regardless of whether it was called by the auto-dismiss timeout or the manual-dismiss click, so a manual click never leaves a dangling timer; add the missing `clearTimeout` guard if it isn't already there. *(depends on T012)* — **Verified: `dismiss()` already calls `clear()` before `element.remove()`; no guard was missing.**
- [X] T014 [P] [US3] Add a system test to `test/system/notification_test.rb`: trigger a popup, click its dismiss button (`find("[role=status] button", text: "Dismiss notification").click` or equivalent), and assert the element is removed from the DOM immediately — well before the 3-second auto-dismiss window would elapse. *(depends on T012, T013)*

**Checkpoint**: All user stories are now independently functional — popups appear, auto-dismiss with pause/resume, are visually distinct by type, and can be dismissed manually.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Full-suite regression check and the remaining spec-level verifications not tied to a single user story.

- [X] T015 [P] Run `bin/rails test:system` (full suite) and fix any regressions in other existing system tests that assert on flash presence — `test/system/account_lockout_test.rb`, `test/system/signup_test.rb`, `test/system/locker_wish_test.rb`, `test/system/locker_swap_proposal_test.rb`, `test/system/navigation_test.rb`, `test/system/access_control_test.rb`. — **Done: 87 runs, 385 assertions, 0 failures. No regressions; no other test needed changing.**
- [ ] T016 [P] Execute the manual screen-reader spot-check from `specs/007-toast-notifications/quickstart.md` step 8 (`status` vs `alert` announcement); record results. (Steps 6 and 7 are now covered by automated tests T019/T020.) — **STILL OPEN: needs a human with a screen reader (VoiceOver/NVDA); it cannot be automated or done from this session.** The structural half is covered by `test/views/layouts/flash_test.rb`, which asserts each message carries `role="status"`/`role="alert"` (live regions in their own right) and a labelled dismiss button.
- [X] T017 [P] Verify the long-message edge case from spec.md Edge Cases: temporarily set a very long `notice`/`alert` string (e.g. in a Rails console or a throwaway test), confirm the popup wraps the text instead of overflowing or breaking the fixed container's layout in `app/views/layouts/_flash.html.erb`. — **Automated instead of done by hand**: `notification_test.rb` swaps in a 40× message, then asserts the box grew taller and never exceeded the viewport width.
- [X] T018 [P] Run `bin/rubocop` and `bin/brakeman` to confirm zero new lint/security warnings on the files touched by this feature (per constitution Quality Gates). — **Done: RuboCop clean (59 files, 0 offenses). Brakeman reports 1 medium SQL-injection warning in `app/models/locker_swap_proposal.rb:206`, a file this feature never touched — pre-existing, not introduced here.**
- [X] T019 [P] Add a system test to `test/system/notification_test.rb` asserting stacking (FR-007, SC-005): trigger two actions in the same page load that each set a message (e.g. visit a flow that sets both `notice` and `alert`, or stub two flash entries in a request test), then assert both `[role=status]` and `[role=alert]` elements are simultaneously present and readable — not that only the last one shows. *(depends on T007, T009)* — **Written as a view test, not a system test**: no controller action sets both keys, so `test/views/layouts/flash_test.rb` renders the partial with both and asserts each role appears exactly once inside the one stacking container.
- [X] T020 [P] Add a system test to `test/system/notification_test.rb` asserting no layout shift (FR-005, SC-003): capture `find("main").native.rect` (or an equivalent bounding-box read via `evaluate_script`) before triggering a popup, again while it's visible, and again after it auto-dismisses; assert all three are equal. *(depends on T002)* — **Done** (two measurements: while showing and once gone; the "before" state does not exist, since the message is already on screen at first paint).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup (T001) — BLOCKS all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational (T002). No dependency on US2/US3.
- **User Story 2 (Phase 4)**: Depends on Foundational (T002) directly for T010/T011; T009 additionally depends on US1's T007 only because it appends tests to the same file (not a functional dependency — the timer/pause logic US2 relies on is already built in US1's T003–T005).
- **User Story 3 (Phase 5)**: Depends on Foundational (T002) and US1's `dismiss()` implementation (T004) and markup wiring (T006).
- **Polish (Phase 6)**: Depends on all three user stories being complete. T019 additionally depends on T007 and T009 (needs both success and error popup rendering already implemented and tested); T020 depends only on T002 (the fixed-position container).

### Within Each User Story

- Controller logic tasks (T003→T004→T005) are sequential — same file, each builds on the previous method.
- Markup wiring (T006, T012) follows the controller logic it wires up.
- Tests (T007, T008, T009, T010, T011, T014) follow the implementation they verify.

### Parallel Opportunities

- Within Phase 4 (US2): T009, T010, T011 touch three different files with no interdependency — can run in parallel.
- Within Phase 6 (Polish): T015, T016, T017, T018, T019, T020 are independent verification activities — can run in parallel (T019 and T020 both append to `test/system/notification_test.rb`, so treat them as sequential relative to each other despite the `[P]` marker if worked by the same person; they have no functional dependency on one another).
- US2's non-test tasks (T010, T011) do not have to wait for US1's tests (T007/T008) to finish, only for Foundational (T002); only T009 (same test file as T007) has a practical, non-functional ordering dependency on T007.

---

## Parallel Example: User Story 2

```bash
# After Foundational (T002) and US1 (through T007) are done, run these together:
Task: "Add error-popup system tests to test/system/notification_test.rb (T009)"
Task: "Verify role=alert assertions still pass in test/system/login_failure_test.rb and test/system/locker_profile_test.rb (T010)"
Task: "Run test/controllers/locker_swap_proposals_controller_test.rb to confirm no regression (T011)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001)
2. Complete Phase 2: Foundational (T002) — CRITICAL, blocks all stories
3. Complete Phase 3: User Story 1 (T003–T008)
4. **STOP and VALIDATE**: sign in, confirm the popup appears, auto-dismisses, and pauses on hover — this alone already fixes the user's core complaint about "Signed in successfully." being static and persistent.
5. Demo if ready.

### Incremental Delivery

1. Setup + Foundational → fixed-position container renders (no auto-dismiss yet).
2. Add User Story 1 → success popups fully work → **this is the MVP** (fixes the exact complaint in the original request).
3. Add User Story 2 → error popups confirmed to work via the same mechanism, with dedicated test coverage.
4. Add User Story 3 → manual dismiss control added.
5. Polish → full regression run, remaining manual/edge-case verification, lint/security gates.

---

## Notes

- [P] tasks = different files, no dependencies.
- [Story] label maps task to specific user story for traceability.
- Because this feature is a single shared Stimulus controller + shared layout partial (not per-page code), most of the "story-specific" work after US1 is verification/test coverage rather than new implementation — this matches the spec's own framing (US2/US3 explicitly describe reusing the same mechanism).
- **Timing-test determinism decision (C1, Option A — changed from Option B during implementation, at the user's request)**: the countdown is configuration, not a literal. `Lockswap::Application::NOTIFICATION_AUTO_DISMISS_MS = 3000` in `config/application.rb` is what ships; `config/environments/test.rb` overrides `config.x.notification_auto_dismiss_ms` to `1000` so the suite is not waiting out three real seconds per assertion. `notification_test.rb` derives every wait from that setting, so the numbers follow the config rather than being restated. The shipped three seconds is still pinned by a test — `flash_test.rb` asserts the constant is `3000` and that the partial renders whatever is configured — so FR-003's actual figure keeps its coverage despite the suite never using it. Measured: system suite ~27s before the feature, ~45s under Option B, ~35s now.
- Upper bounds ("it goes away") use Capybara's polling matchers; the one lower bound ("it is still there") needs a literal `sleep`, since no polling matcher can express "must remain for at least N seconds". `application_system_test_case.rb` already sets `Capybara.default_max_wait_time = 5`, so no per-assertion `using_wait_time` was needed.
- **Watch item**: this repo's system suite has documented pre-existing flakiness on a loaded machine (see the comments in `application_system_test_case.rb` and `locker_profile_test.rb`). One intermittent `locker_profile_test.rb` failure was seen mid-implementation and did not reproduce; the same file also failed once on an unmodified tree, so it is not caused by this feature.
- Commit after each task or logical group.
- Stop at any checkpoint to validate a story independently.
