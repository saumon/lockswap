require "test_helper"

# 035: the account page's password form, without the browser. Each rule here is
# one the controller and the system tests rely on but do not re-derive.
class PasswordChangeTest < ActiveSupport::TestCase
  NEW_PASSWORD = "brandnew456".freeze

  setup do
    @user = users(:carol)
  end

  def change(current: VALID_PASSWORD, password: NEW_PASSWORD, confirmation: password)
    PasswordChange.new(user: @user, current_password: current, password: password,
                       password_confirmation: confirmation)
  end

  def error_types(form, attribute) = form.errors.details[attribute].map { |detail| detail[:error] }

  # --- User Story 1 -----------------------------------------------------------

  test "a correct current password and a valid new one change the password" do
    form = change

    assert form.save, form.errors.full_messages.to_sentence
    assert @user.reload.valid_password?(NEW_PASSWORD)
    assert_not @user.valid_password?(VALID_PASSWORD)
  end

  # FR-020, 034 FR-039: Devise's own after_update sends it, once per change.
  test "a successful change enqueues exactly one password-changed notification" do
    assert_enqueued_emails 1 do
      assert change.save
    end
  end

  test "a wrong current password changes nothing and sends nothing" do
    form = change(current: "not-my-password")

    assert_no_enqueued_emails do
      assert_not form.save
    end
    assert_equal [ :invalid ], error_types(form, :current_password)
    assert @user.reload.valid_password?(VALID_PASSWORD)
  end

  # I1: the user is the controller's resource, which the email card renders on
  # a refusal. It must come back without the password errors or the new hash.
  test "a refusal leaves the user record as it was found" do
    form = change(password: "short")

    assert_not form.save
    assert_empty @user.errors
    assert_not @user.changed?, "unsaved changes left on the user: #{@user.changed.inspect}"
  end

  # --- User Story 2 -----------------------------------------------------------

  # FR-018: Devise clears the token whenever encrypted_password changes.
  test "a reset link issued before the change stops working after it" do
    raw_token = @user.send_reset_password_instructions
    assert change.save

    reset = User.reset_password_by_token(reset_password_token: raw_token,
                                         password: "another789", password_confirmation: "another789")

    assert_predicate reset.errors[:reset_password_token], :present?
    assert @user.reload.valid_password?(NEW_PASSWORD)
  end

  # --- User Story 3: rules ----------------------------------------------------

  test "every empty field is reported, all at once" do
    form = change(current: "", password: "", confirmation: "")

    assert_not form.save
    assert_equal [ :blank ], error_types(form, :current_password)
    assert_equal [ :blank ], error_types(form, :password)
    assert_equal [ :blank ], error_types(form, :password_confirmation)
  end

  test "a new password shorter than 8 characters is refused" do
    form = change(password: "seven77")

    assert_not form.save
    assert_includes error_types(form, :password), :too_short
  end

  test "a new password longer than 128 characters is refused" do
    form = change(password: "x" * 129)

    assert_not form.save
    assert_includes error_types(form, :password), :too_long
  end

  test "a confirmation that differs is refused on the confirmation field" do
    form = change(confirmation: "#{NEW_PASSWORD}-typo")

    assert_not form.save
    assert_equal [ :confirmation ], error_types(form, :password_confirmation)
  end

  test "a new password identical to the current one is refused" do
    form = change(password: VALID_PASSWORD)

    assert_not form.save
    assert_equal [ :same_as_current ], error_types(form, :password)
  end

  # FR-011: no short-circuit — both problems come back together.
  test "a wrong current password and a too-short new one are both reported" do
    form = change(current: "not-my-password", password: "short")

    assert_not form.save
    assert_equal [ :invalid ], error_types(form, :current_password)
    assert_includes error_types(form, :password), :too_short
  end

  # U1, FR-013: same_as_current is only judged once the current password is
  # known to be right. Otherwise it would answer "is Y the real password?" for
  # anyone holding the session.
  test "with a wrong current password, the real password as the new one reveals nothing" do
    form = change(current: "not-my-password", password: VALID_PASSWORD)

    assert_not form.save
    assert_equal [ :invalid ], error_types(form, :current_password)
    assert_not_includes error_types(form, :password), :same_as_current
  end

  # --- User Story 3: throttle (FR-008, data-model.md "Throttle states") -------

  def fail_times(count)
    count.times { change(current: "not-my-password").save }
    @user.reload
  end

  test "four wrong current passwords are counted but do not throttle" do
    fail_times(4)

    assert_equal 4, @user.password_change_failed_attempts
    assert_nil @user.password_change_locked_at
  end

  test "the fifth consecutive wrong current password throttles the form" do
    fail_times(5)

    assert_not_nil @user.password_change_locked_at
  end

  test "while throttled even the correct password is refused without being checked" do
    fail_times(5)
    form = change

    @user.define_singleton_method(:valid_password?) { |*| raise "the password must not be checked while throttled" }

    assert_not form.save
    assert_equal [ :throttled ], error_types(form, :current_password)
    assert User.find(@user.id).valid_password?(VALID_PASSWORD)
  end

  test "the throttle message says how many minutes remain" do
    freeze_time
    fail_times(5)

    travel 10.minutes do
      form = change
      assert_not form.save
      assert_equal 5, form.errors.details[:current_password].first[:count]
    end
  end

  test "fifteen minutes later the form opens again and the count restarts" do
    fail_times(5)

    travel PasswordChange::LOCK_DURATION + 1.second do
      assert change.save
      @user.reload
      assert_equal 0, @user.password_change_failed_attempts
      assert_nil @user.password_change_locked_at
    end
  end

  test "a correct current password resets the count even when the change is refused" do
    fail_times(3)

    assert_not change(password: "short").save
    assert_equal 0, @user.reload.password_change_failed_attempts
  end

  # The sign-in lockout (001 FR-011) is a different counter and stays untouched.
  test "the throttle never touches the sign-in lockout" do
    fail_times(5)

    assert_equal 0, @user.failed_attempts
    assert_nil @user.locked_at
    assert_not @user.access_locked?
  end

  # Analyze C2: a session that is already signed in may still change the
  # password while sign-in is locked, and doing so does not lift that lock.
  test "a change made while sign-in is locked leaves the sign-in lock in place" do
    @user.update_columns(failed_attempts: 5, locked_at: Time.current)

    assert change.save
    assert_predicate @user.reload, :access_locked?
  end
end
