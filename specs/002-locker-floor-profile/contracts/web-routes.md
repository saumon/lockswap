# Contract: Web Routes

Server-rendered Rails monolith — the "interface" is the HTTP route below plus the existing homepage
route from 001-user-authentication, which this feature changes the rendered content of but does not
move.

| Method & Path | Auth required | Maps to spec | Success | Failure |
|---|---|---|---|---|
| `GET /` (homepage, unchanged route from 001) | Must be logged in | User Story 1, User Story 2 | Renders floor + locker number when `floor` is present (FR-003, FR-004); renders the entry form when `floor` is blank (FR-005) | 302 redirect to `/users/sign_in` if not authenticated (unchanged from 001) |
| `PATCH /locker_profile` | Must be logged in | FR-001, FR-002, FR-006, FR-007, FR-008, FR-009, FR-011, FR-012 | 302 redirect to `/`, floor and/or locker number saved | 422 re-render homepage with the entry form and field errors (blank floor, or locker number already taken) |

## Field contract for `PATCH /locker_profile`

| Param | Required | Notes |
|---|---|---|
| `floor` | Yes | Rejected if blank or whitespace-only — FR-007, Edge Case. |
| `locker_number` | No | May be submitted blank to clear/leave unset — FR-002, FR-008. Rejected only if it duplicates a value already held by a different user — FR-011. |

## Error message contract

- A blank `floor` submission re-renders the homepage form with a message stating the floor is
  required — never a generic/unlabeled error (FR-007).
- A `locker_number` submission that collides with another user's saved value re-renders the homepage
  form with a message stating that locker number is not available — it MUST NOT name or otherwise
  identify the other account that holds it (FR-011, Assumptions).
- Both the ordinary validation path and the rare concurrent-submission race (caught as
  `ActiveRecord::RecordNotUnique`) surface this same message, so the two cases are indistinguishable
  to the user (see data-model.md — Persistence-layer backstop).

## Display contract (`GET /`)

The saved `floor` below means the value **on file**, not the value currently in the form — during a
rejected edit the two differ.

| `floor` | `locker_number` | Homepage shows |
|---|---|---|
| present | present | Floor value and locker number (User Story 1, Scenario 1), plus an "Edit locker details" control that reveals the pre-filled form |
| present | absent | Floor value and an explicit "no locker assigned" indicator, never an error (User Story 1, Scenario 2), plus the same "Edit locker details" control |
| absent | — | No display block; the entry form for floor (required) and locker number (optional) is shown openly, as two separate fields, both blank (User Story 2) |

One form partial backs both cases, so the first-time entry (User Story 2) and a later change
(User Story 3) are the same `PATCH /locker_profile` action — no separate edit page or route.

For a user who already has details saved, the form stays hidden until the edit control is
activated, **except** when the last submission was rejected: the disclosure is then rendered already
open so the reported error has a form to be corrected in.
