# Phase 0 Research: Locker Field Lock & Swap History Comment

The technology stack is fixed by the existing codebase (Ruby on Rails 8.1.3 monolith, established in
001-user-authentication, extended in 002/003/004) — there are no framework/language choices left
open. The open questions are about where the new lock rule belongs, how to distinguish "changing an
already-saved value" from "providing one for the first time," how to keep a history comment accurate
without drifting as profiles change later, and how to populate that comment for a bulk auto-decline
without regressing the existing single-statement guarantee. All `NEEDS CLARIFICATION` items from the
spec were resolved during `/speckit-clarify` and are recorded in spec.md's Clarifications section;
this document covers the remaining implementation-shape decisions.

## Where the lock rule lives

- **Decision**: A `User` validation, `validate :floor_and_locker_locked_during_active_swap, on:
  :locker_profile_update`, alongside the existing `floor` presence and `locker_number` uniqueness
  validations already scoped to that same context (002).
- **Rationale**: 002 already established `:locker_profile_update` as the one save context that
  carries every rule specific to the locker-profile save path, precisely so a blanket validation
  does not also block Devise's own account-update save. This feature's rule is exactly that kind of
  rule — it belongs in the same place, not in `LockerProfilesController` (which would duplicate
  business logic the model already owns, per Constitution Principle I) and not as a `before_action`
  guard (which could not distinguish "no change to this field" from "field unchanged but form
  re-submitted with the same value," something a validation checking dirty-tracking state gets for
  free).
- **Alternatives considered**: A controller-level check in `LockerProfilesController#update` before
  calling `save` — rejected, splits a single business rule across two layers for no benefit, and
  does not protect any other future save path (e.g., an admin tool, a future API) the way a model
  validation does.

## Distinguishing "already-saved" from "first-time"

- **Decision**: Inside the new validation, only add an error for a field that both changed
  (`floor_changed?` / `locker_number_changed?`) *and* had a present value before the change
  (`floor_was.present?` / `locker_number_was.present?`).
- **Rationale**: This is exactly what the clarified spec requires (a requester with no locker yet
  must still be able to record one while their proposal is pending) and it reads directly off Active
  Record's existing dirty-tracking API — no extra column or flag needed. It also matches the existing
  UI split in `home/index.html.erb`: a user with `saved_floor.blank?` is always shown the plain
  first-time entry form (never the "Edit locker details" disclosure), so in practice the lock only
  ever needs to affect the edit path, never the first-time path — the validation and the view
  decision are two expressions of the same underlying rule.
- **Alternatives considered**: Blocking every write to `floor`/`locker_number` uniformly while
  locked — rejected per the clarification; it would strand a requester with no locker, unable to
  ever complete the very swap that is blocking them.

## Detecting "active" (FR-001, FR-002)

- **Decision**: A new `LockerSwapProposal.active_for?(user)` class method: `pending or accepted, in
  either role`, implemented as `pending.exists?(requester_id: user.id) ||
  pending.exists?(recipient_id: user.id) || in_progress_for?(user)` (reusing the existing `accepted`
  check from 004).
- **Rationale**: 004's `in_progress_for?` already established the "two separate `exists?` calls, not
  one `OR`" pattern for exactly this reason: this SQLite version's query planner faults trying to
  OR-optimize a scan of this table against its partial indexes. `active_for?` extends the same shape
  to also cover `pending`, which `in_progress_for?` deliberately excludes (it answers a narrower
  question — "committed to an exchange," not "has anything outstanding"). Keeping them as two
  distinctly-named methods (rather than adding a `status:` parameter to `in_progress_for?`) keeps
  each call site's intent legible: proposal-creation eligibility asks "committed" (`in_progress_for?`
  — 004 FR-003/FR-004, unchanged by this feature), the profile lock asks "has anything at all
  outstanding" (`active_for?`, new).
- **Alternatives considered**: A single `OR`-based query — rejected for the same documented SQLite
  planner-fault reason 004 already hit; reusing `in_progress_for?` alone (i.e., only locking once a
  proposal is `accepted`) — rejected, the spec explicitly locks from the moment a proposal is merely
  `pending` (User Story 1, scenarios 1-2).

## Keeping the history comment from drifting after resolution

