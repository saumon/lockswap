# Contract: Sign-in Response and Popup

**Feature**: 036-login-greeting-popup

## Routes

| Verb | Path | Action | Change |
|---|---|---|---|
| POST | `/users/sign_in` | `users/sessions#create` | now routed to the app's own subclass; behavior otherwise Devise's |

Declared by adding `sessions: "users/sessions"` to `devise_for :users` in `config/routes.rb`.

## `POST /users/sign_in`

| Situation | Response |
|---|---|
| Valid credentials | 302 to the stored location or root. Flash holds `notice` ("Signed in successfully.") and `greeting` ("coucou"). |
| Invalid credentials, locked or unconfirmed account | Unchanged from today. No `greeting`. |

## Landing page

When the flash holds `greeting`, the shared flash partial renders it as a toast identical to the success toast:

- `role="status"`, class `toast-success`, success icon, dismiss button with the existing "Dismiss notification" label
- same auto-dismiss duration, hover/focus pause and stacking as every toast
- order: "Signed in successfully." then "coucou"
- the next request (reload, navigation) renders no greeting
