require "application_system_test_case"

# Covers 004 spec.md User Story 1 end to end: proposing from the wish list, the
# notes shown where proposing is not available, and withdrawing from the
# homepage (FR-001..FR-004, FR-018, FR-019).
class LockerSwapProposalTest < ApplicationSystemTestCase
  # The control lives on the row of the person being proposed to, so tests aim at
  # that row rather than at the first matching button on the page.
  def wish_row(user)
    find("#locker-wish-row-#{user.id}")
  end

  # Acceptance Scenario 1: the wish list is where a swap starts.
  test "a proposal can be sent from the wish list to someone looking for a locker" do
    log_in_as users(:dave)
    visit locker_wishes_path

    wish_row(users(:bob)).click_on "Propose swap"

    assert_text "Swap proposal sent."
    assert_equal users(:bob), users(:dave).sent_swap_proposals.pending.last&.recipient
  end

  # Acceptance Scenario 2: there is no control to propose to yourself, so the
  # rule never has to be explained after the fact.
  test "no propose control is offered on your own row" do
    log_in_as users(:carol)
    visit locker_wishes_path

    assert_selector "#locker-wish-row-#{users(:carol).id}"
    assert_no_selector "#locker-wish-row-#{users(:carol).id} input[value='Propose swap']"
  end

  # Acceptance Scenario 3 / Edge Case: someone mid-swap is not an eligible
  # recipient, and their wish stops being listed as an open invitation at all.
  test "a wish is not listed while its owner has an exchange in progress" do
    # dave rather than alice as the requester: alice already has a pending
    # proposal to bob in the fixtures, which is exactly what FR-018 forbids
    # doubling up on.
    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob), status: :accepted)

    log_in_as users(:alice)
    visit locker_wishes_path

    assert_no_selector "#locker-wish-row-#{users(:bob).id}"
    assert_selector "#locker-wish-row-#{users(:carol).id}"
  end

  # Acceptance Scenario 4 / FR-004: the viewer's own swap blocks every row, and
  # says so rather than leaving the page looking broken.
  test "a viewer in an exchange is told why they cannot propose" do
    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:carol), status: :accepted)

    log_in_as users(:dave)
    visit locker_wishes_path

    assert_no_selector "input[value='Propose swap']"
    assert_text "You already have an exchange in progress"
  end

  # FR-018: the row says the proposal is already with them, instead of offering a
  # control that is going to be refused.
  test "a row already holding a pending proposal from the viewer says so" do
    log_in_as users(:alice)
    visit locker_wishes_path

    within wish_row(users(:bob)) do
      assert_text "Proposal pending"
      assert_no_selector "input[value='Propose swap']"
    end
  end

  # Acceptance Scenario 5: alice has neither a locker nor a wish of her own.
  test "a user with no locker of their own can still propose a swap" do
    log_in_as users(:alice)
    visit locker_wishes_path

    wish_row(users(:carol)).click_on "Propose swap"

    assert_text "Swap proposal sent."
    assert_equal users(:carol), users(:alice).sent_swap_proposals.pending.last&.recipient
  end

  # Acceptance Scenario 6 / FR-019, FR-020: withdrawn before a decision lands, and
  # then gone from the recipient's side too.
  test "a pending proposal can be withdrawn and stops being actionable" do
    log_in_as users(:alice)
    visit root_path

    within "#swap-proposals-sent" do
      assert_text users(:bob).email
      click_on "Withdraw"
    end

    assert_text "Swap proposal withdrawn."
    assert_predicate locker_swap_proposals(:alice_pending_to_bob).reload, :withdrawn?

    # Logging out first: a logged-in visitor is bounced off the login page back
    # to the homepage (001 FR-010), so the second login needs the session gone.
    click_on "Log out"
    assert_text "Signed out successfully."
    log_in_as users(:bob)

    assert_no_selector "#swap-proposals-received"
  end

  # User Story 2, Acceptance Scenario 1 (FR-005, FR-006): the homepage is where a
  # proposal is answered, so it does not have to be hunted for.
  test "a received proposal can be accepted from the homepage" do
    log_in_as users(:bob)

    within "#swap-proposals-received" do
      assert_text users(:alice).email
      click_on "Accept"
    end

    assert_text "Swap proposal accepted."
    assert_predicate locker_swap_proposals(:alice_pending_to_bob).reload, :accepted?
  end

  # Acceptance Scenarios 2 and 3 (FR-007, FR-008): declining says why, if the
  # decliner wants to. The comment field sits behind a disclosure, matching how
  # 002 and 003 keep deliberate actions out of the way until they are chosen.
  test "a received proposal can be declined with a comment" do
    log_in_as users(:bob)

    within "#swap-proposals-received" do
      find("summary", text: "Decline").click
      fill_in_reliably "Why? (optional)", with: "Too far from my desk"
      click_on "Confirm decline"
    end

    assert_text "Swap proposal declined."
    proposal = locker_swap_proposals(:alice_pending_to_bob).reload
    assert_predicate proposal, :declined?
    assert_equal "Too far from my desk", proposal.decline_comment
  end

  # Acceptance Scenario 4: the comment is optional all the way through the UI.
  test "a received proposal can be declined without a comment" do
    log_in_as users(:bob)

    within "#swap-proposals-received" do
      find("summary", text: "Decline").click
      click_on "Confirm decline"
    end

    assert_text "Swap proposal declined."
    proposal = locker_swap_proposals(:alice_pending_to_bob).reload
    assert_predicate proposal, :declined?
    assert_predicate proposal.decline_comment, :blank?
  end

  # Acceptance Scenario 5 / FR-010: once answered, the proposal stops offering
  # an answer — the controls are gone rather than refusing a second click.
  test "an answered proposal offers no further decision" do
    log_in_as users(:bob)

    within("#swap-proposals-received") { click_on "Accept" }

    assert_text "Swap proposal accepted."
    assert_no_selector "#swap-proposals-received"
  end

  # User Story 3, Acceptance Scenario 3 (FR-007, FR-009): the decline is how the
  # requester finds out, and the comment comes with it. dave's fixture decline is
  # still unacknowledged, so it is owed to him.
  test "a requester is told on the homepage that their proposal was declined" do
    log_in_as users(:dave)

    within "#swap-proposals-declined" do
      assert_text users(:carol).email
      assert_text "Found another swap"
    end
  end

  # The notification is news, not a permanent fixture of the page: having been
  # shown once, it does not follow the requester around forever.
  test "a decline notification does not reappear after it has been seen" do
    log_in_as users(:dave)
    assert_selector "#swap-proposals-declined"

    visit root_path

    assert_no_selector "#swap-proposals-declined"
  end

  # Acceptance Scenarios 1 and 2: both directions on one page.
  test "pending proposals sent and received both appear on the homepage" do
    LockerSwapProposal.create!(requester: users(:bob), recipient: users(:carol))

    log_in_as users(:bob)

    within("#swap-proposals-received") { assert_text users(:alice).email }
    within("#swap-proposals-sent") { assert_text users(:carol).email }
  end

  # Acceptance Scenario 4: no swap activity means no swap sections at all —
  # carol has only proposals already settled, and none of them is hers to answer.
  test "a user with no live proposals sees no proposal sections" do
    log_in_as users(:carol)

    assert_text "Welcome to LockSwap"
    assert_no_selector "#swap-proposals-received"
    assert_no_selector "#swap-proposals-sent"
    assert_no_selector "#swap-proposals-declined"
  end

  # User Story 4, Acceptance Scenarios 1 and 2 (FR-013): accepted, then actually
  # swapped — the two accounts end up holding each other's lockers.
  test "the recipient can confirm the exchange and both lockers change hands" do
    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob), status: :accepted)

    log_in_as users(:bob)

    within "#swap-exchange-in-progress" do
      assert_text users(:dave).email
      click_on "Confirm exchange completed"
    end

    assert_text "Exchange confirmed"
    assert_equal [ "4", "D07" ], [ users(:bob).reload.floor, users(:bob).locker_number ]
    assert_equal [ "3", "B12" ], [ users(:dave).reload.floor, users(:dave).locker_number ]
  end

  # Acceptance Scenario 3 / FR-012: the requester watches, they do not confirm.
  test "the requester sees the exchange but is offered no confirmation" do
    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob), status: :accepted)

    log_in_as users(:dave)

    within "#swap-exchange-in-progress" do
      assert_text users(:bob).email
      assert_no_selector "input[value='Confirm exchange completed']"
    end
  end

  # User Story 5, Acceptance Scenario 1 (FR-015): both directions, one screen,
  # reached from the nav rather than by knowing the address.
  test "the history lists every proposal the viewer sent or received" do
    log_in_as users(:carol)
    click_on "Proposal history"

    within "#swap-proposal-history-row-#{locker_swap_proposals(:dave_declined_to_carol).id}" do
      assert_text "Received"
      assert_text users(:dave).email
    end

    within "#swap-proposal-history-row-#{locker_swap_proposals(:alice_withdrawn_to_carol).id}" do
      assert_text "Received"
      assert_text "Withdrawn"
    end
  end

  # Acceptance Scenario 2: a decline is shown with whatever was said about it.
  test "the history shows declines with their comment" do
    log_in_as users(:dave)
    visit locker_swap_proposals_path

    within "#swap-proposal-history-row-#{locker_swap_proposals(:dave_declined_to_carol).id}" do
      assert_text "Sent"
      assert_text "Declined"
      assert_text "Found another swap"
    end
  end

  # Acceptance Scenario 3: a finished swap reads as finished.
  test "the history shows a completed exchange" do
    proposal = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob),
                                          status: :accepted)
    proposal.confirm!

    log_in_as users(:dave)
    visit locker_swap_proposals_path

    within("#swap-proposal-history-row-#{proposal.id}") { assert_text "Completed" }
  end

  # Acceptance Scenario 4: never having proposed anything is not an error.
  test "the history of someone with no proposals is empty rather than broken" do
    LockerSwapProposal.destroy_all

    log_in_as users(:alice)
    visit locker_swap_proposals_path

    assert_selector "#swap-proposal-history-empty"
  end

  # The review surface stays a review surface: nothing here decides anything.
  test "the history offers no controls to act on a proposal" do
    log_in_as users(:bob)
    visit locker_swap_proposals_path

    assert_selector "#swap-proposal-history"
    assert_no_selector "#swap-proposal-history input[type=submit]"
  end
end
