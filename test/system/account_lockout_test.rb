require "application_system_test_case"

# Covers spec.md User Story 3, Acceptance Scenario 3 and the cooldown edge case
# (FR-011, SC-006).
class AccountLockoutTest < ApplicationSystemTestCase
  GENERIC_FAILURE = "Invalid email or password.".freeze

  setup { @user = users(:alice) }

  test "five consecutive failures lock the account" do
    5.times { attempt_login_with "wrong-password" }

    assert @user.reload.access_locked?
    assert_equal 5, @user.failed_attempts
  end

  # SC-006: while locked, even the correct password is refused...
  test "the correct password is refused while the account is locked" do
    5.times { attempt_login_with "wrong-password" }

    attempt_login_with VALID_PASSWORD

    assert_current_path new_user_session_path
    assert_no_text "Welcome to LockSwap"
  end

  # ...and the refusal looks exactly like any other failed login, so the lockout
  # never confirms that the account exists (FR-006).
  test "the lockout is reported with the generic failure message" do
    5.times { attempt_login_with "wrong-password" }

    attempt_login_with VALID_PASSWORD

    assert_text GENERIC_FAILURE
  end

  test "four failures do not lock the account" do
    4.times { attempt_login_with "wrong-password" }

    assert_not @user.reload.access_locked?

    attempt_login_with VALID_PASSWORD

    assert_current_path root_path
    assert_text "Welcome to LockSwap"
  end

  # Edge case: once the 15-minute cooldown elapses the account works again...
  test "the account accepts the correct password once the cooldown elapses" do
    5.times { attempt_login_with "wrong-password" }

    travel 16.minutes do
      attempt_login_with VALID_PASSWORD

      assert_current_path root_path
      assert_text "Welcome to LockSwap"
    end
  end

  # ...with the failure count reset, so the next 5 failures start from zero.
  test "the failure count resets after a successful login" do
    5.times { attempt_login_with "wrong-password" }

    travel 16.minutes do
      attempt_login_with VALID_PASSWORD

      assert_equal 0, @user.reload.failed_attempts
      assert_not @user.access_locked?
    end
  end

  test "the account is still locked just before the cooldown elapses" do
    5.times { attempt_login_with "wrong-password" }

    travel 14.minutes do
      attempt_login_with VALID_PASSWORD

      assert_current_path new_user_session_path
      assert_text GENERIC_FAILURE
    end
  end

  private

    def attempt_login_with(password)
      visit new_user_session_path
      fill_in "Email", with: @user.email
      fill_in "Password", with: password
      click_on "Log in"
      # Block until the response has landed, so this attempt is counted before the
      # next one starts. Every outcome — refused, locked out, or signed in —
      # announces itself in the flash, so that is the thing to wait for. The wait
      # has to be the ordinary one: a tight wait leaves Capybara no budget to retry
      # the query it runs while the page is still being replaced, and the stale
      # element it hits then fails whichever test lost that race.
      assert_selector "[role=alert], [role=status]"
    end
end
