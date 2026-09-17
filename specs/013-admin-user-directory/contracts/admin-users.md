# Contract: Admin → Users

This is a server-rendered Rails monolith with no public/JSON API (see `plan.md` Technical Context),
so the interface this feature exposes is the route + full-page-response contract below, in the same
spirit as the app's other read-only listing route (`GET /locker_swap_proposals`).

## Route

```
GET /admin/users   → admin/users#index   (route helper: admin_users_path)
```

No other HTTP verb or action is exposed under `/admin` by this feature (FR-009 — read-only).

## Navigation entry contract

- Rendered inside `shared/_site_menu_items.html.erb`, the single source of both the narrow and wide
  navigation treatments (012).
- Present **if and only if** `current_user.admin?` is true (FR-003, FR-004).
- Structure: an "Admin" disclosure (`<details>`/`<summary>Admin</summary>`) containing one link,
  labelled "Users", pointing at `admin_users_path` (FR-005).
- Never rendered at all — not present-but-hidden — for a non-administrator; the check happens
  server-side in the view, so the markup for it does not reach a non-admin's page.

## Request/response contract

| Caller | Precondition | Response |
|---|---|---|
| Anonymous visitor | not signed in | `302` redirect to `new_user_session_path` (existing Devise `authenticate_user!` behavior — unchanged by this feature) |
| Signed-in, non-administrator | `current_user.admin?` is `false` | `302` redirect to `root_path`, with a flash `:alert` explaining the page is not available to them (FR-004, FR-008) |
| Signed-in administrator | `current_user.admin?` is `true` | `200`, renders the Users list below |
| Any caller, any other admin destination reached directly by address | same rules as above | same outcome as above — the guard is on the controller, not the link (FR-008) |

## Users list response contract (administrator only)

- **Rows**: exactly one per registered `User`, including the administrator's own account (FR-006).
- **Row content**: the account's email address (FR-007); the administrator's row additionally carries
  a visible "Admin" label that no other row has (FR-012).
- **Order**: registration order, oldest first — the administrator's row is always first (FR-010).
- **Completeness**: every account ever registered appears; none is silently omitted regardless of
  how many exist (SC-003) — see `plan.md` Constitution Check for the documented pagination deferral.
- **Mutations**: none available from this screen — no edit, delete, promote, or demote control
  (FR-009). The screen is read-only.

## Out of scope for this contract

- Any way to change an account's `admin` status (no such endpoint exists — see data-model.md).
- Any endpoint under `/admin` other than `/admin/users` (none is introduced by this feature).
