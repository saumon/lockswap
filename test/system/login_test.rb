require "application_system_test_case"

# Covers spec.md User Story 2 (FR-004, FR-005, FR-007, FR-009).
class LoginTest < ApplicationSystemTestCase
  setup { @user = users(:alice) }

  # Acceptance Scenario 1: correct credentials land on the homepage immediately.
  test "a visitor with an account logs in and is shown the homepage" do
    log_in_as @user

    assert_current_path root_path
    assert_text "Welcome to LockSwap"
    assert_text @user.email
  end

  test "the session survives a page reload" do
    log_in_as @user

    visit root_path

    assert_current_path root_path
    assert_text "Welcome to LockSwap"
  end

  # Acceptance Scenario 2: the session outlives the browser itself. Clearing the
  # session cookie while keeping the persistent one is what a browser restart does.
  test "the session survives a browser restart" do
    log_in_as @user
    restart_browser_session

    visit root_path

    assert_current_path root_path
    assert_text "Welcome to LockSwap"
  end

  # FR-007: persistent for up to 30 days...
  test "the session is still valid 29 days after logging in" do
    log_in_as @user
    restart_browser_session

    travel 29.days do
      visit root_path

      assert_current_path root_path
      assert_text "Welcome to LockSwap"
    end
  end

  # ...and no longer.
  test "the session has expired 31 days after logging in" do
    log_in_as @user
    restart_browser_session

    travel 31.days do
      visit root_path

      assert_current_path new_user_session_path
      assert_no_text "Welcome to LockSwap"
    end
  end

  # Acceptance Scenario 3: logging out ends the session for good.
  test "logging out ends the session and blocks the homepage" do
    log_in_as @user

    click_on "Log out"

    assert_current_path new_user_session_path
    assert_text "Signed out successfully."

    visit root_path

    assert_current_path new_user_session_path
    assert_no_text "Welcome to LockSwap"
  end

  test "logging out also clears the persistent session" do
    log_in_as @user
    click_on "Log out"
    assert_text "Signed out successfully."
    restart_browser_session

    visit root_path

    assert_current_path new_user_session_path
  end
end
