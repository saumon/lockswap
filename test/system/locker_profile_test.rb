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

  # 009 FR-007/FR-009: the edit control carries no text of its own any more, so
  # it is found by the name it exposes instead of by what it says.
  EDIT_LOCKER_CONTROL = "summary[aria-label='Edit locker details']".freeze

  # Someone who already has details saved reaches the form through the edit
  # control; someone who has nothing saved is shown it outright. Waiting on the
  # field keeps the caller from typing into a disclosure that has not opened yet.
  def open_locker_editor
    # 008: wait out any Turbo preview before clicking. Opening the disclosure on a
    # cached snapshot acts on a DOM about to be replaced, and the fresh page
    # arrives with it shut again. This guards that race; it is not a cure for the
    # separate, pre-existing keystroke-drop flakiness this file also suffers on a
    # loaded machine (see fill_in_reliably).
    wait_for_turbo

    find(EDIT_LOCKER_CONTROL).click
    # Opening the disclosure reflows the page. Waiting for the submit button —
    # the last thing to settle — keeps a later click from being aimed at where
    # the button used to be and silently going nowhere.
    assert_selector "[name='user[floor]']"
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

  # 022: on mobile, each field's label and value read as one compact line
  # ("Floor 3", "Locker number B12") instead of the label stacking above the
  # value. `.detail-grid > div:has(...)` reaches each field's own <dt> from
  # its <dd> id — scoped to a direct child of .detail-grid, since neither
  # <dt> carries an id of its own and the outer .stack-tight wrapper also
  # "has" both ids as descendants.
  test "on mobile, each field's label and value share one line" do
    log_in_as users(:bob)

    with_viewport(:phone) do
      assert_same_line ".detail-grid > div:has(#locker-profile-floor) dt", "#locker-profile-floor"
      assert_same_line ".detail-grid > div:has(#locker-profile-locker-number) dt", "#locker-profile-locker-number"
    end
  end

  # Same compaction applies to the "No locker assigned" placeholder — it is an
  # ordinary value for this purpose, not a special case.
  test "on mobile, the label and the no-locker placeholder share one line" do
    log_in_as users(:carol)

    with_viewport(:phone) do
      assert_same_line ".detail-grid > div:has(#locker-profile-floor) dt", "#locker-profile-floor"
      assert_same_line ".detail-grid > div:has(#locker-profile-locker-number) dt", "#locker-profile-locker-number"
    end
  end

  # FR-003: the existing desktop layout — label above value, the two fields
  # side by side — must be exactly what it was before the mobile change above.
  test "at desktop width, floor and locker number keep their existing side-by-side layout" do
    log_in_as users(:bob)

    assert_stacked ".detail-grid > div:has(#locker-profile-floor) dt", "#locker-profile-floor", "desktop"
    assert_stacked ".detail-grid > div:has(#locker-profile-locker-number) dt", "#locker-profile-locker-number", "desktop"

    floor_rect = element_rect("#locker-profile-floor")
    locker_number_rect = element_rect("#locker-profile-locker-number")
    assert_operator floor_rect["left"], :<, locker_number_rect["left"],
      "expected Floor and Locker number to remain side by side at desktop width"
  end

  # 022 FR-004/FR-005: on the homepage, "Your locker" is plain content, not a
  # boxed card — but it still says whose locker this is and what is on file.
  test "on the homepage, Your locker has no card container but keeps its content" do
    log_in_as users(:bob)

    assert_no_selector ".card#locker-profile"
    assert_no_selector "#locker-profile.card"
    within "#locker-profile" do
      assert_selector "h2", text: "Your locker"
      assert_selector "#locker-profile-floor", text: "3"
      assert_selector "#locker-profile-locker-number", text: "B12"
    end
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

    assert_no_selector EDIT_LOCKER_CONTROL
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

  # 009 User Story 1: the first answer is a choice between two things, rather
  # than one form with a field most people have nothing to put in.
  #
  # alice throughout: she is the account with nothing on file, which is the only
  # state where this choice is offered at all.

  # Acceptance Scenario 2 / SC-001: someone who says they have no locker is
  # never asked for a locker number.
  test "a first-time user can say they have no locker and save just a floor" do
    log_in_as users(:alice)
    wait_for_turbo

    click_on "I don't have a locker 😔"

    assert_no_selector "input[name='user[locker_number]']"

    save_locker_details "Floor" => "5"

    assert_selector "#locker-profile-floor", text: "5"
    assert_selector "#locker-profile-locker-number", text: "No locker assigned"
    assert_nil users(:alice).reload.locker_number
  end

  # The floor is still required on this path: 009 removes the locker number from
  # the question, not the floor (002 FR-007, carried by 009 FR-003).
  test "saying you have no locker does not excuse the floor" do
    log_in_as users(:alice)
    wait_for_turbo

    click_on "I don't have a locker 😔"
    click_on "Save locker details"

    assert_text "Floor can't be blank"
    assert_nil users(:alice).reload.floor
  end

  # Acceptance Scenario 3 / FR-005: the choice can be taken back, and the floor
  # typed before taking it survives the switch in either direction.
  test "switching back to entering a locker keeps the floor already typed" do
    log_in_as users(:alice)
    wait_for_turbo

    fill_in_reliably "Floor", with: "5"
    fill_in_reliably "Locker number", with: "C09"

    click_on "I don't have a locker 😔"
    click_on "Actually, I have a locker"

    assert_field "Floor", with: "5"
    assert_field "Locker number", with: ""
  end

  # FR-004: the field is cleared and not merely hidden. A number typed and then
  # disowned that still reached the database would contradict the answer given,
  # and would show up on the homepage a moment later as a locker she said she
  # did not have.
  test "a locker number typed before saying you have none is not saved" do
    log_in_as users(:alice)
    wait_for_turbo

    fill_in_reliably "Locker number", with: "C09"
    click_on "I don't have a locker 😔"

    save_locker_details "Floor" => "5"

    assert_selector "#locker-profile-locker-number", text: "No locker assigned"
    assert_nil users(:alice).reload.locker_number
  end

  # 009 User Story 2: the labelled row that used to open the form is now a
  # pencil in the corner of the card it edits.

  # Acceptance Scenario 1 / SC-002: nothing on the page spells the label out any
  # more. SC-003: and what replaced it opens the form in a single click.
  test "the edit control is an icon with no visible label" do
    log_in_as users(:dave)
    wait_for_turbo

    assert_no_selector "summary", text: "Edit locker details"
    assert_selector EDIT_LOCKER_CONTROL

    find(EDIT_LOCKER_CONTROL).click

    assert_selector "input[name='user[floor]']"
    assert_selector "input[name='user[locker_number]']"
  end

  # FR-010: the pencil opens the plain two-field form. carol has a floor and no
  # locker, which is the case where re-asking the first-entry question would be
  # most tempting — and where asking it would put an answer she has already
  # given back up for debate.
  test "the pencil opens the plain form, not the first-entry choice" do
    log_in_as users(:carol)
    open_locker_editor

    assert_field "Locker number", with: ""
    assert_no_button "I don't have a locker 😔"
  end
  # --- 030 User Story 2: the floor is a choice from the site's list -----------

  # The select's options as the browser lists them, prompt included.
  def floor_options
    all("select[name='user[floor]'] option").map(&:text)
  end

  # FR-006: until a list is saved, the floor is still typed.
  test "with no floor list saved, the floor is still a text field" do
    log_in_as users(:alice)

    assert_selector "input[type=text][name='user[floor]']"
    assert_no_selector "select[name='user[floor]']"
  end

  # FR-004, acceptance scenario 1: exactly the listed floors, in the typed order.
  test "the first-entry form offers exactly the listed floors, in order, and saves one" do
    SiteFloorList.current.update!(floors_text: "RDC, 1, 2, 3")
    log_in_as users(:alice)

    assert_equal [ "Choose a floor", "RDC", "1", "2", "3" ], floor_options

    select "2", from: "Floor"
    click_on "Save locker details"

    assert_selector "#locker-profile-floor", text: "2"
    assert_equal "2", users(:alice).reload.floor
  end

  # The prompt is not a floor: leaving it chosen is the existing "required" error.
  test "leaving the prompt chosen is refused as a missing floor" do
    SiteFloorList.current.update!(floors_text: "0, 1")
    log_in_as users(:alice)

    click_on "Save locker details"

    assert_text "Floor can't be blank"
    assert_nil users(:alice).reload.floor
  end

  # The pencil editor offers the same list, with the saved floor selected.
  test "the pencil editor offers the listed floors with the saved one selected" do
    SiteFloorList.current.update!(floors_text: "1, 2, 3")
    log_in_as users(:carol)
    open_locker_editor

    assert_equal [ "Choose a floor", "1", "2", "3" ], floor_options
    assert_select "Floor", selected: "2"
  end

  # FR-007/FR-011: a floor since removed is shown selected, marked, and the form
  # still saves with it left alone.
  test "a saved floor no longer listed is shown as such and can be kept" do
    SiteFloorList.current.update!(floors_text: "0, 1")
    users(:carol).update_columns(floor: "5")
    log_in_as users(:carol)
    open_locker_editor

    assert_select "Floor", selected: "5 (no longer offered)"

    fill_in_reliably "Locker number", with: "C44"
    click_on "Save locker details"

    assert_selector "#locker-profile-locker-number", text: "C44"
    assert_equal "5", users(:carol).reload.floor
  end

  # FR-020: the super admin's save reaches another account's very next page,
  # with nothing to sign out of or refresh.
  test "a list the super admin saves is what the next user is offered" do
    log_in_as users(:frank)
    visit admin_danger_zone_path
    fill_in_reliably "Floors", with: "7, 8"
    click_on "Save floors"
    assert_text "Floors saved."
    click_on "Log out"
    assert_text "Signed out successfully."

    log_in_as users(:alice)

    assert_equal [ "Choose a floor", "7", "8" ], floor_options
  end
  # --- 030 User Story 4: locker numbers follow the site's format --------------

  # FR-016 and acceptance scenarios 1, 2 and 4: the hint says what is expected in
  # the super admin's words, the refusal repeats it, a conforming number saves,
  # and "no locker" is still an answer.
  test "the locker number follows the format, described in the super admin's words" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}", description: "3 chiffres, ex. 042")
    log_in_as users(:carol)
    open_locker_editor

    within("#locker_number_hint") { assert_text "Required format: 3 chiffres, ex. 042" }

    save_locker_details "Locker number" => "42"
    within("#error_explanation") { assert_text "must match the required format: 3 chiffres, ex. 042" }
    assert_nil users(:carol).reload.locker_number

    fill_in_reliably "Locker number", with: "042"
    click_on "Save locker details"
    assert_selector "#locker-profile-locker-number", text: "042"
    assert_equal "042", users(:carol).reload.locker_number
  end

  # Clarification Q1: with no description, the pattern itself is what is shown.
  test "with no description, the hint and the refusal show the pattern" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}")
    log_in_as users(:carol)
    open_locker_editor

    within("#locker_number_hint") { assert_text "Required format: \\d{3}" }

    save_locker_details "Locker number" => "42"
    within("#error_explanation") { assert_text "must match the required format: \\d{3}" }
  end

  # FR-015: the first-entry "I don't have a locker" choice still saves.
  test "saying you have no locker still saves under a format" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}")
    log_in_as users(:alice)

    fill_in_reliably "Floor", with: "5"
    click_on "I don't have a locker 😔"
    click_on "Save locker details"

    assert_selector "#locker-profile-locker-number", text: "No locker assigned"
    assert_nil users(:alice).reload.locker_number
  end

  # With no format set, the hint is exactly what it was.
  test "with no format set, the locker number hint says nothing about a format" do
    log_in_as users(:carol)
    open_locker_editor

    within("#locker_number_hint") { assert_no_text "Required format" }
  end

  # --- 031 User Story 2: only a known locker can be saved --------------------

  # FR-009: unchanged from before this feature — still a plain text box.
  test "the locker number field stays free text, whether or not the map is in use" do
    Zone.create!(floor: "2", name: "Aile Nord").locker_map_entries.create!(locker_number: "203")
    log_in_as users(:carol)
    open_locker_editor

    assert_selector "input[type='text']#user_locker_number"
  end

  test "saving an undeclared locker number is refused" do
    Zone.create!(floor: "2", name: "Aile Nord").locker_map_entries.create!(locker_number: "203")
    log_in_as users(:carol)
    open_locker_editor

    save_locker_details "Floor" => "2", "Locker number" => "999"

    within("#error_explanation") { assert_text I18n.t("errors.messages.locker_number_unknown") }
    assert_nil users(:carol).reload.locker_number
  end

  test "saving a declared locker number succeeds" do
    Zone.create!(floor: "2", name: "Aile Nord").locker_map_entries.create!(locker_number: "203")
    log_in_as users(:carol)
    open_locker_editor

    save_locker_details "Floor" => "2", "Locker number" => "203"

    assert_selector "#locker-profile-locker-number", text: "203"
  end

  # US2 acceptance scenario 4: the pair, not either half alone, is checked.
  test "changing only the floor to one where the same locker number is not declared is refused" do
    Zone.create!(floor: "2", name: "Aile Nord").locker_map_entries.create!(locker_number: "203")
    users(:carol).update_columns(floor: "2", locker_number: "203")
    log_in_as users(:carol)
    open_locker_editor

    save_locker_details "Floor" => "3"

    within("#error_explanation") { assert_text I18n.t("errors.messages.locker_number_unknown") }
  end
end
