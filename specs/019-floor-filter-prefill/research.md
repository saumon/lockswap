# Phase 0 Research: Pre-fill "Their Floor" filter from the viewer's wish

**Feature**: [spec.md](./spec.md) | **Branch**: `019-floor-filter-prefill` | **Date**: 2026-09-19

No `NEEDS CLARIFICATION` markers survived `/speckit-specify` and `/speckit-clarify`, so this document
resolves the remaining *technical* unknowns — chiefly, how to tell a "fresh screen entry" (FR-001,
FR-002) apart from an in-visit filter interaction (FR-008, FR-009) using only what a Rails request
actually carries, since 017 already committed this screen to keeping all filter state in the page
address and nowhere else (no session, no per-account storage).

---

## R1 — Telling a fresh screen entry apart from an in-visit interaction

**Decision**: Use the presence of the `current_floor` key in the query string, not the request's
transport. A request with no `current_floor` key at all is a fresh screen entry — the filter is
derived from `current_user.locker_wish&.saved_floor` (FR-001/FR-002). A request that includes the key,
with any value including an empty one, is treated as already decided for this visit and is respected
exactly as it arrives (FR-008). Every link this feature's axis renders explicitly includes the key from
that point on — an empty string for "All floors" rather than omitting it — so a single click makes the
choice durable for the rest of the visit, through subsequent clicks on either axis and through
browser Back/Forward.

**Rationale**: The obvious first idea — check `turbo_frame_request?` (present, built into turbo-rails;
true when the `Turbo-Frame` request header is set) and treat a frame-scoped request as "in-visit" and
everything else as "fresh" — does not hold up against 017's own research. R1 of 017's research.md
measured Turbo's own Back/Forward restoration visit hitting the server as a genuine full-page
navigation (no `Turbo-Frame` header) "roughly two runs in five," which is exactly why
`frame_history_controller.js` exists at all: to force the *other* three-in-five back onto a frame-scoped
fetch. A signal that is right only 60% of the time for precisely the case this feature must get right —
Back/Forward preserving what the viewer already chose — is not usable. The query string itself does
not have this problem: whichever way Turbo restores a given history entry, it restores the *same URL*,
and that URL already carries whatever the viewer decided the last time they interacted with this axis
during the visit, because every choice this feature's filter offers is written into the address the
moment it is clicked (see R3 for why the empty-string encoding is required to make that true for "All
floors" specifically, not just for a named floor).

**Alternatives considered**:

- *`turbo_frame_request?` / the `Turbo-Frame` header*. Rejected — see above; the measured ~40%
  false-fresh rate on Back/Forward would intermittently overwrite a viewer's manual choice with their
  wish's floor mid-visit, which is exactly what FR-008/FR-009 rule out.
- *`Referer`*. 017's own R5 already rejected this for FR-019 ("best-effort... proxies and privacy
  settings strip it"), and it fails here for an additional reason: Turbo's own fetch-based restoration
  and this feature's in-visit interactions would both send a self-referential `Referer` (the previous
  `/locker_wishes?...` view), indistinguishable from one another, while a plain browser refresh's
  `Referer` behaviour varies by browser — no more reliable than it was for 017.
- *A session-stored "have they touched this filter" flag*. Would reliably distinguish a same-session
  Back/Forward from a brand-new browser session opening a bookmarked link — the one case the query-
  string-only approach cannot resolve, see the Known Limitation below — but it reintroduces exactly what
  017's Assumptions section rules out ("selections live in the page address and nowhere else... not
  stored against the account"), for one axis only. Rejected as disproportionate: it would make this
  screen's persistence model inconsistent with itself for the sake of one edge case that is already an
  edge case of an edge case (a bookmark of a specific manual filter value, reopened while the wish that
  value happens to differ from is still active).

