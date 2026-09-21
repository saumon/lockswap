---

description: "Task list for 026 — open the locker search on arrival from the homepage"
---

# Tasks: Open the locker search on arrival from the homepage

**Input**: Design documents from `/specs/026-locker-wish-expand-from-home/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/locker-wish-entry.md](./contracts/locker-wish-entry.md), [quickstart.md](./quickstart.md)

**Tests**: Included, and not optional here. The constitution's Principle II is
NON-NEGOTIABLE: "Every new feature and every bug fix MUST include automated tests
that fail without the change and pass with it." Every test task below names the
requirement it carries and, where it should fail before implementation, says so.

**Organization**: By user story, in priority order. Read the note under *Story
shapes* before planning parallel work — two of the three stories are guards, not
increments, and cannot be delivered on their own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel — different file, no dependency on an incomplete task
- **[Story]**: `[US1]`, `[US2]`, `[US3]` from spec.md
- Exact file paths are given in every task

## Path conventions

Rails MVC monolith at the repository root: `app/controllers/`, `app/views/`,
`config/`, `test/controllers/`, `test/system/`. No `src/`, no `backend/`.

## Story shapes — read before parallelising

| Story | Shape | Can it ship alone? |
|---|---|---|
| **US1** (P1) — arriving from an invitation opens and focuses | A real increment. Everything this feature adds is here. | Yes. This is the MVP. |
| **US2** (P1) — arriving from the menu stays folded | A **guard**. Its behaviour is today's behaviour; the phase adds the evidence that US1 did not leak the open state onto every arrival. | No — there is nothing to build. Its tests are meaningful only after US1. |
| **US3** (P2) — the person who already declared a search | A **guard**. FR-008 holds structurally: the disclosure US1 opens does not render for a viewer with a wish. | No — no implementation task exists. |

So the honest dependency is **Foundational → US1 → (US2, US3 in parallel)**, and
US2/US3 are verification phases. The template's "different developers take
different stories" strategy does not apply to a feature this size; the parallel
opportunities that are real are listed at the bottom.

---

## Phase 1: Setup

**Purpose**: Know what green looks like before changing anything, so a failure
later is attributable.

- [X] T001 Record the baseline by running `bin/rails test test/controllers/locker_wishes_controller_test.rb test/i18n_completeness_test.rb test/stylesheet_breakpoint_test.rb` and `bin/rails test:system test/system/locker_wish_test.rb test/system/homepage_locker_wish_test.rb`, and note any test that is already failing or flaky on this clean tree — `test/system/homepage_locker_wish_test.rb` documents a historical click-through flake in its header comment, and a pre-existing failure must not be mistaken for one this feature caused

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The route, the intention and the controller read. Nothing on screen
changes in this phase — the views still ignore `@open_wish_form` — which is
deliberate: the phase can land and be verified without touching a single pixel.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Tests first

- [X] T002 [P] In `test/controllers/locker_wishes_controller_test.rb`, add a test that `get new_locker_wish_path` as `users(:erin)` redirects to **exactly** `locker_wishes_path` with no query string (assert the full `response.location` path *and* that its query is empty — FR-003 is about the address, so asserting only `assert_redirected_to` would pass on a redirect that appended parameters), sets `flash[:open_wish_form]`, and leaves `LockerWish.count` unchanged (FR-012). MUST FAIL before T004 — the route does not exist
- [X] T003 [P] In `test/controllers/locker_wishes_controller_test.rb`, add a test that an anonymous `get new_locker_wish_path` redirects to `new_user_session_path` and leaves `LockerWish.count` unchanged, alongside the existing "an anonymous visitor cannot declare a wish". Carry a comment saying why it lives here rather than in `test/system/access_control_test.rb`: that file covers *screens* an anonymous visitor could open, and this endpoint renders nothing — what matters about it is a redirect chain, which is a server-side fact. MUST FAIL before T004

### Implementation

- [X] T004 In `config/routes.rb`, add `:new` to the existing `resource :locker_wish, only: [ :create, :destroy ]`, with a comment recording that the action exists so an intention to declare can be carried without appearing in the address (026 FR-001/FR-003) and that a singular `resource` routes to `LockerWishesController`, so the class's existing `before_action :authenticate_user!` already covers it
- [X] T005 In `app/controllers/locker_wishes_controller.rb`, add `#new`: set `flash[:open_wish_form] = true` and `redirect_to locker_wishes_path` — the bare path, nothing appended. Comment it with the two facts that make it correct: the flash is readable by exactly one subsequent request and swept after it (FR-002), and the redirect is what keeps the address identical to the menu's (FR-003). State explicitly that the key must **not** be added to `add_flash_types` — `app/views/layouts/_flash.html.erb` renders `notice` and `alert` by name rather than iterating the hash (research R2), and registering the key would only invite someone to render it as a message
- [X] T006 In `app/controllers/locker_wishes_controller.rb#index`, add `@open_wish_form = flash[:open_wish_form].present?`, with a comment saying it is deliberately the raw fact — *this arrival asked for the declare form* — with no `persisted?` guard folded in, because where that fact applies is the view's decision and the view already answers it by branch (research R6)

