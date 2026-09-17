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

  # 013 FR-001: the first account ever registered is the site's administrator.
  # Assigned here rather than derived on read, because a derived answer would move
  # to the next-oldest account the moment this one was deleted — which FR-011
  # forbids: deleting the administrator leaves the site with none, not a successor.
  #
  # The assignment is unconditional rather than `= true if ...`, so this is the
  # only thing that can ever set the flag: an explicit `admin: true` passed to
  # create is overwritten here, and there is no path through Active Record that
  # mints a second administrator (FR-002).
  #
  # before_create, so an update never revisits it. exists? rather than a count —
  # the question is whether anybody is already here, not how many.
  before_create :claim_administrator_if_first

  # 013 FR-002, research.md R2: the index is what actually guarantees one
  # administrator, so this is where losing to it is handled.
  #
  # Two signups on an empty site can both come out of claim_administrator_if_first
  # holding the flag; one INSERT then wins and the other is rejected. The loser
  # still signed up — losing a race is not a signup failure — so the save is
  # retried, and the callback, re-reading a table that now has the winner in it,
  # hands the retry admin: false on its own.
  #
  # Only this conflict is caught: an email or locker-number collision is a real
  # refusal with a message for the user, and must keep raising. The retry is not
  # itself rescued, so a second failure propagates rather than looping.
  #
  # save and not save!, because signup reaches this through Devise's
  # `resource.save`; nothing in the application creates an account with save!.
  def save(**options, &block)
    super
  rescue ActiveRecord::RecordNotUnique => error
    raise unless lost_the_administrator_race?(error)

    super
  end

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

    # 013 FR-002: this runs before the row is inserted, so two signups landing
    # together can both find the site empty and both try to claim the flag. The
    # partial unique index is what actually settles that race; see #save.
    def claim_administrator_if_first
      self.admin = !User.exists?
    end

    # Was the rejected write this record's attempt to claim the administrator
    # flag, rather than a genuine collision on email or on a locker?
    #
    # Matched on the index as well as the column: SQLite names the column in the
    # message ("users.admin") and other adapters name the index, and this should
    # not quietly stop working if the database under it ever changes.
    ADMINISTRATOR_INDEX_CONFLICT = /users\.admin\b|index_users_on_admin/

    def lost_the_administrator_race?(error)
      admin? && error.message.match?(ADMINISTRATOR_INDEX_CONFLICT)
    end

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