**Known limitation, accepted**: A request that carries `current_floor` explicitly is indistinguishable,
at the HTTP layer, between "the viewer went Back/Forward to a state they set earlier this visit" and "the
viewer opened a bookmarked or shared link that happens to encode the same parameter" — both are, byte
for byte, the same GET request. This plan resolves that ambiguity in favour of Back/Forward, which the
spec's Assumptions and Edge Cases sections treat as the common, expected interaction; the bookmarked-link
case is the one scenario in the spec's Edge Cases where this plan's behaviour is an approximation rather
than an exact implementation of the literal wording ("reopening it is a fresh screen entry, so 'Their
Floor' is set to the active wish's floor rather than reproducing the bookmarked value") — in practice, a
bookmarked link that already encodes `current_floor` will reproduce that value instead of being
overridden, the same as a Back/Forward visit would. Flagged here rather than silently implemented, so it
can be confirmed or traded off before `/speckit-tasks`.

---

## R2 — Where the derived floor comes from, at zero added queries

**Decision**: `current_user.locker_wish&.saved_floor`, read at the point `LockerWishesController` already
has `current_user.locker_wish` loaded.

**Rationale**: `index` already calls `own_locker_wish` (`current_user.locker_wish ||
current_user.build_locker_wish`) before building the floor filters, and a rejected `create` reaches the
same `load_wish_list` call after already having done the same lookup at the top of `#create`. Either
way, `current_user.locker_wish` is a cached association read by the time the derivation runs — this
mirrors exactly how 018 read `current_user.locker_wish&.saved_floor` for the match-tag comparison
(research R1 there) for the identical reason: it is already in memory, and `saved_floor` (`floor_in_database`) is what
must be read rather than `floor`, so a rejected edit's unsaved input is never mistaken for what the
filter should show. `destroy` does not render `:index` at all — it only redirects — so no read happens
there beyond the one used to build the redirect target (R3).

**Query budget**: zero added queries on every path. Confirmed the same way 017 and 018 did: a
controller-test assertion that the index issues no more queries with an active wish present than
without.

---

## R3 — Threading the derived value through the create and cancel redirects

**Decision**: `#create`'s success redirect explicitly sets `current_floor` to the just-saved wish's
floor (`@locker_wish.saved_floor`), overwriting whatever arrived in the request. `#destroy`'s redirect
drops `current_floor` from what it carries forward (`.except(:current_floor)`) rather than setting it to
anything.

**Rationale**: FR-003/FR-004 are stated as immediate effects of the declare/change and cancel actions,
not effects that should wait for R1's general "no key present" rule to kick in on the next unrelated
request. Setting it explicitly on `#create`'s redirect means the resulting address already reflects the
new floor (FR-011) in the same round trip, and does so regardless of whatever `current_floor` value the
viewer had chosen manually before declaring — satisfying "replacing any value it held before... including
one the viewer had set manually" directly, rather than depending on R1's key-presence rule to happen to
produce the right answer. `#destroy` does not need the symmetrical explicit-blank treatment
(`current_floor: ""`): once the wish is gone, R1's own fallback (`current_user.locker_wish&.saved_floor`
on a nil wish) already evaluates to "All floors" the moment the redirect's bare address is requested, so
explicitly encoding blank would be redundant — and dropping the key instead keeps an existing 017 test
passing unchanged (`"cancelling a wish returns to the list still filtered"`, which asserts the redirect
carries only `looking_for`).

**Existing tests this changes on purpose**: two of 017's controller tests assert the *previous* meaning
of "the filters survive the redirect" for this specific axis, and now assert the opposite by design:

- `"declaring a wish returns to the list still filtered"` — currently asserts a declare with
  `current_floor: "2"` in force redirects still carrying `current_floor: "2"`; after this feature, a
  declare for floor `"4"` must redirect carrying `current_floor: "4"` instead (FR-003).
- `"declaring with no filter in force redirects to the bare list"` — currently asserts a bare declare
  redirects to the bare path; after this feature it cannot, since any successful declare now sets
  `current_floor` to the declared floor. The test's *point* — that an axis nobody touched is not sent as
  an empty parameter — still holds for `looking_for`; it needs restating in terms of that axis only.

Neither change is a regression: both are the literal behaviour this feature was asked for, restated as
tests. Left for `/speckit-tasks` to convert into concrete failing-first edits.

