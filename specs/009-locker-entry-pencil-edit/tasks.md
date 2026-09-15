---

description: "Task list template for feature implementation"
---

# Tasks: Streamlined Locker Entry & Pencil-Icon Edit

**Input**: Design documents from `/specs/009-locker-entry-pencil-edit/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/locker-profile-update.md, quickstart.md (all present)

**Tests**: Included as mandatory tasks, not optional — the project constitution's Testing Standards principle is NON-NEGOTIABLE ("Every new feature ... MUST include automated tests that fail without the change and pass with it"), and plan.md's Constitution Check explicitly calls out the existing and new system-test coverage this feature requires.

**Organization**: Tasks are grouped by user story (from spec.md: US1 = first-entry choice between entering a locker and declaring none, P1; US2 = pencil-icon edit control, P1) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)
- Exact file paths are included in every task description

## Path Conventions

Single Rails project (no frontend/backend split) — paths are under `app/` and `test/` at the repository root, per plan.md's Project Structure.

---

## Phase 1: Setup

**Purpose**: Minimal scaffolding — no new dependencies are needed (Stimulus/Turbo/Tailwind are already in the Gemfile/importmap per research.md).

- [X] T001 Create the Stimulus controller skeleton at `app/javascript/controllers/locker_entry_choice_controller.js`: `import { Controller } from "@hotwired/stimulus"` and an empty `export default class extends Controller {}`. It is auto-registered by the existing `eagerLoadControllersFrom("controllers", application)` call in `app/javascript/controllers/index.js` — no other config changes are needed.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared, blocking infrastructure every user story needs before it can start.

**None required.** US1 (the first-entry screen, `app/views/home/index.html.erb`'s "no floor saved" branch) and US2 (the "Your locker" card's edit control, `app/views/home/_locker_profile.html.erb`) touch independent branches/partials of the same page and share no blocking model, route, or controller changes — both reuse the existing `PATCH /locker_profile` endpoint and validations unchanged (see contracts/locker-profile-update.md). Proceed directly to the user story phases once T001 is done.

---

## Phase 3: User Story 1 - Choose "I have a locker" or "I don't have a locker" on first entry (Priority: P1) 🎯 MVP

**Goal**: On the first-time "Add your locker details" screen, a user can either fill in floor + locker number, or click "I don't have a locker 😔" to switch to a floor-only view, and can switch back without losing an already-typed floor.

**Independent Test**: Log in as a user with no floor saved; confirm the screen offers both entering a locker and an "I don't have a locker 😔" action; exercise each path and confirm both produce a saved profile appropriate to the choice made.

### Implementation for User Story 1

- [X] T002 [US1] In `app/views/home/_locker_profile_form.html.erb`, add opt-in first-entry choice markup guarded by `local_assigns.fetch(:show_no_locker_choice, false)`. When true: wrap the form in `data-controller="locker-entry-choice"`; wrap the locker-number `.field` div in `data-locker-entry-choice-target="lockerNumberField"`; immediately after the locker-number hint, add a button labelled "I don't have a locker 😔" with `data-locker-entry-choice-target="declareNoLockerTrigger" data-action="locker-entry-choice#declareNoLocker"`; add a second, initially-`hidden` button labelled "Actually, I have a locker" with `data-locker-entry-choice-target="declareHasLockerTrigger" data-action="locker-entry-choice#declareHasLocker"`. When `show_no_locker_choice` is false/omitted (the pencil-icon edit path added in US2), none of this renders and the form is exactly what it is today — this is what satisfies Clarification 2 / FR-010 ("the edit form just shows the plain floor and locker-number fields"). *(depends on T001 for the controller identifier to exist)*
- [X] T003 [US1] In `app/views/home/index.html.erb`, update the first-time branch (`<% else %>`, rendered when `current_user.saved_floor.blank?`) to call `<%= render "home/locker_profile_form", show_no_locker_choice: true %>` (FR-001). *(depends on T002)*
- [X] T004 [US1] Implement `app/javascript/controllers/locker_entry_choice_controller.js`: declare `static targets = ["lockerNumberField", "declareNoLockerTrigger", "declareHasLockerTrigger"]`. `declareNoLocker()` hides `lockerNumberFieldTarget` (`.hidden = true`), clears the value of the `<input>` inside it (so a previously typed number is not silently submitted, per data-model.md), hides `declareNoLockerTriggerTarget`, and shows `declareHasLockerTriggerTarget` (FR-003, FR-004). `declareHasLocker()` reverses all three of those without touching the floor field's value (FR-005). *(depends on T001, T002)*
- [X] T005 [P] [US1] Add CSS in `app/assets/tailwind/application.css` for the two triggers added in T002 (e.g. a `.field-link-action` rule reusing `--color-link` and the quiet-hover treatment already used by `.btn-quiet`) so "I don't have a locker 😔" / "Actually, I have a locker" read as clear, discoverable actions rather than plain unstyled buttons.
- [X] T006 [US1] Add system tests to `test/system/locker_profile_test.rb`: (a) "a first-time user can declare they have no locker and save only a floor" — log in as `alice`, call `wait_for_turbo` (the first-entry screen is reached via a post-login redirect, the same precondition that causes the documented 008 Turbo-preview race `open_locker_editor` already guards against), click "I don't have a locker 😔", assert the locker-number field is no longer present, fill in Floor, save, and assert `#locker-profile-floor` shows the value while `#locker-profile-locker-number` shows "No locker assigned" (Acceptance Scenario 2, SC-001); (b) "declaring no locker without a floor is rejected" — same flow, submit with Floor blank, assert "Floor can't be blank" is shown and nothing is saved (Edge Case; floor-mandatory rule unchanged). *(depends on T002, T003, T004)*
- [X] T007 [P] [US1] Add a system test to `test/system/locker_profile_test.rb`: "switching back to entering a locker keeps the floor and drops a previously typed locker number" — log in as `alice`, call `wait_for_turbo` (same post-login-redirect precondition as T006), fill in Floor, type a value into Locker number, click "I don't have a locker 😔" then "Actually, I have a locker", and assert the Floor value is still present while the Locker number field is now empty (Acceptance Scenario 3, FR-005). *(depends on T004)* — **Split into two tests**: the switch-back itself, plus "a locker number typed before saying you have none is not saved", which follows the same setup through to the database. The field assertion proves the field was cleared; only the second proves that is what reaches the record.
- [X] T008 [P] [US1] Update `test/system/accessibility_test.rb`'s "home without locker details is accessible" test (`alice`) to call `wait_for_turbo` (same post-login-redirect precondition as T006) before clicking "I don't have a locker 😔", then call `assert_axe_clean` a second time, so the new toggled view gets the same audit coverage every other screen state has (008 FR-028). *(depends on T004)*