**Checkpoint**: T002 and T003 pass. `bin/rails test test/controllers/locker_wishes_controller_test.rb` is green, and every existing test in the file — especially the three query-count assertions — still passes. Nothing a user can see has changed.

---

## Phase 3: User Story 1 — Arriving from the homepage invitation (Priority: P1) 🎯 MVP

**Goal**: Pressing either homepage invitation lands on the locker wishes screen
with the "I'm looking for a locker" disclosure open and the cursor in the Floor
field, so the person can type immediately.

**Independent Test**: Log in as `users(:erin)`, press "I want a locker! 🙏" on the
homepage, and confirm the disclosure is open and `document.activeElement` is the
floor field. Delivers the whole of the feature's value on its own.

### Tests for User Story 1

- [X] T007 [P] [US1] In `test/controllers/locker_wishes_controller_test.rb`, add a test that follows the redirect from `new_locker_wish_path` as `users(:erin)` and asserts the rendered body carries a `<details open>` wrapping the summary "I'm looking for a locker" and an `input#locker_wish_floor[autofocus]` (FR-004, FR-005). MUST FAIL before T010/T011
- [X] T008 [P] [US1] In `test/controllers/locker_wishes_controller_test.rb`, add a test that a rejected declare (`post locker_wish_path` with a blank floor) still re-renders the disclosure with `open` and **without** `autofocus` — the error is what should draw attention on a re-render, not the field (FR-010, spec US1 scenario 4). The `open` half passes today; the `autofocus` half is the new assertion
- [X] T009 [US1] Create `test/system/locker_wish_entry_test.rb` with a class comment explaining that the rule is proved in the controller test and that this file exists only for what a browser alone can answer — that focus actually landed — and referencing the click-through flake documented in `test/system/homepage_locker_wish_test.rb`'s header
- [X] T010 [US1] ~~add a test that logs in as `users(:erin)`... clicks that link, calls `wait_for_turbo`...~~ **Deviation, recorded at implementation time**: plain `click_on` reproduced the click-then-assert flake `homepage_locker_wish_test.rb`'s header documents — confirmed directly by running this file repeatedly in isolation, not assumed. Fixed with a `click_reliably` helper local to the test file (same shape as `fill_in_reliably`, for the same class of documented ChromeDriver defect), and the erin test was merged with T012 and T024 into one richer test rather than kept separate — see the class comment in `test/system/locker_wish_entry_test.rb` for the full reasoning. FR-004/FR-005 still hold exactly as specified; only the test's shape changed
- [X] T011 [US1] the same for `users(:dave)`, unchanged — kept as its own test since it only needs to prove the second link reaches the same state (FR-004, FR-005)
- [X] T012 [US1] ~~add a test that after arriving as `users(:erin)`... types a floor... and submits~~ **Merged into the erin test (T010) rather than kept standalone** — see the note there

### Implementation for User Story 1

