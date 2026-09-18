# Phase 0 Research: Filter locker wishes by floor

**Feature**: [spec.md](./spec.md) | **Branch**: `017-locker-wishes-floor-filter` | **Date**: 2026-09-18

No `NEEDS CLARIFICATION` markers survived `/speckit-specify` and `/speckit-clarify`, so this document
resolves the remaining *technical* unknowns: how the screen updates in place, what the filter control
is made of, where filtering happens, and how the selections survive the writes on the same screen.

---

## R1 — Updating the list in place while the address still changes

**Decision**: Wrap the wish list in `<turbo-frame id="locker-wish-list" data-turbo-action="advance">`.
The filter links target that frame (they are inside it, so no `data-turbo-frame` attribute is needed).
`LockerWishesController#index` keeps rendering the whole page; Turbo extracts the matching frame from
the response and swaps only that.

**Rationale**: FR-009 and FR-018 pull in opposite directions — the first says only the list region may
change and the viewer's position must be preserved, the second says the page address must reflect the
selections so the view can be shared and reached with back/forward. A frame navigation gives the
first; `data-turbo-action="advance"` promotes that frame navigation to a history entry, giving the
second. Because `#index` renders the full page, a cold load or a refresh of the filtered URL renders
the same filtered screen server-side, so the two paths cannot diverge. No JavaScript is written.

**Alternatives considered**:

- *Full-page navigation*. Simplest, works without Turbo — but the page returns to the top on every
  filter change, which is precisely what the Clarifications session ruled out (Q4) and what SC-006
  now forbids.
- *Turbo Streams*. Would also update the region, but needs a stream-producing action and a
  `turbo_stream` format branch, and does not change the address on its own — FR-018 would then need a
  separate mechanism.
- *Stimulus controller + `fetch`*. Hand-written JavaScript to reproduce what a frame does natively,
  plus manual `history.pushState`. More code, more to test, no benefit here.

**Note for the PR**: this is the codebase's first Turbo Frame. Principle III requires new patterns to
be justified rather than simply introduced; the justification is the FR-009 + FR-018 pair above.

**Found during implementation — the snapshot cache has to be turned off here.** An advancing frame
navigation caches the page snapshot for the address being *left* after the frame has already been
re-drawn. The cache therefore holds, under the old address, markup showing the new filter — and Back
replays it, so the screen and the address bar disagree. `<meta name="turbo-cache-control"
content="no-cache">` on this screen makes a restoration visit ask the server instead, which renders
whatever the address says. It costs a round trip on Back and buys a screen that cannot contradict its
own URL. Asserted by the back/forward test in `locker_wish_filter_test.rb`.

**Found during implementation — Back needs help, and that is where the JavaScript went.** Turbo's
restoration visit for a frame-advance history entry does not reliably re-render the frame: measured at
roughly two runs in five, the address went back to `?looking_for=5` while the list still showed `7`,
and no amount of waiting changed it. Stock Turbo cannot hold FR-009 (change the list alone), FR-018
(address, Back and Forward) and "no JavaScript" at once — one had to give, and the no-JavaScript
preference was this document's, not the spec's. `frame_history_controller.js` (~15 lines) gives Turbo
first refusal on a history movement and, if the frame is still in the document afterwards — meaning
Turbo left the page alone — points it at the address so it fetches the matching list. Six consecutive
runs of the back/forward test pass with it and two in five fail without it. The codebase already has
six Stimulus controllers, so this is not a new pattern for it.

**Also found during implementation — Turbo does not reset the scroll position here.** The concern that
an advancing navigation would scroll to the top, and would need JavaScript to undo, turned out to be
unfounded: measured with and without a restoring Stimulus controller, the position is preserved either
way, so the controller was deleted. The design remains free of hand-written JavaScript. (What looked
like a scroll reset in the first draft of the test was the browser driver scrolling an off-screen link
into view before clicking it — the test now keeps the filter bar in view so it measures the feature.)

---

## R2 — The filter control: links, not a `<select>`

**Decision**: Render each axis as a labelled group of links — "All floors" plus one per floor — with
`aria-current="true"` on the link matching the selection in force. No `<select>`, no submit button, no
JavaScript.

**Rationale**: FR-008 has two halves. "Takes effect in one action, no Apply control" is satisfiable
several ways; "moving through a filter's available floors without committing to one — for example
arrowing through them with the keyboard — MUST NOT re-filter the list" is not. A `<select>` that
submits on `change` fires that event as the user arrows through options on several
browser/platform combinations, which is the WCAG 2.1 SC 3.2.2 (On Input) failure the requirement
describes: the list would re-filter repeatedly at someone who is only reading the choices. A link is
activated deliberately (Enter, or a click) and never by being focused, so both halves hold by
construction. Links also give FR-018 and browser back/forward for free, since each choice simply *is*
a URL.

