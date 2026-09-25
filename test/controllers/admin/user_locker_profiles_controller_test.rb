require "test_helper"

# 027 User Story 3: an administrator correcting a user's floor/locker on their
# behalf, from the pencil-icon control on the detail screen.
class Admin::UserLockerProfilesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "a valid edit updates the account's floor/locker and records provenance" do
    sign_in users(:frank)

    patch admin_user_locker_profile_path(users(:carol)),
      params: { user: { floor: "9", locker_number: "Z99" } }

    carol = users(:carol).reload
    assert_equal "9", carol.floor
    assert_equal "Z99", carol.locker_number
    assert_equal users(:frank), carol.locker_edited_by
    assert_not_nil carol.locker_edited_at
    assert_redirected_to admin_user_path(users(:carol))
  end

  # FR-009: a blank floor is refused, same as the self-service rule.
  test "a blank floor is refused and nothing changes" do
    sign_in users(:frank)
    original_floor = users(:carol).floor

    patch admin_user_locker_profile_path(users(:carol)),
      params: { user: { floor: "", locker_number: "Z99" } }

    assert_response :unprocessable_entity
    assert_equal original_floor, users(:carol).reload.floor
    assert_nil users(:carol).reload.locker_edited_by
  end

  # FR-009, Acceptance Scenario 3: the exact same conflict message a user would
  # see attempting the same conflicting change.
  test "a locker already held on the same floor is refused with the existing message" do
    sign_in users(:frank)
    users(:carol).update_columns(floor: users(:bob).floor)

    patch admin_user_locker_profile_path(users(:carol)),
      params: { user: { floor: users(:bob).floor, locker_number: users(:bob).locker_number } }

    assert_response :unprocessable_entity
    assert_match User::LOCKER_NUMBER_TAKEN_MESSAGE, response.body
    assert_nil users(:carol).reload.locker_number
  end

  # FR-009, Acceptance Scenario 5, Clarifications: no admin bypass of the
  # swap-lock rule — the exact message a self-service edit would show.
  test "an account with an active swap proposal cannot have its floor/locker edited" do
    sign_in users(:frank)
    proposal = locker_swap_proposals(:alice_pending_to_bob)
    proposal.update_columns(status: LockerSwapProposal.statuses[:accepted])

    patch admin_user_locker_profile_path(users(:bob)),
      params: { user: { floor: "11", locker_number: "Q11" } }

    assert_response :unprocessable_entity
    assert_match User::LOCKED_BY_SWAP_MESSAGE, response.body
    assert_equal "3", users(:bob).reload.floor
  end

  test "editing a vanished account says so" do
    sign_in users(:frank)
    gone = users(:dave).id
    users(:dave).destroy

    patch admin_user_locker_profile_path(gone), params: { user: { floor: "9" } }

    assert_redirected_to admin_users_path
    assert_equal Admin::UsersController::ACCOUNT_GONE_MESSAGE, flash[:alert]
  end

  test "a non-administrator cannot edit another account's floor/locker" do
    sign_in users(:carol)

    patch admin_user_locker_profile_path(users(:bob)), params: { user: { floor: "11" } }

    assert_redirected_to root_path
    assert_equal "3", users(:bob).reload.floor
  end

  test "an anonymous visitor cannot edit an account's floor/locker" do
    patch admin_user_locker_profile_path(users(:bob)), params: { user: { floor: "11" } }

    assert_redirected_to new_user_session_path
    assert_equal "3", users(:bob).reload.floor
  end
  # 030 FR-005: an administrator's edit is held to the same list, with no bypass.
  test "a floor outside the site's list is refused even when submitted directly" do
    SiteFloorList.current.update!(floors_text: "0, 1, 2, 3")
    sign_in users(:frank)
    original_floor = users(:carol).floor

    patch admin_user_locker_profile_path(users(:carol)),
      params: { user: { floor: "7", locker_number: "Z99" } }

    assert_response :unprocessable_entity
    assert_equal original_floor, users(:carol).reload.floor
  end
  # 030 FR-013: an administrator's edit is held to the same format.
  test "a locker number that does not match the format is refused even when submitted directly" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}")
    sign_in users(:frank)

    patch admin_user_locker_profile_path(users(:carol)),
      params: { user: { floor: users(:carol).floor, locker_number: "42" } }

    assert_response :unprocessable_entity
    assert_nil users(:carol).reload.locker_number
  end
end
