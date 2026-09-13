require "test_helper"

# Covers 004 spec.md at the HTTP layer: the rules a request has to satisfy before
# a proposal exists (FR-001..FR-004, FR-017, FR-018), and the scoping that keeps
# one user's proposals out of another's reach (FR-016, FR-020).
class LockerSwapProposalsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # FR-001: the ordinary case, from the wish list back to the wish list.
  test "a proposal to someone with an active wish is recorded" do
    sign_in users(:bob)

    assert_difference -> { LockerSwapProposal.count }, 1 do
      post locker_swap_proposals_path,
           params: { locker_swap_proposal: { recipient_id: users(:carol).id } }
    end

    assert_redirected_to locker_wishes_path
    assert_predicate LockerSwapProposal.last, :pending?
  end

  # FR-002 / Acceptance Scenario 2.
  test "a proposal to yourself is refused" do
    sign_in users(:bob)

    assert_no_difference -> { LockerSwapProposal.count } do
      post locker_swap_proposals_path,
           params: { locker_swap_proposal: { recipient_id: users(:bob).id } }
    end

    assert_redirected_to locker_wishes_path
    assert_match "yourself", flash[:alert]
  end

  # FR-017: dave has a locker but has declared no wish.
  test "a proposal to someone with no active wish is refused" do
    sign_in users(:bob)

    assert_no_difference -> { LockerSwapProposal.count } do
      post locker_swap_proposals_path,
           params: { locker_swap_proposal: { recipient_id: users(:dave).id } }
    end

    assert_redirected_to locker_wishes_path
    assert_match "not looking for a locker", flash[:alert]
  end

  # FR-003 / Acceptance Scenario 3.
  test "a proposal to someone already in an exchange is refused" do
    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:carol), status: :accepted)
    sign_in users(:bob)

    assert_no_difference -> { LockerSwapProposal.count } do
      post locker_swap_proposals_path,
           params: { locker_swap_proposal: { recipient_id: users(:carol).id } }
    end

    assert_redirected_to locker_wishes_path
    assert_match "already has an exchange in progress", flash[:alert]
  end

  # FR-004 / Acceptance Scenario 4: the sender's own locker is spoken for.
  test "a user already in an exchange cannot send a new proposal" do
    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:carol), status: :accepted)
    sign_in users(:dave)

    assert_no_difference -> { LockerSwapProposal.count } do
      post locker_swap_proposals_path,
           params: { locker_swap_proposal: { recipient_id: users(:bob).id } }
    end

    assert_redirected_to locker_wishes_path
    assert_match "already have an exchange in progress", flash[:alert]
  end

  # FR-018: alice already has one pending with bob.
  test "a second pending proposal to the same person is refused" do
    sign_in users(:alice)

    assert_no_difference -> { LockerSwapProposal.count } do
      post locker_swap_proposals_path,
           params: { locker_swap_proposal: { recipient_id: users(:bob).id } }
    end

    assert_redirected_to locker_wishes_path
    assert_match "already has a pending proposal from you", flash[:alert]
  end

  # FR-018 under concurrency: two submissions can both pass the validation before
  # either commits. The loser must read as the ordinary duplicate refusal, not as
  # a 500 the user cannot act on.
  test "a proposal that loses the database race is refused, not crashed" do
    sign_in users(:bob)

    with_the_first_save_losing_the_race do
      post locker_swap_proposals_path,
           params: { locker_swap_proposal: { recipient_id: users(:carol).id } }
    end

    assert_redirected_to locker_wishes_path
    assert_match "already has a pending proposal from you", flash[:alert]
  end

  # Edge Case: a decline settles that proposal, not the pairing. bob may ask
  # again later, as long as the ordinary rules still hold.
  test "a new proposal is allowed after an earlier one to the same person was declined" do
    sign_in users(:dave)

    assert_difference -> { LockerSwapProposal.count }, 1 do
      post locker_swap_proposals_path,
           params: { locker_swap_proposal: { recipient_id: users(:carol).id } }
    end

    assert_redirected_to locker_wishes_path
    assert_predicate LockerSwapProposal.last, :pending?
  end

  # FR-019.
  test "the requester can withdraw their own pending proposal" do
    sign_in users(:alice)

    delete locker_swap_proposal_path(locker_swap_proposals(:alice_pending_to_bob))

    assert_redirected_to root_path
    assert_predicate locker_swap_proposals(:alice_pending_to_bob).reload, :withdrawn?
  end

  # FR-020 / scoping: the recipient has no withdraw of their own to make, and the
  # proposal is simply not theirs to find in that context.
  test "the recipient cannot withdraw a proposal sent to them" do
    sign_in users(:bob)

    delete locker_swap_proposal_path(locker_swap_proposals(:alice_pending_to_bob))

    assert_response :not_found
    assert_predicate locker_swap_proposals(:alice_pending_to_bob).reload, :pending?
  end

  # FR-020: withdrawn is final, so there is nothing left to act on.
  test "a proposal that is already withdrawn cannot be withdrawn again" do
    sign_in users(:alice)

    delete locker_swap_proposal_path(locker_swap_proposals(:alice_withdrawn_to_carol))

    assert_response :not_found
  end

  # FR-005 / FR-006.
  test "the recipient can accept a proposal sent to them" do
    sign_in users(:bob)

    patch accept_locker_swap_proposal_path(locker_swap_proposals(:alice_pending_to_bob))

    assert_redirected_to root_path
    assert_predicate locker_swap_proposals(:alice_pending_to_bob).reload, :accepted?
  end

  # Scoping: the decision belongs to the recipient alone, so to anyone else the
  # proposal is simply not theirs to find.
  test "the requester cannot accept their own proposal" do
    sign_in users(:alice)

    patch accept_locker_swap_proposal_path(locker_swap_proposals(:alice_pending_to_bob))

    assert_response :not_found
    assert_predicate locker_swap_proposals(:alice_pending_to_bob).reload, :pending?
  end

  test "an uninvolved user cannot accept someone else's proposal" do
    sign_in users(:dave)

    patch accept_locker_swap_proposal_path(locker_swap_proposals(:alice_pending_to_bob))

    assert_response :not_found
    assert_predicate locker_swap_proposals(:alice_pending_to_bob).reload, :pending?
  end

  # FR-011: accepting settles every other proposal either party was part of.
  test "accepting declines the other pending proposals either party was part of" do
    competing = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob))
    sign_in users(:bob)

    patch accept_locker_swap_proposal_path(locker_swap_proposals(:alice_pending_to_bob))

    assert_redirected_to root_path
    assert_predicate competing.reload, :declined?
  end

  # FR-003 / FR-004: the race the model re-checks — reported, not crashed.
  test "accepting is refused when a party has meanwhile entered another exchange" do
    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob), status: :accepted)
    sign_in users(:bob)

    patch accept_locker_swap_proposal_path(locker_swap_proposals(:alice_pending_to_bob))

    assert_redirected_to root_path
    assert_match "already", flash[:alert]
    assert_predicate locker_swap_proposals(:alice_pending_to_bob).reload, :pending?
  end

  # FR-007 / FR-008.
  test "the recipient can decline with a comment" do
    sign_in users(:bob)

    patch decline_locker_swap_proposal_path(locker_swap_proposals(:alice_pending_to_bob)),
          params: { locker_swap_proposal: { decline_comment: "Too far from my desk" } }

    assert_redirected_to root_path
    proposal = locker_swap_proposals(:alice_pending_to_bob).reload
    assert_predicate proposal, :declined?
    assert_equal "Too far from my desk", proposal.decline_comment
  end

  # Acceptance Scenario 4: no comment is an ordinary decline, not a failure.
  test "the recipient can decline without a comment" do
    sign_in users(:bob)

    patch decline_locker_swap_proposal_path(locker_swap_proposals(:alice_pending_to_bob))

    assert_redirected_to root_path
    proposal = locker_swap_proposals(:alice_pending_to_bob).reload
    assert_predicate proposal, :declined?
    assert_predicate proposal.decline_comment, :blank?
  end

  # FR-010: a settled proposal is out of reach of either decision. Split in two
  # because a rescued 404 does not carry the signed-in session into a following
  # request, so each verb is asserted on its own.
  test "a proposal that has already been decided cannot be accepted" do
    sign_in users(:carol)

    patch accept_locker_swap_proposal_path(locker_swap_proposals(:dave_declined_to_carol))

    assert_response :not_found
    assert_predicate locker_swap_proposals(:dave_declined_to_carol).reload, :declined?
  end

  test "a proposal that has already been decided cannot be declined again" do
    sign_in users(:carol)

    patch decline_locker_swap_proposal_path(locker_swap_proposals(:dave_declined_to_carol)),
          params: { locker_swap_proposal: { decline_comment: "changed my mind" } }

    assert_response :not_found
    assert_equal "Found another swap", locker_swap_proposals(:dave_declined_to_carol).reload.decline_comment
  end

  # FR-012, FR-013: the recipient's confirmation is what moves the lockers.
  test "the recipient can confirm an exchange and both lockers move" do
    proposal = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob),
                                          status: :accepted)
    sign_in users(:bob)

    patch confirm_locker_swap_proposal_path(proposal)

    assert_redirected_to root_path
    assert_predicate proposal.reload, :completed?
    assert_equal [ "3", "B12" ], [ users(:dave).reload.floor, users(:dave).locker_number ]
    assert_equal [ "4", "D07" ], [ users(:bob).reload.floor, users(:bob).locker_number ]
  end

  # Acceptance Scenario 3 / FR-012: the requester has no confirmation to give.
  test "the requester cannot confirm the exchange" do
    proposal = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob),
                                          status: :accepted)
    sign_in users(:dave)

    patch confirm_locker_swap_proposal_path(proposal)

    assert_response :not_found
    assert_predicate proposal.reload, :accepted?
    assert_equal "D07", users(:dave).reload.locker_number
  end

  # Acceptance Scenario 4 / FR-014: confirming twice would swap the lockers back.
  test "an exchange that has been confirmed cannot be confirmed again" do
    proposal = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob),
                                          status: :accepted)
    proposal.confirm!
    sign_in users(:bob)

    patch confirm_locker_swap_proposal_path(proposal)

    assert_response :not_found
    assert_equal [ "3", "B12" ], [ users(:dave).reload.floor, users(:dave).locker_number ]
  end

  # FR-016 for the verbs a browser cannot issue on its own, mirroring how 003
  # covers its own write routes.
  test "an anonymous visitor cannot send a proposal" do
    assert_no_difference -> { LockerSwapProposal.count } do
      post locker_swap_proposals_path,
           params: { locker_swap_proposal: { recipient_id: users(:carol).id } }
    end

    assert_redirected_to new_user_session_path
  end

  test "an anonymous visitor cannot withdraw a proposal" do
    delete locker_swap_proposal_path(locker_swap_proposals(:alice_pending_to_bob))

    assert_redirected_to new_user_session_path
    assert_predicate locker_swap_proposals(:alice_pending_to_bob).reload, :pending?
  end

  test "an anonymous visitor cannot confirm an exchange" do
    proposal = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob),
                                          status: :accepted)

    patch confirm_locker_swap_proposal_path(proposal)

    assert_redirected_to new_user_session_path
    assert_predicate proposal.reload, :accepted?
  end

  test "an anonymous visitor cannot accept or decline a proposal" do
    patch accept_locker_swap_proposal_path(locker_swap_proposals(:alice_pending_to_bob))
    assert_redirected_to new_user_session_path

    patch decline_locker_swap_proposal_path(locker_swap_proposals(:alice_pending_to_bob))
    assert_redirected_to new_user_session_path

    assert_predicate locker_swap_proposals(:alice_pending_to_bob).reload, :pending?
  end

  private

    # No mocking gem is bundled (see Gemfile), so the stub is hand-rolled,
    # mirroring test/controllers/locker_wishes_controller_test.rb. It plays the
    # request that won the race: by the time the loser's write is rejected, a
    # pending proposal for that pair really does exist.
    def with_the_first_save_losing_the_race
      race_already_lost = false

      LockerSwapProposal.class_eval do
        alias_method :save_without_forced_conflict, :save

        define_method(:save) do |**options|
          next save_without_forced_conflict(**options) if race_already_lost

          race_already_lost = true
          raise ActiveRecord::RecordNotUnique, "forced by test"
        end
      end

      yield
    ensure
      LockerSwapProposal.class_eval do
        remove_method :save
        alias_method :save, :save_without_forced_conflict
        remove_method :save_without_forced_conflict
      end
    end
end
