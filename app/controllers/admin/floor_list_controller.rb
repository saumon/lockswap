# 030 User Story 1: the super admin saving the site's list of floors from the
# Danger Zone (FR-001). One write, one resource — the screen that shows it is
# Admin::DangerZoneController#show.
class Admin::FloorListController < ApplicationController
  include LoadsDangerZone

  # FR-019: the same pair, in the same order, that guards the rest of the Danger
  # Zone (029 FR-005/FR-006). Restated here rather than inherited, for the reason
  # Admin::DangerZoneController gives.
  before_action :authenticate_user!
  before_action :require_super_admin!

  # The notice says the list was saved and nothing more: how many accounts or
  # wishes sit on a floor no longer listed is deliberately not reported
  # (clarification Q4) — their data is kept until next edited either way
  # (FR-011).
  def update
    @site_floor_list = SiteFloorList.current

    if @site_floor_list.update(floor_list_params)
      redirect_to admin_danger_zone_path, notice: t(".saved")
    else
      load_danger_zone
      render "admin/danger_zone/show", status: :unprocessable_entity
    end
  end

  private

    # Only the typed line: the array is always derived from it, so the FR-002
    # clean-up cannot be written around.
    def floor_list_params
      params.expect(site_floor_list: [ :floors_text ])
    end
end
