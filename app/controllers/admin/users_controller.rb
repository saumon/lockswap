# 013: the administrator's view of who is registered on the site (FR-006).
#
# Read-only by design. Administrator status is claimed once, at signup, by the
# first account to exist (see User#claim_administrator_if_first); there is
# nothing here to grant, revoke, edit or delete, which is why this routes to
# index and nothing else (FR-009).
class Admin::UsersController < ApplicationController
  # Both, in this order: signed in at all, then signed in as the administrator.
  # authenticate_user! sends an anonymous visitor to log in, as everywhere else
  # on the site; require_admin! turns away everyone else (FR-004, FR-008).
  before_action :authenticate_user!
  before_action :require_admin!

  # FR-006/FR-010: everyone who has registered, oldest first — which puts the
  # administrator at the top without the order having to mention the flag, since
  # the account holding it is by definition the first one there was.
  #
  # One query, and the "Admin" label on the row is read from the column already
  # loaded with it rather than looked up again, so the page costs the same
  # whether it lists three accounts or three hundred (Principle IV). It is not
  # paginated: see the deferral recorded in the feature's plan.md.
  def index
    @users = User.order(:created_at)
  end
end
