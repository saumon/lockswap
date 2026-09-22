require "test_helper"

# 027 User Story 4: an administrator cancelling a user's standing locker search
# on their behalf, from the detail screen.
class Admin::UserLockerWishesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "cancelling an existing wish destroys it and records provenance" do
    sign_in users(:frank)

    assert_difference -> { LockerWish.count }, -1 do
      delete admin_user_locker_wish_path(users(:bob))
    end

    bob = users(:bob).reload
    assert_nil bob.locker_wish
    assert_equal users(:frank), bob.search_cancelled_by
    assert_not_nil bob.search_cancelled_at
    assert_redirected_to admin_user_path(users(:bob))
    assert_not_nil flash[:notice]
  end

  # Edge Cases: already accomplished, not an error.
  test "cancelling when there is no wish is a no-op that still succeeds" do
    sign_in users(:frank)

    assert_no_difference -> { LockerWish.count } do
      delete admin_user_locker_wish_path(users(:dave))
    end

    assert_redirected_to admin_user_path(users(:dave))
    assert_not_nil flash[:notice]
    assert_nil users(:dave).reload.search_cancelled_by
  end

  # FR-011, Acceptance Scenario 4: the proposal itself is left exactly as it was.
  test "cancelling a search leaves any active swap proposal untouched" do
    sign_in users(:frank)
    proposal = locker_swap_proposals(:alice_pending_to_bob)

    delete admin_user_locker_wish_path(users(:bob))

    proposal.reload
    assert_predicate proposal, :pending?
  end

  test "cancelling for a vanished account says so" do
    sign_in users(:frank)
    gone = users(:dave).id
    users(:dave).destroy

    delete admin_user_locker_wish_path(gone)

    assert_redirected_to admin_users_path
    assert_equal Admin::UsersController::ACCOUNT_GONE_MESSAGE, flash[:alert]
  end

  test "a non-administrator cannot cancel another account's search" do
    sign_in users(:carol)

    assert_no_difference -> { LockerWish.count } do
      delete admin_user_locker_wish_path(users(:bob))
    end

    assert_redirected_to root_path
  end

  test "an anonymous visitor cannot cancel an account's search" do
    assert_no_difference -> { LockerWish.count } do
      delete admin_user_locker_wish_path(users(:bob))
    end

    assert_redirected_to new_user_session_path
  end
end
