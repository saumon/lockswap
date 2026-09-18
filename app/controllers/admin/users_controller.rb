# 013: the administrator's view of who is registered on the site (FR-006).
#
# 015 gave the screen one write — granting administrator rights — and that is the
# only one it will ever have. Removing rights, editing an account and deleting one
# are all out of scope by requirement (015 FR-014), not by omission, which is why
# this routes to index and a single named action rather than a full resource.
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
  ACCOUNT_GONE_MESSAGE = "That account no longer exists.".freeze

  # FR-006/FR-010: everyone who has registered, oldest first — which puts the
  # bootstrap administrator at the top without the order having to mention the
  # flag, since the account holding it is by definition the first one there was.
  #
  # includes, and not a query per row: FR-018 puts the granting administrator's
  # email on every granted row, which through the association alone would be the
  # unbounded per-row query Principle IV names. Two queries, whether the list runs
  # to three accounts or three hundred (research.md R5). It is not paginated: see
  # the deferral recorded in 013's plan.md.
  def index
    @users = User.includes(:admin_granted_by).order(:created_at)
  end

  # 015 FR-006: the grant. The confirmation that guards it lives in the view — by
  # the time a request arrives here it has been answered, so there is nothing left
  # to ask (FR-020: nothing else is asked either, no password, no second step).
  def grant_admin
    user = User.find_by(id: params[:id])

    # FR-011: find_by and not find, so a vanished account is a message rather than
    # a 404 — the administrator did nothing wrong and should land back on the list.
    return redirect_to admin_users_path, alert: ACCOUNT_GONE_MESSAGE if user.nil?

    # FR-012: grant_admin_rights! is a no-op when the account already has them, so
    # arriving second at the same destination reports success. A stale list is a
    # stale list, not a failure.
    user.grant_admin_rights!(by: current_user)

    redirect_to admin_users_path, notice: "#{user.email} has been granted administrator rights."
  end
end
