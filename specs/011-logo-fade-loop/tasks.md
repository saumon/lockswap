---

description: "Task list for Looping Logo Fade Animation"
---

# Tasks: Looping Logo Fade Animation

**Input**: Design documents from `/specs/011-logo-fade-loop/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/brand-motion-loop.md](./contracts/brand-motion-loop.md), [quickstart.md](./quickstart.md)

**Tests**: Included as mandatory tasks, not optional — the project constitution's Testing Standards principle is NON-NEGOTIABLE, and this feature specifically reverses two existing, explicitly-tested behaviors ("the flourish must play once, never loop" and "the header mark does not fade" in `test/system/motion_test.rb`), which per Principle II must be rewritten with passing evidence of the *new* behavior, not silently deleted.

**Organization**: Tasks are grouped by user story (from spec.md: US1 = looping fade on the sign-in/sign-up screens, P1; US2 = the same loop on the signed-in header's reduced mark, P2) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: US1 or US2 — maps to the user stories in spec.md
- Exact file paths are included in every task description

## Path Conventions

Single Rails project (no frontend/backend split) — paths are under `app/` and `test/` at the repository root, per plan.md's Project Structure.

---

## Phase 1: Setup

**Purpose**: Project initialization.

**None required.** This feature adds no new dependency, no new directory, and no new tooling — `tailwindcss-rails`, Minitest, Capybara, and axe-core are already in place from features 007–010. Proceed directly to Phase 2.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The shared motion token, the shared keyframes, and a pre-existing test-helper bug this feature would otherwise trigger for every system test. Both user stories depend on all three.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

> T001 and T002 both edit `app/assets/tailwind/application.css` and must be applied in that order (sequentially), not in parallel.

- [X] T001 In `app/assets/tailwind/application.css`, add `--motion-brand-loop: 3000ms;` to the `:root` motion-token block, immediately after the existing `--motion-brand: 1100ms;` / `--motion-flourish: 900ms;` lines (data-model.md "Motion token" entity)
- [X] T002 In `app/assets/tailwind/application.css`, add `@keyframes brand-fade-pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.6; } }` immediately after the existing `@keyframes brand-fade-in { ... }` block. Do not add any property other than `opacity` to this keyframe (contracts/brand-motion-loop.md CSS contract)
- [X] T003 [P] In `test/application_system_test_case.rb`, stop the private `wait_for_entrance` helper from waiting on animations that never finish: filter `document.getAnimations()` down to those whose `effect.getTiming().iterations !== Infinity` before checking `every(a => a.playState !== "running")`. (Originally specified as scoping the query to `el.getAnimations()`; that was wrong — the entrance is staggered across *descendants* of `.page-enter`, including the sign-in tagline that the colour-contrast audit reads, so scoping to the wrapper would return mid-fade and risk false axe failures. Excluding infinite animations keeps the original document-wide intent.) Without this fix, once either user story below adds an infinite-duration animation to a page, this helper — used by every `assert_axe_clean` call — will always fall through to its 5-second timeout instead of returning as soon as the entrance settles (research.md D7)

**Checkpoint**: The loop's building blocks (token, keyframes) exist but nothing references them yet, and the shared test harness is safe to run against a page containing an infinite animation. User story implementation can now begin.

---

## Phase 3: User Story 1 - Eye-catching logo on the sign-in/sign-up screen (Priority: P1) 🎯 MVP

**Goal**: The sign-in and sign-up screens' large logo keeps gently pulsing in opacity, forever, once its existing one-shot entrance animation finishes — rather than sitting static.

**Independent Test**: Open `/users/sign_in` (or `/users/sign_up`), wait for the entrance to settle, and confirm the logo continues to visibly pulse between full and ~60% opacity on a ~3-second cycle, indefinitely.

### Tests for User Story 1

> **Write these first and confirm they fail against the current codebase before touching implementation files.** T004–T008 all edit `test/system/motion_test.rb` and must be applied in that order (sequentially), not in parallel.

- [X] T004 [US1] In `test/system/motion_test.rb`, rewrite the test `"the flourish must play once, never loop"` (drop "never loop" from its name and comment, since that is exactly what this feature reverses): keep the existing assertion that the *entrance* component still runs once — `getComputedStyle(document.querySelector('.brand-mark-flourish')).animationName` must include `"brand-fade-in"` as one comma-separated component with a matching `"1"` in the parallel position of `animationIterationCount` — and add a new assertion that a second component, `"brand-fade-pulse"`, is present with `"infinite"` in the matching position of `animationIterationCount` (contracts/brand-motion-loop.md test contract row for FR-001/FR-002)
- [X] T005 [US1] In `test/system/motion_test.rb`, fix the wait loop inside the test `"the logo fades in on the sign-in screen and settles"` so it waits for the *entrance* animation specifically instead of every animation on the page: replace `document.getAnimations().every(a => a.playState !== 'running')` with a filter on animation name, e.g. `document.getAnimations().filter(a => a.animationName === 'brand-fade-in').every(a => a.playState !== 'running')`. Without this the test will hang against the new infinite pulse and always hit its own `Timeout.timeout(5)` (research.md D8). Leave the rest of the test (final opacity, resolved blur) unchanged
- [X] T006 [US1] In `test/system/motion_test.rb`, add a new test `"the sign-in logo keeps pulsing after the entrance settles"`: visit `new_user_session_path`, wait for the entrance animation to finish (reuse the fixed wait pattern from T005), then assert `.brand-mark-flourish`'s `animationName` includes `"brand-fade-pulse"` with `"infinite"` in the matching `animationIterationCount` position, and that the pulse's `animationDelay` component equals `"1.1s"` (i.e. `var(--motion-brand)` — proving the loop is chained to start only once the entrance ends, per FR-006). Additionally, set `getAnimations()[<pulse-index>].currentTime` to half the loop's duration (1500ms) and assert `getComputedStyle(...).opacity` reads `"0.6"` (FR-004). Also capture `document.querySelector('.brand-mark-flourish').getBoundingClientRect()` once before the pulse's low point and once at it, and assert `x`, `y`, `width`, and `height` are all unchanged — proving the pulse never touches layout (FR-008)
- [X] T007 [US1] In `test/system/motion_test.rb`, add a new test `"the sign-up logo keeps pulsing after the entrance settles"`, identical in structure to T006 but visiting `new_user_registration_path` (FR-002), including the same `getBoundingClientRect()` before/at-pulse-low-point comparison against the sign-up screen's mark (FR-008)
- [X] T008 [US1] In `test/system/motion_test.rb`, extend the existing test `"reduced motion shows the logo immediately, with no animation declared"` with an additional assertion that, under `emulate_reduced_motion`, `.brand-mark-flourish`'s `animationName` does **not** include `"brand-fade-pulse"` either — it must still read exactly `"none"` (FR-007)

### Implementation for User Story 1

- [X] T009 [US1] In `app/assets/tailwind/application.css`, inside the existing `@media (prefers-reduced-motion: no-preference)` block, add the compound rule immediately after `.brand-mark-flourish { animation: brand-fade-in var(--motion-brand) var(--ease-brand) 1 both; }`:
  ```css
  .brand-mark-flourish.brand-mark-loop {
    animation:
      brand-fade-in var(--motion-brand) var(--ease-brand) 1 both,
      brand-fade-pulse var(--motion-brand-loop) ease-in-out infinite;
    animation-delay: 0s, var(--motion-brand);
  }
  ```
  This must come from a **compound** selector (both classes required) so its higher specificity wins over the plain `.brand-mark-loop` rule added in T015 — the `animation` shorthand does not merge across separate matching rules (research.md D4). Depends on T001, T002
- [X] T010 [P] [US1] In `app/views/shared/_brand_stacked.html.erb`, add `brand-mark-loop` to the `<img>` tag's existing `class="brand-mark brand-mark-flourish"` attribute (→ `class="brand-mark brand-mark-flourish brand-mark-loop"`), and update the file's top doc-comment line `FR-022: the logo fades up out of a blur once, and never loops.` to note that the mark now continues pulsing in opacity after that one-shot entrance (FR-001/FR-002/FR-006 of feature 011)

**Checkpoint**: User Story 1 is fully functional and independently testable — sign-in and sign-up logos pulse forever after their entrance; the header is untouched and still carries no animation.

---

## Phase 4: User Story 2 - Consistent brand animation in the signed-in header (Priority: P2)

**Goal**: The small logo mark in the site's top header pulses the same way, continuously, on every signed-in page.

**Independent Test**: Sign in, confirm the header logo is pulsing immediately (no entrance precedes it there), and confirm it is still pulsing after navigating to another page.

### Tests for User Story 2

> T011–T013 all edit `test/system/motion_test.rb` and must be applied in that order (sequentially), not in parallel, and after T004–T008 (Phase 3) since both phases edit the same file.

- [X] T011 [US2] In `test/system/motion_test.rb`, rewrite the test `"the header mark does not fade"` (rename it, since the header now deliberately does — e.g. `"the header mark pulses"`) to assert `getComputedStyle(document.querySelector('header [data-brand-mark]')).animationName` includes `"brand-fade-pulse"`, with `"infinite"` in the matching `animationIterationCount` position and `"0s"` in the matching `animationDelay` position (no entrance precedes the header mark, per FR-003/contracts/brand-motion-loop.md)
- [X] T012 [US2] In `test/system/motion_test.rb`, add a new test `"the header mark keeps pulsing across page navigation"`: log in, visit the homepage, assert the header mark's `animationName` includes `"brand-fade-pulse"`, then `click_on "Locker wishes"` and re-assert the same on the new page (FR-003). Also capture the header mark's `getBoundingClientRect()` before and during a pulse dip and assert it is unchanged (FR-008)
- [X] T013 [US2] In `test/system/motion_test.rb`, add an assertion (either extending the existing reduced-motion test or as a new one) that under `emulate_reduced_motion`, `header [data-brand-mark]`'s `animationName` is `"none"` (FR-007)

### Implementation for User Story 2

- [X] T014 [P] [US2] In `app/views/shared/_brand_mark.html.erb`, add a new `pulse` local, sibling to the existing `flourish` local: default it to `false` (`pulse = false if !defined?(pulse) || pulse.nil?`), append `" brand-mark-loop"` to the SVG's `class` attribute when true (independent of `flourish`), and add a `pulse` line to the file's top `Locals:` doc-comment block, matching the existing `flourish` line's style (contracts/brand-motion-loop.md view-partial contract)
- [X] T015 [US2] In `app/assets/tailwind/application.css`, inside the same `@media (prefers-reduced-motion: no-preference)` block, add the plain rule **before** the compound rule from T009 (so the compound rule's higher specificity still wins where both classes are present):
  ```css
  .brand-mark-loop {
    animation: brand-fade-pulse var(--motion-brand-loop) ease-in-out infinite;
  }
  ```
  Depends on T001, T002; sequential with T009 (same file)
- [X] T016 [P] [US2] In `app/views/shared/_brand_lockup.html.erb`, change `<%= render "shared/brand_mark", size: 32 %>` to `<%= render "shared/brand_mark", size: 32, pulse: true %>` (never `flourish: true` — the header must still never carry the one-shot entrance), and add a short comment noting the header mark now continuously pulses per feature 011. Depends on T014 (the partial must support the `pulse` local for this to have any visible effect)

**Checkpoint**: Both user stories are independently functional — the sign-in/sign-up entrance-then-loop behavior from Phase 3 and the header's always-on loop from this phase.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Full-suite verification and manual sign-off, per quickstart.md.

- [X] T017 [P] Run `bin/rails test test/system/motion_test.rb` and confirm every rewritten and new assertion passes
- [X] T018 [P] Run `bin/rails test test/system/` (the full system suite) and time at least one `assert_axe_clean`-covered test before/after comparison to confirm the T003 fix keeps those calls resolving promptly rather than always hitting a 5-second timeout now that an infinite animation exists on signed-in pages (research.md D7, quickstart.md)
- [X] T019 [P] Run `bin/rubocop` and `bin/rails tailwindcss:build` to confirm no lint or CSS build regressions (Constitution Quality Gates)
- [X] T020 Manually walk through quickstart.md's "Manual validation" steps in a real browser: sign-in loop, sign-up loop, header loop across navigation, and reduced-motion suppression on both surfaces

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: None required.
- **Foundational (Phase 2)**: No dependencies — start immediately. Blocks both user stories.
- **User Story 1 (Phase 3)**: Depends on Phase 2 (T001–T003). No dependency on US2.
- **User Story 2 (Phase 4)**: Depends on Phase 2 (T001–T003). Its test tasks (T011–T013) are sequenced after US1's test tasks (T004–T008) only because both edit `test/system/motion_test.rb`, not because US2 depends on US1's behavior — the two stories are otherwise independent.
- **Polish (Phase 5)**: Depends on both user stories being complete.

### Within Each User Story

- US1: T004 → T005 → T006 → T007 → T008 (all edit `motion_test.rb`, sequentially) must exist and fail before T009/T010. T009 (CSS) depends on T001/T002. T010 (view) has no dependency on T009 — either can land first.
- US2: T011 → T012 → T013 (all edit `motion_test.rb`, sequentially, after Phase 3's edits to the same file) must exist and fail before T014–T016. T015 (CSS) depends on T001/T002 and is sequential with T009 (same file). T016 (view) depends on T014 (the partial must support `pulse` first).

### Parallel Opportunities

- T003 (Foundational, `test/application_system_test_case.rb`) can run alongside T001–T002 (different file).
- T010 (US1, `_brand_stacked.html.erb`) can run alongside T009 (US1, `application.css`) — different files.
- T014 and T016 (US2, two different partials) can run alongside T015 (US2, `application.css`) and alongside each other's *editing*, though T016's effect depends on T014 being done first.
- Once Phase 2 is complete, US1 (Phase 3) and US2 (Phase 4) implementation tasks could be worked by different people in parallel, coordinating only on the shared edits to `application.css` (T009 vs. T015) and to `motion_test.rb` (T004–T008 vs. T011–T013), which must not be applied concurrently by two people without merging.
- All of Phase 5 (T017–T020) are independent verification activities and can run in parallel with each other.

---

## Parallel Example: User Story 1

```bash
# After Phase 2 (T001–T003) is done, and T004–T008 are written and failing:
Task: "Add the compound .brand-mark-flourish.brand-mark-loop rule to app/assets/tailwind/application.css (T009)"
Task: "Add brand-mark-loop to the class attribute in app/views/shared/_brand_stacked.html.erb (T010)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Foundational (T001–T003)
2. Complete Phase 3: User Story 1 (T004–T010)
3. **STOP and VALIDATE**: open `/users/sign_in`, confirm the logo pulses forever after its entrance, confirm reduced motion still shows it fully static
4. This alone already delivers the core of the request — the eye-catching sign-in/sign-up logo — and is a safe, demoable increment even before the header changes

