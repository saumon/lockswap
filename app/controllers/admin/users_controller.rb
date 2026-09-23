# 013: the administrator's view of who is registered on the site (FR-006).
#
# 015 gave the screen its first write, granting administrator rights; 028 moved
# that control (and the confirmation that guards it) onto each account's own
# detail screen and added its counterpart, revoking. Editing an account or
# deleting one are still out of scope (015 FR-014, narrowed by 028) — which is
# why grant/revoke are named member actions rather than a general #update.
class Admin::UsersController < ApplicationController
  # Both, in this order: signed in at all, then signed in as an administrator.
  # authenticate_user! sends an anonymous visitor to log in, as everywhere else
  # on the site; require_admin! turns away everyone else (FR-004, FR-008).
  #
  # 015 FR-009: the pair covers grant_admin as well as index, so the write cannot
  # drift from the read — there is no second place to remember to guard.
  before_action :authenticate_user!
  before_action :require_admin!

  # 015 FR-011: said plainly. Between a list being drawn and a button on it being
  # pressed, the account can have cancelled itself; that is not an error to hide.
  #
  # 025: kept as a plain frozen string for existing tests that assert against it
  # by name; #grant_admin calls t(".account_gone") instead of this constant, for
  # the same locale-reactivity reason as User::LOCKER_NUMBER_TAKEN_MESSAGE.
  ACCOUNT_GONE_MESSAGE = "That account no longer exists.".freeze

  # 020: the four filters, and where each one's value arrives from. The keys are
  # the query parameters, so this is also what the filtered address looks like
  # (mirrors LockerWishesController::FILTER_AXES, feature 017).
  FILTER_AXES = %i[current_locker current_floor role email].freeze

  # FR-006/FR-010: everyone who has registered, oldest first — which puts the
  # bootstrap administrator at the top without the order having to mention the
  # flag, since the account holding it is by definition the first one there was.
  #
  # includes, and not a query per row: FR-018 puts the granting administrator's
  # email on every granted row, which through the association alone would be the
  # unbounded per-row query Principle IV names. 020 FR-003 adds :locker_wish for
  # the same reason — each row reads user.locker_wish to show the active wish (or
  # its absence), which would otherwise be a query per row too. Three queries,
  # whether the list runs to three accounts or three hundred (research.md R5,
  # 020 data-model.md). It is not paginated: see the deferral recorded in 013's
  # plan.md.
  #
  # 020 FR-004/FR-009: the four scopes are no-ops when their value is blank, so
  # they compose unconditionally into the intersection when several are set, and
  # into the single-axis list when only one is (mirrors LockerWish, feature 017).
  # FR-015: filtering removes non-matching rows without reordering the ones that
  # remain, since `order(:created_at)` is applied once, last, over whatever the
  # four scopes have already narrowed.
  def index
    @current_floor_filter = FloorFilter.new(selection: filter_selection(:current_floor),
                                             available: User.saved_floors)
    # capitalize, not the raw value: with_role matches "role" case-insensitively
    # (F1), so a hand-typed `?role=admin` filters correctly, but RoleFilter's
    # own current?/aria-current comparison is exact-string against the
    # capitalized CHOICES — this normalizes to the same canonical case the
    # filter links themselves always send, so the two never disagree about
    # what is "current".
    @role_filter = RoleFilter.new(selection: filter_selection(:role)&.capitalize)

    @users = User.includes(:admin_granted_by, :locker_wish)
                 .with_role(filter_selection(:role))
                 .on_floor(filter_selection(:current_floor))
                 .with_locker_number(filter_selection(:current_locker))
                 .email_containing(filter_selection(:email))
                 .order(:created_at)
  end

  # 015 FR-006: the grant. The confirmation that guards it lives in the view — by
  # the time a request arrives here it has been answered, so there is nothing left
  # to ask (FR-020: nothing else is asked either, no password, no second step).
  #
  # 028: reached from and redirects to the account's own detail screen now, not
  # the list — the control moved there (research.md R1). The redirect no longer
  # carries filter_selections; there is no filtered list state left to return to
  # (research.md R2).
  def grant_admin
    user = User.find_by(id: params[:id])

    # FR-011: find_by and not find, so a vanished account is a message rather than
    # a 404 — the administrator did nothing wrong and should land back on the list.
    return redirect_to admin_users_path, alert: t(".account_gone") if user.nil?

    # FR-012: grant_admin_rights! is a no-op when the account already has them, so
    # arriving second at the same destination reports success. A stale list is a
    # stale list, not a failure.
    user.grant_admin_rights!(by: current_user)

    redirect_to admin_user_path(user), notice: t(".granted", email: user.email)
  end

  # 028 FR-009: the revoke, the direct counterpart of #grant_admin above. Same
  # confirmation-lives-in-the-view shape, same account-gone handling.
  def revoke_admin
    user = User.find_by(id: params[:id])

    return redirect_to admin_users_path, alert: t(".account_gone") if user.nil?

    # FR-011, research.md R3: refused here, independent of whether the view ever
    # rendered a revoke control for this row — visibility of the control is never
    # what authorises it (015's own reasoning for #grant_admin, applied to the one
    # account this action must never be allowed to touch: the acting
    # administrator's own).
    return redirect_to admin_user_path(user), alert: t(".self_forbidden") if user == current_user

    # FR-014: revoke_admin_rights! is a no-op when the account is already
    # standard, so arriving second at the same destination reports success.
    user.revoke_admin_rights!

    redirect_to admin_user_path(user), notice: t(".revoked", email: user.email)
  end

  # 027 FR-001/FR-002/FR-003: one account's full detail — everything the list
  # already shows plus its search status and proposal history (added by
  # #search_status_data below, as the corresponding user stories land).
  #
  # find_by, not find: a vanished account is a message and a redirect back to
  # the list, the same as #grant_admin already treats one (FR-011-equivalent).
  def show
    @user = User.includes(:admin_granted_by, :locker_edited_by, :search_cancelled_by,
                           :locker_wish).find_by(id: params[:id])

    return redirect_to admin_users_path, alert: t(".account_gone") if @user.nil?

    # 027 FR-005, research.md R6: every proposal this account is party to, in
    # either role, that is still pending or accepted — zero, one, or more than
    # one, since nothing in the model caps a requester to a single simultaneous
    # pending proposal with different recipients. Two bounded queries unioned in
    # Ruby, not one `OR`, for the same reason #proposal_history below is (R5).
    @active_proposals =
      (@user.sent_swap_proposals.where(status: %i[pending accepted]).includes(:recipient).to_a +
       @user.received_swap_proposals.where(status: %i[pending accepted]).includes(:requester).to_a)

    # 027 FR-006, research.md R5: the exact expression
    # LockerSwapProposalsController#index already uses for current_user, applied
    # to the viewed account instead. Never a single `.or(...)` query on this
    # table — see LockerSwapProposal#in_progress_for?'s comment on the SQLite
    # planner fault that shape triggers against this table's partial indexes.
    @proposal_history =
      (@user.sent_swap_proposals.includes(:recipient).to_a +
       @user.received_swap_proposals.includes(:requester).to_a).sort_by(&:created_at).reverse
  end

  private

    # FR-020-equivalent robustness (research.md R5/data-model.md): a value
    # arriving in the address that is not a plain string — `?role[]=admin` — is no
    # filter at all rather than an error.
    def filter_selection(axis)
      value = params[axis]

      value.is_a?(String) ? value : nil
    end
end
