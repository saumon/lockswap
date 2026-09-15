# Phase 0 Research: Responsive Site Layout and Signed-In Menu

**Feature**: 012-responsive-layout-menu
**Date**: 2026-09-15

The spec arrived with all five clarifications resolved, so there are no
`NEEDS CLARIFICATION` markers to close. What remains are four technical
questions the spec deliberately left to planning. Each is settled below.

---

## R1 — Rendering one menu that is a disclosure below 48rem and a plain bar above

**Question**: FR-010 wants a `<details>`-style disclosure below the breakpoint;
FR-009 wants the same destinations laid out directly in the bar above it. FR-011
and the "no control appears twice" edge case rule out simply rendering two
navigations. A closed `<details>` hides its own content, so how does the same
element become an always-open row on a wide screen without script?

**Decision**: Render the menu **once**, inside `<details class="site-menu">`, and
neutralise the disclosure above the breakpoint with two co-operating
declarations:

```css
@media (min-width: 48rem) {
  .site-menu { display: contents; }
  .site-menu::details-content { content-visibility: visible; }
  .site-menu-toggle { display: none; }
}
```

Browsers hide a closed `<details>` in one of two ways depending on engine
vintage. Older engines withhold the children from the rendering tree via the
internal slot, which `display: contents` dissolves along with the element's own
box. Current engines instead apply `content-visibility: hidden` to the
`::details-content` pseudo-element, which the second declaration overrides.
Declaring both covers either implementation, and each is inert where the engine
does not use that mechanism. With the summary hidden and the content forced
visible, `.site-menu-panel` becomes an ordinary flex child of the nav row.

**Rationale**:

- One DOM node per control. FR-011 ("the same capabilities at every width") and
  FR-018b become structurally true rather than something two code paths have to
  be kept agreeing on, and Principle I's rule against duplicated logic holds.
- `<details>` is this codebase's established disclosure (`.disclosure`,
  `.tile-disclosure`, `.locker-profile-editor` — three features already use it,
  each with a comment citing its built-in keyboard and screen-reader support).
  FR-019 asks for exactly this reuse.
- It satisfies the no-script baseline (FR-010b) for free: open, close, keyboard
  operation and expanded/collapsed announcement are all native.

**Risk and fallback**: `::details-content` is recent. If it proves unsupported
in the CI browser, the desktop bar would render collapsed — a visible failure,
not a silent one. **T-series task ordering puts a verification test before the
markup work** so this is caught in minutes rather than at review. Documented
fallback if it fails: extract the menu contents to a shared partial and render
it into two CSS-exclusive containers, `display: none` on the inactive one, which
keeps a single source of truth for the *content* while duplicating only the
wrapper. Only one container is ever in the accessibility tree, so the "appears
twice" edge case still holds.

**Alternatives considered**:

| Alternative | Rejected because |
|---|---|
| Always render `<details open>`, hide summary on desktop | Solves desktop, breaks mobile — the panel would start open on every page load. |
| Script sets `open` from a media query | Makes navigation depend on JavaScript, which Q5 explicitly ruled out. |
| Two separate navigations in the layout | Duplicates every control and every link target; FR-011 becomes a convention rather than a fact. |

---

## R2 — Restacking the two tables as cards without losing table semantics

**Question**: FR-005 wants stacked cards below the breakpoint and the existing
column table above it. FR-005a wants every value visibly labelled, FR-005d wants
both forms conveyed correctly to assistive technology, and FR-020 forbids any
desktop regression.

**Decision**: Keep a single `<table>`. Add an explicit ARIA role to each table
element and a `data-label` attribute to each `<td>`. Below the breakpoint, flip
the table elements to block layout and surface the label from the attribute:

```css
@media (max-width: 47.999rem) {
  .data-table thead { position: absolute; width: 1px; height: 1px;
                      overflow: hidden; clip-path: inset(50%); }
  .data-table tr    { display: block; /* card surface */ }
  .data-table td    { display: grid; grid-template-columns: auto 1fr; }
  .data-table td::before { content: attr(data-label); /* the visible label */ }
}
```

The explicit roles (`role="table"`, `role="row"`, `role="columnheader"`,
`role="cell"`) are what make this safe: changing an element's `display` drops
its implicit table role in current engines, and restating the role keeps the
accessibility tree correct in *both* forms. The roles are redundant-but-harmless
above the breakpoint, where the native element already supplies them.

**Rationale**:

- Desktop markup is unchanged apart from added attributes, so FR-020 is
  satisfied by construction rather than by inspection.
- One rendering of each row means the "Propose swap" form exists once, and
  FR-005c (same record order, same field order) is automatic — there is only one
  order.
- `content: attr(data-label)` is visible text, which is what FR-005a asks for.
- The header row is visually hidden rather than removed, so its `<th>` cells
  remain available to anything that walks the table.

**Risk and fallback**: axe-core runs against every screen and, per FR-024, will
now run at the phone width too. If it objects to the restacked table, the
fallback is to render a `<ul>` of `<li>` cards, each containing a `<dl>` of
term/value pairs, as a second CSS-exclusive form. That is unambiguously correct
semantically but duplicates the row rendering, so it is the fallback and not the
first choice. **The axe-at-phone-width task is sequenced immediately after the
restack task** so the answer arrives before anything is built on top of it.

