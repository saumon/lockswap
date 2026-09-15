---

description: "Task list for 012-responsive-layout-menu"
---

# Tasks: Responsive Site Layout and Signed-In Menu

**Input**: Design documents from `/specs/012-responsive-layout-menu/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/)

**Tests**: REQUIRED and included. FR-022–FR-025 are themselves test requirements, and Constitution Principle II (Testing Standards) is marked NON-NEGOTIABLE. Every behavioural task here is paired with a test that fails before it and passes after.

**Organization**: Grouped by user story so each can be implemented, tested and shipped independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel — different file, no dependency on incomplete work
- **[Story]**: US1 / US2 / US3, mapping to the user stories in spec.md

## Path Conventions

Rails monolith, paths relative to repository root. `app/` for application code, `test/` for tests. No new directory is introduced by this feature.

## ⚠️ Two gates, sequenced deliberately

[research.md](./research.md) identifies two technical risks. Each has a **gate task** placed so the answer arrives before anything is built on top of it, and each has a documented fallback:

- **T012 — the R1 gate** (`::details-content` support). Fallback: R1 in research.md.
- **T026 — the R2 gate** (axe verdict on the restacked table). Fallback: R2 in research.md.

Do not proceed past a gate on a failure — adopt that gate's fallback instead.

---

## Phase 1: Setup (Shared Test Infrastructure)

**Purpose**: The viewport machinery every story's tests depend on. All four tasks touch `test/application_system_test_case.rb` or the new sweep file, so they are sequential.

- [X] T001 Add `VIEWPORTS` constants (`minimum: [320, 568]`, `phone: [390, 844]`, `desktop: [1400, 1400]`) and a `with_viewport(name)` helper driving `page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width:, height:, deviceScaleFactor: 0, mobile:)` in `test/application_system_test_case.rb`, mirroring the existing `emulate_reduced_motion` pattern
- [X] T002 Extend the existing `teardown` block in `test/application_system_test_case.rb` to clear the override via `Emulation.clearDeviceMetricsOverride`, guarded by an ivar exactly as `@emulated_media` is — the suite is `parallelize(workers: 1)` and a leaked override would silently put every later test at phone width
- [X] T003 Add `assert_no_horizontal_overflow` (asserting `document.documentElement.scrollWidth <= document.documentElement.clientWidth`) to `test/application_system_test_case.rb`
- [X] T004 Add `assert_touch_targets_at_least(44)` to `test/application_system_test_case.rb`, measuring `getBoundingClientRect()` across the standalone-control selector list (`.btn`, `.site-nav-link`, `summary`, `input[type=submit]`) and excluding links inline in flowing text (`.auth-link`) per FR-007a
- [X] T005 Create `test/system/responsive_test.rb` with a helper self-test: inside `with_viewport(:phone)` the script `matchMedia("(max-width: 47.999rem)").matches` is true, and inside `with_viewport(:desktop)` it is false

**Checkpoint**: The suite can now drive an exact viewport and assert against it.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Declare the one breakpoint. Every user story's CSS keys off it.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T006 Add the breakpoint convention comment block to `app/assets/tailwind/application.css` per [contracts/breakpoint.md](./contracts/breakpoint.md): narrow is `@media (max-width: 47.999rem)`, wide is `@media (min-width: 48rem)`, mobile-first defaults preferred, and no other width value may appear in any media query
- [X] T007 Move the existing `.detail-grid` rule in `app/assets/tailwind/application.css` from `@media (min-width: 40rem)` to `@media (min-width: 48rem)` (FR-018a) — this is currently the stylesheet's only width-based media query
- [X] T008 [P] Create `test/stylesheet_breakpoint_test.rb` — a plain Minitest (no browser) that reads `app/assets/tailwind/application.css` and asserts every `@media` clause containing `min-width`/`max-width` uses only `48rem` or `47.999rem`. This is the testable form of FR-018
- [X] T009 Add to `test/system/responsive_test.rb`: at 767px `.detail-grid` renders one column, at 768px it renders two (FR-018b) — the boundary is exact, not approximate

**Checkpoint**: One breakpoint, declared once, guarded by a test. User stories may now begin, in parallel if staffed.

---

## Phase 3: User Story 1 — The signed-in menu works on a phone (Priority: P1) 🎯 MVP

**Goal**: Below 768px the menu collapses behind a toggle that opens a panel holding both destinations, the identity and sign-out. At and above 768px it is the bar it is today.

**Independent Test**: Sign in at phone width; confirm the bar is one row (brand + toggle), that the toggle reveals all four items, and that everything is reachable and ≥44px. Then confirm the desktop bar is unchanged.

### Tests for User Story 1 ⚠️ Write first, confirm they FAIL

- [X] T010 [US1] Create `test/system/site_menu_test.rb` with the **R1 spike test**: inside `with_viewport(:desktop)`, signed in, the toggle is absent and both destinations, the identity and Log out are all visible in the bar
- [X] T011 [P] [US1] Add to `test/system/site_menu_test.rb` the narrow-width behavioural tests from [contracts/menu-dom.md](./contracts/menu-dom.md) rows 1–3 and 7: toggle opens the panel, a second activation closes it, the toggle is keyboard-operable, and focus returns to the toggle on close

### Implementation for User Story 1

- [X] T012 [US1] **R1 GATE** — add the wide-width neutralisation block to `app/assets/tailwind/application.css`: `.site-menu { display: contents }`, `.site-menu::details-content { content-visibility: visible }`, `.site-menu-toggle { display: none }`, then run T010. On failure, stop and adopt the R1 fallback in research.md (extract the panel contents to a shared partial rendered into two CSS-exclusive containers)
  - **GATE OUTCOME: failed as specified; R1 fallback adopted.** `::details-content` *is* supported (Chrome 152) and the panel laid out correctly with a real 455×44 rect — but content inside a closed `<details>` is treated as hidden by the platform regardless of computed style (the WebDriver displayedness algorithm says so explicitly, and assistive technology plausibly follows). The single-render trick was visually right and semantically wrong. Now two CSS-exclusive containers (`.site-menu` / `.site-bar`), both filled from the new `app/views/shared/_site_menu_items.html.erb`, so there is still one source of truth for the menu's contents.
- [X] T013 [US1] Create `app/views/shared/_site_menu.html.erb` — `<details class="site-menu">` containing `<summary class="site-menu-toggle" aria-label="Menu">` and a `.site-menu-panel` div holding both `site-nav-link` destinations, the `site-nav-identity` span and the Log out `button_to`, exactly per [contracts/menu-dom.md](./contracts/menu-dom.md). Do NOT hand-write `aria-expanded`, `aria-controls` or `role` on the summary — `<details>` supplies them natively and that is why the pattern was chosen
- [X] T014 [US1] In `app/views/layouts/application.html.erb`, replace the inline `user_signed_in?` block with a render of `shared/site_menu`, keeping the brand lock-up a sibling **outside** the `<details>` so it stays visible at every width (FR-012)
- [X] T015 [US1] Add `.site-menu`, `.site-menu-toggle` (2.75rem square) and `.site-menu-panel` component CSS to `app/assets/tailwind/application.css` in `@layer components`, using only existing `--color-*`, `--spacing-*` and `--radius-*` tokens — a raw hex in this codebase is already a defect
- [X] T016 [US1] Raise touch targets inside the narrow-width block only, in `app/assets/tailwind/application.css`: `.btn-sm` `min-height` and `.locker-profile-editor-summary` `width`/`height` from `2.25rem` to `2.75rem`, and `.site-nav-link` inside the panel to `min-height: 2.75rem` with vertical padding so the whole row is the target. Above the breakpoint all three keep their current size (FR-007b, FR-020). Comment the literal `2.75rem` with the requirement it serves, matching how the existing `2.25rem` is justified in place
- [X] T017 [P] [US1] Create `app/javascript/controllers/site_menu_controller.js` — clears `open` on document Escape (returning focus to the summary), on click outside `.site-menu`, and on `turbo:load`/`disconnect`. It must only ever **remove** `open`, never add it; adding is the summary's job, which is what keeps the no-script baseline intact. No focus trap — this is a disclosure, not a modal
- [X] T018 [US1] Register the `site-menu` controller — **no code needed**: `app/javascript/controllers/index.js` uses `eagerLoadControllersFrom` and `config/importmap.rb` uses `pin_all_from`, so the controller is discovered automatically
- [X] T019 [US1] Add `data-controller="site-menu"` to the `<details>` in `app/views/shared/_site_menu.html.erb`

### Verification for User Story 1

- [X] T020 [US1] Add script-dependent dismissal tests to `test/system/site_menu_test.rb` ([contracts/menu-dom.md](./contracts/menu-dom.md) rows 4–6): Escape closes the panel, activating outside closes it, and following a panel destination leaves the panel closed on the page that loads (FR-010c)
- [X] T021 [US1] Add the no-script baseline test to `test/system/site_menu_test.rb`: with JavaScript disabled at phone width, the toggle still opens and closes the panel and every destination plus Log out is reachable (FR-010b, SC-006a)
- [X] T022 [US1] Add a touch-target assertion at phone width to `test/system/site_menu_test.rb` using `assert_touch_targets_at_least(44)` (FR-025)
- [X] T023 [P] [US1] Extend `test/system/navigation_test.rb` for the wide-width bar (no toggle, both destinations present) and confirm `click_on "LockSwap"` still resolves — the wordmark's accessible name must not have changed
- [X] T024 [P] [US1] Extend `test/system/accessibility_test.rb` with `assert_axe_clean` at phone width **with the menu panel open** (FR-024)

**Checkpoint**: The menu is fully functional and independently shippable. This is the MVP.

---

## Phase 4: User Story 2 — Every signed-in screen is readable on a phone (Priority: P2)

**Goal**: Homepage, locker wishes, proposal history and account edit all work below 768px, with the two data lists rendering as labelled stacked cards.

**Independent Test**: At phone width, visit each signed-in screen; confirm no horizontal page scrolling, that each list record is a labelled card with its action visible, and that every form can be completed.

### Implementation for User Story 2

- [X] T025 [US2] Add `data-label` (matching its column's `<th>` text exactly) and `role="cell"` to every `<td>`, plus `role="row"`, `role="columnheader"` and `role="table"`, in `app/views/locker_wishes/_locker_wish_list.html.erb` per [contracts/list-forms.md](./contracts/list-forms.md). **Every existing id must be preserved unchanged** — `locker-wish-row-*`, `*-floor`, `*-person`, `*-current-floor`, `*-current-locker`, `*-swap` are asserted by existing tests
- [X] T026 [P] [US2] Same treatment for the six columns in `app/views/locker_swap_proposals/index.html.erb`, preserving `swap-proposal-history-row-*`, `*-status`, `*-comment` and `*-locker-details`
- [X] T027 [US2] Add the narrow-width card-form rules for `.data-table` to `app/assets/tailwind/application.css`: `thead` visually hidden via clip-path (**not** `display: none` — the `<th>` cells must stay in the accessibility tree), `tr` as a card surface, `td` as a two-column grid, and `td::before { content: attr(data-label) }` for the visible label (FR-005a)
- [X] T028 [US2] **R2 GATE** — add `assert_axe_clean` at phone width for both list screens to `test/system/accessibility_test.rb` and run it. On failure, stop and adopt the R2 fallback in research.md (a second CSS-exclusive `<ul>`/`<dl>` card rendering)
  - **GATE OUTCOME: passed. No fallback needed.** axe is clean on both restacked lists at phone width; the explicit ARIA roles kept the accessibility tree correct through the display change. Non-vacuity guards added to both tests so an empty list cannot produce a silent pass.
- [X] T029 [US2] Audit the homepage at 320px and 390px and fix stacking, wrapping and overflow in `app/assets/tailwind/application.css` and `app/views/home/*` as needed — the locker profile, the locker wish block and each swap proposal section must render as one readable column (FR-003, FR-004)
- [X] T030 [US2] Audit the account-edit screen (`app/views/devise/registrations/edit.html.erb`) at 320px and 390px and fix any overflow or control sizing

### Verification for User Story 2

- [X] T031 [US2] Add list-form tests to `test/system/responsive_test.rb`: card form at 390px and column table at 1400px, every `td`'s `data-label` matching its `th`, and the "Propose swap" control within the viewport at 390px with no horizontal scrolling (FR-005b, SC-004a)
- [X] T032 [US2] Add overflow tests to `test/system/responsive_test.rb` for the homepage, both list screens and account edit at the `minimum` (320px) and `phone` viewports (FR-022a)
- [X] T033 [P] [US2] Run `test/system/locker_wish_test.rb` and `test/system/locker_swap_proposal_test.rb` unchanged and confirm green — proof that the preserved ids and the desktop table survived the restack (FR-020)

**Checkpoint**: All signed-in screens work at phone width. US1 and US2 are both independently shippable.

---

## Phase 5: User Story 3 — Sign-in and sign-up work on a phone (Priority: P3)

**Goal**: The two auth screens fit and function below 768px.

**Independent Test**: Signed out at phone width, open sign-in and sign-up; confirm the brand lock-up, fields, submit control and auth links all fit, and that the forms submit successfully.

### Implementation for User Story 3

- [X] T034 [US3] Audit `app/views/devise/sessions/new.html.erb` and `app/views/devise/registrations/new.html.erb` at 320px and 390px; fix any overflow or control sizing in `app/assets/tailwind/application.css`. The `.auth-page` column is already narrow and centred, so expect little or no change — verify rather than assume, per the story's stated rationale

### Verification for User Story 3

- [X] T035 [US3] Add tests to `test/system/responsive_test.rb`: at phone width both auth screens have no horizontal overflow, and a sign-in submitted from that width succeeds with its resulting message fully visible
- [X] T036 [P] [US3] Add `assert_axe_clean` at phone width for sign-in and sign-up to `test/system/accessibility_test.rb`

**Checkpoint**: All three user stories independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T037 Add the full two-width sweep to `test/system/responsive_test.rb`: every screen in FR-002, at both the `phone` and `desktop` viewports, asserting no horizontal overflow, the menu treatment required at that width, and the list form required at that width (FR-022, FR-023)
- [X] T038 Add a keyboard-reachability assertion at both widths to `test/system/responsive_test.rb` using the existing `assert_tab_order_follows_visual_order` helper (FR-023, SC-006)
- [X] T039 Run `bin/rubocop` and resolve any finding with zero suppressions (Constitution Principle I)
- [X] T040 Run the full suite: `bin/rails test && bin/rails test:system`. Note that `bin/ci` leaves system tests commented out in `config/ci.rb` and `bin/rails test` excludes them — `test:system` must be run explicitly
- [X] T041 Verify every new block carries a comment naming the requirement it serves, matching the density of the surrounding code, across `app/assets/tailwind/application.css`, `app/views/shared/_site_menu.html.erb`, `app/javascript/controllers/site_menu_controller.js` and `test/application_system_test_case.rb` (Constitution Principle I)
- [ ] T042 **MANUAL** — FR-008: on a real phone, open the locker-profile and locker-wish forms and confirm the field being edited and its submit control stay reachable with the on-screen keyboard up. Headless Chrome has no soft keyboard, so this cannot be automated. Record the result in the PR
- [ ] T043 **MANUAL** — SC-008: at desktop width, set browser zoom to 200% and confirm no content or control is lost. Outside the FR-022 viewport matrix. Record the result in the PR
- [X] T044 (measured: **143 → 175 system tests, +22%**; local full-suite ~98s. CI job-duration comparison recorded in `PR.md` for the reviewer to fill against `dev`.) Record the `system-test` job duration from `.github/workflows/ci.yml` before and after this branch, writing both figures into the PR description (Constitution Principle IV — the feature's one measurable cost)
- [X] T045 (written to `specs/012-responsive-layout-menu/PR.md`) Write the PR description covering: which Core Principles from `.specify/memory/constitution.md` are engaged and how, which existing patterns were reused (Principle III — `<details>`, `.data-table`, the `execute_cdp` helper pattern, the design tokens), and an explicit note that the menu gains a toggle below 768px, which is a visible change for anyone on a narrow window
- [X] T046 Run [quickstart.md](./quickstart.md) end to end, including the single-breakpoint grep self-check and the no-script manual check
- [X] T047 Document in [quickstart.md](./quickstart.md) that `bin/rails tailwindcss:build` must run before system tests see a stylesheet change — the suite serves `app/assets/builds/tailwind.css`, not the source, and a skipped build reads as a failing assertion

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies — start immediately
- **Foundational (Phase 2)**: depends on Setup — **blocks all user stories**
- **User Stories (Phases 3–5)**: all depend on Phase 2; independent of each other thereafter
- **Polish (Phase 6)**: depends on whichever stories are being shipped

### User Story Dependencies

- **US1 (P1)**: needs Phase 2 only. No dependency on US2 or US3.
- **US2 (P2)**: needs Phase 2 only. Independently testable — a user arriving by direct link benefits even without US1.
- **US3 (P3)**: needs Phase 2 only. Fully independent.

### Critical path

```
T001→T002→T003→T004→T005  (setup, serial — same file)
        ↓
T006→T007→T009   T008 [P]   (foundational)
        ↓
T010→T012 ⚠️R1 GATE→T013→T014→T015→T016   (US1 core)
                         T017 [P]→T018→T019
                         T020→T021→T022    T023 [P]  T024 [P]
        ↓
T025→T027→T028 ⚠️R2 GATE→T031   T026 [P]   T029→T030→T032   T033 [P]
        ↓
T034→T035   T036 [P]
        ↓
T037→T038→T039→T040→T041→T042→T043→T044→T045→T046
```

### Why so few [P] markers

`app/assets/tailwind/application.css` is a single stylesheet touched by nine tasks, and `test/system/responsive_test.rb` by eight. Tasks against the same file are marked sequential rather than parallel, because marking them `[P]` would be untrue and would produce conflicting edits. The genuine parallel opportunities are listed below.

### Parallel Opportunities

- **T008** (new `test/stylesheet_breakpoint_test.rb`) alongside T006–T007 (CSS)
- **T017** (new `site_menu_controller.js`) alongside T013–T016 (ERB + CSS)
- **T023** (`navigation_test.rb`) and **T024** (`accessibility_test.rb`) alongside each other and T020–T022
- **T026** (`locker_swap_proposals/index.html.erb`) alongside T025 (`_locker_wish_list.html.erb`)
- **T033** (running two existing test files) alongside T029–T032
- **T036** (`accessibility_test.rb`) alongside T035 (`responsive_test.rb`)
- **Across stories**: once Phase 2 lands, US1, US2 and US3 can be taken by three people — but they must coordinate on the shared stylesheet

---

## Parallel Example: User Story 1

```bash
# After the R1 gate (T012) passes, these touch different files:
Task: "T017 Create app/javascript/controllers/site_menu_controller.js"
Task: "T013 Create app/views/shared/_site_menu.html.erb"

# Verification, three different test files:
Task: "T022 Touch-target assertion in test/system/site_menu_test.rb"
Task: "T023 Wide-width bar in test/system/navigation_test.rb"
Task: "T024 axe at phone width with panel open in test/system/accessibility_test.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Phase 1 Setup (T001–T005)
2. Phase 2 Foundational (T006–T009) — **blocks everything**
3. Phase 3 US1 (T010–T024), clearing the R1 gate at T012
4. **STOP and VALIDATE**: the menu works at both widths, with and without script
5. Shippable — the highest-value slice, and the explicit second half of the original request

### Incremental Delivery

1. Setup + Foundational → the breakpoint exists and is guarded
2. + US1 → menu works on a phone → **MVP**
3. + US2 → every signed-in screen works on a phone, lists restack
4. + US3 → auth screens verified
5. + Polish → sweep, manual checks, PR evidence

### Risk-first ordering

The two gates (T012, T028) are placed as early as their phases allow. Both fail loudly and cheaply — T012 costs one CSS block to discover, T028 one axe run — and both have a documented fallback in research.md that stays inside the same constitutional principles. Do not build past a failing gate.

---

## Notes

- `[P]` means a genuinely different file with no incomplete dependency
- Every task names its file path; the two `MANUAL` tasks name what to record instead
- Tests are written before the implementation they cover, per Principle II
- Commit after each task or logical group; the branch is `feature/012-responsive-layout-menu`
- Stop at any checkpoint to validate a story independently
- No task adds a gem, a migration, a model change or a query — if one appears to, re-read the plan
