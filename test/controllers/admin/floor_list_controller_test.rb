require "test_helper"

# 030 User Story 1: the write behind the Danger Zone's floors section, and who
# may make it (FR-019: the same rule as the rest of the screen, 029).
class Admin::FloorListControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "the super admin saves the list" do
    sign_in users(:frank)

    patch admin_floor_list_path, params: { site_floor_list: { floors_text: "0, 1, 2, 3" } }

    assert_redirected_to admin_danger_zone_path
    assert_equal I18n.t("admin.floor_list.update.saved"), flash[:notice]
    assert_equal %w[0 1 2 3], SiteFloorList.current.floors
  end

  # FR-003: refused on the screen the super admin was on, list untouched.
  test "an empty list is refused and the saved list kept" do
    SiteFloorList.current.update!(floors_text: "0, 1")
    sign_in users(:frank)

    patch admin_floor_list_path, params: { site_floor_list: { floors_text: " , " } }

    assert_response :unprocessable_entity
    assert_select "#danger-zone-floors .form-errors"
    assert_equal %w[0 1], SiteFloorList.current.reload.floors
  end

  # FR-019: a granted administrator is refused exactly as for the rest of the
  # danger zone.
  test "a granted administrator is refused" do
    sign_in users(:grace)

    patch admin_floor_list_path, params: { site_floor_list: { floors_text: "9" } }

    assert_redirected_to root_path
    assert_equal I18n.t("application.administrators_only"), flash[:alert]
    assert_nil SiteFloorList.current.floors
  end

  test "a standard account is refused" do
    sign_in users(:carol)

    patch admin_floor_list_path, params: { site_floor_list: { floors_text: "9" } }

    assert_redirected_to root_path
    assert_nil SiteFloorList.current.floors
  end

  test "a signed-out visitor is sent to sign in" do
    patch admin_floor_list_path, params: { site_floor_list: { floors_text: "9" } }

    assert_redirected_to new_user_session_path
  end

  # Only the typed line is accepted: the array itself cannot be written around
  # the clean-up.
  test "the floors array itself cannot be submitted" do
    sign_in users(:frank)

    patch admin_floor_list_path, params: { site_floor_list: { floors_text: "1", floors: [ " x ", "" ] } }

    assert_equal %w[1], SiteFloorList.current.floors
  end
end
