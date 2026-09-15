require "application_system_test_case"

# The site-wide navigation in app/views/layouts/application.html.erb.
class NavigationTest < ApplicationSystemTestCase
  # 008: the signed-out screens carry no header. They already lead with the full
  # stacked lock-up, so a bar would show the brand twice, and it would hold
  # nothing else — every control in it is behind user_signed_in?.
  test "the sign-in and sign-up screens have no header bar" do
    visit new_user_session_path
    assert_no_selector "header"
    assert_no_selector "nav[aria-label=Main]"
    assert_selector "[data-brand-mark]", visible: :all

    visit new_user_registration_path
    assert_no_selector "header"
    assert_selector "[data-brand-mark]", visible: :all
  end

  test "a signed-in visitor gets the header back" do
    log_in_as users(:carol)

    assert_selector "header nav[aria-label=Main]"
    assert_link "Locker wishes"
    assert_link "Proposal history"
  end

  # 012 FR-009: at and above the breakpoint the destinations are in the bar, with
  # nothing to open first. The suite's default screen size is already wide, but
  # asserting the viewport explicitly keeps this true if that default ever moves.
  test "the wide treatment puts the destinations in the bar with no toggle" do
    log_in_as users(:carol)

    with_viewport(:desktop) do
      assert_no_selector ".site-menu-toggle", visible: true
      assert_selector ".site-bar", visible: true

      within ".site-bar" do
        assert_link "Locker wishes"
        assert_link "Proposal history"
        assert_button "Log out"
      end
    end
  end

  # 012: each treatment has its own container, so exactly one copy of each
  # control may ever be on screen — FR-011 and the "no control appears twice"
  # edge case. This is the assertion that would catch a display rule going
  # missing and both containers showing at once.
  test "exactly one copy of each destination is visible at any width" do
    log_in_as users(:carol)

    with_viewport(:desktop) do
      assert_selector "header a", text: "Locker wishes", count: 1, visible: true
    end

    with_viewport(:phone) do
      find(".site-menu-toggle").click
      assert_selector "header a", text: "Locker wishes", count: 1, visible: true
    end
  end

  test "the wordmark takes a logged-in visitor back to the homepage" do
    log_in_as users(:carol)
    visit locker_wishes_path
    assert_no_text "Welcome to LockSwap"

    click_on "LockSwap"

    assert_current_path root_path
    assert_text "Welcome to LockSwap"
  end
end
