# 035: the account page's password form — current password, new password,
# confirmation — as its own object, so its errors are its own and never land on
# the email form beside it (research.md R3). Not persisted; #save changes the
# user's password or returns false with errors on these three attributes.
#
# What a successful save sets off is Devise's, not this class's: the new bcrypt
# salt signs out every other session and remember-me cookie (R4), the reset
# token is cleared (R6, FR-018) and the password-changed notification is sent
# (034 FR-039). Keeping this session signed in is the controller's job.
class PasswordChange
  include ActiveModel::Model

  # FR-008, research.md R5: the same numbers as the sign-in lockout (001
  # FR-011), deliberately a separate counter — this throttle never stops anyone
  # signing in.
  MAXIMUM_ATTEMPTS = 5
  LOCK_DURATION = 15.minutes

  attr_accessor :user, :current_password, :password, :password_confirmation

  # Never identifies a record, so form_with posts to the URL it is given rather
  # than building a member path from an id.
  def to_key = nil

  # Every rule is judged and every failure reported in one go (FR-011), except
  # while throttled, when nothing is judged at all.
  def save
    errors.clear
    expire_lapsed_throttle

    if throttled?
      errors.add(:current_password, :throttled, count: minutes_until_unthrottled)
      return false
    end

    @current_password_correct = check_current_password
    check_presence
    check_differs_from_current if @current_password_correct
    check_new_password_rules
    count_wrong_attempt unless @current_password_correct

    errors.empty? ? persist : refuse
  ensure
    user.clean_up_passwords
  end

  def throttled?
    user.password_change_locked_at.present?
  end

  # FR-024: the one error the controller adds itself, when saving raised.
  def fail!
    errors.add(:base, :failed)
  end

  def minutes_until_unthrottled
    ((user.password_change_locked_at + LOCK_DURATION - Time.current) / 60).ceil.clamp(1, LOCK_DURATION.in_minutes.to_i)
  end

  private

    def expire_lapsed_throttle
      return unless throttled? && user.password_change_locked_at <= LOCK_DURATION.ago

      user.update_columns(password_change_failed_attempts: 0, password_change_locked_at: nil)
    end

    # FR-013: "incorrect" and nothing more.
    def check_current_password
      return false if current_password.blank?
      return true if user.valid_password?(current_password)

      errors.add(:current_password, :invalid)
      false
    end

    def check_presence
      %i[current_password password password_confirmation].each do |attribute|
        errors.add(attribute, :blank) if public_send(attribute).blank?
      end
    end

    # FR-009, research.md R3: only ever asked once the current password is known
    # to be right. Asked alongside a wrong one, its answer would tell anyone
    # holding the session whether their guess was the real password (FR-013).
    # Compared against the stored hash, so this runs before the new password is
    # assigned.
    def check_differs_from_current
      return if password.blank?

      errors.add(:password, :same_as_current) if user.valid_password?(password)
    end

    # Length (8..128) and the match come from Devise's :validatable on User, so
    # the rule is defined once. Its errors are re-added here under this form's
    # own attribute names and messages; one error per field, blank first.
    def check_new_password_rules
      return if password.blank?

      user.password = password
      user.password_confirmation = password_confirmation.presence
      user.valid?

      %i[password password_confirmation].each do |attribute|
        next if errors.include?(attribute)

        user.errors.details[attribute].each do |detail|
          errors.add(attribute, detail[:error], **detail.except(:error, :attribute))
        end
      end
    end

    # FR-008, research.md R5. One atomic UPDATE, so two tabs submitting at once
    # cannot both read 4 and both stop short of the lock. A blank current
    # password is not a guess and is not counted.
    def count_wrong_attempt
      return if current_password.blank?

      User.update_counters(user.id, password_change_failed_attempts: 1)
      attempts = User.where(id: user.id).pick(:password_change_failed_attempts)
      User.where(id: user.id).update_all(password_change_locked_at: Time.current) if attempts >= MAXIMUM_ATTEMPTS
    end

    # FR-022: the new password and the throttle reset are one row, one UPDATE.
    def persist
      user.password_change_failed_attempts = 0
      user.password_change_locked_at = nil
      return true if user.save

      fail!
      refuse
    end

    # Analyze I1: the user is the controller's resource, which the email card
    # renders on a refusal. Reloading drops the assigned password and any errors,
    # and picks up the counter written in SQL above. A correct current password
    # still resets the count, even though the change itself was refused.
    def refuse
      user.reload
      user.errors.clear
      user.update_columns(password_change_failed_attempts: 0, password_change_locked_at: nil) if @current_password_correct
      false
    end
end
