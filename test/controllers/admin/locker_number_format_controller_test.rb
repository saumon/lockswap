require "test_helper"

# 030 User Story 3: the write behind the Danger Zone's locker number format
# section, and who may make it (FR-019).
class Admin::LockerNumberFormatControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "the super admin saves a pattern and its description" do
    sign_in users(:frank)

    patch admin_locker_number_format_path,
      params: { locker_number_format: { pattern: "\\d{3}", description: "3 chiffres, ex. 042" } }

    assert_redirected_to admin_danger_zone_path
    assert_equal I18n.t("admin.locker_number_format.update.saved"), flash[:notice]
    format = LockerNumberFormat.current
    assert_equal "\\d{3}", format.pattern
    assert_equal "3 chiffres, ex. 042", format.description
  end

  # User Story 3 scenario 4: a blank pattern lifts the format, and says so.
  test "a blank pattern clears the format" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}", description: "3 digits")
    sign_in users(:frank)

    patch admin_locker_number_format_path, params: { locker_number_format: { pattern: "", description: "3 digits" } }

    assert_redirected_to admin_danger_zone_path
    assert_equal I18n.t("admin.locker_number_format.update.cleared"), flash[:notice]
    assert_nil LockerNumberFormat.current.pattern
    assert_nil LockerNumberFormat.current.description
  end

  # FR-010: refused on the screen, previous format still in force.
  test "an invalid pattern is refused and the previous format kept" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}")
    sign_in users(:frank)

    patch admin_locker_number_format_path, params: { locker_number_format: { pattern: "[0-9" } }

    assert_response :unprocessable_entity
    assert_select "#danger-zone-locker-format .form-errors"
    assert_select "#danger-zone-floors .form-errors", count: 0
    assert_equal "\\d{3}", LockerNumberFormat.current.reload.pattern
  end

  test "a granted administrator is refused" do
    sign_in users(:grace)

    patch admin_locker_number_format_path, params: { locker_number_format: { pattern: "\\d" } }

    assert_redirected_to root_path
    assert_equal I18n.t("application.administrators_only"), flash[:alert]
    assert_nil LockerNumberFormat.current.pattern
  end

  test "a standard account is refused" do
    sign_in users(:carol)

    patch admin_locker_number_format_path, params: { locker_number_format: { pattern: "\\d" } }

    assert_redirected_to root_path
    assert_nil LockerNumberFormat.current.pattern
  end

  test "a signed-out visitor is sent to sign in" do
    patch admin_locker_number_format_path, params: { locker_number_format: { pattern: "\\d" } }

    assert_redirected_to new_user_session_path
  end
end
