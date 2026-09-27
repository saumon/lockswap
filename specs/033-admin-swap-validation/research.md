# Research: Administrator Validation of Locker Swap Exchanges

## R1 — "Awaiting validation" is the existing `accepted` status, not a new one

**Decision**: Do not add a new `LockerSwapProposal` status. An exchange "awaiting validation" is exactly
what `status: :accepted` already means; the admin screen's list is `LockerSwapProposal.accepted`.

**Rationale**: The enum (`pending: 0, accepted: 1, declined: 2, withdrawn: 3, completed: 4`) is documented
on the model as "mutually exclusive by construction." Adding a fifth value (e.g. `awaiting_validation`)
would require migrating every currently-`accepted` row at deploy time and would duplicate a distinction
that doesn't otherwise exist: nothing about a proposal's data changes between "the recipient just accepted
it" and "an administrator is now looking at it" — only who is allowed to act on it changes, and that is a
controller-level concern (which scope a controller queries), not a fact about the row. This is also exactly
what makes the "already-accepted-before-rollout" clarification a non-issue (R11 below) — there is nothing to
migrate.

**Alternatives considered**: A new `awaiting_admin_validation` enum value between `accepted` and
`completed`. Rejected — it would need a one-time data migration to move every currently-`accepted` row into
it, would make `in_progress_for?`/`active_for?` (which key off `accepted`) need to check two values instead
of one, and buys no behavioral distinction the existing single value doesn't already provide.

## R2 — Access guard: `require_admin!`, not `require_super_admin!`

**Decision**: `Admin::SwapValidationsController` uses the existing `before_action :require_admin!`, the
same guard `Admin::UsersController`, `Admin::ZonesController`, and `Admin::LockerMapController` already use
— not `require_super_admin!` (029), which is reserved for the danger zone.

**Rationale**: Directly settled by spec.md's Assumptions ("does not restrict the validation screen to the
super administrator the way the existing danger zone is restricted") and confirmed by User Story 1's
Acceptance Scenario 3. Reusing `require_admin!` also means the existing, already-tested refusal message
(`I18n.t("application.administrators_only")`) applies with no new string (Constitution III; mirrors 029
research.md R2's reasoning for why `require_super_admin!` reused the same message rather than inventing a
"super admins only" one).

**Alternatives considered**: A new `require_admin_or_super_admin!` guard. Rejected — `require_admin!`
already means exactly that, since `super_admin?` implies `admin?` (`User#super_admin? = admin? &&
admin_granted_at.nil?`); a second guard with identical behavior would be a duplicate, not a distinction.

## R3 — Extend `confirm!`/`decline!` with `by:`, don't fork admin-specific methods

**Decision**: `confirm!` and `decline!` each gain one optional keyword argument, `by: nil`, recorded onto
the new `admin_decided_by` association only when present. Existing callers
(`LockerSwapProposalsController#accept`/`#decline`, the retired `#confirm`) are unaffected — they never
pass `by:`, so `admin_decided_by` stays `nil` for a decision either party made about their own exchange, as
it always implicitly has been.

**Rationale**: Both methods already do exactly what validating/refusing needs (swap-and-complete;
mark-declined-with-comment respectively) — see spec.md's User Story 1/2 both saying "the same outcome the
retired self-confirmation used to produce" and "the same way a recipient's own decline comment already is."
Forking `admin_confirm!`/`admin_decline!` would duplicate the transaction/snapshot logic in `confirm!` and
the comment-handling in `decline!` for no behavioral difference beyond "who gets attributed." The `by:`
keyword is the same shape `User#grant_admin_rights!(by:)` (015) already established for "this action was
taken on someone's behalf by an administrator."

**Alternatives considered**: Set `admin_decided_by_id` directly from the controller with `update_column`
after calling `confirm!`/`decline!` unchanged. Rejected — it would split one logical write (the decision and
who made it) into two statements against the same row, and the second write would not participate in
`confirm!`'s existing transaction, leaving a window where a completed swap has not yet recorded who
validated it.

