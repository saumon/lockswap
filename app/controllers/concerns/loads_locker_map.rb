# 031: everything the Locker Map screen draws. Lives here because the screen
# has several renderers: Admin::LockerMapController#show, and every
# controller whose write belongs to it and re-renders it on a refusal
# (Admin::ZonesController, Admin::LockerMapEntriesController) — the same
# "several renderers, one loader" shape LoadsDangerZone already established
# (research.md, mirroring 030's LoadsDangerZone).
module LoadsLockerMap
  extend ActiveSupport::Concern

  private

    # ||= is load-bearing: the controller whose write was refused has already
    # assigned its own `@new_zone` or `@zone` — holding the rejected input and
    # its errors — and that object, not a fresh copy, is what the re-render
    # must show.
    #
    # @floors falls back to the floors already used by a declared Zone when no
    # site-wide list is configured, so an existing zone is never orphaned off
    # the screen (contracts/admin-locker-map.md) — but these sections are
    # read-only groupings; they do not gate where a new zone can be created
    # (see admin/zones/_new_zone_form.html.erb, finding C1).
    def load_locker_map
      @floors ||= SiteFloorList.current.configured? ? SiteFloorList.current.floors : Zone.distinct.order(:floor).pluck(:floor)
      @zones_by_floor ||= Zone.includes(:locker_map_entries).order(:name).group_by(&:floor)
    end
end
