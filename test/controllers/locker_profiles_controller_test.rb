require "test_helper"

# Covers 002 spec.md FR-011 at the layer the uniqueness validation cannot reach:
# two submissions can both pass validation before either commits, leaving the
# database's unique index as the only thing standing between them. The user must
# not be able to tell that race apart from an ordinary "locker already taken".
class LockerProfilesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "a locker number that loses the database race is reported like any other conflict" do
    sign_in users(:alice)

    with_save_losing_the_race do
      patch locker_profile_path, params: { user: { floor: "4", locker_number: "D01" } }
    end

    assert_response 422
    assert_includes response.body, "Locker number is not available"
    assert_nil users(:alice).reload.locker_number
  end

  # 006 FR-002: the same number one floor up is a different locker, and the save
  # path has to let it through — this is the case 002's rule wrongly refused.
  test "a locker number already held on another floor is accepted" do
    sign_in users(:carol)

    patch locker_profile_path, params: { user: { floor: "9", locker_number: users(:bob).locker_number } }

    assert_redirected_to root_path
    assert_equal [ "9", "B12" ], [ users(:carol).reload.floor, users(:carol).locker_number ]
  end

  # 006 FR-003: the same number on the same floor is the same locker. Refused —
  # and without naming who holds it, which is the half of the rule that is about
  # the other account rather than about carol.
  test "a locker number already held on the same floor is refused without naming the holder" do
    sign_in users(:carol)

    patch locker_profile_path,
          params: { user: { floor: users(:bob).floor, locker_number: users(:bob).locker_number } }

    assert_response 422
    assert_includes response.body, "not available on that floor"
    assert_not_includes response.body, users(:bob).email
    assert_nil users(:carol).reload.locker_number
  end

  # 005 FR-001/FR-003: bob is the recipient of alice_pending_to_bob, so his
  # details are spoken for until he answers it. The refusal has to say so, not
  # simply fail.
  test "changing a saved floor is refused while a swap proposal is active" do
    sign_in users(:bob)

    patch locker_profile_path, params: { user: { floor: "9", locker_number: "B12" } }

    assert_response 422
    assert_includes response.body, "active swap proposal"
    assert_equal "3", users(:bob).reload.floor
  end

  # FR-001/FR-002: alice has nothing on file yet, and an active proposal of her
  # own. Holding her to a value she never set would leave her no way out.
  test "a first-time floor and locker number are saved even with an active proposal" do
    sign_in users(:alice)

    patch locker_profile_path, params: { user: { floor: "5", locker_number: "C01" } }

    assert_redirected_to root_path
    assert_equal [ "5", "C01" ], [ users(:alice).reload.floor, users(:alice).locker_number ]
  end

  # The lock is the exception, not the new rule: dave's only proposal is decided,
  # so 002's edit path is untouched for him.
  test "changing a saved floor still works with no active proposal" do
    sign_in users(:dave)

    patch locker_profile_path, params: { user: { floor: "9", locker_number: "D07" } }

    assert_redirected_to root_path
    assert_equal "9", users(:dave).reload.floor
  end

  private

    # No mocking gem is bundled (see Gemfile), so the stub is hand-rolled. The
    # ensure block is what keeps it from leaking into the rest of the suite.
    def with_save_losing_the_race
      User.class_eval do
        alias_method :save_without_forced_conflict, :save
        def save(**) = raise(ActiveRecord::RecordNotUnique, "forced by test")
      end

      yield
    ensure
      User.class_eval do
        remove_method :save
        alias_method :save, :save_without_forced_conflict
        remove_method :save_without_forced_conflict
      end
    end
  # 030 FR-005: refused at the model, so a request built by hand is refused too.
  test "a floor outside the site's list is refused even when submitted directly" do
    SiteFloorList.current.update!(floors_text: "0, 1, 2, 3")
    sign_in users(:alice)

    patch locker_profile_path, params: { user: { floor: "7", locker_number: "" } }

    assert_response :unprocessable_entity
    assert_nil users(:alice).reload.floor
  end
  # 030 FR-013: refused at the model, so a request built by hand is refused too.
  test "a locker number that does not match the format is refused even when submitted directly" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}")
    sign_in users(:carol)

    patch locker_profile_path, params: { user: { floor: users(:carol).floor, locker_number: "42" } }

    assert_response :unprocessable_entity
    assert_nil users(:carol).reload.locker_number
  end

  # 031 FR-010: refused at the model, so a request built by hand is refused too.
  test "an undeclared locker is refused even when submitted directly, once the map is in use" do
    Zone.create!(floor: "2", name: "Aile Nord").locker_map_entries.create!(locker_number: "203")
    sign_in users(:alice)

    patch locker_profile_path, params: { user: { floor: "2", locker_number: "999" } }

    assert_response :unprocessable_entity
    assert_nil users(:alice).reload.locker_number
  end

  test "a declared locker is accepted" do
    Zone.create!(floor: "2", name: "Aile Nord").locker_map_entries.create!(locker_number: "203")
    sign_in users(:alice)

    patch locker_profile_path, params: { user: { floor: "2", locker_number: "203" } }

    assert_redirected_to root_path
    assert_equal "203", users(:alice).reload.locker_number
  end
end
