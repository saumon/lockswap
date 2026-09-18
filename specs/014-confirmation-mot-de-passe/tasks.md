---

description: "Task list for Password Confirmation and Visibility Toggle on Signup"
---

# Tasks: Password Confirmation and Visibility Toggle on Signup

**Input**: Design documents from `/specs/014-confirmation-mot-de-passe/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/form-contract.md](./contracts/form-contract.md), [quickstart.md](./quickstart.md)

**Tests**: Included as mandatory tasks, not optional — the project constitution's Testing Standards
principle is NON-NEGOTIABLE ("Every new feature ... MUST include automated tests that fail without
the change and pass with it"). This feature also modifies the behavior of two currently-passing
tests (`test/system/signup_test.rb`, `test/controllers/registrations_controller_test.rb`), which per
research.md R6 must be updated rather than left to silently start failing.

**Organization**: Tasks are grouped by user story (from spec.md: US1 = password confirmation match
gate, P1; US2 = per-field visibility toggle, P1) to enable independent implementation and testing of
each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on an incomplete task)
- **[Story]**: Which user story this task belongs to (US1, US2) — omitted for Setup/Foundational/Polish
- Every task names its exact file path

## Path Conventions

Single Rails monolith (see plan.md Project Structure) — `app/`, `config/`, `test/` at the repository
root. No new top-level directory; no frontend/backend split.

---

## Phase 1: Setup

**Purpose**: Project initialization.

**None required.** This feature adds no new gem, route, model, or migration — Devise, Stimulus
(via importmap), and the existing Tailwind design tokens are already in place (plan.md Technical
Context; research.md R1). Proceed directly to Phase 2.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared infrastructure both stories would need before either can be implemented.

**None required.** There is no new model, route, or migration for either story to share. Both
stories edit the same view file (`app/views/devise/registrations/new.html.erb`), so they are
sequenced rather than parallelized — see "Dependencies & Execution Order" below for exactly how.
Proceed directly to Phase 3.

---

## Phase 3: User Story 1 - Confirm the password before creating an account (Priority: P1) 🎯 MVP

**Goal**: The signup page has a "Confirm password" field; submission is blocked whenever it does not
exactly match "Password" (including when left blank), with a distinct mismatch message that first
appears after the visitor leaves the "Confirm password" field once, then updates live.

**Independent Test**: Fill in the signup form with a valid email and two matching passwords and
confirm the account is created; fill it in with two different passwords and confirm the submission
is blocked with a distinct error.

### Tests for User Story 1 ⚠️

> Write these tests FIRST; confirm the new assertions fail before the corresponding implementation
> task (the updates to already-passing tests are expected to fail differently — see research.md R6
> — until T003 exists).

- [X] T001 [P] [US1] (Also covers the Edge Case `/speckit-analyze` flagged as uncovered: the existing "password shorter than 8 characters" test now fills the confirmation with the *same* short value, so the length rule is proved to still fire when the two fields agree.) In `test/system/signup_test.rb`: (a) update every existing successful-signup test to also `fill_in "Confirm password", with:` the same value used for `"Password"` (research.md R6), so they keep passing once the field is enforced; (b) add new tests for spec.md User Story 1 Acceptance Scenarios 2–6: submitting different values in "Password" and "Confirm password" blocks signup and shows a message distinguishable from the "too short" error (FR-002, FR-003); correcting "Confirm password" to match clears the message and allows signup (Scenario 3); leaving "Confirm password" blank is treated as a mismatch (FR-002, Scenario 4); no mismatch message appears while first typing into "Confirm password" before leaving the field (Scenario 5); after leaving the field once while still mismatched, the message appears and then updates live on further edits to either field without leaving again (Scenario 6, FR-004)
- [X] T002 [P] [US1] (Four existing calls, not three. Also: these tests would *not* in fact have broken — a direct `post` that omits the key sends `nil`, which the confirmation validator skips, where the real form sends `""`, which it does not. research.md R6's warning holds for the system tests only; the change here is still right, because a controller test should send what the form sends.) In `test/controllers/registrations_controller_test.rb`: (a) update the existing `post user_registration_path` calls to include `password_confirmation: VALID_PASSWORD` (research.md R6), so they keep passing; (b) add a new test asserting that posting with a `password_confirmation` different from `password` responds with the form re-rendered (no redirect) and creates no new `User` row (FR-002, FR-009)

### Implementation for User Story 1

- [X] T003 [P] [US1] In `app/views/devise/registrations/new.html.erb`, add a "Confirm password" field directly after the existing "Password" field, mirroring the markup pattern already used for the same attribute in `app/views/devise/registrations/edit.html.erb`: `f.label :password_confirmation, class: "field-label"` and `f.password_field :password_confirmation, autocomplete: "new-password", class: "field-input"`, wrapped in a `.field` div (FR-001)
- [X] T004 [P] [US1] (Plus one key the task did not anticipate: `activerecord.attributes.user.password_confirmation: "Confirm password"`. Rails builds a full error message by prefixing the attribute's humanised name, so without this the form labels the field "Confirm password" and then reports "Password confirmation doesn't match" — the page answering in words it never used. Naming the attribute once fixes the label and the error together. Side effect, accepted: the account-settings page's own confirmation field is now labelled "Confirm password" too, which is the consistency the constitution's UX principle asks for and is covered by the existing suite.) In `config/locales/devise.en.yml`, add `activerecord.errors.models.user.attributes.password_confirmation.confirmation: "doesn't match the password above."`, placed as a sibling of the existing `password:` attribute block, matching that block's second-person, actionable tone (FR-003, research.md R2)
- [X] T005 [P] [US1] Create `app/javascript/controllers/password_confirmation_controller.js`: a Stimulus controller with `static targets = ["password", "confirmation", "hint"]`; track a `touched` flag that data-model.md defines as "Set the first time the 'Confirm password' field is blurred; gates when live mismatch feedback begins" — set it true on the confirmation target's `blur`, and only evaluate/show-or-hide the `hint` target (comparing `passwordTarget.value` to `confirmationTarget.value`) on `blur` and on subsequent `input` events on either target once `touched` is true; before `touched` is true, never show the hint (FR-004, data-model.md state transitions)
- [X] T006 [US1] In `app/views/devise/registrations/new.html.erb`, wire T005's controller onto the two password fields: `data-controller="password-confirmation"` on their shared wrapping element, `data-password-confirmation-target="password"` / `"confirmation"` on the two inputs, `data-action="input->password-confirmation#check"` on the password input and `data-action="blur->password-confirmation#check input->password-confirmation#check"` on the confirmation input, and a `data-password-confirmation-target="hint"` element styled with the existing `.field-error` class, initially `hidden`, carrying the same wording as the T004 locale message *(depends on T003, T005)*

**Checkpoint**: User Story 1 is fully functional and independently testable — mismatched passwords
are blocked, with a distinct, correctly-timed message.

---

## Phase 4: User Story 2 - Reveal typed password characters to verify correct entry (Priority: P1)

**Goal**: Each password field ("Password" and "Confirm password") has its own "eye" control that
toggles that field's content between masked and plain readable text, independently of the other
field.

**Independent Test**: Type a password into either field, activate its eye control, and confirm the
field's content becomes readable plain text; toggle again and confirm it returns to masked;
confirm the other field's masking is unaffected throughout.

### Tests for User Story 2 ⚠️

> Write these tests FIRST; confirm they fail before the corresponding implementation task.

- [X] T007 [P] [US2] Create `test/system/password_visibility_test.rb` covering spec.md User Story 2
  Acceptance Scenarios 1–4 and its Edge Cases: activating the "Password" field's eye control reveals
  its typed text and toggling again re-masks it; the "Confirm password" field's eye control does the
  same fully independently — toggling one never changes the other's masked/revealed state; characters
  typed after revealing remain visible without re-toggling; reloading the page resets both fields to
  masked by default (data-model.md: "Resets to `false` (masked) on every fresh page load"); and each
  toggle button is reachable and operable via keyboard alone, with its accessible name/state changing
  between a "shown" and "hidden" description rather than relying on the icon alone (FR-008)

### Implementation for User Story 2

- [X] T008 [P] [US2] In `app/assets/tailwind/application.css`, add `.field-input-wrapper` (`position: relative`, matching the existing `.field-input` block's location) and `.field-visibility-toggle` (an icon-sized `<button>` positioned at the input's trailing edge, no background/border like `.field-link-action`, with a visible `:focus-visible` outline) near the existing `.field`/`.field-input`/`.field-hint` rules (FR-005)
- [X] T009 [P] [US2] (Two deviations, both deliberate. **No `aria-pressed`**: a toggle button that changes its *name* and reports a pressed state announces two overlapping answers — "Hide password, pressed" leaves the listener to work out which half is the current state and which is the offer. The accessible name alone carries it, which is the documented pattern for a password reveal. **The icon swap moved from JS to CSS**: it is driven by `.field-input[type="text"] ~ .field-visibility-toggle`, so which eye is drawn is read off the field's real state instead of a second copy of it kept in script.) Create `app/javascript/controllers/password_visibility_controller.js`: a Stimulus controller with `static targets = ["input", "button"]`; a `toggle()` action that flips `inputTarget.type` between `"password"` and `"text"`, and updates `buttonTarget`'s `aria-label` between `"Show password"` and `"Hide password"` (or equivalent), and toggles which of two inline icon elements is `hidden` — with no state shared outside this one controller instance, so two independent instances never affect each other by construction (FR-005, FR-006, FR-007, FR-008; research.md R4)
- [X] T010 [US2] (The wrapper, input and button are rendered from one new partial, `app/views/devise/shared/_password_field.html.erb`, rather than written out inline here and again in T011: the block is fifteen lines of icon markup, and two copies of it in one file is the duplication the constitution's Code Quality principle says to refactor rather than repeat. The partial takes the field's `subject` — "password", "confirm password" — which is what gives the two controls distinct accessible names.) In `app/views/devise/registrations/new.html.erb`, wrap the "Password" field's input in a `.field-input-wrapper`, add `data-controller="password-visibility"` to that wrapper, `data-password-visibility-target="input"` on the input, and a `<button type="button" data-password-visibility-target="button" data-action="password-visibility#toggle" aria-pressed="false" aria-label="Show password">` containing two inline `aria-hidden="true" focusable="false"` eye/eye-off SVGs (matching the icon-button pattern in `app/views/home/_locker_profile.html.erb`) *(depends on T008, T009)*
- [X] T011 [US2] (A second render of T010's partial, which is what "repeat" comes to here.) Repeat T010's wrapper/button/controller markup for the "Confirm password" field added in Phase 3, as its own independent `data-controller="password-visibility"` instance *(depends on T003, T008, T009, T010)*

**Checkpoint**: Both P1 user stories are independently functional — password confirmation gates
signup, and either field's typed content can be revealed and re-masked without affecting the other.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Verification that spans both user stories.

- [X] T012 [P] Run `rubocop` across the app and resolve any warnings introduced by this feature (constitution Code Quality gate — zero unresolved warnings)
- [X] T013 Run `test/system/accessibility_test.rb`'s existing `"sign up is accessible"` axe check against the changed signup page and confirm it still passes with no test edits required (constitution User Experience Consistency; quickstart.md)
- [X] T014 Run the `specs/014-confirmation-mot-de-passe/quickstart.md` validation checklist end-to-end, then run `bin/rails test` and `bin/rails test:system` for the full suite

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: None required — proceed directly to Phase 2.
- **Foundational (Phase 2)**: None required — proceed directly to Phase 3.
- **User Stories (Phase 3-4)**: Both P1. User Story 1 (Phase 3) is sequenced first because User
  Story 2's second target — the "Confirm password" field's own eye control (T011) — needs that
  field to already exist (T003). User Story 1's own behavior has no dependency on User Story 2.
- **Polish (Phase 5)**: Depends on both user stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: No dependency on User Story 2. This is the MVP slice.
- **User Story 2 (P1)**: T010 (the "Password" field's toggle) has no dependency on User Story 1.
  T011 (the "Confirm password" field's toggle) depends on User Story 1's T003. Both T010 and T011
  edit `new.html.erb`, the same file User Story 1 edits, so Phase 4's view edits are sequenced after
  Phase 3's, not run in parallel with them.

### Parallel Opportunities

- T001 and T002 (different test files, no dependency between them) can run in parallel.
- T003, T004, and T005 (different files: view, locale, JS controller — no dependency between them)
  can run in parallel; T006 waits for both T003 and T005.
- T007, T008, and T009 (different files, no dependency between them) can run in parallel; T010
  waits for T008 and T009, and T011 waits for T003 and T010.
- T012 can run in parallel with T013/T014.

---

## Parallel Example: User Story 1

```bash
# Launch both test-file updates together:
Task: "Update and extend test/system/signup_test.rb per T001"
Task: "Update and extend test/controllers/registrations_controller_test.rb per T002"

