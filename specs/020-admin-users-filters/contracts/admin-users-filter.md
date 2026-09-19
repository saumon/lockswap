# Contract: Admin Users screen — columns, filters, frame and DOM

**Feature**: [../spec.md](../spec.md) | **Branch**: `020-admin-users-filters`

This is not a network API — it is the address, frame, and DOM shape the system and browser tests
assert against, the same role `contracts/locker-wish-filter.md` plays for feature 017.

## Route

`GET /admin/users` (unchanged route, `admin_users_path`; `Admin::UsersController#index`).

## Query Parameters

| Param | Example | Effect |
|---|---|---|
| `current_locker` | `?current_locker=42` | Exact match on `users.locker_number`. |
| `current_floor` | `?current_floor=3` | Exact match on `users.floor`. |
| `role` | `?role=admin` or `?role=standard` | Restricts to administrators or standard accounts. Any other value is ignored (treated as absent). |
| `email` | `?email=alice` | Partial (case-insensitive, `%`/`_`-escaped) match on `users.email`. |

Combining parameters ANDs them: `?role=standard&current_floor=3` shows only standard accounts on
floor 3. Omitting or blanking a parameter removes that restriction without affecting the others.

## New Row Content (per `<tr id="admin-user-row-<%= user.id %>">`)

Three new cells, added after the existing "Joined" cell and before "Role" (order not asserted by
tests beyond "present on the row"; visual order is a view concern):

| `data-label` | Content when present | Content when absent |
|---|---|---|
| `Floor` | The floor value, verbatim | `"Not set"`, with the `detail-value-empty` class (matches `home/_locker_profile.html.erb`'s wording) |
| `Locker` | The locker number, verbatim | `"No locker assigned"`, with the `detail-value-empty` class (matches the existing homepage/locker-wishes wording) |
| `Wish` | `"Looking for floor <floor>"` | `"Not looking for a locker"`, with the `detail-value-empty` class |

Cell ids follow the existing per-row convention: `#admin-user-row-<id>-floor`,
`#admin-user-row-<id>-locker`, `#admin-user-row-<id>-wish`.

## Frame

```html
<turbo-frame id="admin-user-directory-list" data-turbo-action="advance" data-controller="frame-history">
  <!-- filter bar + table (or no-match state) -->
</turbo-frame>
```

- Every filter control (the two link groups, the two text inputs' form) targets this frame implicitly
  by being inside it.
- `admin/users/index.html.erb` carries `<meta name="turbo-cache-control" content="no-cache">`, same as
  `locker_wishes/index.html.erb`.
- The "Grant admin rights" `button_to` on each non-admin row carries
  `data: { turbo_frame: "_top" }` and hidden fields for the four current filter values, so its
  redirect (a) is rendered as a full-page navigation (making the flash notice visible — it lives
  outside the frame) and (b) lands on `admin_users_path` with the same filters still applied (FR-016).

## Filter Bar

```html
<div id="admin-user-directory-filters" class="filter-bar">
  <!-- link-based: current floor -->
  <nav id="admin-user-filter-current-floor" class="filter-group" aria-label="Current floor">…</nav>

  <!-- link-based: role -->
  <nav id="admin-user-filter-role" class="filter-group" aria-label="Role">…</nav>

  <!-- debounced text: current locker -->
  <form id="admin-user-filter-current-locker-form" data-controller="auto-submit" ...>
    <label for="admin-user-filter-current-locker">Current locker</label>
    <input type="text" id="admin-user-filter-current-locker" name="current_locker"
           data-auto-submit-target="field" data-action="input->auto-submit#submit">
  </form>

  <!-- debounced text: email -->
  <form id="admin-user-filter-email-form" data-controller="auto-submit" ...>
    <label for="admin-user-filter-email">Email</label>
    <input type="text" id="admin-user-filter-email" name="email"
           data-auto-submit-target="field" data-action="input->auto-submit#submit">
  </form>
</div>
```

- The two link groups follow 017's contract exactly: "All" link plus one per choice,
  `aria-current="true"` on the one in force.
- The two text forms are `method="get"`, submitting to `admin_users_path`, each carrying the *other*
  three filter values as hidden fields so submitting one never drops the others (mirrors
  `locker_wish_filter_path` preserving the other axis).
- Each text input keeps whatever value produced the current results, even after a debounced
  auto-submit navigates the frame (the server re-renders the input with `value:` set from the
  request), so a viewer can see and continue editing what they searched for.

## No-Match State

```html
<p id="admin-user-directory-no-match" class="empty-state">
  No account matches the current filters.
</p>
```

Shown in place of the table when `@users.none?` and at least one filter is set. Distinct id from any
per-row content, so a regression cannot satisfy a test selector while showing the wrong message
(mirrors `#locker-wish-list-no-match`'s role in 017's contract). There is no equivalent to
`#locker-wish-list-empty` on this screen — see data-model.md's note that an unfiltered empty state is
unreachable here.

## Unaffected

- `#admin-user-directory` (outer card), `.data-table`, `Email`/`Joined`/`Role`/`Actions` cell content
  and ids, the `Admin` badge markup, and the grant-control's confirmation dialog text are byte-for-byte
  unchanged from 013/015 (FR-013).
- `locker_wishes/*` views, `LockerWishesHelper`, and `LockerWishesController` are not modified by this
  feature.
