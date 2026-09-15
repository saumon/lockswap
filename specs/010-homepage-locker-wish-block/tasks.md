---

description: "Task list for the homepage locker wish block"
---

# Tasks: Homepage Locker Wish Block

**Input**: Design documents from `/specs/010-homepage-locker-wish-block/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/homepage-locker-wish-block.md](./contracts/homepage-locker-wish-block.md), [quickstart.md](./quickstart.md)

**Tests**: Included and NOT optional. Constitution Principle II is non-negotiable: every change ships with automated tests that fail without it. This feature is purely presentational, so system tests are its primary evidence — write each one first and watch it fail.

**Organization**: Tasks are grouped by user story. Note the structural constraint recorded in plan.md: all three states live in the **same partial**, so the three stories are independently *testable* but not independently *editable* — they share `app/views/home/_locker_wish.html.erb` and must be done in sequence, not in parallel by different people.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Single Rails monolith. Views in `app/views/`, tests in `test/`, fixtures in `test/fixtures/`. No `src/`.

---

## Phase 1: Setup

**Purpose**: A branch to work on and a known-green starting point

- [X] T001 Create the feature branch from `dev`: `git checkout dev && git checkout -b feature/010-homepage-locker-wish-block` (no hook does this — `.specify/extensions.yml` does not exist in this repo)
- [X] T002 Record a green baseline before touching anything: run `bin/rails test && bin/rails test:system && bin/rubocop` from the repository root and confirm all three pass

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The block's container and its placement — shared by all three states

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 Create `app/views/home/_locker_wish.html.erb` containing only the shared shell and the empty three-way branch: a `<div id="home-locker-wish" class="card stack-tight">` wrapping a per-state `<h2 class="card-title">` — each branch supplies its own text, per the States table in the contract — then `if current_user.locker_wish&.persisted?` / `elsif current_user.saved_locker_number.present?` / `else`, with each branch body left as a TODO comment naming the story that fills it (US1, US2, US3). Read state through `current_user` only — no instance variable, per research.md §1
- [X] T004 Render the partial from `app/views/home/index.html.erb` with `<%= render "home/locker_wish" %>`, placed inside the existing `if current_user.saved_floor.present?` branch and immediately above the existing `<%= render "home/locker_profile", editable: !locked %>` line — that one placement satisfies both FR-001a (withheld until details are saved) and FR-012 (after swap proposals, above the locker card). Add an ERB comment citing both requirement ids, matching the commenting style of the surrounding partials
- [X] T005 Create `test/system/homepage_locker_wish_test.rb` as `class HomepageLockerWishTest < ApplicationSystemTestCase`, and add the FR-001a case first: logging in as `users(:alice)` (no floor, no locker) shows no `#home-locker-wish` anywhere on the homepage — `assert_no_selector "#home-locker-wish"` — while the "Add your locker details" card is still present. Confirm it passes against T003/T004 and would fail if the render were moved outside the saved-details branch

**Checkpoint**: The block renders in the right place for the right people, with three empty states. Every story below fills exactly one branch.

---

## Phase 3: User Story 1 - See my declared wish on the homepage (Priority: P1) 🎯 MVP

**Goal**: A user who has declared a wish sees the floor they are looking for, plus the one way in to the wish page.

**Independent Test**: Log in as `users(:bob)` (locker B12 on floor 3, wish for floor 7) and as `users(:carol)` (floor 2, no locker, wish for floor 5); both see the floor they seek and a "Review locker wishes! 🥷" button that reaches `/locker_wishes` in one action.

### Tests for User Story 1 ⚠️ Write first, watch them fail

