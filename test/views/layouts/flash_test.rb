require "test_helper"

# Covers 007 FR-007 and SC-005: when a page carries both a success and a failure,
# neither one may swallow the other. No controller action sets both today, so the
# partial is exercised directly rather than through a flow that cannot produce it.
class FlashTest < ActionView::TestCase
  test "a notice and an alert are both rendered, each with its own role" do
    render partial: "layouts/flash",
           locals: { notice: "Locker details saved.", alert: "Swap proposal refused." }

    assert_select "[role=status]", count: 1, text: /Locker details saved\./
    assert_select "[role=alert]", count: 1, text: /Swap proposal refused\./
  end

  test "both messages share one stacking container, so neither covers the other" do
    render partial: "layouts/flash",
           locals: { notice: "Locker details saved.", alert: "Swap proposal refused." }

    assert_select "div.fixed.flex-col" do
      assert_select "[role=status]", count: 1
      assert_select "[role=alert]", count: 1
    end
  end

  # FR-008: a message that comes and goes on its own still has to reach a screen
  # reader. role=status and role=alert are live regions in their own right —
  # polite for a success, assertive for a failure — and the way out is labelled
  # rather than left as a bare glyph.
  test "each message carries the role its urgency calls for and a labelled way out" do
    render partial: "layouts/flash",
           locals: { notice: "Locker details saved.", alert: "Swap proposal refused." }

    assert_select "[role=status] button[aria-label=?]", "Dismiss notification", count: 1
    assert_select "[role=alert] button[aria-label=?]", "Dismiss notification", count: 1
  end

  # FR-003 names three seconds, and the test environment deliberately runs a
  # shorter countdown, so the shipped figure is pinned here rather than being
  # taken on trust from a suite that never uses it.
  test "the countdown that ships is the three seconds the spec asks for" do
    assert_equal 3000, Lockswap::Application::NOTIFICATION_AUTO_DISMISS_MS
  end

  test "the rendered countdown comes from configuration, not a hardcoded figure" do
    render partial: "layouts/flash", locals: { notice: "Locker details saved.", alert: nil }

    assert_select "[role=status][data-notification-duration-value=?]",
                  Rails.configuration.x.notification_auto_dismiss_ms.to_s
  end

  test "nothing at all is rendered when there is no message to show" do
    render partial: "layouts/flash", locals: { notice: nil, alert: nil }

    assert_select "[role=status]", count: 0
    assert_select "[role=alert]", count: 0
    assert_empty rendered.strip
  end
end
