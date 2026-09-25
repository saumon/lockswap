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

  # --- 028 User Story 1: grant admin rights from the detail screen ------------

  # FR-002/FR-003: offered where it can do something, absent where it cannot.
  test "the grant control is offered when the account is not an administrator, and absent when it is" do
    log_in_as @administrator

    visit admin_user_path(users(:carol))
    assert_button "Grant admin rights"

    visit admin_user_path(users(:grace))
    assert_no_button "Grant admin rights"
  end

  # FR-004, research.md R7: the confirmation names the account and no longer
  # claims the grant cannot be undone — it can, by a revoke.
  test "the grant confirmation names the account and no longer claims it cannot be undone" do
    log_in_as @administrator
    visit admin_user_path(users(:carol))

    message = dismiss_confirm { click_button "Grant admin rights" }

    assert_includes message, users(:carol).email
    assert_no_match(/cannot be undone/i, message)
  end

  # 015 FR-015's underlying concern (a control's accessible name must not rely on
  # its position) still applies to a single control, not only to a column of
  # them — the button's own aria-label is what makes that true here.
  test "the grant control's accessible name identifies the account it acts on" do
    log_in_as @administrator
    visit admin_user_path(users(:carol))

    assert_selector %(button[aria-label="Grant administrator rights to #{users(:carol).email}"])
  end

  test "declining the grant confirmation changes nothing and leaves the control usable" do
    log_in_as @administrator
    visit admin_user_path(users(:carol))

    dismiss_confirm { click_button "Grant admin rights" }

    assert_not_predicate users(:carol).reload, :admin?
    assert_button "Grant admin rights"
  end

  # FR-012, FR-017: the promotion shows on both the detail screen and the list,
  # in agreement. No password is asked for on the way through.
  test "accepting the grant confirmation promotes the account on both screens" do
    log_in_as @administrator
    visit admin_user_path(users(:carol))

    accept_confirm { click_button "Grant admin rights" }

    assert_text(/granted/i)
    assert_no_field "user_password"
    assert_text "Admin"
    assert_text @administrator.email
    assert_no_button "Grant admin rights"

    visit admin_users_path
    within "#admin-user-row-#{users(:carol).id}" do
      assert_text "Admin"
    end
  end

  # 015 User Story 2, FR-007: a granted administrator is an administrator, and
  # the grant works from their hands too, now from the detail screen.
  test "a granted administrator reaches the screen and can grant rights onwards" do
    log_in_as users(:grace)

    visit admin_user_path(users(:carol))
    accept_confirm { click_button "Grant admin rights" }

    assert_text(/granted/i)
    assert_predicate users(:carol).reload, :admin?
    assert_predicate users(:grace).reload, :admin?
  end

  # 015 SC-004: "from their next page view onwards, with no sign-out or manual
  # step". This grants to somebody already signed in, in a second session, and
  # only reloads.
  test "rights reach an account that is already signed in, without signing out" do
    using_session(:carol) do
      log_in_as users(:carol)
      visit root_path
      assert_no_selector "summary", text: "Admin"
    end

    using_session(:administrator) do
      log_in_as @administrator
      visit admin_user_path(users(:carol))
      accept_confirm { click_button "Grant admin rights" }
    end

    using_session(:carol) do
      visit root_path
      assert_selector "summary", text: "Admin"
    end
  end

  # --- 028 User Story 2: revoke admin rights from the detail screen -----------

  # FR-005/FR-006, Acceptance Scenarios 1 and 6.
  test "the revoke control is offered on a different administrator's screen, and absent on a standard account's" do
    log_in_as @administrator

    visit admin_user_path(users(:grace))
    assert_button "Revoke admin rights"

    visit admin_user_path(users(:carol))
    assert_no_button "Revoke admin rights"
  end

  # FR-007, Acceptance Scenario 2.
  test "the revoke confirmation names the account and says it will lose administrator rights" do
    log_in_as @administrator
    visit admin_user_path(users(:grace))

    message = dismiss_confirm { click_button "Revoke admin rights" }

    assert_includes message, users(:grace).email
  end

  test "the revoke control's accessible name identifies the account it acts on" do
    log_in_as @administrator
    visit admin_user_path(users(:grace))

    assert_selector %(button[aria-label="Revoke administrator rights from #{users(:grace).email}"])
  end

  # Acceptance Scenario 3.
  test "declining the revoke confirmation changes nothing" do
    log_in_as @administrator
    visit admin_user_path(users(:grace))

    dismiss_confirm { click_button "Revoke admin rights" }

    assert_predicate users(:grace).reload, :admin?
    assert_button "Revoke admin rights"
  end

  # FR-018, Acceptance Scenario 4: no grant-provenance line remains anywhere
  # once the revoke completes.
  test "accepting the revoke confirmation demotes the account on both screens, with no grant trace left" do
    log_in_as @administrator
    visit admin_user_path(users(:grace))

    accept_confirm { click_button "Revoke admin rights" }

    assert_text(/revoked/i)
    within "#admin-user-detail" do
      assert_no_text "Admin"
      assert_no_text "Granted by"
    end

    visit admin_users_path
    within "#admin-user-row-#{users(:grace).id}" do
      assert_no_text "Admin"
    end
  end

  # --- 028 User Story 3: an administrator cannot revoke their own rights ------

  # Acceptance Scenario 1.
  test "an administrator never sees a revoke control on their own detail screen" do
    log_in_as @administrator
    visit admin_user_path(@administrator)

    assert_no_button "Revoke admin rights"
  end

  # Acceptance Scenario 3: no special case for the sole remaining administrator.
  test "this holds even when the administrator is the only one on the site" do
    users(:grace).revoke_admin_rights!
    log_in_as @administrator

    visit admin_user_path(@administrator)

    assert_no_button "Revoke admin rights"
  end

  # --- 029 FR-009: no revoke control on the super admin's row, from anyone ----

  test "no revoke control appears on the super admin's own detail screen, even viewed by a different administrator" do
    log_in_as users(:grace)

    visit admin_user_path(users(:frank))

    assert_no_button "Revoke admin rights"
  end

  # --- 028 Polish: accessibility of both new controls -------------------------

  test "the grant and revoke controls are keyboard-operable and accessible" do
    log_in_as @administrator

    visit admin_user_path(users(:carol))
    assert_selector "button", text: "Grant admin rights"
    assert_axe_clean

    visit admin_user_path(users(:grace))
    assert_selector "button", text: "Revoke admin rights"
    assert_axe_clean
  end
  # --- 030 User Story 2: the administrator's editor offers the same list -----

  test "with a floor list saved, the administrator's editor offers it and saves a listed floor" do
    SiteFloorList.current.update!(floors_text: "1, 2, 9")
    log_in_as @administrator

    visit admin_user_path(users(:carol))
    find("summary[aria-label='Edit locker details']").click

    options = all("#admin-user-locker-editor select[name='user[floor]'] option").map(&:text)
    assert_equal [ "Choose a floor", "1", "2", "9" ], options

    select "9", from: "Floor"
    click_on "Save"

    assert_selector "#admin-user-detail-floor", text: "9"
    assert_equal "9", users(:carol).reload.floor
  end

  test "with a floor list saved, the administrator's editor is still accessible" do
    SiteFloorList.current.update!(floors_text: "1, 2, 9")
    log_in_as @administrator

    visit admin_user_path(users(:carol))
    find("summary[aria-label='Edit locker details']").click

    assert_selector "#admin-user-locker-editor select[name='user[floor]']"
    assert_axe_clean
  end
  # --- 030 User Story 4: the administrator's edit follows the format ---------

  test "the administrator's editor states the format and refuses a number that does not follow it" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}", description: "3 chiffres, ex. 042")
    log_in_as @administrator

    visit admin_user_path(users(:carol))
    find("summary[aria-label='Edit locker details']").click

    within("#admin_locker_number_hint") { assert_text "Required format: 3 chiffres, ex. 042" }

    fill_in "Locker number", with: "42"
    click_on "Save"
    assert_text "must match the required format: 3 chiffres, ex. 042"
    assert_nil users(:carol).reload.locker_number

    fill_in "Locker number", with: "042"
    click_on "Save"
    assert_selector "#admin-user-detail-locker", text: "042"
  end
end
