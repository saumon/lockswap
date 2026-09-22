# Contract: Admin User Detail screen — routes, DOM and confirmation copy

**Feature**: [../spec.md](../spec.md) | **Branch**: `027-admin-user-detail-view`

This is not a network API — it is the routes, DOM shape, and confirmation copy the system and
controller tests assert against, the same role `contracts/admin-users-filter.md` (020) and
`contracts/locker-wish-filter.md` (017) play for their own screens.

## Routes

| Verb | Path | Route helper | Controller#action |
|---|---|---|---|
| GET | `/admin/users/:id` | `admin_user_path(user)` | `Admin::UsersController#show` |
| PATCH | `/admin/users/:user_id/locker_profile` | `admin_user_locker_profile_path(user)` | `Admin::UserLockerProfilesController#update` |
| DELETE | `/admin/users/:user_id/locker_wish` | `admin_user_locker_wish_path(user)` | `Admin::UserLockerWishesController#destroy` |

All three carry the same `authenticate_user!` + `require_admin!` guard `admin_users_path` already has
(research.md R1). A non-admin or signed-out request to any of the three is refused exactly as
`admin_users_path` refuses one today (FR-002).

`routes.rb` shape:

```ruby
namespace :admin do
  resources :users, only: [ :index, :show ] do
    member do
      patch :grant_admin
    end
    resource :locker_profile, only: :update, controller: "user_locker_profiles"
    resource :locker_wish, only: :destroy, controller: "user_locker_wishes"
  end
  # ...existing danger_zone / allowed_email_domains unchanged
end
```

## `GET /admin/users/:id` (`Admin::UsersController#show`)

- `find_by(id:)`, not `find` — a vanished account is `redirect_to admin_users_path,
  alert: t(".account_gone")` (reuses the exact wording `Admin::UsersController::ACCOUNT_GONE_MESSAGE`
  already uses for `#grant_admin`), never a 404 page (Edge Cases: "the administrator MUST see a clear
  ... outcome ... and MUST be returned to a working screen").
- `@user` is loaded with `includes(:admin_granted_by, :locker_edited_by, :search_cancelled_by,
  :locker_wish)` — every association the view reads, eager-loaded once, matching
  `Admin::UsersController#index`'s own reasoning (Principle IV: no per-render query beyond a fixed,
  small set).
- `@active_proposals` and `@proposal_history`: composed per data-model.md's "State shown on the detail
  screen" table (research.md R5/R6 — two queries unioned in Ruby, never one `OR`).

### DOM (`admin/users/show.html.erb`)

```html
<div class="stack">
  <div class="page-head">
    <h1 class="page-title"><!-- user.email --></h1>
  </div>

  <div id="admin-user-detail" class="card stack-tight">
    <!-- FR-003: email, role badge + grant provenance (reuses index.html.erb's role cell markup),
         registration date, floor, locker -->
    <dl id="admin-user-detail-profile" class="detail-grid">…</dl>

    <!-- FR-008: pencil-icon disclosure, admin variant of home/_locker_profile.html.erb -->
    <details id="admin-user-locker-editor" class="locker-profile-editor" <%= "open" if @user.errors.any? %>>
      <summary aria-label="<!-- t('.edit_locker_details') -->">…</summary>
      <!-- form_with model: @user, url: admin_user_locker_profile_path(@user), method: :patch -->
    </details>

    <!-- FR-009a: shown only when locker_edited_by/at is present -->
    <p id="admin-user-locker-edit-provenance" class="meta">…</p>

    <!-- FR-004/FR-005: wish, active proposal(s), or neither -->
    <div id="admin-user-search-status">…</div>

    <!-- FR-010/FR-010a: only rendered when @user.locker_wish present -->
    <%= button_to t(".cancel_search_button"), admin_user_locker_wish_path(@user), method: :delete,
          data: { confirm: t(".cancel_search_confirm", email: @user.email),
                  turbo_confirm: t(".cancel_search_confirm", email: @user.email) },
          aria: { label: t(".cancel_search_aria_label", email: @user.email) },
          class: "btn btn-secondary btn-sm" %>

    <!-- FR-011a: shown only when search_cancelled_by/at is present -->
    <p id="admin-user-search-cancel-provenance" class="meta">…</p>

    <!-- FR-006/FR-007: the extracted shared partial (research.md R4) -->
    <%= render "locker_swap_proposals/history_table", proposals: @proposal_history, viewer: @user %>
  </div>
</div>
```

- `id="admin-user-detail"` is the screen's own root, distinct from `#swap-proposal-history` (the
  self-service screen's root) and `#admin-user-directory` (the list's root) — no id collision between
  the three.
- The extracted partial's `viewer:` local replaces every `current_user` reference the existing
  `locker_swap_proposals/index.html.erb` table body makes today (e.g. `sent = proposal.requester_id ==
  current_user.id` becomes `sent = proposal.requester_id == viewer.id`), so the "sent"/"received"
  direction and rail colour are judged from the *viewed* account's perspective on this screen and from
  the signed-in visitor's own perspective on the self-service screen — both correct, from one partial.

### Confirmation copy

