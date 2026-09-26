require "test_helper"

# 031 FR-001/FR-002: the Locker Map screen itself — who may open it, and what
# it shows.
class Admin::LockerMapControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "an admin sees the screen" do
    sign_in users(:grace)

    get admin_locker_map_path

    assert_response :success
  end

  test "a standard account is refused" do
    sign_in users(:carol)

    get admin_locker_map_path

    assert_redirected_to root_path
    assert_equal I18n.t("application.administrators_only"), flash[:alert]
  end

  test "a signed-out visitor is sent to sign in" do
    get admin_locker_map_path

    assert_redirected_to new_user_session_path
  end

  test "a zone with entries appears grouped under its floor" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    zone.locker_map_entries.create!(locker_number: "203")
    sign_in users(:grace)

    get admin_locker_map_path

    assert_select "body", text: /Aile Nord/
    assert_select "body", text: /203/
  end
end