**Alternatives considered**:

- *`<select>` auto-submitting on `change`*. Fewest elements on screen, scales to many floors — but
  fails FR-008's second half and SC-008's keyboard promise.
- *`<select>` plus an "Apply" button*. Avoids the On Input problem, but costs the extra interaction
  the Clarifications session rejected (Q3) and that SC-001 forbids.
- *`<select>` committing on blur or on Enter via Stimulus*. Custom JavaScript reproducing a link's
  semantics, with a commit moment users cannot see.

**Accessibility shape**: each axis is a `<nav>` with its own `aria-label` naming what it filters
(FR-002, FR-021), so assistive technology announces two distinct landmarks rather than one
undifferentiated pile of links. `aria-current="true"` — not `aria-current="page"`, since the choices
are states of one screen, not separate pages — marks the selection in force.

**Scale note**: one link per distinct floor. The choice set is bounded by the number of floors in a
building, and the bar wraps at narrow widths (FR-023). If a deployment ever accumulated dozens of
distinct free-text floor values this would want revisiting, but that is a data-hygiene problem the
spec explicitly leaves out of scope.

---

## R3 — Where filtering happens, and where the choices come from

**Decision**: Filter in SQL, via scopes on `LockerWish`. Derive each axis's choices with its own
`SELECT DISTINCT` over the **unfiltered** active set. Extract the existing "exclude people with an
exchange in progress" rule into a shared `active` scope that all three queries build on.

**Rationale**: FR-006 settles the question the Clarifications session asked (Q5) — each filter's
choices come from all active wishes and never narrow when the other filter is set — so the choices
cannot be derived from the filtered relation, and the two choice queries have to run against the
unfiltered set regardless of what is selected. Given that, filtering the list itself in SQL rather
than in Ruby costs nothing extra and means a filtered view reads *fewer* rows than the screen does
today (Principle IV). The `active` scope is extracted because three queries now depend on the same
definition of "active"; leaving it inline in `all_locker_wishes` would let the list and the choices
drift apart, which would show up as a floor being offered that matches nothing.

**Query budget**: two `DISTINCT` queries are added, each returning at most one row per distinct floor
— constant in the number of wishes. Nothing is added per row. The controller test asserts the
filtered index issues no more queries than the unfiltered one, which is the Principle IV evidence the
PR needs.

**Alternatives considered**:

- *Load every active wish and filter in Ruby*. One query instead of three, and the choices fall out of
  the same array — but it makes the existing unbounded load unconditional, so the filtered path would
  read every row to display a handful. Wrong direction for Principle IV.
- *Narrow each filter's choices by the other's selection*. Rejected by the Clarifications session (Q5)
  on UX grounds; it would also have made the choice queries depend on the filtered relation.

---

## R4 — Ordering the choices

**Decision**: Sort in Ruby, on the small distinct-floor arrays, with the key
`[numeric? ? 0 : 1, numeric_value_or_zero, raw_string]`. Numeric-ness is decided by
`Integer(value, exception: false)`.

