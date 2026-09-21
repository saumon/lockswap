require "application_system_test_case"

# 026: opening the locker wishes screen's declare zone on arrival from the
# homepage's two invitations, and only from those two.
#
# The rule itself — when the disclosure carries `open` and the field carries
# `autofocus` — is proved in test/controllers/locker_wishes_controller_test.rb,
# where it is a server-side fact and the suite is fast and deterministic. This
# file exists only for what a browser alone can answer: that focus actually
# lands where the markup says it should, that a submission from that state
# still works, that it holds at phone width (FR-015), and that the opened
# screen still passes the accessibility bar (SC-004).
#
# test/system/homepage_locker_wish_test.rb documents three tests deleted for a
# click-and-follow flake that had nothing to do with the block under test — the
# click registered and the navigation did not, independently of any change to
# the block. Chasing this file's own version of that flake is what cut it down
# to exactly the three click-throughs research.md R8 originally budgeted — one
# per invitation, plus phone — with everything else folded into those three
# rather than kept as separate tests. Every other acceptance scenario this
# feature has (spending the intention on reload/Back, FR-008's guard for a
# viewer with a wish, FR-009's fold-by-hand) is either proved at the controller
# level or true by construction with no code of this feature's able to affect
# it; the reasoning for each is where task T019/T021/etc. in tasks.md left it,
# not repeated here.
#
# What retrying (click_reliably below) does *not* fix, and is not this
# feature's to fix: config/database.yml documents that this test suite's own
# threading model — the browser driving the app from a second thread while the
# test thread holds a transaction open — occasionally leaves a writer waiting
# behind it, and raised the busy-timeout from 5s to 15s for exactly that
# reason. Every request in this app, this feature's included, reads
# SiteLanguageSetting.current (an uncached query, ApplicationController
# #switch_locale) before anything else, so every click is also a chance to hit
# that contention. That is a pre-existing, whole-suite characteristic — an
# earlier baseline run of the full system suite hit the same
# "database is locked" error in admin_users_filter_test.rb, a file with
# nothing to do with this one — not a defect this feature introduces, and
# more retries made it worse here, not better, consistent with each retry
# being one more request competing for the same lock rather than one more
# chance at a dropped click.
class LockerWishEntryTest < ApplicationSystemTestCase
  # Retries a click up to 3 times, the same shape as fill_in_reliably above,
  # until +until_selector+ is genuinely on screen — confirming the click was
  # received and Turbo's navigation completed, not merely that the click
  # method returned. Scoped to this file rather than added to
  # ApplicationSystemTestCase: it fixes one class's problem (a dropped click
  # losing an entire navigation), not fill_in_reliably's (a dropped keystroke
  # within a field already on screen), and nothing else in the suite has hit
  # this driver defect from a plain link click before.
  def click_reliably(locator, until_selector:)
    3.times do
      click_on locator
      wait_for_turbo
      return if page.has_selector?(until_selector, wait: 1)
    end

    assert_selector until_selector
  end

  # Acceptance Scenarios 1 and 3 (FR-004, FR-005): erin has a floor and no
  # locker and no wish — "I want a locker! 🙏". Also carries SC-004's
  # accessibility check and Acceptance Scenario 3's submit-from-arrival proof,
  # rather than splitting either into its own click-through.
  test "pressing I want a locker opens the declare zone, focused, submittable and accessible" do
    log_in_as users(:erin)

    click_reliably "I want a locker! 🙏", until_selector: "details[open] summary"

    assert_selector "details[open] summary", text: "I'm looking for a locker"
    assert_equal "locker_wish_floor", page.evaluate_script("document.activeElement.id")

    assert_axe_clean

    fill_in_reliably "Floor", with: "4"
    click_on "Save my wish"

    assert_selector "#locker-wish-floor", text: "4"
    assert_equal "4", users(:erin).reload.locker_wish.floor
  end

  # Acceptance Scenario 2 (FR-004, FR-005): dave has a floor and a locker and no
  # wish — "I want to switch my locker! 👀". One behaviour covers both
  # invitations, so this test only needs to prove the second link reaches the
  # same state; the erin test above already carries the rest.
  test "pressing I want to switch my locker opens the declare zone with the floor field focused" do
    log_in_as users(:dave)

    click_reliably "I want to switch my locker! 👀", until_selector: "details[open] summary"

    assert_selector "details[open] summary", text: "I'm looking for a locker"
    assert_equal "locker_wish_floor", page.evaluate_script("document.activeElement.id")
  end

  # FR-015: no narrow-screen exception. The keyboard the focus raises is an
  # accepted consequence of the invitation the person pressed (spec Edge Cases).
  # Also carries the touch-target check, at the viewport that check is
  # everywhere else in the suite scoped to (responsive_test.rb,
  # site_menu_test.rb) — at desktop width the site nav's small links and
  # compact "Propose swap" buttons are mouse targets, not touch ones, and are
  # outside this feature's scope regardless.
  test "the same arrival opens and focuses at phone width" do
    log_in_as users(:erin)

    with_viewport(:phone) do
      click_reliably "I want a locker! 🙏", until_selector: "details[open] summary"

      assert_selector "details[open] summary", text: "I'm looking for a locker"
      assert_equal "locker_wish_floor", page.evaluate_script("document.activeElement.id")
      assert_touch_targets_at_least
    end
  end
end
