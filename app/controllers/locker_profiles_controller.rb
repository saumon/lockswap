# Saves the floor and locker number shown on the homepage (002 FR-001, FR-002).
# Deliberately separate from the Devise controllers: authentication and locker
# details are different concerns, and this is the only save path that applies the
# :locker_profile_update rules.
class LockerProfilesController < ApplicationController
  # A rejected edit re-renders the homepage, which carries 004's proposal
  # sections too — they must not vanish because a floor failed validation.
  include LoadsHomepageProposals

  before_action :authenticate_user!

  # FR-009: the same action serves the first fill-in and every later edit.
  def update
    current_user.assign_attributes(locker_profile_params)

    if save_locker_profile
      redirect_to root_path, notice: t(".saved")
    else
      load_homepage_proposals
      render "home/index", status: :unprocessable_entity
    end
  end

  private

    def locker_profile_params
      params.expect(user: [ :floor, :locker_number ])
    end

    # Two submissions can both clear the uniqueness validation before either one
    # commits, so the unique index is the real guarantee (FR-011, SC-005).
    # Translating it back into the ordinary error keeps that race invisible to
    # the user instead of surfacing a 500.
    def save_locker_profile
      current_user.save(context: :locker_profile_update)
    rescue ActiveRecord::RecordNotUnique
      current_user.errors.add(:locker_number, I18n.t("user.messages.locker_number_taken"))
      false
    end
end
