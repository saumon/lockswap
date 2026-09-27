# Contract: Admin swap validation screen — routes, controller, views, locale keys

**Feature**: [../spec.md](../spec.md) | **Branch**: `033-admin-swap-validation`

Not a network API — this is the shared route/controller/view/locale surface `contracts/*.md` plays for
every prior admin-only feature in this repo (029's `super-admin-access.md` is the closest precedent).

## Routes (new + removed)

```ruby
# config/routes.rb

resources :locker_swap_proposals, only: [ :create, :destroy, :index ] do
  member do
    patch :accept
    patch :decline
    # patch :confirm   ← REMOVED (research.md R8)
  end
end

namespace :admin do
  # ...existing resources unchanged...

  # 033 FR-001/FR-004/FR-005: the validation queue and its two decisions.
  # Member actions, not a status param — the same reasoning
  # locker_swap_proposals' accept/decline/confirm already follow (each
  # decision keeps its own authorization and rules).
  resources :swap_validations, only: :index do
    member do
      patch :validate
      patch :refuse
    end
  end
end
```

| Verb | Path | Route helper | Controller#action | Guard |
|---|---|---|---|---|
| GET | `/admin/swap_validations` | `admin_swap_validations_path` | `Admin::SwapValidationsController#index` | `authenticate_user!`, `require_admin!` |
| PATCH | `/admin/swap_validations/:id/validate` | `validate_admin_swap_validation_path` | `Admin::SwapValidationsController#validate` | `authenticate_user!`, `require_admin!` |
| PATCH | `/admin/swap_validations/:id/refuse` | `refuse_admin_swap_validation_path` | `Admin::SwapValidationsController#refuse` | `authenticate_user!`, `require_admin!` |

`PATCH /locker_swap_proposals/:id/confirm` (`LockerSwapProposalsController#confirm`) and its route no
longer exist; a request to it 404s (research.md R8).

## `Admin::SwapValidationsController` (new)

```ruby
# 033 FR-001..FR-010: the queue services généraux works from, and its two
# decisions. Deliberately separate from LockerSwapProposalsController — that
# one is the two parties' own self-service actions (create/destroy/accept/
# decline), this one is an administrator acting on a proposal that is not
# theirs to decide by default.
class Admin::SwapValidationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  # FR-001, FR-002, research.md R7: every accepted proposal, oldest-waiting
  # first, both parties' zones resolved in one batched call (032 research.md
  # R3's pattern) rather than one query per row.
  def index
    @proposals = LockerSwapProposal.accepted.includes(:requester, :recipient).order(decided_at: :asc)
    @zone_names = LockerMapEntry.zone_names_for(@proposals.flat_map(&:locker_sides))
  end

  # FR-004: validating is exactly what the retired self-confirmation did —
  # confirm! is unchanged except for by:, which records who did it (FR-014).
  def validate
    if accepted_proposal&.confirm!(by: current_user)
      redirect_to admin_swap_validations_path, notice: t(".validated")
    else
      # research.md R6: the row was decided by someone else (or vanished)
      # between the list being drawn and this request — not an error to hide.
      redirect_to admin_swap_validations_path, alert: t(".already_decided")
    end
  end

  # FR-005..FR-008: decline! now reachable from accepted?, not only pending?
  # (data-model.md). The comment is optional — decline! already treats a
  # blank one as no comment via .presence.
  def refuse
    if accepted_proposal&.decline!(refuse_params[:decline_comment], by: current_user)
      redirect_to admin_swap_validations_path, notice: t(".refused")
    else
      redirect_to admin_swap_validations_path, alert: t(".already_decided")
    end
  end

  private

    # research.md R6: scoped to .accepted so a row that has already moved on
    # is simply not found here, rather than being found and then no-op'd
    # inside the model method.
    def accepted_proposal
      LockerSwapProposal.accepted.find_by(id: params[:id])
    end

    def refuse_params
      params.fetch(:locker_swap_proposal, {}).permit(:decline_comment)
    end
end
```

Note: `refuse_params` uses `params.fetch(...).permit(...)` rather than `params.expect(...)` (the pattern
`LockerSwapProposalsController#decline` uses via `params.dig`) because the comment is optional and the
`locker_swap_proposal` key itself may be entirely absent when an administrator refuses with no comment —
mirroring `LockerSwapProposalsController#decline`'s own `params.dig(:locker_swap_proposal,
:decline_comment)` in spirit (optional all the way down), spelled with `permit` here since the view submits
a real form rather than a single dug value.

## `LockerSwapProposal` (existing model, methods extended — full bodies in data-model.md)

```ruby
belongs_to :admin_decided_by, class_name: "User", optional: true

