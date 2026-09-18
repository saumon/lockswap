# Phase 0 Research: Grant Administrator Rights

**Feature**: [spec.md](./spec.md) | **Branch**: `015-grant-admin-rights` | **Date**: 2026-09-18

Six questions stood between the clarified spec and a design. The first is the one the feature turns
on: the database currently makes a second administrator impossible.

## R1 — Making room for a second administrator without losing the "first account" guarantee

**Decision**: Replace the partial unique index `index_users_on_admin` (`WHERE admin = 1`) with one
scoped to the bootstrap case only: `WHERE admin = 1 AND admin_granted_at IS NULL`.

**Rationale**: 013 shipped a hard guarantee — at most one row may carry `admin` — and `User#save`
depends on it to settle the signup race (013 FR-002, 013 research R2). FR-013 removes the *cap*, but
013's other promise is untouched: the automatic bootstrap must still reach exactly one account, never
two people who happened to sign up on an empty site at the same instant. Dropping the index outright
would take both promises away when only one was asked for.

Scoping the index to rows with no grant timestamp keeps the race-settling constraint exactly where it
was — two simultaneous first signups both compute `admin = true` with `admin_granted_at` still NULL,
and the index rejects the loser, which `User#save` already retries — while leaving granted
administrators (`admin_granted_at` set) entirely outside the constraint, unlimited in number.

The predicate is deliberately `admin_granted_at IS NULL` and not `admin_granted_by_id IS NULL`. The
`by` column nullifies when the granting account is deleted (FR-019); were the index keyed on it, a
granted administrator would silently drift into the bootstrap slot the moment whoever promoted them
cancelled their account, and collide with the real first administrator. The timestamp is never
cleared, so it is the stable answer to "were these rights granted?".

**Alternatives considered**:

- *Drop the index, enforce one bootstrap administrator in Ruby only.* Rejected: the model check reads
  the table before inserting, which is exactly the read-then-write that 013 found insufficient. The
  index is the only thing that actually settles it.
- *Keep the index and make granting a transfer.* Rejected by the Clarifications session: both accounts
  stay administrators.
- *A separate `admin_source` enum column with a partial unique index on it.* Rejected as a third way
  to say what `admin_granted_at IS NULL` already says; FR-017 requires the timestamp regardless, so an
  enum would be a second source of truth to keep in step.

**Consequence for `User#save`**: `ADMINISTRATOR_INDEX_CONFLICT` matches on `users.admin` or
`index_users_on_admin`. Renaming the index to `index_users_on_bootstrap_admin` keeps that comment's
intent (match the index as well as the column, so a change of adapter does not quietly stop working)
but the regex must be updated in the same commit, or the retry silently stops firing and a lost race
becomes a 500 at signup. This is the sharpest edge in the feature.

## R2 — Where the grant action lives

**Decision**: A member action on the existing admin users resource —
`PATCH /admin/users/:id/grant_admin` — handled by a new `#grant_admin` action on
`Admin::UsersController`.

**Rationale**: The repository already has this shape. `locker_swap_proposals` routes `accept`,
`decline` and `confirm` as member `patch` actions rather than folding them into `update` with a status
parameter, precisely so each decision keeps its own authorization and state rules (see routes.rb).
Granting rights is the same kind of named decision. Keeping it on `Admin::UsersController` also keeps
the `before_action :authenticate_user!` / `before_action :require_admin!` pair that already guards the
list (FR-009) covering the write without restating it.

`PATCH` rather than `POST`: the action modifies an existing account rather than creating anything.

**Alternatives considered**:

- *`POST /admin/users/:id/admin` as a nested singular resource.* More orthodox REST, but it reads as
  creating an "admin" thing, and it would need its own controller to stay conventional — new surface
  for one action, against Code Quality's preference for the simpler shape.
- *`PATCH /admin/users/:id` with an `admin=true` parameter.* Rejected: a general update action on
  accounts is exactly what FR-014 says must not exist. A named action cannot be widened by accident.

## R3 — The confirmation, and what it has to say

**Decision**: `button_to` with `data: { confirm: ..., turbo_confirm: ... }`, the same construction the
"Cancel my account" button already uses, with the message naming the account and stating the grant is
permanent.

**Rationale**: Constitution III asks that an established pattern be reused rather than a new one
introduced, and the site has exactly one confirm-before-acting precedent
(`app/views/devise/registrations/edit.html.erb`). The Clarifications session settled that this
confirmation is the only guard (FR-020, no credential re-entry), which raises what the message must
carry: FR-004 requires the account's email address and the fact that the grant cannot be undone.