## R4 — Widen `decline!`'s guard rather than add a second decline method

**Decision**: `decline!`'s guard changes from `return false unless pending?` to
`return false unless pending? || accepted?`. No new method is added.

**Rationale**: `decline!`'s body already does precisely what an admin refusal needs — mark `declined`,
record the optional comment, don't touch locker details, don't call `decline_competing_proposals` (that is
`accept!`'s job, unaffected here). The only thing stopping it from being callable on an `accepted` proposal
today is the guard. Existing callers keep their existing behavior unchanged: the recipient's own decline
path (`LockerSwapProposalsController#decline`) is scoped through
`current_user.received_swap_proposals.pending.find(...)`, so it can never reach an `accepted` row regardless
of what the model-level guard allows — the widened guard only becomes reachable through the new admin
controller's `.accepted` scope.

**Alternatives considered**: A separate `refuse!` method for the admin path. Rejected for the same
duplication reason as R3 — it would re-implement `decline!`'s body (comment handling, `resolution_snapshot`,
`decided_at`) with no behavioral difference.

## R5 — `admin_decided_by_id`: same shape as the three existing admin-attribution columns

**Decision**: Add `locker_swap_proposals.admin_decided_by_id` (integer, nullable, indexed, foreign key to
`users`), with `belongs_to :admin_decided_by, class_name: "User", optional: true` on `LockerSwapProposal`
and the matching `has_many :swap_decisions_made, class_name: "LockerSwapProposal",
foreign_key: :admin_decided_by_id, dependent: :nullify, inverse_of: :admin_decided_by` on `User`.

**Rationale**: This is the fourth instance of a pattern the codebase already established three times —
`admin_granted_by_id` (015), `locker_edited_by_id` and `search_cancelled_by_id` (027), each: nullable,
optional, indexed, foreign-keyed to `users`, `dependent: :nullify` on the inverse so cancelling the acting
administrator's own account later doesn't raise a foreign-key violation or cascade-delete the proposal it
decided. FR-014 ("record which administrator... and when") needs a "when" too, but that already exists —
`decided_at` (set by both `confirm!` and `decline!`) is reused rather than duplicated into a second
timestamp.

**Alternatives considered**: A separate `AdminSwapDecision` join/audit model recording every validate/refuse
event. Rejected as unjustified complexity (Constitution I) for what spec.md actually asks: "who and when"
for the one decision that settles a proposal — not a full history of every administrator who ever looked at
it. If a fuller audit trail is wanted later, the existing `decided_at`/`admin_decided_by` pair is the minimum
that answers FR-014 today.

## R6 — The race condition: `find_by` on the `.accepted` scope, not `find`

**Decision**: Both `#validate` and `#refuse` look up the proposal as
`LockerSwapProposal.accepted.find_by(id: params[:id])`. When it returns `nil` — because another
administrator already decided it, or it never existed — the action redirects back to the list with an
"already decided" flash rather than raising.

**Rationale**: This is the same graceful-vanished-record shape `Admin::ZonesController#update`/`#destroy`
already use (`Zone.find_by(id: params[:id])`, `redirect_to ..., alert: t(".zone_gone")` /
`find_by(...)&.destroy`) rather than the plain `find` (which raises `ActiveRecord::RecordNotFound`, a 404)
that `LockerSwapProposalsController`'s user-facing actions use for a proposal that is simply "not yours to
find." Here the row exists and did belong to this screen a moment ago — the honest message is "someone
already decided this," matching spec.md's Edge Cases ("only the first action... takes effect; the second is
refused rather than applied... since it is no longer awaiting a decision") — not "not found."

**Alternatives considered**: Wrap `confirm!`/`decline!`'s own `return false unless accepted?` /
`pending? || accepted?` guard and let the controller not bother re-scoping the lookup with `.accepted`.
Rejected — without scoping the `find` itself, a request for an id that exists but is `completed` or
`declined` would successfully load the record and then silently no-op inside the model method, which is
harder to distinguish from "the id doesn't exist at all" than simply not finding it in the first place.