def confirm!(by: nil)
  return false unless accepted?
  # ...unchanged body, plus admin_decided_by: by on the completing update!...
end

def decline!(comment = nil, by: nil)
  return false unless pending? || accepted?
  # ...unchanged body, plus admin_decided_by: by...
end
```

## `User` (existing model, one association added)

```ruby
has_many :swap_decisions_made, class_name: "LockerSwapProposal",
         foreign_key: :admin_decided_by_id, dependent: :nullify, inverse_of: :admin_decided_by
```

## `app/views/admin/swap_validations/index.html.erb` (new)

> **As built (implementation deviation):** the list is a card of `.tile`s — the
> `home/_swap_proposals_received.html.erb` shape — not the `.data-table` sketched
> below. `.tile-disclosure` is styled for a tile, and a comment form inside a
> table cell stacks badly below the 48rem breakpoint. Each tile names both
> parties (email, floor, locker, zone), the acceptance date, a primary
> "Validate" button (with an aria-label naming both parties, since a column of
> identical buttons is otherwise told apart only by position), and the refuse
> `<details>`. The controller reads the optional comment with
> `params.dig(:locker_swap_proposal, :decline_comment)`, as
> `LockerSwapProposalsController#decline` already does, rather than the
> `refuse_params` helper below. Locale keys were renamed to match
> (`admin.swap_validations.index.requester`, `.recipient`, `.locker_details`,
> `.lead`, `.refuse`, …); the menu entry is "Validation des échanges".

Reuses the `.data-table` shape from `locker_swap_proposals/_history_table.html.erb` (six columns become
five: both parties instead of one "counterpart", their locker details plus zone, and the two actions) and
the `<details class="tile-disclosure">` decline-with-comment pattern from `home/_swap_proposals_received.html.erb`
for the refusal form:

```erb
<% if @proposals.any? %>
  <div class="table-scroll">
    <table class="data-table" role="table">
      <thead>
        <tr role="row">
          <th scope="col" role="columnheader"><%= t(".requester_header") %></th>
          <th scope="col" role="columnheader"><%= t(".recipient_header") %></th>
          <th scope="col" role="columnheader"><%= t(".accepted_at_header") %></th>
          <th scope="col" role="columnheader"><%= t(".actions_header") %></th>
        </tr>
      </thead>
      <tbody>
        <% @proposals.each do |proposal| %>
          <tr id="swap-validation-row-<%= proposal.id %>" role="row">
            <td class="data-value" role="cell"><%= proposal.requester.email %></td>
            <%# each cell's floor/locker/zone reads the same "value on file"
                shape _swap_exchange_in_progress.html.erb and
                _swap_proposals_received.html.erb already use, fed by
                @zone_names rather than a per-row LockerMapEntry query %>
            <td class="data-value" role="cell"><%= proposal.recipient.email %></td>
            <td class="meta" role="cell"><%= l proposal.decided_at, format: :long %></td>
            <td role="cell">
              <%= button_to t(".validate_button"), validate_admin_swap_validation_path(proposal), method: :patch,
                    class: "btn btn-primary btn-sm", form: { data: { turbo_submits_with: t(".validating") } } %>

              <details class="tile-disclosure">
                <summary class="tile-disclosure-summary"><%= t(".refuse_button") %></summary>
                <%= form_with url: refuse_admin_swap_validation_path(proposal), method: :patch,
                              class: "stack-tight tile-disclosure-body" do |f| %>
                  <%= f.label :"locker_swap_proposal[decline_comment]", t(".refuse_comment_label"),
                        for: "refuse-comment-#{proposal.id}", class: "field-label" %>
                  <%= f.text_area :"locker_swap_proposal[decline_comment]", rows: 2,
                        id: "refuse-comment-#{proposal.id}", class: "field-input" %>
                  <%= f.submit t(".confirm_refuse"), class: "btn btn-secondary btn-sm",
                        data: { turbo_submits_with: t(".refusing") } %>
                <% end %>
              </details>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
<% else %>
  <p id="admin-swap-validations-empty" class="empty-state"><%= t(".empty") %></p>
<% end %>
```

## `app/views/home/_swap_exchange_in_progress.html.erb` (simplified)

The `viewer_is_recipient` branch (confirm button vs. waiting message) is removed; both parties see the same
paragraph:

