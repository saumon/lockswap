require "test_helper"

# 034 User Story 1 (following the activation link, FR-006/FR-008) and User
# Story 4 (asking for a new one, FR-011 to FR-013, FR-023).
class Users::ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @pending = User.create!(email: "pending@example.com", password: VALID_PASSWORD)
    @token = @pending.confirmation_token
    clear_enqueued_jobs
  end

  # ---- show: following the link -------------------------------------------

  # FR-006, US1-2: the link activates and invites sign-in — it does not sign in.
  test "a valid link activates the account and sends it to sign in" do
    get user_confirmation_path(confirmation_token: @token)

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("devise.confirmations.confirmed"), flash[:notice]
    assert_predicate @pending.reload, :confirmed?

    get root_path
    assert_redirected_to new_user_session_path
  end

  # FR-007/FR-008: after 24 hours the link is refused and the account stays as
  # it was; the page offers a new one.
  test "an expired link is refused with a way to get a new one" do
    travel 25.hours do
      get user_confirmation_path(confirmation_token: @token)
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("devise.confirmations.new.outcome.expired")
    assert_select "form[action=?]", user_confirmation_path
    assert_not_predicate @pending.reload, :confirmed?
  end

  # FR-008, spec edge case: a second click says so rather than erroring.
  test "a link followed twice says the account is already active" do
    get user_confirmation_path(confirmation_token: @token)
    get user_confirmation_path(confirmation_token: @token)

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("devise.confirmations.new.outcome.already_active")
    assert_select "a[href=?]", new_user_session_path
  end

  test "an unknown link is refused" do
    get user_confirmation_path(confirmation_token: "not-a-real-token")

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("devise.confirmations.new.outcome.unrecognised")
  end

  # analyze I2: the email-change link is usually followed while signed in, and
  # confirms an address rather than activating an account.
  test "confirming a changed address while signed in stays signed in and says what changed" do
    alice = users(:alice)
    sign_in alice
    alice.update!(email: "alice.new@example.com")
    token = alice.reload.confirmation_token

    get user_confirmation_path(confirmation_token: token)

    assert_redirected_to root_path
    assert_equal I18n.t("devise.confirmations.email_changed"), flash[:notice]
    assert_equal "alice.new@example.com", alice.reload.email
  end

  # ---- create: asking for a new email --------------------------------------

  def request_new_email(email)
    post user_confirmation_path, params: { user: { email: email } }
  end

  def assert_generic_answer
    assert_redirected_to new_user_session_path
    assert_equal I18n.t("devise.confirmations.send_paranoid_instructions"), flash[:notice]
  end

  # FR-011
  test "an unactivated address gets a new email once five minutes have passed" do
    travel 6.minutes do
      assert_enqueued_emails 1 do
        request_new_email(@pending.email)
      end
    end

    assert_generic_answer
  end

  # FR-023: the signup email itself counts, so an immediate request waits.
  test "a request within five minutes of the last email sends nothing" do
    assert_no_enqueued_emails do
      request_new_email(@pending.email)
    end

    assert_generic_answer
  end

  # FR-013, SC-006
  test "an active address gets nothing and the same answer" do
    assert_no_enqueued_emails do
      request_new_email(users(:alice).email)
    end

    assert_generic_answer
  end

  test "an unknown address gets nothing and the same answer" do
    assert_no_enqueued_emails do
      request_new_email("nobody@example.com")
    end

    assert_generic_answer
  end

  test "the address is matched however it was typed" do
    travel 6.minutes do
      assert_enqueued_emails 1 do
        request_new_email("  Pending@Example.COM ")
      end
    end
  end
end
