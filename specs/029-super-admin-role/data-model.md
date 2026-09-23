# Phase 1 Data Model: Super Admin Role and Exclusive Danger Zone Access

**Feature**: [spec.md](./spec.md) | **Branch**: `029-super-admin-role`

No migration. This feature adds one derived predicate to an entity whose stored columns already exist;
see research.md R1 for why no new column is introduced.

## `User` (existing entity, `db/schema.rb`)

Relevant existing columns (unchanged):

| Column | Type | Set by |
|---|---|---|
| `admin` | boolean, default `false` | `claim_administrator_if_first` (before_create) on the first account ever; `grant_admin_rights!` on any later account |
| `admin_granted_at` | datetime, nullable | `nil` for the account `claim_administrator_if_first` promoted; a timestamp for every account `grant_admin_rights!` promoted |
| `admin_granted_by_id` | FK → `users.id`, nullable | `nil` for the bootstrap account; the granting admin's id otherwise |

Existing constraint this feature relies on (015, `db/schema.rb:73`):

```
t.index ["admin"], name: "index_users_on_bootstrap_admin", unique: true,
                    where: "admin = 1 AND admin_granted_at IS NULL"
```

At most one row may ever have `admin = 1 AND admin_granted_at IS NULL` at the same time. Combined with
013 FR-002 (the flag is only ever *claimed*, in `before_create`, when `User.exists?` is false — never
set this way on an update), this index is what already makes "the account from the first registration"
unique and permanent at the database level.

### New derived attribute: `super_admin?`

```ruby
# 029 FR-001/FR-003: the account index_users_on_bootstrap_admin already guarantees is unique —
# admin_granted_at is nil only for the account claim_administrator_if_first promoted, never for one
# grant_admin_rights! promoted (research.md R1). No new column: this predicate is the existing
# invariant, named.
def super_admin? = admin? && admin_granted_at.nil?
```

Not stored. Recomputed from already-loaded attributes on every call — no query, no caching to
invalidate.

### State / lifecycle

```
                 claim_administrator_if_first
                 (before_create, only when
                  User.exists? is false)
                            │
                            ▼
              admin=true, admin_granted_at=nil
                            │
                 super_admin? ⇒ true, permanently
                            │
        ┌───────────────────┴───────────────────┐
        │                                        │
  grant_admin_rights!(other)          revoke_admin_rights!(other) /
  never touches this row              destroy other admin accounts:
  (FR-012 — no control                no effect on this row
   targets the super admin)           (FR-009/FR-010 guards, below)
```

- **Entry**: exactly once per site lifetime, at the first successful registration (FR-002). No later
  event can create a second row in this state — the unique index rejects it, and the model-level race
  handling in `User#save`/`#lost_the_administrator_race?` (013) already resolves the concurrent-signup
  case by retrying the loser as a plain account (spec.md Edge Cases, first bullet).
- **No transitions out while other accounts exist**: nothing in this feature (or any prior one) sets
  `admin_granted_at` on this row, so `super_admin?` never becomes false for the account that has it
  while it exists. Two new guards make that true by construction rather than by omission:
  - `Admin::UsersController#revoke_admin` refuses when the target `super_admin?` (research.md R5) — the
    row is never passed to `revoke_admin_rights!` in the first place.
  - `User#prevent_super_admin_cancellation` (new `before_destroy`, **replacing** the old
    `keep_an_administrator_for_the_remaining_accounts`) refuses to let the row be destroyed while any
    other account exists (research.md R6) — the one path that would otherwise leave the site with zero
    super admins for the rest of its life. When the super admin is the sole remaining account, the row
    *can* still be destroyed — the site returns to empty, and the next registration reclaims the role
    exactly as the first one did (spec.md Clarifications, Edge Cases).
- **Every other write already available on this row is unaffected**: `grant_admin_rights!` no-ops on it
  already (it is already `admin?`); floor/locker edits and search cancellation continue to apply exactly
  as they do to any other admin account (FR-011). The old, generic "last administrator" destroy guard
  (015 FR-016) is removed rather than kept alongside the new one — research.md R6 traces why it becomes
  permanently unreachable once the super admin's own permanence guarantees the same outcome more
  strongly (FR-014): a *granted* admin's own account is now unrestricted on deletion, at any time,
  regardless of how many other admins remain.

### Validation / invariant summary

| Rule | Enforced by |
|---|---|
| At most one account has `super_admin?` true | `index_users_on_bootstrap_admin` (existing, unchanged) |
| Only the first-ever registration can produce one | `claim_administrator_if_first` (existing, unchanged) |
| No control grants it to a second account | No code path sets `admin_granted_at` to `nil` outside `claim_administrator_if_first` (existing; nothing in this feature adds one) |
| No control revokes or transfers it | `Admin::UsersController#revoke_admin` guard (new) |
| The account holding it can never be deleted while any other account exists | `User#prevent_super_admin_cancellation` (new, replaces the old `keep_an_administrator_for_the_remaining_accounts`) |
| It may still be deleted when it is the sole remaining account | `prevent_super_admin_cancellation` no-ops when `User.where.not(id: id).exists?` is false |
| It keeps every standard-admin capability | Derived from `admin?` being `true` whenever `super_admin?` is (existing `admin` boolean, unchanged) |
| A granted (non-super) admin's own account is never blocked from deletion | The old "last administrator" rule is removed as unreachable (research.md R6, spec.md FR-014) — the super admin's own permanence already guarantees the site keeps an administrator |

## Other entities

No other entity is added, removed, or changed. `Admin::DangerZoneController` and
`Admin::AllowedEmailDomainsController` change which predicate their access guard checks
(`admin?` → `super_admin?`); they read and write the same `SiteLanguageSetting` and
`AllowedEmailDomain` rows as before (see contracts/super-admin-access.md).
