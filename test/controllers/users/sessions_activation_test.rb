require "test_helper"

# 034 User Story 2: an account that has not been activated cannot sign in, even
# with the right password (FR-005), without revealing that to someone who does
# not know it (FR-006), and without sending anything as a side effect (FR-009).
class Users::SessionsActivationTest < ActionDispatch::IntegrationTest
  setup do
    @pending = User.create!(email: "pending@example.com", password: VALID_PASSWORD)
    clear_enqueued_jobs
  end

  def sign_in_with(password)
    post user_session_path, params: { user: { email: @pending.email, password: password } }
  end

  test "the right password is refused until the account is activated" do
    sign_in_with VALID_PASSWORD

    assert_equal I18n.t("devise.failure.unconfirmed"), flash[:alert]
    get root_path
    assert_redirected_to new_user_session_path
  end

  # FR-006: activation status is only ever told to someone who knew the password.
  test "a wrong password gets the usual generic message" do
    sign_in_with "not-the-password"

    assert_equal I18n.t("devise.failure.invalid", authentication_keys: "Email"), flash[:alert]
  end

  # FR-009
  test "a refused sign-in sends no email" do
    assert_no_enqueued_emails do
      sign_in_with VALID_PASSWORD
      sign_in_with "not-the-password"
    end
  end

  # Spec edge case: activate after a refused attempt, and the next one works.
  test "once activated, the same password signs in" do
    sign_in_with VALID_PASSWORD
    @pending.confirm

    sign_in_with VALID_PASSWORD

    assert_redirected_to root_path
  end
end
