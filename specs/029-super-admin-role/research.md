# Phase 0 Research: Super Admin Role and Exclusive Danger Zone Access

**Feature**: [spec.md](./spec.md) | **Branch**: `029-super-admin-role`

No NEEDS CLARIFICATION markers remain in the Technical Context — the one open scope question
(retroactive promotion of the existing bootstrap administrator) was resolved in `/speckit-clarify`
(spec.md Clarifications, FR-013) before this phase began. The research below is about *how* to implement
against the existing codebase, not about resolving ambiguity in the spec.

## R1: Represent "super admin" as a derived predicate, not a new column

**Decision**: `User#super_admin?` is `admin? && admin_granted_at.nil?` — no new database column, no new
migration.

**Rationale**: 013 FR-001/FR-002 already made "the account created by the first registration" a unique,
permanent, database-enforced fact: `admin: true` is set unconditionally in
`claim_administrator_if_first` only when `User.exists?` is false, and
`index_users_on_bootstrap_admin` (a partial unique index `WHERE admin = 1 AND admin_granted_at IS NULL`,
added in 015) already makes it impossible for more than one row to be in that state. A row reaches
`admin_granted_at IS NULL` in exactly one way — being the account `claim_administrator_if_first` set
`admin = true` on — because every other way an account becomes an admin
(`User#grant_admin_rights!`) always stamps `admin_granted_at`. That is precisely the "at most one,
established only at first registration, never granted" shape spec.md FR-001/FR-002/FR-003/FR-008
describe. Storing a second, separate `super_admin` boolean would duplicate this fact in a column that
has to be kept in lockstep with the first by hand — exactly the kind of unjustified complexity
Constitution I asks reviewers to block, and a real drift risk (e.g., a future migration or console
fix that updates `admin_granted_at` without remembering a sibling column).

**Alternatives considered**:
- A new `super_admin` boolean column with its own partial unique index, set alongside `admin` in
  `claim_administrator_if_first`. Rejected: two independently-updatable columns encoding the same fact,
  doubling the surface `lost_the_administrator_race?`'s index-conflict rescue would need to recognize,
  for no behavior the derived predicate does not already provide.
- A `role` enum column (`standard` / `admin` / `super_admin`) replacing the existing boolean. Rejected as
  out of scope: it would touch every existing query and scope built on the `admin` boolean
  (`with_role`, `RoleFilter`, `grant_admin_rights!`, `revoke_admin_rights!`) across five prior features,
  for a rename the spec never asked for. FR-011 explicitly asks that the super admin keep being treated
  as an admin everywhere except the danger zone — a derived predicate delivers that for free; a
  role-enum rewrite would have to re-earn it.

## R2: A dedicated `require_super_admin!` guard, mirroring `require_admin!`

**Decision**: Add `ApplicationController#require_super_admin!`, structurally identical to the existing
`require_admin!` but checking `current_user&.super_admin?`. Apply it (replacing `require_admin!`) on
`Admin::DangerZoneController` and `Admin::AllowedEmailDomainsController` — the two controllers behind
"the danger zone screen and every action it offers" (spec.md FR-005).

**Rationale**: `require_admin!`'s own comment already states the principle this feature needs to keep
true: "Leaving the ... entry out of a non-administrator's navigation is presentation; this is what
refuses the address when it is typed, bookmarked, or guessed." The same reasoning applies one level up:
hiding the menu link is presentation, `require_super_admin!` is what actually refuses a standard admin
who types or bookmarks `/admin/danger_zone`. `Admin::AllowedEmailDomainsController` is in scope because
its own header comment already says its writes are "the two writes behind the Danger Zone screen" — the
spec's "every action it offers" (FR-005) is not just `DangerZoneController#update` (the site language),
it is this controller's `#create`/`#destroy` too.

**Alternatives considered**:
- Checking `super_admin?` inline inside `require_admin!` itself with an extra parameter. Rejected:
  `require_admin!` is used by `Admin::UsersController` too, where FR-011 requires standard-admin access
  to keep working unchanged; branching one shared method by a caller-supplied flag is more complex than
  a second, equally small method.
- A `SuperAdminController` base class both controllers inherit from. Rejected: neither controller shares
  any other behavior, and the codebase's established pattern (documented on `DangerZoneController`
  itself) is that each controller in this namespace "states its own guard and cannot lose it to a
  refactor somewhere else" — introducing a shared base class here would work against that stated reason.

## R3: Reuse the existing admin-only refusal message

