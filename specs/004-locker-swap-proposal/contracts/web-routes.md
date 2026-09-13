# Contract: Web Routes

Server-rendered Rails monolith — the "interface" is the HTTP routes below. All are new for this
feature except the homepage route (`GET /`), whose response gains new content.

| Method & Path | Auth required | Maps to spec | Success | Failure |
| - | - | - | - | - |
| `POST /locker_swap_proposals` | Must be logged in | User Story 1 (FR-001, FR-002, FR-017, FR-018) | 302 redirect to `/locker_wishes`, proposal recorded as `pending` | 302 redirect back with an error message: self-target (FR-002), recipient has no active wish (FR-017), recipient or requester already in an exchange in progress (FR-003, FR-004), or a pending proposal to this recipient already exists (FR-018) |
| `DELETE /locker_swap_proposals/:id` | Must be logged in, must be the proposal's requester, proposal must be `pending` | User Story 1 (FR-019, FR-020) | 302 redirect to `/`, proposal marked `withdrawn` | 404 if not found among the current user's own pending sent proposals |
| `PATCH /locker_swap_proposals/:id/accept` | Must be logged in, must be the proposal's recipient, proposal must be `pending` | User Story 2 (FR-005, FR-006, FR-011) | 302 redirect to `/`, proposal marked `accepted`; any other pending proposal touching either party is auto-declined | 404 if not found among the current user's own pending received proposals; redirect with an error if the party is no longer eligible (race, FR-003/FR-004 re-check) |
| `PATCH /locker_swap_proposals/:id/decline` | Must be logged in, must be the proposal's recipient, proposal must be `pending` | User Story 2 (FR-005, FR-007, FR-008) | 302 redirect to `/`, proposal marked `declined`, optional `decline_comment` stored | 404 if not found among the current user's own pending received proposals |
| `PATCH /locker_swap_proposals/:id/confirm` | Must be logged in, must be the proposal's recipient, proposal must be `accepted` | User Story 4 (FR-012, FR-013) | 302 redirect to `/`, floor/locker swapped between both users, proposal marked `completed`, both users' wishes (if any) removed | 404 if not found among the current user's own accepted received proposals |
| `GET /locker_swap_proposals` | Must be logged in | User Story 5 (FR-015) | Renders the read-only history: every proposal the viewer sent or received, each with its date, status, and decline comment if any | 302 redirect to `/users/sign_in` if not authenticated |
| `GET /` (existing route, extended) | Must be logged in | User Story 3 (FR-009) | Renders, in addition to existing 001/002 content: pending proposals received (with Accept/Decline), pending proposals sent (with Withdraw), any exchange in progress the viewer is party to (with Confirm shown only to the recipient), and any newly-declined sent proposal (shown once, then acknowledged) | 302 redirect to `/users/sign_in` if not authenticated (unchanged from 001) |

None of the `locker_swap_proposals` actions accept an arbitrary `:id` from another user's
proposals — every lookup is scoped through `current_user.sent_swap_proposals` or
`current_user.received_swap_proposals` first, so attempting to act on a proposal the current user is
not a party to (or not in the required role for) 404s rather than exposing or mutating someone
else's record.

## Field contract for `POST /locker_swap_proposals`

| Param | Required | Notes |
| - | - | - |
| `locker_swap_proposal[recipient_id]` | Yes | Must identify a user with an active `LockerWish`, other than the current user, not already party to an exchange in progress — FR-002, FR-003, FR-017. |

## Field contract for `PATCH /locker_swap_proposals/:id/decline`

| Param | Required | Notes |
| - | - | - |
| `locker_swap_proposal[decline_comment]` | No | Free-form text, stored verbatim if present — FR-008. |

## Error message contract

- Self-targeted proposal: rejected with a message that a proposal cannot be sent to yourself
  (FR-002).
- Proposal to a user without an active wish, or to one already in an exchange in progress: rejected
  with a message naming the reason (FR-003, FR-017).
- Proposal from a user who is themselves already in an exchange in progress: rejected with a message
  explaining they cannot start a new swap while one is underway (FR-004).
- Duplicate pending proposal to the same recipient (including the rare concurrent-submission race
  caught as `ActiveRecord::RecordNotUnique`): rejected with a message that a proposal to this person
  is already pending (FR-018).
- Accept/decline/confirm/withdraw attempted on a proposal not in the required state, or by a user
  not in the required role: 404 (the lookup is scoped so this record is simply not "theirs" in that
  context) — see data-model.md's state transitions for which actions are valid in which state.

## Display contract (`GET /` — homepage additions)

| Section | Shown when | Content |
| - | - | - |
| Pending proposals received | `current_user.received_swap_proposals.pending.any?` | Each proposer's identifier, an Accept control, and a Decline disclosure with an optional comment field (FR-005–FR-008) |
| Pending proposals sent | `current_user.sent_swap_proposals.pending.any?` | Each recipient's identifier and a Withdraw control (FR-019) |
| Exchange in progress | The viewer is party (either role) to an `accepted` proposal | The other party's identifier and status; a "Confirm exchange completed" control shown only when the viewer is the recipient (FR-012, FR-013) |
| Recently declined (sent) | `current_user.sent_swap_proposals.declined.where(requester_acknowledged_at: nil).any?` | The recipient's identifier and the decline comment if any (FR-007); marked acknowledged immediately after this render, so it does not reappear |

## Display contract (`GET /locker_swap_proposals` — history)

| Column | Source |
| - | - |
| Direction | "Sent" or "Received", depending on whether the viewer is `requester` or `recipient` on that row |
| Counterparty | The other party's identifier |
| Date | `created_at` |
| Status | `pending` / `accepted` (in progress) / `declined` / `withdrawn` / `completed` |
| Decline comment | Shown when `status` is `declined` and a comment is present |

Read-only: no accept/decline/confirm/withdraw controls appear on this page (see research.md — the
homepage is the action surface; this page is the audit/review surface, per User Story 5).
