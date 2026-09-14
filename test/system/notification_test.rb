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

    def main_rect
      rect = find("main").native.rect
      [ rect.x, rect.y, rect.width, rect.height ]
    end
end
