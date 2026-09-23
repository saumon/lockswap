# Contract: Admin rights controls — routes, DOM and confirmation copy

**Feature**: [../spec.md](../spec.md) | **Branch**: `028-move-admin-grant-button`

This is not a network API — it is the routes, DOM shape, and confirmation copy the controller and
system tests assert against, the same role `contracts/admin-user-detail.md` (027) plays for the detail
screen it extends.

## Routes

| Verb | Path | Route helper | Controller#action |
|---|---|---|---|
| PATCH | `/admin/users/:id/grant_admin` | `grant_admin_admin_user_path(user)` | `Admin::UsersController#grant_admin` (existing, redirect target changes) |
| PATCH | `/admin/users/:id/revoke_admin` | `revoke_admin_admin_user_path(user)` | `Admin::UsersController#revoke_admin` (new) |

Both carry the same `authenticate_user!` + `require_admin!` guard every other action on this
controller already has. `routes.rb` shape:

```ruby
resources :users, only: [ :index, :show ] do
  member do
    patch :grant_admin
    patch :revoke_admin
  end

  resource :locker_profile, only: :update, controller: "user_locker_profiles"
  resource :locker_wish, only: :destroy, controller: "user_locker_wishes"
end
```

## `PATCH /admin/users/:id/grant_admin` (existing action, changed redirect)

- Unchanged: `find_by(id:)`, `ACCOUNT_GONE_MESSAGE` on a vanished account, `grant_admin_rights!(by:
  current_user)`, idempotent on an already-admin account (FR-015).
- **Changed**: no longer builds or passes `filter_selections` (research.md R2 — dead once the control
  leaves the list).
- **Changed**: success redirects to `admin_user_path(user)` (was `admin_users_path(filter_selections)`),
  `notice: t(".granted", email: user.email)` (unchanged copy/key).
- **Changed**: the account-gone branch redirects to `admin_users_path` (unchanged — there is no valid
  `:id` to build a detail-screen path with), `alert: t(".account_gone")` (unchanged copy/key).

## `PATCH /admin/users/:id/revoke_admin` (new action)

```ruby
def revoke_admin
  user = User.find_by(id: params[:id])

  return redirect_to admin_users_path, alert: t(".account_gone") if user.nil?

  if user == current_user
    return redirect_to admin_user_path(user), alert: t(".self_forbidden")
  end

  user.revoke_admin_rights!

  redirect_to admin_user_path(user), notice: t(".revoked", email: user.email)
end
```

- `find_by`, not `find` — same account-gone handling as every other action on this controller
  (FR-013), redirect to `admin_users_path` since there is no detail screen left to return to.
- Self-check (FR-011) runs before the model call, independent of what the view rendered
  (research.md R3) — redirects back to the acting administrator's own detail screen (`admin_user_path`
  of the account making the request, which is the same account being refused) with an alert, no
  change made.
- `revoke_admin_rights!` is idempotent on an already-standard account (FR-014) — reachable directly,
  not through the view, since the control is never rendered for a non-admin row.
- Success redirects to `admin_user_path(user)`, `notice: t(".revoked", email: user.email)`.

## Grant and revoke controls on `admin/users/show.html.erb`

Both sit together near the existing role display in the detail grid, e.g. immediately after the
`dt`/`dd` pair that shows the role badge and grant provenance:

```html
<% if @user.admin? %>
  <% if @user != current_user %>
    <%= button_to t(".revoke_button"), revoke_admin_admin_user_path(@user), method: :patch,
          data: { confirm: t(".revoke_confirm", email: @user.email),
                  turbo_confirm: t(".revoke_confirm", email: @user.email) },
          aria: { label: t(".revoke_aria_label", email: @user.email) },
          class: "btn btn-secondary btn-sm" %>
  <% end %>
<% else %>
  <%= button_to t(".grant_button"), grant_admin_admin_user_path(@user), method: :patch,
        data: { confirm: t(".grant_confirm", email: @user.email),
                turbo_confirm: t(".grant_confirm", email: @user.email) },
        aria: { label: t(".grant_aria_label", email: @user.email) },
        class: "btn btn-secondary btn-sm" %>
<% end %>
```

- No `form: { data: { turbo_frame: "_top" } }` is needed on either `button_to` — unlike the list,
  `admin/users/show.html.erb` is not itself inside a turbo-frame (027 already established this for the
  cancel-search button on the same screen), so a plain redirect already re-renders the whole page and
  its flash.
- `@user != current_user` (Ruby object comparison, both `ActiveRecord::Base` instances loaded in the
  same request) is the view-level mirror of the controller's own check — belt-and-suspenders with
  research.md R3, not a substitute for it.
- IDs: no new wrapping element id is required beyond what already exists in the role `dd` — the two
  `button_to` forms render as plain buttons in the existing `#admin-user-detail` card, discoverable in
  tests via their visible text/aria-label, the same way the existing "Cancel search" button on this
  screen already is.

### Confirmation copy

- `t(".grant_confirm", email:)`: `"Grant administrator rights to %{email}?"` — the existing string
  minus its trailing "This cannot be undone." clause (research.md R7 — that clause is no longer true).
- `t(".revoke_confirm", email:)`: `"Revoke %{email}'s administrator rights?"` — parallel construction,
  names the account, states the action, no password required (research.md R5).

## Users list (`admin/users/index.html.erb`) — Actions column removed

- The `<th scope="col" role="columnheader"><%= t(".actions_header") %></th>` and its corresponding
  `<td role="cell" data-label="...">…</td>` (currently holding the grant button or an em dash) are
  deleted from the row markup entirely (research.md R6) — the table has six columns (Email, Joined,
  Floor, Locker, Wish, Role), not seven.
- Every other cell (email link to `admin_user_path`, joined date, floor, locker, wish, role badge +
  grant provenance) is unchanged — this feature touches only the removed column.

## i18n keys

`config/locales/en.yml` (mirrored in `fr.yml`):

```yaml
admin:
  users:
    index:
      # actions_header: REMOVED
      # grant_confirm / grant_button / grant_aria_label: MOVED to show:
    show:
      grant_confirm: "Grant administrator rights to %{email}?"
      grant_button: "Grant admin rights"
      grant_aria_label: "Grant administrator rights to %{email}"
      revoke_confirm: "Revoke %{email}'s administrator rights?"
      revoke_button: "Revoke admin rights"
      revoke_aria_label: "Revoke administrator rights from %{email}"
    grant_admin:
      account_gone: "That account no longer exists."   # unchanged
      granted: "%{email} has been granted administrator rights."  # unchanged
    revoke_admin:
      account_gone: "That account no longer exists."
      revoked: "%{email}'s administrator rights have been revoked."
      self_forbidden: "You cannot revoke your own administrator rights."
```

`test/i18n_completeness_test.rb` covers all of these without modification (it diffs the two locale
files directly, not per-feature).