`t(".cancel_search_confirm", email: @user.email)` — parallel construction to the existing
`grant_confirm` string this screen already has (`"Grant administrator rights to %{email}? This cannot
be undone."`): `"Cancel <email>'s locker search? This cannot be undone."` (exact copy is an
implementation/locale-file decision, not fixed by this contract beyond "names the account, says the
action is irreversible" — the same two things `grant_confirm` already says).

## `PATCH /admin/users/:user_id/locker_profile` (`Admin::UserLockerProfilesController#update`)

- `User.find_by(id: params[:user_id])`; `nil` → `redirect_to admin_users_path, alert: t(".account_gone")`
  (same account-gone handling as `show`, since arriving here means the account vanished between the
  detail screen loading and the edit being submitted).
- Params: `params.expect(user: [ :floor, :locker_number ])` — identical shape to
  `LockerProfilesController#update`'s `locker_profile_params`.
- Assigns `locker_edited_by: current_user, locker_edited_at: Time.current` alongside the submitted
  attributes, then `user.save(context: :locker_profile_update)` — one save, so the provenance is only
  ever persisted together with a successful edit, never on a rejected one (FR-009a: "a *successful*
  floor/locker edit... MUST record").
- Success → `redirect_to admin_user_path(user), notice: t(".saved")`.
- Failure (floor blank, locker taken, or `locker_details_held_by_active_swap` — FR-009,
  Acceptance Scenarios 3–5) → re-render `admin/users/show` with the editor `<details>` open and
  `user.errors` displayed via `devise/shared/error_messages`-equivalent partial, `status:
  :unprocessable_entity`, exactly the pattern `LockerProfilesController#update`'s failure branch
  already uses for the homepage.
- `ActiveRecord::RecordNotUnique` rescue mirrors `LockerProfilesController#save_locker_profile`
  exactly (same race, same message key `user.messages.locker_number_taken`).

## `DELETE /admin/users/:user_id/locker_wish` (`Admin::UserLockerWishesController#destroy`)

- `User.find_by(id: params[:user_id])`; `nil` → `redirect_to admin_users_path, alert: t(".account_gone")`.
- `user.locker_wish&.destroy` — same fire-and-forget idempotence as
  `LockerWishesController#destroy` (Edge Cases: an already-cancelled wish is "treated as already
  accomplished, not as an error").
- Only when a wish was actually present and destroyed: `user.update_columns(search_cancelled_by_id:
  current_user.id, search_cancelled_at: Time.current)` — `update_columns` (no validation/callback
  pass) is deliberate: this is a plain audit-fact write, not a `:locker_profile_update`, and must not
  be blocked by the swap-lock validation, which governs floor/locker changes only, not this pair
  (FR-011: cancelling "MUST NOT alter any swap proposal the account is party to," and by the same
  reasoning must not be blocked by one either — cancelling a search is always available regardless of
  an outstanding proposal).
- Redirect: `redirect_to admin_user_path(user), notice: t(".cancelled")` (reuses `LockerWishesController`'s
  own `t(".cancelled")` wording, "Locker search cancelled.").
- The confirmation step (FR-010a) is enforced entirely client-side via `data-confirm`/
  `data-turbo-confirm` on the button in `show.html.erb`, the same as the existing "Grant admin rights"
  control — this action itself takes no separate "confirmed" parameter, matching how the grant action
  takes none either (015 FR-020's reasoning, reused).

## Row link on `admin/users/index.html.erb` (FR-001)

One addition to the existing per-row markup (`admin/users/index.html.erb`, 013/015/020) — the email
cell's contents become a link rather than plain text:

```html
<td class="strong data-value" role="cell" data-label="<!-- Email -->">
  <%= link_to user.email, admin_user_path(user), id: "admin-user-row-#{user.id}-detail-link",
        data: { turbo_frame: "_top" } %>
</td>
```

Reuses the row's existing `#admin-user-row-<id>` id convention for the new link's own id
(`-detail-link` suffix), consistent with the `-floor`/`-locker`/`-wish` cell ids already on the same
row (020). Per the Clarifications session, this link — not a click handler on the `<tr>` — is the sole
navigable element; every other cell on the row is unchanged.

`data: { turbo_frame: "_top" }` is required: the row lives inside
`#admin-user-directory-list` (the `turbo-frame` 020 wraps the whole list in), so without it Turbo
scopes the click to that frame, finds no matching frame id in the detail screen's response, and does
nothing — the same reason the existing "Grant admin rights" `button_to` on this row already carries
`form: { data: { turbo_frame: "_top" } }`. Found during implementation (T008); not anticipated by the
original contract.

## No-wish / no-active-proposal state (FR-004/FR-005)

```html
<div id="admin-user-search-status" class="detail-value-empty">
  <!-- t(".no_search_in_progress") -->
</div>
```

Distinct id from any other per-screen content (mirrors `#admin-user-directory-no-match`'s role, 020),
so a regression cannot satisfy a test selector while showing the wrong message.

## Empty proposal-history state (FR-007)

Reused unchanged from the existing self-service screen: `#swap-proposal-history-empty` becomes a
generic id emitted by the extracted partial — e.g. `id="<%= dom_id_prefix %>-empty"` where the caller
passes a `dom_id_prefix:` local (`"swap-proposal-history"` from the self-service screen,
`"admin-user-detail-history"` from this one) so the two screens' empty states remain distinct,
independently selectable ids, exactly as their non-empty tables already are via each row's own
`swap-proposal-history-row-<id>` / a new `admin-user-detail-history-row-<id>` — the partial takes this
prefix as a local rather than hardcoding either screen's id.
