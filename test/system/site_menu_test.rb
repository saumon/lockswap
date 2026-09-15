require "application_system_test_case"

# 012 User Story 1: the signed-in menu, at both treatments.
#
# Below the breakpoint the menu is a <details> disclosure behind a toggle; at
# and above it, the bar it has always been. It is rendered once and neutralised
# into a row by CSS (research R1), so these tests are as much about the single
# rendering as about the behaviour: a control that appeared twice, or a desktop
# bar that stayed collapsed, would show up here.
class SiteMenuTest < ApplicationSystemTestCase
  setup do
    @user = users(:carol)
  end

  # --- Wide treatment (FR-009) ----------------------------------------------

  # The R1 gate. If ::details-content is not honoured, the panel stays collapsed
  # at desktop width and this fails — which is exactly the signal the plan wants
  # before anything else is built on the single-render approach.
  test "at desktop width the bar carries everything and there is no toggle" do
    log_in_as @user

    with_viewport(:desktop) do
      assert_no_selector ".site-menu-toggle", visible: true

      within "header" do
        assert_link "Locker wishes", visible: true
        assert_link "Proposal history", visible: true
        assert_text @user.email
        assert_button "Log out", visible: true
      end
    end
  end

  # --- Narrow treatment, no script required (FR-010, FR-010b) ---------------

  test "at phone width the menu collapses behind a toggle that opens a panel" do
    log_in_as @user

    with_viewport(:phone) do
      assert_selector ".site-menu-toggle", visible: true
      assert_no_selector ".site-menu-panel a", text: "Locker wishes", visible: true

      find(".site-menu-toggle").click

      assert_link "Locker wishes", visible: true
      assert_link "Proposal history", visible: true
      assert_text @user.email
      assert_button "Log out", visible: true
    end
  end

  test "a second activation of the toggle closes the panel again" do
    log_in_as @user

    with_viewport(:phone) do
      find(".site-menu-toggle").click
      assert_link "Locker wishes", visible: true

      find(".site-menu-toggle").click
      assert_no_selector ".site-menu-panel a", text: "Locker wishes", visible: true
    end
  end

  # <details> announces its own state. This asserts the native attribute rather
  # than a hand-written aria-expanded precisely because hand-writing one is
  # forbidden by the contract: it would override what the element already says.
  test "the toggle announces expanded and collapsed without any scripting" do
    log_in_as @user

    with_viewport(:phone) do
      assert_not page.evaluate_script("document.querySelector('.site-menu').open")

      find(".site-menu-toggle").click
      assert page.evaluate_script("document.querySelector('.site-menu').open")
    end
  end

  test "the toggle is reachable and operable from the keyboard" do
    log_in_as @user

    with_viewport(:phone) do
      find(".site-menu-toggle").send_keys(:enter)

      assert_link "Locker wishes", visible: true
    end
  end

  # --- The brand stays put (FR-012) -----------------------------------------

  test "the brand lockup stays visible and linked at both widths" do
    log_in_as @user

    with_viewport(:phone) do
      assert_selector "header a.brand-lockup", visible: true
    end

    with_viewport(:desktop) do
      assert_selector "header a.brand-lockup", visible: true
    end
  end

  # --- Dismissal, where script is available (FR-010b-i) ---------------------

  test "Escape closes the panel and puts focus back on the toggle" do
    log_in_as @user

    with_viewport(:phone) do
      find(".site-menu-toggle").click
      assert_link "Locker wishes", visible: true

      page.driver.browser.action.send_keys(:escape).perform

      assert_no_selector ".site-menu-panel a", text: "Locker wishes", visible: true
      assert_equal "SUMMARY", page.evaluate_script("document.activeElement.tagName"),
        "focus must return to the toggle, not fall through to the body"
    end
  end

  test "activating something outside the panel closes it" do
    log_in_as @user

    with_viewport(:phone) do
      find(".site-menu-toggle").click
      assert_link "Locker wishes", visible: true

      # Clicking below the panel rather than at a named element: the panel spans
      # the width of the bar and hangs over the top of the content, so most of
      # what is nominally "outside" it is underneath it, and the click would be
      # intercepted by the panel itself.
      panel_bottom = page.evaluate_script(
        "document.querySelector('.site-menu-panel').getBoundingClientRect().bottom"
      )
      page.driver.browser.action.move_to_location(100, panel_bottom.to_i + 80).click.perform

      assert_no_selector ".site-menu-panel a", text: "Locker wishes", visible: true
    end
  end

  # FR-010c: the panel must not be left hanging over whatever the click loaded.
  test "following a destination leaves the panel closed on the next page" do
    log_in_as @user

    with_viewport(:phone) do
      find(".site-menu-toggle").click
      click_on "Locker wishes"
      wait_for_turbo

      assert_current_path locker_wishes_path
      assert_no_selector ".site-menu-panel a", text: "Proposal history", visible: true
    end
  end

  # --- The no-script baseline (FR-010b, SC-006a) ----------------------------

  # The whole point of building the menu on <details>. With scripting off the
  # only things lost are Escape and outside-click; nothing becomes unreachable.
  test "the menu still opens and closes with scripting disabled" do
    log_in_as @user

    with_viewport(:phone) do
      # Turning scripting off through CDP rather than rebuilding the driver, so
      # this costs one test rather than a second browser session. Restored in
      # ensure — the browser is shared across this single-worker suite.
      page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: true)
      visit root_path

      find(".site-menu-toggle").click
      assert_link "Locker wishes", visible: true
      assert_link "Proposal history", visible: true
      assert_text @user.email
      assert_button "Log out", visible: true

      find(".site-menu-toggle").click
      assert_no_selector ".site-menu-panel a", text: "Locker wishes", visible: true
    ensure
      page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: false)
    end
  end

  # --- Touch targets (FR-007, FR-025) ---------------------------------------

  test "every standalone control in the open menu is a real touch target" do
    log_in_as @user

    with_viewport(:phone) do
      find(".site-menu-toggle").click

      assert_touch_targets_at_least 44
    end
  end

  # --- The identity is what gives way (FR-013) ------------------------------

  # 008 decided that on a narrow screen the email truncates and the brand and
  # the controls do not. 012 has to keep that true in the panel as well as in
  # the bar, because the panel is where the email now lives on a phone.
  test "a long email truncates rather than pushing anything off screen" do
    long = users(:dave)
    long.update!(email: "a-really-quite-long-address-for-testing@example.com")
    log_in_as long

    with_viewport(:phone) do
      find(".site-menu-toggle").click

      assert_no_horizontal_overflow "the open menu panel"
      assert_touch_targets_at_least 44

      overflowing = page.evaluate_script(<<~JS)
        (() => {
          const el = document.querySelector(".site-menu-panel .site-nav-identity");
          const limit = document.documentElement.clientWidth;
          const r = el.getBoundingClientRect();
          return { escapes: r.right > limit, clipped: el.scrollWidth > el.clientWidth };
        })()
      JS

      assert_equal false, overflowing["escapes"],
        "the identity must stay inside the viewport"
      assert_equal true, overflowing["clipped"],
        "an address too long for the panel must be truncated, not laid out full width"
    end
  end
end
