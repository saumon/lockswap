# Phase 1 Data Model: Admin User Detail View

**Feature**: [../spec.md](../spec.md) | **Branch**: `027-admin-user-detail-view`

This feature adds one migration (two provenance pairs on `users`) and no new table. `LockerWish` and
`LockerSwapProposal` are read unchanged; see spec.md's Key Entities for why each is unchanged.

## `User` (existing table, extended)

### New columns

| Column | Type | Null | Notes |
|---|---|---|---|
| `locker_edited_by_id` | bigint, FK → `users.id` | yes | Who last edited this account's floor/locker from the admin detail screen. `nil` means no admin has ever done so (self-service edits by the account holder do not set this — research.md R3). |
| `locker_edited_at` | datetime | yes | When. `nil` iff `locker_edited_by_id` is `nil`. |
| `search_cancelled_by_id` | bigint, FK → `users.id` | yes | Who last cancelled this account's standing wish from the admin detail screen. `nil` means no admin has ever done so. |
| `search_cancelled_at` | datetime | yes | When. `nil` iff `search_cancelled_by_id` is `nil`. |

Both `_by_id` columns are ordinary foreign keys to `users.id`, `on_delete: :nullify` — mirrors
`admin_granted_by_id` (015) exactly: an admin's account being cancelled later must not erase the fact
that an edit or a cancellation happened, only who is no longer around to be named for it. The view
falls back to an "(account removed)"-style phrase for a `nil` `_by` with a non-nil timestamp, the same
fallback `admin/users/index.html.erb` already has for `admin_granted_by` (`granted_account_removed`).

### New associations

```ruby
belongs_to :locker_edited_by, class_name: "User", optional: true
belongs_to :search_cancelled_by, class_name: "User", optional: true
```

No new `has_many` inverse is required for either — unlike `admin_granted_by`/`admin_grants_made`
(015), nothing on the detail screen or elsewhere needs to list "every account this admin has ever
edited/cancelled a search for," so no inverse collection is introduced speculatively (Principle I: no
code without a requirement behind it). Add one only if a future requirement needs that list.

### Validations

None. Both pairs are write-once-per-action audit facts set directly by the two new controller actions,
not user-supplied input — no presence/format rule applies to them, the same as
`admin_granted_by`/`admin_granted_at` today.

### Behavior (unchanged rules that continue to govern the new writes)

- `validates :floor, presence: true, on: :locker_profile_update` — still enforced when an
  administrator edits on the account's behalf (FR-009), because the new controller action reuses this
  exact validation context.
- `validates :locker_number, uniqueness: { scope: :floor }, on: :locker_profile_update` — same.
- `validate :locker_details_held_by_active_swap, on: :locker_profile_update` — same; this is what
  makes FR-009's "cannot be changed while the account has a pending or accepted swap proposal
  outstanding" true with no new code (Clarifications: no admin bypass).

### State shown on the detail screen

| Screen fact | Source |
|---|---|
| Email, registration date | `user.email`, `user.created_at` (unchanged) |
| Role + grant provenance | `user.admin?`, `user.admin_rights_granted?`, `user.admin_granted_by`, `user.admin_granted_at` (unchanged, 015) |
| Current floor/locker | `user.saved_floor`, `user.saved_locker_number` (unchanged, 002/020) |
| Floor/locker edit provenance | `user.locker_edited_by`, `user.locker_edited_at` (new) |
| Search-cancel provenance | `user.search_cancelled_by`, `user.search_cancelled_at` (new) — shown only once a wish has actually been cancelled from this screen; a account that has simply never had a wish shows neither this line nor a wish |
| Standing wish | `user.locker_wish` (unchanged, 003) |
| Active proposal(s) | `user.sent_swap_proposals.where(status: [:pending, :accepted])` ∪ `user.received_swap_proposals.where(status: [:pending, :accepted])`, unioned in Ruby (research.md R6) |
| Full proposal history | `user.sent_swap_proposals` ∪ `user.received_swap_proposals`, unioned in Ruby, sorted `created_at` desc (research.md R5, exact expression `LockerSwapProposalsController#index` already uses for `current_user`) |

## `LockerWish` (existing, no schema change)

Read: `user.locker_wish`. Written: `#destroy`, exactly as the self-service cancel already does
(`LockerWishesController#destroy`) — the admin action's only addition is writing
`search_cancelled_by`/`search_cancelled_at` onto the `User` row in the same request, after the wish is
gone (there is no wish row left to carry its own provenance — that is why these two fields live on
`User`, not on `LockerWish`, per spec.md's Key Entities).

## `LockerSwapProposal` (existing, no schema change)

Read only. No new method is required beyond composing the existing `sent_swap_proposals`/
`received_swap_proposals` associations and `pending`/`accepted` scopes the model already exposes.

## Migration

One migration, `db/migrate/<timestamp>_add_admin_action_provenance_to_users.rb`:

```ruby
add_reference :users, :locker_edited_by, foreign_key: { to_table: :users }
add_column :users, :locker_edited_at, :datetime
add_reference :users, :search_cancelled_by, foreign_key: { to_table: :users }
add_column :users, :search_cancelled_at, :datetime
```

`add_reference` without `foreign_key: { on_delete: ... }` defaults to no `ON DELETE` action at the
database level, matching how `admin_granted_by_id` was added (015) — nullify-on-delete is enforced at
the Rails association level (`dependent: :nullify` would be declared on the *inverse*, which this
feature deliberately does not add — see "New associations" above). Since no inverse `has_many` exists
here, deleting a `User` who is referenced by another account's `locker_edited_by_id` /
`search_cancelled_by_id` needs an explicit `before_destroy`/`dependent: :nullify` companion exactly
like 015's `admin_grants_made` — this is a genuine open point for `/speckit-tasks` to schedule
correctly: either add the same `has_many ..., dependent: :nullify, inverse_of: ...` pairing 015 uses
for `admin_grants_made`, scoped to these two new columns, or accept a DB-level `ON DELETE SET NULL` via
`foreign_key: { to_table: :users, on_delete: :nullify }` instead of an application-level callback. Both
achieve the same nullify guarantee; `/speckit-tasks` should pick one and apply it consistently to both
new pairs.

No index is added on either `_by_id` beyond the one `add_reference` creates automatically (an ordinary,
non-unique index for the foreign key) — unlike `admin_granted_at`'s partial unique index (015), nothing
about these two facts needs to be unique or to gate a race; they are simply overwritten on each
subsequent admin action.
