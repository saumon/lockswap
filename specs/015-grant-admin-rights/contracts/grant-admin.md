# Contract: Granting administrator rights

**Feature**: [spec.md](../spec.md) | **Date**: 2026-09-18

Extends [013's Admin → Users contract](../../013-admin-user-directory/contracts/admin-users.md),
which stays in force for the listing itself. Two things change there (the grant control, and the
provenance shown on administrator rows) and one new route is added.

## Route

```
PATCH /admin/users/:id/grant_admin   →  Admin::UsersController#grant_admin
                                        grant_admin_admin_user_path(user)
```

Declared as a member action on the existing `namespace :admin { resources :users }`, alongside
`index`. No other action is added: this feature adds granting and nothing else (FR-014).

## Request/response contract

| Caller | Outcome |
|---|---|
| Anonymous | Redirect to `new_user_session_path` (`authenticate_user!`), nothing changed |
| Signed in, not an administrator | Redirect to `root_path` with `flash[:alert]` = `ApplicationController::ADMINISTRATORS_ONLY_MESSAGE`, nothing changed (FR-009) |
| Administrator, target is a standard account | Target becomes an administrator; redirect to `admin_users_path` with `flash[:notice]` confirming the grant (FR-006, FR-010) |
| Administrator, target is already an administrator | No change, no error; redirect to `admin_users_path` reported as success (FR-012) |
| Administrator, target no longer exists | Redirect to `admin_users_path` with `flash[:alert]` saying the account no longer exists; nothing changed (FR-011) |

The non-administrator refusal is the same rule, message and destination the listing already uses —
`require_admin!` on the controller covers both actions, so the write cannot drift from the read.

**No credential re-entry.** The request carries no password and none is demanded (FR-020). The
confirmation is the only step between the control and the grant.

## Grant control contract (Users list)

| Row | Control |
|---|---|
| Account that is not an administrator | A `button_to` submitting the route above |
| Account that is already an administrator | No control at all (FR-002) |

- **Label**: "Grant admin rights"
- **Accessible name**: `aria-label` naming the account, e.g. `Grant administrator rights to bob@example.com` — the control must not rely on its row position to say what it acts on (FR-015)
- **Confirmation** (`data-turbo-confirm`, with `data-confirm` as the no-JavaScript fallback): names the account and states the grant is permanent, e.g. `Grant administrator rights to bob@example.com? This cannot be undone.` (FR-003, FR-004)
- **Declining** the dialog issues no request and changes nothing (FR-005)
- Keyboard-operable, as `button_to` and `window.confirm` are by construction (FR-015)

## Administrator row contract (Users list)

The Role cell keeps the `Admin` badge exactly as 013 defines it — the badge does not vary with how
the rights were obtained (FR-008). Beneath it, one line of provenance:

| Account state | Provenance line |
|---|---|
| Bootstrap administrator (`admin_granted_at` NULL) | `First registration` |
| Granted, grantor still registered | `Granted by <grantor email> on <date>` (FR-018) |
| Granted, grantor's account deleted | `Granted on <date> (account removed)` (FR-019) |
| Not an administrator | Unchanged from 013: the em dash placeholder |

Dates use the site's existing `l ..., format: :long`, as the Joined column already does.

## Account cancellation contract (changed)

`DELETE /users` (Devise `RegistrationsController#destroy`) gains one refusal:

| Caller | Outcome |
|---|---|
| Last administrator, other accounts still registered | Deletion refused, account intact, `flash[:alert]` telling them to grant administrator rights to another account first (FR-016) |
| Administrator, another administrator exists | Deleted as before |
| Last administrator, no other accounts registered | Deleted as before — see the narrowing in [research.md R4](../research.md) |
| Any non-administrator | Deleted as before |

Two administrators cancelling at the same moment: exactly one deletion succeeds (FR-016).

## Out of scope for this contract

- Removing administrator rights, editing or deleting accounts from the list (FR-014)
- Any notification to the promoted person — the application has no mail delivery configured
- Any record of declined confirmations or repeated grants; the account carries current state and the
  origin of its rights, not a history of events
