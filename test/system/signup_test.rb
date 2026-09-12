require "application_system_test_case"

# Covers spec.md User Story 1 (FR-001, FR-002, FR-003).
class SignupTest < ApplicationSystemTestCase
  test "a visitor creates an account and lands on the homepage" do
    assert_difference -> { User.count }, 1 do
      visit new_user_registration_path

      fill_in "Email", with: "new.person@example.com"
      fill_in "Password", with: "password123"
      click_on "Create account"

      assert_current_path root_path
    end

    assert_text "Welcome to LockSwap"
    assert_text "new.person@example.com"
  end

  # FR-007: the account created by signup gets the same 30-day persistent
  # session a normal login does — no second trip through the login form.
  test "a new account is signed in persistently" do
    visit new_user_registration_path
    fill_in "Email", with: "new.person@example.com"
    fill_in "Password", with: "password123"
    click_on "Create account"
    assert_text "Welcome to LockSwap"

    restart_browser_session
    visit root_path

    assert_current_path root_path
    assert_text "Welcome to LockSwap"
  end

  # Acceptance Scenario 2: duplicate email is rejected, no second account created.
  test "a duplicate email is rejected without creating a second account" do
    assert_no_difference -> { User.count } do
      visit new_user_registration_path

      fill_in "Email", with: users(:alice).email
      fill_in "Password", with: "password123"
      click_on "Create account"
    end

    assert_text "Email is already registered"
    assert_no_text "Welcome to LockSwap"
  end

  # Acceptance Scenario 3: a password shorter than 8 characters is rejected with
  # an explanation of what to correct.
  test "a password shorter than 8 characters is rejected with an explanation" do
    assert_no_difference -> { User.count } do
      visit new_user_registration_path

      fill_in "Email", with: "new.person@example.com"
      fill_in "Password", with: "short"
      click_on "Create account"
    end

    assert_text "Password must be at least 8 characters long."
  end

  # Acceptance Scenario 3: an invalid email format is rejected with an explanation.
  test "an invalid email format is rejected with an explanation" do
    assert_no_difference -> { User.count } do
      visit new_user_registration_path

      fill_in "Email", with: "not-an-email"
      fill_in "Password", with: "password123"
      click_on "Create account"
    end

    assert_text "Email must look like an email address"
  end

  # Edge case: empty fields must be reported, not silently accepted.
  test "an empty submission reports the required fields" do
    assert_no_difference -> { User.count } do
      visit new_user_registration_path
      click_on "Create account"
    end

    assert_text "Email can't be blank"
    assert_text "Password can't be blank"
  end
end
