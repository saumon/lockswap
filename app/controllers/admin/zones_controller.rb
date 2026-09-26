# 031 FR-003/FR-004/FR-006: creating, renaming, and (US3) deleting a zone.
class Admin::ZonesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  include LoadsLockerMap

  # FR-003: the zone's floor is fixed here, at creation, and never assigned
  # again (FR-004).
  def create
    @zone = Zone.new(zone_params)

    if save_zone
      redirect_to admin_locker_map_path, notice: t(".saved")
    else
      load_locker_map
      # The standalone new-zone form re-appears with its errors — there is
      # only one such form (finding C1), so no "which floor" bookkeeping is
      # needed the way per-floor forms would have required.
      @new_zone = @zone
      render "admin/locker_map/show", status: :unprocessable_entity
    end
  end

  # FR-004: only the name may change. A submitted floor is silently ignored —
  # zone_params.except(:floor) never even reaches assign_attributes.
  def update
    @zone = Zone.find_by(id: params[:id])
    return redirect_to admin_locker_map_path, alert: t(".zone_gone") if @zone.nil?

    @zone.assign_attributes(zone_params.except(:floor))

    if save_zone
      redirect_to admin_locker_map_path, notice: t(".saved")
    else
      load_locker_map
      @new_zone = Zone.new
      render "admin/locker_map/show", status: :unprocessable_entity
    end
  end

  # FR-006, research.md R4: cascades to every locker map entry it holds, in
  # one action. Idempotent — arriving a second time (the zone already gone)
  # still reports success, the same posture
  # Admin::UsersController#grant_admin's vanished-record handling takes.
  def destroy
    Zone.find_by(id: params[:id])&.destroy

    redirect_to admin_locker_map_path, notice: t(".deleted")
  end

  private

    def zone_params
      params.expect(zone: [ :floor, :name ])
    end

    # finding M1: the same DB-level race LockerMapEntriesController#create
    # rescues (research.md R6), applied symmetrically — two admins naming a
    # zone the same thing on the same floor at once would otherwise 500
    # instead of getting a friendly validation error.
    def save_zone
      @zone.save
    rescue ActiveRecord::RecordNotUnique
      @zone.errors.add(:name, I18n.t("zone.messages.name_taken"))
      false
    end
end