**Decision**: `require_super_admin!` redirects with `I18n.t("application.administrators_only")` — the
exact message and key `require_admin!` already uses — rather than a new "super admins only" string.

**Rationale**: spec.md's Edge Cases and User Story 2's fourth acceptance scenario both describe a
standard admin being "refused exactly as they already are today for the rest of the Admin section" —
the spec does not ask a standard admin's refusal to read differently from a non-admin's, and revealing
that a second, more privileged admin tier exists is information a refusal screen has no reason to leak.
Reusing the string also means this feature adds zero new strings for the access-refusal path itself,
only for the two guards described in R5/R6 below (Constitution III: reuse existing conventions before
adding new ones).

**Alternatives considered**: A distinct "super admins only" message naming the tier. Rejected per above
— no acceptance scenario asks for it, and it adds a translation obligation the feature does not need.

## R4: Menu — gate only the danger zone link, not the whole submenu

**Decision**: In `shared/_site_menu_items.html.erb`, keep the outer `<details class="site-submenu">`
(and the "Users" link inside it) gated on `current_user.admin?` exactly as today; wrap only the
"Zone de danger" `link_to` in a nested `<% if current_user.super_admin? %>`.

**Rationale**: FR-007 asks that the Admin menu stop listing the danger zone entry for a standard admin
while every other admin capability (starting with the Users list) keeps working unchanged (FR-011).
Narrowing the whole submenu's condition to `super_admin?` would also hide "Users" from every standard
admin, which nothing in the spec asks for and User Story 2's first acceptance scenario explicitly rules
out ("the Users entry still does" appear).

**Alternatives considered**: A second, separate `<details>` for the super admin's extra entry. Rejected:
one extra danger-zone link does not warrant a second disclosure widget, and it would change the submenu's
visual/interaction shape for the one account that needs it least (the super admin already sees today's
single "Admin" submenu).

## R5: Close the revoke path — `Admin::UsersController#revoke_admin` refuses on the super admin

**Decision**: Add a guard to `#revoke_admin`, structurally parallel to the existing self-forbidden
check, that redirects with a new alert when `user.super_admin?`. Hide the "Revoke admin rights" button
on `admin/users/show.html.erb` for the super admin's row (in addition to the existing self-check), the
same belt-and-suspenders posture 028's contract already documents for the self-forbidden case.

**Rationale**: Today, `User#revoke_admin_rights!` only checks `admin?` — nothing stops a second, granted
administrator from opening the bootstrap administrator's detail page and revoking their rights (the only
existing guard, `user == current_user`, does not apply to a *different* administrator viewing the
bootstrap admin's page). Left alone, that gap directly violates FR-009 ("no control ... removes,
transfers, or reassigns the super admin role"). The fix belongs in the controller, matching where the
self-forbidden check already lives and for the same documented reason: "visibility of the control is
never what authorises it" (026/028's own comment on this action).

**Alternatives considered**: Push the guard into `User#revoke_admin_rights!` itself (raise or silently
no-op). Rejected: every other guard on this action (`account_gone`, `self_forbidden`) lives in the
controller and produces a flash the person reads; moving only this one into the model would make it
behave differently from its siblings for no benefit, and a silent no-op would report success on a write
that did not happen, which is what 015/028 deliberately avoided for the self-forbidden case.

## R6: Close the cancellation path — the super admin can never delete their own account while others exist

**Decision**: Replace the existing `before_destroy :keep_an_administrator_for_the_remaining_accounts`
callback (015 FR-016) with a new one, `prevent_super_admin_cancellation`, that aborts with a new message
whenever `super_admin? && User.where.not(id: id).exists?` — i.e. whenever the super admin's own account
is being destroyed and at least one other account still exists, with no exception for whether any of
those other accounts happen to be admins. When the super admin is the *sole* remaining account, the
callback is a no-op and destroy proceeds exactly as it does today (spec.md's clarified exception,
Edge Cases).