## R7 — List order: oldest-accepted-first

**Decision**: `Admin::SwapValidationsController#index` orders by `decided_at: :asc` — the exchange that has
been waiting longest for validation appears first.

**Rationale**: A FIFO queue is the ordinary expectation for a worklist an administrator processes
periodically (services généraux checking the screen and working through it), and avoids the appearance of
some requests being skipped indefinitely. `decided_at` is already set the moment `accept!` runs, so no new
timestamp is needed to order by.

**Alternatives considered**: Newest-first (matching `LockerSwapProposalsController#index`'s own
newest-first history ordering). Rejected for this specific screen — that ordering suits a personal history
someone reads top-down for "what happened most recently," not a shared queue meant to be worked oldest-first
so nothing waits indefinitely.

## R8 — Remove `#confirm` outright, not guard it

**Decision**: `LockerSwapProposalsController#confirm`, its route (`patch :confirm` under
`resources :locker_swap_proposals`), and the button in `home/_swap_exchange_in_progress.html.erb` are
deleted, not left in place behind a guard that always refuses.

**Rationale**: Constitution I: a guarded action nobody can ever successfully call is unjustified complexity
— dead code kept "just in case," not a defensive check against a reachable state. spec.md's User Story 3,
Acceptance Scenario 3 ("a user attempts to trigger the exchange's completion directly... refused") is
satisfied by ordinary Rails behavior once the route is gone: a request to a route that no longer exists is
refused with a 404, the same as any other retired endpoint in any Rails app, requiring no bespoke handling.

**Alternatives considered**: Keep the route/action and make it always redirect with an alert (e.g. "only an
administrator can do this now"). Rejected — it would require a new locale string and a new code path whose
only purpose is to explain that a deleted feature is deleted, for a URL no current UI ever links to once the
button is removed.

## R9 — Reuse existing UI components; no new pattern

**Decision**: The admin screen's list reuses the `.data-table` shape (`locker_swap_proposals/
_history_table.html.erb`'s structure: `role="table"`, `data-rail`, `.data-value` cells); the refusal comment
uses the same `<details class="tile-disclosure">` + `form_with` + optional `text_area` pattern
`home/_swap_proposals_received.html.erb` already uses for the recipient's own decline; zone display reuses
`shared/_zone_label` fed by a batched `LockerMapEntry.zone_names_for` call (032 research.md R3's pattern),
not a new component.

**Rationale**: Constitution III requires reusing established UI patterns over inventing new ones without
justification; nothing about "list exchanges, act on one, optionally explain why" differs from patterns the
product already has in two places.

**Alternatives considered**: A card-per-exchange layout (like the homepage's own `.card--them` treatment).
Rejected for this screen specifically — the homepage cards suit "your one exchange, prominently, alone,"
while the admin screen is a worklist of arbitrarily many rows, which is exactly what `.data-table` (already
used for the analogous "many proposals, one per row" history screen) is for.

**Revised during implementation**: the tile/card alternative was the right one after all — the
refuse form needs the `<details>` disclosure, which is styled for `.tile` and does not fit inside a
table cell at phone width. The screen reuses `home/_swap_proposals_received.html.erb`'s tile shape
(contracts/admin-swap-validation.md, "As built").

## R10 — Self-validation: no additional guard (clarified)

**Decision**: No code checks whether the signed-in administrator is a party to the exchange they are
validating or refusing. `require_admin!` alone gates the whole controller.

**Rationale**: Directly settled by the 2026-09-27 clarification ("Allow it — administrators can validate or
refuse any listed exchange, including their own"), now spec.md FR-003. Confirmed as the simpler,
no-code-required option, consistent with this codebase's existing posture that `require_admin!`/
`require_super_admin!` are the only gates on every other admin action — none of them special-cases "unless
it's your own record" (e.g. `Admin::UsersController#grant_admin`/`#revoke_admin` don't check whether the
admin is looking at their own account either, beyond the pre-existing "can't revoke the last admin" rule,
which is unrelated).

