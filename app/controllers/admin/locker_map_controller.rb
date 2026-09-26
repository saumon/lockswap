# 031 FR-001/FR-002: the Locker Map screen itself — every floor, the zones
# declared on it, and each zone's locker numbers.
class Admin::LockerMapController < ApplicationController
  before_action :authenticate_user!
  # Ordinary admin-only, not the stricter require_super_admin! the Danger
  # Zone uses — this screen is content administration, not a site-wide
  # danger-zone setting (research.md R7, mirrors Admin::UsersController).
  before_action :require_admin!

  include LoadsLockerMap

  def show
    load_locker_map
    @new_zone ||= Zone.new
  end
end