```erb
<% counterpart = @exchange_in_progress.requester_id == current_user.id ? @exchange_in_progress.recipient : @exchange_in_progress.requester %>

<div id="swap-exchange-in-progress" class="card card--them stack-tight">
  <div class="row">
    <h2 class="card-title"><%= t(".title") %></h2>
    <span class="badge badge-success"><%= t(".accepted") %></span>
  </div>

  <div>
    <%# ...unchanged counterpart details / zone label... %>
  </div>

  <p class="card-lead"><%= t(".pending_admin_validation") %></p>
</div>
```

`viewer_is_recipient` is deleted along with the branch it only existed for.

## `app/views/shared/_site_menu_items.html.erb` (new admin link)

```erb
<% if current_user.admin? %>
  <details class="site-submenu">
    <summary class="site-submenu-toggle"><%= t(".admin") %></summary>

    <div class="site-submenu-panel">
      <%= link_to t(".users"), admin_users_path, ... %>
      <%= link_to t(".locker_map"), admin_locker_map_path, ... %>
      <%# 033: same tier as Users/Locker map — require_admin!, not
          require_super_admin! (research.md R2). %>
      <%= link_to t(".swap_validations"), admin_swap_validations_path, class: "site-nav-link",
            "aria-current": ("page" if current_page?(admin_swap_validations_path)) %>

      <% if current_user.super_admin? %>
        <%= link_to t(".danger_zone"), admin_danger_zone_path, ... %>
      <% end %>
    </div>
  </details>
<% end %>
```

Placed above the super-admin-only `danger_zone` link, alongside the other ordinary-admin links.

## Locale keys

`config/locales/en.yml`:

```yaml
en:
  shared:
    site_menu_items:
      swap_validations: "Swap validations"
  admin:
    swap_validations:
      index:
        title: "Swap exchanges awaiting validation"
        requester_header: "Requester"
        recipient_header: "Recipient"
        accepted_at_header: "Accepted"
        actions_header: "Actions"
        validate_button: "Validate"
        refuse_button: "Refuse"
        refuse_comment_label: "Reason (optional)"
        confirm_refuse: "Confirm refusal"
        empty: "No exchanges are currently awaiting validation."
      validate:
        validated: "Exchange validated — locker details have been swapped."
        already_decided: "That exchange was already decided."
      refuse:
        refused: "Exchange refused."
        already_decided: "That exchange was already decided."
  home:
    swap_exchange_in_progress:
      title: "Awaiting validation"
      pending_admin_validation: "Your exchange request is awaiting validation. Please see the facilities
        team in person to complete the physical locker swap and finalize the request."
  locker_swap_proposals:
    index:
      exchange_in_progress: "Awaiting validation"
    # confirm: (removed — no action left to reach it from)
```

`config/locales/fr.yml`:

```yaml
fr:
  shared:
    site_menu_items:
      swap_validations: "Validations d'échanges"
  admin:
    swap_validations:
      index:
        title: "Échanges de casiers en attente de validation"
        requester_header: "Demandeur"
        recipient_header: "Destinataire"
        accepted_at_header: "Accepté le"
        actions_header: "Actions"
        validate_button: "Valider"
        refuse_button: "Refuser"
        refuse_comment_label: "Motif (facultatif)"
        confirm_refuse: "Confirmer le refus"
        empty: "Aucun échange n'est actuellement en attente de validation."
      validate:
        validated: "Échange validé — les détails des casiers ont été échangés."
        already_decided: "Cet échange a déjà été traité."
      refuse:
        refused: "Échange refusé."
        already_decided: "Cet échange a déjà été traité."
  home:
    swap_exchange_in_progress:
      title: "En attente de validation"
      pending_admin_validation: "Votre demande d'échange est en attente de validation. Rapprochez-vous des
        services généraux pour l'échange physique des casiers et ainsi finaliser la demande."
  locker_swap_proposals:
    index:
      exchange_in_progress: "En attente de validation"
    # confirm: (supprimé — plus d'action pour l'atteindre)
```

Retired keys (both locales), deleted rather than reworded: `home.swap_exchange_in_progress.confirm_instructions`,
`confirm_button`, `confirming`, `waiting_for_their_confirmation`; `locker_swap_proposals.confirm.confirmed`.

`swap_exchange_in_progress.pending_admin_validation` carries the spec's quoted text verbatim (French) with
its literal English sense (not a separate translation decision — spec.md's Assumptions already settle that
English follows the same change).