**Rationale**: FR-007 requires numeric floors ascending (`3` before `10`), then non-numeric values
alphabetically — a natural sort over a column that is free text. `Integer(_, exception: false)`
returns `nil` for `"RDC"` and an Integer for `"3"`, `"03"` and `"-1"`, which is exactly the partition
the requirement describes, with basements sorting ahead of ground floors as they should. The trailing
`raw_string` in the key breaks the `"3"` / `"03"` tie deterministically, which the spec's edge case
requires ("their order relative to one another is settled consistently rather than varying between
displays"). Sorting in Ruby is free here: the arrays hold one entry per distinct floor, not per wish.

**Alternatives considered**:

- *`ORDER BY CAST(floor AS INTEGER), floor` in SQL*. SQLite casts `"RDC"` to `0`, so non-numeric
  values would be scattered among the low-numbered floors instead of grouped after them.
- *Plain string sort*. Rejected by the Clarifications session (Q2): `10` would sit between `1` and `2`.
- *A `Float`-based check*. Would accept `"3.5"` as numeric. `Integer` keeps the numeric group to whole
  floors; a value like `"3.5"` falls into the alphabetical group, which is defined behaviour rather
  than a surprise ordering. Recorded here so the choice is deliberate rather than incidental.

---

## R5 — Carrying the selections through the declare and cancel writes

**Decision**: The declare form and the cancel control each carry the two selections as hidden fields;
`LockerWishesController#create` and `#destroy` redirect to `locker_wishes_path` with those values.
Rejected declares re-render `:index` with both filters still in force.

**Rationale**: FR-019. `#create` and `#destroy` are separate requests that end in a redirect, so the
query string of the screen the viewer came from is not carried anywhere unless it is sent with the
write and put back on the redirect. Hidden fields plus explicit redirect parameters keep the whole
mechanism visible in the request, consistent with the Assumption that the selections live in the page
address and nowhere else.

**Alternatives considered**:

- *Store the selections in the session*. Contradicts that Assumption, and would make the filter
  sticky in ways the spec says it must not be (opening the screen fresh shows every wish).
- *`redirect_back fallback_location:`*. Depends on a `Referer` header that proxies and privacy
  settings strip, so the guarantee would be best-effort — and FR-019 states it as a MUST.

**Parameter hygiene**: the two filter values are read separately from `locker_wish_params`, which
stays `params.expect(locker_wish: [ :floor ])`. Nothing about this feature widens what the wish
record itself will accept.

**Found during implementation — where the hidden fields have to live.** Putting them inside the two
forms does not work. Those forms are in the declare panel, which sits *outside* the frame precisely so
a filter change never re-draws it (FR-009) — so fields inside them keep whatever was in force when the
page first loaded, and the first filter change makes them stale. The fields therefore live inside the
frame, where every filter change refreshes them, and attach themselves to the two forms by id using
the HTML `form` attribute. The form ids are constants on `LockerWishesController` so the two ends
cannot drift. This is still declarative: no JavaScript, and no duplicated state.

The failure mode was caught by the FR-019 system tests, which went red on exactly this: the filter was
in force on screen, and the redirect came back unfiltered.

---

## R6 — A selection in force that no wish carries

**Decision**: Build each axis's choice list from the derived floors, then, if the selection in force is
not among them, append it as an extra choice marked as current.

**Rationale**: This is the contradiction the clarify pass caught. FR-015 says the selection must stay
visible in its control; FR-004/FR-005 say the control offers exactly the floors present among active
wishes. Both hold once the in-force selection is appended when missing: the floor is no longer offered
to anyone choosing afresh, but the viewer who is on it can still see what they are filtered on and
click away from it. The same mechanism covers FR-020 — a junk value from the address renders as the
current selection over an empty list, with "All floors" one activation away, rather than as an error
or a silent reset to the full list.

**Escaping**: the value is echoed back into the page from the query string, so it is rendered through
ERB's default escaping like any other floor value. No `raw`/`html_safe` anywhere in the filter bar.

**Alternatives considered**:

- *Drop an unknown selection and show the full list*. Explicitly forbidden by FR-020 — it would hide
  from the viewer that a filter was ever applied.
- *Redirect to the unfiltered URL when the value matches nothing*. Same objection, and it would
  silently rewrite a shared link.

---

## R7 — Test strategy

**Decision**: Split the evidence across the three levels this repo already uses, following the
precedent in `test/controllers/locker_wishes_controller_test.rb` that anything the browser suite
cannot hold still goes to the integration suite.

| Level | What it covers |
|---|---|
| `test/models/floor_filter_test.rb` (new) | FR-007 ordering including the `3`/`03` tie and non-numeric grouping; FR-015/FR-020 appending an in-force selection that is absent. Pure Ruby, no database. |
| `test/models/locker_wish_test.rb` | The three scopes and the two choice queries: FR-010, FR-011, FR-012 (people with no saved floor), and that choices come from the unfiltered set (FR-006). |
| `test/controllers/locker_wishes_controller_test.rb` | Parameter handling including blank-as-unfiltered; FR-020 junk values; FR-019 selections surviving both the declare and the cancel redirect, and a rejected declare; the Principle IV query-count comparison. |
| `test/system/locker_wish_filter_test.rb` (new) | User Stories 1–4 in the browser: the frame updating in place with the panel and scroll position untouched (FR-009), FR-008's keyboard rule, both empty states (FR-016), and back/forward over filter changes (FR-018). |
| `test/system/accessibility_test.rb` | axe-core clean on a filtered list and on the no-match state; the two `aria-label`led groups and `aria-current` (FR-021, SC-008). |
| `test/system/responsive_test.rb` | The filter bar wraps at narrow width with no sideways scroll (FR-023), against the site's single 48rem breakpoint. |

**Fixtures**: `users.yml` and `locker_wishes.yml` gain enough rows to make the ordering rule
observable — at least one floor that sorts differently as a string than as a number (`10` against `3`
and `5`), and one account with no saved floor so FR-012 has a subject. Existing fixtures are added to,
not renumbered, so the suites that depend on them keep passing.

**Failing-first**: every item above fails before the change and passes after it, per Principle II.
The one exception is `test/system/locker_wish_test.rb`, which must keep passing untouched — that is
the evidence for FR-013 and FR-014, that nothing about the existing screen changed.
