require "application_system_test_case"

# 034 User Story 6: a changed address only takes effect once confirmed from the
# new mailbox (FR-021, FR-022).
class EmailChangeTest < ApplicationSystemTestCase
  NEW_EMAIL = "alice.new@example.com".freeze

  test "a new address is confirmed from its own mailbox before it replaces the old one" do
    alice = users(:alice)
    log_in_as alice

    visit edit_user_registration_path
    # 035: "Current password" is on the page twice now — once per card — so the
    # fills are scoped to the email card, which carries no new-password field.
    within(".card", text: I18n.t("devise.registrations.edit.email_section_title")) do
      assert_no_field "New password"
      assert_no_field "Password", exact: true
      fill_in_reliably "Email", with: NEW_EMAIL
      fill_in_reliably "Current password", with: VALID_PASSWORD
      click_on "Update"
    end

    assert_text I18n.t("devise.registrations.update_needs_confirmation")

    # FR-022: the account page names the address waiting for confirmation.
    visit edit_user_registration_path
    assert_text NEW_EMAIL
    assert_equal "alice@example.com", alice.reload.email

    # US6-2, analyze I2: followed while signed in, it says what changed and
    # leaves the person signed in.
    assert_equal [ NEW_EMAIL ], emails_to(NEW_EMAIL).last.to
    visit link_from_last_email(/confirmation_token=/)
    assert_text I18n.t("devise.confirmations.email_changed")
    assert_text "Welcome to LockSwap"

    click_on "Log out"
    assert_text "Signed out successfully."
    log_in_as alice.reload
    assert_equal NEW_EMAIL, alice.email
  end
end