- [X] T006 [US1] In `test/system/homepage_locker_wish_test.rb`, add the wish-state test: as `users(:bob)`, `#home-locker-wish-floor` reads `7`, the block contains a link with the exact text `Review locker wishes! 🥷`, and it holds no "I want" invitation text (FR-002, FR-003)
- [X] T007 [US1] In `test/system/homepage_locker_wish_test.rb`, add the no-duplication test: as `users(:bob)`, the `#home-locker-wish` block does not contain `B12` or the text `Floor 3` — the `#locker-profile` card below is the only place the user's own locker appears (FR-002, per the clarification)
- [X] T008 [US1] In `test/system/homepage_locker_wish_test.rb`, add the precedence test: as `users(:carol)` (a wish but no locker), the block shows floor `5` and the `Review locker wishes! 🥷` button — never `I want a locker! 🙏` (spec Edge Cases)
- [X] T009 [US1] In `test/system/homepage_locker_wish_test.rb`, add the navigation test: as `users(:bob)`, clicking `Review locker wishes! 🥷` lands on `locker_wishes_path` — assert with `assert_current_path locker_wishes_path` after `wait_for_turbo` (FR-006)
- [X] T010 [US1] In `test/system/homepage_locker_wish_test.rb`, add the freshness test: as `users(:bob)`, change the wish floor on the wish page, return to the homepage via `visit root_path`, call `wait_for_turbo`, and assert `#home-locker-wish-floor` reads the new floor — the Turbo cached snapshot carries the old value without that wait (FR-007, research.md §6)
- [X] T010a [US1] In `test/system/homepage_locker_wish_test.rb`, add the cancellation-freshness test: as `users(:bob)`, cancel the wish from the wish page, return to the homepage via `visit root_path`, call `wait_for_turbo`, then assert the wish state is gone — `assert_no_selector "#home-locker-wish-floor"` and no `Review locker wishes! 🥷` link. Asserting only the *absence* here keeps this phase green before US2 exists; T012 adds the assertion about which invitation replaces it (FR-007, SC-004, US1 acceptance scenario 4)

### Implementation for User Story 1

- [X] T011 [US1] Fill the wish branch in `app/views/home/_locker_wish.html.erb`: a `<dl>` with `<dt class="detail-term">Looking for a locker on floor</dt>` and `<dd id="home-locker-wish-floor" class="detail-value">`, reading `current_user.locker_wish.saved_floor` — the value on file, not the attribute (data-model.md) — followed by `<div class="row">` holding `link_to "Review locker wishes! 🥷", locker_wishes_path, class: "btn btn-primary"`. A link, not `button_to`: this navigates and changes nothing (research.md §2). Label text is exact, emoji included

**Checkpoint**: User Story 1 is fully functional. The other two branches still render an empty card — that is the next two stories, and T005's test still passes.

---

## Phase 4: User Story 2 - Be invited to switch when I already have a locker (Priority: P2)

**Goal**: A locker holder with no wish is invited to swap, in one click.

**Independent Test**: Log in as `users(:dave)` (locker D07 on floor 4, deliberately no wish) and confirm the block offers "I want to switch my locker! 👀", shows no wish values, and reaches `/locker_wishes`.

### Tests for User Story 2 ⚠️ Write first, watch them fail

- [X] T012 [US2] In `test/system/homepage_locker_wish_test.rb`, add the switch-invitation test: as `users(:dave)`, the block contains a link with the exact text `I want to switch my locker! 👀`, and `assert_no_selector "#home-locker-wish-floor"` — the invitation states render no wish values (FR-004). Then extend T010a's cancellation test: after `users(:bob)` cancels a wish, the block shows `I want to switch my locker! 👀` — bob has a locker, so cancelling drops him into this state (SC-004)
- [X] T013 [US2] In `test/system/homepage_locker_wish_test.rb`, add the navigation test: as `users(:dave)`, clicking that button lands on `locker_wishes_path` after `wait_for_turbo` (FR-006)
- [X] T014 [US2] In `test/system/homepage_locker_wish_test.rb`, add the active-proposal test (FR-013): create an accepted `LockerSwapProposal` involving `users(:dave)` in the test itself — the fixtures deliberately contain no accepted proposal, per the comment at the top of `test/fixtures/locker_swap_proposals.yml` — then assert the homepage still shows `I want to switch my locker! 👀` and its working link, while `#locker-profile-locked` confirms the card below really is frozen

