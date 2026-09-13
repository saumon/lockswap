# One user's declared search for a locker on a particular floor (003 FR-001).
# At most one per user (FR-003): the unique index on user_id is the real guarantee,
# since the controller's "do they already have one" lookup cannot be race-safe on
# its own. Cancelling removes the row outright rather than flagging it.
class LockerWish < ApplicationRecord
  belongs_to :user

  # Rails treats a whitespace-only string as blank, so presence alone already
  # rejects "   " — no separate trimming step is needed (FR-007).
  validates :floor, presence: true

  # The floor as it is on file. While a rejected change is being re-displayed the
  # attribute holds the input being corrected, so anything reporting what is
  # actually saved has to read past it.
  def saved_floor = floor_in_database
end
