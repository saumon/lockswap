require "application_system_test_case"

# Covers 017 spec.md User Stories 1-4 in the browser: the two axes, combining and
# clearing them, the list updating in place, and an empty result reading as an
# ordinary outcome.
#
# dave is the viewer throughout unless a test needs otherwise: he holds no wish,
# so he is never in the list he is filtering and never his own subject.
class LockerWishFilterTest < ApplicationSystemTestCase
  LOOKING_FOR = "#locker-wish-filter-looking-for".freeze
  CURRENT_FLOOR = "#locker-wish-filter-current-floor".freeze

  # The people currently listed, in the order the list shows them — so a
  # comparison catches a row appearing, vanishing, or moving.
  def listed_people
    all("#locker-wish-list tbody td[data-label='Person']").map(&:text)
  end

  def choices_in(group)
    all("#{group} a").map(&:text)
  end

  # Both groups offer "All floors", so every choice is made within its own group.
  #
  # The frame is replaced asynchronously, so reading the list straight after the
  # click races it. Waiting for the choice to become the one in force is what
  # turns that race into a wait — and it is the same marker the viewer sees.
  def choose(group, floor)
    within(group) { click_on floor }
    assert_current_choice group, floor
  end

  def assert_current_choice(group, floor)
    assert_selector "#{group} a[aria-current='true']", text: floor, exact_text: true
  end

  def current_choice(group)
    find("#{group} a[aria-current='true']").text
  end

  # --- User Story 1: the floor people are looking for ------------------------

  # Scenario 1: the list is narrowed to exactly the rows for that floor.
  test "choosing a looked-for floor leaves only the wishes for it" do
    log_in_as users(:dave)
    visit locker_wishes_path

    # 018: henry and iris are two more active wishes, declared after karl's.
    assert_equal [ "bob@example.com", "carol@example.com", "judy@example.com", "karl@example.com",
                   "henry@example.com", "iris@example.com" ],
      listed_people

    choose LOOKING_FOR, "5"

    assert_equal [ "carol@example.com" ], listed_people
  end

  # Scenario 2: a row that survives the filter is the same row it always was.
  test "a filtered row carries the same details it carried unfiltered" do
    log_in_as users(:dave)
    visit locker_wishes_path
    choose LOOKING_FOR, "7"

    within "#locker-wish-row-#{users(:bob).id}" do
      assert_text "7"
      assert_text "bob@example.com"
      assert_text "3"
      assert_text "B12"
      assert_button "Propose swap"
    end
  end

  # Scenario 3: proposing from a filtered list is proposing, unchanged. This is
  # the one that fails if the "Propose swap" form is left inside the frame.
  test "a swap can be proposed from a filtered list exactly as from the full one" do
    log_in_as users(:dave)
    visit locker_wishes_path
    choose LOOKING_FOR, "5"

    within("#locker-wish-row-#{users(:carol).id}") { click_on "Propose swap" }

    assert_text "Swap proposal sent."
  end

  # Scenario 4: the viewer's own wish is listed like anyone else's.
  test "the viewer's own row is shown when it matches the filter" do
    log_in_as users(:karl)
    visit locker_wishes_path
    choose LOOKING_FOR, "3"

    within "#locker-wish-row-#{users(:karl).id}" do
      assert_text "This is you"
    end
  end

  # Scenario 5 (FR-007): 10 is offered last, not between 1 and 2.
  test "floors are offered in numeric order, not as text" do
    log_in_as users(:dave)
    visit locker_wishes_path

    assert_equal %w[All\ floors 3 5 7 10], choices_in(LOOKING_FOR)
    # 018: henry and iris are both saved on floor "7", so it now joins the choices.
    assert_equal %w[All\ floors 2 3 7 10], choices_in(CURRENT_FLOOR)
  end

  # Scenario 6 (FR-008): moving across the choices is not choosing. A select that
  # submitted on `change` would re-filter on every arrow key; links cannot.
  test "moving across the choices by keyboard does not filter the list" do
    log_in_as users(:dave)
    visit locker_wishes_path

    before = listed_people
    find("#{LOOKING_FOR} a", text: "All floors").send_keys(:tab, :tab, :tab)

    assert_equal before, listed_people
    assert_equal "All floors", current_choice(LOOKING_FOR)
  end

  # --- User Story 2: the floor people are on ---------------------------------

  # Scenario 1: with the first axis untouched throughout.
  test "choosing a current floor leaves only the people saved on it" do
    log_in_as users(:dave)
    visit locker_wishes_path
    choose CURRENT_FLOOR, "3"

    assert_equal [ "bob@example.com" ], listed_people
    assert_equal "All floors", current_choice(LOOKING_FOR)
  end

  # Scenario 2 (FR-012): never having saved a floor is not an error, and it is not
  # a floor either.
  test "someone who has saved no floor is left out of every current-floor filter" do
    log_in_as users(:dave)
    visit locker_wishes_path

    choices_in(CURRENT_FLOOR).drop(1).each do |floor|
      choose CURRENT_FLOOR, floor

      assert_no_selector "#locker-wish-row-#{users(:karl).id}"
      choose CURRENT_FLOOR, "All floors"
    end
  end

  # Scenario 3: and they come back, still reading "Not set".
  test "clearing the current-floor filter brings back people with no floor" do
    log_in_as users(:dave)
    visit locker_wishes_path
    choose CURRENT_FLOOR, "3"
    choose CURRENT_FLOOR, "All floors"

    within "#locker-wish-row-#{users(:karl).id}" do
      assert_text "Not set"
      assert_text "No locker assigned"
    end
  end

  # --- User Story 3: combining and clearing ----------------------------------

  # Scenarios 1 and 2: both set is the intersection; clearing one widens to the
  # other alone rather than to everything.
  test "both filters together show only the rows matching both" do
    log_in_as users(:dave)
    visit locker_wishes_path

    choose LOOKING_FOR, "7"
    choose CURRENT_FLOOR, "3"

    assert_equal [ "bob@example.com" ], listed_people

    # carol is looking for 5 — a row that matches one filter and not the other.
    choose LOOKING_FOR, "5"

    assert_empty listed_people

    choose CURRENT_FLOOR, "All floors"

    assert_equal [ "carol@example.com" ], listed_people
  end

  # Scenario 3 (FR-013): clearing everything restores the list exactly, order
  # included.
  test "clearing both filters restores the full list in its original order" do
    log_in_as users(:dave)
    visit locker_wishes_path
    before = listed_people

    choose LOOKING_FOR, "7"
    choose CURRENT_FLOOR, "3"
    choose LOOKING_FOR, "All floors"
    choose CURRENT_FLOOR, "All floors"

    assert_equal before, listed_people

    # The address is updated after the frame has swapped, so it is asserted with a
    # waiting matcher rather than read the moment the list looks right.
    assert_current_path locker_wishes_path, ignore_query: false
  end

  # Scenario 4: the screen opens unfiltered.
  test "the screen opens with neither filter applied" do
    log_in_as users(:dave)
    visit locker_wishes_path

    assert_equal "All floors", current_choice(LOOKING_FOR)
    assert_equal "All floors", current_choice(CURRENT_FLOOR)
  end

  # Scenario 5 (FR-009, SC-006): the whole point of the frame. The declare panel
  # stays put and the page does not jump back to the top.
  test "filtering replaces only the list, leaving the panel and the scroll position" do
    # SC-001's scale, and what makes this assertion mean anything: four rows do not
    # fill the window, so there would be nothing to scroll and nothing to lose.
    # They all want floor 42, so the list is still long after filtering — a list
    # that shrank to nothing would let the browser clamp the scroll and the test
    # would fail for a reason that is not the one under test.
    #
    # The viewer is put part-way down, but not so far that the filter bar leaves
    # the window: a link out of view is one the driver scrolls to before clicking,
    # and this would then be measuring the driver rather than the feature.
    60.times do |i|
      LockerWish.create!(
        user: User.create!(email: "crowd#{i}@example.com", password: VALID_PASSWORD, floor: "42"),
        floor: "42"
      )
    end

    log_in_as users(:dave)
    visit locker_wishes_path
    assert_selector "#locker-wish-panel"

    # behavior: "instant" because the site scrolls smoothly (008), which makes
    # scrollTo asynchronous — read straight afterwards, scrollY is still 0 and the
    # assertion below would be measuring nothing.
    page.execute_script "window.scrollTo({ top: 150, behavior: 'instant' })"
    scrolled_to = page.evaluate_script("window.scrollY")
    assert_equal 150, scrolled_to, "the page needs to be scrolled for this to mean anything"
    assert_operator page.evaluate_script(
      "document.querySelector('#{LOOKING_FOR}').getBoundingClientRect().bottom"
    ), :<, page.evaluate_script("window.innerHeight"), "the filter must be in view, or the driver scrolls to it"

    choose LOOKING_FOR, "42"

    assert_equal 60, listed_people.count
    assert_selector "#locker-wish-panel"
    assert_equal scrolled_to, page.evaluate_script("window.scrollY")
  end

  # Scenario 6 (FR-006): the choices never shift under the viewer.
  test "setting one filter leaves the other offering the same floors in the same order" do
    log_in_as users(:dave)
    visit locker_wishes_path
    before = choices_in(CURRENT_FLOOR)

    choose LOOKING_FOR, "10"

    assert_equal before, choices_in(CURRENT_FLOOR)
  end

  # FR-018: each filter change is its own history entry, so Back means what it
  # means everywhere else.
  test "the browser's back button returns to the previous filter state" do
    log_in_as users(:dave)
    visit locker_wishes_path
    choose LOOKING_FOR, "5"
    choose LOOKING_FOR, "7"

    assert_equal [ "bob@example.com" ], listed_people

    # The address moves first and the list follows, so both are asserted: FR-018
    # is about what the address carries *and* about arriving back at that view.
    # Without frame_history_controller this fails about two runs in five — the
    # address goes back and the list does not.
    page.go_back
    assert_current_path(/looking_for=5/, url: true)
    assert_current_choice LOOKING_FOR, "5"

    assert_equal [ "carol@example.com" ], listed_people
  end

  # --- User Story 4: nothing matches -----------------------------------------

  # Scenario 1 (FR-016): its own message, in its own words, with both selections
  # still in force so either can be relaxed (FR-015).
  test "a combination matching nobody says so in its own words" do
    log_in_as users(:dave)
    visit locker_wishes_path

    choose LOOKING_FOR, "7"
    choose CURRENT_FLOOR, "10"

    assert_selector "#locker-wish-list-no-match"
    assert_no_selector "#locker-wish-list-empty"
    assert_no_text "Nobody is looking for a locker right now."
    assert_equal "7", current_choice(LOOKING_FOR)
    assert_equal "10", current_choice(CURRENT_FLOOR)
  end

  # Scenario 2: nobody looking at all is the other message, and neither filter has
  # a floor to offer.
  test "no wishes at all shows the original empty state and offers no floors" do
    LockerWish.destroy_all

    log_in_as users(:dave)
    visit locker_wishes_path

    assert_selector "#locker-wish-list-empty"
    assert_no_selector "#locker-wish-list-no-match"
    assert_equal [ "All floors" ], choices_in(LOOKING_FOR)
    assert_equal [ "All floors" ], choices_in(CURRENT_FLOOR)
  end

  # FR-015, and the spec's edge case: the last wish for a floor is cancelled while
  # someone is filtered on it. The floor stops being offered to anyone choosing
  # afresh, but stays visible to the viewer who is on it.
  test "a floor whose last wish is gone stays visible as the selection in force" do
    log_in_as users(:dave)
    visit locker_wishes_path
    choose LOOKING_FOR, "5"

    users(:carol).locker_wish.destroy
    visit locker_wishes_path(looking_for: "5")

    assert_selector "#locker-wish-list-no-match"
    assert_equal "5", current_choice(LOOKING_FOR)
    assert_equal %w[All\ floors 3 7 10 5], choices_in(LOOKING_FOR)
  end

  # --- FR-019: the filters survive the viewer's own writes -------------------

  test "saving a wish comes back to the list still filtered" do
    log_in_as users(:karl)
    visit locker_wishes_path
    choose LOOKING_FOR, "3"

    assert_selector "#locker-wish-row-#{users(:karl).id}"

    find("summary", text: "Change floor").click
    fill_in_reliably "Floor", with: "6"
    click_on "Save my wish"

    assert_text "Locker search saved."
    assert_equal "3", current_choice(LOOKING_FOR)
    assert_no_selector "#locker-wish-row-#{users(:karl).id}"
  end

  test "cancelling a wish comes back to the list still filtered" do
    log_in_as users(:karl)
    visit locker_wishes_path
    choose LOOKING_FOR, "7"

    click_on "Cancel wish"

    assert_text "Locker search cancelled."
    assert_equal "7", current_choice(LOOKING_FOR)
    assert_equal [ "bob@example.com" ], listed_people
  end
end