### Implementation for User Story 2

- [X] T015 [US2] Fill the has-locker branch in `app/views/home/_locker_wish.html.erb`: `<p class="card-lead">You haven't said where you'd rather be. Tell people which floor you're after and find someone to swap with.</p>`, then `<div class="row">` holding `link_to "I want to switch my locker! 👀", locker_wishes_path, class: "btn btn-primary"`. No wish markup in this branch, and nothing conditional on any swap proposal (FR-013)

**Checkpoint**: User Stories 1 and 2 both work. Only the no-locker branch is still empty.

---

## Phase 5: User Story 3 - Be invited to ask for a locker when I have none (Priority: P3)

**Goal**: A user with saved details but no locker and no wish is invited to ask for one.

**Independent Test**: Log in as the new fixture user (floor on file, no locker number, no wish) and confirm the block offers "I want a locker! 🙏" and reaches `/locker_wishes`.

### Setup for User Story 3

- [X] T016 [US3] Add a user fixture to `test/fixtures/users.yml` for the state no existing fixture covers — a floor on file, **no** `locker_number`, and **no** wish in `test/fixtures/locker_wishes.yml`. Follow the file's existing style: an `email`, `encrypted_password: <%= Devise::Encryptor.digest(User, "password123") %>`, `failed_attempts: 0`, and a comment saying which case the fixture exists for (`carol` cannot serve: she already carries `carol_wish`). Give it a floor that does not collide with another user's floor + locker pair
- [X] T017 [US3] Re-run the existing suites that read these fixtures — `bin/rails test test/system/locker_wish_test.rb test/system/locker_swap_proposal_test.rb test/controllers/locker_wishes_controller_test.rb` — and confirm the new user changes no existing expectation (it has neither wish nor proposal, so no list or history row moves)

### Tests for User Story 3 ⚠️ Write first, watch them fail

- [X] T018 [US3] In `test/system/homepage_locker_wish_test.rb`, add the ask-invitation test: as the new fixture user, the block contains a link with the exact text `I want a locker! 🙏`, and `assert_no_selector "#home-locker-wish-floor"` (FR-005)
- [X] T019 [US3] In `test/system/homepage_locker_wish_test.rb`, add the navigation test: as the new fixture user, clicking that button lands on `locker_wishes_path` after `wait_for_turbo` — this is the requirement the clarification added, so a plain-text third state would fail here (FR-005, FR-006)

### Implementation for User Story 3

- [X] T020 [US3] Fill the else branch in `app/views/home/_locker_wish.html.erb`: `<p class="card-lead">You don't have a locker yet. Say which floor you're looking on so people know you're waiting for one.</p>`, then `<div class="row">` holding `link_to "I want a locker! 🙏", locker_wishes_path, class: "btn btn-primary"`. Replace the TODO comment left by T003 with a comment explaining why this branch is a button and not text, citing the clarification

