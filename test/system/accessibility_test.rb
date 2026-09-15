require "application_system_test_case"

# 008 FR-028 / SC-004: the automated accessibility coverage for every screen.
#
# This is the feature's primary test evidence. A visual refresh has no business
# logic to unit-test, so what gets asserted instead is what the refresh actually
# promises: contrast, visible focus, accessible naming and heading order, on
# every screen, as part of the standard suite.
#
# assert_axe_clean carries one documented exemption — colour contrast on the
# brand wordmark, per WCAG 2.1 SC 1.4.3. See test/application_system_test_case.rb.
class AccessibilityTest < ApplicationSystemTestCase
  setup do
    @user = users(:carol)
  end

  # --- Brand (User Story 1) -------------------------------------------------

  test "the header brand is a mark plus the product name" do
    log_in_as @user

    within "header" do
      assert_selector "a svg[data-brand-mark]", visible: :all
      assert_selector "a", text: "LockSwap"
    end
  end

  # FR-003a: the tagline is rendered in English so it matches the interface, and
  # the French original from the source artwork never reaches a page.
  test "the sign-in page shows the stacked lockup with the English tagline" do
    visit new_user_session_path

    # The auth screens carry the supplied artwork as an image rather than the
    # vector trace the header uses, so this matches on the marker, not the tag.
    assert_selector "[data-brand-mark]", visible: :all
    assert_text "Find the locker that suits you"
    assert_no_text "Trouvez le casier"
  end

  # --- Every screen (User Story 2) ------------------------------------------

  test "sign in is accessible" do
    visit new_user_session_path
    assert_axe_clean
  end

  test "sign up is accessible" do
    visit new_user_registration_path
    assert_axe_clean
  end

  test "account settings is accessible" do
    log_in_as @user
    visit edit_user_registration_path
    assert_axe_clean
  end

  # alice has neither floor nor locker — the "not yet asked" case.
  test "home without locker details is accessible" do
    log_in_as users(:alice)
    assert_axe_clean

    # 009: taking the first-entry choice leaves a different set of controls on
    # screen — a field gone, one trigger swapped for another — so the screen it
    # turns into is audited in its own right.
    wait_for_turbo
    click_on "I don't have a locker 😔"
    assert_axe_clean
  end

  # carol has a floor on file, so the saved profile and its disclosure render.
  test "home with a saved locker profile is accessible" do
    log_in_as @user
    assert_axe_clean
  end

  # dave has a floor and locker on file and no *active* proposal, so the edit
  # disclosure is offered rather than locked.
  test "home with the edit disclosure open is accessible" do
    log_in_as users(:dave)
    # 009: the control is a pencil now, so it is found by its accessible name —
    # which this audit is also, in passing, checking it still has.
    find("summary[aria-label='Edit locker details']").click
    assert_axe_clean
  end

  # bob is the recipient of alice_pending_to_bob.
  test "home with a received proposal is accessible" do
    log_in_as users(:bob)
    assert_selector "#swap-proposals-received"
    assert_axe_clean
  end

  # alice is the requester of alice_pending_to_bob.
  test "home with a sent proposal is accessible" do
    log_in_as users(:alice)
    assert_selector "#swap-proposals-sent"
    assert_axe_clean
  end

  # dave's proposal to carol was declined and not yet acknowledged.
  test "home with a declined proposal is accessible" do
    log_in_as users(:dave)
    assert_selector "#swap-proposals-declined"
    assert_axe_clean
  end

  test "home with an exchange in progress is accessible" do
    # bob is the valid recipient here: an accepted proposal requires the
    # recipient to be looking for a locker, and bob_wish is the fixture wish.
    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob), status: :accepted)
    log_in_as users(:bob)
    assert_selector "#swap-exchange-in-progress"
    assert_axe_clean
  end

  test "the locker wish list is accessible" do
    log_in_as @user
    visit locker_wishes_path
    assert_selector "#locker-wish-list"
    assert_axe_clean
  end

  test "an empty locker wish list is accessible" do
    LockerWish.delete_all
    log_in_as @user
    visit locker_wishes_path
    assert_selector "#locker-wish-list-empty"
    assert_axe_clean
  end

  test "the proposal history is accessible" do
    log_in_as @user
    visit locker_swap_proposals_path
    assert_selector "#swap-proposal-history"
    assert_axe_clean
  end

  test "an empty proposal history is accessible" do
    log_in_as users(:bob)
    LockerSwapProposal.delete_all
    visit locker_swap_proposals_path
    assert_selector "#swap-proposal-history-empty"
    assert_axe_clean
  end

  # --- Tab order (FR-015b) --------------------------------------------------
  #
  # Restructuring a layout is allowed; walking it out of order is not. These are
  # the three screens whose structure changes most, so they are the ones where a
  # reordered DOM would go unnoticed.

  test "tab order follows visual order on the home page" do
    log_in_as users(:bob)
    assert_no_selector "[role=status]"   # let the sign-in notification go first
    assert_tab_order_follows_visual_order
  end

  test "tab order follows visual order on the locker wish list" do
    log_in_as @user
    visit locker_wishes_path
    assert_selector "#locker-wish-list"
    assert_tab_order_follows_visual_order
  end

  # The proposal history is deliberately absent here: it is read-only, with no
  # focusable control inside <main> at all, so there is no tab order on it to
  # get wrong. Its restructuring is covered by the axe audit above instead.
end
