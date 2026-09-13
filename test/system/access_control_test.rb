require "application_system_test_case"

# Covers the redirect rules in contracts/web-routes.md (FR-008, FR-010).
class AccessControlTest < ApplicationSystemTestCase
  setup { @user = users(:alice) }

  # FR-008: the homepage is never rendered to a visitor who is not logged in.
  test "an unauthenticated visitor is sent from the homepage to the login page" do
    visit root_path

    assert_current_path new_user_session_path
    assert_no_text "Welcome to LockSwap"
    assert_text "You need to sign in or sign up before continuing."
  end

  # FR-010: a logged-in visitor has no business on the signup or login pages.
  test "a logged-in visitor is sent from the login page to the homepage" do
    log_in_as @user

    visit new_user_session_path

    assert_current_path root_path
    assert_text "Welcome to LockSwap"
  end

  # 003 FR-013 / Edge Case: the wish list is not public — an anonymous visitor
  # sees the login page instead of who is looking for a locker. The two write
  # verbs a browser cannot issue on its own are covered in
  # test/controllers/locker_wishes_controller_test.rb.
  test "an unauthenticated visitor is sent from the wish list to the login page" do
    visit locker_wishes_path

    assert_current_path new_user_session_path
    assert_no_text "Everyone looking for a locker"
    assert_text "You need to sign in or sign up before continuing."
  end

  # 004 FR-016: the proposal history is not public either. The five write verbs
  # this feature adds — POST /locker_swap_proposals, DELETE one, and the accept,
  # decline and confirm PATCHes — a browser cannot issue on its own, so they are
  # covered in test/controllers/locker_swap_proposals_controller_test.rb.
  test "an unauthenticated visitor is sent from the proposal history to the login page" do
    visit locker_swap_proposals_path

    assert_current_path new_user_session_path
    assert_no_text "Your swap proposals"
    assert_text "You need to sign in or sign up before continuing."
  end

  test "a logged-in visitor is sent from the signup page to the homepage" do
    log_in_as @user

    visit new_user_registration_path

    assert_current_path root_path
    assert_text "Welcome to LockSwap"
  end
end
