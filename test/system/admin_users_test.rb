require "application_system_test_case"

# 013 User Story 2: the administrator's view of who is registered.
#
# The controller test covers the contract — who is let in, what the response
# contains, in what order. What is asserted here is the part only a browser can
# answer: that the screen is reachable by following the menu, that the label on
# the administrator's row is actually on screen rather than merely in the markup,
# and that the page offers nothing to press.
class AdminUsersTest < ApplicationSystemTestCase
  setup do
    @administrator = users(:frank)
  end

  # FR-005: the way in is the menu, not a memorised address.
  test "the administrator reaches the users screen through the Admin menu" do
    log_in_as @administrator

    find("summary", text: "Admin").click
    click_on "Users"

    assert_current_path admin_users_path
    assert_selector "h1", text: "Registered users"
  end

  # FR-006/FR-007/FR-010: everyone who has registered, by email, oldest first.
  # The order is read off the screen and compared with the order the database
  # gives, so this asserts the rule rather than a fixed list.
  test "every registered account is on screen, oldest first" do
    log_in_as @administrator
    visit admin_users_path

    assert_selector ".data-table tbody tr", count: User.count

    on_screen = all(".data-table tbody td[data-label='Email']").map(&:text)

    assert_equal User.order(:created_at).pluck(:email), on_screen
  end

  # FR-012: visible, not just present. A label the reader cannot see is not a
  # label — which is why this asks for it as displayed text on the row.
  test "the administrator's own row is the one carrying the Admin label" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-row-#{@administrator.id}" do
      assert_text "Admin"
    end

    within "#admin-user-row-#{users(:carol).id}" do
      assert_no_text "Admin"
    end
  end

  # FR-009: the screen reports and does not act. Nothing here promotes, demotes,
  # edits or removes an account — there is no such capability in the product, and
  # a control that looked like one would be a promise it cannot keep.
  test "the screen offers no way to change an account" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-directory" do
      assert_no_button
      assert_no_field
      assert_no_link "Edit"
      assert_no_link "Delete"
    end
  end

  # FR-008: the same refusal the controller test asserts, seen the way a person
  # would meet it — sent back to the homepage with the reason on screen.
  test "a non-administrator who types the address is refused and told why" do
    log_in_as users(:carol)
    visit admin_users_path

    assert_current_path root_path
    assert_text ApplicationController::ADMINISTRATORS_ONLY_MESSAGE
  end

  # The audits of this screen live in accessibility_test.rb with every other
  # screen's, and its behaviour at the two widths in responsive_test.rb with
  # every other list's — this file is the feature's own behaviour.
end
