# 027 User Story 3: an administrator correcting a registered account's floor and
# locker number on its behalf, from the pencil-icon control on that account's
# detail screen (Admin::UsersController#show).
#
# Deliberately its own single-action controller rather than folded into
# Admin::UsersController, the same split LockerProfilesController already keeps
# from LockerWishesController for the analogous self-service concern.
class Admin::UserLockerProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  # FR-009: the exact same validation context — and therefore the exact same
  # swap-lock refusal — a self-service edit already runs through
  # (LockerProfilesController#update). No admin bypass (Clarifications).
  #
  # FR-009a: the edit's provenance is assigned alongside the submitted
  # attributes, in the same save, so it is only ever persisted together with a
  # successful edit.
  def update
    @user = User.includes(:admin_granted_by, :locker_edited_by, :search_cancelled_by,
                           :locker_wish).find_by(id: params[:user_id])
    return redirect_to admin_users_path, alert: t(".account_gone") if @user.nil?

    @user.assign_attributes(locker_profile_params)
    @user.locker_edited_by = current_user
    @user.locker_edited_at = Time.current

    if save_locker_profile
      redirect_to admin_user_path(@user), notice: t(".saved")
    else
      # A rejected edit must not claim a provenance fact that was never
      # persisted — @user.saved_floor/saved_locker_number already read past the
      # rejected input for the same reason (see User#saved_floor's comment);
      # locker_edited_by/at have no such saved_ accessor, so the attributes
      # themselves are reverted here instead of being left holding this
      # request's unsaved assignment.
      @user.locker_edited_by_id = @user.locker_edited_by_id_in_database
      @user.locker_edited_at = @user.locker_edited_at_in_database
      @user.association(:locker_edited_by).reset
      load_proposal_data
      render "admin/users/show", status: :unprocessable_entity
    end
  end

  private

    def locker_profile_params
      params.expect(user: [ :floor, :locker_number ])
    end

    # Mirrors LockerProfilesController#save_locker_profile exactly (same race,
    # same message key), on the target account instead of current_user.
    def save_locker_profile
      @user.save(context: :locker_profile_update)
    rescue ActiveRecord::RecordNotUnique
      @user.errors.add(:locker_number, I18n.t("user.messages.locker_number_taken"))
      false
    end

    # A rejected edit re-renders the detail screen with the same search-status
    # and proposal-history data #show itself loads, so those sections do not
    # vanish because the floor/locker edit failed.
    def load_proposal_data
      @active_proposals =
        (@user.sent_swap_proposals.where(status: %i[pending accepted]).includes(:recipient).to_a +
         @user.received_swap_proposals.where(status: %i[pending accepted]).includes(:requester).to_a)
      @proposal_history =
        (@user.sent_swap_proposals.includes(:recipient).to_a +
         @user.received_swap_proposals.includes(:requester).to_a).sort_by(&:created_at).reverse
    end
end