### Incremental Delivery

1. Foundational (T001–T003) → nothing user-visible yet
2. Add User Story 1 (T004–T010) → sign-in/sign-up loop works → **this is the MVP**
3. Add User Story 2 (T011–T016) → the header's reduced logo also loops, on every signed-in page
4. Polish (T017–T020) → full regression run, CI-timing sanity check, lint/build gates, manual walkthrough

### Parallel Team Strategy

With two developers: once Phase 2 is done, Developer A takes US1 (T004–T010) and Developer B takes US2 (T011–T016) — they touch different partials and different (though adjacent) regions of `application.css` and `motion_test.rb`, coordinating only on merging those two shared files.

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks.
- [Story] label maps task to specific user story for traceability.
- This is a breaking change to previously documented and tested motion behavior (feature 008's "never loop" / "header never fades" guarantees) — per Constitution Principle III, the pull request description must call this out explicitly rather than treating it as an incidental tweak.
- No model, controller, route, or migration is touched anywhere in this feature — it is confined to one stylesheet, two view partials, and one test file plus one shared test helper.
- FR-009 / SC-004's clickability requirement is covered by the pre-existing, unmodified `test/system/navigation_test.rb` (`click_on "LockSwap"`), exercised as part of T018's full-suite run — no new task is needed for it.
- Commit after each task or logical group.
- Stop at either checkpoint (end of Phase 3 or Phase 4) to validate a story independently.