**Alternatives considered**:

| Alternative | Rejected because |
|---|---|
| Keep `.table-scroll` horizontal scrolling | This is what Q1 decided against: the "Propose swap" button ends up off-screen behind an undiscoverable swipe. |
| Drop columns below the breakpoint | Contradicts the "same information at every size" assumption and FR-005a. |
| Replace the table with a grid at all widths | Loses real table semantics on desktop, which is a regression under FR-020. |

---

## R3 — Meeting the 44px touch-target floor below the breakpoint

**Question**: FR-007/FR-007b require standalone controls to reach 44×44 below
the breakpoint, while the existing `.btn-sm` and the locker-profile pencil sit
at `2.25rem` (36px) and must keep that size above it (FR-007b, FR-020).

**Decision**: Raise the floor inside the narrow-width media query only.

- `.btn-sm` and `.locker-profile-editor-summary`: `min-height` / `width` /
  `height` go from `2.25rem` to `2.75rem` (44px) below 48rem.
- `.site-nav-link`, when inside the menu panel, gets `min-height: 2.75rem` and
  vertical padding so the whole row is the target, not just the text.
- The menu toggle is authored at `2.75rem` square from the start.
- `.auth-link` and any other link inline in prose are left alone under FR-007a.

FR-007c's invisible-enlargement allowance is available via padding where a
control's drawn shape should stay small, but is not expected to be needed: every
control in scope can simply grow.

**Rationale**: A single narrow-width block keeps the change auditable and makes
FR-007b's "desktop density unchanged" verifiable by reading one media query.
Using the existing `--spacing-*` scale is not possible here — 44px is not on the
scale — so `2.75rem` is written literally, with a comment naming the
requirement, matching how `2.25rem` is already justified in place.

**Alternatives considered**: raising the floor at every width was rejected by Q2
(it overrides feature 009's deliberate sizing and loosens desktop layouts);
lowering the requirement to WCAG 2.2's 24×24 was also rejected by Q2.

---

## R4 — Driving the test suite at two viewport widths

**Question**: FR-022 requires automated runs at 390×844 and 1400×1400, but
`ApplicationSystemTestCase` fixes `screen_size: [1400, 1400]` at class level for
the whole suite.

**Decision**: Add a `with_viewport` helper to `ApplicationSystemTestCase` that
drives Chrome DevTools Protocol directly:

```ruby
page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
  width:, height:, deviceScaleFactor: 0, mobile:)
```

cleared in `teardown` with `Emulation.clearDeviceMetricsOverride`, exactly
mirroring how `emulate_reduced_motion` already sets and clears
`Emulation.setEmulatedMedia`.

**Rationale**:

- The file already reaches for `execute_cdp` and already documents why
  (`DriverExtensions::HasCDP` ships with the Chromium driver, so no new gem).
  Reusing that pattern is Principle III applied to test code.
- CDP overrides the **viewport**, which is what media queries read. Resizing the
  OS window via `manage.window.resize_to` sets the outer window instead, leaving
  the viewport off by the browser chrome — the wrong number for a test whose
  whole subject is a breakpoint at an exact width.
- The existing teardown already demonstrates why clearing matters: the browser
  is shared across tests in this single-worker suite, so a leaked override would
  silently put every later test at phone width.

**Assertions the helper enables**:

| Check | Mechanism |
|---|---|
| No horizontal overflow | `documentElement.scrollWidth <= clientWidth` |
| Menu treatment at width | presence/absence of the toggle, panel visibility |
| List form at width | card form vs. `<table>` rendering |
| Touch targets (FR-025) | `getBoundingClientRect()` over a defined selector list of standalone controls |
| Accessibility (FR-024) | existing `assert_axe_clean`, called inside the viewport block |

**Cost, and how it is contained**: the system suite runs
`parallelize(workers: 1)` because feature 003 found that parallel browsers made
tests fail on expired waits rather than on behaviour. Running every existing
system test at both widths would roughly double the slowest suite. The plan
therefore runs the **sweep** checks (overflow, axe, menu treatment, list form)
across screens at both widths, and leaves existing behavioural tests at their
current single width, adding narrow-width behavioural tests only for what is
genuinely width-specific: the menu panel and the card restack. This is recorded
against Principle IV as the feature's measured cost.

---

## Constitution notes carried into the plan

- **Principle II** is satisfied structurally: FR-022–FR-025 are themselves test
  requirements, so the feature cannot be "done" without the tests that prove it.
- **Principle III** drives R1 (reuse `<details>`), R2 (keep the existing
  `.data-table`), R3 (existing spacing and sizing conventions) and R4 (reuse the
  `execute_cdp` pattern).
- **Principle IV**'s "only transform and opacity are animated" rule (already
  stated in the stylesheet's Motion section) applies to any panel animation; the
  global `prefers-reduced-motion` block covers FR-016 with no new code.
- **Principle I**: every new CSS block and partial carries a comment naming the
  requirement it serves, matching the density of the surrounding code.