# Once tests are in place, launch the three independent implementation files together:
Task: "Add Confirm password field in app/views/devise/registrations/new.html.erb (T003)"
Task: "Add locale message in config/locales/devise.en.yml (T004)"
Task: "Create app/javascript/controllers/password_confirmation_controller.js (T005)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (none required)
2. Complete Phase 2: Foundational (none required)
3. Complete Phase 3: User Story 1 (T001–T006)
4. **STOP and VALIDATE**: Confirm mismatched passwords are blocked, with the distinct,
   correctly-timed message, per spec.md User Story 1's Independent Test
5. Deploy/demo if ready — the signup page already ships real value with just the confirmation gate

### Incremental Delivery

1. User Story 1 (T001–T006) → Test independently → Deploy/Demo (MVP)
2. User Story 2 (T007–T011) → Test independently → Deploy/Demo (adds the reveal/hide toggles)
3. Polish (T012–T014) → Full-suite and accessibility verification before merge

---

## Notes

- [P] tasks touch different files with no dependency on an incomplete task.
- [Story] label maps each task to US1 or US2 for traceability; Setup/Foundational/Polish carry none.
- Both existing tests updated in T001/T002 must be re-run to confirm they pass again, not just that
  the new assertions pass (research.md R6 — this is a required fix, not an optional cleanup).
- Commit after each task or logical group; stop at either Checkpoint to validate a story
  independently before continuing.
