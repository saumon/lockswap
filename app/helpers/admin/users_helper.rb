# 020: the addresses and carried-forward values behind the admin Users screen's
# four filters.
module Admin::UsersHelper
  # The current value of one filter axis, however it is represented: the two
  # link-based axes read it off their filter object, the two text axes read it
  # off the request directly. One place for both partials to ask, so they cannot
  # disagree about what "current" means for a given axis.
  def admin_user_filter_current_value(axis)
    case axis
    when :current_floor then @current_floor_filter.selection
    when :role then @role_filter.selection
    else params[axis].presence
    end
  end

  # The screen for one choice on one link-filter axis, with every other axis
  # left exactly as it is — so choosing a floor does not also clear a role
  # selection, and the two text filters travel through untouched (mirrors
  # LockerWishesHelper#locker_wish_filter_path, feature 017).
  #
  # `value` is nil for the "All ..." choice.
  def admin_user_filter_path(axis:, value:)
    Admin::UsersController::FILTER_AXES.index_with { |other| admin_user_filter_current_value(other) }
                                        .merge(axis => value)
                                        .transform_values(&:presence)
      .then { |selections| admin_users_path(selections) }
  end
end
