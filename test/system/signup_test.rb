require "application_system_test_case"

# Covers 001 spec.md User Story 1 (FR-001, FR-002, FR-003) and 014 spec.md User
# Story 1 — the password is typed twice and the two have to agree before an
# account is created.
class SignupTest < ApplicationSystemTestCase
  # 014 FR-003: the words the mismatch is reported in, kept in one place so the
  # tests below assert the real message rather than a paraphrase of it.
  MISMATCH_MESSAGE = "doesn't match the password above".freeze

  test "a visitor creates an account and lands on the homepage" do
    assert_difference -> { User.count }, 1 do
      visit new_user_registration_path

      fill_in "Email", with: "new.person@example.com"
      fill_in "Password", with: "password123"
      fill_in "Confirm password", with: "password123"
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
    fill_in "Confirm password", with: "password123"
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
      fill_in "Confirm password", with: "password123"
      click_on "Create account"
    end

    assert_text "Email is already registered"
    assert_no_text "Welcome to LockSwap"
  end

  # Acceptance Scenario 3: a password shorter than 8 characters is rejected with
  # an explanation of what to correct.
  #
  # 014 Edge Case: the confirmation matches here, deliberately. A password that
  # was typed twice identically is still too short, and the length rule has to
  # keep reporting that on its own — agreeing with yourself is not a way past it.
  test "a password shorter than 8 characters is rejected with an explanation" do
    assert_no_difference -> { User.count } do
      visit new_user_registration_path

      fill_in "Email", with: "new.person@example.com"
      fill_in "Password", with: "short"
      fill_in "Confirm password", with: "short"
      click_on "Create account"
    end

    assert_text "Password must be at least 8 characters long."
    assert_no_text MISMATCH_MESSAGE
  end

  # Acceptance Scenario 3: an invalid email format is rejected with an explanation.
  test "an invalid email format is rejected with an explanation" do
    assert_no_difference -> { User.count } do
      visit new_user_registration_path

      fill_in "Email", with: "not-an-email"
      fill_in "Password", with: "password123"
      fill_in "Confirm password", with: "password123"
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

  # --- 014: the confirmation field ------------------------------------------

  # 014 Acceptance Scenario 2 (FR-002, FR-003): two different values, no account,
  # and a message that names this problem rather than password trouble generally.
  test "two different passwords are refused with a message of their own" do
    assert_no_difference -> { User.count } do
      visit new_user_registration_path

      fill_in_reliably "Email", with: "new.person@example.com"
      fill_in_reliably "Password", with: "password123"
      fill_in_reliably "Confirm password", with: "password124"
      click_on "Create account"
    end

    assert_text MISMATCH_MESSAGE
    # FR-003: distinguishable from the other password error, not folded into it.
    assert_no_text "at least 8 characters"
    assert_no_text "Welcome to LockSwap"
  end

  # 014 Acceptance Scenario 4 (FR-002): leaving the confirmation blank is a
  # mismatch like any other — not a field that is simply skipped.
  test "an empty confirmation is refused as a mismatch" do
    assert_no_difference -> { User.count } do
      visit new_user_registration_path

      fill_in_reliably "Email", with: "new.person@example.com"
      fill_in_reliably "Password", with: "password123"
      click_on "Create account"
    end

    assert_text MISMATCH_MESSAGE
  end

  # 014 Acceptance Scenario 5 (FR-004): nothing is said while the confirmation is
  # being typed for the first time. A mismatch reported against a half-typed
  # value is a complaint about something the visitor has not finished saying.
  test "no mismatch message appears while the confirmation is first being typed" do
    visit new_user_registration_path

    fill_in_reliably "Password", with: "password123"
    find_field("Confirm password").send_keys("passwo")

    assert_no_text MISMATCH_MESSAGE
  end

  # 014 Acceptance Scenario 6 (FR-004, SC-004): leaving the field runs the check
  # for the first time, and from then on every edit re-runs it — the message
  # clears itself without a second blur and without submitting the form.
  test "the mismatch message appears on leaving the confirmation and then tracks every edit" do
    visit new_user_registration_path

    fill_in_reliably "Password", with: "password123"
    fill_in_reliably "Confirm password", with: "password124"
    find_field("Confirm password").send_keys(:tab)

    assert_text MISMATCH_MESSAGE

    fill_in_reliably "Confirm password", with: "password123"

    assert_no_text MISMATCH_MESSAGE
  end

  # 014 Acceptance Scenario 3: and once corrected, the signup goes through.
  test "correcting the confirmation lets the signup through" do
    assert_difference -> { User.count }, 1 do
      visit new_user_registration_path

      fill_in_reliably "Email", with: "new.person@example.com"
      fill_in_reliably "Password", with: "password123"
      fill_in_reliably "Confirm password", with: "password124"
      find_field("Confirm password").send_keys(:tab)
      assert_text MISMATCH_MESSAGE

      fill_in_reliably "Confirm password", with: "password123"
      click_on "Create account"

      assert_current_path root_path
    end

    assert_text "Welcome to LockSwap"
  end
end
