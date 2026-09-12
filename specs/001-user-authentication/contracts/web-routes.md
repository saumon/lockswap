# Contract: Web Routes

This is a server-rendered Rails monolith, so the "interface" exposed to users is the set of HTTP
routes/pages below (no JSON/API contract is exposed for this feature). Auth routes are provided by
Devise's router helper (`devise_for :users`); the homepage route is application-specific.

| Method & Path | Auth required | Maps to spec | Success | Failure |
|---|---|---|---|---|
| `GET /users/sign_up` | Must NOT be logged in (else redirect to `/`) | User Story 1 | Renders signup form | — |
| `POST /users` | Must NOT be logged in | FR-001, FR-002, FR-003 | 302 redirect to `/` (auto-signed-in), success flash | 422 re-render form with field errors (invalid email, password < 8 chars, duplicate email) |
| `GET /users/sign_in` | Must NOT be logged in (else redirect to `/`) | User Story 2 | Renders login form | — |
| `POST /users/sign_in` | Must NOT be logged in | FR-004, FR-005, FR-006, FR-011 | 302 redirect to `/`, session established (≤30 days) | 422 re-render form with generic "Invalid Email or password" flash (unknown email, wrong password, or account locked) |
| `DELETE /users/sign_out` | Must be logged in | FR-009 | 302 redirect to `/users/sign_in`, session cleared | — |
| `GET /` (homepage) | Must be logged in (else redirect to `/users/sign_in`) | FR-005, FR-008 | Renders homepage | 302 redirect to `/users/sign_in` if not authenticated |

## Redirect rules (cross-cutting)

- Authenticated visitor hits `/users/sign_up` or `/users/sign_in` → redirected to `/` (FR-010).
- Unauthenticated visitor hits `/` → redirected to `/users/sign_in` (FR-008).
- Locked account submits correct credentials during the 15-minute cooldown → treated the same as
  invalid credentials at `POST /users/sign_in` (generic failure message, no account-exists signal) —
  Acceptance Scenario 3 (User Story 3).

## Error message contract

Per FR-006, both "no such email" and "wrong password" cases at `POST /users/sign_in` MUST render the
identical generic message (Devise's default `devise.failure.invalid` i18n key: "Invalid Email or
password.") — never a message that reveals which part was wrong.
