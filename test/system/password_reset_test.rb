require "application_system_test_case"

# 034 User Story 3: from "Forgot your password?" on the sign-in screen, through
# the emailed link, to signed in with the new password (SC-005).
class PasswordResetTest < ApplicationSystemTestCase
  NEW_PASSWORD = "brand-new-pass".freeze

  test "a forgotten password is replaced from the emailed link" do
    alice = users(:alice)

    visit new_user_session_path
    click_on I18n.t("devise.sessions.new.forgot_password")
    assert_axe_clean

    fill_in_reliably "Email", with: alice.email
    click_on I18n.t("devise.passwords.new.submit")
    assert_text I18n.t("devise.passwords.send_paranoid_instructions")

    visit link_from_last_email(/reset_password_token=/)
    assert_axe_clean

    # US3-5: signup's own mismatch message, and the link survives it.
    fill_in_reliably "New password", with: NEW_PASSWORD
    fill_in_reliably "Confirm new password", with: "something-else"
    click_on I18n.t("devise.passwords.edit.submit")
    assert_text "doesn't match the password above"

    fill_in_reliably "New password", with: NEW_PASSWORD
    fill_in_reliably "Confirm new password", with: NEW_PASSWORD
    click_on I18n.t("devise.passwords.edit.submit")
    assert_text "Welcome to LockSwap"

    # US3-4: the old password no longer works; the new one does.
    click_on "Log out"
    assert_text "Signed out successfully."
    fill_in_reliably "Email", with: alice.email
    fill_in_reliably "Password", with: VALID_PASSWORD
    click_on "Log in"
    assert_text I18n.t("devise.failure.invalid", authentication_keys: "Email")

    log_in_as alice, password: NEW_PASSWORD
  end
end
