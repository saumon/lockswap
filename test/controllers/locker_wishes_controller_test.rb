require "test_helper"

# Covers the parts of 003 spec.md that the browser tests cannot reach: the
# concurrent-declare race behind FR-004, and the HTTP verbs FR-013 has to refuse
# to an anonymous visitor.
class LockerWishesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # FR-004: two declares for one account can both pass the already-has-a-wish
  # lookup before either commits, and the unique index then rejects the loser.
  # The loser must still end up doing what a second declare is defined to do —
  # leave one wish holding the floor just submitted — not report a conflict the
  # user cannot act on.
  test "a declare that loses the database race still leaves one wish at the submitted floor" do
    sign_in users(:alice)

    with_the_first_save_losing_the_race(to: users(:alice)) do
      post locker_wish_path, params: { locker_wish: { floor: "4" } }
    end

    assert_redirected_to locker_wishes_path
    assert_equal 1, LockerWish.where(user: users(:alice)).count
    assert_equal "4", users(:alice).reload.locker_wish.floor
  end

  # User Story 1, Acceptance Scenarios 3 and 4 (FR-002): already holding a locker
  # neither blocks a wish nor is changed by one — that is what a swap is. This
  # lived in the browser suite until ChromeDriver's dropped keystrokes and clicks
  # made it the one scenario that would not hold still; here nothing is dropped.
  test "a user who already has a locker can declare a wish and keeps the locker" do
    sign_in users(:dave)

    assert_difference -> { LockerWish.count }, 1 do
      post locker_wish_path, params: { locker_wish: { floor: "9" } }
    end

    assert_redirected_to locker_wishes_path
    assert_equal "9", users(:dave).reload.locker_wish.floor
    assert_equal "D07", users(:dave).locker_number
  end

  # User Story 3, Acceptance Scenario 2: there is simply nothing to cancel.
  test "cancelling with no active wish changes nothing and does not error" do
    sign_in users(:alice)

    assert_no_difference -> { LockerWish.count } do
      delete locker_wish_path
    end

    assert_redirected_to locker_wishes_path
  end

  # FR-013 for the two verbs a browser test cannot issue on its own.
  test "an anonymous visitor cannot declare a wish" do
    assert_no_difference -> { LockerWish.count } do
      post locker_wish_path, params: { locker_wish: { floor: "4" } }
    end

    assert_redirected_to new_user_session_path
  end

  test "an anonymous visitor cannot cancel a wish" do
    assert_no_difference -> { LockerWish.count } do
      delete locker_wish_path
    end

    assert_redirected_to new_user_session_path
  end

  private

    # No mocking gem is bundled (see Gemfile), so the stub is hand-rolled. It plays
    # the request that won the race: by the time the loser's write is rejected, the
    # row really does exist, which is what the rescue path then has to find. Only
    # the first save loses, so the rescue's own update can still go through.
    def with_the_first_save_losing_the_race(to:)
      race_already_lost = false

      LockerWish.class_eval do
        alias_method :save_without_forced_conflict, :save

        define_method(:save) do |**options|
          next save_without_forced_conflict(**options) if race_already_lost

          race_already_lost = true
          LockerWish.insert_all!([
            { user_id: to.id, floor: "99", created_at: Time.current, updated_at: Time.current }
          ])
          raise ActiveRecord::RecordNotUnique, "forced by test"
        end
      end

      yield
    ensure
      LockerWish.class_eval do
        remove_method :save
        alias_method :save, :save_without_forced_conflict
        remove_method :save_without_forced_conflict
      end
    end
end
