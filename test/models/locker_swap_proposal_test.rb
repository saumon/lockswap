require "test_helper"

# Covers 004 spec.md at the model layer: who may be proposed to (FR-001..FR-004,
# FR-017, FR-018), and the state transitions each decision makes.
class LockerSwapProposalTest < ActiveSupport::TestCase
  # FR-001: the ordinary case — a requester, and a recipient who is looking.
  test "a proposal to someone with an active wish is valid" do
    proposal = LockerSwapProposal.new(requester: users(:bob), recipient: users(:carol))

    assert proposal.valid?
    assert proposal.save
    assert_predicate proposal, :pending?
  end

  # FR-002 / Acceptance Scenario 2: there is no swap to make with yourself.
  test "a proposal cannot target the user who sent it" do
    proposal = LockerSwapProposal.new(requester: users(:bob), recipient: users(:bob))

    assert_not proposal.valid?
    assert_includes proposal.errors[:recipient], "cannot be yourself"
  end

  # FR-017 / Edge Case: alice has declared nothing, so there is nothing to answer.
  test "a proposal to someone with no active wish is rejected" do
    proposal = LockerSwapProposal.new(requester: users(:bob), recipient: users(:alice))

    assert_not proposal.valid?
    assert_includes proposal.errors[:recipient], "is not looking for a locker right now"
  end

  # FR-003: their locker is already committed to the swap under way.
  test "a proposal to someone already in an exchange is rejected" do
    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:carol), status: :accepted)

    proposal = LockerSwapProposal.new(requester: users(:bob), recipient: users(:carol))

    assert_not proposal.valid?
    assert_includes proposal.errors[:recipient], "already has an exchange in progress"
  end

  # FR-004: and symmetrically — the sender's own locker is committed too.
  test "a user already in an exchange cannot propose to anyone else" do
    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:carol), status: :accepted)

    proposal = LockerSwapProposal.new(requester: users(:dave), recipient: users(:bob))

    assert_not proposal.valid?
    assert_includes proposal.errors[:base], "You already have an exchange in progress."
  end

  # FR-018: alice_pending_to_bob is still undecided, so a second one is noise.
  test "a second pending proposal to the same person is rejected" do
    proposal = LockerSwapProposal.new(requester: users(:alice), recipient: users(:bob))

    assert_not proposal.valid?
    assert_includes proposal.errors[:recipient], "already has a pending proposal from you"
  end

  # FR-018 under concurrency: two submissions can both pass the validation above
  # before either commits, so the partial unique index is the real guarantee.
  # insert_all! rather than insert_all: the plain form asks the database to skip
  # the conflicting row, which would hide the rejection being asserted.
  test "the database refuses a second pending proposal for the same pair" do
    assert_raises ActiveRecord::RecordNotUnique do
      LockerSwapProposal.insert_all!([
        {
          requester_id: users(:alice).id, recipient_id: users(:bob).id, status: 0,
          created_at: Time.current, updated_at: Time.current
        }
      ])
    end
  end

  # FR-003 / FR-004 under concurrency: one user, two accepts landing at once.
  test "the database refuses a second exchange in progress for the same user" do
    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:carol), status: :accepted)

    assert_raises ActiveRecord::RecordNotUnique do
      LockerSwapProposal.insert_all!([
        {
          requester_id: users(:dave).id, recipient_id: users(:bob).id, status: 1,
          created_at: Time.current, updated_at: Time.current
        }
      ])
    end
  end

  # FR-019: withdrawing is the requester's own call, up until a decision lands.
  test "withdrawing a pending proposal marks it withdrawn and dates the decision" do
    proposal = locker_swap_proposals(:alice_pending_to_bob)

    assert proposal.withdraw!

    assert_predicate proposal.reload, :withdrawn?
    assert_not_nil proposal.decided_at
  end

  # FR-020: withdrawn is final — there is nothing left to withdraw.
  test "a proposal that is no longer pending cannot be withdrawn" do
    proposal = locker_swap_proposals(:alice_withdrawn_to_carol)

    assert_not proposal.withdraw!

    assert_predicate proposal.reload, :withdrawn?
    assert_equal 2.days.ago.to_date, proposal.decided_at.to_date
  end

  # FR-006 / Acceptance Scenario 1: accepting is what starts the exchange.
  test "accepting a proposal marks the exchange in progress and dates the decision" do
    proposal = locker_swap_proposals(:alice_pending_to_bob)

    assert proposal.accept!

    assert_predicate proposal.reload, :accepted?
    assert_not_nil proposal.decided_at
    assert LockerSwapProposal.in_progress_for?(users(:alice))
    assert LockerSwapProposal.in_progress_for?(users(:bob))
  end

  # 005 FR-001/FR-002: what the locker-profile lock asks. Broader than
  # in_progress_for? on purpose — a proposal still waiting for an answer is just
  # as much a commitment of these values as one already accepted.
  test "a user is active while any proposal of theirs is pending or accepted" do
    assert LockerSwapProposal.active_for?(users(:alice)), "requester of a pending proposal"
    assert LockerSwapProposal.active_for?(users(:bob)), "recipient of a pending proposal"

    # dave and carol are party only to resolved proposals: declined, withdrawn.
    assert_not LockerSwapProposal.active_for?(users(:dave))
    assert_not LockerSwapProposal.active_for?(users(:carol))

    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:carol), status: :accepted)

    assert LockerSwapProposal.active_for?(users(:dave)), "requester of an accepted proposal"
    assert LockerSwapProposal.active_for?(users(:carol)), "recipient of an accepted proposal"
  end

  # FR-003 / FR-004: two proposals involving the same person can both be pending
  # and both be accepted a moment apart. The second accept has to lose, so the
  # check is made again here rather than only when the proposal was created.
  test "accepting is refused when a party has meanwhile entered another exchange" do
    proposal = locker_swap_proposals(:alice_pending_to_bob)
    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob), status: :accepted)

    assert_not proposal.accept!

    assert_predicate proposal.reload, :pending?
  end

  # FR-011 / Edge Cases: neither party can pursue a competing swap now, so every
  # other proposal either of them was part of is declined for them, in whichever
  # role they held it — and each affected requester is owed the news (FR-007).
  test "accepting declines every other pending proposal either party was part of" do
    same_recipient = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob))
    other_role = LockerSwapProposal.create!(requester: users(:bob), recipient: users(:carol))
    untouched = locker_swap_proposals(:dave_declined_to_carol)

    locker_swap_proposals(:alice_pending_to_bob).accept!

    assert_predicate same_recipient.reload, :declined?
    assert_predicate other_role.reload, :declined?
    [ same_recipient, other_role ].each do |auto_declined|
      assert_not_nil auto_declined.decided_at
      assert_predicate auto_declined.decline_comment, :present?
      assert_nil auto_declined.requester_acknowledged_at
    end

    # A proposal already settled is left exactly as it was.
    assert_equal "Found another swap", untouched.reload.decline_comment
  end

  # FR-007 / FR-008 / Acceptance Scenarios 2 and 3.
  test "declining a proposal records the decision and the comment" do
    proposal = locker_swap_proposals(:alice_pending_to_bob)

    assert proposal.decline!("Your floor is too far from mine")

    assert_predicate proposal.reload, :declined?
    assert_not_nil proposal.decided_at
    assert_equal "Your floor is too far from mine", proposal.decline_comment
    assert_nil proposal.requester_acknowledged_at
  end

  # Acceptance Scenario 4: the comment is optional and its absence is not an error.
  test "declining without a comment is recorded just the same" do
    proposal = locker_swap_proposals(:alice_pending_to_bob)

    assert proposal.decline!

    assert_predicate proposal.reload, :declined?
    assert_nil proposal.decline_comment
  end

  # FR-010 / Acceptance Scenario 5: one decision per proposal, whichever it was.
  test "a proposal that has already been decided cannot be decided again" do
    decided = locker_swap_proposals(:dave_declined_to_carol)

    assert_not decided.accept!
    assert_not decided.decline!("changed my mind")

    assert_predicate decided.reload, :declined?
    assert_equal "Found another swap", decided.decline_comment
  end

  # FR-013 / User Story 4, Acceptance Scenarios 1 and 2: the whole point of the
  # feature — the lockers actually change hands. Both of these two hold a locker,
  # which is the case that has to get past the unique index on locker_number.
  test "confirming an exchange swaps both users' floor and locker" do
    proposal = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob),
                                          status: :accepted)

    assert proposal.confirm!

    assert_equal [ "3", "B12" ], [ users(:dave).reload.floor, users(:dave).locker_number ]
    assert_equal [ "4", "D07" ], [ users(:bob).reload.floor, users(:bob).locker_number ]
    assert_predicate proposal.reload, :completed?
    assert_not_nil proposal.completed_at
  end

  # Edge Case: the need both of them had is now settled, so neither wish is an
  # open invitation any more — the rows go, as cancelling one would.
  test "confirming an exchange removes both parties' wishes" do
    proposal = LockerSwapProposal.create!(requester: users(:carol), recipient: users(:bob),
                                          status: :accepted)

    proposal.confirm!

    assert_nil users(:carol).reload.locker_wish
    assert_nil users(:bob).reload.locker_wish
  end

  # research.md: floor and locker already tolerate nil — having no locker is an
  # ordinary state (002), and swapping with someone who has none just moves that
  # state to the other side.
  test "confirming an exchange works when one side has no locker at all" do
    # alice is the one fixture user with neither floor nor locker, and her
    # proposal to bob is already on file — so accept that one rather than
    # opening a second to the same person, which FR-018 forbids.
    proposal = locker_swap_proposals(:alice_pending_to_bob)
    proposal.accept!

    assert proposal.confirm!

    assert_equal [ "3", "B12" ], [ users(:alice).reload.floor, users(:alice).locker_number ]
    assert_nil users(:bob).reload.floor
    assert_nil users(:bob).locker_number
  end

  # 005 FR-009: the four snapshot columns, and what the history reads off them.

  def snapshot_of(proposal)
    proposal.reload.slice(:requester_floor_at_resolution, :requester_locker_number_at_resolution,
                          :recipient_floor_at_resolution, :recipient_locker_number_at_resolution)
            .values
  end

  test "withdrawing records both sides' locker details as they stood" do
    proposal = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:carol))

    proposal.withdraw!

    assert_equal [ "4", "D07", "2", nil ], snapshot_of(proposal)
  end

  test "declining records both sides' locker details alongside the comment" do
    proposal = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:carol))

    proposal.decline!("No thanks")

    assert_equal [ "4", "D07", "2", nil ], snapshot_of(proposal)
    assert_equal "No thanks", proposal.reload.decline_comment
  end

  # FR-011's cascade settles proposals in bulk, each with its own two parties —
  # so the details recorded have to be the ones on that row, not the accepted
  # proposal's. bob's "3"/"B12" appearing here would mean the wrong row was read.
  test "an automatically declined proposal records its own parties' details" do
    competing = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:carol))
    LockerSwapProposal.create!(requester: users(:bob), recipient: users(:carol)).accept!

    assert_predicate competing.reload, :declined?
    assert_equal [ "4", "D07", "2", nil ], snapshot_of(competing)
  end

  # The whole point of the timing: confirm! swaps the two users' details, so read
  # a moment later it would record each side as holding what it just gave away.
  test "confirming records the details as they were before the swap" do
    proposal = LockerSwapProposal.create!(requester: users(:bob), recipient: users(:carol),
                                          status: :accepted)

    proposal.confirm!

    assert_equal [ "3", "B12", "2", nil ], snapshot_of(proposal)
    assert_equal [ "2", nil ], [ users(:bob).reload.floor, users(:bob).locker_number ]
  end

  # FR-006: still an offer, so it reads as one — and off the live details, which
  # 005's lock is holding still for exactly as long as this state lasts.
  test "an undecided proposal summarises what is being offered" do
    proposal = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:carol))

    assert_match(/\AProposed/, proposal.floor_and_locker_summary)
    assert_includes proposal.floor_and_locker_summary, "Floor 4, locker D07"
    assert_includes proposal.floor_and_locker_summary, "Floor 2, no locker assigned"
    assert_nil proposal.requester_floor_at_resolution
  end

  # FR-006: nothing changed hands, so neither did the wording.
  test "a declined or withdrawn proposal still summarises it as an offer" do
    declined = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:carol))
    declined.decline!
    withdrawn = LockerSwapProposal.create!(requester: users(:bob), recipient: users(:carol))
    withdrawn.withdraw!

    assert_match(/\AProposed/, declined.floor_and_locker_summary)
    assert_includes declined.floor_and_locker_summary, "Floor 4, locker D07"
    assert_match(/\AProposed/, withdrawn.floor_and_locker_summary)
  end

  # FR-006: and here it did, so the summary says so — from the record, since the
  # users' own details have since moved.
  test "a completed exchange summarises what actually changed hands" do
    proposal = LockerSwapProposal.create!(requester: users(:bob), recipient: users(:carol),
                                          status: :accepted)
    proposal.confirm!

    assert_match(/\AExchanged/, proposal.floor_and_locker_summary)
    assert_includes proposal.floor_and_locker_summary, "Floor 3, locker B12"
    assert_includes proposal.floor_and_locker_summary, "Floor 2, no locker assigned"
  end

  # Edge Case: having no locker is an ordinary state (002), and it reads the same
  # way here as it does on the homepage, whether read live or from the record.
  test "a side with no locker is described the same way live and from the record" do
    proposal = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:carol))

    assert_includes proposal.floor_and_locker_summary, "no locker assigned"

    proposal.decline!

    assert_includes proposal.floor_and_locker_summary, "no locker assigned"
  end

  # The reason the columns exist at all: once the lock lifts, these two are free
  # to change their details again, and this entry must go on describing the
  # exchange that was actually proposed.
  test "a resolved proposal's summary does not follow later changes to either profile" do
    proposal = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:carol))
    proposal.decline!
    summary = proposal.floor_and_locker_summary

    users(:dave).update!(floor: "9", locker_number: "D99")

    assert_equal summary, proposal.reload.floor_and_locker_summary
    assert_includes proposal.floor_and_locker_summary, "Floor 4, locker D07"
  end

  # FR-014 / Acceptance Scenario 4: an exchange is completed once. Anything that
  # is not in progress has nothing to confirm.
  test "only an exchange in progress can be confirmed" do
    assert_not locker_swap_proposals(:alice_pending_to_bob).confirm!
    assert_not locker_swap_proposals(:dave_declined_to_carol).confirm!

    completed = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob),
                                           status: :accepted)
    completed.confirm!

    assert_not completed.confirm!
    assert_equal [ "3", "B12" ], [ users(:dave).reload.floor, users(:dave).locker_number ]
  end
end
