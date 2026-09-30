require "application_system_test_case"

# 034 User Story 1 (activate from the email), User Story 2 (no sign-in before
# that), User Story 4 (ask for a new email) — through the browser, following the
# links out of the emails the app actually sent.
class AccountActivationTest < ApplicationSystemTestCase
  EMAIL = "new.person@example.com".freeze

  # US1-1 to US1-3, SC-003
  test "a new account is activated from its email and can then sign in" do
    sign_up EMAIL

    assert_current_path new_user_session_path
    assert_text I18n.t("devise.registrations.signed_up_but_unconfirmed")
    assert_no_text "Welcome to LockSwap"
    assert_axe_clean

    visit link_from_last_email(/confirmation_token=/)
    assert_text I18n.t("devise.confirmations.confirmed")

    log_in_as User.find_by!(email: EMAIL)
  end

  # US2-1, FR-005: the right password is not enough before activation, and the
  # screen still shows the way to a new email.
  test "an unactivated account is refused and pointed at a new activation email" do
    sign_up EMAIL

    fill_in_reliably "Email", with: EMAIL
    fill_in_reliably "Password", with: VALID_PASSWORD
    click_on "Log in"

    assert_text I18n.t("devise.failure.unconfirmed")
    assert_no_text "Welcome to LockSwap"
    assert_link I18n.t("devise.sessions.new.no_activation_email")
  end

  # US4-1/US4-2, FR-012: after a resend only the newest link works.
  test "a new activation email replaces the earlier link" do
    sign_up EMAIL
    first_link = link_from_last_email(/confirmation_token=/)

    travel 6.minutes do
      visit new_user_session_path
      click_on I18n.t("devise.sessions.new.no_activation_email")
      assert_axe_clean
      fill_in_reliably "Email", with: EMAIL
      click_on I18n.t("devise.confirmations.new.submit")
      assert_text I18n.t("devise.confirmations.send_paranoid_instructions")
      second_link = link_from_last_email(/confirmation_token=/)

      visit first_link
      assert_text I18n.t("devise.confirmations.new.outcome.unrecognised")

      visit second_link
      assert_text I18n.t("devise.confirmations.confirmed")
    end
  end

  private

    def sign_up(email)
      visit new_user_registration_path
      fill_in_reliably "Email", with: email
      fill_in_reliably "Password", with: VALID_PASSWORD
      fill_in_reliably "Confirm password", with: VALID_PASSWORD
      click_on "Create account"

      # Wait for the server's answer: until it lands, the activation email may
      # not be queued yet, and reading it back would race the request.
      assert_text I18n.t("devise.registrations.signed_up_but_unconfirmed")
    end
end
