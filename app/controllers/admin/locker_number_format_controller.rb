# 030 User Story 3: the super admin setting the format every locker number must
# follow, from the Danger Zone (FR-009). One write, one resource — the screen
# that shows it is Admin::DangerZoneController#show.
class Admin::LockerNumberFormatController < ApplicationController
  include LoadsDangerZone

  # FR-019: the same guard, in the same order, as the rest of the Danger Zone
  # (029 FR-005/FR-006), restated for the reason Admin::DangerZoneController gives.
  before_action :authenticate_user!
  before_action :require_super_admin!

  # A blank pattern is a legitimate save — it lifts the format — so the notice
  # says which of the two happened. Neither reports how many locker numbers on
  # file do not match: they are kept until next changed (FR-017), and the
  # confirmation says nothing about them (clarification Q4).
  def update
    @locker_number_format = LockerNumberFormat.current

    if @locker_number_format.update(locker_number_format_params)
      redirect_to admin_danger_zone_path,
        notice: @locker_number_format.in_force? ? t(".saved") : t(".cleared")
    else
      load_danger_zone
      render "admin/danger_zone/show", status: :unprocessable_entity
    end
  end

  private

    def locker_number_format_params
      params.expect(locker_number_format: [ :pattern, :description ])
    end
end
