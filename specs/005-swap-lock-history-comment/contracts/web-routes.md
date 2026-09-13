# Contract: Web Routes

Server-rendered Rails monolith — the "interface" is the HTTP routes below. No new route is added;
this feature changes the behavior and rendered content of two existing routes from 002 and 004.

| Method & Path | Auth required | Maps to spec | Success | Failure |
| - | - | - | - | - |
| `PATCH /locker_profile` (existing, 002, behavior extended) | Must be logged in | User Story 1 (FR-001, FR-002, FR-003, FR-004) | Unchanged when the user has no active proposal, or is providing a floor/locker number for the first time: 302 redirect to `/`, values saved. When the user has an active proposal (`LockerSwapProposal.active_for?(current_user)`) **and** is changing an already-saved `floor` and/or `locker_number`: submission rejected | 422, re-renders the homepage with a validation error on the locked field(s) explaining they cannot be changed while an active swap proposal exists (FR-003); a `locker_number` uniqueness conflict (002) is still reported the same way it always was, independent of this feature |
| `GET /locker_swap_proposals` (existing, 004, rendered content extended) | Must be logged in | User Story 2 (FR-005, FR-006, FR-007) | Renders the existing read-only history — direction, counterparty, date, status, decline comment — plus a new column: a system-generated summary of the floor/locker number proposed (`pending`/`accepted`/`declined`/`withdrawn`) or exchanged (`completed`), present on every row with no manual entry (FR-005) | Unchanged from 004 — 302 redirect to `/users/sign_in` if not authenticated |
| `GET /` (existing, 002/004, rendered content extended) | Must be logged in | User Story 1 | When the viewer has a saved floor and `LockerSwapProposal.active_for?(current_user)` is true: the existing "Edit locker details" disclosure is replaced by a locked notice explaining the fields cannot be changed while a swap proposal is active, naming no specific action (plain explanatory text, Constitution Principle III). Unchanged otherwise (no saved floor yet → first-time entry form, unaffected by the lock; no active proposal → the existing disclosure, unaffected) | N/A (read-only difference) |

No new route, no new controller action. `LockerProfilesController#update` (002) and
`LockerSwapProposalsController#index` (004) are the only two actions whose behavior changes; both
remain scoped to `current_user` exactly as before.

## Field contract for `PATCH /locker_profile`

| Param | Required | Notes |
| - | - | - |
| `user[floor]` | Conditionally | Rejected only if it differs from the currently-saved value *and* the user has an active proposal (FR-001); otherwise behaves exactly as in 002. |
| `user[locker_number]` | No | Rejected only if it differs from the currently-saved value *and* the user has an active proposal (FR-002); otherwise behaves exactly as in 002 (optional, unique). |

## Error message contract

- Changing an already-saved floor while locked: rejected with a message naming the floor as locked
  because of an active swap proposal (FR-001, FR-003).
- Changing an already-saved locker number while locked: rejected with a message naming the locker
  number as locked for the same reason (FR-002, FR-003).
- Providing a floor or locker number for the first time: never rejected for this reason, even while
  the user has an active proposal (FR-001, FR-002 — "already-saved" clarification).
- Both fields submitted as changes while locked: both errors are reported together on the same
  rejected submission (Edge Cases).

## Display contract (`GET /locker_swap_proposals` — history, new column)

| Column | Source | Shown when |
| - | - | - |
| Locker details | `proposal.floor_and_locker_summary` | Always — every row, every status (FR-005). Reads live `requester`/`recipient` floor/locker number for `pending`/`accepted` rows; reads the frozen `..._at_resolution` snapshot columns for `declined`/`withdrawn`/`completed` rows (FR-006, FR-009; see data-model.md). |

This column is additive: the existing "Comment" column (`decline_comment`) is unchanged and keeps
showing only the user-entered decline comment, exactly as in 004 — the two are shown side by side,
neither replacing the other (FR-008, clarification).

## Display contract (`GET /` — homepage, "Edit locker details" section)

| Situation | Rendered content |
| - | - |
| No saved floor yet | Unchanged from 002: the plain first-time entry form, regardless of any active proposal. |
| Saved floor exists, no active proposal | Unchanged from 002/004: the "Edit locker details" disclosure, closed by default. |
| Saved floor exists, `LockerSwapProposal.active_for?(current_user)` is true, and the last submission (if any) was not rejected | A locked notice replaces the disclosure, stating the floor and locker number cannot be changed while an active swap proposal exists (FR-003). |
| Saved floor exists, `LockerSwapProposal.active_for?(current_user)` is true, and the current re-render follows a rejected submission (`current_user.errors.any?`) | The disclosure is shown open, with the validation error(s) rendered via the existing `devise/shared/error_messages` partial — a defense-in-depth path in case the lock was bypassed (e.g., a direct request), so the rejection is never a dead end (Constitution Principle III). |
