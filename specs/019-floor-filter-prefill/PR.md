# 019 — Pre-fill "Their floor" filter from the viewer's own wish

The **Their floor** filter (017) on the **Locker wishes** screen now tracks your
own active wish instead of always starting on "All floors." Declare a wish for
floor `5` and the filter — and the list below it — is already narrowed to
floor `5`, without touching the filter yourself. Change your wish's floor and
it updates immediately; cancel your wish and it resets to "All floors."

No migration, no new table, no new column, no new route, no new Turbo Frame or
Stimulus controller. The existing `#locker-wish-list` frame, its link-based
filter bar, and its redirect-carries-the-filters pattern (017) are all reused
unchanged in shape.

## What changes for users

The moment you declare or change your wish, **Their floor** is set to that
same floor and the list narrows to it — one action instead of declare-then-
filter. That stays true on any later visit while the wish is still active:
opening the screen fresh, or simply reloading it, shows the same narrowed
list with no interaction needed.

If you manually change **Their floor** yourself during a visit, that choice
holds — through other clicks, through Back and Forward — until you next
leave and come back, or until you declare, change, or cancel your wish.
Cancelling puts the filter back on "All floors" immediately, and it stays
there on any later visit, since there is no longer a wish to derive it from.

**Looking for floor** (017's other filter) is untouched by any of this.

## Core Principles

**I. Code Quality.** One controller method,
`LockerWishesController#current_floor_selection`, is the single place the
derivation rule is decided — called once, from `build_floor_filters`; `#create`
and `#destroy` each state their own explicit override/drop inline rather than
re-deriving. `FloorFilter` needed no change at all: its existing `.presence`
handling of a blank selection already covers the one new value shape
(`current_floor=""`) this feature introduces. The one deliberate asymmetry —
`current_floor` and `looking_for` are no longer handled identically — is
inherent to the requirement (nothing asks `looking_for` to track anything) and
is documented in `plan.md`'s Constitution Check rather than left implicit.
RuboCop: 84 files, no offenses.

**II. Testing Standards.** Controller tests cover the derivation rule directly
(fresh entry with/without an active wish, an explicit value — including a
deliberate blank one — always winning over the wish, a rejected declare
leaving the filter untouched, and that the derivation reads only the signed-in
viewer's own wish, never another active wish present in the same fixture set).
System tests cover the full interaction shape in the browser: a manual choice
holding across an unrelated interaction and across Back/Forward, then being
discarded by a genuine reload; a wish's floor change overriding a manual
choice; a rejected change leaving it alone; the no-match state when the
pre-filled floor matches nobody; and that "Looking for floor" is never touched
by any of it. Two existing 017 controller tests, and three more this feature's
own redirect change reaches, were rewritten on purpose (not regressed) — see
below. A query-count assertion (Principle IV) confirms the derivation adds no
query.

**III. User Experience Consistency.** No new visual component or interaction
pattern — the same filter bar and links 017 shipped, now sometimes pre-selected
rather than always starting on "All floors." One behaviour change a user could
notice, called out explicitly rather than left to be discovered: a bookmarked
or shared link that already encodes `current_floor` is indistinguishable, at
the request level, from resuming a visit via Back/Forward, and reproduces its
value rather than being overridden by an active wish — the trade-off that
keeps this screen's filter state living entirely in the page address, with no
new session or account-level storage (`research.md` R1).

**IV. Performance Requirements.** Zero queries added. `current_floor_selection`
reads `current_user.locker_wish`, an association already loaded by
`own_locker_wish` on every path that reaches it. Asserted directly in the
controller test: a request for a viewer with an active wish issues no more
queries than one for a viewer without.

## Two things the process caught that would have been costly later

- **The literal spec edge case ("reopening a bookmarked link overrides to the
  wish's floor") isn't quite what got built.** Distinguishing "the viewer went
  Back/Forward to a state from earlier this visit" from "the viewer opened a
  bookmarked link that happens to encode the same value" turns out to be
  impossible from the request alone — both are byte-identical HTTP requests.
  017's own research already measured Turbo's native Back/Forward restoration
  hitting the server as a genuine full-page visit "roughly two runs in five,"
  which rules out the obvious `Turbo-Frame`-header-based approach too. Resolved
  in favour of Back/Forward — the common case, and what the spec's own
  Assumptions section treats as expected — with the bookmark scenario as a
  named, accepted trade-off (`research.md` R1) rather than a silent deviation.
- **Auto-filtering broke 18 tests across six files that were never about this
  feature.** `carol` and `karl` — both fixture users with an active wish whose
  floor matches nobody (or, for `karl`, matches nobody *including himself*,
  since 017 already excludes anyone with no saved current floor once a
  specific one is in force) — turned out to be used across
  `locker_swap_proposal_test.rb`, `responsive_test.rb`, `locker_wish_test.rb`,
  `accessibility_test.rb`, and `motion_test.rb` as "just some signed-in user"
  for tests asserting on the *unfiltered* list. Auto-deriving "Their floor"
  from their wish narrowed or emptied the list out from under those
  assertions. Fixed by pinning `current_floor: ""` on the specific affected
  request in each test — the same pattern `locker_wish_filter_test.rb`
  already used deliberately for `dave` (017 R-note: he holds no wish, so he's
  the one safe "neutral" viewer). Full findings in `research.md` R6.

## Not done

`quickstart.md` section-by-section manual validation was not performed by
hand; the same scenarios are covered by `locker_wishes_controller_test.rb`
and `locker_wish_filter_test.rb`, including the Back/Forward step. Worth a
few minutes in a browser before merge, per `tasks.md` T016.

This environment carries a pre-existing, systemic Capybara/Selenium flake —
roughly 1 test in 20–30 per `bin/rails test:system` run fails because a
click's effect is read a moment before it has settled, on a different random
test each time. Confirmed via `git stash` to occur at the same rate on the
unmodified 017 test file, and independently documented by 018's own PR
(`specs/018-wishes-match-tag/PR.md`) as unrelated to that feature either —
predates both, environmental, worth investigating separately from this PR.
