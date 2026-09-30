require "test_helper"

# 034 User Story 3: password reset by emailed link (FR-014 to FR-020, FR-023,
# FR-039, FR-040).
class Users::PasswordsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  NEW_PASSWORD = "brand-new-pass".freeze

  setup do
    @alice = users(:alice)
  end

  # ---- create: asking for a link -------------------------------------------

  # FR-015
  test "a reset for an existing account sends one link and gives the generic answer" do
    assert_enqueued_email_with UserMailer, :reset_password_instructions,
                               args: ->(args) { args.first == @alice } do
      post user_password_path, params: { user: { email: @alice.email } }
    end

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("devise.passwords.send_paranoid_instructions"), flash[:notice]
  end

  # FR-016, SC-006: an unknown address is answered exactly the same way.
  test "a reset for an unknown address sends nothing and gives the same answer" do
    assert_no_enqueued_emails do
      post user_password_path, params: { user: { email: "nobody@example.com" } }
    end

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("devise.passwords.send_paranoid_instructions"), flash[:notice]
  end

  # FR-023: one reset email per address per five minutes.
  test "a second request within five minutes sends nothing" do
    post user_password_path, params: { user: { email: @alice.email } }

    assert_no_enqueued_emails do
      travel 4.minutes do
        post user_password_path, params: { user: { email: @alice.email } }
      end
    end

    travel 6.minutes do
      assert_enqueued_emails 1 do
        post user_password_path, params: { user: { email: @alice.email } }
      end
    end
  end

  test "the address is matched however it was typed" do
    assert_enqueued_emails 1 do
      post user_password_path, params: { user: { email: "  ALICE@example.com " } }
    end
  end

  # ---- update: choosing the new password -----------------------------------

  # FR-019, FR-039: signed in with the new password, the old one refused, and a
  # notice sent to the account.
  test "a valid reset changes the password, signs in, and sends a notice" do
    token = @alice.send_reset_password_instructions
    clear_enqueued_jobs

    assert_enqueued_email_with UserMailer, :password_change, args: ->(args) { args.first == @alice } do
      put user_password_path, params: { user: { reset_password_token: token,
                                                password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD } }
    end

    assert_redirected_to root_path
    assert @alice.reload.valid_password?(NEW_PASSWORD)
    assert_not @alice.valid_password?(VALID_PASSWORD)

    get root_path
    assert_response :success
  end

  # US3-5: a mismatch is refused with signup's own message, and the link still works.
  test "mismatched passwords are refused and the link stays usable" do
    token = @alice.send_reset_password_instructions

    put user_password_path, params: { user: { reset_password_token: token,
                                              password: NEW_PASSWORD, password_confirmation: "something-else" } }

    assert_response :unprocessable_content
    assert_select "#error_explanation li", text: /#{Regexp.escape(I18n.t("activerecord.errors.models.user.attributes.password_confirmation.confirmation"))}/

    put user_password_path, params: { user: { reset_password_token: token,
                                              password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD } }
    assert_redirected_to root_path
  end

  # US3-6, FR-018: a link works once.
  test "a used link is refused" do
    token = @alice.send_reset_password_instructions
    params = { user: { reset_password_token: token, password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD } }

    put user_password_path, params: params
    delete destroy_user_session_path
    put user_password_path, params: params

    assert_response :unprocessable_content
    assert_select "a[href=?]", new_user_password_path
  end

  # FR-018, FR-020: and for six hours only.
  test "an expired link is refused with a way to get a new one" do
    token = @alice.send_reset_password_instructions

    travel 7.hours do
      put user_password_path, params: { user: { reset_password_token: token,
                                                password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD } }
    end

    assert_response :unprocessable_content
    assert_select "a[href=?]", new_user_password_path
    assert @alice.reload.valid_password?(VALID_PASSWORD)
  end

  # ---- the two things stock Devise does not do (research.md R4, R5) ---------

  # FR-019 (clarified): the reset link proves the mailbox, so it activates.
  test "completing a reset activates an account that was never activated" do
    pending = User.create!(email: "pending@example.com", password: VALID_PASSWORD)
    token = pending.send_reset_password_instructions

    put user_password_path, params: { user: { reset_password_token: token,
                                              password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD } }

    assert_predicate pending.reload, :confirmed?
    assert_nil pending.confirmed_by_id
    assert_redirected_to root_path
    get root_path
    assert_response :success
  end

  # FR-040 (clarified): and it ends a lockout rather than leaving the person
  # to wait out 15 minutes with a password they have just proved they own.
  test "completing a reset ends a lockout" do
    @alice.lock_access!
    token = @alice.send_reset_password_instructions

    put user_password_path, params: { user: { reset_password_token: token,
                                              password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD } }

    @alice.reload
    assert_not_predicate @alice, :access_locked?
    assert_equal 0, @alice.failed_attempts
    get root_path
    assert_response :success
  end

  # research.md R5: activating through a reset never promotes a pending new address.
  test "activating through a reset leaves the address as it was" do
    pending = User.create!(email: "pending@example.com", password: VALID_PASSWORD)
    pending.update_columns(unconfirmed_email: "elsewhere@example.com")
    token = pending.send_reset_password_instructions

    put user_password_path, params: { user: { reset_password_token: token,
                                              password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD } }

    assert_equal "pending@example.com", pending.reload.email
  end
end