**Alternatives considered**:

- *Let R1's general rule handle `#create`/`#destroy` too, by simply not carrying `current_floor` forward
  on either redirect*. Works for `#destroy` (already the choice made above) but not for `#create`: the
  redirect's bare address would have no `current_floor` key, so R1 would derive it from the now-current
  wish anyway — same *displayed* result, but the address would not visibly reflect the just-made choice
  (FR-011), and a viewer who then manually cleared the filter and came back to this exact address later
  would see a different, confusing history: "no key" reproducing today's wish rather than "no filter was
  ever chosen."

---

## R4 — The hidden field for `current_floor` has to stop being conditional

**Decision**: `_locker_wish_list.html.erb`'s hidden-field injection (the fields that carry the filters
into the declare/cancel forms, which live outside the frame per 017 R5) renders the `current_floor`
field unconditionally. The `looking_for` field keeps its existing `next unless filter.filtering?` guard.

**Rationale**: A rejected declare re-renders `:index` directly from the submitted POST params, not from
a redirect — so FR-006 ("if declaring or changing the wish fails... 'Their Floor' filter MUST NOT be
changed") depends on `params.key?(:current_floor)` being true whenever the viewer had explicitly set
this axis, including to "All floors." Under 017's original guard (`next unless filter.filtering?`), the
hidden field was omitted precisely when the axis was "All floors" — meaning a viewer who had manually
cleared "Their Floor," then submitted a declare that got rejected, would resubmit with no
`current_floor` key at all, and R1 would incorrectly derive it fresh from the wish rather than leave the
manual "All floors" alone. Removing the guard for this one axis closes that gap. `looking_for` has no
such dependency — it is never derived from anything, so an absent key there still means exactly what it
always has.

**Consequence for `locker_wish_filter_path`**: the helper's own link generation is the other place that
must stop dropping a blank `current_floor` — `Rails.application.routes.url_helpers` drops a `nil` query
value from the generated path entirely but keeps an explicit `""` as `current_floor=` (confirmed with
`rails runner`), so the fix is to pass `nil` for a blank `looking_for` (unchanged, dropped) and `""` for
a blank `current_floor` (new, kept) rather than `compact_blank`-ing the whole selections hash as today.

---

## R5 — Test strategy

**Decision**: Extend the same three levels 017 and 018 used; add no new level and no new fixture files
beyond rows already present.

| Level | What it covers |
|---|---|
| `test/controllers/locker_wishes_controller_test.rb` | R1's key-presence rule for a fresh GET with/without an active wish; a GET carrying an explicit (including blank) `current_floor` is respected unchanged; `#create` redirects with `current_floor` set to the new floor, overwriting a prior manual value; `#destroy` redirects with `current_floor` dropped; a rejected declare preserves whatever `current_floor` was submitted; the two existing tests named in R3 updated to their new, intentional assertions; a query-count assertion for Principle IV. |
| `test/system/locker_wish_filter_test.rb` | Story 1: declaring a wish narrows "Everyone looking for a locker" to that floor without touching the filter; a fresh reload of the screen while the wish is still active shows the same narrowed list without interaction (SC-005); a manual change to "Their Floor" during the visit holds across a subsequent, unrelated interaction (changing "Looking for floor") and across Back/Forward, per R1. Story 2: cancelling resets the filter and a subsequent reload keeps it reset. |
| `test/system/accessibility_test.rb` | axe-core stays clean on a list narrowed by this feature's auto-set selection — no new markup is introduced, so this is a regression check rather than new coverage. |

No new fixtures are required: `users.yml`/`locker_wishes.yml` already carry enough distinct floors
(from 017) and a fixture user with no saved floor to exercise the "no active wish" branch of R1.

**Failing-first**: every item above fails before the change and passes after it, per Principle II. The
two 017 tests identified in R3 are edited in place to their new, correct assertions rather than left
red — they are not being "fixed" so much as restated for what this feature deliberately changes.

---

## R6 — Found during implementation: fixture users as an implicit "unfiltered" assumption

**What happened**: T004 (running the two files this plan named) passed cleanly, as predicted. Running
the *full* suite afterward — a step this plan's own test strategy above did not call for, and which
`tasks.md` T004 did not ask for either — surfaced 15 failures across five files this feature's research
never named: `locker_swap_proposal_test.rb`, `responsive_test.rb` (×3), `locker_wish_test.rb` (×3),
`accessibility_test.rb` (×3), and `motion_test.rb`.

**Root cause**: `carol` (wish floor `"5"`, current floor `"2"`) and `karl` (wish floor `"3"`, no saved
current floor) are both used across the suite as "just some signed-in user" for tests that have nothing
to do with floor filtering — responsive breakpoints, accessibility audits, swap-proposal eligibility,
motion/transition timing. Every one of those tests calls `visit`/`get locker_wishes_path` with no
`current_floor` param and asserts on the *unfiltered* list. Before this feature, that always produced
"All floors." After R1's derivation lands, the same bare request now auto-fills "Their floor" to that
viewer's own wish floor — which, for `carol`, matches nobody's current floor at all (the list goes
empty), and for `karl`, excludes even *himself* (017 FR-012 already hides anyone with no saved current
floor once a specific one is in force, and `karl` is exactly that person).

**Why this wasn't caught in planning**: `research.md`'s own test strategy (R5, above) only named the two
files this feature adds coverage to. `locker_wish_filter_test.rb`'s file-level comment already documents
that `dave` was deliberately chosen there *because* he holds no wish — the same reasoning was not carried
through to the other four files, which were written under 017/018 and had no reason to think about a
viewer's *own* wish affecting what filter is in force when the address doesn't name one.

**Resolution**: pinned `current_floor: ""` explicitly on the specific `visit`/`get` call in each of the
15 affected tests, restoring the exact pre-019 "All floors" starting point for tests that were never
about this feature's own behaviour — the same pattern already used deliberately in
`locker_wish_filter_test.rb` for `dave`. No fixture data changed; no test's actual assertions changed
beyond that one added parameter (plus, for two tests, moving a filter-reset earlier so it takes effect
before the first assertion rather than after). One further failure, in `navigation_test.rb`, was
confirmed via `git stash` to fail identically against unmodified `dev` — a pre-existing flake unrelated
to this feature, left untouched.

**Lesson for the next feature that changes a default**: when a change makes an *existing* default
conditional on a viewer's own data, `bin/rails test:system` on the full suite is not optional even when
a plan's own test strategy names only the files it expects to touch — grep the fixture files for which
users are already "spoken for" by an existing behavioural assumption (`dave` = no wish, `alice` =
nothing on file at all) before assuming an arbitrary other fixture user is safe to reuse as a neutral
"just sign in as someone" viewer.

**Addendum, found again during T014**: the same pattern recurred in `test/system/accessibility_test.rb`,
missed by the sweep above because that file's `assert_axe_clean` calls kept passing regardless — the
no-match state this feature silently substituted for the populated one three tests expected is, itself,
already accessible, so nothing *failed*; three tests just quietly stopped checking what their names say
they check. `assert_axe_clean` passing is necessary but not sufficient evidence that a test still
exercises its intended state — worth an explicit `assert_selector` on actual row content, not just the
axe pass, whenever a test's fixture user carries an active wish.

**Second addendum, found during T008/verification**: this environment carries a separate, pre-existing
Capybara/Selenium flake — roughly 1 test in 20–30 per `bin/rails test:system` run fails because a
click's effect (an `aria-current` update, a filled-in field) is read before it has settled, on a
*different* random test each run. Confirmed via `git stash` to occur at the same rate on the unmodified
017 test file, so it predates this feature and is environmental, not a code defect. The one place this
feature's own new tests were more exposed to it than 017's own tests: `current_choice(group)` (a bare
`find(...).text`, no retry-until-match) versus `assert_current_choice(group, floor)` (retries until the
text matches). Every post-mutation assertion added by this feature uses the latter; a bare `current_choice`
equality check is safe only immediately after `choose`, whose own internal `assert_current_choice` has
already waited.
