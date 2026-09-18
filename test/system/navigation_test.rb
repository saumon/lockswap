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

  # --- 013: the administrator's entry ---------------------------------------

  # FR-003/FR-005: the administrator gets one more thing in the navigation than
  # anyone else — an "Admin" menu, with "Users" inside it. Asserted at both
  # treatments, because the menu is rendered into two containers (012) and an
  # entry that only reached one of them would be missing on half the site.
  test "the administrator's navigation carries an Admin menu holding Users" do
    log_in_as users(:frank)

    with_viewport(:desktop) do
      within ".site-bar" do
        assert_selector "summary", text: "Admin"
        # Inside a closed disclosure the link is present but not yet displayed,
        # which is the whole point of a submenu — so this asks for it either way
        # and then opens the menu to see it properly.
        assert_link "Users", visible: :all
        find("summary", text: "Admin").click
        assert_link "Users", visible: true
      end
    end

    with_viewport(:phone) do
      find(".site-menu-toggle").click

      within ".site-menu-panel" do
        find("summary", text: "Admin").click
        assert_link "Users", visible: true
      end
    end
  end

  # 015 FR-007: the same entry, at both widths, for an administrator who was
  # granted the rights rather than claiming them at signup. The navigation reads
  # current_user.admin? and nothing finer — this is the assertion that says so,
  # and would fail if any of it had been keyed on being the first account.
  test "a granted administrator's navigation carries the same Admin menu" do
    log_in_as users(:grace)

    # Deliberately the same shape as the test above, scoped to one container at a
    # time: 012 renders this menu twice, so an unscoped find takes whichever copy
    # comes first in the DOM — which at this width is the collapsed one, clipped
    # to a 0x0 rectangle that Capybara still counts as visible. The click then
    # lands on the header behind it and the disclosure never opens.
    with_viewport(:desktop) do
      within ".site-bar" do
        assert_selector "summary", text: "Admin"
        assert_link "Users", visible: :all
        find("summary", text: "Admin").click
        assert_link "Users", visible: true
      end
    end

    with_viewport(:phone) do
      find(".site-menu-toggle").click

      within ".site-menu-panel" do
        find("summary", text: "Admin").click
        assert_link "Users", visible: true
      end
    end
  end

  # FR-004: and everybody else gets exactly what they got before. Not hidden,
  # not disabled — absent, at either width, with the menu opened so a narrow
  # panel is actually looked inside rather than assumed empty.
  test "a non-administrator's navigation has no Admin entry at either width" do
    log_in_as users(:carol)

    with_viewport(:desktop) do
      assert_no_selector "header summary", text: "Admin", visible: :all
      assert_no_link "Users", visible: :all
    end

    with_viewport(:phone) do
      find(".site-menu-toggle").click
      assert_no_selector ".site-menu-panel summary", text: "Admin", visible: :all
      assert_no_link "Users", visible: :all
    end
  end

  # FR-005: the entry is a way somewhere, not a label. Following it has to arrive.
  test "the Admin menu leads the administrator to the users screen" do
    log_in_as users(:frank)

    find("summary", text: "Admin").click
    click_on "Users"

    assert_current_path admin_users_path
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
