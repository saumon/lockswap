# 012 — Responsive site layout and signed-in menu

Makes every screen work from 320px up, and gives the signed-in menu two
treatments around a single breakpoint at **48rem (768px)**: a `<details>`
disclosure behind a toggle below it, the bar it has always been at and above it.

## Breaking change for users

**Below 768px the menu now collapses behind a toggle.** Anyone using the site in
a narrow window will find the destinations, their email and Log out behind a
control in the top bar rather than laid out in it. Nothing is removed — the same
four things are all there, one tap away (FR-011).

## Core Principles

**I. Code Quality** — `bin/rubocop` clean, zero suppressions. The menu's contents
live in one partial (`shared/_site_menu_items`) rendered into both treatment
containers, so there is a single source of truth for what the menu offers rather
than two lists kept in agreement by review. Every new CSS block, partial and
controller carries a comment naming the requirement it serves.

**II. Testing Standards** — 143 → 175 system tests. Every assertion fails against
the previous stylesheet: there were no width-based rules before this branch
beyond one `.detail-grid` query. New coverage: the two-width sweep across every
screen, menu behaviour in both treatments, the no-script baseline, touch-target
measurement, keyboard order at both widths, and axe at phone width including
with the panel open. Plus `test/stylesheet_breakpoint_test.rb`, a unit test that
enforces FR-018 by refusing any media query at a width other than the one
breakpoint.

**III. User Experience Consistency** — reuses `<details>` (the site's disclosure
in three prior features), `.data-table`, the design tokens, and the `execute_cdp`
set-and-clear pattern already used for reduced-motion emulation. The only new
component is the menu toggle. No user-facing copy changed; the empty states
render identically in both list forms.

**IV. Performance** — no request-path, query or model change; nothing to measure
server-side. The cost is CI time: **+32 system tests (143 → 175, +22%)**, landing
on the `system-test` job, which runs on its own runner in parallel with the unit
`test` job. Local full-suite wall clock is ~98s. Please compare the job duration
on this PR against `dev`.

## Two design decisions worth reviewing

**The menu renders two containers, not one.** The first attempt rendered a single
`<details>` and dissolved it on wide screens with `display: contents` plus
`::details-content { content-visibility: visible }`. That version laid out
correctly — real 455×44 box, Chrome reporting the content visible. It was still
wrong: content inside a closed `<details>` is treated as hidden by the platform
whatever the computed style says. The WebDriver displayedness algorithm states it
outright, and assistive technology plausibly follows. A bar whose links are
"visible" only to someone reading pixels does not satisfy FR-011, so the content
is now swapped (`display: none` on the inactive container) rather than revealed.
Only one copy is ever in the accessibility tree.

**The lists keep their `<table>`.** Below the breakpoint the rows restack as
labelled cards via `display` changes plus `content: attr(data-label)`. Explicit
ARIA roles restate what the native elements would have said, because changing
display drops the implicit table roles. axe is clean on both lists at phone
width. Desktop markup is unchanged apart from the added attributes, and every
existing row id is preserved — the 70 existing list tests pass untouched.

## Defects found and fixed along the way

- The **flash dismiss control was a 20×20 target** sitting on a message that
  overlays the content, so a miss landed on whatever was underneath. Now 44×44
  below the breakpoint, with the × keeping its drawn size (FR-007c).
- Two **test-infrastructure bugs** that would have made assertions pass
  vacuously: the visibility filter used a rect test, but a control inside a
  closed `<details>` still reports a bounding box; and it measured before the
  entrance animation settled, where `checkOpacity` reports everything as
  invisible. Both fixed, and `assert_touch_targets_at_least` now fails if it
  measured nothing at all.

## Accessibility

axe (WCAG 2.1 A/AA) now runs at phone width as well as desktop, on every screen,
including with the menu panel open. Keyboard order asserted in both treatments.
The menu is a `<details>`, so expanded/collapsed announcement, keyboard operation
and focus return are native and work with scripting disabled.

## Deferred to manual verification

Neither is coverable by the automated matrix. **Both still need doing before
merge:**

- [ ] **FR-008** — forms usable with the on-screen keyboard open. Headless Chrome
      has no soft keyboard; needs a real device.
- [ ] **SC-008** — 200% text zoom at desktop width. Outside the viewport matrix.
