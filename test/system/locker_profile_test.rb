require "application_system_test_case"

# Covers 002 spec.md User Story 1 (FR-003, FR-004).
class LockerProfileTest < ApplicationSystemTestCase
  # Someone who already has details saved reaches the form through the edit
  # control; someone who has nothing saved is shown it outright. Waiting on the
  # field keeps the caller from typing into a disclosure that has not opened yet.
  def open_locker_editor
    find("summary", text: "Edit locker details").click
    # Opening the disclosure reflows the page. Waiting for the submit button —
    # the last thing to settle — keeps a later click from being aimed at where
    # the button used to be and silently going nowhere.
    assert_selector "input[name='user[floor]']"
    assert_selector "input[type=submit][value='Save locker details']"
  end

  # Acceptance Scenario 1: a user with both values sees both.
  test "a user with a floor and a locker number sees both on the homepage" do
    log_in_as users(:bob)

    assert_selector "#locker-profile-floor", text: "3"
    assert_selector "#locker-profile-locker-number", text: "B12"
  end

  # Acceptance Scenario 2: no locker assigned is a normal state, not a failure.
  test "a user with a floor but no locker number is told no locker is assigned" do
    log_in_as users(:carol)

    assert_selector "#locker-profile-floor", text: "2"
    assert_selector "#locker-profile-locker-number", text: "No locker assigned"
    assert_no_selector "[role=alert]"
  end

  # User Story 2 (FR-005..FR-008, FR-010, FR-011).

  # Acceptance Scenario 1: two fields, never one combined input.
  test "a user with nothing saved is offered separate floor and locker number fields" do
    log_in_as users(:alice)

    assert_no_selector "#locker-profile"
    assert_selector "input[name='user[floor]']"
    assert_selector "input[name='user[locker_number]']"
  end

  # Acceptance Scenario 2 / FR-008: the locker number never blocks saving a floor.
  test "submitting a floor with no locker number saves the floor and reports no locker" do
    log_in_as users(:alice)

    fill_in "Floor", with: "5"
    click_on "Save locker details"

    assert_selector "#locker-profile-floor", text: "5"
    assert_selector "#locker-profile-locker-number", text: "No locker assigned"
    assert_nil users(:alice).reload.locker_number
  end

  # Acceptance Scenario 3: a whitespace-only floor counts as missing.
  test "submitting a blank floor is rejected and leaves the saved floor untouched" do
    log_in_as users(:bob)
    open_locker_editor

    fill_in "Floor", with: "   "
    click_on "Save locker details"

    assert_text "Floor can't be blank"
    assert_equal "3", users(:bob).reload.floor
  end

  # Acceptance Scenario 4: rejected, and the other account stays anonymous.
  test "submitting a locker number another account holds is rejected without naming them" do
    log_in_as users(:alice)

    fill_in "Floor", with: "4"
    fill_in "Locker number", with: users(:bob).locker_number
    click_on "Save locker details"

    assert_text "Locker number is not available"
    assert_no_text users(:bob).email
    assert_nil users(:alice).reload.locker_number
  end

  # FR-010: the details belong to the account, not to one browser session.
  test "saved locker details survive logging out and logging back in" do
    log_in_as users(:alice)

    fill_in "Floor", with: "7"
    fill_in "Locker number", with: "C09"
    click_on "Save locker details"
    assert_selector "#locker-profile-floor", text: "7"

    click_on "Log out"
    assert_text "Signed out successfully."
    log_in_as users(:alice)

    assert_selector "#locker-profile-floor", text: "7"
    assert_selector "#locker-profile-locker-number", text: "C09"
  end

  # User Story 3 (FR-009): the form above is pre-filled, so it doubles as the edit
  # path. These prove each value can move without disturbing the other.

  # Acceptance Scenario 1.
  test "changing only the floor leaves the locker number alone" do
    log_in_as users(:bob)
    open_locker_editor

    fill_in "Floor", with: "8"
    click_on "Save locker details"

    assert_selector "#locker-profile-floor", text: "8"
    assert_selector "#locker-profile-locker-number", text: "B12"
    assert_equal "B12", users(:bob).reload.locker_number
  end

  # Acceptance Scenario 2: the locker was reassigned away from them.
  test "clearing the locker number leaves the floor alone" do
    log_in_as users(:bob)
    open_locker_editor

    fill_in "Locker number", with: ""
    click_on "Save locker details"

    assert_selector "#locker-profile-locker-number", text: "No locker assigned"
    assert_selector "#locker-profile-floor", text: "3"
    assert_nil users(:bob).reload.locker_number
  end

  test "the form stays out of the way until the user asks to edit" do
    log_in_as users(:bob)

    assert_no_selector "input[name='user[floor]']"
    assert_no_selector "input[name='user[locker_number]']"

    open_locker_editor

    assert_selector "input[name='user[floor]']"
    assert_selector "input[name='user[locker_number]']"
  end

  # Without this the rejected edit would report an error with no form to fix it in.
  # The saved values must still be reported as they are on file, not as the
  # rejected input sitting in the form.
  test "a rejected edit reopens the form with the error and the saved values intact" do
    log_in_as users(:bob)
    open_locker_editor

    fill_in "Floor", with: ""
    click_on "Save locker details"

    assert_text "Floor can't be blank"
    assert_selector "input[name='user[floor]']"
    assert_selector "#locker-profile-floor", text: "3"
    assert_selector "#locker-profile-locker-number", text: "B12"
  end
end
