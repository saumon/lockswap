# Phase 0 Research: Locker Swap Proposals

The technology stack is fixed by the existing codebase (Ruby on Rails 8.1.3 monolith, established in
001-user-authentication, extended in 002-locker-floor-profile and 003-locker-search-wish) — there are
no framework/language choices left open. The open questions are about how to model a proposal
between two users, enforce the "one active exchange at a time" and "no duplicate pending proposal"
rules under concurrency, and where the new UI surfaces live. All `NEEDS CLARIFICATION` items are
resolved below.

## A new table for the proposal itself

- **Decision**: Introduce `locker_swap_proposals` (`requester_id`, `recipient_id`, `status`,
  `decline_comment`, `decided_at`, `completed_at`, `requester_acknowledged_at`), with
  `belongs_to :requester, class_name: "User"` / `belongs_to :recipient, class_name: "User"`, and
  reciprocal `has_many :sent_swap_proposals` / `has_many :received_swap_proposals` on `User`.
- **Rationale**: A proposal is its own entity with an independent multi-step lifecycle (pending →
  accepted/declined/withdrawn → completed) spanning two distinct users in two distinct roles — it
  cannot be modeled as a column on `users` (unlike 002's `floor`/`locker_number`) and is not a
  single-user declaration like 003's `LockerWish`. This mirrors 003's own reasoning for giving
  `LockerWish` its own table.
- **Alternatives considered**: Reusing `LockerWish` itself as the proposal record (rejected — a wish
  is one user's standing declaration with no counterparty and no lifecycle beyond
  declared/cancelled; conflating it with a two-party, multi-state proposal would violate Constitution
  Principle I's single-responsibility guidance).

## Status as a Rails enum, not booleans

- **Decision**: `status` is an integer-backed `enum` with five values: `pending` (0, default),
  `accepted` (1, i.e. "exchange in progress"), `declined` (2), `withdrawn` (3), `completed` (4).
- **Rationale**: The spec's own Key Entities section describes exactly this state set. An enum gives
  named scopes (`LockerSwapProposal.pending`, `.accepted`, ...) for free, which every FR below reads
  as "the current active proposal(s)" queries.
- **Alternatives considered**: Separate boolean columns (`accepted`, `declined`, `withdrawn`,
  `completed`) — rejected, allows invalid combinations (e.g., both `declined` and `completed` true)
  that an enum makes structurally impossible.

## Enforcing "no duplicate pending proposal between the same pair" (FR-018)

- **Decision**: A partial unique DB index on `[requester_id, recipient_id]` `WHERE status = 0`
  (pending), plus an application-level lookup in `create` that checks for an existing pending
  proposal between the two users before building a new one. A `rescue ActiveRecord::RecordNotUnique`
  in the controller catches the race (two submissions for the same pair passing the lookup before
  either commits) and re-renders with a "you already have a pending proposal to this person"
  message rather than a 500.
- **Rationale**: Same pattern 002 (`locker_number` uniqueness) and 003 (`locker_wishes.user_id`
  uniqueness) already established: the DB constraint is the actual correctness guarantee under
  concurrency; the application check exists for the common (non-race) case's error message.
- **Alternatives considered**: Application-level check alone (rejected — not race-safe, same
  reasoning as 002/003).

## Enforcing "at most one exchange in progress per user, in either role" (FR-003, FR-004)

- **Decision**: Two partial unique indexes — `requester_id WHERE status = 1` and
  `recipient_id WHERE status = 1` — mean a user can be the requester of at most one accepted
  proposal, and the recipient of at most one accepted proposal, at the database level. On top of
  that, a shared lookup method (`LockerSwapProposal.in_progress_for?(user)`, checking
  `accepted.where("requester_id = :id OR recipient_id = :id", id: user.id).exists?`) is used as the
  application-level gate in three places: creating a proposal (neither the requester nor the
  target recipient may already be `in_progress_for?`), and accepting one (re-checked inside the same
  transaction immediately before flipping status, closing the race window between two proposals
  involving the same user being accepted near-simultaneously).
- **Rationale**: A single partial unique index cannot by itself express "this user appears in
  neither of two FK columns more than once across both roles combined" — SQLite (like most SQL
  databases) has no native cross-column uniqueness constraint of that shape. Given this app's scale
  (a single building's locker population, not a high-frequency trading system), pairing the two
  same-column partial indexes (which do catch the two most likely single-role races) with an
  application-level, transaction-scoped re-check immediately before the state transition that would
  create a second commitment is proportionate: it closes the practical race window without
  introducing a join table purely to satisfy a corner case this system's real concurrency profile is
  very unlikely to hit. This is a deliberate, documented judgment call, not an oversight.
- **Alternatives considered**: A separate `locker_swap_participants` join table (`proposal_id,
  user_id, role`) with one partial unique index on `user_id WHERE proposal.status = accepted`
  (rejected — meaningfully more complexity, an extra join on every check, for a race window this
  system's expected concurrency does not warrant); pessimistic row locking across both `users` rows
  on every accept (rejected — same reasoning, plus SQLite's single-writer model already serializes
  writes at the file level).

## Self-targeting and recipient eligibility (FR-002, FR-017)

- **Decision**: Model validations: `recipient_id` must differ from `requester_id` (FR-002); the
  recipient must currently have a `LockerWish` (FR-017), checked via `recipient.locker_wish.present?`
  at creation time.
- **Rationale**: Both are simple presence/comparison checks with no concurrency concern (a wish
  being cancelled between page-load and submission is the only race here, and it is already covered
  by the Edge Cases as "reject the submission" — no different outcome needed than the direct
  validation failure).
- **Alternatives considered**: none — these are unambiguous rules directly from the spec.

## Withdrawing a pending proposal (FR-019, FR-020)

- **Decision**: `LockerSwapProposal#withdraw!` transitions `pending → withdrawn`, settable only by
  the requester, only while `pending`. A `before_action` in the controller scopes the lookup to
  `current_user.sent_swap_proposals.pending`, so attempting to withdraw someone else's proposal, or
  one that already moved past `pending`, 404s rather than silently no-op'ing.
- **Rationale**: Directly implements the resolved clarification; scoping the lookup through the
  association is the same defensive-scoping pattern already used for `current_user.locker_wish` in
  003.
- **Alternatives considered**: none.

## Auto-declining competing proposals on acceptance (FR-011, Edge Cases)

- **Decision**: `LockerSwapProposal#accept!` runs in one transaction: (1) re-check neither party is
  already `in_progress_for?` (closes the accept-side race noted above), (2) set `status: :accepted,
  decided_at: Time.current` on itself, (3) find every other `pending` proposal where `requester_id`
  or `recipient_id` equals either this proposal's `requester_id` or `recipient_id`, and for each,
  set `status: :declined, decided_at: Time.current, decline_comment: <system message>,
  requester_acknowledged_at: nil`.
- **Rationale**: `requester_acknowledged_at: nil` on every auto-declined row reuses exactly the same
  homepage-notification mechanism as a manual decline (see below) — the affected requester (who may
  be either of the two people who just completed this acceptance, or an uninvolved third party who
  had proposed to one of them) sees the decline on their next homepage visit without any
  special-cased notification path.
- **Alternatives considered**: Leaving other pending proposals untouched and only blocking their
  future acceptance (rejected in clarification — auto-decline was the chosen answer, and it avoids
  stale, un-actionable proposals lingering in everyone's pending lists).

## Confirming completion: the actual floor/locker swap (FR-013)

- **Decision**: `LockerSwapProposal#confirm!`, callable only by the recipient and only while
  `accepted`, runs in one transaction: read both users' current `floor`/`locker_number`, write each
  user's pair of values to the other user via a plain `update!` (not `update_columns` — no callback
  bypass is needed since the profile's `on: :locker_profile_update`-scoped validations do not run on
  a plain `update!`, exactly as 003's `LockerWishesController` already relies on for `LockerWish`),
  then set `status: :completed, completed_at: Time.current` on the proposal, then destroy each
  user's `LockerWish` if present (the underlying need is now resolved).
- **Rationale**: `floor`/`locker_number` already tolerate `nil` (002's "no locker assigned" case), so
  swapping is safe even when one side has no locker on file — the "no-locker" side simply receives
  the other's values and the other side receives `nil`. The existing `locker_number` uniqueness
  validation is scoped to `on: :locker_profile_update` and therefore is not re-triggered by this
  plain update, avoiding an irrelevant validation context on a system-driven change.
- **Alternatives considered**: Requiring the requester to also confirm (rejected — spec explicitly
  gives this action only to the recipient); keeping the wish record around after completion
  (rejected — Edge Cases says a completed exchange's wishes are no longer open invitations, and an
  already-fulfilled wish has no further purpose, consistent with 003's own "cancelling removes the
  row outright" precedent).
- **Performance note (Constitution Principle IV)**: this is the swap/lock execution path the
  constitution calls out by name. The PR must include a before/after measurement — expected trivial
  (two single-row `UPDATE`s plus at most two single-row `DELETE`s in one transaction), but the
  measurement is still required evidence, not assumed.

## Suspending a wish while an exchange is in progress (Edge Cases)

- **Decision**: `LockerWishesController#all_locker_wishes` excludes any wish whose owner currently
  has an accepted proposal: `LockerWish.where.not(user_id: LockerSwapProposal.in_progress_user_ids)`,
  where `in_progress_user_ids` is `accepted.pluck(:requester_id, :recipient_id).flatten.uniq`. The
  wish row itself is never modified or destroyed by acceptance — only hidden from the list — so a
  later decline-equivalent situation is impossible (there is no path back from `accepted` except
  `completed`) and, on `confirm!`, the wish is destroyed outright per the section above.
- **Rationale**: Matches the Edge Cases wording exactly ("no longer treated as open invitations
  while the exchange is in progress or after it is completed") without adding a new column to
  `LockerWish` — the exclusion is computed from the proposal side, keeping `LockerWish` itself
  unchanged from 003.
- **Alternatives considered**: A `suspended` boolean on `LockerWish` (rejected — redundant state
  that must be kept in sync with the proposal's status; computing it from `LockerSwapProposal`
  avoids a second source of truth).

## Where the new UI lives

- **Decision**:
  - **Propose** (US1): a "Propose swap" `button_to` on each eligible row of the existing
    `/locker_wishes` list (003) — eligible meaning not the viewer's own row, and no pending proposal
    already exists from the viewer to that row's user. If the viewer themselves currently has an
    exchange in progress, every "Propose swap" control on the page is replaced with an explanatory
    note instead (FR-004) rather than omitted silently.
  - **Respond and confirm** (US2, US4): surfaced directly on the existing homepage (001/002), which
    is already the site's per-user landing/notification surface — pending received proposals get
    Accept and a "Decline" disclosure (`<details>`, matching 002/003's no-JavaScript pattern) with
    an optional comment field; pending sent proposals get a "Withdraw" control; an accepted/
    in-progress exchange the viewer is party to shows its status, with a "Confirm exchange
    completed" control shown only to the recipient.
  - **History** (US5): a new, separate `/locker_swap_proposals` page (`LockerSwapProposalsController
    #index`), read-only, listing every proposal the viewer sent or received, each with its dates,
    status, and decline comment if any.
- **Rationale**: US1 is explicitly scoped to the Locker Wishes screen by the spec text itself. US2's
  accept/decline/confirm actions need to live somewhere the user will actually see them without
  hunting, and the homepage is already established as exactly that surface (002's "fill in your
  floor" prompt lives there for the same reason). Keeping History separate and read-only matches the
  spec's own framing of it as a review/audit screen ("afficher... l'historique"), distinct from the
  action surface.
- **Alternatives considered**: Putting accept/decline/confirm controls on the History page instead
  of the homepage (rejected — conflates an audit/read screen with an action screen, and the spec
  only asks the homepage to carry notifications); a dedicated single-proposal `show` page per
  proposal (rejected — no scenario requires drilling into one proposal beyond what a homepage row or
  history row already displays).

## Testing strategy

- **Decision**: `test/models/locker_swap_proposal_test.rb` for every validation, the enum
  transitions, the auto-decline cascade, the confirm swap, and the two race backstops (mirroring
  003's hand-rolled `save` stub pattern, since no mocking gem is bundled); `test/controllers/
  locker_swap_proposals_controller_test.rb` for the HTTP-level authorization scoping (withdrawing/
  accepting/declining/confirming someone else's proposal, wrong role, wrong state) and the races;
  `test/system/locker_swap_proposal_test.rb` (Capybara, headless Chrome) covering User Stories 1–5's
  acceptance scenarios end-to-end.
- **Rationale**: Matches the constitution's Testing Standards principle and 001/002/003's existing,
  already-configured stack — no new test dependency.
- **Alternatives considered**: RSpec (rejected — not used anywhere in this codebase).

**Output**: All Technical Context items resolved; no `NEEDS CLARIFICATION` markers remain.
