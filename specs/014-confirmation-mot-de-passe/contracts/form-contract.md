# Contract: Signup Form (Password Fields)

This is a server-rendered Rails monolith; no new route is introduced by this feature. The existing
`POST /users` route (Devise `registrations#create`) gains one new request field and one new
possible failure reason. The client-side "eye" toggle and blur-then-live mismatch hint are pure
presentation behavior with no network contract of their own — they never send a request.

## Route (unchanged path, extended request/response)

| Method & Path | Auth required | Maps to spec | Success | Failure (new in this feature) |
|---|---|---|---|---|
| `GET /users/sign_up` | Must NOT be logged in | — | Renders signup form with **two** password fields, each with its own visibility toggle (FR-001, FR-005) | — |
| `POST /users` | Must NOT be logged in | FR-002, FR-003, FR-009 | 302 redirect to `/` (unchanged from 001) | 422 re-render form; **new**: `password_confirmation` "doesn't match the password above" error shown distinctly from `password` "too short" error, when the two password fields differ (including when Confirm password is blank) |

No other route, verb, or path changes. `edit_user_registration_path` (account settings) is
unaffected — see [research.md](./research.md) R5.

## Request field contract

| Param | Required | Notes |
|---|---|---|
| `user[password]` | Yes (unchanged from 001) | 8+ characters — existing rule, untouched. |
| `user[password_confirmation]` | New in this feature; must be submitted by the rendered form (always present as a form field, defaults to empty string if the visitor never types in it) | MUST equal `user[password]` exactly, or the request fails validation (FR-002). |

## Client-side behavior contract (no network calls)

| Control | Behavior |
|---|---|
| "Password" field's eye toggle | Click/Enter/Space toggles that field's `type` between `password` and `text`; updates its own `aria-pressed`/`aria-label`; has zero effect on the "Confirm password" field (FR-005, FR-006, FR-008). |
| "Confirm password" field's eye toggle | Identical behavior, fully independent, scoped to its own field (FR-005, FR-006, FR-008). |
| Live mismatch hint | Hidden until "Confirm password" is blurred once; from then on, shown or hidden live as either field changes (FR-004, per `/speckit-clarify` decision — see research.md R3). Never blocks submission by itself; the server-side check (above) is the actual gate (FR-009). |

## Error message contract

Per FR-003, a confirmation mismatch renders under a dedicated locale key
(`activerecord.errors.models.user.attributes.password_confirmation.confirmation`), distinct in
wording from the existing `password.too_short` key, so the two failure reasons are never
confusable in the rendered error list.
