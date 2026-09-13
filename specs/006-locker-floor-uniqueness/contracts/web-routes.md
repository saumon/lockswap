# Contract: Web Routes (delta from 002)

No route changes. This feature updates the **validation contract** of the existing
`PATCH /locker_profile` route introduced in 002-locker-floor-profile — specifically, what counts as
a collision and what the resulting error means. `GET /` (homepage display) is unaffected: it already
displays `floor` and `locker_number` exactly as saved, independent of how uniqueness was checked.

| Method & Path | Auth required | Maps to spec | Success | Failure |
|---|---|---|---|---|
| `PATCH /locker_profile` (unchanged route from 002) | Must be logged in | FR-001 through FR-008 | 302 redirect to `/`, floor and/or locker number saved | 422 re-render homepage with the entry form and field errors (blank floor, or locker number already taken **on that floor**) |

## Field contract for `PATCH /locker_profile` (updated)

| Param | Required | Notes |
|---|---|---|
| `floor` | Yes | Unchanged from 002: rejected if blank or whitespace-only (FR-007). Now doubles as the scope for the locker-number collision check below. |
| `locker_number` | No | **Updated**: rejected only if it duplicates a value already held by a *different user on the same floor* (FR-003). The identical value already saved by a different user on a *different* floor is no longer a collision and is accepted (FR-001, FR-002). |

## Error message contract (updated)

- A blank `floor` submission: unchanged from 002 — re-renders the homepage form with a message
  stating the floor is required.
- A `locker_number` submission that collides with another user's saved value **on the same floor**:
  re-renders the homepage form with a message stating that locker number is not available *on that
  floor* — still MUST NOT name or otherwise identify the other account that holds it (FR-003). This
  replaces 002's floor-agnostic "not available" wording.
- Both the ordinary validation path and the concurrent-submission race (still caught as
  `ActiveRecord::RecordNotUnique`, now from the composite index) surface this same message — see
  data-model.md.

## Display contract (`GET /`)

Unchanged from 002 — the homepage renders exactly what is on file for `floor` and `locker_number`
with no new state introduced by this feature. See `specs/002-locker-floor-profile/contracts/web-routes.md`
for the full display contract.