**Checkpoint**: At this point, User Story 1 is fully functional and independently testable — a first-time user can choose either path, switch between them, and the floor-mandatory rule still holds.

---

## Phase 4: User Story 2 - Edit saved locker details via a pencil icon (Priority: P1)

**Goal**: On the "Your locker" card, replace the text-labeled "Edit locker details" disclosure with an icon-only pencil control that reveals the same pre-filled floor/locker-number form.

**Independent Test**: Log in as a user with existing locker details; confirm no "Edit locker details" text menu is shown; click the pencil icon; confirm the same floor/locker-number fields appear pre-filled; change a value and confirm the update saves.

### Implementation for User Story 2

- [X] T009 [US2] Restructure `app/views/home/_locker_profile.html.erb`: wrap the existing `<h2 class="card-title">Your locker</h2>` and a new edit control in a `.tile-head` row (the existing `justify-content: space-between; align-items: center` utility already used elsewhere in the stylesheet, not a new class). Render the edit control only when `local_assigns.fetch(:editable, true)` is true.
- [X] T010 [US2] Move the `<details class="disclosure" ...>...</details>` block — currently in `app/views/home/index.html.erb` (the `saved_floor.present?` branch, wrapping `<summary>Edit locker details</summary>` and the form) — into the `.tile-head` row added in T009. Keep `<%= "open" if current_user.errors.any? %>` on `<details>` (005's rejected-submission-reopens-form behavior) and keep `<%= render "home/locker_profile_form" %>` unchanged — no `show_no_locker_choice` local, so it defaults to `false` and renders the plain two-field form, per Clarification 2 / FR-010 — inside `.disclosure-body`. *(depends on T009)*
- [X] T011 [US2] In the `<summary>` moved in T010, replace the visible text "Edit locker details" with `aria-label="Edit locker details"` on the `<summary>` element itself, and make a hand-authored inline `<svg aria-hidden="true">...</svg>` pencil icon (matching the inline-SVG convention from `app/views/shared/_brand_mark.html.erb`) its only visible content (FR-007, FR-009; research.md Decisions 2–3). *(depends on T010)*
- [X] T012 [US2] Update `app/views/home/index.html.erb`: delete the `<details>` block now moved into `_locker_profile.html.erb`; change `<%= render "home/locker_profile" %>` to `<%= render "home/locker_profile", editable: !(LockerSwapProposal.active_for?(current_user) && current_user.errors.empty?) %>`; leave the `#locker-profile-locked` block exactly as it is today, under the same condition it already uses (005's locked-while-active-swap behavior is unaffected). *(depends on T009, T010, T011)*
- [X] T013 [P] [US2] Add CSS in `app/assets/tailwind/application.css` for the icon-only trigger, e.g. `.disclosure-icon-summary`: a circular/quiet control sized to at least `.btn-sm`'s 2.25rem minimum tap target, hover/focus-visible treatment consistent with `.tile-disclosure-summary`, `.disclosure-icon-summary::-webkit-details-marker { display: none }`, and no chevron `::after` marker (the icon itself signals the affordance, unlike the text-label disclosures that keep their chevron). — **Named `.locker-profile-editor-summary`, not `.disclosure-icon-summary`**: the rule is `position: absolute` with offsets measured against *that* card's padding and title line box, so a name promising a general-purpose icon disclosure would be writing a cheque the rule cannot cash. The summary is taken out of the flow because `<summary>` and the form it opens must be siblings — anything that put the pencil in a row with the heading would open the form in that row too.
- [X] T014 [US2] Update `test/system/locker_profile_test.rb`: change the `open_locker_editor` helper (currently `find("summary", text: "Edit locker details").click`) to `find("summary[aria-label='Edit locker details']").click`; change the locked-state assertion (currently `assert_no_selector "summary", text: "Edit locker details"`) to `assert_no_selector "summary[aria-label='Edit locker details']"`; add a new test "a user with saved details sees an icon-only edit control, not a text menu" asserting `assert_no_selector "summary", text: "Edit locker details"` and `assert_selector "summary[aria-label='Edit locker details']"`, then click that control once and assert the floor/locker-number fields are immediately present with no intermediate menu to expand first (FR-007, SC-002, SC-003). *(depends on T009, T010, T011, T012)*
- [X] T015 [P] [US2] Add a system test to `test/system/locker_profile_test.rb`: "the pencil-icon edit form never offers the no-locker choice" — log in as `carol` (floor saved, no locker number), open the editor via the pencil icon, and assert both `input[name='user[floor]']` and `input[name='user[locker_number]']` are present (the latter empty) with no "I don't have a locker 😔" control anywhere on the page (Clarification 2, FR-010). *(depends on T012, and on US1's T002 existing so the trigger's absence is meaningfully asserted)*
- [X] T016 [P] [US2] Update `test/system/accessibility_test.rb`'s "home with the edit disclosure open is accessible" test (`dave`) to open the editor via `find("summary[aria-label='Edit locker details']").click` instead of the old text-based selector, then call `assert_axe_clean` as before. *(depends on T011)*

**Checkpoint**: At this point, User Stories 1 AND 2 both work independently — the first-entry choice and the icon-only edit control are both fully functional and tested.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Full-suite regression check and the remaining spec-level verifications not tied to a single user story.

- [X] T017 [P] Run `bin/rails test:system` (full suite) and fix any regressions, in particular re-checking `test/system/locker_swap_proposal_test.rb` and `test/system/locker_wish_test.rb` for any incidental dependency on the old "Edit locker details" text or form layout. — **Done: 124 runs, 524 assertions, 0 failures, 0 errors.** No other file needed changing; the three that referenced the old control were the two updated in T014/T016 and `index.html.erb` itself. The non-system suite passes too (103 runs, 394 assertions).
- [X] T018 [P] Run `bin/rubocop` and `bin/brakeman` to confirm zero new lint/security warnings on the files touched by this feature (Constitution Quality Gates). — **Done: RuboCop clean (61 files, 0 offenses); Brakeman 0 security warnings.**
- [X] T019 [P] Walk through `specs/009-locker-entry-pencil-edit/quickstart.md` Scenarios A–G by hand, confirming each is either directly verified or already covered by an automated test above; record results. — **Done.** A–E and G are each covered by an automated test (A and G by 002/005's existing ones, B–E by those added here), and A–E were also driven in a real headless browser and reviewed as screenshots at 1400px and 400px — which is what confirmed the pencil's alignment and that a closed editor leaves no dead space in the card. Scenario F is automated as far as it can be: the axe audit covers both new screen states and `assert_selector "summary[aria-label=…]"` pins the accessible name. **STILL OPEN:** F's screen-reader spot-check needs a human with VoiceOver/NVDA, as in 007's T016.
- [X] T020 [P] Re-run `test/system/accessibility_test.rb`'s "tab order follows visual order on the home page" test against the restructured card header and first-entry choice controls (FR-015b); adjust DOM order if the pencil icon or choice triggers land out of visual sequence. — **Done: passes unchanged, no DOM reordering needed.** That test logs in as bob, whose card is locked by an active proposal and so renders no pencil at all; the control is covered instead by the axe audit in T016 and, for the walk itself, by being the only focusable element in its card.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: None required (see rationale above) — does not block either story beyond T001.
- **User Story 1 (Phase 3)**: Depends on Setup (T001). No dependency on US2.
- **User Story 2 (Phase 4)**: Independent of US1's implementation; T015 additionally depends on US1's T002 existing so its "no no-locker-choice control" assertion is meaningful, not because US2 needs US1's behavior.
- **Polish (Phase 5)**: Depends on both user stories being complete.

### Within Each User Story

- US1: T002 (form markup) → T003 (wire it into the first-entry screen) and → T004 (controller logic, needs T002's target names); T005 (CSS) is independent of T002–T004. Tests T006–T008 follow the implementation they verify.
- US2: T009 (header restructure) → T010 (move the disclosure in) → T011 (icon/aria-label) → T012 (index.html.erb cleanup + `editable` local). T013 (CSS) is independent. Tests T014–T016 follow T009–T012.

### Parallel Opportunities

- T005 (US1 CSS) can run alongside T002–T004 (different file).
- T007 and T008 (US1) touch different files (`locker_profile_test.rb` vs `accessibility_test.rb`) from each other and from T006, but T006 and T007 both append to `locker_profile_test.rb` — treat as sequential relative to each other if worked by the same person, despite the `[P]` marker.
- T013 (US2 CSS) can run alongside T009–T012.
- T015 and T016 (US2) touch different files from T014 — can run in parallel with it once T009–T012 are done.
- US1 (Phase 3) and US2 (Phase 4) can be worked on in parallel by different people once T001 is done: they touch different branches of `index.html.erb` and different partials, though both edit that one file, so treat T003 and T012 as sequential relative to each other if the same person is doing both.
- All of Phase 5 (T017–T020) are independent verification activities — can run in parallel.

---

## Parallel Example: User Story 1

```bash
# After T001 is done, run these together:
Task: "Add the opt-in first-entry choice markup to app/views/home/_locker_profile_form.html.erb (T002)"
Task: "Add CSS for the two first-entry triggers in app/assets/tailwind/application.css (T005)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001)
2. Complete Phase 3: User Story 1 (T002–T008) — Phase 2 is a no-op, see above
3. **STOP and VALIDATE**: log in as a first-time user, confirm both paths work and switching between them preserves the floor
4. Demo if ready — this alone already delivers the "lighter, no-irrelevant-field" first-entry experience the request asked for

### Incremental Delivery

1. Setup (T001) → nothing user-visible yet
2. Add User Story 1 (T002–T008) → first-entry choice fully works → **this is the MVP**
3. Add User Story 2 (T009–T016) → the edit control becomes icon-only
4. Polish (T017–T020) → full regression run, manual quickstart walkthrough, lint/security gates

### Parallel Team Strategy

With two developers: once T001 is done, Developer A takes US1 (T002–T008) and Developer B takes US2 (T009–T016) — they touch different partials and different branches of `index.html.erb`, coordinating only on that one shared file's diff.

---

## Notes

- [P] tasks = different files, no dependencies.
- [Story] label maps task to specific user story for traceability.
- Both stories reuse the existing `PATCH /locker_profile` endpoint and its validations unchanged (contracts/locker-profile-update.md) — no controller or model task is needed in either story.
- The pencil-icon control (US2) reuses the zero-JS `<details>`/`<summary>` disclosure pattern already in the codebase rather than introducing a second JS mechanism; only US1's mutually-exclusive-views toggle needs the new Stimulus controller (research.md Decisions 1–2).
- Commit after each task or logical group.
- Stop at either checkpoint to validate a story independently.