- [X] T013 [US1] In `app/views/locker_wishes/_locker_wish_panel.html.erb`, change the declare branch's `<details>` to `<details <%= "open" if @open_wish_form || @locker_wish.errors.any? %>>` and pass `autofocus: @open_wish_form` to its `render "locker_wishes/locker_wish_form"`. In the same edit, pass `autofocus: false` from the persisted branch's nested "Change floor" `render`, leaving that disclosure's own `errors.any?` condition untouched. Comment that FR-008 needs no controller guard because the disclosure being opened does not render at all for a viewer who has a wish (research R6)
- [X] T014 [US1] In `app/views/locker_wishes/_locker_wish_form.html.erb`, add the strict-locals declaration `<%# locals: (autofocus: false) %>` at the top and change the floor field to `<%= f.text_field :floor, autofocus: autofocus, autocomplete: "off", aria: { describedby: "locker_wish_floor_hint" }, class: "field-input" %>`. Carry a comment at the attribute recording the load-bearing constraint from research R3: turbo-rails 2.0.23 picks the autofocusable element with a filter that excludes anything matching `details:not([open])`, so the `open` attribute and this one must arrive in the **same server response** — opening the disclosure from script after render leaves the field permanently unfocused with no error anywhere. Must land together with T013; strict locals break the other call site otherwise
- [X] T015 [US1] In `app/views/home/_locker_wish.html.erb`, repoint both invitations — `t(".switch_locker")` and `t(".want_a_locker")` — from `locker_wishes_path` to `new_locker_wish_path`, keeping `link_to` (not `button_to`) and the existing `class: "btn btn-primary btn-arrow"`. Leave the third state's "See my locker searches! 🥷" link on `locker_wishes_path` (FR-008). Comment that the new target is still a navigation that changes nothing the user can observe, so 010's reason for a link rather than a button still holds
- [X] T016 [US1] In `test/system/homepage_locker_wish_test.rb`, update the href assertion at line 185 inside "an active swap proposal does not change the block" from `locker_wishes_path` to `new_locker_wish_path`. Change nothing else in that file — in particular "every state offers exactly one control and no form" must still pass untouched, since the invitations stay links

**Checkpoint**: US1 is fully functional. T007, T008, T010, T011 and T012 pass; `bin/rails test:system test/system/homepage_locker_wish_test.rb` passes with the single line changed in T016.

**FR-009 (analysis finding C1 — fold-by-hand, no task originally named it):**
attempted as a browser test (click summary to close an already-open `<details>`)
and dropped. It reproduced the click flake even via a raw Selenium mouse action,
bypassing Capybara's `click_on` entirely — and no other test in this suite has
ever closed an already-open `<details>` by click either (every existing case
only opens one from closed). FR-009 is satisfied by construction instead: the
disclosure this feature opens is the same plain `<details>` with no script and
no CSS added that could intercept its native toggle — unchanged from 003's own
choice of element for exactly that property. Recorded in
`test/system/locker_wish_entry_test.rb` at the point T009 would have added it.

---

## Phase 4: User Story 2 — Arriving from the menu (Priority: P1)

**Goal**: Every arrival that did not come from an invitation — the menu, a typed
address, a bookmark, a reload, a Back navigation — still lands folded, with
nothing focused.

**Independent Test**: Log in as `users(:alice)`, reach the locker wishes screen
from the site menu, and confirm the floor field does not exist yet. This is
already asserted by `test/system/locker_wish_test.rb`'s first test, which is why
this phase adds no implementation.

**Note**: A guard phase. There is nothing to build — the tasks below add the
evidence that Phase 3 did not leak the open state onto every arrival.

### Tests for User Story 2

- [X] T017 [P] [US2] In `test/controllers/locker_wishes_controller_test.rb`, add a test that a plain `get locker_wishes_path` as `users(:erin)` renders the declare disclosure **without** `open` and the floor field **without** `autofocus` (FR-006). This must pass both before and after Phase 3 — it is the assertion that would catch an implementation that opened the zone for everyone
- [X] T018 [P] [US2] In `test/controllers/locker_wishes_controller_test.rb`, add a test that issues `get new_locker_wish_path`, follows the redirect, then issues a second `get locker_wishes_path`, and asserts the second render is folded with nothing focused — the flash was spent by the first (FR-002). This is the reload and Back case reduced to the fact that makes it true
- [X] T019 [US2] **Dropped, deliberately, at implementation time.** A `click_on`-then-reload browser version was written and hit the same click-then-assert flake as T010; since nothing about this fact needs a browser (no focus is asserted, only whether markup is present after a second request — exactly what a controller test already answers deterministically), the coverage lives entirely in T018 instead, which issues the same two requests a reload or Back produces without a browser's timing in the way. Full reasoning is in `test/system/locker_wish_entry_test.rb`'s class comment. FR-002/spec US1 scenario 5 are still covered — by T018, not by a system test
- [X] T020 [US2] Run `bin/rails test:system test/system/locker_wish_test.rb` and confirm it passes **with no edits**. Its first test — "the wish page asks which floor only once the button is clicked" — reaches the screen through the menu and asserts the field does not exist yet; that test failing means this feature leaked the open state onto every arrival. Do not adjust it to accommodate the change