**Rationale — this is a replacement, not an addition**: The clarified answer (spec.md Clarifications,
FR-010/FR-014) is stricter than "would this leave the site with zero admins" — it is "would this leave
the site with any other account while nobody can ever hold this role again." Tracing the consequence of
that rule through: `claim_administrator_if_first` (013 FR-002) only ever sets `admin_granted_at: nil` on
a completely empty site, so the super admin is, by construction, *permanently present* for as long as
any other account exists — the one path this callback blocks is the only way to remove it. That means
the super admin is now an unconditional, permanent example of "an admin remains" for every other
account's own destroy check. The old rule's condition, `others.exists? && !others.exists?(admin: true)`,
can therefore never be true again for any account other than the super admin: whenever `others.exists?`
is true for some other account being destroyed, the super admin is necessarily among those others (it
cannot already have been destroyed while they exist), so `others.exists?(admin: true)` is always also
true. And for the super admin's own destroy, the new callback already decides the outcome before the old
one would even run. The old callback is therefore unreachable in every case once this feature ships —
dead code under Constitution I ("duplicated logic and unjustified complexity MUST be refactored"), not a
rule this feature merely narrows. It is removed outright, along with `User::LAST_ADMINISTRATOR_MESSAGE`
and the `user.messages.last_administrator` locale key/strings, which become vestigial with it.
`RegistrationsController#destroy`'s existing `resource.errors[:base].first || I18n.t(...)` fallback is
unchanged in shape — only its fallback key moves to `user.messages.super_admin_uncancellable`, the one
message a failed destroy can now actually produce.

A real, intentional side effect: a *granted* (non-super) admin can now always cancel their own account,
regardless of how many other admins exist, because the super admin's permanence already guarantees the
site is never left without one (spec.md FR-014). This is not a gap — it is what "the site is never left
with registered accounts and no administrator" now means, holding more strongly than the rule it
replaces (that rule only ever guaranteed *some* admin stayed; this one guarantees a specific, permanent
one does).

**Alternatives considered**:
- Add the new callback *alongside* the old one, leaving `keep_an_administrator_for_the_remaining_accounts`
  in place. Rejected once its condition was traced through as shown above — keeping code that can never
  execute contradicts Constitution I and this repo's own precedent of deleting code a feature makes
  unreachable rather than leaving it as a comment-only relic (028 deleting `filter_selections` for the
  same reason, at far smaller scale).
- Extend `keep_an_administrator_for_the_remaining_accounts` itself with an `if super_admin?` branch at
  the top, keeping one method/message for both rules. Rejected: the two conditions are different shapes
  (`others.exists?` vs `others.exists? && !others.exists?(admin: true)`) and, per the analysis above,
  only one of them is ever reachable after this feature ships — merging them under one name would
  misdescribe what the surviving rule actually checks.

## Test strategy

Every guard added above already has a corresponding controller or model test file (Technical Context);
no new test file is required. Each guard gets a failing-then-passing test per Constitution II:

- `test/models/user_test.rb`: `super_admin?` true only for the bootstrap account; false after
  `grant_admin_rights!` on any other account; `destroy` on the super admin's own account is refused
  whenever any other account exists, regardless of whether any of those other accounts are themselves
  admins; `destroy` succeeds when the super admin is the sole remaining account.
- `test/controllers/admin/danger_zone_controller_test.rb`,
  `test/controllers/admin/allowed_email_domains_controller_test.rb`: a signed-in standard admin is
  refused on `#show`/`#update`/`#create`/`#destroy`; the super admin still succeeds.
- `test/controllers/admin/users_controller_test.rb`: `#revoke_admin` against the super admin's own
  `id`, requested by a *different* admin, is refused with the new alert and makes no change.
- `test/controllers/registrations_controller_test.rb`: the super admin's own account-cancellation
  request is refused with the new message while any other account exists.
- `test/system/admin_danger_zone_test.rb`, `test/system/admin_users_test.rb`,
  `test/system/admin_user_detail_test.rb`: the "Zone de danger" link is absent for a standard admin and
  present for the super admin; the revoke button is absent on the super admin's own detail row.

### R6 fallout: existing tests that assumed the old, now-removed rule

Tracing R6's replacement through the existing suites, every test below asserted behavior that
`keep_an_administrator_for_the_remaining_accounts`/`LAST_ADMINISTRATOR_MESSAGE` produced and that the
new rule produces differently (or no longer produces at all). None of these is a regression to preserve
— each one is either now testing an unreachable rule, or exercises `users(:frank).destroy` directly
with the full fixture set loaded, which the new rule now correctly refuses since other accounts remain:

- `test/models/user_test.rb` — `"deleting an administrator does not promote anyone in their place"` and
  `"signing up while the site has an administrator grants nothing"` call `users(:frank).destroy`
  directly while every other fixture is still loaded; both must switch to `users(:grace).destroy`
  (a granted, non-super admin), which the new rule leaves unrestricted per FR-014 and demonstrates the
  same underlying claim (no promotion, no vacancy admitted) without depending on the retired rule.
