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
  #
  # 025: kept as a plain frozen string for existing tests that assert against it
  # by name; #decline_competing_proposals below calls I18n.t fresh instead of
  # referencing this constant, so the persisted comment follows the site
  # language at the moment the auto-decline actually happens — see
  # User::LOCKER_NUMBER_TAKEN_MESSAGE's comment for why a frozen constant alone
  # would not be locale-reactive. Like any other decline_comment, once saved it
  # does not retroactively change if the site language changes afterward.
  AUTO_DECLINE_COMMENT =
    "Automatically declined — one of you started another exchange.".freeze

  # FR-019: the requester's own call, right up until a decision lands. Returns
  # false rather than raising on a proposal that has already moved on, so a
  # caller can treat "too late" as an ordinary outcome (FR-020).
  def withdraw!
    return false unless pending?

    update!(status: :withdrawn, decided_at: Time.current, **resolution_snapshot)
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

    update!(status: :declined, decided_at: Time.current, decline_comment: comment.presence,
            **resolution_snapshot)
  end

  # FR-013: the exchange has happened in the building, so the records catch up —
  # the two lockers change hands and both wishes are satisfied. Only the recipient
  # gets here (the controller scopes it), and only once (FR-012, FR-014).
  def confirm!
    return false unless accepted?

    transaction do
      # Read before the swap, not after: a moment later each side holds what it
      # has just given away, and the record would have them the wrong way round
      # (005 FR-009).
      snapshot = resolution_snapshot
      swap_lockers
      update!(status: :completed, completed_at: Time.current, **snapshot)
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

  # 005 FR-005, FR-006: what this proposal was about, said by the system rather
  # than by either party — so the history explains itself on every row, including
  # the ones nobody commented on.
  #
  # An undecided proposal reads live: the lock (FR-001, FR-002) is holding both
  # sides' details still for exactly as long as that state lasts. A settled one
  # reads the record, which is the only account left of what was on the table.
  def floor_and_locker_summary
    sides = locker_sides

    # Joined by a word rather than a ↔: read aloud, a screen reader set to low
    # punctuation verbosity drops the symbol entirely and runs the two sides
    # together (Principle III).
    #
    # 025: I18n.t rather than a frozen constant, since this method's output must
    # follow the site language in effect at call time, not at class-load time.
    verb = completed? ? I18n.t("locker_swap_proposal.floor_and_locker_summary.exchanged") :
                         I18n.t("locker_swap_proposal.floor_and_locker_summary.proposed")
    "#{verb}: #{sides.map { |side| locker_details(*side) }.join(" #{I18n.t('locker_swap_proposal.floor_and_locker_summary.for')} ")}"
  end

  # 032 research.md R3: the same two [floor, locker_number] pairs
  # floor_and_locker_summary turns into one joined sentence, exposed on their
  # own so a caller (the swap-history table) can resolve their zones via
  # LockerMapEntry.zone_names_for without re-deriving this branching itself.
  def locker_sides
    if pending? || accepted?
      [ [ requester.floor, requester.locker_number ], [ recipient.floor, recipient.locker_number ] ]
    else
      [ [ requester_floor_at_resolution, requester_locker_number_at_resolution ],
        [ recipient_floor_at_resolution, recipient_locker_number_at_resolution ] ]
    end
  end

  # Whether this user has anything outstanding at all — waiting for an answer as
  # well as already committed (005 FR-001, FR-002). Deliberately broader than
  # in_progress_for?: a proposal still pending is an offer made on the strength
  # of these locker details, so they are held still from the moment it is sent
  # rather than from the moment it is accepted.
  #
  # Asked as separate exists? calls for the same reason as in_progress_for?.
  def self.active_for?(user)
    pending.exists?(requester_id: user.id) ||
      pending.exists?(recipient_id: user.id) ||
      in_progress_for?(user)
  end

  # Everyone currently committed to an exchange. The wish list reads this to
  # stop showing wishes that are no longer open invitations (Edge Cases).
  def self.in_progress_user_ids
    accepted.pluck(:requester_id, :recipient_id).flatten.uniq
  end

  private

    # One side of the summary, in the same words the homepage uses for the same
    # two states (002 FR-004) — having no locker is ordinary, and reads that way.
    def locker_details(floor, locker_number)
      floor_part = floor.present? ? I18n.t("locker_swap_proposal.floor_and_locker_summary.floor", floor: floor) :
                                     I18n.t("locker_swap_proposal.floor_and_locker_summary.no_floor")
      locker_part = locker_number.present? ? I18n.t("locker_swap_proposal.floor_and_locker_summary.locker", locker_number: locker_number) :
                                              I18n.t("locker_swap_proposal.floor_and_locker_summary.no_locker_assigned")
      "#{floor_part}, #{locker_part}"
    end

    # What both sides' lockers look like right now, ready to be written onto the
    # proposal as it settles (005 FR-009). Taken once, at that moment: afterwards
    # the lock lifts and these two are free to change their details again.
    def resolution_snapshot
      { requester_floor_at_resolution: requester.floor,
        requester_locker_number_at_resolution: requester.locker_number,
        recipient_floor_at_resolution: recipient.floor,
        recipient_locker_number_at_resolution: recipient.locker_number }
    end

    # The floor/locker_number pair is unique (006), and the check is immediate, so
    # the two rows cannot simply be written over each other: for the moment between
    # the two updates both would hold the same pair and the second would be
    # rejected. The requester's side is vacated first so that never happens.
    # Narrowing the key to the pair does not lift that — a swap hands one side's
    # exact pair to the other, which is precisely when the key collides.
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
        decline_comment: I18n.t("locker_swap_proposal.messages.auto_decline_comment"),
        requester_acknowledged_at: nil,
        updated_at: Time.current,
        # Each of these rows has its own two parties, so their details cannot be
        # one value repeated across the update — they are looked up per row,
        # which keeps this a single statement rather than a query each (005
        # FR-009; Principle IV).
        requester_floor_at_resolution: detail_of("requester_id", "floor"),
        requester_locker_number_at_resolution: detail_of("requester_id", "locker_number"),
        recipient_floor_at_resolution: detail_of("recipient_id", "floor"),
        recipient_locker_number_at_resolution: detail_of("recipient_id", "locker_number")
      )
    end

    # Built out of Arel nodes rather than an interpolated string: Arel quotes the
    # column names it is handed, so the correlated subquery cannot be talked into
    # meaning something else even if a caller one day passes something that did
    # not start life as a literal here.
    def detail_of(role_column, detail_column)
      users = User.arel_table
      subquery = users.project(users[detail_column])
                      .where(users[:id].eq(self.class.arel_table[role_column]))

      Arel::Nodes::Grouping.new(subquery.ast)
    end

    # FR-002.
    def recipient_is_not_the_requester
      errors.add(:recipient, I18n.t("locker_swap_proposal.messages.cannot_be_yourself")) if recipient_id == requester_id
    end

    # FR-017: a wish is what makes someone an eligible recipient, so one
    # cancelled between the list being drawn and this submission lands here.
    def recipient_is_looking_for_a_locker
      return if recipient.blank? || recipient.locker_wish.present?

      errors.add(:recipient, I18n.t("locker_swap_proposal.messages.recipient_not_looking"))
    end

    # FR-003 and FR-004: one locker cannot be promised to two swaps at once, so
    # the block applies to both parties, whichever role they hold in the other
    # exchange.
    def neither_party_is_already_in_an_exchange
      if requester.present? && self.class.in_progress_for?(requester)
        errors.add(:base, I18n.t("locker_swap_proposal.messages.requester_already_in_exchange"))
      end

      return if recipient.blank? || !self.class.in_progress_for?(recipient)

      errors.add(:recipient, I18n.t("locker_swap_proposal.messages.recipient_already_in_exchange"))
    end

    # FR-018: only while the earlier one is still undecided. Once it is declined
    # or withdrawn, asking again is allowed (Edge Case).
    def no_pending_proposal_already_stands
      return if requester.blank? || recipient.blank?
      return unless self.class.pending.exists?(requester_id: requester_id, recipient_id: recipient_id)

      errors.add(:recipient, I18n.t("locker_swap_proposal.messages.pending_proposal_already_stands"))
    end
end
