# 015 — Grant administrator rights

An administrator can grant administrator rights to a standard account, from a
button on that account's row in the **Admin → Users** screen 013 built. A
confirmation naming the account, and saying the grant cannot be undone, stands
between the button and the change. The promoted account's row then records where
its rights came from.

## What changes for users

For anyone who is not an administrator, nothing: the screen is still refused, and
nothing about their own account changes.

For an administrator, one button per standard row and one extra line on each
administrator row. Two things they could do before, they now cannot:

- **The Users list is no longer read-only.** 013 stated it was (its FR-009), by
  requirement rather than omission. That requirement is superseded and annotated
  in place.
- **The last administrator cannot cancel their account** while other accounts are
  registered. They are told to grant rights to someone else first. The sole
  account on an otherwise empty site can still cancel — see the exception below.

Nothing needs doing on an existing deployment. The migration is additive, and an
instance that already has an administrator keeps exactly the one it has.

## Core Principles

**I. Code Quality.** The grant is a named member action
(`PATCH /admin/users/:id/grant_admin`), matching the shape `locker_swap_proposals`
already uses for `accept`/`decline`/`confirm`, rather than an `update` action
taking a role parameter — which is precisely the general edit capability FR-014
says must not exist. A named action cannot be widened by accident. The grant rule
and the deletion guard sit on `User` beside its other invariants. RuboCop: 72
files, no offenses. Brakeman: 0 warnings. `bundler-audit` and `importmap audit`:
clean.

**II. Testing Standards.** 125 runs / 469 assertions before, **155 runs / 587
assertions** after — 30 new tests, each written before the code it constrains.
The split is deliberate: the refusals, the already-an-administrator no-op and the
vanished-account case are controller tests because no browser can reach them; the
confirmation, the accessible names and the provenance line are system tests
because no request test can see them. See the verification gap below.

**III. User Experience Consistency.** The confirmation is the same
`button_to` + `data-turbo-confirm` construction as the existing "Cancel my
account" button, which was the site's only confirm-before-acting precedent; no
modal was introduced. Success and refusal reuse the 007 notification component.
The promoted row carries 013's `Admin` badge unchanged — rights obtained by grant
are not displayed as lesser rights (FR-008). The accessibility and responsive
sweeps both gained coverage: the new control is audited with the screen, its
accessible name is asserted to name the account rather than rely on row position
(FR-015, which axe cannot check), and the phone-width test now measures the row
carrying the longest provenance line.

**IV. Performance Requirements.** No swap or lock path is touched. The one real
risk was the listing: FR-018 puts the granting administrator's email on every
granted row, which through the association alone is a query per row — the
unbounded per-row query the principle names. `Admin::UsersController#index` loads
it with `includes(:admin_granted_by)`, and a controller test asserts the query
count does not grow when five more granted administrators are added, so the
promise is enforced rather than remembered. 013's deferral of pagination is
inherited unchanged.

## Exception recorded under Governance

**FR-016 deliberately lets one case through.** Read literally, "refuse the
deletion that would leave the site with no administrator at all" also refuses the
sole account on a new site from ever closing itself. That is a trap rather than a
guard: with no accounts left there is nothing to administer, and the next
registration claims the rights again exactly as the first one did (013 FR-001).
The guard therefore checks that accounts would be *left behind*, not merely that
an administrator would be.

This began as a reading the plan imposed on the spec. Rather than ship a
divergence, the spec was amended to state it: FR-016 carries the condition,
SC-007 no longer promises more than the guard delivers, and the Edge Cases list
names the sole-account case. Reasoning in full at `research.md` R4; the behaviour
is pinned by a model test.

## Verification

Both suites pass in full: **155 runs / 587 assertions** for `bin/rails test`, and
**213 runs / 994 assertions** for `bin/rails test:system`.

013's PR recorded that system tests could not run on the development machine, and
this branch's tasks inherited that note. It was stale: Selenium Manager holds a
working Chrome in `~/.cache/selenium` and `libnspr4.so` is installed, which
`test/application_system_test_case.rb` already knows how to resolve. Running them
rather than trusting the note is what caught four defects in the new tests — a
Capybara selector that does not interpolate `?` the way `assert_select` does, and
three races where an assertion read the database while the request it depended on
was still in flight.

One pre-existing flake to be aware of, unrelated to this branch:
`HomepageLockerWishTest#test_the_ask_invitation_leads_to_the_wish_page` failed once
under parallel load and passes in isolation and on every re-run since.

Worth knowing that **`bin/ci` does not run system tests** — that step is commented
out (`config/ci.rb:16`) — so a green `bin/ci` is not by itself evidence for this
branch. `.github/workflows/ci.yml:122` does run them.

## Reviewer's attention is best spent on

**The index, in `db/migrate/20260918113055_add_admin_grant_provenance_to_users.rb`.**
013's partial unique index made a second administrator impossible, and `User#save`
relies on it to settle the race between two people signing up on an empty site.
FR-013 asked for the cap to go, not the guarantee, so the index is narrowed to
`WHERE admin = 1 AND admin_granted_at IS NULL` rather than dropped. Keyed on the
timestamp and not on `admin_granted_by_id` deliberately: the "by" column nullifies
when the grantor is deleted (FR-019), so an index keyed on it would let a granted
administrator drift into the bootstrap slot and collide with the real first
account.

**The retry pattern, in `app/models/user.rb`.** `ADMINISTRATOR_INDEX_CONFLICT` now
names the renamed index. On SQLite this rename is invisible — the message names
the column (`users.admin`) and that branch matches first — so the existing race
test would have passed whether or not the constant was updated. The stale branch
is covered by a test asserting the pattern directly, since no race on this adapter
can reach it.

**Seven existing tests changed**, across four files. All of them encoded the
single-administrator invariant that FR-013 removes — counting `.badge` elements,
asking `find_by(admin: true)` as though it had one answer, or asserting the Users
screen offers nothing to press. Each was narrowed to what it actually meant rather
than deleted; the diff is worth reading for what was *kept*.
