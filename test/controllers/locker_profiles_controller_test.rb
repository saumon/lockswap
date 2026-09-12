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
end
