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

  # 002 FR-011.
  test "rejects a locker number another account already holds" do
    user = users(:carol)
    user.locker_number = users(:bob).locker_number

    assert_not user.valid?(:locker_profile_update)
    assert_includes user.errors[:locker_number], User::LOCKER_NUMBER_TAKEN_MESSAGE
  end

  test "stores a blank locker number as nil rather than an empty string" do
    user = users(:carol)
    user.locker_number = "   "

    assert user.save(context: :locker_profile_update)
    assert_nil user.reload.locker_number
  end

  # 002 FR-011/SC-005: the unique index — not the validation above — is what holds
  # under concurrency, so it has to reject a duplicate on its own.
  test "the database rejects a duplicate locker number even when validation is skipped" do
    user = users(:carol)
    user.locker_number = users(:bob).locker_number

    assert_raises ActiveRecord::RecordNotUnique do
      user.save(validate: false)
    end
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
end
