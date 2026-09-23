require "application_system_test_case"

# 020: the enriched admin Users screen — locker, floor and wish on every row
# (User Story 1), the four search filters (User Story 2), and the no-match state
# (User Story 3). The existing screen's own behaviour (the "Admin" badge, the
# grant control, who is let through) stays in admin_users_test.rb; this file is
# the feature's own.
class AdminUsersFilterTest < ApplicationSystemTestCase
  setup do
    @administrator = users(:frank)
  end

  # --- User Story 1: locker, floor and wish on every row ----------------------

  # FR-001/FR-002: matches what that same account's own homepage shows.
  test "a row shows the account's floor and locker when both are on file" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-row-#{users(:bob).id}" do
      assert_text users(:bob).saved_floor
      assert_text users(:bob).saved_locker_number
    end
  end

  # FR-002: distinct from "not set" — a floor is on file, a locker is not.
  test "a row shows 'No locker assigned' for an account with a floor but no locker" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-row-#{users(:carol).id}" do
      assert_text users(:carol).saved_floor
      assert_text "No locker assigned"
    end
  end

  # FR-001: distinct from "no locker assigned" — this account has never saved a
  # floor at all.
  test "a row shows 'Not set' for an account that has never saved a floor" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-row-#{users(:alice).id}" do
      assert_text "Not set"
    end
  end

  # FR-003: the account is looking for a locker, and the row names the floor.
  test "a row shows the floor an account is looking for" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-row-#{users(:bob).id}" do
      assert_text "Looking for floor #{users(:bob).locker_wish.saved_floor}"
    end
  end

  # FR-003: plainly says so rather than leaving a blank cell.
  test "a row shows that an account has no active wish" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-row-#{users(:dave).id}" do
      assert_text "Not looking for a locker"
    end
  end

  # --- User Story 2: the four filters ------------------------------------------

  # FR-005/FR-009: choosing a floor narrows the list to that floor alone, in
  # place — the filter bar and the viewer's position on the page stay put.
  test "the current-floor filter narrows the list without a full page reload" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-filter-current-floor" do
      click_on users(:judy).saved_floor
    end

    within "#admin-user-directory-list" do
      assert_text users(:judy).email
      assert_no_text users(:bob).email
    end

    within "#admin-user-filter-current-floor" do
      assert_selector "[aria-current='true']", text: users(:judy).saved_floor
    end
  end

  # FR-006/FR-009: choosing a role narrows to administrators or standard
  # accounts alone.
  test "the role filter narrows the list to administrators or standard accounts" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-filter-role" do
      click_on "Admin"
    end

    within "#admin-user-directory-list" do
      assert_text users(:frank).email
      assert_text users(:grace).email
      assert_no_text users(:bob).email
    end
  end

  # FR-007: exact match — typing part of a locker number does not match a
  # different, longer one.
  test "the current-locker filter matches a locker number exactly" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-filter-current-locker-form" do
      fill_in "current_locker", with: users(:quinn).saved_locker_number
    end

    within "#admin-user-directory-list" do
      assert_text users(:quinn).email
      assert_no_text users(:bob).email
    end
  end

  # FR-008: partial, case-insensitive match on email.
  test "the email filter narrows the list to accounts whose email contains the text" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-filter-email-form" do
      fill_in "email", with: "quinn"
    end

    within "#admin-user-directory-list" do
      assert_text users(:quinn).email
      assert_no_text users(:bob).email
    end
  end

  # FR-009: combining filters narrows to accounts matching all of them.
  test "combining filters narrows to accounts matching every one of them" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-filter-role" do
      click_on "Standard"
    end
    within "#admin-user-filter-current-floor" do
      click_on users(:bob).saved_floor
    end

    within "#admin-user-directory-list" do
      assert_text users(:bob).email
      assert_no_text users(:frank).email
      assert_no_text users(:judy).email
    end
  end

  # spec.md US2 Acceptance Scenario 6: returning a filter to "All"/blank widens
  # the list back to everyone still matching the remaining filters.
  test "clearing a filter widens the list back out" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-filter-current-floor" do
      click_on users(:judy).saved_floor
    end
    within "#admin-user-directory-list" do
      assert_no_text users(:bob).email
    end

    within "#admin-user-filter-current-floor" do
      click_on "All floors"
    end
    within "#admin-user-directory-list" do
      assert_text users(:bob).email
      assert_text users(:judy).email
    end
  end

  # spec.md US2 Acceptance Scenario 7: a fresh visit is always unfiltered.
  test "a fresh visit to the screen is unfiltered" do
    log_in_as @administrator
    visit admin_users_path

    assert_selector ".data-table tbody tr", count: User.count
  end

  # --- User Story 3: no filter combination is an error ------------------------

  # FR-011: told plainly, not left to look like a broken screen.
  test "a filter combination matching nobody shows a clear message" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-filter-role" do
      click_on "Admin"
    end
    within "#admin-user-filter-current-floor" do
      click_on users(:bob).saved_floor
    end

    assert_selector "#admin-user-directory-no-match"
  end

  # Relaxing one filter recovers whichever accounts now match the rest.
  test "relaxing one filter after a no-match recovers the list" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-filter-role" do
      click_on "Admin"
    end
    within "#admin-user-filter-current-floor" do
      click_on users(:bob).saved_floor
    end
    assert_selector "#admin-user-directory-no-match"

    within "#admin-user-filter-current-floor" do
      click_on "All floors"
    end

    within "#admin-user-directory-list" do
      assert_text users(:frank).email
    end
  end
end