**Checkpoint**: All three states are implemented and independently covered.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T021 [P] Add the third state to the accessibility suite: in `test/system/accessibility_test.rb`, add a homepage `assert_axe_clean` test logged in as the new fixture user, alongside the existing homepage audits (008 FR-028). No rule skip and no exemption is permitted for this block (contract, Accessibility)
- [X] T022 [P] In `test/system/homepage_locker_wish_test.rb`, add the exclusivity assertion that SC-002 rests on: for each of the three fixture states, exactly one link exists inside `#home-locker-wish` — never zero, never two. In the same test, assert the block contains no form — `assert_no_selector "#home-locker-wish form"` — so it can never grow a declare, edit or cancel control (FR-009)
- [X] T022a [P] In `test/system/homepage_locker_wish_test.rb`, assert the placement FR-012 fixes: as `users(:bob)`, `#home-locker-wish` follows every swap-proposal section and immediately precedes `#locker-profile` in the DOM — `assert_selector "#home-locker-wish + #locker-profile"` if the two are adjacent siblings in the homepage stack, otherwise an XPath `following-sibling` check. Verify the adjacency against the real DOM rather than assuming it: in the active-proposal case `#locker-profile-locked` renders *after* `#locker-profile`, so the pair stays adjacent, but a future card between them would make `+` the wrong operator (FR-012)
- [X] T023 Confirm the design did not drift: `git diff --stat dev` should touch only `app/views/home/index.html.erb`, `app/views/home/_locker_wish.html.erb`, `test/system/homepage_locker_wish_test.rb`, `test/system/accessibility_test.rb` and `test/fixtures/users.yml`. Any change to `config/routes.rb`, a controller, a model, a migration, the stylesheet or JavaScript means a decision in [research.md](./research.md) was overturned — stop and record why before continuing (quickstart.md, "What would mean the design drifted")
- [X] T024 Run the full gates from the repository root: `bin/rails test && bin/rails test:system && bin/rubocop`, all green with no new skips (Quality Gates: lint gate, test gate)
- [ ] T025 Walk the manual validation table in [quickstart.md](./quickstart.md) against `bin/dev` — all five fixture states, plus the keyboard check that the control takes visible focus and is announced as a link with its label as its accessible name (FR-010)
- [ ] T026 Open the pull request into `dev` with the evidence the Development Workflow requires: which Core Principles the change implicates and how it satisfies them, the accessibility/consistency note (existing card and button classes reused, no new visual pattern, no new stylesheet rule), and a line stating no performance-sensitive path was touched (one memoized indexed lookup added)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: T003 → T004 → T005, in that order. **Blocks every user story**
- **User Stories (Phases 3–5)**: All depend on Phase 2. They share one file, so run them **sequentially** in priority order: US1 → US2 → US3
- **Polish (Phase 6)**: Depends on all three stories

### User Story Dependencies

- **US1 (P1)**: After Phase 2. Independent — fills the first branch
- **US2 (P2)**: After Phase 2. Independent of US1's behaviour, but edits the same partial, so land US1 first to avoid a conflict in `_locker_wish.html.erb`
- **US3 (P3)**: After Phase 2. Same file constraint; also owns the new fixture (T016), which nothing else needs

### Within Each User Story

- Tests first, failing, before the branch that satisfies them
- One branch per story; never edit another story's branch to make your test pass

### Parallel Opportunities

Genuinely limited — this is a one-partial feature, and honest sequencing beats a misleading `[P]`:

- **Within a story**: the test tasks touch one file each and are written in one sitting; they are listed in order rather than marked `[P]` because they all append to `test/system/homepage_locker_wish_test.rb`
- **Phase 6**: T021 (`accessibility_test.rb`) is a different file from T022/T022a (`homepage_locker_wish_test.rb`) and is marked `[P]`; T022 and T022a share a file and are `[P]` only relative to T021
- **Across stories**: none. Three people on this feature would collide in one partial

---

## Implementation Strategy

### MVP (User Story 1 only)

1. Phase 1: Setup
2. Phase 2: Foundational — the shell and its placement
3. Phase 3: User Story 1
4. **STOP and VALIDATE**: `bin/rails test test/system/homepage_locker_wish_test.rb`; log in as `bob` and as `carol` and see the wish on the homepage
5. Shippable: users who have declared a wish now see it. Users who have not see an empty card — so ship the MVP alone only as a demo, not to production

### Incremental Delivery

1. Setup + Foundational → block renders, in the right place, for the right people
2. US1 → wish state → validate → demo
3. US2 → switch invitation → validate → demo
4. US3 → ask invitation → validate → **now production-ready**: no state renders an empty card
5. Polish → accessibility, exclusivity, drift check, gates, PR

### Notes

- `[P]` means different files with no dependency between them
- The exact button labels — `Review locker wishes! 🥷`, `I want to switch my locker! 👀`, `I want a locker! 🙏` — are assertion targets; changing the wording means changing the spec first
- Commit after each task or logical group; the suite is the gate at every checkpoint
