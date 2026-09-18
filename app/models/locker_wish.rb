# One user's declared search for a locker on a particular floor (003 FR-001).
# At most one per user (FR-003): the unique index on user_id is the real guarantee,
# since the controller's "do they already have one" lookup cannot be race-safe on
# its own. Cancelling removes the row outright rather than flagging it.
class LockerWish < ApplicationRecord
  belongs_to :user

  # Rails treats a whitespace-only string as blank, so presence alone already
  # rejects "   " — no separate trimming step is needed (FR-007).
  validates :floor, presence: true

  # 003 FR-011/FR-012, extracted from the controller by 017: every wish on offer,
  # oldest declaration first, with its owner loaded so the rows do not each cost a
  # query.
  #
  # 004 Edge Case: someone mid-swap is no longer an open invitation, so their wish
  # drops out until the exchange completes — which destroys the wish outright. The
  # wish row itself is never touched here.
  #
  # It is a scope rather than a line in the controller because 017's two choice
  # queries depend on the same definition of "on offer". Were it inline, the list
  # and the floors offered could drift apart, and a floor would be offered that
  # matched no row.
  scope :active, -> {
    where.not(user_id: LockerSwapProposal.in_progress_user_ids)
      .includes(:user)
      .order(created_at: :asc)
  }

  # 017 FR-010: the floor being looked for. A blank argument is "all floors", so
  # the caller composes both axes unconditionally and neither needs a branch.
  # Matched exactly: floors are free text and the spec rules out normalisation.
  scope :looking_for, ->(floor) { floor.presence ? where(floor: floor) : all }

  # 017 FR-010/FR-012: the floor the wisher currently holds a locker on. Someone
  # who has never saved a floor simply fails to match any value here — it falls
  # out of the join rather than needing a case of its own, which is exactly what
  # FR-012 asks for.
  scope :owner_on_floor, ->(floor) {
    floor.presence ? joins(:user).where(users: { floor: floor }) : all
  }

  # 017 FR-004/FR-005/FR-006: the floors each axis offers. Both read the whole
  # active set rather than a filtered relation, so setting one filter never
  # changes what the other offers. Each returns at most one row per distinct
  # floor, whatever the number of wishes.
  def self.looked_for_floors = active.distinct.pluck(:floor)

  # users.floor is nullable, and FR-005 offers "no floor on which none of them
  # holds a locker" — an absent floor is not a floor, so it is not a choice.
  def self.owner_floors
    active.joins(:user).where.not(users: { floor: [ nil, "" ] }).distinct.pluck("users.floor")
  end

  # The floor as it is on file. While a rejected change is being re-displayed the
  # attribute holds the input being corrected, so anything reporting what is
  # actually saved has to read past it.
  def saved_floor = floor_in_database
end