- **Decision**: Four new nullable string columns on `locker_swap_proposals`
  (`requester_floor_at_resolution`, `requester_locker_number_at_resolution`,
  `recipient_floor_at_resolution`, `recipient_locker_number_at_resolution`), populated exactly once,
  at the moment a proposal transitions out of `pending`/`accepted` into `declined`, `withdrawn`, or
  `completed`. While a proposal is still `pending` or `accepted`, the summary is computed live from
  `requester.floor`/`requester.locker_number`/`recipient.floor`/`recipient.locker_number` (which
  cannot drift during that window — they are exactly the fields this feature locks).
- **Rationale**: Storing raw values rather than a pre-rendered sentence keeps wording a presentation
  concern, changeable without a migration or backfill — the same separation `saved_floor`/
  `saved_locker_number` already draw between "the value" and "how it's shown." A snapshot taken
  *at resolution* (rather than, say, at proposal creation) is what the clarified spec calls for: an
  active/unresolved proposal's summary must track live values (since nothing can drift while locked
  anyway) and only freezes once resolved.
- **Alternatives considered**: A single free-text `system_comment` column, written once as a
  formatted string — rejected, entangles data with presentation and would need a data migration for
  any future wording change; snapshotting only on `completed` and leaving `declined`/`withdrawn`
  to recompute forever from current `users` values — rejected, contradicts the clarified requirement
  that a resolved proposal's history never drifts, and would need special-casing `completed` against
  the other two final statuses instead of one uniform "snapshot at resolution" rule.

## Snapshot timing inside `confirm!` (pre-swap, not post-swap)

- **Decision**: Inside `confirm!`'s existing transaction, capture the snapshot from
  `requester`/`recipient`'s *current* `floor`/`locker_number` **before** calling the existing
  `swap_lockers`, then pass those captured values into the same `update!` call that already sets
  `status: :completed, completed_at: Time.current`.
- **Rationale**: The spec's Assumptions section is explicit that a completed exchange's comment
  states each side's pre-swap values ("what each side gave up and received"); `swap_lockers` mutates
  `requester`/`recipient` in place, so the snapshot must be read before that call, not after.
- **Alternatives considered**: Reading `requester_details`/`recipient_details` (the two local
  variables `swap_lockers` already computes internally) from inside `confirm!` after the fact —
  rejected as more fragile (couples `confirm!` to `swap_lockers`'s private local variable names) than
  simply capturing a `resolution_snapshot` from the association objects before either method runs.

## Populating the snapshot for the bulk auto-decline path

- **Decision**: `decline_competing_proposals` keeps its existing single `update_all` call but adds
  the four new columns to it using correlated subqueries against `users`, e.g.
  `requester_floor_at_resolution = (SELECT floor FROM users WHERE users.id =
  locker_swap_proposals.requester_id)` (and the equivalent for the other three columns), rather than
  looping over `competing_ids` and calling an instance method per row.
- **Rationale**: The method's own existing comment already documents "one statement regardless of
  how many there are" as a deliberate Principle IV (Performance) choice — each of the (potentially
  several) auto-declined proposals has a *different* requester/recipient pair, so the four new
  columns cannot be filled with one fixed value the way `status`/`decided_at`/`decline_comment`
  already are; a correlated subquery per column keeps the whole operation one SQL statement instead
  of turning a bulk update into an N-query loop, which the constitution's Performance principle
  flags as exactly the kind of regression that needs justification (or, better, avoiding) on a
  swap/lock-adjacent path.
- **Alternatives considered**: `competing_ids.each { |id| find(id).decline!(...) }` — rejected as a
  straightforward regression from one statement to N, on a path this codebase already optimized once
  for this exact reason; a raw SQL `UPDATE ... FROM` (Postgres-style multi-table update) — rejected,
  not supported by SQLite, whereas a per-column correlated subquery is standard SQL and works
  identically here.

## Where the summary text is composed

- **Decision**: A new `LockerSwapProposal#floor_and_locker_summary` instance method, returning the
  display string for whichever status the proposal is currently in (reading live association values
  for `pending`/`accepted`, the four snapshot columns otherwise).
- **Rationale**: Same reasoning 004 already applied to `swap_lockers`/`in_progress_for?`: state- and
  status-dependent logic belongs on the model, once, so the history view (and any future surface
  that might want the same text) calls one method rather than re-deriving "which columns, which
  wording" in ERB.
- **Alternatives considered**: A Rails helper/presenter — rejected, would split "which values apply"
  (inherently a model-level, status-dependent concern) from "how to render them" for no real benefit,
  and could not be unit-tested at the model level the way the rest of this class already is (see
  `test/models/locker_swap_proposal_test.rb`).
