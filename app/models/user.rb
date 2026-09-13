class User < ApplicationRecord
  # :database_authenticatable — bcrypt password storage + email/password login (FR-004, FR-006)
  # :registerable            — self-service signup (FR-001, FR-003)
  # :rememberable            — persistent session across browser restarts, 30 days (FR-007)
  # :lockable                — lock after 5 consecutive failures for 15 minutes (FR-011)
  # :validatable             — email format/uniqueness and the 8-character password minimum (FR-002)
  devise :database_authenticatable, :registerable,
         :rememberable, :lockable, :validatable

  # 003: the locker this user is looking for, once they have declared a wish.
  # A wish cannot outlive the account that declared it.
  has_one :locker_wish, dependent: :destroy

  # 004: the two sides of a swap proposal. Both foreign keys point back here, so
  # each association has to name its own; neither can outlive the account.
  has_many :sent_swap_proposals, class_name: "LockerSwapProposal",
           foreign_key: :requester_id, dependent: :destroy, inverse_of: :requester
  has_many :received_swap_proposals, class_name: "LockerSwapProposal",
           foreign_key: :recipient_id, dependent: :destroy, inverse_of: :recipient

  # "No locker" must reach the database as NULL, never "": a unique index treats
  # NULLs as distinct, but two empty strings would collide (002 FR-002, FR-011).
  normalizes :locker_number, with: ->(value) { value.blank? ? nil : value }

  # Both rules are scoped to :locker_profile_update so they only apply on the
  # locker-profile save path. A blanket validation would block every other save
  # for a user who has not set a floor yet — including Devise's own account
  # update — which is not what "the floor is required" means here (002 FR-007).
  validates :floor, presence: true, on: :locker_profile_update
  # The values as they are on file. While a rejected edit is being re-displayed
  # the attributes hold the input being corrected, so anything reporting what is
  # actually saved has to read past them.
  def saved_floor = floor_in_database
  def saved_locker_number = locker_number_in_database

  # Says the locker is spoken for without identifying who holds it (002 FR-011).
  # Names the floor, because that is the whole scope of the refusal: the same
  # number is free to take one floor up (006 FR-003).
  # The controller reuses it for the same conflict caught by the unique index.
  LOCKER_NUMBER_TAKEN_MESSAGE =
    "is not available on that floor — another account already has this locker".freeze

  # 006 FR-001: the pair is the key. A number identifies a locker only once you
  # know the floor it is on, so the same one on two floors is two lockers.
  # allow_nil is load-bearing: the uniqueness validator does not skip nil on its
  # own, so without it the second user with no locker is rejected as a duplicate.
  validates :locker_number, uniqueness: { scope: :floor, message: LOCKER_NUMBER_TAKEN_MESSAGE },
            allow_nil: true, on: :locker_profile_update

  # 005 FR-003: says why the field is refused, so the restriction reads as a
  # state the account is in rather than as something wrong with the input.
  LOCKED_BY_SWAP_MESSAGE = "cannot be changed while you have an active swap proposal".freeze

  # 005 FR-001, FR-002: a proposal is an offer made on these exact values, so
  # neither side can move them out from under the other while one is outstanding.
  validate :locker_details_held_by_active_swap, on: :locker_profile_update

  private

    # Only a value already on file is held: someone who has never recorded a
    # floor or a locker number is still asked for it, since an offer cannot have
    # been made on a value that does not exist (FR-001, FR-002). The query is
    # asked only when there is a change to refuse.
    def locker_details_held_by_active_swap
      changing = { floor: floor_changed? && floor_was.present?,
                   locker_number: locker_number_changed? && locker_number_was.present? }
      return if changing.values.none?
      return unless LockerSwapProposal.active_for?(self)

      changing.each { |attribute, changed| errors.add(attribute, LOCKED_BY_SWAP_MESSAGE) if changed }
    end
end