## R11 — Already-accepted exchanges at rollout need no migration step (clarified)

**Decision**: No data migration, no backfill, no special-cased query. `Admin::SwapValidationsController
#index`'s plain `LockerSwapProposal.accepted` scope picks up every `accepted` row that exists the moment
this feature deploys, including ones accepted before it shipped.

**Rationale**: Directly settled by the 2026-09-27 clarification and made trivial by R1 — since "awaiting
validation" was never a new status, there is nothing to move a pre-existing `accepted` row into. The row's
`admin_decided_by_id` is simply `NULL` until an administrator acts on it, same as any newly-accepted one.

## R12 — "Échange en cours" is retired everywhere it appears, not just on the homepage

**Decision**: Both occurrences of the French string "Échange en cours" (English: "Exchange in progress")
are replaced with "En attente de validation" ("Awaiting validation"): `swap_exchange_in_progress.title`
(the homepage card, spec.md's explicit example) **and** `locker_swap_proposals.index.exchange_in_progress`
(the status badge `locker_swap_proposals/_history_table.html.erb` shows for an `accepted?` row — used on the
self-service proposal-history screen and, per that partial's own comment, reused unmodified on the admin
user-detail screen, 027 research.md R4).

**Rationale**: These are the same fact — a proposal is `accepted?` — surfaced through two different locale
keys read by two different views. spec.md quotes only the homepage's copy because that is the screen the
request was written against, but Constitution III's "UI terminology... MUST be reused from existing
conventions" cuts the other way here too: leaving the history table's badge reading "Échange en cours" while
the homepage right above the same feature says "En attente de validation" would describe the identical proposal
state with two different, now-contradictory words. `locker_swap_proposals.confirm.confirmed` (the retired
`#confirm` action's own success flash) is deleted outright rather than reworded — there is no controller
action left to reach it from (research.md R8).

**Alternatives considered**: Change only the homepage copy, exactly as literally quoted. Rejected —
`_history_table.html.erb` is shown to the very same standard users this feature's User Story 3 is about
(their own proposal history), so it would visibly contradict the homepage's new wording for the same
proposal on the very next screen a curious user opens.

## Test strategy

| Behavior | Test file |
|---|---|
| `decline!` now succeeds from `accepted?`, still fails once `declined?`/`completed?`/`withdrawn?` | `test/models/locker_swap_proposal_test.rb` |
| `confirm!(by:)`/`decline!(comment, by:)` record `admin_decided_by` when given, leave it `nil` when not | `test/models/locker_swap_proposal_test.rb` |
| Non-admin / anonymous refused on index, validate, refuse | `test/controllers/admin/swap_validations_controller_test.rb` |
| Admin validates a listed exchange: lockers swap, `completed?`, `admin_decided_by` set, row leaves the list | `test/controllers/admin/swap_validations_controller_test.rb` |
| Admin refuses with and without a comment: `declined?`, no locker change, comment recorded or blank | `test/controllers/admin/swap_validations_controller_test.rb` |
| Acting on an id no longer `accepted` (already decided): graceful "already decided" alert, no double-apply | `test/controllers/admin/swap_validations_controller_test.rb` |
| An administrator validating/refusing their own exchange succeeds like any other row (R10) | `test/controllers/admin/swap_validations_controller_test.rb` |
| `#confirm` route/action no longer exists | `test/controllers/locker_swap_proposals_controller_test.rb` (removed assertions replaced by a routing-absence check or simply deleted) |
| Homepage shows "En attente de validation" / the new waiting-for-admin message for both requester and recipient, no button | `test/system/locker_swap_proposal_test.rb` |
| Full admin flow end-to-end (list → validate; list → refuse with comment) | `test/system/admin_swap_validation_test.rb` (new) |
| `en.yml`/`fr.yml` stay in lockstep for every new/changed key | `test/i18n_completeness_test.rb` (automatic, no edits needed) |
