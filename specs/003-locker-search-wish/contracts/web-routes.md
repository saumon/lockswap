# Contract: Web Routes

Server-rendered Rails monolith — the "interface" is the three HTTP routes below, all new for this
feature.

| Method & Path | Auth required | Maps to spec | Success | Failure |
| - | - | - | - | - |
| `GET /locker_wishes` | Must be logged in | User Story 2 | Renders the wish list (every active wish, floor sought, wishing user's email, their current floor/locker) plus the viewer's own declare/cancel/edit controls | 302 redirect to `/users/sign_in` if not authenticated |
| `POST /locker_wish` | Must be logged in | User Story 1 (FR-001, FR-002, FR-004, FR-006, FR-007, FR-008) | 302 redirect to `/locker_wishes`, wish recorded or updated in place | 422 re-render `/locker_wishes` with the declare form open and a field error (blank floor) |
| `DELETE /locker_wish` | Must be logged in | User Story 3 (FR-009, FR-010) | 302 redirect to `/locker_wishes`, wish removed (or no-op if none existed) | n/a — this action cannot fail validation |

No `:id` appears in `POST /locker_wish` or `DELETE /locker_wish`: both always act on
`current_user`'s own single wish, never on another user's — the spec places no scenario where one
user manages another's wish.

## Field contract for `POST /locker_wish`

| Param | Required | Notes |
| - | - | - |
| `locker_wish[floor]` | Yes | Rejected if blank or whitespace-only — FR-007, Edge Case. |

Submitting this action while an active wish already exists for the current user updates that wish's
`floor` in place rather than creating a second one — FR-004; the response and redirect are
identical to the first-time declare case.

## Error message contract

- A blank `locker_wish[floor]` submission re-renders `/locker_wishes` with the declare/edit
  disclosure open and a message stating the floor is required — FR-007.
- The rare concurrent-submission race (two declares for the same user racing past the
  already-has-a-wish lookup, caught as `ActiveRecord::RecordNotUnique`) is folded into an
  update-in-place, not surfaced as an error — see data-model.md.

## Display contract (`GET /locker_wishes`)

| Viewer's own wish state | Page shows |
| - | - |
| No active wish | A "I'm looking for a locker" button that reveals the floor field once clicked (FR-005, FR-006) |
| Has an active wish | The current floor they're seeking, a "Cancel wish" control (FR-009), and a "Change floor" disclosure that reveals the same form, pre-filled (FR-004 via US1 scenario 6) |
| Wish declare/edit was just rejected | Same as the relevant state above, but the disclosure is rendered already open with the field error shown (mirrors 002's rejected-edit behavior) |

| Every row in the wish list | Shows |
| - | - |
| Floor sought | `wish.floor` |
| Wishing user | `wish.user.email` (per the resolved clarification) |
| Current floor | The value on file, or "Not set" if the user has never saved one — Edge Case |
| Current locker number | The value on file, or "No locker assigned" if none — reuses 002's exact wording |

The viewing user's own wish appears in this list like anyone else's — it is not filtered out
(User Story 2, Acceptance Scenario 3). An empty active-wish set renders the list empty, not as an
error (User Story 2, Acceptance Scenario 2).

One form partial backs both the first-time declare and a later "Change floor" edit — both are the
same `POST /locker_wish` action, no separate edit route, matching 002's precedent for
`PATCH /locker_profile`.
