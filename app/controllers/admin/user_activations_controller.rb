# 034 User Story 7: an administrator activating an account by hand, from its
# detail screen — the way out when the activation email never arrived
# (FR-035 to FR-038).
#
# No email is sent (FR-038). The account's earlier activation link stays in the
# database and, followed later, reads "already active" (research.md R6). The
# conditional UPDATE inside User#activate! is what settles a race with the holder
# clicking that link at the same moment: whichever lands second changes nothing.
class Admin::UserActivationsController < ApplicationController
  # FR-037: signed in, then an administrator — the site's usual pair and refusal.
  before_action :authenticate_user!
  before_action :require_admin!

  def create
    user = User.find_by(id: params[:user_id])

    # find_by, not find: a vanished account is a message, as on every other admin
    # write on this screen (027's account_gone).
    return redirect_to admin_users_path, alert: t(".account_gone") if user.nil?

    if user.activate!(by: current_user)
      # FR-032, research.md R16
      Rails.logger.info("[account_mail] event=activated_by_admin user_id=#{user.id} admin_id=#{current_user.id}")
      redirect_to admin_user_path(user), notice: t(".activated", email: user.email)
    else
      redirect_to admin_user_path(user), notice: t(".already_active", email: user.email)
    end
  end
end
