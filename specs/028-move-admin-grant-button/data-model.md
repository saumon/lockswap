# Phase 1 Data Model: Admin Rights Controls on the User Detail Screen

**Feature**: [../spec.md](../spec.md) | **Branch**: `028-move-admin-grant-button`

This feature adds no migration and no new column. It reuses `users.admin`,
`users.admin_granted_at`, and `users.admin_granted_by_id` — the exact triple 015 introduced — both for
the existing grant and for the new revoke.

## `User` (existing table, no schema change)

### New behavior

```ruby
# 028 FR-009, FR-018: the whole of revoking. Symmetric with #grant_admin_rights! above — one write,
# and it clears every trace of the grant rather than replacing it with a "revoked" record (research.md
# R4; the Clarifications session declined a revoked_by/revoked_at pair).
def revoke_admin_rights!
  return self unless admin?

  update!(admin: false, admin_granted_at: nil, admin_granted_by: nil)
  self
end
```

Placed immediately after `grant_admin_rights!`/`admin_rights_granted?` in `app/models/user.rb`, since
it is the direct counterpart of both.

### Validations

None added. `admin`, `admin_granted_at`, `admin_granted_by_id` already have none of their own (015) —
they are write-once-per-action facts set by controller actions, not user-supplied input.

### Who may call it

`revoke_admin_rights!` itself performs no authorization check — like `grant_admin_rights!`, it is a
plain model mutation. FR-010/FR-011 (only an administrator may revoke; never on one's own account) are
enforced in `Admin::UsersController#revoke_admin` before the method is ever called (research.md R3),
the same division of responsibility 015 already uses for the grant (`grant_admin_rights!` does not ask
who `by:` is allowed to be either).

### State shown on the detail and list screens (unchanged sources, updated meaning)

| Screen fact | Source | Effect of this feature |
|---|---|---|
| Role badge ("Admin" / "Standard") | `user.admin?` | Flips to standard the instant `revoke_admin_rights!` commits — no new state to read. |
| Grant provenance line ("Granted by X on Y" / "First registration") | `user.admin_rights_granted?`, `user.admin_granted_by`, `user.admin_granted_at` | Only ever rendered inside the `if user.admin?` branch on both screens (unchanged markup) — once revoked, `admin?` is false and the whole branch, including this line, stops rendering. No new "was revoked" branch is added (FR-018: no trace is kept). |
| Grant control | `!user.admin?` | Unchanged logic; only its screen location changes (index → show). |
| Revoke control | `user.admin? && user != current_user` | New. |

No other model, `LockerWish` or `LockerSwapProposal`, is touched.

## Removed behavior

`Admin::UsersController`'s private `filter_selections` method is deleted (research.md R2) — it has no
caller once `#grant_admin` stops redirecting through it and `#revoke_admin` never needs it either.
`FILTER_AXES` and `#filter_selection` are unchanged; `#index` still uses them.

## Migration

None.
