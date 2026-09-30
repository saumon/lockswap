require "application_system_test_case"

# 034 User Story 7: an administrator sees an account that never activated, and
# activates it by hand (FR-034 to FR-038, SC-009).
class AdminUserActivationTest < ApplicationSystemTestCase
  test "an administrator activates an account from its detail screen" do
    pending = User.create!(email: "pending@example.com", password: VALID_PASSWORD)
    admin = users(:frank)
    log_in_as admin

    visit admin_users_path
    within("#admin-user-row-#{pending.id}") { assert_text I18n.t("admin.users.index.not_activated") }
    within("#admin-user-row-#{users(:alice).id}") { assert_no_text I18n.t("admin.users.index.not_activated") }

    click_on pending.email
    within("#admin-user-detail-activation") { assert_text I18n.t("admin.users.show.not_activated") }
    assert_axe_clean

    accept_confirm_reliably { click_button I18n.t("admin.users.show.activate_button") }

    assert_text I18n.t("admin.user_activations.create.activated", email: pending.email)
    within("#admin-user-detail-activation") { assert_text "Activated by #{admin.email} on" }
    assert_no_button I18n.t("admin.users.show.activate_button")
    assert_axe_clean

    click_on "Log out"
    assert_text "Signed out successfully."
    log_in_as pending
  end
end
