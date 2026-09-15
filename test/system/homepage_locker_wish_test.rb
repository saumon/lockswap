require "application_system_test_case"

# 010: the locker wish block on the homepage.
#
# The feature is presentation only — there is no new model, endpoint or rule to
# unit-test — so these system tests are its evidence. What they hold is the shape
# of the block: which of the three states each kind of user gets, that exactly one
# control is ever offered, and that the control goes where it says it does.
class HomepageLockerWishTest < ApplicationSystemTestCase
  BLOCK = "#home-locker-wish".freeze
  WISH_FLOOR = "#home-locker-wish-floor".freeze

  # Follows the block's control, whichever state rendered it.
  #
  # The sign-in notification is a sticky overlay in the top-right of <main>, and
  # it dismisses itself after a few seconds. Where it lands relative to this card
  # depends on how many proposal sections happen to be above it, so a click sent
  # while it is still up can be taken by the toast instead of the link — which
  # reads as a link that does not navigate. Letting it go first is what the rest
  # of the suite does (see accessibility_test.rb).
  def follow_block_link(label)
    assert_no_selector "[role=status]"
    within(BLOCK) { click_on label }
    wait_for_turbo
  end

  # FR-001a: a user who has not saved any locker details is being asked one
  # question, and this block is not it. alice has neither floor nor locker — the
  # "not yet asked" fixture — so the homepage must carry no block at all.
  test "the block is withheld until locker details are saved" do
    log_in_as users(:alice)

    assert_no_selector BLOCK
    assert_text "Add your locker details"
  end

  # --- The declared wish (User Story 1) -------------------------------------

  # FR-002, FR-003: bob is looking on floor 7. That floor, and the way back to
  # the page he declared it on, are the whole content of the state.
  test "a declared wish is shown with the way back to the wish page" do
    log_in_as users(:bob)

    assert_selector WISH_FLOOR, text: "7"

    within BLOCK do
      assert_link "Review locker wishes! 🥷"
      assert_no_text "I want"
    end
  end

  # FR-002: the locker card sits directly below this block and already says what
  # bob has. Repeating it here would be a second copy of the same two values,
  # free to drift from the first.
  test "the block does not repeat the locker the card below already shows" do
    log_in_as users(:bob)

    within BLOCK do
      assert_no_text "B12"
      # The floor sought is the one value the block carries, so there is exactly
      # one of these. A second would mean bob's own floor had crept in beside it.
      assert_selector ".detail-value", count: 1
    end
  end

  # Edge case: a wish outranks both invitations. carol has no locker at all, and
  # still sees her wish rather than being asked to want one.
  test "a declared wish outranks the invitation for a user with no locker" do
    log_in_as users(:carol)

    assert_selector WISH_FLOOR, text: "5"

    within BLOCK do
      assert_link "Review locker wishes! 🥷"
      assert_no_text "I want a locker!"
    end
  end

  # FR-006: one action, from the homepage to the page that can act on the wish.
  test "the review button leads to the wish page" do
    log_in_as users(:bob)

    follow_block_link "Review locker wishes! 🥷"

    assert_current_path locker_wishes_path
  end

  # FR-007, SC-004: the block reports the wish as it now stands, not as it stood
  # when the page was last cached.
  #
  # carol, not bob, deliberately. 003 removed its own browser coverage of typing
  # a floor while holding a locker: ChromeDriver dropped the keystrokes and the
  # submit click under load, on a page that was provably correct at the moment of
  # failure (see the note in locker_wish_test.rb). carol has no locker, which is
  # the combination that holds still — and the block cannot tell the difference,
  # since the wish state is reached the same way either way.
  test "changing the floor on the wish page changes what the homepage shows" do
    log_in_as users(:carol)
    visit locker_wishes_path
    find("summary", text: "Change floor").click
    fill_in_reliably "Floor", with: "9"
    click_on "Save my wish"
    assert_selector "#locker-wish-floor", text: "9"

    visit root_path
    wait_for_turbo

    assert_selector WISH_FLOOR, text: "9"
  end

  # FR-007, SC-004, US1 acceptance scenario 4: cancelling has to reach here too.
  # Only the absence is asserted at this point — which invitation replaces the
  # wish is User Story 2's subject, and is asserted there.
  test "cancelling the wish clears the wish state from the homepage" do
    log_in_as users(:bob)
    visit locker_wishes_path
    click_on "Cancel wish"
    assert_no_button "Cancel wish"

    visit root_path
    wait_for_turbo

    assert_no_selector WISH_FLOOR
    assert_no_link "Review locker wishes! 🥷"

    # bob keeps locker B12, so cancelling puts him back among the people who
    # could still be talked into a swap (SC-004).
    within(BLOCK) { assert_link "I want to switch my locker! 👀" }
  end

  # --- The switch invitation (User Story 2) ---------------------------------

  # FR-004: dave holds D07 and has declared nothing. The block has no wish to
  # report, so it asks for one instead.
  test "a locker holder with no wish is invited to switch" do
    log_in_as users(:dave)

    assert_no_selector WISH_FLOOR

    within BLOCK do
      assert_link "I want to switch my locker! 👀"
      assert_no_text "Looking for a locker on floor"
    end
  end

  # FR-006: the invitation goes to the page that can act on it.
  test "the switch invitation leads to the wish page" do
    log_in_as users(:dave)

    follow_block_link "I want to switch my locker! 👀"

    assert_current_path locker_wishes_path
  end

  # FR-013: an accepted proposal freezes the locker card below — those values are
  # what the other side agreed to. It freezes nothing here: a wish is a statement
  # about what someone wants, not an edit to what they hold.
  #
  # Built in the test rather than in the fixtures, because no fixture proposal is
  # accepted on purpose — an accepted one hides both parties' wishes from the wish
  # list and would quietly break 003's expectations.
  test "an active swap proposal does not change the block" do
    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob), status: :accepted)
    log_in_as users(:dave)

    # The card below really is frozen, so this is the state FR-013 is about and
    # not an ordinary page that happens to pass.
    assert_selector "#locker-profile-locked"

    within BLOCK do
      assert_selector "h2", text: "Looking for a different locker?"
      assert_no_selector WISH_FLOOR
      # The control is offered, and it still points where it always did. What
      # FR-013 asserts is what the block renders; that following such a link
      # arrives on the wish page is covered twice above, in the states where it
      # can be clicked.
      #
      # It cannot be clicked here: with an exchange in progress the homepage
      # grows past the viewport, and in that state ChromeDriver drops a native
      # click entirely — no click event reaches the document at all, while the
      # same link dispatched from JavaScript navigates. It is not this block:
      # the header's own "Locker wishes" link, untouched by this feature, is
      # dropped the same way on the same page. Asserting the href keeps this
      # test about the requirement instead of about the driver.
      assert_equal locker_wishes_path,
        URI.parse(find_link("I want to switch my locker! 👀")[:href]).path
    end
  end

  # --- The ask invitation (User Story 3) ------------------------------------

  # FR-005, FR-011: erin has answered the locker question and has no locker. She
  # has nothing to swap, which is no reason to leave her out — a wish is how
  # someone with nothing says what they are waiting for.
  test "a user with no locker and no wish is invited to ask for one" do
    log_in_as users(:erin)

    assert_no_selector WISH_FLOOR

    within BLOCK do
      assert_link "I want a locker! 🙏"
      assert_no_text "switch my locker"
    end
  end

  # FR-005, FR-006: the clarification that made this a button rather than a line
  # of text. A plain-text third state would leave the person with the least to
  # lose by swapping with no way out of the homepage.
  test "the ask invitation leads to the wish page" do
    log_in_as users(:erin)

    follow_block_link "I want a locker! 🙏"

    assert_current_path locker_wishes_path
  end

  # --- What holds across all three states -----------------------------------

  # SC-002: the three states are one if/elsif/else, and this is what says so from
  # the outside. One way in, whoever is looking — never two, never none.
  #
  # FR-009: and never a way to act here. Declaring, changing and cancelling stay
  # on the wish page; a form appearing in this block would mean the two screens
  # had started to compete for the same job.
  test "every state offers exactly one control and no form" do
    [ users(:bob), users(:dave), users(:erin) ].each do |user|
      log_in_as user

      within BLOCK do
        assert_selector "a", count: 1
        assert_no_selector "form"
      end

      click_on "Log out"
      assert_text "Log in"
    end
  end

  # FR-012: the order is the point. Proposals waiting on an answer come first —
  # they cannot move without this user — and the locker card is reference, so the
  # wish goes in front of it. bob has a proposal waiting on him, so his homepage
  # is the one where all three are on screen at once.
  test "the block sits after the proposal sections and above the locker card" do
    log_in_as users(:bob)

    assert_selector "#swap-proposals-received ~ #home-locker-wish"
    assert_selector "#home-locker-wish + #locker-profile"
  end
end
