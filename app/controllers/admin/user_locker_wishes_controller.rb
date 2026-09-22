# 027 User Story 4: an administrator cancelling a registered account's standing
# locker-search wish on its behalf, from the confirm-gated button on that
# account's detail screen (Admin::UsersController#show).
class Admin::UserLockerWishesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  # FR-011: the wish is destroyed outright, the same effect a user's own "Cancel
  # wish" action already has — and, unlike a floor/locker edit, this action is
  # never blocked by an outstanding swap proposal and never alters one (FR-011,
  # Acceptance Scenario 4): cancelling a search is always available.
  #
  # FR-011a: the cancellation's provenance is recorded on the account itself —
  # there is no wish row left afterward to carry it — via update_columns rather
  # than save, since this is a plain audit-fact write that must not run through,
  # or be blocked by, the :locker_profile_update validation context (that
  # context governs floor/locker changes only, not this pair).
  #
  # Fire-and-forget on an account with no wish, exactly like
  # LockerWishesController#destroy: someone with nothing to cancel is not an
  # error (Edge Cases).
  def destroy
    user = User.find_by(id: params[:user_id])
    return redirect_to admin_users_path, alert: t(".account_gone") if user.nil?

    if user.locker_wish
      user.locker_wish.destroy
      user.update_columns(search_cancelled_by_id: current_user.id, search_cancelled_at: Time.current)
    end

    redirect_to admin_user_path(user), notice: t(".cancelled")
  end
end
