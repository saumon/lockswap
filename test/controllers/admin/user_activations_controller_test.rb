require "test_helper"

# 034 User Story 7: an administrator activating an account by hand, from its
# detail screen (FR-035 to FR-038).
class Admin::UserActivationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @pending = User.create!(email: "pending@example.com", password: VALID_PASSWORD)
    clear_enqueued_jobs
  end

  # FR-035, FR-036, FR-038: activated, attributed, and no email sent.
  test "an administrator activates an account and is recorded as having done it" do
    sign_in users(:grace)

    assert_no_enqueued_emails do
      post admin_user_activation_path(@pending)
    end

    @pending.reload
    assert_predicate @pending, :confirmed?
    assert_equal users(:grace), @pending.confirmed_by
    assert_redirected_to admin_user_path(@pending)
    assert_equal I18n.t("admin.user_activations.create.activated", email: @pending.email), flash[:notice]
  end

  # Edge case: arriving second is not an error, and does not rewrite who did it.
  test "activating an account that is already active changes nothing" do
    @pending.activate!(by: users(:frank))
    sign_in users(:grace)

    post admin_user_activation_path(@pending)

    assert_equal users(:frank), @pending.reload.confirmed_by
    assert_equal I18n.t("admin.user_activations.create.already_active", email: @pending.email), flash[:notice]
  end

  # FR-037: administrators only — the site's usual refusal, not a new message.
  test "a standard user is refused" do
    sign_in users(:carol)

    post admin_user_activation_path(@pending)

    assert_redirected_to root_path
    assert_equal I18n.t("application.administrators_only"), flash[:alert]
    assert_not_predicate @pending.reload, :confirmed?
  end

  test "an anonymous visitor is sent to sign in" do
    post admin_user_activation_path(@pending)

    assert_redirected_to new_user_session_path
    assert_not_predicate @pending.reload, :confirmed?
  end

  test "an account that no longer exists is said so" do
    sign_in users(:frank)
    id = @pending.id
    @pending.destroy

    post admin_user_activation_path(id)

    assert_redirected_to admin_users_path
    assert_equal I18n.t("admin.user_activations.create.account_gone"), flash[:alert]
  end

  # FR-038, research.md R6: the email that was sent no longer activates
  # anything — following it says the account is already active.
  test "the activation link sent earlier reads as already active afterwards" do
    token = @pending.confirmation_token
    sign_in users(:frank)
    post admin_user_activation_path(@pending)
    delete destroy_user_session_path

    get user_confirmation_path(confirmation_token: token)

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("devise.confirmations.new.outcome.already_active")
  end
end