- `test/models/user_test.rb` — `"deleting the editor keeps the edit provenance and clears only the
  editor"` and `"deleting the canceller keeps the cancellation provenance and clears only the
  canceller"` both call `users(:frank).destroy` with `users(:carol)` (and the rest of the fixture set)
  still present; both must switch to `users(:grace)` as the editor/canceller being deleted — the
  `dependent: :nullify` behavior under test does not depend on which admin triggers it.
- `test/models/user_test.rb` — `"the last administrator cannot be deleted while other accounts remain"`,
  `"an administrator can be deleted while another administrator remains"`, and `"the refused
  administrator is told to grant rights to someone else first"` each assert the retired rule's exact
  shape (blocked only when no other admin remains; a second admin is enough to let the first go; the
  remedy is "grant rights to someone else"). None of these claims survives R6: the first two need
  rewriting around the new rule (blocked whenever *any* other account remains, admin or not; a granted
  admin, unlike the super admin, can always leave); the third's premise (a "last administrator" ever
  gets told to grant rights elsewhere) no longer occurs at all and is replaced by a test of the new
  message instead.
- `test/models/user_test.rb` — `"the sole account on the site can be deleted even though it is the
  administrator"` is the one test in this group that needs **no change** to its setup — it already
  exercises exactly the exception spec.md's Clarifications preserved (the sole remaining account may
  still leave); renamed to `"...the super admin"` and extended with a `:super_admin?` assertion on the
  successor account, since that is now the more precise claim.
- `test/models/user_test.rb` — `"deleting the grantor keeps the grant and clears only the grantor"`
  (FR-019) also calls `users(:frank).destroy` directly with `users(:carol)` (and the rest of the fixture
  set) still present, discovered only once T022 landed and this test started failing — not caught during
  planning because it sat outside the "last administrator" block the other frank-based tests are grouped
  in. Switches to `users(:grace)` as the grantor, same reasoning as the editor/canceller pair above.
- `test/controllers/registrations_controller_test.rb` — `"the last administrator cannot cancel their
  account while others remain"` signs in as `frank` after destroying `grace`, while the rest of the
  fixture set (carol, bob, dave, …) remains — the refusal still happens (other accounts remain), but the
  message asserted (`User::LAST_ADMINISTRATOR_MESSAGE`) must become the new
  `user.messages.super_admin_uncancellable` string, and the test's framing (destroying `grace` first) is
  no longer necessary to reach the refusal — the refusal fires with everyone but `frank` still present,
  grace or no grace — though keeping that setup is harmless and keeps the diff small. Renamed to `"the
  super admin cannot cancel..."`.
- `test/controllers/registrations_controller_test.rb` — `"an administrator can cancel while another
  administrator remains"` signs in as `frank` and self-cancels via `DELETE /users`, expecting success —
  also discovered only once T022 landed, not named in the original task list. `frank` can no longer
  self-cancel this way while `grace`/others remain; rewritten as `"a granted administrator can cancel
  while the super admin remains"`, signed in as `grace` instead (FR-014).
- `test/system/admin_users_test.rb` — `"the last administrator is stopped from cancelling until someone
  else is promoted"` destroys `grace`, has `frank` fail to self-cancel, then grants `carol` admin rights
  and has `frank` succeed at self-cancelling. The second half no longer holds — `frank` can never
  self-cancel while `carol` (or anyone else) remains, granted admin rights or not. This test must be
  rewritten to stop after asserting the refusal (with the new message), without the "grant rights then
  succeed" tail — that tail's claim is retired.
- `test/system/admin_users_test.rb` — `"a grant survives the deletion of the administrator who made
  it"` has `frank` grant `carol` admin rights and then self-cancel to prove the grant survives its
  grantor's deletion. Since `frank` can no longer be deleted this way while `carol`/others remain, this
  scenario must be restaged with `grace` as the grantor who then self-cancels (grace is a granted
  admin with no restriction on her own departure) — the `dependent: :nullify` claim under test is
  identical either way.

### R6 fallout: code and locale removal

- `app/models/user.rb`: remove `LAST_ADMINISTRATOR_MESSAGE`, `keep_an_administrator_for_the_remaining_accounts`,
  and its `before_destroy` registration; add `prevent_super_admin_cancellation` and its `before_destroy`
  registration in its place.
- `app/controllers/registrations_controller.rb`: update the fallback `I18n.t("user.messages.last_administrator")`
  to `I18n.t("user.messages.super_admin_uncancellable")`; update the comment referencing
  `keep_an_administrator_for_the_remaining_accounts` by name.
- `config/locales/en.yml`, `config/locales/fr.yml`: remove the `last_administrator` key, add
  `super_admin_uncancellable` (contracts/super-admin-access.md already specifies its two new strings).