Both `confirm` and `turbo_confirm` are emitted, mirroring the existing button — `turbo_confirm` is
what Turbo reads, `confirm` is the no-JavaScript fallback.

**Accessibility (FR-015)**: a column of buttons all reading "Grant admin rights" tells a screen reader
nothing about which row it is on, and FR-015 forbids relying on row position. Each button therefore
carries an `aria-label` naming the account, e.g. "Grant administrator rights to bob@example.com". The
dialog itself is `window.confirm`, which is keyboard-operable and announced by assistive technology
for free — the same trade already accepted for account cancellation.

**Alternatives considered**: a bespoke in-page modal (a new interaction pattern, and a new focus-trap
to get right and test); a two-step confirmation page (a second screen for a one-field decision).

## R4 — Refusing the deletion that would leave no administrator (FR-016)

**Decision**: A `before_destroy` guard on `User` that aborts when the account is the last
administrator *and other accounts remain*, surfaced through an override of
`RegistrationsController#destroy` so the refusal reaches the person as a flash message.

**Rationale**: The guard belongs on the model, beside `User`'s other invariants, because it is a fact
about the data and not about one request path. Devise's `destroy` calls `resource.destroy`, so a
`throw :abort` is enough to stop it; the controller override exists only to turn the abort into the
site's existing failure notification (007) rather than a blank redirect.

**On the race** (FR-016, second sentence): a read-then-write inside a transaction is normally not
enough. Here it is, and the reason is worth recording rather than assuming. Active Record 8.1.3 opens
SQLite transactions with `default_transaction_mode: :immediate`
(`activerecord-8.1.3.1/lib/active_record/connection_adapters/sqlite3_adapter.rb:162`, not overridden in
`config/database.yml`), so the write lock is taken at `BEGIN`. SQLite permits one writer at a time,
which serializes the two destroys: the second transaction cannot begin until the first commits, and
its count then sees the first deletion. No advisory lock or extra constraint is needed — but the
guard must run inside the destroy transaction, which `before_destroy` does.

**An ambiguity this uncovered**: FR-016 originally said refuse when the deletion "would leave the
site with no administrator at all". Taken literally, the sole account on a brand-new site could never
be cancelled, since deleting it leaves no administrator. That reading produces a trap rather than a
guard: with no accounts left, 013's bootstrap rule applies again and the very next signup becomes
administrator, so there is nothing to be locked out of. The guard therefore fires only when **other
accounts would remain**, and deleting the last account on the site stays allowed.

This began as a reading the plan imposed on the spec. It is no longer: FR-016, SC-007 and the Edge
Cases list were amended to say it outright, so nothing here interprets a requirement that the spec
states differently.

## R5 — Showing where the rights came from, without an N+1 (FR-018, FR-019)

**Decision**: Extend the existing Role column rather than add a fourth one, and load the grantor with
`includes(:admin_granted_by)` in `Admin::UsersController#index`.

**Rationale**: The table is already three columns and has a responsive card form below the breakpoint
(012 FR-005) driven by `data-label`; a fourth column costs width on every screen to carry a fact that
belongs to the badge already there. The Role cell becomes the badge plus one line of provenance —
"first registration", "granted by bob@example.com on 18 September 2026", or, when the grantor's
account is gone, "granted on 18 September 2026 (account removed)" per FR-019.

Reading `user.admin_granted_by.email` per row inside the existing loop is a query per administrator —
the unbounded per-row query Principle IV names directly. `includes` makes it two queries total,
holding the promise 013's controller comment makes: the page costs the same for three accounts or
three hundred.

**Alternatives considered**: a fourth column (width, and an empty cell on every non-administrator row);
denormalising the grantor's email onto the row (a second copy of an email that account edits can
change, for no gain now that `includes` is one word).

## R6 — Fixtures, and what the new index permits

**Decision**: Add one fixture for a granted administrator, setting `admin`, `admin_granted_at` and
`admin_granted_by_id` explicitly.

**Rationale**: 013 research R6 already recorded that fixtures are inserted straight into the database
and never run `before_create`, which is why `frank` carries `admin: true` literally. The same applies
to the grant columns: nothing derives them at load. Setting `admin_granted_at` is also what keeps the
new fixture outside the bootstrap index — a second fixture with `admin: true` and a NULL timestamp
would collide with `frank` and fail the whole suite at load time, which is a confusing way to discover
the constraint. The new fixture is deliberately not `alice`, for the reason 013 gives: she is signed in
by most of the suite and none of it is about administration.