**Checkpoint**: The distinction the feature is actually about is proved from both sides — T007/T010 say the invitation opens it, T017/T018/T019/T020 say nothing else does.

---

## Phase 5: User Story 3 — The person who already declared a search (Priority: P2)

**Goal**: A viewer who has already declared a search sees the screen unchanged by
this feature: their search, the withdraw control, a folded "Change floor" zone,
nothing focused.

**Independent Test**: Log in as `users(:bob)` (has `bob_wish`), reach the locker
wishes screen by any route including `new_locker_wish_path`, and confirm the
"Change floor" disclosure is closed and no field carries `autofocus`.

**Note**: A guard phase, and the strongest of the three: FR-008 holds
structurally, because the disclosure US1 opens is in a branch that does not
render at all for a viewer who has a wish. No implementation task exists.

### Tests for User Story 3

- [X] T021 [P] [US3] In `test/controllers/locker_wishes_controller_test.rb`, add a test that `get new_locker_wish_path` as `users(:bob)` (who has `bob_wish`) and following the redirect renders the persisted panel — `#locker-wish-floor` present — with the nested "Change floor" `<details>` carrying no `open` and no `[autofocus]` anywhere in the body (FR-008, spec US3 scenario 2, the "declared in another tab" race)
- [X] T022 [P] [US3] In `test/system/homepage_locker_wish_test.rb`, extend "a declared wish is shown with the way back to the wish page" with an href assertion that "See my locker searches! 🥷" still points at `locker_wishes_path` and not at `new_locker_wish_path` (FR-008), matching how "an active swap proposal does not change the block" asserts its own control's destination

