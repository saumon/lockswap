# Phase 1 Data Model: Grant Administrator Rights

**Feature**: [spec.md](./spec.md) | **Research**: [research.md](./research.md) | **Date**: 2026-09-18

One existing entity changes. No new table.

## User (existing — `users`)

### Columns added

| Column | Type | Null | Default | Purpose |
|---|---|---|---|---|
| `admin_granted_at` | `datetime` | yes | — | When administrator rights were granted. NULL means the rights were not granted: either the account is not an administrator, or it claimed the rights at first registration (013 FR-001). Never cleared once set. (FR-017) |
| `admin_granted_by_id` | `integer` (FK → `users.id`) | yes | — | Which administrator granted the rights. Nullified when that account is deleted, so the grant survives its grantor. (FR-017, FR-019) |

`admin` (boolean, `null: false, default: false`) is unchanged.

### Index changed

| Index | Before (013) | After (015) |
|---|---|---|
| bootstrap administrator | `UNIQUE (admin) WHERE admin = 1` | `UNIQUE (admin) WHERE admin = 1 AND admin_granted_at IS NULL`, renamed `index_users_on_bootstrap_admin` |

The constraint that settles the signup race (013 FR-002) is kept, narrowed to the bootstrap case so
granted administrators are unlimited (FR-013). Keyed on `admin_granted_at`, not
`admin_granted_by_id`, because only the timestamp is immune to the grantor's deletion — see
[research.md R1](./research.md).

`admin_granted_by_id` gets a plain, non-unique index: one administrator may grant many times.

### The three states of an account

| `admin` | `admin_granted_at` | Meaning | Reachable how |
|---|---|---|---|
| `false` | NULL | Standard account | Any signup after the first |
| `true` | NULL | Bootstrap administrator | The first account ever registered (013 FR-001). At most one, enforced by the index. |
| `true` | set | Granted administrator | An administrator validated the confirmation (FR-006). Unlimited. |

`admin = false` with `admin_granted_at` set is unreachable: rights are never removed (FR-014).

### Transitions

- **Standard → granted administrator** (FR-006): sets `admin`, `admin_granted_at` and
  `admin_granted_by_id` together, in one write. One-way — no transition removes `admin` (FR-014).
- **Granted administrator → granted administrator** (FR-012): granting to an account that is already
  an administrator is a no-op reported as success, not a failure. The original `admin_granted_at` is
  **not** overwritten, so the recorded origin stays the first grant.
- **Any administrator → deleted**: refused when other accounts would remain and this is the last
  administrator (FR-016; the sole-account case it lets through is reasoned at
  [research.md R4](./research.md)).
- **Grantor deleted**: `admin_granted_by_id` nullifies; `admin_granted_at` persists (FR-019).

### Associations

```ruby
belongs_to :admin_granted_by, class_name: "User", optional: true,
           inverse_of: :admin_grants_made
has_many :admin_grants_made, class_name: "User", foreign_key: :admin_granted_by_id,
         dependent: :nullify, inverse_of: :admin_granted_by
```

`dependent: :nullify` is what FR-019 rests on; `dependent: :destroy` here would delete every account
an outgoing administrator ever promoted.

### Validation and callback rules

| Rule | Where | Requirement |
|---|---|---|
| Rights are granted at most once; a second grant leaves `admin_granted_at` as it was | `User#grant_admin_rights!` (no-op when `admin?`) | FR-012 |
| A grant sets all three columns together or none | Single `update!` inside the action | FR-006 |
| The last administrator cannot be deleted while other accounts remain | `before_destroy` guard, `throw :abort` | FR-016 |
| At most one bootstrap administrator | Partial unique index + the existing `User#save` retry | 013 FR-002 |

### Derived reading for the Users list

- `admin? && admin_granted_at.nil?` → "first registration"
- `admin_granted_at? && admin_granted_by` → "granted by \<email\> on \<date\>"
- `admin_granted_at? && admin_granted_by.nil?` → "granted on \<date\> (account removed)" (FR-019)

Loaded with `includes(:admin_granted_by)` so the list stays two queries regardless of size
([research.md R5](./research.md)).

## Existing behaviour this feature must not break

- `User#save`'s rescue of the bootstrap race matches the index by name
  (`ADMINISTRATOR_INDEX_CONFLICT`); renaming the index without updating that constant turns a lost
  race into a 500 at signup.
- `User#claim_administrator_if_first` stays as it is: `admin = !User.exists?` still designates only
  the first account, and it never sets `admin_granted_at`, which is what puts it under the index.
