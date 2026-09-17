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
  # FR-001: the first person to sign up on an untouched instance is the
  # administrator, with no setup step. destroy_all for the empty site the
  # requirement is written about — the fixtures are a site that already exists.
  test "the first signup on an empty site becomes the administrator" do
    User.destroy_all

    post user_registration_path, params: {
      user: { email: "founder@example.com", password: VALID_PASSWORD }
    }

    assert_redirected_to root_path
    assert_predicate User.find_by(email: "founder@example.com"), :admin?
  end

  # FR-003: and is shown the menu that goes with it.
  test "the first signup lands on a homepage carrying the Admin menu" do
    User.destroy_all

    post user_registration_path, params: {
      user: { email: "founder@example.com", password: VALID_PASSWORD }
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
      user: { email: "newcomer@example.com", password: VALID_PASSWORD }
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
      user: { email: "ambitious@example.com", password: VALID_PASSWORD, admin: true }
    }

    assert_not_predicate User.find_by(email: "ambitious@example.com"), :admin?
    assert_equal users(:frank), User.find_by(admin: true)
  end
end
