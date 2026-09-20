require "application_system_test_case"

# Covers 007 User Story 1 (FR-001, FR-003) and the clarified pause-on-hover
# behaviour that keeps a short-lived message readable.
class NotificationTest < ApplicationSystemTestCase
  SIGN_IN_MESSAGE = "Signed in successfully.".freeze
  FAILURE_MESSAGE = "Invalid email or password.".freeze

  # The test environment runs a shorter countdown than the one that ships (see
  # config/environments/test.rb), so the waits below are taken from it rather
  # than written out — change the setting and these follow.
  COUNTDOWN = Rails.configuration.x.notification_auto_dismiss_ms / 1000.0

  setup { @user = users(:alice) }

  # User Story 1, Acceptance Scenarios 1 and 3.
  test "a success message arrives as a popup and then takes itself away" do
    log_in_as @user

    assert_selector "[role=status]", text: SIGN_IN_MESSAGE

    # Still there a moment on: a message that flickers straight past is as
    # unreadable as no message at all, so the countdown has to be a countdown
    # rather than merely ending in the element's eventual removal.
    sleep COUNTDOWN / 4
    assert_selector "[role=status]", text: SIGN_IN_MESSAGE, wait: 0

    assert_no_selector "[role=status]", text: SIGN_IN_MESSAGE
  end

  # Clarifications, 2026-09-14: the countdown pauses on hover and resumes once
  # the pointer leaves.
  test "pointing at a message holds it open, and moving away lets it go" do
    log_in_as @user
    find("[role=status]", text: SIGN_IN_MESSAGE).hover

    sleep COUNTDOWN * 2 # comfortably past the countdown it is being held through

    assert_selector "[role=status]", text: SIGN_IN_MESSAGE, wait: 0

    find("main").hover

    assert_no_selector "[role=status]", text: SIGN_IN_MESSAGE
  end

  # User Story 2: a refusal is delivered the same way a success is, and is told
  # apart at a glance rather than by reading it.
  test "an error message arrives as a popup, styled apart from a success, and then goes" do
    visit new_user_session_path
    fill_in_reliably "Email", with: @user.email
    fill_in_reliably "Password", with: "wrong-password"
    click_on "Log in"

    refusal = find("[role=alert]", text: FAILURE_MESSAGE)

    # 008: this asserted Tailwind class names until the visual refresh replaced
    # them with a component class. Same behaviour, asserted one level lower —
    # the colour a reader actually sees, rather than the name of the rule that
    # produced it, so a future rename cannot break it again. The accent bar is
    # the error tint (#9F1239) and not the success one (#07795A).
    accent = refusal.native.css_value("border-left-color").delete(" ")
    assert_match(/^rgba?\(159,18,57/, accent)
    assert_no_match(/^rgba?\(7,121,90/, accent)

    assert_no_selector "[role=alert]", text: FAILURE_MESSAGE
  end

  # User Story 3: a reader who is already done should not have to wait out the
  # rest of the countdown.
  test "a message can be dismissed by hand without waiting out the countdown" do
    log_in_as @user
    notification = find("[role=status]", text: SIGN_IN_MESSAGE)

    # Hovering first stops the clock, so the message can only leave by being
    # dismissed — a button that did nothing would leave it on screen for good
    # rather than letting the countdown quietly pass the test.
    notification.hover
    notification.find("button[aria-label='Dismiss notification']").click

    assert_no_selector "[role=status]", text: SIGN_IN_MESSAGE
  end

  # FR-005 and SC-003: the overlay owes the page underneath nothing — no room
  # taken while it is up, and no gap left behind when it goes.
  test "a message neither moves the page it covers nor leaves a gap behind" do
    log_in_as @user
    assert_selector "[role=status]", text: SIGN_IN_MESSAGE

    while_showing = main_rect
    assert_no_selector "[role=status]", text: SIGN_IN_MESSAGE
    once_gone = main_rect

    assert_equal while_showing, once_gone
  end

  # 023 FR-002: the icon doubles the color signal — never the sole one, per
  # CLAUDE.md, but present alongside it now rather than color-and-text alone.
  test "a success notification renders its type icon" do
    log_in_as @user
    icon = find("[role=status]", text: SIGN_IN_MESSAGE).find("svg.toast-icon", visible: :all)
    assert_equal "true", icon["aria-hidden"]
  end

  test "an error notification renders its type icon" do
    visit new_user_session_path
    fill_in_reliably "Email", with: @user.email
    fill_in_reliably "Password", with: "wrong-password"
    click_on "Log in"
    icon = find("[role=alert]", text: FAILURE_MESSAGE).find("svg.toast-icon", visible: :all)
    assert_equal "true", icon["aria-hidden"]
  end

  # 023 FR-009: the redesign must not regress accessibility — the new icon in
  # particular must not be announced on top of the role/text that already
  # carry the message to assistive technology.
  test "a visible notification has no accessibility violations" do
    log_in_as @user
    assert_selector "[role=status]", text: SIGN_IN_MESSAGE
    assert_axe_clean
  end

  # 023 FR-004 / SC-006: entrance and exit must settle within the app's
  # existing motion budget (--motion-entrance, 240ms) rather than being
  # abrupt — but also rather than lingering past it.
  test "a notification's entrance and exit stay within the motion budget" do
    log_in_as @user
    notification = find("[role=status]", text: SIGN_IN_MESSAGE)

    assert_operator animation_duration_ms(notification), :<=, 240

    notification.hover # hold the countdown so only the click drives the exit
    notification.find("button[aria-label='Dismiss notification']").click

    leaving = find("[role=status].is-leaving", text: SIGN_IN_MESSAGE, wait: 0.5)
    assert_operator animation_duration_ms(leaving), :<=, 240

    assert_no_selector "[role=status]", text: SIGN_IN_MESSAGE
  end

  # 023 US2 acceptance scenario 1: fixed to the bottom-right, never over the
  # header, resolved in the 2026-09-20 clarification (spec.md).
  test "at desktop width a notification is fixed to the bottom-right, clear of the header" do
    log_in_as @user
    notification = find("[role=status]", text: SIGN_IN_MESSAGE)

    viewport = page.evaluate_script("({ width: window.innerWidth, height: window.innerHeight })")
    toast = notification.native.rect
    header = find(".site-header").native.rect

    assert_operator toast.x + toast.width, :>, viewport["width"] / 2,
      "expected the toast to sit in the right half of the viewport"
    assert_operator toast.y + toast.height, :>, viewport["height"] / 2,
      "expected the toast to sit in the bottom half of the viewport"
    assert_not rects_intersect?(toast, header), "toast overlaps the header"
  end

  # 023 US2 acceptance scenario 2: fully visible and readable at phone width,
  # no horizontal scroll, clear of the header's own controls.
  test "at phone width a notification stays fully visible and clear of the menu toggle" do
    with_viewport(:phone) do
      log_in_as @user
      assert_selector "[role=status]", text: SIGN_IN_MESSAGE

      assert_no_horizontal_overflow("with a notification visible")

      toast = find("[role=status]", text: SIGN_IN_MESSAGE).native.rect
      toggle = find("[aria-label='Menu']").native.rect
      assert_not rects_intersect?(toast, toggle), "toast covers the menu toggle"
    end
  end

  # Edge case: resizing/rotating with a notification already on screen must
  # not strand it off-screen or over content at the new width.
  test "a notification re-settles when the viewport resizes across the breakpoint" do
    log_in_as @user
    notification = find("[role=status]", text: SIGN_IN_MESSAGE)
    notification.hover # hold it open across the resize

    with_viewport(:phone) do
      assert_no_horizontal_overflow("after resizing to phone width")
      toast = find("[role=status]", text: SIGN_IN_MESSAGE).native.rect
      viewport = page.evaluate_script("({ width: window.innerWidth, height: window.innerHeight })")
      assert_operator toast.x, :>=, 0
      assert_operator toast.x + toast.width, :<=, viewport["width"]
      assert_operator toast.y + toast.height, :<=, viewport["height"]
    end
  end

  # New edge case (spec.md, added after /speckit-analyze's E2 finding): a
  # short viewport must not let the toast drift off the top of the screen or
  # over the header, the same guarantee desktop/phone already get.
  test "on a short viewport a notification stays fully on screen and clear of the header" do
    log_in_as @user

    with_custom_viewport(700, 400) do
      assert_selector "[role=status]", text: SIGN_IN_MESSAGE
      toast = find("[role=status]", text: SIGN_IN_MESSAGE).native.rect
      header = find(".site-header").native.rect
      viewport = page.evaluate_script("({ width: window.innerWidth, height: window.innerHeight })")

      assert_operator toast.y, :>=, 0, "toast top edge is above the viewport"
      assert_operator toast.y + toast.height, :<=, viewport["height"], "toast bottom edge is below the viewport"
      assert_not rects_intersect?(toast, header), "toast overlaps the header"
    end
  end

  # 023 US3 acceptance scenario 1: FR-005's existing stacking behaviour,
  # unchanged, now with the redesigned card. There is no production trigger
  # for two toasts at once yet (a single request carries at most notice +
  # alert), so the second is injected the same way toast_layer_controller's
  # own enqueue() seam expects a future live-append mechanism to.
  test "two notifications visible at once are stacked with clear separation" do
    log_in_as @user
    first = find("[role=status]", text: SIGN_IN_MESSAGE)
    first.hover # hold it open so it cannot dismiss mid-assertion

    inject_toast(role: "alert", palette: "toast-error", message: "Second notification.")
    second = find("[role=alert]", text: "Second notification.")

    assert_not rects_intersect?(first.native.rect, second.native.rect)
  end

  # 023 US3 acceptance scenario 2 / FR-010: a burst beyond the visible cap
  # queues rather than crowding, and a promoted toast gets a full countdown
  # of its own rather than one already run down while it waited
  # (data-model.md's Toast Layer transition rule).
  test "a burst of 4+ notifications caps visible toasts and queues the rest" do
    log_in_as @user
    first = find("[role=status]", text: SIGN_IN_MESSAGE)
    first.hover # holds #1 open — it is the one we dismiss by hand below

    inject_toast(role: "alert", palette: "toast-error", message: "Burst one.")
    inject_toast(role: "alert", palette: "toast-error", message: "Burst two.")
    inject_toast(role: "alert", palette: "toast-error", message: "Burst three.", duration_ms: 400)

    assert_selector "[role]", text: "Burst one."
    assert_selector "[role]", text: "Burst two."
    assert_no_selector "[role]", text: "Burst three." # visible: default — hidden while queued
    assert_selector "[role]", text: "Burst three.", visible: :all # present, just not shown

    first.find("button[aria-label='Dismiss notification']").click
    assert_no_selector "[role=status]", text: SIGN_IN_MESSAGE # the freed slot

    assert_selector "[role]", text: "Burst three." # promoted out of the queue

    # A fresh 400ms countdown from promotion, not one already run down while
    # queued: still present well before 400ms have passed since promotion...
    sleep 0.2
    assert_selector "[role]", text: "Burst three.", wait: 0
    # ...and gone once its own full countdown has actually elapsed.
    assert_no_selector "[role]", text: "Burst three."
  end

  # Edge case: a long message has to grow downwards, not burst sideways out of
  # the viewport and take the layout with it.
  test "a long message wraps instead of bursting out of its box" do
    log_in_as @user
    notification = find("[role=status]", text: SIGN_IN_MESSAGE)
    notification.hover # holds the countdown so the measuring is not a race

    one_line_high = notification.native.rect.height
    page.execute_script(
      "arguments[0].querySelector('span').textContent = arguments[1]",
      notification, "Locker details saved. " * 40
    )

    grown = notification.native.rect
    assert_operator grown.height, :>, one_line_high
    assert_operator grown.width, :<=, page.execute_script("return document.documentElement.clientWidth")
  end

  private

    # Builds a toast the same shape _flash.html.erb renders and hands it to
    # toast_layer_controller#enqueue — the one seam that applies FR-010's cap,
    # exactly as a future live-append mechanism would need to. There is no
    # such mechanism yet (see the test above), so this stands in for it.
    def inject_toast(role:, palette:, message:, duration_ms: Rails.configuration.x.notification_auto_dismiss_ms)
      page.execute_script(<<~JS, role, palette, message, duration_ms)
        const [role, palette, message, durationMs] = arguments
        const el = document.createElement("div")
        el.className = `toast pointer-events-auto ${palette}`
        el.setAttribute("role", role)
        el.setAttribute("data-controller", "notification")
        el.setAttribute("data-toast-layer-target", "toast")
        el.setAttribute("data-notification-duration-value", durationMs)
        el.setAttribute("data-action",
          "mouseenter->notification#pause mouseleave->notification#resume " +
          "focusin->notification#pause focusout->notification#resume")
        el.innerHTML = `
          <svg class="toast-icon" viewBox="0 0 20 20" fill="none" aria-hidden="true">
            <circle cx="10" cy="10" r="9" stroke="currentColor" stroke-width="1.5"></circle>
          </svg>
          <span class="min-w-0 flex-1 break-words"></span>
          <button type="button" aria-label="Dismiss notification" data-action="notification#dismiss" class="toast-dismiss">&times;</button>
        `
        el.querySelector("span").textContent = message

        const layerEl = document.querySelector(".toast-layer")
        const layer = window.Stimulus.getControllerForElementAndIdentifier(layerEl, "toast-layer")
        layer.enqueue(el)
      JS
    end

    def rects_intersect?(a, b)
      a.x < b.x + b.width && a.x + a.width > b.x &&
        a.y < b.y + b.height && a.y + a.height > b.y
    end

    # 023 US2's short-viewport edge case needs a height no named VIEWPORTS
    # entry has (application_system_test_case.rb's :phone/:desktop/:minimum
    # are all taller than they are testing for here) — same CDP technique as
    # with_viewport, with dimensions of its own rather than a fourth named one.
    def with_custom_viewport(width, height)
      @emulated_metrics = true
      page.driver.browser.execute_cdp(
        "Emulation.setDeviceMetricsOverride",
        width: width, height: height, deviceScaleFactor: 0, mobile: false
      )
      yield
    ensure
      clear_viewport_override
    end

    def animation_duration_ms(element)
      duration = element.native.css_value("animation-duration").strip
      duration.end_with?("ms") ? duration.to_f : duration.to_f * 1000
    end

    def main_rect
      rect = find("main").native.rect
      [ rect.x, rect.y, rect.width, rect.height ]
    end
end
