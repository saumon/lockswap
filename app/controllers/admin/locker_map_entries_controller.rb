# 031 FR-005 through FR-008: declaring, and (US3) removing, one locker
# number within a zone.
class Admin::LockerMapEntriesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  include LoadsLockerMap

  def create
    zone = Zone.find_by(id: params[:zone_id])
    return redirect_to admin_locker_map_path, alert: t(".zone_gone") if zone.nil?

    @locker_map_entry = zone.locker_map_entries.new(locker_map_entry_params)

    if save_locker_map_entry
      redirect_to admin_locker_map_path, notice: t(".saved")
    else
      load_locker_map
      @new_zone = Zone.new
      render "admin/locker_map/show", status: :unprocessable_entity
    end
  end

  # Idempotent, the same "already the desired end state" posture #destroy on
  # zones takes.
  def destroy
    Zone.find_by(id: params[:zone_id])&.locker_map_entries&.find_by(id: params[:id])&.destroy

    redirect_to admin_locker_map_path, notice: t(".deleted")
  end

  private

    def locker_map_entry_params
      params.expect(locker_map_entry: [ :locker_number ])
    end

    # research.md R6: mirrors LockerProfilesController#save_locker_profile
    # exactly — two admins declaring the same floor + locker number at once
    # can both pass validation before either commits, so the unique index is
    # the real guarantee; this turns that race into the ordinary error
    # instead of a 500.
    def save_locker_map_entry
      @locker_map_entry.save
    rescue ActiveRecord::RecordNotUnique
      @locker_map_entry.errors.add(:locker_number, I18n.t("locker_map_entry.messages.locker_taken", zone: nil))
      false
    end
end