**Checkpoint**: All three stories are covered. The feature touches exactly one entrance and is proved not to touch the other two.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T023 [P] In `test/system/locker_wish_entry_test.rb`, add a test that repeats the `users(:erin)` arrival inside `with_viewport(:phone)` and asserts the same open disclosure and the same focused field, proving FR-015's "identical at every viewport width" rather than assuming it. Also carries `assert_touch_targets_at_least` (folded in from T024, at the viewport that check is scoped to everywhere else in the suite)
- [X] T024 [P] `assert_axe_clean` on the opened screen (Principle III's accessibility gate, SC-004) — merged into T010's erin test rather than kept as its own click-through, for the same reason T012 was; `assert_touch_targets_at_least` moved to T023 (phone width, matching the suite's own convention: at desktop width the site nav's small links are mouse targets, not touch ones, and running it there without `with_viewport(:phone)` produced a false failure unrelated to this feature)
- [X] T025 Screenshots taken via the real arrival mechanism (a click on the homepage link, not `visit new_locker_wish_path` directly — the first attempt used a direct visit and produced a misleading image; see below) at desktop and phone, read against the five points. Four of five clean: the list is not pushed off the fold at either width, nothing sits behind the frosted bar, no new animation was added, and the field sits above the fold at phone width. **The focus-ring point turned up a real, verified finding, not assumed from the screenshot alone**: `document.activeElement.matches(':focus-visible')` is `true` for the click-driven arrival on desktop and `false` for the identical arrival at phone width — confirmed with `getComputedStyle` (desktop: `outline: solid`, blue border; phone: `outline: none`, muted border) and reproduced across repeated runs. This is a Chromium `:focus-visible` heuristic treating a touch-context click differently from a mouse-context one, not something this feature's HTML/CSS controls — `application.css`'s own FR-024 comment states the `:focus-visible`-only design is deliberate ("so a mouse click does not leave a ring behind"), and the site's one pre-existing `autofocus` use (devise/registrations/edit.html.erb) would show the identical gap on a phone, unrelated to 026. DOM focus itself (`activeElement.id`, the `autofocus` attribute, label/hint association) is identical and correct at both widths — this is a visual-indicator gap only, on mobile only, inherited from the site's existing autofocus pattern rather than introduced here. Left unfixed as out of this feature's scope; reported to the user rather than silently accepted or silently "fixed" with a change to the project's stated focus-ring philosophy
- [X] T026 [P] Run `bin/rails test test/i18n_completeness_test.rb` and `bin/rails test test/stylesheet_breakpoint_test.rb` and confirm both are unchanged: this feature adds no locale key (FR-013) and no media query, and `bin/rails tailwindcss:build` should not be needed because `app/assets/tailwind/application.css` should not have been touched
- [X] T027 [P] Run `bin/rubocop` over the changed files and resolve every warning without a suppression; if one is genuinely unavoidable, it carries an inline comment saying why it is safe (Principle I)
- [X] T028 Confirm the Principle IV evidence: the three query-count assertions in `test/controllers/locker_wishes_controller_test.rb` — "filtering issues no more queries than not filtering", "deriving current_floor from an active wish costs no extra queries", "rendering the list issues the same number of queries whether or not a match is present" — still pass with no change to their expected counts. State this in the PR description as the before/after measurement
- [X] T029 Run the full suite: `bin/rails test && bin/rails test:system`. Every failure is either this feature's or was recorded in T001; nothing else is acceptable
- [X] T030 Write the PR description against the constitution's Development Workflow: which Core Principles are implicated and how the change satisfies each, the accessibility/consistency note (no new pattern — the existing `<details>`, form and copy reused), the i18n note (no new string), the performance note from T028, and the one breaking change for maintainers (the two homepage links now point at `new_locker_wish_path`, which is why `homepage_locker_wish_test.rb:185` moved)

---

## Dependencies & Execution Order

### Phase dependencies

- **Phase 1 (Setup)**: no dependencies
- **Phase 2 (Foundational)**: after T001 — **blocks everything**
- **Phase 3 (US1)**: after Phase 2. This is where every visible change lives
- **Phase 4 (US2)** and **Phase 5 (US3)**: after Phase 3. Both are verification; they can run in parallel with each other
- **Phase 6 (Polish)**: after Phases 3–5

### Within Phase 2

T002 and T003 are written first and must fail. T004 → T005 → T006 in that order: the route must exist before the action is reachable, and `#index` reads what `#new` writes.

### Within Phase 3

- T007, T008 are written first and must fail
- T009 creates the file T010, T011, T012 write into, so it precedes all three
- **T013 and T014 must land in the same commit.** T014 introduces strict locals on a partial with two call sites; T013 is what updates the second one. Split them and the tree is broken between the two
- T015 then T016 — repointing the links is what makes the existing href assertion wrong, so the test edit follows the code edit rather than preceding it

### Critical path

T001 → T002 → T004 → T005 → T006 → T013+T014 → T015 → T016 → T029

Everything else hangs off it.

### Parallel opportunities

Real ones, given the size of this feature:

- **T002 ‖ T003** — two independent tests in the same file; write them together, land them together
- **T007 ‖ T008** — same
- **T010 ‖ T011 ‖ T012** — three independent tests in the new system-test file, once T009 has created it
- **T017 ‖ T018** ‖ **T021 ‖ T022** — Phase 4's and Phase 5's controller tests are independent of each other and of the browser tests
- **T023 ‖ T024** — both in the new system-test file, independent assertions
- **T026 ‖ T027** — two independent gates

Not parallel, however they look: **T013 and T014** (one change across two files), and **T015 before T016** (the test edit depends on the code edit).

---

## Implementation Strategy

### MVP

Phases 1–3. That is the entire user-visible feature: the two invitations open the
form and focus the field. Stop there, run `bin/rails test:system test/system/locker_wish_entry_test.rb test/system/locker_wish_test.rb`, and look at the screen before going further.

### Then

Phase 4 and Phase 5 in either order — they are the proof that the other two
entrances are untouched, and they are what a reviewer will look for first,
because "opens the form" is easy and "opens it only here" is the requirement.
Phase 6 last.

### What to watch

The one live hazard is the system-test flake documented in
`test/system/homepage_locker_wish_test.rb`'s header: three tests were deleted for
doing exactly what T010 and T011 do — click the block's control and assert what
came next. The mitigations are already baked into the task descriptions (fixtures
whose homepage fits the viewport, `wait_for_turbo` after the click, assert on
content rather than on the address, and only three click-throughs in total). If
T010 or T011 proves flaky in practice, the answer is to move more of the burden
onto the controller tests, not to add retries — Principle II forbids retries as a
permanent workaround.

---

## Notes

- `[P]` means a different file, or an independent test in the same file that can be written alongside its sibling
- Commit after each task or logical group; T013+T014 are one group by necessity
- Every new rule gets its reasoning at the site of the rule, per CLAUDE.md — the comments named in T004, T005, T006, T013, T014 and T015 are part of those tasks, not optional polish
- No migration, no schema change, no new locale key, no JavaScript, no stylesheet change. If a task seems to need one of those, re-read [contracts/locker-wish-entry.md](./contracts/locker-wish-entry.md) §4 before writing it
