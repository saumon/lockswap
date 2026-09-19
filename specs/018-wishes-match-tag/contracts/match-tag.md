# Contract: The "It's a match!" tag

**Feature**: [spec.md](../spec.md) | **Date**: 2026-09-19

No route, no endpoint, no parameter changes. What this feature adds is a DOM contract on the existing
`GET /locker_wishes` response, so the implementation and the test suites cannot drift apart on where
the badge lives, what it says, or when it must — and must not — appear.

## DOM contract

For each row `#locker-wish-row-<user_id>` inside `#locker-wish-list`, the "Swap" cell
(`#locker-wish-row-<user_id>-swap`) gains one more possible piece of content:

```html
<span class="badge badge-success">It's a match!</span>
```

- **Text**: exactly `It's a match!` — the literal string from the feature request, asserted verbatim
  by every test that checks for it (no abbreviation, no punctuation change).
- **Class**: `badge badge-success` — the existing component, no new class introduced.
- **Position**: inside the same `<td>` as the cell's other conditional content, appearing **before**
  it (badge, then "This is you" / the exchange-in-progress notice / "Proposal pending" / the
  "Propose swap" button) — the two are siblings, never one replacing the other (spec FR-010,
  Acceptance Scenarios 9–10).
- **Presence rule**: rendered if and only if
  `wish.reciprocal_match?(@viewer_current_floor, @viewer_wish_floor)` is true **and**
  `wish.user_id != current_user.id`. Both conditions are required; neither alone is sufficient
  (data-model.md).

## Non-goals restated as contract

These are asserted as **absence** of the badge, not merely as untested:

| Condition | Badge |
|---|---|
| Viewer has no wish of their own (`@viewer_wish_floor` is `nil`) | Absent on every row |
| Viewer's own current floor is not on file (`@viewer_current_floor` is `nil`) | Absent on every row |
| Row's person has no saved floor ("Not set") | Absent on that row |
| The row is the viewer's own | Absent, even if the formula would otherwise be true |
| Only one direction of the floor comparison holds | Absent on that row |

## Filter interaction contract

The badge is not filter-aware and needs no special-casing: it is computed per row exactly as before,
and a floor filter only changes *which rows reach the loop*, never how a reached row is evaluated. A
matching row that survives an active `looking_for` or `current_floor` filter still carries the badge;
a matching row excluded by a filter is simply not rendered at all, same as any other row.

## Query-budget contract

Rendering `#index` with `N` rows, of which `M` are reciprocal matches, issues the same number of SQL
queries as rendering it with `M = 0`. The two additional reads this feature introduces —
`current_user.saved_floor` and `current_user.locker_wish&.saved_floor` — are attribute reads on
associations `#index` already loads (`current_user` via Devise, `current_user.locker_wish` via
`own_locker_wish`), and the per-row reads (`wish.floor`, `wish.user.saved_floor`) come from
`LockerWish.active`'s existing `includes(:user)`. Asserted in the controller test as: the query count
for a render with at least one matching row equals the query count for a render with none.
