require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "is valid with an email and an 8-character password" do
    user = User.new(email: "new.person@example.com", password: "12345678")

    assert user.valid?, user.errors.full_messages.to_sentence
  end

  # FR-002: email is the account identifier, so it is required.
  test "requires an email" do
    user = User.new(email: "", password: VALID_PASSWORD)

    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "requires a well-formed email" do
    user = User.new(email: "not-an-email", password: VALID_PASSWORD)

    assert_not user.valid?
    assert_includes user.errors[:email], "must look like an email address, for example name@example.com."
  end

  # FR-003: one account per email address.
  test "requires a unique email" do
    user = User.new(email: users(:alice).email, password: VALID_PASSWORD)

    assert_not user.valid?
    assert_includes user.errors[:email], "is already registered. Log in instead, or sign up with a different address."
  end

  test "treats emails as unique case-insensitively" do
    user = User.new(email: users(:alice).email.upcase, password: VALID_PASSWORD)

    assert_not user.valid?
    assert_includes user.errors[:email], "is already registered. Log in instead, or sign up with a different address."
  end

  # FR-002: passwords must be at least 8 characters.
  test "rejects a password shorter than 8 characters" do
    user = User.new(email: "new.person@example.com", password: "1234567")

    assert_not user.valid?
    assert_includes user.errors[:password], "must be at least 8 characters long."
  end

  test "requires a password" do
    user = User.new(email: "new.person@example.com", password: nil)

    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "stores the password as a bcrypt digest, never in plaintext" do
    user = User.create!(email: "new.person@example.com", password: VALID_PASSWORD)

    assert_not_equal VALID_PASSWORD, user.encrypted_password
    assert user.valid_password?(VALID_PASSWORD)
  end

  # 002 FR-007: the floor is required when saving the locker profile, and only
  # then — an account with no floor yet must still be editable in every other way.
  test "requires a floor on the locker profile save path" do
    user = users(:alice)

    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:floor], "can't be blank"
  end

  test "does not require a floor outside the locker profile save path" do
    user = users(:alice)
    user.email = "alice.renamed@example.com"

    assert user.save, user.errors.full_messages.to_sentence
  end

  # 002 FR-002: having no locker is expected, so "no locker" can never collide.
  test "allows several accounts to have no locker number at once" do
    assert_nil users(:alice).locker_number
    user = users(:carol)

    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  # 006 FR-002: carol is on floor 2 and bob on floor 3, so bob's number names a
  # locker she is not asking for. Under 002's rule this was refused; it is the
  # case the feature exists to allow.
  test "allows the same locker number on a different floor" do
    user = users(:carol)
    user.locker_number = users(:bob).locker_number

    assert_not_equal users(:bob).floor, user.floor
    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  # 006 FR-003: same floor, same number — one locker, two claims.
  test "rejects a locker number another account already holds on the same floor" do
    user = users(:carol)
    user.floor = users(:bob).floor
    user.locker_number = users(:bob).locker_number

    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:locker_number], User::LOCKER_NUMBER_TAKEN_MESSAGE
  end

  # 006 FR-004: the holder is not a rival to themselves, so saving the form
  # untouched cannot be a collision.
  test "allows a user to resubmit their own current floor and locker number unchanged" do
    user = users(:dave)
    user.floor = user.floor
    user.locker_number = user.locker_number

    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  test "stores a blank locker number as nil rather than an empty string" do
    user = users(:carol)
    user.locker_number = "   "

    assert user.save(context: :locker_profile_update)
    assert_nil user.reload.locker_number
  end

  # 006 FR-003/SC-003: the unique index — not the validation above — is what holds
  # under concurrency, so it has to reject a duplicate on its own. The floor is
  # set alongside the number because the index now spans the pair: leave carol on
  # her own floor and there is nothing for the database to refuse.
  test "the database rejects a duplicate locker number on the same floor even when validation is skipped" do
    user = users(:carol)
    user.floor = users(:bob).floor
    user.locker_number = users(:bob).locker_number

    assert_raises ActiveRecord::RecordNotUnique do
      user.save(validate: false)
    end
  end

  # 006 FR-007/FR-008: the number is scoped to a floor, so there is no floor to
  # scope it to until one is given. dave and carol are used for the moves below
  # rather than bob: bob is the recipient of alice_pending_to_bob, and 005 holds
  # a saved floor still for as long as a proposal is outstanding, which would
  # answer these tests for a reason that has nothing to do with uniqueness.
  test "rejects saving a locker number when no floor is on file or supplied" do
    user = users(:alice)
    user.locker_number = "Z99"

    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:floor], "can't be blank"
  end

  # 006 FR-005: the pair is re-checked against the floor being moved to, not the
  # one being left.
  test "allows moving a locker number to a different floor when that floor's slot is free" do
    user = users(:dave)
    user.floor = "9"

    assert user.save(context: :locker_profile_update), user.errors.full_messages.to_sentence
    assert_equal [ "9", "D07" ], [ user.reload.floor, user.locker_number ]
  end

  test "rejects moving a locker number onto a floor where another user already holds that same number" do
    holder = users(:carol)
    holder.update!(floor: "9", locker_number: "D07")

    user = users(:dave)
    user.floor = "9"

    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:locker_number], User::LOCKER_NUMBER_TAKEN_MESSAGE
  end

  # 006 FR-006: a pair is held, not owned — once its holder moves off it, it is
  # immediately someone else's to take.
  test "frees a vacated floor-and-locker pair for another user to claim" do
    mover = users(:dave)
    mover.floor = "9"

    assert mover.save(context: :locker_profile_update), mover.errors.full_messages.to_sentence

    claimant = users(:carol)
    claimant.floor = "4"
    claimant.locker_number = "D07"

    assert claimant.valid?(:locker_profile_update), claimant.errors.full_messages.to_sentence
  end

  # 005 FR-001/FR-002: while a swap is being negotiated, these two values are what
  # the other party is answering — so they are held still until it is settled.
  # bob is the recipient of alice_pending_to_bob, which every test loads.
  test "a saved floor cannot be changed while a swap proposal is active" do
    user = users(:bob)
    user.floor = "9"

    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:floor], User::LOCKED_BY_SWAP_MESSAGE
  end

  test "a saved locker number cannot be changed while a swap proposal is active" do
    user = users(:bob)
    user.locker_number = "B99"

    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:locker_number], User::LOCKED_BY_SWAP_MESSAGE
  end

  # Saving the form untouched is not a change, so there is nothing to hold still.
  test "resubmitting the same floor and locker number is allowed while locked" do
    user = users(:bob)
    user.floor = user.floor
    user.locker_number = user.locker_number

    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  # FR-001/FR-002 "already-saved" clarification: a requester need not have a locker
  # of their own (004), so locking the first entry would strand them — with an
  # active proposal they can never withdraw their way out of.
  test "a first-time floor and locker number can still be saved while locked" do
    user = users(:alice)
    user.floor = "5"
    user.locker_number = "C01"

    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  # Acceptance Scenario 3: an accepted exchange holds the values just as a pending
  # proposal does — this is the point where they are about to be swapped for real.
  test "a saved floor cannot be changed while an exchange is in progress" do
    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:carol), status: :accepted)

    requester = users(:dave)
    requester.floor = "9"
    recipient = users(:carol)
    recipient.floor = "9"

    assert_not requester.valid?(:locker_profile_update)
    assert_not recipient.valid?(:locker_profile_update)
  end

  # Acceptance Scenario 5: the hold lasts exactly as long as the proposal does.
  test "the floor can be changed again once the proposal is resolved" do
    locker_swap_proposals(:alice_pending_to_bob).decline!

    user = users(:bob)
    user.floor = "9"

    assert user.valid?(:locker_profile_update), user.errors.full_messages.to_sentence
  end

  # --- 013: the administrator -----------------------------------------------

  # FR-001: on an instance nobody has registered on yet, the first account to be
  # created is the administrator, with no setup step by anyone.
  #
  # destroy_all rather than delete_all: the fixtures hang wishes and proposals off
  # these rows, and the foreign keys would refuse a bare delete. The empty site is
  # the precondition the requirement is written about, so it has to be built here
  # rather than assumed — every test in this file starts with six accounts loaded.
  test "the first account ever created is the administrator" do
    User.destroy_all

    first = User.create!(email: "first@example.com", password: VALID_PASSWORD)

    assert_predicate first, :admin?
  end

  # FR-002: the flag is claimed once, by the first account, and no later signup
  # is a candidate for it however many accounts come and go afterwards.
  test "an account created after the first is not an administrator" do
    User.destroy_all
    User.create!(email: "first@example.com", password: VALID_PASSWORD)

    second = User.create!(email: "second@example.com", password: VALID_PASSWORD)

    assert_not_predicate second, :admin?
  end

  # The ordinary case on a site that is already running: signing up today makes
  # nobody an administrator, whatever the fixtures happen to contain.
  test "signing up on a site that already has accounts grants nothing" do
    user = User.create!(email: "newcomer@example.com", password: VALID_PASSWORD)

    assert_not_predicate user, :admin?
    assert_equal users(:frank), User.find_by(admin: true)
  end

  # FR-002/SC-002: the callback reads the table before the insert, so it cannot be
  # what guarantees a single administrator under concurrency — the index is. This
  # asserts the index on its own, going around the callback with insert_all! the
  # way the locker-number test goes around its validation.
  test "the database refuses a second administrator" do
    assert_raises ActiveRecord::RecordNotUnique do
      User.insert_all!([ {
        email: "rival@example.com",
        encrypted_password: Devise::Encryptor.digest(User, VALID_PASSWORD),
        admin: true, created_at: Time.current, updated_at: Time.current
      } ])
    end
  end

  # FR-002, research.md R2: two signups on an empty site can both read it as
  # empty and both come to the insert claiming the flag. The one that gets there
  # second must still end up with an account — losing a race is not a signup
  # failure — just without the flag. Never both, and never neither.
  test "a signup that loses the race to claim the flag is still saved, without it" do
    User.destroy_all

    loser = User.new(email: "loser@example.com", password: VALID_PASSWORD)
    with_a_rival_claiming_the_flag_mid_save(email: "winner@example.com") do
      assert loser.save, loser.errors.full_messages.to_sentence
    end

    assert_not_predicate loser.reload, :admin?
    assert_equal 1, User.where(admin: true).count
    assert_equal "winner@example.com", User.find_by(admin: true).email
  end

  # FR-011: the flag does not move. Deleting the account that holds it leaves the
  # site with no administrator at all — there is no next-in-line, by design.
  test "deleting the administrator leaves the site with no administrator" do
    users(:frank).destroy

    assert_nil User.find_by(admin: true)
    assert_predicate User.count, :positive?
  end

  # The same rule seen from the other side: an empty administrator slot is not an
  # opening that the next person to sign up walks into.
  test "signing up after the administrator is deleted does not fill the vacancy" do
    users(:frank).destroy

    newcomer = User.create!(email: "newcomer@example.com", password: VALID_PASSWORD)

    assert_not_predicate newcomer, :admin?
    assert_nil User.find_by(admin: true)
  end

  private

    # Stages the state the rescue exists for: another signup has already taken the
    # flag and committed, while this record is still carrying its own claim to it.
    #
    # The winner is written first, and outside the save. Inserting it from inside
    # the loser's save — which is where it lands in wall-clock terms — does not
    # survive: the rejected INSERT rolls that transaction back and takes the
    # winner with it, so the retry finds an empty table and claims the flag after
    # all. In a real race the winner is committed on its own connection and no
    # rollback of the loser's touches it, which is what writing it here reproduces.
    #
    # The lambda then puts the claim back once, standing in for the loser having
    # read the site as empty a moment before the winner committed. Once only: on
    # the retry the callback's own answer is what must stand, and that is the
    # behaviour under test.
    #
    # insert_all! so the winner skips callbacks — through create! it would read
    # the site as empty too and stage a different situation. No mocking gem is
    # bundled (see Gemfile), so this is hand-rolled, as the comparable stub in
    # locker_wishes_controller_test is.
    def with_a_rival_claiming_the_flag_mid_save(email:)
      User.insert_all!([ {
        email: email,
        encrypted_password: Devise::Encryptor.digest(User, VALID_PASSWORD),
        admin: true, created_at: Time.current, updated_at: Time.current
      } ])

      claimed = false
      still_claiming = lambda do
        next if claimed

        claimed = true
        self.admin = true
      end

      User.set_callback(:create, :before, still_claiming)
      yield
    ensure
      User.skip_callback(:create, :before, still_claiming, raise: false)
    end
end
