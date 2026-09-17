# Phase 1 Data Model: Admin Role and User Directory

## User (existing entity, extended)

The feature adds one attribute to the existing `users` table; no new table is introduced.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `admin` | boolean | `NOT NULL`, default `false` | Set exactly once, by the model, never by a controller. True for exactly zero or one row at a time. |

### New index

`add_index :users, :admin, unique: true, where: "admin = 1"` (partial unique index, SQLite boolean
column) — the database-level guarantee behind FR-001/FR-002 that at most one account can ever be
`admin: true` at a time, per R2 in `research.md`.

### Lifecycle / state transitions

```
[account created] ──before_create──> admin = true   if User.count.zero? at that instant
                    │
                    └────────────────> admin = false  otherwise (the default)

admin: true  ──(no transition exists)──> admin: false
admin: false ──(no transition exists)──> admin: true
```

- **Set once, at creation.** There is no `update` path for this attribute anywhere in the
  application: it is never in a controller's permitted params, and no view offers a control for it
  (FR-009 — the Users list is read-only).
- **Race handled by the index, not the check.** Two accounts created at effectively the same instant
  can both evaluate `User.count.zero?` as true; the partial unique index added above lets only one
  `INSERT` with `admin = true` succeed. The model rescues `ActiveRecord::RecordNotUnique` for the
  losing save and retries once with `admin = false` (R2).
- **Deletion is a dead end, by design.** Destroying the `admin: true` row does not cause any other
  row to become `admin: true` — there is no callback, job, or query that looks for "the next one."
  This is the direct implementation of FR-011: the site is left with zero administrators until that
  is addressed outside this feature.

### Validation rules

- No new user-facing validation. `admin` is never assigned from user input, so there is nothing for
  a validation to reject; its only guard is the database-level uniqueness above, defended against in
  the model layer as described.

### Relationships

Unchanged. `admin` is a plain attribute on the existing `User` row — it does not participate in any
association added by this feature.

### Derived / display-only facts

- **"Admin" label in the Users list (FR-012)**: read directly from `user.admin?` on the already-loaded
  row — no extra query per row.
- **List order (FR-010)**: `User.order(:created_at)` — oldest first, so the administrator (definitionally
  the earliest row) sorts first without needing `admin` in the `ORDER BY` at all.
