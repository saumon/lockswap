require "test_helper"

# Covers 003 spec.md FR-003 and FR-007 at the model layer.
class LockerWishTest < ActiveSupport::TestCase
  # FR-007 / Edge Case: a floor of spaces is a missing floor, not a floor.
  test "a wish needs a floor that is not blank" do
    wish = LockerWish.new(user: users(:alice), floor: "   ")

    assert_not wish.valid?
    assert_includes wish.errors[:floor], "can't be blank"
  end

  test "a wish cannot exist without the user who declared it" do
    wish = LockerWish.new(floor: "4")

    assert_not wish.valid?
    assert_includes wish.errors[:user], "must exist"
  end

  # FR-003 / SC-003: the controller looks for an existing wish before writing, but
  # two declares for one account can both pass that lookup before either commits.
  # The unique index is the real guarantee, so prove it rejects a row that skips
  # validation entirely.
  test "the database refuses a second wish for a user who already has one" do
    # insert_all! rather than insert_all: the plain form asks the database to skip
    # a conflicting row, which would hide the very rejection being asserted here.
    assert_raises ActiveRecord::RecordNotUnique do
      LockerWish.insert_all!([
        { user_id: users(:carol).id, floor: "9", created_at: Time.current, updated_at: Time.current }
      ])
    end
  end
end
