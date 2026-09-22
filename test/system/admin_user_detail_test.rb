require "application_system_test_case"

# 027: the admin-only detail screen for one registered account, reached from a
# link on its row in Admin → Users.
class AdminUserDetailTest < ApplicationSystemTestCase
  setup do
    @administrator = users(:frank)
  end

  # --- User Story 1: reach the screen, and only as an admin -------------------

  # FR-001: a link within the row, not the row as a whole (Clarifications).
  test "the administrator opens an account's detail screen from its row link" do
    log_in_as @administrator
    visit admin_users_path

    click_on users(:bob).email

    assert_current_path admin_user_path(users(:bob))
    assert_text users(:bob).email
  end

  test "a non-administrator cannot open a user's detail screen directly" do
    log_in_as users(:carol)

    visit admin_user_path(users(:bob))

    assert_current_path root_path
    assert_text ApplicationController::ADMINISTRATORS_ONLY_MESSAGE
  end

  test "a signed-out visitor requesting a user's detail screen is sent to sign in" do
    visit admin_user_path(users(:bob))

    assert_current_path new_user_session_path
  end

  # --- User Story 2: full profile, search status, proposal history ------------

  test "the detail screen shows the same floor and locker the Users list and homepage show" do
    log_in_as @administrator

    visit admin_user_path(users(:bob))

    assert_selector "#admin-user-detail-floor", text: users(:bob).saved_floor
    assert_selector "#admin-user-detail-locker", text: users(:bob).saved_locker_number
  end

  test "an account with neither a wish nor an active proposal shows no search in progress" do
    log_in_as @administrator

    visit admin_user_path(users(:quinn))

    assert_selector "#admin-user-search-status"
    assert_no_selector ".data-table"
  end

  test "an account with no proposal history shows the empty state, not an empty table" do
    log_in_as @administrator

    visit admin_user_path(users(:quinn))

    assert_selector "#admin-user-detail-history-empty"
  end

  test "the detail screen lists a declined proposal with its comment" do
    log_in_as @administrator

    visit admin_user_path(users(:dave))

    within "#admin-user-detail-history-row-#{locker_swap_proposals(:dave_declined_to_carol).id}" do
      assert_text "Found another swap"
    end
  end

  # --- User Story 3: edit floor/locker on a user's behalf ---------------------

  test "the pencil icon reveals a form pre-filled with the account's current values" do
    log_in_as @administrator

    visit admin_user_path(users(:carol))
    find("summary[aria-label='Edit locker details']").click

    assert_field "Floor", with: users(:carol).floor
    assert_field "Locker number", with: ""
  end

  test "a valid edit updates the screen and shows who made it" do
    log_in_as @administrator

    visit admin_user_path(users(:carol))
    find("summary[aria-label='Edit locker details']").click
    fill_in "Floor", with: "9"
    fill_in "Locker number", with: "Z99"
    click_on "Save"

    assert_selector "#admin-user-detail-floor", text: "9"
    assert_selector "#admin-user-detail-locker", text: "Z99"
    assert_text @administrator.email
  end

  test "the pencil icon and its form are keyboard-operable and accessible" do
    log_in_as @administrator

    visit admin_user_path(users(:carol))

    assert_selector "summary[aria-label='Edit locker details']"
    assert_axe_clean
  end

  # --- User Story 4: cancel a user's search on their behalf -------------------

  test "the cancel-search button is shown only when the account has a standing wish" do
    log_in_as @administrator

    visit admin_user_path(users(:bob))
    assert_selector "[aria-label=\"Cancel #{users(:bob).email}'s locker search\"]"

    visit admin_user_path(users(:dave))
    assert_no_selector "[aria-label=\"Cancel #{users(:dave).email}'s locker search\"]"
  end

  test "dismissing the confirmation leaves the wish untouched" do
    log_in_as @administrator

    visit admin_user_path(users(:bob))
    dismiss_confirm do
      click_button "Cancel search"
    end

    assert_not_nil users(:bob).reload.locker_wish
  end

  test "confirming cancels the wish and shows who did it" do
    log_in_as @administrator

    visit admin_user_path(users(:bob))
    accept_confirm do
      click_button "Cancel search"
    end

    # Waiting assertion first, so the request has actually completed and the
    # redirect rendered before the database is checked (accept_confirm returns
    # as soon as the dialog is dismissed, not once the request finishes). bob
    # is also the recipient on the pending alice_pending_to_bob fixture, so the
    # search-status area still shows that active proposal — only the wish's own
    # "Looking for floor" line is gone.
    assert_text @administrator.email
    assert_no_text "Looking for floor"
    assert_nil users(:bob).reload.locker_wish
  end

  test "the cancel-search button is keyboard-operable and accessible" do
    log_in_as @administrator

    visit admin_user_path(users(:bob))

    assert_axe_clean
  end
end
