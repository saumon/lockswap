require "application_system_test_case"

# Covers 002 spec.md User Story 1 (FR-003, FR-004).
class LockerProfileTest < ApplicationSystemTestCase
  # 004's "declined" notice is shown once and acknowledged as it is handed to the
  # view, so it is on the homepage when a test arrives and gone from the re-render
  # after it submits — moving the form between a click being aimed and landing.
  # These tests are about the form, so the notice is spent before they start.
  setup do
    LockerSwapProposal.declined.update_all(requester_acknowledged_at: Time.current)
  end

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

  # Typing and submitting are separate round trips to the browser, and a page
  # replaced in between loses the input silently — the submit then carries the
  # old values and the failure surfaces somewhere far less obvious than here.
  # Confirming what landed first turns that race into a wait.
  def save_locker_details(fields)
    fields.each { |label, value| fill_in_reliably label, with: value }
    click_on "Save locker details"
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

    save_locker_details "Floor" => "5"

    assert_selector "#locker-profile-floor", text: "5"
    assert_selector "#locker-profile-locker-number", text: "No locker assigned"
    assert_nil users(:alice).reload.locker_number
  end

  # Acceptance Scenario 3: a whitespace-only floor counts as missing.
  #
  # Every test below that opens the editor uses dave rather than bob: bob is the
  # recipient of 004's alice_pending_to_bob fixture, which every test loads, so
  # 005's lock hides his edit control. dave's only proposal is already decided.
  test "submitting a blank floor is rejected and leaves the saved floor untouched" do
    log_in_as users(:dave)
    open_locker_editor

    save_locker_details "Floor" => "   "

    assert_text "Floor can't be blank"
    assert_equal "4", users(:dave).reload.floor
  end

  # Acceptance Scenario 4: rejected, and the other account stays anonymous.
  # 006 FR-003: the floor is bob's own, because that is what makes this the same
  # locker. On any other floor the identical number is a different one, and alice
  # is entitled to it.
  test "submitting a locker number another account holds on the same floor is rejected without naming them" do
    log_in_as users(:alice)

    save_locker_details "Floor" => users(:bob).floor, "Locker number" => users(:bob).locker_number

    assert_text "Locker number is not available on that floor"
    # Scoped to the rejection itself: what FR-011 forbids is the conflict naming
    # who holds the locker. Elsewhere on this page alice may legitimately see the
    # same person for reasons of her own — 004 lists the swap proposals she sent,
    # and one of them is to bob.
    within("#error_explanation") { assert_no_text users(:bob).email }
    assert_nil users(:alice).reload.locker_number
  end

  # FR-010: the details belong to the account, not to one browser session.
  test "saved locker details survive logging out and logging back in" do
    log_in_as users(:alice)

    save_locker_details "Floor" => "7", "Locker number" => "C09"
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
    log_in_as users(:dave)
    open_locker_editor

    save_locker_details "Floor" => "8"

    assert_selector "#locker-profile-floor", text: "8"
    assert_selector "#locker-profile-locker-number", text: "D07"
    assert_equal "D07", users(:dave).reload.locker_number
  end

  # Acceptance Scenario 2: the locker was reassigned away from them.
  test "clearing the locker number leaves the floor alone" do
    log_in_as users(:dave)
    open_locker_editor

    save_locker_details "Locker number" => ""

    assert_selector "#locker-profile-locker-number", text: "No locker assigned"
    assert_selector "#locker-profile-floor", text: "4"
    assert_nil users(:dave).reload.locker_number
  end

  test "the form stays out of the way until the user asks to edit" do
    log_in_as users(:dave)

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
    log_in_as users(:dave)
    open_locker_editor

    save_locker_details "Floor" => ""

    assert_text "Floor can't be blank"
    assert_selector "input[name='user[floor]']"
    assert_selector "#locker-profile-floor", text: "4"
    assert_selector "#locker-profile-locker-number", text: "D07"
  end

  # 005 User Story 1: the details are held still while a swap is being decided.

  # Acceptance Scenario 1 & 2: bob is the recipient of alice_pending_to_bob.
  # Constitution Principle III — the restriction is explained where the control
  # used to be, rather than the control silently disappearing.
  test "the edit control is replaced by an explanation while a proposal is active" do
    log_in_as users(:bob)

    assert_no_selector "summary", text: "Edit locker details"
    assert_selector "#locker-profile-locked", text: "active swap proposal"
    assert_selector "#locker-profile-floor", text: "3"
    assert_selector "#locker-profile-locker-number", text: "B12"
  end

  # Acceptance Scenario 5: resolving the proposal gives the control back.
  test "the edit control returns once the proposal is resolved" do
    locker_swap_proposals(:alice_pending_to_bob).decline!
    log_in_as users(:bob)

    assert_no_selector "#locker-profile-locked"
    open_locker_editor
    save_locker_details "Floor" => "8"

    assert_selector "#locker-profile-floor", text: "8"
    assert_equal "8", users(:bob).reload.floor
  end

  # Acceptance Scenario 6: alice has an active proposal too, but nothing on file
  # yet — so she is still asked for it, exactly as in 002.
  test "a user with nothing saved is still offered the form while a proposal is active" do
    log_in_as users(:alice)

    assert_no_selector "#locker-profile-locked"

    save_locker_details "Floor" => "5", "Locker number" => "C01"

    assert_selector "#locker-profile-floor", text: "5"
    assert_equal [ "5", "C01" ], [ users(:alice).reload.floor, users(:alice).locker_number ]
  end
end
