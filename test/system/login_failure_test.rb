require "application_system_test_case"

# Covers spec.md User Story 3, Acceptance Scenarios 1 and 2 (FR-006).
class LoginFailureTest < ApplicationSystemTestCase
  GENERIC_FAILURE = "Invalid email or password.".freeze

  setup { @user = users(:alice) }

  # Scenario 1: an email with no account must not be distinguishable...
  test "an unknown email is denied with the generic message" do
    attempt_login_as "nobody@example.com", password: VALID_PASSWORD

    assert_current_path new_user_session_path
    assert_text GENERIC_FAILURE
    assert_no_text "Welcome to LockSwap"
  end

  # ...Scenario 2: ...from a known email with the wrong password.
  test "a wrong password is denied with the same generic message" do
    attempt_login_as @user.email, password: "wrong-password"

    assert_current_path new_user_session_path
    assert_text GENERIC_FAILURE
    assert_no_text "Welcome to LockSwap"
  end

  test "the unknown-email and wrong-password messages are identical" do
    attempt_login_as "nobody@example.com", password: VALID_PASSWORD
    unknown_email_message = failure_message

    attempt_login_as @user.email, password: "wrong-password"

    assert_equal unknown_email_message, failure_message
  end

  # Edge case: an empty submission is a failure like any other, and must not
  # reveal anything either.
  test "an empty submission is denied with the generic message" do
    visit new_user_session_path
    click_on "Log in"

    assert_text GENERIC_FAILURE
  end

  test "a failed login leaves the visitor logged out" do
    attempt_login_as @user.email, password: "wrong-password"

    visit root_path

    assert_current_path new_user_session_path
  end

  private

    def attempt_login_as(email, password:)
      visit new_user_session_path
      fill_in "Email", with: email
      fill_in "Password", with: password
      click_on "Log in"
    end

    def failure_message
      find("[role='alert']").text
    end
end
