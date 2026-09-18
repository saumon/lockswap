# 017 — Filter locker wishes by floor

Two independent floor filters on the **Locker wishes** list: one on the floor each
person is *looking for*, one on the floor they *already hold a locker on*. Either
can be used alone; set together they show only the rows matching both — the
shortlist of people an exact two-way swap would suit.

No migration, no new table, no new column, no new route. The selections are query
parameters on the existing `GET /locker_wishes`.

## What changes for users

The list gains a filter bar above it with two rows of choices, each labelled the
way the list's own columns are already labelled: **Looking for floor** and **Their
floor**. Each offers "All floors" plus the floors that actually appear among the
active wishes — never a floor nobody is on.

The screen opens unfiltered, exactly as today. Nothing about a row changes: same
person, same floors, same locker, same swap control and the same reasons a swap
cannot be proposed. The ordering — oldest declaration first — is untouched.

Three behaviours worth stating plainly, because each was a decision rather than a
default:

- **The choices never shift under you.** Setting one filter does not add to, remove
  from or reorder what the other offers. That makes a combination matching nobody
  reachable, and that case has its own message, distinct from the existing "Nobody
  is looking for a locker right now" (FR-006, FR-016).
- **The filters survive your own edits.** Saving or cancelling your own wish returns
  you to the list still filtered the way you left it. If your row no longer matches,
  it simply leaves the list — the filters are not cleared to keep it in view
  (FR-019).
- **Floors stay free text.** No validated list of floors, no normalisation: `3` and
  `03` remain two distinct floors. They are *ordered* as numbers, though, so `3`
  comes before `10` rather than after `1` (FR-007).

## Core Principles

**I. Code Quality.** The querying lives on `LockerWish` as scopes — `active`,
`looking_for`, `owner_on_floor` — plus two bounded choice queries. `active` is the
"exclude people mid-exchange" rule that 003 applied inline in the controller,
extracted because three queries now depend on it; left inline, the list and the
floors offered could drift and a floor would be offered that matched nothing. Both
axes are one `FloorFilter` PORO instantiated twice, so the ordering rule, the
blank-means-all-floors rule and the keep-the-selection-visible rule are each
written once rather than per axis. The controller still reads as read-params,
build-list, render. RuboCop: 84 files, no offenses.

**II. Testing Standards.** Every requirement has a test at the level that can reach
it: `floor_filter_test.rb` (15 tests, no database) for ordering and the in-force
selection; `locker_wish_test.rb` for the scopes and FR-012; the controller test for
parameter handling, junk values, the FR-019 redirects and a query-count assertion;
`locker_wish_filter_test.rb` (21 tests) for the four user stories in the browser.
`locker_wish_test.rb` and `locker_swap_proposal_test.rb` pass **unedited** — that is
the evidence for FR-013 and FR-014 that nothing about the existing screen moved.

**III. User Experience Consistency.** The screen reuses `card`, `data-table`,
`empty-state`, `btn` and `meta` unchanged, and the narrow-width restack is
untouched. Two patterns are new to this codebase, and both are deliberate:

- **A Turbo Frame** around the list. It is what makes a filter change replace the
  list alone — the declare panel and your place on the page stay put (FR-009) —
  while `data-turbo-action="advance"` still puts the filtered address in the
  history, so a filtered view can be shared and reached with Back (FR-018).
- **A filter bar of links, not a `<select>`.** FR-008 requires that moving through
  the choices without committing to one leaves the list alone. A select that
  submits on `change` fires as a keyboard user arrows through its options — the
  WCAG 2.1 SC 3.2.2 (On Input) failure that requirement describes. A link is
  activated deliberately and never merely by being focused.

Accessibility: each axis is a `<nav>` with its own `aria-label`, the choice in
force carries `aria-current="true"` (and the styling hangs off that attribute, so
the state cannot be shown without being announced), and axe-core is clean on the
filtered list and on the no-match state with no new exemption.

**IV. Performance Requirements.** Two `SELECT DISTINCT` queries are added per
render, one per axis, each returning at most one row per distinct floor and
independent of wish count. Nothing is added per row, and filtering is pushed into
SQL so a filtered view reads *fewer* rows than the screen does today. Asserted in
`locker_wishes_controller_test.rb`: a filtered index issues no more queries than an
unfiltered one.

## Three things the process caught that review would have had to

- **The frame would have swallowed the swap-proposal toast.** `/speckit-analyze`
  flagged that the "Propose swap" `button_to` is the only form inside the new
  frame, and that its redirect targets a page *containing* that frame — so Turbo
  would render the redirect into the frame, the "Swap proposal sent." message would
  never appear, and the address would lose both selections. Confirmed by removing
  the fix and watching `locker_swap_proposal_test.rb` fail in two places. Fixed with
  `data-turbo-frame="_top"`.
- **Hidden fields in the declare panel go stale.** The panel sits outside the frame
  so filtering never re-draws it — which means filter fields placed inside it keep
  whatever was in force at page load, and FR-019 fails on the first filter change.
  The fields now live inside the frame and attach to the two forms by id, using the
  HTML `form` attribute. No JavaScript.
- **Back would have contradicted the address bar.** Two separate causes, both
  caught by the same test. An advancing frame navigation snapshots the page for
  the address being *left* after the frame has already been re-drawn, so a cached
  restore shows the new filter under the old address — fixed with
  `<meta name="turbo-cache-control" content="no-cache">`. And Turbo's restoration
  visit for such an entry does not reliably re-render the frame at all: measured
  at two runs in five, the address went back and the list did not, with no amount
  of waiting helping. `frame_history_controller.js` gives Turbo first refusal on a
  history movement and, if the frame is still in the document afterwards, points
  it at the address. Six consecutive runs green with it, two in five failing
  without.

  This is the one place the design gave up its "no JavaScript" property. Stock
  Turbo cannot hold FR-009 (change the list alone), FR-018 (address, Back and
  Forward) and no-JavaScript at once; the no-JavaScript part was a preference
  recorded in `research.md`, not a requirement, and the codebase already has six
  Stimulus controllers.

## Not done

`quickstart.md` section-by-section manual validation was not performed by hand; the
same scenarios are covered by `locker_wish_filter_test.rb`, `accessibility_test.rb`
and `responsive_test.rb`. Worth a few minutes in a browser before merge.

Two spec-level decisions are still open and deliberately untouched, both raised by
`/speckit-analyze`: SC-001 names a scale (30 wishes across 5 floors) that only the
scroll-preservation test builds, and SC-005's "no perceptible delay" has no
threshold — the query-count assertion is a narrower claim than the one written.
