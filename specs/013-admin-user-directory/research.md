# Phase 0 Research: Admin Role and User Directory

All Technical Context items were resolvable from the existing codebase and constitution; no
[NEEDS CLARIFICATION] markers remain. This document records the decisions that shaped the design in
`data-model.md`, `contracts/`, and `quickstart.md`.

## R1 — How "the first account" is decided and kept immutable

**Decision**: Persist a plain `admin:boolean` column on `users`, set once by a `before_create`
callback that checks whether any account already exists (`User.count.zero?` at the moment the new
record is being created). Once set, nothing in this feature ever changes it again — there is no
update path, and it is left out of every controller's permitted params.

**Rationale**: FR-002 and FR-011 both require that admin status never move to a different account,
including after the original administrator account is deleted. A *computed* answer (e.g., "whoever
has the lowest `id` right now") would silently reassign the role the moment the original admin's row
disappeared — exactly the behavior FR-011 forbids. A *stored* boolean, set once, does the opposite:
deleting that row just removes the only `true` value there ever was, with nothing left to "become"
first. This mirrors how the app already treats other one-time facts (e.g., `requester_floor_at_resolution`
on `LockerSwapProposal`, frozen at the moment it happens rather than re-derived later).

**Alternatives considered**:
- *Compute from `MIN(users.id)` or `MIN(created_at)` on every request*: rejected — reassigns on
  deletion, which is the one thing FR-011 rules out; also an extra query on every request needing to
  know the viewer's role, rather than a column already loaded with the record.
- *A separate `roles` join table*: rejected as needless generality — the spec (Assumptions) is
  explicit that there is exactly one administrator and no promotion mechanism; a single boolean says
  exactly that and nothing more, matching the Code Quality principle's "no unjustified complexity."

## R2 — Race safety when two people sign up at the same moment

**Decision**: Back the `before_create` check with a partial unique index —
`add_index :users, :admin, unique: true, where: "admin = 1"` (or `true` on the SQLite boolean
representation actually in use) — and rescue `ActiveRecord::RecordNotUnique` in the model by falling
back to `admin = false` for the loser of the race, then retrying the save once.

**Rationale**: `User.count.zero?` read by two simultaneous signups can both observe zero accounts and
both attempt to save as admin. The app already solves the identical shape of problem twice — the
`(floor, locker_number)` uniqueness in `User` and the pending-proposal pair uniqueness in
`LockerSwapProposal` are both enforced by a database index first, with the controller/model layer
catching the race and resolving it, never by trusting the pre-check alone. Reusing that exact pattern
here (an index as the real guarantee, a rescue as the resolution) is the smallest, most consistent way
to make FR-001 ("the sole administrator") hold even under concurrent signups, per the Edge Cases
section of the spec.

**Alternatives considered**:
- *Database transaction with `SELECT ... FOR UPDATE`*: rejected — SQLite does not support row locking
  the way a client/server database would, and the rest of the app already avoids relying on it,
  solving the same class of race with a unique index instead.
- *Accept the small race window with no index*: rejected — two administrators (or, transiently, zero)
  is exactly the "serious access control failure" the spec's Story 1 rationale calls out.

## R3 — Enforcing "admin-only" at the request level, not just hiding the link

**Decision**: `Admin::UsersController` gets its own `before_action :authenticate_user!` (unchanged
Devise behavior for anonymous visitors — redirected to the login page) followed by a
`before_action :require_admin!`, defined once on `ApplicationController` as a protected method, that
redirects a signed-in non-admin to the homepage with a flash `:alert`.

**Rationale**: FR-008 and the spec's own Assumptions are explicit that hiding the nav entry is a
display convenience, not the security boundary. The flash `:alert` reuses the existing toast
notification component (007) rather than inventing a new "access denied" page — consistent with User
Experience Consistency (III), which asks that user-facing messages reuse existing components. Placing
`require_admin!` on `ApplicationController` (unused by every other controller today) keeps it
available for any future admin-only destination without every future feature re-deriving it.

**Alternatives considered**:
- *Render a 404* instead of redirecting: considered for "don't reveal the feature exists," but
  rejected as inconsistent with how the rest of the app already handles unauthorized access to
  signed-in-only content (a clear redirect with an explanation, e.g. the generic login failure
  message in 001) rather than pretending the route does not exist.
- *A `Pundit`/`CanCanCan` authorization gem*: rejected — a single boolean and a single guard method is
  the entire authorization surface this feature needs; adding a policy-object gem for one check is the
  kind of unjustified complexity Code Quality (I) asks reviewers to push back on.

## R4 — Fitting "Admin → Users" into the existing navigation

**Decision**: Add a nested `<details>` disclosure inside `shared/_site_menu_items.html.erb`, rendered
only when `current_user.admin?`, with `<summary>Admin</summary>` and a single `Users` link inside it —
reusing the exact disclosure mechanism the site already uses four times over (008/009's locker editor,
003's wish panel, 005's decline form, 012's own site menu), rather than introducing a new expand/collapse
pattern.

**Rationale**: The feature request asks specifically for a menu with a submenu, not a single link —
and the site already has exactly one accessible, scripted-or-not disclosure pattern for "reveal more
navigation on demand." Because `_site_menu_items` is the single partial rendered into both the narrow
and wide containers (012 R1), the nested disclosure automatically gets both treatments for free with
no extra markup path to keep in sync.

**Alternatives considered**:
- *A flat second link, e.g. "Admin users"*: rejected — does not match what was asked for (an "Admin"
  menu containing a "Users" submenu), and stops being able to hold a second admin destination later
  without renaming it.
- *A dropdown built from scratch with Stimulus*: rejected — the site's stated reason for choosing
  `<details>` for its own menu (native keyboard operation and expanded/collapsed announcement with no
  script required) applies just as well one level down; duplicating that behavior in JavaScript would
  be the unjustified complexity Code Quality (I) flags.

## R5 — Keeping the Users listing within Performance Requirements (IV) without a new dependency

**Decision**: `Admin::UsersController#index` runs a single `User.order(:created_at)` query (no
per-row queries — the "Admin" label is derived from the already-loaded `admin` column, not a second
lookup). No pagination gem is added in this pass; the deferral is recorded explicitly in `plan.md`'s
Constitution Check and in the spec's Assumptions, per the Governance section's requirement that a
Performance-gate exception be written down rather than silently skipped.

**Rationale**: The list is for a single company's employees — bounded in practice, not the
open-ended, ever-growing dataset Principle IV's swap/lock examples are guarding against. Adding a
pagination gem (Kaminari, Pagy) for a list this small, on a page whose only reader is the one
administrator account, is complexity the feature does not need yet; the constitution's own escape
hatch ("a gate MAY only be bypassed with an explicit, written exception") is used deliberately here
rather than ignored.

**Alternatives considered**:
- *Add Kaminari/Pagy now*: rejected for this pass — no `package.json`/extra JS tooling either, and the
  app already avoids adding dependencies it does not yet need (e.g., no Node for Tailwind).
- *Manual `limit`/`offset` pagination with no gem*: viable and cheap if the account count ever
  actually becomes a problem; left as the documented fallback rather than built pre-emptively.

## R6 — Fixtures and the `before_create` bootstrap

**Decision**: Rails fixtures are inserted directly into the database and do not run Active Record
callbacks. The test fixture intended to represent the administrator (`test/fixtures/users.yml`) must
set `admin: true` explicitly in the YAML rather than relying on being "the first row loaded."

**Rationale**: Without this, no fixture-backed test would ever see `current_user.admin?` return
true, since `before_create` never fires for fixture data — silently making every admin-only test
either untestable or accidentally passing for the wrong reason (e.g., testing against `nil`/`false`
for everyone). This is purely a test-authoring fact, not a production behavior change.
