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
  # The controller reuses it for the same conflict caught by the unique index.
  LOCKER_NUMBER_TAKEN_MESSAGE = "is not available — another account already has this locker".freeze

  # allow_nil is load-bearing: the uniqueness validator does not skip nil on its
  # own, so without it the second user with no locker is rejected as a duplicate.
  validates :locker_number, uniqueness: { message: LOCKER_NUMBER_TAKEN_MESSAGE },
            allow_nil: true, on: :locker_profile_update
end
