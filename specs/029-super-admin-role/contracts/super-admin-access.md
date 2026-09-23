# Contract: Super admin access guards — routes, predicate, and refusal copy

**Feature**: [../spec.md](../spec.md) | **Branch**: `029-super-admin-role`

This is not a network API — it is the shared predicate, the controller guard, the routes it protects,
and the refusal/guard copy the controllers, model, and system tests assert against, the same role
`contracts/admin-user-rights-controls.md` (028) plays for the grant/revoke controls it documents.

## The predicate: `User#super_admin?`

```ruby
def super_admin? = admin? && admin_granted_at.nil?
```

True for exactly the one account `claim_administrator_if_first` (013) ever set `admin_granted_at` to
`nil` on — see data-model.md for why this is already unique and permanent. Every caller below shares
this one method; none re-derives the condition.

## `ApplicationController#require_super_admin!` (new)

```ruby
def require_super_admin!
  return if current_user&.super_admin?

  redirect_to root_path, alert: I18n.t("application.administrators_only")
end
```

Structurally identical to the existing `require_admin!` immediately above it, differing only in the
predicate checked. Reuses the existing `administrators_only` message/key (research.md R3) — a standard
admin sees the same refusal a non-admin already sees; no new locale key for this path.

## Routes protected by `require_super_admin!` (guard changed, no route changed)

| Verb | Path | Route helper | Controller#action | Guard before | Guard after |
|---|---|---|---|---|---|
| GET | `/admin/danger_zone` | `admin_danger_zone_path` | `Admin::DangerZoneController#show` | `require_admin!` | `require_super_admin!` |
| PATCH | `/admin/danger_zone` | `admin_danger_zone_path` | `Admin::DangerZoneController#update` | `require_admin!` | `require_super_admin!` |
| POST | `/admin/allowed_email_domains` | `admin_allowed_email_domains_path` | `Admin::AllowedEmailDomainsController#create` | `require_admin!` | `require_super_admin!` |
| DELETE | `/admin/allowed_email_domains/:id` | `admin_allowed_email_domain_path` | `Admin::AllowedEmailDomainsController#destroy` | `require_admin!` | `require_super_admin!` |

Both controllers keep their own `before_action :authenticate_user!` unchanged, and each still states its
own guard rather than inheriting it (unchanged rationale already documented on `DangerZoneController`).
No route, path, or path helper changes — only which `before_action` the controller declares.

## `Admin::UsersController#revoke_admin` (existing route, new guard)

```ruby
def revoke_admin
  user = User.find_by(id: params[:id])

  return redirect_to admin_users_path, alert: t(".account_gone") if user.nil?
  return redirect_to admin_user_path(user), alert: t(".self_forbidden") if user == current_user
  return redirect_to admin_user_path(user), alert: t(".super_admin_forbidden") if user.super_admin?

  user.revoke_admin_rights!

  redirect_to admin_user_path(user), notice: t(".revoked", email: user.email)
end
```

- New third guard, same shape as the existing `self_forbidden` check immediately above it: checked
  before the write, independent of whether the view ever rendered a revoke control for this row
  (research.md R5 — the established "visibility is not authorization" posture for this action).
- New locale key `admin.users.revoke_admin.super_admin_forbidden` (en/fr — see below).
- Everything else about this action (`find_by`, `account_gone`, idempotent `revoke_admin_rights!`,
  success redirect/notice) is unchanged.

## `admin/users/show.html.erb` (view guard added)

```erb
<% if @user.admin? %>
  <% if @user != current_user && !@user.super_admin? %>
    <%= button_to t(".revoke_button"), revoke_admin_admin_user_path(@user), method: :patch,
          data: { confirm: revoke_message, turbo_confirm: revoke_message },
          aria: { label: t(".revoke_aria_label", email: @user.email) },
          class: "btn btn-secondary btn-sm" %>
  <% end %>
<% else %>
  <%# grant button, unchanged %>
<% end %>
```

Only the revoke branch's condition changes (`&& !@user.super_admin?` added). The grant branch is
unaffected: the super admin is always `admin?`, so the grant button was never offered on their row
before this feature either.

## `shared/_site_menu_items.html.erb` (view guard narrowed)

```erb
<% if current_user.admin? %>
  <details class="site-submenu">
    <summary class="site-submenu-toggle"><%= t(".admin") %></summary>

    <div class="site-submenu-panel">
      <%= link_to t(".users"), admin_users_path, class: "site-nav-link",
            "aria-current": ("page" if current_page?(admin_users_path)) %>

      <% if current_user.super_admin? %>
        <%= link_to t(".danger_zone"), admin_danger_zone_path, class: "site-nav-link",
              "aria-current": ("page" if current_page?(admin_danger_zone_path)) %>
      <% end %>
    </div>
  </details>
<% end %>
```

The outer `<details>` and the "Users" link keep the existing `current_user.admin?` condition — only the
"Zone de danger" `link_to` moves inside its own `current_user.super_admin?` check (research.md R4).

## `User#prevent_super_admin_cancellation` (new `before_destroy`, replaces the old guard)

`before_destroy :keep_an_administrator_for_the_remaining_accounts` (015 FR-016) and
`User::LAST_ADMINISTRATOR_MESSAGE` are **removed**, not kept alongside the new guard — research.md R6
traces why the old condition can never be true again once this ships (the super admin is a permanent,
unconditional "admin remains" for every other account's check, so the rule it used to enforce is now
guaranteed a stronger way). `config/locales/en.yml`/`fr.yml`'s `user.messages.last_administrator` key is
removed with it.

```ruby
before_destroy :prevent_super_admin_cancellation

# ...

# 029 FR-010/FR-014, research.md R6: replaces keep_an_administrator_for_the_remaining_accounts, which
# this makes permanently unreachable — see research.md for why. Only the super admin's own row is ever
# blocked here, and only while at least one other account still exists; as the sole remaining account
# it may still go, the same exception 013/015 already carved out for "the only account on the site."
def prevent_super_admin_cancellation
  return unless super_admin?
  return unless User.where.not(id: id).exists?

  errors.add(:base, I18n.t("user.messages.super_admin_uncancellable"))
  throw :abort
end
```

- Reached the same way the old guard already was —
  `RegistrationsController#destroy`'s `resource.errors[:base].first || I18n.t(...)` fallback picks this
  message up with no controller change beyond swapping its fallback key (below); it already generalizes
  to any `errors[:base]` entry.
- New locale key `user.messages.super_admin_uncancellable` (en/fr — see below), replacing the removed
  `user.messages.last_administrator`.
- A granted (non-super) admin's own account has no destroy guard at all after this change — deletable at
  any time, regardless of how many other admins remain (spec.md FR-014).

## New locale keys

`config/locales/en.yml`:

```yaml
en:
  admin:
    users:
      revoke_admin:
        super_admin_forbidden: "The super admin's rights cannot be revoked."
  user:
    messages:
      super_admin_uncancellable: "The super admin account can never be cancelled."
```

`config/locales/fr.yml`:

```yaml
fr:
  admin:
    users:
      revoke_admin:
        super_admin_forbidden: "Les droits du super administrateur ne peuvent pas être révoqués."
  user:
    messages:
      super_admin_uncancellable: "Le compte du super administrateur ne peut jamais être annulé."
```

`revoke_admin.super_admin_forbidden` is placed alongside the existing `revoke_admin.self_forbidden` key.
`user.messages.super_admin_uncancellable` **replaces** `user.messages.last_administrator` at the same
nesting depth — that key, and its two locale strings, are deleted (research.md R6; nothing else
references them once `RegistrationsController#destroy`'s fallback is updated).
