# Phase 1 Data Model: Users Screen — Locker Details and Filters

**Feature**: [spec.md](./spec.md) | **Branch**: `020-admin-users-filters` | **Date**: 2026-09-19

No migration. Every field this feature displays or filters on already exists (`users.floor`,
`users.locker_number`, `users.admin`, `locker_wishes.floor`). This document records the query surface
added on top of them and the two POROs that back the filter bar.

## Entities (all pre-existing; no schema change)

### User (`app/models/user.rb`)

Already carries `email`, `floor`, `locker_number`, `admin`, `admin_granted_at`, `admin_granted_by`,
`created_at`. This feature adds four scopes and one class-level choice query; no new column, no new
validation, no new association.

| Addition | Kind | Behavior |
|---|---|---|
| `with_role(role)` | scope | Matched case-insensitively — `role.to_s.downcase` — against `"admin"` → `where(admin: true)` and `"standard"` → `where(admin: false)`. Blank or any other value is a no-op (`all`), so a malformed value never errors. The case-insensitivity is load-bearing: `RoleFilter::CHOICES` sends the capitalized display values `"Admin"`/`"Standard"` as the filter's own query values (mirroring `FloorFilter`'s "the value is also the label" pattern), and this scope has to accept exactly what that sends. |
| `on_floor(floor)` | scope | Exact match on `users.floor`. Blank is a no-op. Same shape as `LockerWish#owner_on_floor`'s exact-match half, but directly on `User` rather than through a join. |
| `with_locker_number(number)` | scope | Exact match on `users.locker_number`. Blank is a no-op. (FR-007 — the clarified exact-match decision.) |
| `email_containing(text)` | scope | `WHERE email LIKE '%<escaped text>%' ESCAPE '\\'`, escaped via `sanitize_sql_like`. The `ESCAPE '\\'` clause is required — SQLite does not treat backslashes in a `LIKE` pattern as escape characters unless the clause says so, so without it `sanitize_sql_like`'s inserted backslashes would be matched as literal characters and a literal `%`/`_` in the search text would not be escaped (research R4). Case-insensitive for free, via the column's existing `NOCASE` collation. Blank is a no-op. |
| `self.saved_floors` | class method | `where.not(floor: [nil, ""]).distinct.pluck(:floor)` — every distinct floor saved by *any* registered user, independent of any filter currently applied (research R3). Feeds `FloorFilter`'s `available:` exactly as `LockerWish.owner_floors` does for the locker-wishes screen. |

None of the four scopes touch `locker_wish` — the "active wish" column (FR-003) is read directly per
row via the existing `user.locker_wish` association (already eager-loadable; see Query Composition
below), not filtered on.

### LockerWish (`app/models/locker_wish.rb`)

Unchanged. Read per row via `user.locker_wish&.saved_floor` to populate FR-003's "active wish" column.
Not eager-loaded with a scope of its own in this feature's first cut — see Query Composition for the
eager-load that avoids turning this into a per-row query.

### FloorFilter (`app/models/floor_filter.rb`)

Unchanged — reused as-is (feature 017). Instantiated once here:

```ruby
FloorFilter.new(selection: floor_selection, available: User.saved_floors)
```

Its `choices`, `current?`, `filtering?` and ordering (numeric floors ascending, then alphabetical —
FR-005) behave identically to its use on the locker wishes screen; only what feeds `available:`
differs (every registered user's floor, not just active wishers').

### RoleFilter (`app/models/role_filter.rb`) — NEW

A deliberately smaller sibling of `FloorFilter`, sharing just enough of its shape (`selection`,
`filtering?`, `current?(value)`, `choices`) to be rendered by the same kind of link-group partial, but
without `FloorFilter`'s sorting or "keep a vanished selection visible" logic — neither applies to a
fixed, closed pair of choices.

```ruby
class RoleFilter
  CHOICES = %w[Admin Standard].freeze

  attr_reader :selection

  def initialize(selection:)
    @selection = selection.presence
  end

  def filtering? = !@selection.nil?
  def current?(choice) = choice == @selection
  def choices = CHOICES
end
```

Constructed as `RoleFilter.new(selection: role_selection)` — no `available:` argument, since FR-006
fixes the pair regardless of what roles are actually present among registered accounts.

**Why not reuse `FloorFilter` directly** (Constitution I): passing `available: RoleFilter::CHOICES`
into `FloorFilter` would incidentally produce the right order today (both values are non-numeric, so
`FloorFilter`'s alphabetical fallback happens to put "Admin" before "Standard"), but that correctness
would be accidental — a future third role value could sort anywhere, and `FloorFilter`'s
"append the selection back in if it's not among the derived choices" logic (needed because a floor
can stop being anyone's) has no meaning for a role, which is never absent from the fixed pair. A
smaller, purpose-built class is less code overall than the conditionals that would be needed to make
`FloorFilter` correctly handle a choice set it does not derive.

## Filter Parameters (query string on `GET /admin/users`)

| Parameter | Values | Default (absent/blank) |
|---|---|---|
| `current_locker` | any string | no restriction |
| `current_floor` | any string | no restriction |
| `role` | `admin`, `standard` | no restriction |
| `email` | any string | no restriction |

All four are read as plain strings (mirroring `LockerWishesController#filter_selection`'s "anything
that is not a plain string is no filter at all" rule) — a malformed value such as
`?role[]=admin` is treated as absent rather than raising.

## Query Composition (`Admin::UsersController#index`)

```ruby
@users = User.includes(:admin_granted_by, :locker_wish)
             .with_role(role_selection)
             .on_floor(floor_selection)
             .with_locker_number(locker_selection)
             .email_containing(email_selection)
             .order(:created_at)
```

`:locker_wish` is added to the existing `.includes(:admin_granted_by)` eager-load so FR-003's "active
wish" column costs no additional per-row query — the same reasoning that put
`:admin_granted_by` there in 013/015's plan.

**Query budget**: this composed relation is one `SELECT` regardless of how many of the four filters
are set (each is a `WHERE`/no-op), plus the existing `includes` (two more, both bounded by result size,
not by total user count) plus the new `User.saved_floors` `DISTINCT` (bounded by distinct-floor
count). Total: at most one query more than today's unfiltered index issues, and never more when
filtered than unfiltered — the assertion `test/controllers/admin/users_controller_test.rb` records.

## No-Match State

`@users.any?` is false and at least one of the four filters is set → render the "no account matches
the current filters" message (FR-011). Because viewing this screen already requires being a
registered administrator, `@users` can never be empty when *no* filter is set — unlike the locker
wishes screen, there is no equivalent to "nobody is looking for a locker right now" to keep distinct
from; the only empty state this screen can ever show is the filtered one.
