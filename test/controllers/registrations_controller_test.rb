require "test_helper"

# 013 User Story 1, Acceptance Scenarios 1 and 2, through the path a person
# actually takes: Devise's signup form, not User.create! in a test.
#
# The model test proves the callback assigns the flag; this proves the callback
# is reached by the real registration, and that the resulting page is the one the
# administrator gets rather than the one everybody else gets. Those are different
# claims, and only the second of them would survive someone permitting :admin as
# a signup parameter or filtering the menu on something other than the flag.
class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  # 015: the cancellation tests at the foot of this file act as a signed-in
  # account, which the signup tests above never needed to do.
  include Devise::Test::IntegrationHelpers

  # FR-001: the first person to sign up on an untouched instance is the
  # administrator, with no setup step. destroy_all for the empty site the
  # requirement is written about — the fixtures are a site that already exists.
  test "the first signup on an empty site becomes the administrator" do
    User.destroy_all

    post user_registration_path, params: {
      user: { email: "founder@example.com", password: VALID_PASSWORD,
              password_confirmation: VALID_PASSWORD }
    }

    assert_redirected_to root_path
    assert_predicate User.find_by(email: "founder@example.com"), :admin?
  end

  # FR-003: and is shown the menu that goes with it.
  test "the first signup lands on a homepage carrying the Admin menu" do
    User.destroy_all

    post user_registration_path, params: {
      user: { email: "founder@example.com", password: VALID_PASSWORD,
              password_confirmation: VALID_PASSWORD }
    }
    follow_redirect!

    assert_response :success
    assert_select "summary.site-submenu-toggle", text: "Admin"
    assert_select "a[href=?]", admin_users_path
  end

  # FR-002/FR-004: everybody after that gets an ordinary account and the
  # navigation they have always had.
  test "a later signup is an ordinary account with no Admin menu" do
    post user_registration_path, params: {
      user: { email: "newcomer@example.com", password: VALID_PASSWORD,
              password_confirmation: VALID_PASSWORD }
    }
    follow_redirect!

    assert_response :success
    assert_not_predicate User.find_by(email: "newcomer@example.com"), :admin?
    assert_select "summary.site-submenu-toggle", count: 0
    assert_select "a[href=?]", admin_users_path, count: 0
  end

  # FR-002: the flag is not an attribute a signup gets to set. Asking for it
  # politely in the form parameters has to make no difference on a site that
  # already has an administrator.
  test "a signup cannot award itself the flag by asking for it" do
    post user_registration_path, params: {
      user: { email: "ambitious@example.com", password: VALID_PASSWORD,
              password_confirmation: VALID_PASSWORD, admin: true }
    }

    assert_not_predicate User.find_by(email: "ambitious@example.com"), :admin?
    # 015 FR-013: more than one administrator is possible now, so the question is
    # whether the set changed, not who the single answer is.
    assert_equal [ users(:frank), users(:grace) ].sort_by(&:id),
                 User.where(admin: true).order(:id).to_a
  end

  # 014 FR-002, FR-009: the two password fields have to agree, and that is
  # settled at the server. The form's live hint is an enhancement on top of this
  # check, never the check itself (research.md R1) — so a request that never went
  # near a browser is refused here just the same.
  test "a signup whose confirmation does not match the password is refused" do
    assert_no_difference -> { User.count } do
      post user_registration_path, params: {
        user: { email: "mistyped@example.com", password: VALID_PASSWORD,
                password_confirmation: "#{VALID_PASSWORD}x" }
      }
    end

    assert_response :unprocessable_entity
    assert_select "#error_explanation li", text: /doesn't match the password above/
  end

  # --- 015 FR-016: cancelling the last administrator's account ----------------
  #
  # The model refuses it; this is where that refusal has to become something the
  # person can read and act on. Devise's own destroy reports success regardless of
  # what the record did, which is the specific thing being corrected here.

  test "the last administrator cannot cancel their account while others remain" do
    users(:grace).destroy
    sign_in users(:frank)

    assert_no_difference -> { User.count } do
      delete user_registration_path
    end

    assert_equal User::LAST_ADMINISTRATOR_MESSAGE, flash[:alert]
    assert_nil flash[:notice]
  end

  # And they are still signed in afterwards: a refused cancellation must not log
  # somebody out of an account they still have.
  test "a refused cancellation leaves the administrator signed in" do
    users(:grace).destroy
    sign_in users(:frank)

    delete user_registration_path
    get root_path

    assert_response :success
  end

  test "an administrator can cancel while another administrator remains" do
    sign_in users(:frank)

    assert_difference -> { User.count }, -1 do
      delete user_registration_path
    end

    assert_nil flash[:alert]
  end

  test "a non-administrator can always cancel" do
    sign_in users(:carol)

    assert_difference -> { User.count }, -1 do
      delete user_registration_path
    end

    assert_nil flash[:alert]
  end
end
