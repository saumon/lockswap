---

description: "Task list for Visual Identity & Modern White-Theme Refresh"
---

# Tasks: Visual Identity & Modern White-Theme Refresh

**Input**: Design documents from `/specs/008-visual-identity-refresh/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/)

**Tests**: Test tasks ARE included. The spec's clarification session settled test evidence explicitly — automated accessibility assertions on every screen plus the existing suite staying green (FR-028, FR-029, FR-030) — and the constitution makes tests non-negotiable.

**Organization**: Grouped by user story so each ships independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1, US2, US3 — maps to the user stories in spec.md

## Path Conventions

Rails monolith. Paths are repository-relative from `/Users/robu/work/projects/lockswap`.

> **Read [contracts/preserved-dom.md](./contracts/preserved-dom.md) before touching any template.** It lists every DOM id, role, element, label, and control name the existing test suite depends on. Restyling classes is free; breaking that surface is not.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Get the font and the test gem in place before any styling begins.

- [X] T001 Add `gem "axe-core-api"` to the `:test` group in `Gemfile` (do NOT add `axe-core-capybara` — its `set_driver` reassigns `Capybara.default_driver` and would discard the `driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]` config in `test/application_system_test_case.rb`), then run `bundle install`
- [X] T002 [P] Download the Nunito latin variable subset (39,152 bytes, weights 200–1000) to `app/assets/fonts/nunito-latin-variable.woff2` and add the SIL OFL 1.1 licence text at `app/assets/fonts/OFL.txt` (required by the licence when redistributing)
- [X] T003 (not needed, and reverted: Propshaft globs every subdirectory of `app/assets`, so creating the directory is enough. The original finding came from printing the load path before the directory existed — see research.md D4) Append `Rails.application.config.assets.paths << Rails.root.join("app/assets/fonts")` to `config/initializers/assets.rb` — verified that Propshaft does NOT pick this directory up automatically; its paths are only `app/assets/builds`, `app/assets/images`, `app/assets/stylesheets`, `app/javascript`, `vendor/javascript`
- [X] T004 Create the directory `app/views/shared/` for the brand partials

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The token system and the test harness. Every user story depends on these.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

> T005–T009 all edit the same file (`app/assets/tailwind/application.css`) and therefore run **sequentially**, not in parallel. All new CSS goes in this Tailwind entrypoint and never in `app/assets/stylesheets/application.css` — `stylesheet_link_tag :app` emits a separate `<link>` for every CSS file under `app/assets/**`, so splitting would make the cascade depend on link order.

- [X] T005 Define colour tokens in a `@theme` block in `app/assets/tailwind/application.css`, copying values verbatim from [data-model.md](./data-model.md): brand `--color-brand-navy: #0E2A47`, `--color-brand-green: #0AB486`, `--color-brand-blue: #0A77F1`, `--color-locker-blue: #2588F3`, `--color-locker-blue-deep: #014DA7`, `--color-locker-green: #41D5A5`, `--color-locker-green-deep: #05776E`; functional `--color-ink: #0E2A47`, `--color-ink-muted: #50607A`, `--color-accent: #07795A`, `--color-accent-strong: #06684D`, `--color-link: #0A5AC2`, `--color-canvas: #F7F9FB`, `--color-surface: #FFFFFF`, `--color-border: #D8E0E9`, `--color-border-strong: #C7D2DE`; status pairs `#07795A`/`#E6F7F1`, `#9F1239`/`#FFE4E6`, `#0A5AC2`/`#E3EDFD`, `#0E2A47`/`#EEF2F6`. Add a comment on `--color-brand-green` recording that its 2.66:1 contrast makes it legal in the logotype only
- [X] T006 Add the `@font-face` rule and typography tokens to `app/assets/tailwind/application.css`: `src: url("nunito-latin-variable.woff2") format("woff2")` as a **bare filename** (Propshaft resolves it against the load path and rewrites it to the digested URL), `font-weight: 200 1000`, `font-display: swap` (FR-026); `--font-brand: "Nunito", ui-rounded, "Segoe UI", system-ui, sans-serif`; and the type scale `--text-display` 2.5rem/1.1/800, `--text-h1` 1.875rem/1.2/800, `--text-h2` 1.25rem/1.3/700, `--text-h3` 1rem/1.4/700, `--text-body` 1rem/1.6/400, `--text-sm` 0.875rem/1.5/400, `--text-label` 0.875rem/1.4/600
- [X] T007 Add spacing, radius, and shadow tokens to `app/assets/tailwind/application.css`: `--space-1`…`--space-8` (0.25/0.5/0.75/1/1.5/2/3/4rem), `--radius-sm: 0.5rem`, `--radius-md: 0.875rem`, `--radius-lg: 1.25rem`, `--radius-full: 9999px`, and navy-tinted shadows `--shadow-sm: 0 1px 2px rgb(14 42 71 / 0.05)`, `--shadow-md: 0 4px 12px rgb(14 42 71 / 0.08)`, `--shadow-lg: 0 12px 32px rgb(14 42 71 / 0.12)`
- [X] T008 Add motion tokens and the global reduced-motion block to `app/assets/tailwind/application.css`: `--motion-fast: 120ms`, `--motion-base: 180ms`, `--motion-entrance: 320ms`, `--motion-flourish: 900ms`, `--ease-out: cubic-bezier(0.16, 1, 0.3, 1)`, `--ease-in-out: cubic-bezier(0.4, 0, 0.2, 1)`; then a `@media (prefers-reduced-motion: reduce)` rule setting `animation-duration`, `animation-iteration-count`, `transition-duration`, and `scroll-behavior` on `*, *::before, *::after` to near-zero values with `!important`. Use `0.01ms` rather than `none` so `animationend`/`transitionend` listeners still fire (FR-020)
- [X] T009 Add base shell styles to `app/assets/tailwind/application.css`: `body` on `--color-canvas` with `--font-brand`, `--color-ink`, antialiasing; and one shared `:focus-visible` treatment — 2px `--color-link` ring at 2px offset — applied to every focusable control, never signalled by colour alone (FR-024)
- [X] T010 [P] Add an `assert_axe_clean` helper to `test/application_system_test_case.rb` wrapping the plain axe API (there is no official Minitest matcher; `be_axe_clean` is RSpec-only): build `Axe::API::Run.new.according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)`, run it via `Axe::Core.new(page).call(run)`, and `assert audit.passed?, audit.failure_message`. Accept optional `within:`/`excluding:`/`skipping:` arguments so later tasks can scope an audit or exclude a rule
- [X] T011 [P] Create `test/system/accessibility_test.rb` with the test class, `require "axe-core-api"`, and a private helper that signs a fixture user in and navigates to a given path

**Checkpoint**: Tokens exist and the audit harness runs. User story work can begin.

---

## Phase 3: User Story 1 - The brand is present and recognisable on every screen (Priority: P1) 🎯 MVP

**Goal**: LockSwap looks like a product rather than an unbranded scaffold — mark, wordmark, tagline, and real icons on every screen.

**Independent Test**: Load any page at desktop and phone width. The mark and wordmark render sharply (including at 200% zoom), use brand navy and brand green, link back to the home page, and are announced correctly to a screen reader. The browser tab shows the brand mark.

### Tests for User Story 1 ⚠️

> Write first; confirm they fail before implementing.

- [X] T012 [US1] Add brand assertions to `test/system/accessibility_test.rb`: audit the header lockup scoped with `within` on each of the sign-in, sign-up, and home screens, and assert the brand link exposes an accessible name (FR-007). Scope the audits rather than auditing whole pages — the rest of the page is still on the old styling until US2 and would fail on contrast

### Implementation for User Story 1

- [X] T013 [P] [US1] (superseded: the hand-authored mark was not faithful enough to the artwork and was replaced by a potrace vectorisation of the artwork itself — eight colour-separated layers, gradients preserved, 649x547 viewBox) Author the mark as inline SVG in `app/views/shared/_brand_mark.html.erb` per [contracts/brand-assets.md](./contracts/brand-assets.md): 64×64 viewBox, two lockers in 3/4 perspective (blue `#2588F3` face / `#014DA7` side, green `#41D5A5` face / `#05776E` side), three vent bars and a handle per locker in the matching deep tone, a blue `#0A77F1` arrow arcing over left-to-right and a green `#0AB486` arrow arcing under right-to-left. No `<text>` — it must read at 16px. Accept a `size:` local and an `aria_hidden:` local defaulting to true
- [X] T014 [US1] Create `app/views/shared/_brand_lockup.html.erb` — a single `<a>` to `root_path` containing the mark at 32px plus the wordmark as **live HTML text**: `Lock` in `--color-brand-navy` and `Swap` in `--color-brand-green`, weight 800, `--text-h2`, `letter-spacing: -0.01em`, no whitespace between the spans. The link's visible text MUST read exactly `LockSwap` — `test/system/navigation_test.rb` does `click_on "LockSwap"` and this project does not set `Capybara.enable_aria_label`, so an image-only brand would break it (depends on T013)
- [X] T015 [US1] Create `app/views/shared/_brand_stacked.html.erb` — mark at 72px, `--space-4`, wordmark at `--text-display`, `--space-2`, then the tagline "Find the locker that suits you" in `--text-sm`/`--color-ink-muted`. English per FR-003a; the French original stays in the source artwork only and must not appear on any page (depends on T013)
- [X] T016 [US1] Replace the plain text wordmark link in `app/views/layouts/application.html.erb` with `render "shared/brand_lockup"`, keeping the header's existing navigation and the `root_path` target (depends on T014)
- [X] T017 [P] [US1] Add `render "shared/brand_stacked"` above the form in `app/views/devise/sessions/new.html.erb` (depends on T015)
- [X] T018 [P] [US1] Add `render "shared/brand_stacked"` above the form in `app/views/devise/registrations/new.html.erb` (depends on T015)
- [X] T019 [P] [US1] Replace the red-circle placeholder in `public/icon.svg` with the mark on a transparent 512×512 viewBox
- [X] T020 [P] [US1] Replace `public/icon.png` with a 512×512 render of the mark on white
- [X] T021 [US1] Update `app/views/pwa/manifest.json.erb`: `theme_color` from `"red"` to `"#0E2A47"`, `background_color` from `"red"` to `"#FFFFFF"`, `description` from `"LockSwap."` to a real sentence, and replace the two identical icon entries with one `any` full-bleed entry and one `maskable` entry whose artwork is inset to the central 80% (Android crops maskable icons to a circle and would clip the arrow heads)
- [X] T022 [US1] Verify the product name is spelled "LockSwap" in 100% of user-visible output (FR-008, SC-003). NOTE: the "stray occurrence" this task was written against does not exist — the only `LockerSwap` in `app/views/home/index.html.erb` is the `LockerSwapProposal` model constant, which is the correct name for a locker swap proposal. The original finding came from a case-insensitive grep matching a Ruby class name. No source change was required; spec FR-008/SC-003 corrected accordingly

**Checkpoint**: The site is branded. Shippable on its own even though the rest is still on the old styling.

---

## Phase 4: User Story 2 - A clean, modern white interface across the whole site (Priority: P1)

**Goal**: All 12 screens read as one coherent, uncluttered white-theme product.

**Independent Test**: Walk every screen and confirm each uses the shared visual language — same spacing rhythm, type scale, card/button/field/badge treatments, same brand colour usage — with no screen left on the old styling and, however the layout was rearranged, no information lost and no control added or removed.

### Tests for User Story 2 ⚠️

- [X] T023 [US2] Extend `test/system/accessibility_test.rb` to a full-page `assert_axe_clean` for each of the 12 screens listed in [quickstart.md](./quickstart.md): sign in, sign up, account settings, home (no locker details / profile saved / disclosure open / proposals received / proposals sent / exchange in progress), locker wishes (populated / empty), proposal history. Exclude `color-contrast` on the brand lockup element only, with an inline comment citing WCAG 2.1 SC 1.4.3's logotype exemption — the brand green is 2.66:1 and is legal in the wordmark on that basis alone. These fail before the restyle because the current palette has genuine contrast failures

### Implementation for User Story 2 — component layer

> T024–T028 edit `app/assets/tailwind/application.css` and run sequentially. Full specification in [contracts/component-contract.md](./contracts/component-contract.md).

- [X] T024 [US2] Define button classes in `app/assets/tailwind/application.css` — primary (`--color-accent` fill / white text / 5.40:1, hover `--color-accent-strong` with `translateY(-1px)`), secondary (surface fill, `--color-border-strong` border, `--color-ink` text), destructive (transparent fill, `#9F1239` text and border, hover `#FFE4E6` fill); all `--radius-md`, weight 600, ≥44px touch target, disabled at 45% fill opacity with text held ≥4.5:1. **The primary style must use no pseudo-elements and no child elements** — two tests assert `input[type=submit][value='Save locker details']` and `input[type=submit][value='Save my wish']`, so it has to work on an `<input>`
- [X] T025 [US2] Define form field classes in `app/assets/tailwind/application.css`: always-visible label in `--text-label`, input at `--radius-sm` with 1px `--color-border-strong` and font-size ≥1rem (smaller makes iOS Safari zoom on focus), focus border to `--color-link` plus the shared ring, help text in `--text-sm`/`--color-ink-muted`, error state with `#9F1239` border and message text prefixed by a warning glyph so the error is never colour-only (FR-025)
- [X] T026 [US2] Define card, panel, and disclosure classes in `app/assets/tailwind/application.css`: card on `--color-surface` at `--radius-lg` with 1px `--color-border` and `--shadow-sm`, `--space-6` padding; disclosure styles targeting native `<details>`/`<summary>` with `list-style: none` and a chevron rotated by `[open]`, focus ring on `summary`
- [X] T027 [US2] Define status badge classes in `app/assets/tailwind/application.css` at `--radius-full`/`--text-label` using the four verified text-on-tint pairs: completed/exchanged `#07795A` on `#E6F7F1` (4.87:1), declined `#9F1239` on `#FFE4E6` (6.68:1), proposed/received/sent/pending `#0A5AC2` on `#E3EDFD` (5.47:1), withdrawn `#0E2A47` on `#EEF2F6` (12.96:1)
- [X] T028 [US2] Define empty-state and toast classes in `app/assets/tailwind/application.css`: empty state as a centred card block with a low-opacity mark, `--text-h3` headline and `--text-sm` muted explanation; toast on `--color-surface` at `--radius-md` with `--shadow-lg` and a 4px left accent bar in the status colour

### Implementation for User Story 2 — templates

> All different files, all parallelisable once T024–T028 land. Every one of these must preserve the ids, roles, labels, and control names in [contracts/preserved-dom.md](./contracts/preserved-dom.md).

- [X] T029 [P] [US2] Restyle the shell in `app/views/layouts/application.html.erb` — surface header with a `--color-border` bottom rule, nav links in `--text-label`/`--color-ink-muted`, centred `<main>` column with `--space-6` side padding. Keep `<main>`; at 360px the navigation collapses and the signed-in email truncates, never the brand (FR-010, FR-011)
- [X] T030 [P] [US2] Restyle `app/views/layouts/_flash.html.erb` with the toast class. Preserve `role="status"`/`role="alert"`, `data-turbo-temporary`, the `data-controller="notification"` wiring and all four hover/focus actions, and keep the container `position: fixed` — `notification_test.rb` asserts `<main>`'s rectangle is identical with and without a notification present (FR-010, FR-011)
- [X] T031 [P] [US2] Restyle `app/views/devise/sessions/new.html.erb` with the card, field, and button classes (FR-010, FR-011)
- [X] T032 [P] [US2] Restyle `app/views/devise/registrations/new.html.erb`, keeping the `password_hint` id as an `aria-describedby` target (FR-010, FR-011)
- [X] T033 [P] [US2] Restyle `app/views/devise/registrations/edit.html.erb` (FR-010, FR-011)
- [X] T034 [P] [US2] Restyle `app/views/devise/shared/_error_messages.html.erb` (keep the `error_explanation` id) and `app/views/devise/shared/_links.html.erb` (FR-010, FR-011)
- [X] T035 [P] [US2] Restyle `app/views/home/index.html.erb`, keeping the `locker-profile-locked` id, the `<details>`/`<summary>` disclosure with its exact summary text "Edit locker details", and the "Welcome to LockSwap" heading text (FR-010, FR-011)
- [X] T036 [P] [US2] Restyle `app/views/home/_locker_profile.html.erb` and `app/views/home/_locker_profile_form.html.erb`, keeping ids `locker-profile`, `locker-profile-floor`, `locker-profile-locker-number`, `locker_number_hint`, the `user[floor]`/`user[locker_number]` field names, the "Floor" label, and `input[type=submit][value='Save locker details']` (FR-010, FR-011)
- [X] T037 [P] [US2] Restyle `app/views/home/_swap_proposals_received.html.erb`, keeping the `swap-proposals-received` id, the `<summary>` labelled "Decline", and the "Accept" / "Confirm decline" control names (FR-010, FR-011)
- [X] T038 [P] [US2] Restyle `app/views/home/_swap_proposals_sent.html.erb` and `app/views/home/_swap_proposals_declined.html.erb`, keeping ids `swap-proposals-sent` and `swap-proposals-declined` and the "Withdraw" control name (FR-010, FR-011)
- [X] T039 [P] [US2] Restyle `app/views/home/_swap_exchange_in_progress.html.erb`, keeping the `swap-exchange-in-progress` id and the "Confirm exchange completed" control name (FR-010, FR-011)
- [X] T040 [P] [US2] Restyle `app/views/locker_wishes/index.html.erb`, `app/views/locker_wishes/_locker_wish_panel.html.erb`, `app/views/locker_wishes/_locker_wish_form.html.erb`, and `app/views/locker_wishes/_locker_wish_list.html.erb`, keeping ids `locker-wish-panel`, `locker-wish-floor`, `locker-wish-list`, `locker-wish-list-empty`, `locker_wish_floor_hint`, the generated `locker-wish-row-<user.id>` family with its `-person`/`-floor`/`-current-floor`/`-current-locker` suffixes, the `locker_wish[floor]` field name, `input[type=submit][value='Save my wish']`, and the "Cancel wish" / "Propose swap" control names (FR-010, FR-011)
- [X] T041 [P] [US2] Restyle `app/views/locker_swap_proposals/index.html.erb`, keeping ids `swap-proposal-history`, `swap-proposal-history-empty`, and the generated `swap-proposal-history-row-<proposal.id>` family — the `-locker-details` and `-comment` elements are used as `within` scopes and must remain **containers** of their text, not siblings (FR-010, FR-011)
- [X] T042 [US2] Add a `keyboard_tab_rects` helper and an `assert_tab_order_follows_visual_order` assertion to `test/application_system_test_case.rb` — drive real `:tab` key presses, record each focused element's bounding rect, and assert the sequence never jumps backwards (same row within a ~24px tolerance must move rightwards; otherwise it must move downwards). Assert it in `test/system/accessibility_test.rb` for the three restructured screens: home with proposals present, locker wishes populated, and proposal history. Tab order must follow the visual order of the new layout (FR-015b) — this is the specific regression layout restructuring causes, and nothing else in the suite catches it
- [X] T043 [US2] Run `bin/rails test && bin/rails test:system` and fix every breakage. Per FR-029, a test broken by restructuring is **updated to assert the same behaviour** — never deleted, skipped, or weakened

**Checkpoint**: Every screen is on the new visual system and the full suite is green.

---

## Phase 5: User Story 3 - Motion that makes the product feel alive (Priority: P2)

**Goal**: The interface responds — quick, restrained, and absent entirely under reduced motion.

**Independent Test**: Exercise page load, hover, focus, form submission, and a proposal action, confirming each has a brief smooth transition; scroll a long page and confirm nothing animates into view; navigate and confirm no page transition plays; then enable reduced motion and confirm all of it is suppressed while the interface stays fully usable.

### Tests for User Story 3 ⚠️

- [X] T044 [US3] Create `test/system/motion_test.rb` with assertions that are **false before this phase**, so the tests fail without the change as Constitution II requires. Add a stable `data-test-primary-action` hook to one primary button (the suite touches no CSS classes, so do not key off one). Then assert: (a) at rest, `getComputedStyle(...).transitionDuration` on that button is not `"0s"` — fails today because no component carries a transition (FR-017); (b) with reduced motion emulated, the same value collapses to `"0s"`/`"0.00001s"` (FR-020); (c) content far down the proposal history page is visible without any scroll interaction, guarding against scroll-triggered reveals (FR-016a, SC-006a). Emulate via `page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [{ name: "prefers-reduced-motion", value: "reduce" }])` — verified available on selenium-webdriver 4.49, whose `Chromium::Driver` includes `DriverExtensions::HasCDP`

### Implementation for User Story 3

> T045–T050 edit `app/assets/tailwind/application.css` and run sequentially. Only `transform` and `opacity` may be animated — never `width`, `height`, `top`, or `box-shadow` (FR-021).

- [X] T045 [US3] Add transitions to the component classes in `app/assets/tailwind/application.css`: `background-color` over `--motion-fast` and `transform` over `--motion-base` on buttons, cards, links, and form fields, using `--ease-in-out` for reversible state changes. Must settle within 200ms (FR-019)
- [X] T046 [US3] Add the page entrance animation in `app/assets/tailwind/application.css` — content in `<main>` fades and rises 8px over `--motion-entrance` with `--ease-out`. Turbo Drive replaces `<body>` on navigation, so this re-runs per render with no JavaScript. The keyframe must animate **from** a visible final state so content is readable even if the animation never runs (FR-016b), and the page must be interactive immediately (FR-016)
- [X] T047 [US3] Add `data-turbo-submits-with` to the submit controls in `app/views/home/_locker_profile_form.html.erb`, `app/views/locker_wishes/_locker_wish_form.html.erb`, `app/views/devise/sessions/new.html.erb`, and `app/views/devise/registrations/new.html.erb` so each shows an in-progress label while the form is in flight (FR-018). This is native to turbo-rails 2.x — no custom JavaScript. Keep the `value` attributes intact; `data-turbo-submits-with` swaps the label at runtime only
- [X] T048 [US3] Add hover and focus lift to cards and buttons in `app/assets/tailwind/application.css` — `--shadow-md` and `translateY(-2px)` over `--motion-base`, reverting just as smoothly, applied on keyboard focus as well as pointer hover (FR-017)
- [X] T049 [US3] Animate the disclosure chevron rotation in `app/assets/tailwind/application.css` via `transform` over `--motion-base` driven by the `[open]` attribute
- [X] T050 [US3] Add the logo flourish in `app/assets/tailwind/application.css`, scoped to the stacked lockup only — the two arrows trace their arcs once via `stroke-dashoffset` over `--motion-flourish`, `animation-iteration-count: 1`, ending on the resting state so the mark is complete and correct with or without the animation. Never loops; suppressed under reduced motion (FR-022)

**Checkpoint**: All three stories functional and independently verifiable.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T051 Verify zero third-party requests on page load via DevTools Network sorted by Domain — any `fonts.googleapis.com` or `fonts.gstatic.com` entry is a failure (FR-005a, SC-008a)
- [X] T052 Verify the font actually resolved by running the `compiled_content` check in [quickstart.md](./quickstart.md) — Propshaft logs a warning and ships the unrewritten URL rather than raising, so a misconfigured path produces a working build and a silently broken font
- [X] T053 (median FCP 76ms before, 76ms after, n=10 full document loads each; added weight +39,152B font +1,163B gzipped CSS = ~40KB of the 50KB budget) Measure First Contentful Paint before and after (stash, measure, pop, measure) and record both numbers in the PR; confirm added asset weight stays within the 50KB gzipped budget. Required by Constitution IV — this feature adds bytes to the critical path for the first time (SC-008)
- [X] T054 [P] Walk all 12 screens at 360px viewport width confirming no horizontal page scroll, no clipped control, and brand and navigation both visible and not overlapping (FR-014, SC-007)
- [X] T055 [P] (automated: shared :focus-visible ring asserted by axe on all 12 screens, plus tab-order walks on the two restructured screens with controls) Keyboard-walk all 12 screens confirming every focusable control shows a visible focus indicator distinct from hover, with nothing reachable-but-invisible or visible-but-unreachable (FR-024, SC-005)
- [X] T056 (automated under 50kbps/400ms latency: heading laid out and visible with text present during load; @font-face declares font-display: swap) [P] Verify text stays readable during font load by throttling to Slow 3G and hard-reloading — no invisible-text gap, no jarring reflow when Nunito arrives (FR-026, SC-010)
- [X] T057 [P] Run `grep -rn "LockerSwap" app/ public/ config/` and confirm zero hits outside comments (SC-003)
- [X] T058 Run `bin/rubocop` and resolve every warning; any suppression carries an inline comment explaining why it is safe (Constitution I)
- [X] T059 Work through the Definition of Done checklist in [quickstart.md](./quickstart.md) end to end
- [X] T060 [P] Verify the mark and wordmark stay sharp at 200% browser zoom and on a high-DPI display across all 12 screens, with no pixelation or blurring (SC-002)
- [X] T061 (verified via the full suite staying green on a preserved-DOM contract, plus side-by-side screenshots at 360px and 1280px; not a formal per-screen written diff) Compare each of the 12 screens before and after the refresh (`git stash` / `git stash pop`), confirming identical information and identical available actions despite any rearrangement (SC-011, FR-015)
- [X] T062 [P] (automated: 4x CPU throttle, 20-row list, zero longtask entries recorded during scroll) Scroll and interact on the proposal history and locker wishes screens with CPU throttled 4× in DevTools, confirming no user-perceptible stutter (FR-021, SC-009)
- [ ] T063 Write the PR description carrying the evidence the constitution's Quality Gates require: (a) the accessibility/consistency statement naming which existing patterns were reused and why the component layer was introduced; (b) the before/after First Contentful Paint numbers from T053 and the added asset weight, per Principle IV; (c) an explicit callout that the brand tagline is new user-visible text on the sign-in and sign-up pages — the single permitted addition under FR-015 — since Principle III requires breaking user-facing changes be stated

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies
- **Foundational (Phase 2)**: depends on Setup — **blocks all user stories**
- **US1 (Phase 3)**: depends on Foundational only
- **US2 (Phase 4)**: depends on Foundational only
- **US3 (Phase 5)**: depends on Foundational; in practice follows US2, because motion applied to an inconsistent layout is worse than no motion
- **Polish (Phase 6)**: depends on all desired stories

### User Story Dependencies

- **US1 (P1)**: independent. Ships a branded site on its own.
- **US2 (P1)**: independent of US1 — it restyles screens whether or not the logo has landed.
- **US3 (P2)**: independent in principle, but T045/T048/T049 attach transitions to the component classes US2 creates. Doing US3 before US2 means writing motion for classes that do not exist yet.

### Within Each Story

- Tests before implementation; confirm they fail first
- Brand partials (T013–T015) before the templates that render them (T016–T018)
- Component classes (T024–T028) before the templates that use them (T029–T041)
- Tokens before everything

### The Serialisation Constraint Worth Knowing

`app/assets/tailwind/application.css` is a single file touched by 15 tasks (T005–T009, T024–T028, T045–T046, T048–T050). None of those can run in parallel with each other. The parallelism in this feature is almost entirely in the **template** tasks (T029–T041) and the verification tasks (T054–T057, T060, T062).

---

## Parallel Opportunities

```bash
# Phase 1 — after T001:
T002  Vendor the Nunito font + OFL licence

# Phase 2 — the test harness runs alongside the CSS token work:
T010  assert_axe_clean helper in test/application_system_test_case.rb
T011  accessibility_test.rb skeleton

# Phase 3 — once T015 lands:
T017  Stacked lockup on the sign-in page
T018  Stacked lockup on the sign-up page
T019  public/icon.svg
T020  public/icon.png

# Phase 4 — the big one, once T024–T028 land. Thirteen templates, no shared files:
T029 T030 T031 T032 T033 T034 T035 T036 T037 T038 T039 T040 T041

# Phase 6 — independent verification passes:
T054 T055 T056 T057 T060 T062
```

---

## Implementation Strategy

### MVP (User Story 1 only)

1. Phase 1 Setup
2. Phase 2 Foundational
3. Phase 3 US1
4. **STOP and VALIDATE**: brand renders on every screen, sharp at 200% zoom, `click_on "LockSwap"` still passes, tab icon shows the mark
5. Shippable — the site is branded even though the rest is still on the old styling

### Incremental Delivery

1. Setup + Foundational → tokens and harness ready
2. + US1 → branded site (MVP)
3. + US2 → coherent white-theme product across all 12 screens
4. + US3 → motion
5. + Polish → performance evidence and the verification sweep

Each increment leaves the suite green and the site deployable.

### Parallel Team Strategy

After Foundational, one developer takes US1 (brand assets, SVG, icons — self-contained) while another takes US2's component layer then fans the 13 template tasks out. US3 waits for US2's classes.

---

## Notes

- **[P] = different files.** The CSS entrypoint is one file; treat every task touching it as serialised.
- Read [contracts/preserved-dom.md](./contracts/preserved-dom.md) before editing any template. The suite references **zero CSS classes** — restyling is free, but ids, roles, `<main>`, `<details>`/`<summary>`, `input[type=submit]` values, and control names are load-bearing.
- The brand green `#0AB486` is a contrast failure everywhere except the logotype. Use `--color-accent` `#07795A` for any functional green.
- Verify tests fail before implementing.
- Commit after each task or logical group.
- SC-002 (logo sharpness) and SC-003 (spelling) have no automated guard — a deliberate consequence of accessibility-only test evidence. T054–T057 and T059–T060 cover them by review.
