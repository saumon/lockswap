# Phase 1 Data Model: Locker Swap Proposals

## Entity: Locker Swap Proposal (new `locker_swap_proposals` table)

See [research.md](./research.md) for why this is a new table, why status is an enum, and why the
concurrency guarantees are shaped the way they are.

| Field | Type | Notes |
| - | - | - |
| `id` | primary key | |
| `requester_id` | integer, not null, FK → `users.id` | The user who sent the proposal (spec's "requester"). |
| `recipient_id` | integer, not null, FK → `users.id` | The user who received it (spec's "recipient"); must have an active `LockerWish` at creation time (FR-017). |
| `status` | integer, not null, default `0` | Enum: `pending` (0), `accepted` (1, i.e. "exchange in progress"), `declined` (2), `withdrawn` (3), `completed` (4). |
| `decline_comment` | text, nullable | Set only when `status` is `declined` — user-entered (FR-008) or system-generated for an auto-decline (FR-011). |
| `decided_at` | datetime, nullable | Set when the proposal leaves `pending` (accepted, declined, or withdrawn). |
| `completed_at` | datetime, nullable | Set only when `status` becomes `completed` (FR-013). |
| `requester_acknowledged_at` | datetime, nullable | Set once the requester's homepage has displayed this proposal's `declined` outcome (FR-007, FR-009); drives the "recently declined" homepage query without an unbounded, permanently-visible notification. |
| `created_at` / `updated_at` | datetime | Standard Active Record timestamps. `created_at` is "the date of each proposal" in history (FR-015). |

### Associations

- `LockerSwapProposal belongs_to :requester, class_name: "User"`
- `LockerSwapProposal belongs_to :recipient, class_name: "User"`
- `User has_many :sent_swap_proposals, class_name: "LockerSwapProposal", foreign_key: :requester_id, dependent: :destroy`
- `User has_many :received_swap_proposals, class_name: "LockerSwapProposal", foreign_key: :recipient_id, dependent: :destroy`

### Validation rules

- `requester`, `recipient`: required.
- `recipient_id != requester_id` — FR-002 (no self-targeted proposal).
- `recipient` must have a `LockerWish` on file at creation time — FR-017.
- Neither `requester` nor `recipient` may already be party to an `accepted` proposal (in either
  role) — FR-003, FR-004. Checked via `LockerSwapProposal.in_progress_for?(user)`.
- No existing `pending` proposal between this exact `requester_id`/`recipient_id` pair — FR-018.

### Persistence-layer backstops (see research.md for full rationale)

| DB constraint | Guarantees |
| - | - |
| Partial unique index on `[requester_id, recipient_id]` `WHERE status = 0` | At most one pending proposal per requester→recipient pair (FR-018), even under a concurrent double-submit. |
| Partial unique index on `requester_id` `WHERE status = 1` | A user is the requester of at most one accepted (in-progress) exchange at a time. |
| Partial unique index on `recipient_id` `WHERE status = 1` | A user is the recipient of at most one accepted (in-progress) exchange at a time. |

`LockerSwapProposalsController#create` rescues `ActiveRecord::RecordNotUnique` (the duplicate-pending
race) and re-renders with a "you already have a pending proposal to this person" message.
`LockerSwapProposal#accept!` re-checks `in_progress_for?` for both parties inside its own transaction
immediately before flipping `status`, closing the accept-side race between two proposals involving
the same user.

### State transitions

```text
[pending]  (created by requester, targeting an eligible recipient — US1)
  --(recipient accepts)-->            [accepted]   ("exchange in progress" — US2 scenario 1, FR-006)
  --(recipient declines, w/ optional comment)--> [declined]  (US2 scenario 2-4, FR-007, FR-008)
  --(requester withdraws)-->          [withdrawn]  (FR-019, FR-020)
  --(another of either party's proposals is accepted first)--> [declined]  (auto-decline, FR-011)

[accepted]
  --(recipient confirms the exchange took place)--> [completed]  (US4, FR-013)
  --(never confirmed)-->              stays [accepted] indefinitely — no timeout, no cancel path
                                       (resolved clarification; out of scope for this feature)

[declined] / [withdrawn] / [completed]
  --(any action)-->                   rejected — these are final states (FR-010, FR-014, FR-020)
```

- A brand-new proposal from the same requester to the same recipient after a `declined` or
  `withdrawn` outcome is allowed and creates a new row (FR-018 only blocks a second *pending* row
  between the same pair, not a later one after the earlier row is resolved).

## Effect on Locker Wish (existing entity, 003 — unchanged schema, behavior extended by reference)

`LockerWish` itself gains no column and no new validation. Its treatment changes only in how it is
*read*:

| Situation | Wish list (`/locker_wishes`) behavior |
| - | - |
| Owner has no `accepted` proposal | Shown normally, as in 003. |
| Owner is party (either role) to an `accepted` proposal | Excluded from the list — "no longer treated as an open invitation" (Edge Cases) — until the exchange completes or, if it somehow re-opens, no path back to non-accepted exists except `completed`. |
| Exchange reaches `completed` | The wish row is destroyed outright (both requester's and recipient's, if present) — the need is now resolved, mirroring 003's "cancelling removes the row outright" precedent. |

## Effect on User Locker Profile (existing entity, 002 — read and written here)

`User.floor` / `User.locker_number` gain no new validation. `LockerSwapProposal#confirm!` is the only
place this feature writes to them: it swaps the two users' current values via a plain `update!`
(the `on: :locker_profile_update`-scoped presence/uniqueness validations do not fire on a plain
`update!`, so this system-driven swap is not subject to end-user profile validation rules — see
research.md).

## Relationships

- `locker_swap_proposals.requester_id` → `users.id`
- `locker_swap_proposals.recipient_id` → `users.id`
- `locker_swap_proposals` reads `users.id`'s associated `locker_wish` (existence check at creation;
  destroyed on completion) and `users.floor` / `users.locker_number` (swapped on completion).
- No other table or entity is introduced or referenced.
