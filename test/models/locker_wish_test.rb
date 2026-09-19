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

  # --- 017: the list the filters narrow ---------------------------------------
  #
  # `active` is the rule 003 applied inline in the controller, extracted because
  # three queries now depend on it — the list itself and the two choice queries.
  # Left in the controller they could drift, and a floor would be offered that
  # matched nothing.

  test "active lists every wish whose owner has no exchange in progress" do
    assert_equal LockerWish.count, LockerWish.active.count
  end

  test "active returns wishes oldest declaration first" do
    assert_equal LockerWish.order(created_at: :asc).map(&:id), LockerWish.active.map(&:id)
  end

  # 004 Edge Case: someone mid-swap is no longer an open invitation, whichever
  # side of the exchange they are on.
  # bob and carol both hold a wish, so one accepted proposal between them proves
  # the rule from both sides at once: the requester's wish leaves the list and so
  # does the recipient's.
  test "active drops the wishes of both parties to an exchange in progress" do
    LockerSwapProposal.create!(requester: users(:bob), recipient: users(:carol), status: :accepted)

    listed = LockerWish.active.map(&:user_id)

    assert_not_includes listed, users(:bob).id
    assert_not_includes listed, users(:carol).id
    assert_includes listed, users(:judy).id
    assert_includes listed, users(:karl).id
  end

  # --- 017 FR-004/FR-010: the floor being looked for --------------------------

  test "looking_for matches the wished floor exactly" do
    # 018: henry and iris also wish for floor "3" (they reciprocate with bob),
    # oldest declaration first, same as every other active-scope ordering.
    assert_equal [ users(:karl).id, users(:henry).id, users(:iris).id ],
      LockerWish.active.looking_for("3").map(&:user_id)
  end

  test "looking_for with a blank floor is all floors" do
    [ nil, "", "  " ].each do |blank|
      assert_equal LockerWish.active.count, LockerWish.active.looking_for(blank).count,
        "#{blank.inspect} should not narrow the list"
    end
  end

  test "looking_for a floor nobody wants returns nothing" do
    assert_empty LockerWish.active.looking_for("NOPE")
  end

  test "looked_for_floors offers each wished floor once" do
    assert_equal %w[10 3 5 7], LockerWish.looked_for_floors.sort
  end

  # --- 017 FR-005/FR-012: the floor the wisher is on --------------------------

  test "owner_on_floor matches the wisher's own saved floor" do
    assert_equal [ users(:bob).id ], LockerWish.active.owner_on_floor("3").map(&:user_id)
  end

  # FR-012: never having saved a floor is not a floor, so it matches no selection
  # — and it is not an error either.
  test "owner_on_floor never matches someone who has saved no floor" do
    LockerWish.looked_for_floors.each do |floor|
      assert_not_includes LockerWish.active.owner_on_floor(floor).map(&:user_id), users(:karl).id
    end
  end

  test "owner_on_floor with a blank floor is all floors, including people with none" do
    assert_includes LockerWish.active.owner_on_floor(nil).map(&:user_id), users(:karl).id
  end

  # Only the floors of people who actually hold a wish, and only where one is set:
  # karl has no floor, so nothing stands in for him here. 018: henry and iris are
  # both floor "7", but owner_floors is distinct, so "7" appears only once.
  test "owner_floors offers each wisher's saved floor once, and no blank" do
    assert_equal %w[10 2 3 7], LockerWish.owner_floors.sort
    assert_not_includes LockerWish.owner_floors, nil
  end

  # --- 018 FR-001/FR-002/FR-005: the reciprocal-match predicate ---------------
  #
  # henry_wish (floor "3", henry's own saved floor "7") is the fixture pair
  # exercised throughout: bob's current floor "3" and wish floor "7" reciprocate
  # with it exactly.

  test "reciprocal_match? is true only when both directions hold" do
    assert locker_wishes(:henry_wish).reciprocal_match?("3", "7")
  end

  test "reciprocal_match? is false when only the row's own floor matches the viewer's current floor" do
    refute locker_wishes(:henry_wish).reciprocal_match?("3", "9")
  end

  test "reciprocal_match? is false when only the row owner's saved floor matches the viewer's wish" do
    refute locker_wishes(:henry_wish).reciprocal_match?("9", "7")
  end

  test "reciprocal_match? is false when the viewer's current floor is blank" do
    [ nil, "", "  " ].each do |blank|
      refute locker_wishes(:henry_wish).reciprocal_match?(blank, "7")
    end
  end

  test "reciprocal_match? is false when the viewer's wish floor is blank" do
    [ nil, "", "  " ].each do |blank|
      refute locker_wishes(:henry_wish).reciprocal_match?("3", blank)
    end
  end

  # karl has no saved floor of his own (see users.yml) — "Not set" cannot match
  # anything, however the viewer's own floors are set.
  test "reciprocal_match? is false when the row owner has no saved floor" do
    refute locker_wishes(:karl_wish).reciprocal_match?("3", "anything")
  end

  # Floors are free text everywhere else in this codebase (looking_for,
  # owner_on_floor) — the predicate must not normalize what those don't either.
  test "reciprocal_match? compares floors as exact strings" do
    refute locker_wishes(:henry_wish).reciprocal_match?("03", "7")
    refute locker_wishes(:henry_wish).reciprocal_match?(" 3", "7")
  end
end
