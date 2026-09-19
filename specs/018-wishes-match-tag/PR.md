# 018 — "It's a match!" tag on locker wishes

A badge on the **Locker wishes** list: a row is tagged **It's a match!** when that
row's person is on the floor you want, *and* that same person wants the floor you
are currently on — the one kind of swap guaranteed to work both ways.

No migration, no new table, no new column, no new route. The tag is computed fresh
on every render from two floor values that already exist on each side.

## What changes for users

Nothing about the list's shape, order, or filtering changes. A row that reciprocates
with your own current-floor/wanted-floor pair now shows **It's a match!** in the
same Swap column that already carries "Proposal pending", "This is you," and the
"Propose swap" button — alongside whichever of those already applies, never in
place of it.

The tag never appears:

- on any row, if you have not declared a wish of your own, or your own current
  floor is not on file — there is nothing of yours to reciprocate;
- on a row whose person has no saved floor ("Not set");
- on your own row, even in the edge case where your current and wanted floor
  happen to be the same value.

It survives the existing floor filters unchanged, and disappears again the moment
either side's wish or floor changes — nothing about a match is remembered between
renders.

## Core Principles

**I. Code Quality.** The reciprocity rule is one predicate,
`LockerWish#reciprocal_match?(viewer_current_floor, viewer_wish_floor)`, colocated
with the `saved_floor` accessor it depends on. It takes the viewer's two floors as
plain arguments rather than a `User` object, so `LockerWish` needs no new knowledge
of `User` beyond what it already reads for display. The controller gains two lines
in `load_wish_list`, following the exact shape `@viewer_in_progress`/
`@pending_recipient_ids` already use. The view adds one conditional; every
comparison is delegated to the model. RuboCop: 84 files, no offenses.

**II. Testing Standards.** Model tests cover both directions of the predicate,
each one-sided near-miss, every blank-floor case, and exact (non-normalized) string
equality. Controller tests cover presence on both of two simultaneously-matching
rows, absence in every FR-003/004/005/006 case, survival under a floor filter, and
a cancel-then-reload check that the tag is recomputed fresh rather than
remembered. A system test confirms the visible text renders and coexists with
"Proposal pending" rather than replacing it. `accessibility_test.rb` gains an
axe-core pass on a list containing the badge, with no new exemption.
`locker_wish_test.rb`'s and `locker_wish_filter_test.rb`'s pre-existing tests
needed updating for the two new fixtures (see below) but are otherwise unedited —
standing evidence this feature doesn't change what was already there.

**III. User Experience Consistency.** The tag reuses `.badge`/`.badge-success`
verbatim — the same component already used for other row-level status text — and
introduces no new visual pattern or CSS. Its placement (inside the Swap column,
alongside the cell's existing content) was settled in the spec's Clarifications
session rather than invented during implementation.

**IV. Performance Requirements.** No query is added. The viewer's own two floors
are attribute reads on associations `#index` already loads (`current_user` via
Devise, `current_user.locker_wish` via the existing `own_locker_wish`); each row's
comparison reads attributes already present from `LockerWish.active`'s existing
`includes(:user)`. Asserted in `locker_wishes_controller_test.rb`: a render with
matches present issues the same number of queries as a render with none.

## Two things the process caught that would have been costly later

- **The planned test fixture already existed, for something else.**
  `/speckit-analyze` (and a re-check while writing the remediation) found that
  `research.md`'s original choice of fixture name — `erin` — collided with an
  existing fixture used by feature 010's homepage test (`floor: "5"`, no locker, no
  wish). Reusing her would have either failed fixture loading outright or silently
  broken that unrelated test. Renamed to `henry`/`iris` before any test was
  written against the wrong name.
- **A naive query-count comparison would have been flaky, not wrong.** The first
  version of the Principle IV test compared one signed-in viewer's query count
  across two sequential requests (one with a match, one after mutating the wish to
  remove it). That consistently showed a 1-query difference — not from this
  feature, but from an unrelated Warden/session lookup that only fires on a
  *second* request within the same signed-in session. Confirmed with a throwaway
  probe test that dumped the actual SQL from both requests. Rewritten to compare
  two independently-signed-in viewers, each making only their first request, which
  removed the artifact entirely.

## Not done

`quickstart.md` section-by-section manual validation was not performed by hand;
the same scenarios are covered by `locker_wish_test.rb`, `locker_wishes_controller_test.rb`,
and `accessibility_test.rb`. Worth a few minutes in a browser before merge.

Running `bin/rails test:system` repeatedly (5 full runs) surfaced an intermittent,
pre-existing flake in `locker_wish_filter_test.rb`'s shared `assert_current_choice`
helper (017's Turbo-frame filter suite) — a different specific test each time,
always the same async `aria-current` race, unrelated to anything this feature
touches. It passed 100% of the time whenever run in isolation or alongside this
feature's own system tests. Worth investigating separately from this PR.
