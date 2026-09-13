# One user's request to swap lockers with another (004 FR-001). Unlike a
# LockerWish — one person's standing declaration — a proposal has two parties in
# two distinct roles and a lifecycle of its own, which is why it gets its own
# table rather than a column on either existing model.
class LockerSwapProposal < ApplicationRecord
  belongs_to :requester, class_name: "User"
  belongs_to :recipient, class_name: "User"

  # Mutually exclusive by construction: separate booleans would allow
  # combinations like declined and completed at once. "accepted" is the spec's
  # "exchange in progress".
  enum :status, { pending: 0, accepted: 1, declined: 2, withdrawn: 3, completed: 4 }

  # All four rules decide whether a proposal may be *created*; none of them
  # re-applies to the row afterwards, when only its status changes. Scoping them
  # to :create is what lets accept!/decline!/confirm! save a row whose recipient
  # has since been taken off the market — by this very exchange.
  validate :recipient_is_not_the_requester, on: :create
  validate :recipient_is_looking_for_a_locker, on: :create
  validate :neither_party_is_already_in_an_exchange, on: :create
  validate :no_pending_proposal_already_stands, on: :create

  # Said on every proposal this one settles on its parties' behalf, so the people
  # affected are told why rather than finding it simply gone (FR-011).
  AUTO_DECLINE_COMMENT =
    "Automatically declined — one of you started another exchange.".freeze

  # FR-019: the requester's own call, right up until a decision lands. Returns
  # false rather than raising on a proposal that has already moved on, so a
  # caller can treat "too late" as an ordinary outcome (FR-020).
  def withdraw!
    return false unless pending?

    update!(status: :withdrawn, decided_at: Time.current)
  end

  # FR-006: the recipient's yes. Two proposals sharing a party can be accepted a
  # moment apart, so eligibility is re-checked here and not only at creation —
  # the partial unique indexes each see one role at a time, and this crosses both.
  # Everything else either party had open is then settled in the same
  # transaction, so nobody is left holding a proposal that can no longer go
  # anywhere (FR-011).
  def accept!
    return false unless pending?

    transaction do
      return false if self.class.in_progress_for?(requester) || self.class.in_progress_for?(recipient)

      update!(status: :accepted, decided_at: Time.current)
      decline_competing_proposals
    end

    true
  end

  # FR-007, FR-008: the recipient's no, with their reasons if they gave any.
  # requester_acknowledged_at stays nil, which is what puts it on the requester's
  # homepage the next time they look (FR-009).
  def decline!(comment = nil)
    return false unless pending?

    update!(status: :declined, decided_at: Time.current, decline_comment: comment.presence)
  end

  # FR-013: the exchange has happened in the building, so the records catch up —
  # the two lockers change hands and both wishes are satisfied. Only the recipient
  # gets here (the controller scopes it), and only once (FR-012, FR-014).
  def confirm!
    return false unless accepted?

    transaction do
      swap_lockers
      update!(status: :completed, completed_at: Time.current)
      requester.locker_wish&.destroy
      recipient.locker_wish&.destroy
    end

    true
  end

  # Whether this user is already committed to an exchange, in either role
  # (FR-003, FR-004). Asked before creating a proposal and again inside accept!,
  # since the two partial unique indexes can each only see one role at a time.
  #
  # Asked as two queries rather than one OR: SQLite 3.53's planner faults
  # ("internal query planner error") when it tries to OR-optimise a scan of this
  # table against its partial indexes. Both roles are single indexed lookups.
  def self.in_progress_for?(user)
    accepted.exists?(requester_id: user.id) || accepted.exists?(recipient_id: user.id)
  end

  # Everyone currently committed to an exchange. The wish list reads this to
  # stop showing wishes that are no longer open invitations (Edge Cases).
  def self.in_progress_user_ids
    accepted.pluck(:requester_id, :recipient_id).flatten.uniq
  end

  private

    # locker_number is unique across users, and the check is immediate, so the
    # two rows cannot simply be written over each other: for the moment between
    # the two updates both would hold the same locker and the second would be
    # rejected. The requester's side is vacated first so that never happens.
    #
    # Plain update!, not update_columns: 002's presence and uniqueness rules are
    # scoped to :locker_profile_update and so do not fire here, which is what
    # lets a swap move a nil floor onto someone who had one.
    def swap_lockers
      requester_details = [ requester.floor, requester.locker_number ]
      recipient_details = [ recipient.floor, recipient.locker_number ]

      requester.update!(floor: nil, locker_number: nil)
      recipient.update!(floor: requester_details.first, locker_number: requester_details.last)
      requester.update!(floor: recipient_details.first, locker_number: recipient_details.last)
    end

    # Every other pending proposal touching either party, in either role — a
    # third party who proposed to one of them is as stuck as they are. Updated in
    # bulk: this is one statement regardless of how many there are (Principle IV),
    # and none of them needs the validations, which only govern creation.
    def decline_competing_proposals
      parties = [ requester_id, recipient_id ]
      competing_ids = self.class.pending.where(requester_id: parties).pluck(:id) |
                      self.class.pending.where(recipient_id: parties).pluck(:id)
      competing_ids -= [ id ]
      return if competing_ids.empty?

      self.class.where(id: competing_ids).update_all(
        status: self.class.statuses[:declined],
        decided_at: Time.current,
        decline_comment: AUTO_DECLINE_COMMENT,
        requester_acknowledged_at: nil,
        updated_at: Time.current
      )
    end

    # FR-002.
    def recipient_is_not_the_requester
      errors.add(:recipient, "cannot be yourself") if recipient_id == requester_id
    end

    # FR-017: a wish is what makes someone an eligible recipient, so one
    # cancelled between the list being drawn and this submission lands here.
    def recipient_is_looking_for_a_locker
      return if recipient.blank? || recipient.locker_wish.present?

      errors.add(:recipient, "is not looking for a locker right now")
    end

    # FR-003 and FR-004: one locker cannot be promised to two swaps at once, so
    # the block applies to both parties, whichever role they hold in the other
    # exchange.
    def neither_party_is_already_in_an_exchange
      if requester.present? && self.class.in_progress_for?(requester)
        errors.add(:base, "You already have an exchange in progress.")
      end

      return if recipient.blank? || !self.class.in_progress_for?(recipient)

      errors.add(:recipient, "already has an exchange in progress")
    end

    # FR-018: only while the earlier one is still undecided. Once it is declined
    # or withdrawn, asking again is allowed (Edge Case).
    def no_pending_proposal_already_stands
      return if requester.blank? || recipient.blank?
      return unless self.class.pending.exists?(requester_id: requester_id, recipient_id: recipient_id)

      errors.add(:recipient, "already has a pending proposal from you")
    end
end
