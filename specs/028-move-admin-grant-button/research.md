# Phase 0 Research: Admin Rights Controls on the User Detail Screen

**Feature**: [../spec.md](../spec.md) | **Branch**: `028-move-admin-grant-button`

No item in the spec's Technical Context was left as `NEEDS CLARIFICATION` — every unknown was either
resolved during `/speckit-clarify` or has a reasonable default already established by an existing
feature in this codebase (chiefly 015's grant flow and 027's detail-screen conventions). This document
records the design decisions those defaults imply, so Phase 1 has a fixed shape to build
`data-model.md` and `contracts/` against.

## R1: Grant and revoke are both member actions on `Admin::UsersController`, reached from and
returning to the detail screen

**Decision**: `#grant_admin` (existing, 015) stays where it is — a `PATCH` member route on
`Admin::UsersController` — but its redirect target changes from `admin_users_path` to
`admin_user_path(user)`. A new sibling `#revoke_admin` action is added the same way: a `PATCH` member
route, redirecting to `admin_user_path(user)` on success.

**Rationale**: The relocation the spec asks for (FR-001/FR-002) is about where the *control* lives,
not about inventing a new resource — grant already has exactly the controller action this needs, and
015's own comment explains why it is a named member action rather than a generic `#update`
(`Admin::UsersController`'s header comment: "removing rights, editing an account and deleting one are
all out of scope... which is why this routes to index and a single named action rather than a full
resource"). This feature narrows that comment (revoke is no longer out of scope) but the *shape* — a
single named write per capability, not a general update — still fits, matching 027's own
`Admin::UserLockerProfilesController`/`Admin::UserLockerWishesController` precedent of one
single-purpose controller action per admin-on-behalf-of capability. Redirecting to the detail screen
(rather than the list) is what "faisable... depuis l'écran admin/users/x" (from the detail screen)
means in practice: the administrator's next natural view is the account they were just looking at, not
the list they came from.

**Alternatives considered**: A generic `PATCH /admin/users/:id` toggling a `role` param — rejected,
015's own comment explicitly forbids a general account update on this resource, and a single implicit
toggle param is a worse fit for two distinct, separately-confirmed, separately-worded actions than two
named ones.

## R2: The list's filter-carrying redirect machinery is dropped, not adapted

**Decision**: `Admin::UsersController#grant_admin` no longer builds or passes `filter_selections` on
its redirect, and the private `filter_selections` method is deleted. `FILTER_AXES` and
`filter_selection` stay — they are still read by `#index` for `@current_floor_filter`, `@role_filter`,
and the `@users` query, which this feature does not touch.

**Rationale**: `filter_selections` exists solely so a grant, submitted from a filtered list, returns
the administrator to the same filtered list (020 FR-016). Once grant (and revoke) are submitted from
the detail screen instead, there is no filtered list state to carry — the redirect target is a single
account's own page, which is not filterable. Keeping the now-argument-less method around would be dead
code the moment this ships, which Constitution I ("duplicated logic and unjustified complexity MUST be
refactored rather than repeated") argues against keeping.

**Alternatives considered**: Leaving `filter_selections` in place unused — rejected as dead code with
no caller once this change lands.

## R3: Self-revoke is refused at the controller, not only hidden in the view

**Decision**: `#revoke_admin` compares the resolved target account against `current_user` and refuses
(redirect back to the target's own detail screen, i.e. `current_user`'s own, with an alert) before
calling the model method, independent of whether the view ever rendered a revoke control for that row.

**Rationale**: Mirrors 015's own reasoning for `#grant_admin`'s admin-only guard almost exactly — FR-011
in this spec ("refuse... including when requested directly rather than through the interface") is the
same shape as 015 FR-009, and the codebase already treats "the control isn't shown" as no substitute
for "the request is refused" (015's `before_action` pair guards `grant_admin` regardless of what the
list rendered). The User Story 3 edge case ("no special case that would let them remove the site's last
administrator") depends on this being enforced server-side, since a crafted request bypasses whatever
the view chose to render.

**Alternatives considered**: Relying on the view alone to never offer the control on one's own row —
rejected, this is exactly the "visibility of the control is never what authorises it" principle 015's
own Edge Cases section already states for grant, applied here to revoke.

## R4: `User#revoke_admin_rights!` mirrors `#grant_admin_rights!` and clears provenance, per FR-018

**Decision**: A new model method, symmetric with the existing one:

```ruby
def revoke_admin_rights!
  return self unless admin?

  update!(admin: false, admin_granted_at: nil, admin_granted_by: nil)
  self
end
```

No new columns, no new association. The existing `admin_granted_at`/`admin_granted_by` pair (015) is
reused as the field being cleared, not a new "revoked_at"/"revoked_by" pair.

**Rationale**: The Clarifications session settled that no revoke record is kept (FR-018) — the account
simply reverts to showing no rights-history, the same shape a never-promoted standard account already
has. Clearing `admin_granted_at`/`admin_granted_by` on revoke, rather than adding new columns to record
the revoke itself, is the direct implementation of "that record is cleared, not merely hidden" (FR-018)
— a `revoked_by`/`revoked_at` pair would be exactly the audit trail the clarification declined. The
guard clause (`return self unless admin?`) mirrors `grant_admin_rights!`'s own `return self if admin?`
and implements FR-014 (revoking an already-standard account is not a failure).

**Alternatives considered**: Recording who revoked and when (a `revoked_by`/`revoked_at` pair,
symmetric with `admin_granted_by`/`admin_granted_at`) — this was the direct alternative offered during
clarification and declined; not revisited here. Leaving `admin_granted_at`/`admin_granted_by` set after
a revoke (so a later re-grant could be distinguished from a first-time grant) — rejected as
contradicting FR-018's "no trace of its prior administrator status."

## R5: No new client-side pattern; the confirmation is the same `data-confirm`/`turbo_confirm` control

**Decision**: The revoke control is a `button_to`/`PATCH` with `data: { confirm:, turbo_confirm: }`,
identical in shape to the grant control it sits beside and to the "Cancel search" control already on
this same screen (027). No Turbo Frame wrapper is needed (`admin/users/show.html.erb` is not itself
inside a turbo-frame, unlike the list), no new Stimulus controller, no new CSS component.

**Rationale**: Settled directly by the Clarifications session (revoke reuses grant's plain, no-password
confirmation). This is also the third instance of the identical pattern on this exact screen family
(grant on the old list, cancel-search on the detail screen, now revoke on the detail screen too),
which is precisely the "UI terminology, interaction patterns, and visual components MUST be reused"
bar Constitution III sets, and means this PR needs no new-pattern justification.

**Alternatives considered**: A password re-entry step — the direct alternative offered during
clarification and declined.

## R6: The Users list's Actions column is deleted, not emptied

**Decision**: The `<th>` for `actions_header` and every row's corresponding `<td>` are removed from
`admin/users/index.html.erb` entirely — the table goes from seven columns to six.

**Rationale**: Settled directly by the Clarifications session and matches the request's own stated
goal ("alléger l'affichage de la liste des users" — lighten the list's display). `test/i18n_completeness_test.rb`
and the responsive card layout (012's `data-label`-per-cell pattern) both key off whatever columns
exist; removing the column outright rather than leaving it permanently empty is the more truthful
structure for a column with nothing left to put in it.

**Alternatives considered**: Keeping the column with an em dash on every row (mirroring how the
existing Role column already shows an em dash for standard accounts) — the direct alternative offered
during clarification and declined, since every row would show the same em dash with no exceptions,
unlike Role's em dash which varies by row.

## R7: i18n — relocate the grant strings, drop the "cannot be undone" claim, add revoke's own

**Decision**: `admin.users.index.grant_confirm`/`grant_button`/`grant_aria_label` move to
`admin.users.show.*` (the control's new home) and `grant_confirm`'s copy drops "This cannot be undone" —
it can now be undone, by a revoke. `admin.users.index.actions_header` is deleted. New keys are added
under `admin.users.show.*` (`revoke_button`, `revoke_confirm`, `revoke_aria_label`) and under a new
`admin.users.revoke_admin.*` action namespace (`account_gone`, `revoked`, `self_forbidden`), mirroring
the existing `admin.users.grant_admin.*` namespace's shape. Every key is added to both
`config/locales/en.yml` and `config/locales/fr.yml` (Constitution III's i18n bullet), which
`test/i18n_completeness_test.rb` already enforces without modification.

**Rationale**: `grant_confirm`'s current copy is a factual claim ("This cannot be undone") that this
feature makes false — leaving it unchanged would ship a confirmation dialog that lies to the
administrator reading it. Relocating rather than duplicating the grant strings avoids two copies of the
same three keys living in both `index.*` and `show.*` after the button moves.

**Alternatives considered**: Leaving `grant_confirm`'s wording as-is — rejected, since it would be
inaccurate the moment revoke ships.
