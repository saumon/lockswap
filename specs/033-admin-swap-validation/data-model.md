# Phase 1 Data Model: Administrator Validation of Locker Swap Exchanges

**Feature**: [spec.md](./spec.md) | **Branch**: `033-admin-swap-validation`

One migration: one new nullable, indexed, foreign-keyed column on the existing `locker_swap_proposals`
table. No new table, no new enum value — "awaiting validation" is the existing `accepted` status
(research.md R1).

## `LockerSwapProposal` (existing entity, `db/schema.rb`)

Relevant existing columns (unchanged):

| Column | Type | Set by |
|---|---|---|
| `status` | integer enum (`pending: 0, accepted: 1, declined: 2, withdrawn: 3, completed: 4`) | `accept!`/`decline!`/`withdraw!`/`confirm!` |
| `decided_at` | datetime, nullable | `accept!` (moment of acceptance), then overwritten by `decline!` if later refused, or left as-is through `confirm!` |
| `completed_at` | datetime, nullable | `confirm!` only |
| `decline_comment` | text, nullable | `decline!`'s `comment` argument — reused unchanged as the carrier for an administrator's refusal explanation (FR-006/FR-007) |
| `requester_floor_at_resolution`, `requester_locker_number_at_resolution`, `recipient_floor_at_resolution`, `recipient_locker_number_at_resolution` | string, nullable | `resolution_snapshot`, taken by both `confirm!` and `decline!` at the moment they run |
| `requester_acknowledged_at` | datetime, nullable | homepage read (`unacknowledged_declines`) — unaffected by this feature |

### New column: `admin_decided_by_id`

| Column | Type | Set by |
|---|---|---|
| `admin_decided_by_id` | integer, nullable, FK → `users.id`, indexed | `confirm!(by:)` / `decline!(comment, by:)` when an administrator calls either — `nil` when either party decided their own exchange (unchanged existing calls that never pass `by:`) |

Migration shape (mirrors `admin_granted_by_id`/`locker_edited_by_id`/`search_cancelled_by_id` — research.md
R5):

```ruby
add_column :locker_swap_proposals, :admin_decided_by_id, :integer
add_index :locker_swap_proposals, :admin_decided_by_id
add_foreign_key :locker_swap_proposals, :users, column: :admin_decided_by_id
```

Model associations:

```ruby
# LockerSwapProposal
belongs_to :admin_decided_by, class_name: "User", optional: true

# User
has_many :swap_decisions_made, class_name: "LockerSwapProposal",
         foreign_key: :admin_decided_by_id, dependent: :nullify, inverse_of: :admin_decided_by
```

`dependent: :nullify` on the `User` side (not `:destroy`) for the same reason the three existing siblings
use it: an administrator's own account being cancelled later must not delete, or block the deletion of,
every proposal they ever validated or refused (FR-014's record is meant to outlive the administrator who
made it, same as `admin_granted_by`/`locker_edited_by`/`search_cancelled_by` already do).

### Method signature changes

```ruby
# Unchanged guard (accepted? only) — by: is new
def confirm!(by: nil)
  return false unless accepted?

  transaction do
    snapshot = resolution_snapshot
    swap_lockers
    update!(status: :completed, completed_at: Time.current, admin_decided_by: by, **snapshot)
    requester.locker_wish&.destroy
    recipient.locker_wish&.destroy
  end

  true
end

# Guard widens from `pending?` to `pending? || accepted?` — by: is new
def decline!(comment = nil, by: nil)
  return false unless pending? || accepted?

  update!(status: :declined, decided_at: Time.current, decline_comment: comment.presence,
          admin_decided_by: by, **resolution_snapshot)
end
```

Every existing caller (`LockerSwapProposalsController#decline`, the retired `#confirm`) keeps working
unchanged — neither passes `by:`, so `admin_decided_by` stays `nil` exactly as it implicitly always has been
for a decision either party made about their own exchange.

### State / lifecycle

```
        propose               accept!                 confirm!(by: admin)
pending ────────► pending ────────────► accepted ─────────────────────────► completed
  │  ▲                │                    │
  │  │ withdraw!       │ decline!           │ decline!(by: admin)   [NEW: reachable from here too]
  │  └─────────────────┘                    │
  ▼                                         ▼
withdrawn                                declined
```

- **Entry into "awaiting validation"**: unchanged — `accept!`, the recipient's own yes. No new event
  produces this state; it is the same `accepted` a proposal has always reached (research.md R1).
- **New exit, `accepted → declined` via an administrator**: `decline!`'s widened guard is what makes this
  reachable. Locker details are untouched (`decline!`'s body never calls `swap_lockers`); the two partial
  unique indexes on `accepted` (`index_swap_proposals_accepted_requester`/`_recipient`) release the moment
  the status leaves `accepted`, so both parties immediately stop counting as "already in an exchange"
  (FR-008, `in_progress_for?` reads `accepted.exists?`).
- **Existing exit, `accepted → completed` via an administrator instead of the recipient**: unchanged body,
  new attribution. `LockerSwapProposalsController#confirm` (the caller that used to reach this for the
  recipient) is deleted (research.md R8); `Admin::SwapValidationsController#validate` is the only caller
  left that can invoke `confirm!` on an arbitrary (not `current_user`-scoped) `accepted` row.
- **No new state, no new transition table needed for "already accepted before rollout"**: such a row is
  already sitting in the `accepted` state on the existing lifecycle diagram above; it enters the admin queue
  through the same `LockerSwapProposal.accepted` scope as any other (research.md R11).

### Validation / invariant summary

| Rule | Enforced by |
|---|---|
| A proposal can only be validated or refused while `accepted?` | `confirm!`'s unchanged guard; `decline!`'s widened guard (both `return false` otherwise) |
| Refusing never changes either party's floor/locker | `decline!`'s body has no `swap_lockers` call (unchanged) |
| Validating always swaps and completes, same as before | `confirm!`'s body (unchanged) |
| A refused-by-admin exchange stops blocking either party | Existing `in_progress_for?`/partial unique indexes read `status = 1 (accepted)` only — leaving that status via `decline!` already releases both, no new code needed |
| Who (if anyone) administratively decided a proposal, permanently | `admin_decided_by_id`, `dependent: :nullify` so the record survives the deciding administrator's own account being later cancelled |
| At most one row per user pair may be `accepted`/`pending` at a time | `index_swap_proposals_accepted_requester`/`_recipient`, `index_swap_proposals_pending_pair` (existing, unchanged — this feature adds no new proposal-creation path) |

## Other entities

No other entity is added, removed, or changed. `Admin::SwapValidationsController` reads and writes only
`LockerSwapProposal` rows (through the model methods above) and reads `User`/`LockerMapEntry` for display,
the same associations `home/_swap_exchange_in_progress.html.erb` and
`locker_swap_proposals/_history_table.html.erb` already read (see contracts/admin-swap-validation.md).
