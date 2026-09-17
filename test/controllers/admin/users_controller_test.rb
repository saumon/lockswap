require "test_helper"

# 013: who is allowed through to the administrator screens, and who is turned
# away at the door.
#
# This is the half of FR-004 the browser cannot test. A system test can only
# confirm the menu entry is absent; whether the address behind it is actually
# refused when typed, bookmarked, or guessed is an HTTP question, and it is the
# one that matters — hiding the link is a convenience, this is the control.
class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # The site's standing rule for signed-in-only content: an anonymous visitor is
  # sent to sign in rather than told what is behind the door.
  test "an anonymous visitor is sent to the login page" do
    get admin_users_path

    assert_redirected_to new_user_session_path
  end

  # FR-008: the refusal is here, at the request, not in the template that decides
  # whether to draw a link.
  test "a signed-in non-administrator is refused and told why" do
    sign_in users(:carol)

    get admin_users_path

    assert_redirected_to root_path
    assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, flash[:alert]
  end

  # Following the redirect matters: the refusal has to land somewhere usable with
  # the reason on screen, not bounce or loop.
  test "a refused visitor lands on the homepage with the reason shown" do
    sign_in users(:carol)

    get admin_users_path
    follow_redirect!

    assert_response :success
    assert_match ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, response.body
  end

  test "the administrator is let through" do
    sign_in users(:frank)

    get admin_users_path

    assert_response :success
  end

  # --- What the screen reports (User Story 2) -------------------------------

  # FR-006: every account, with none quietly left off — the administrator's own
  # included. Counted against the table rather than a fixed number so adding a
  # fixture cannot silently shrink what this covers.
  test "every registered account is listed, the administrator's own included" do
    sign_in users(:frank)

    get admin_users_path

    assert_select ".data-table tbody tr", count: User.count
    assert_select "td", text: users(:frank).email
    assert_select "td", text: users(:carol).email
  end

  # FR-007/FR-010: identified by email, in registration order, oldest first. The
  # expectation is read from the database rather than written out, so the test
  # states the rule and not a snapshot of today's fixtures.
  test "accounts are listed by email in registration order, oldest first" do
    sign_in users(:frank)

    get admin_users_path

    listed = css_select(".data-table tbody td[data-label='Email']").map { |cell| cell.text.strip }

    assert_equal User.order(:created_at).pluck(:email), listed
    assert_equal users(:frank).email, listed.first, "the administrator registered first"
  end

  # FR-012: the administrator's row says so outright, rather than leaving it to
  # be inferred from being at the top of the list.
  test "the administrator's row is labelled and no other row is" do
    sign_in users(:frank)

    get admin_users_path

    assert_select "#admin-user-row-#{users(:frank).id}" do
      assert_select ".badge", text: "Admin"
    end

    assert_select "#admin-user-row-#{users(:carol).id}" do
      assert_select ".badge", text: "Admin", count: 0
    end

    assert_select ".badge", text: "Admin", count: 1
  end

  # FR-009: read-only. Nothing on this screen changes an account — no form to
  # submit, no button to press, no link that goes anywhere but back out.
  test "the screen offers nothing that would change an account" do
    sign_in users(:frank)

    get admin_users_path

    assert_select "#admin-user-directory form", count: 0
    assert_select "#admin-user-directory button", count: 0
    assert_select "#admin-user-directory input", count: 0
  end
end
