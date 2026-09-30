# 034 User Story 3: password reset by emailed link (FR-014 to FR-020, FR-023,
# FR-040).
#
# Devise's own controller does the reset itself. Two things are added: #create
# answers identically whatever the address is and holds it to one email per five
# minutes, and #update also activates the account and lifts any lockout once the
# new password is saved.
class Users::PasswordsController < Devise::PasswordsController
  # FR-023: one reset email per address per five minutes.
  RESEND_COOLDOWN = 5.minutes

  # FR-015, FR-016, FR-023: the same sentence on the same page whether the address
  # has an account or not, and whether an email went out or was held back
  # (research.md R2/R3).
  def create
    email = params.dig(resource_name, :email).to_s.strip.downcase
    user = User.find_by(email: email) if email.present?

    if user.nil?
      log_event(:reset_unknown_email)
    elsif user.reset_password_sent_at.present? && user.reset_password_sent_at > RESEND_COOLDOWN.ago
      log_event(:reset_throttled, user)
    else
      user.send_reset_password_instructions
    end

    redirect_to new_user_session_path, notice: I18n.t("devise.passwords.send_paranoid_instructions")
  end

  # Devise yields here after the password is saved and before it checks
  # active_for_authentication? and signs in (devise 5.0.4,
  # passwords_controller.rb#update) — so anything that would stop the sign-in has
  # to be cleared in this block (research.md R4).
  #
  # FR-019 (clarified): following the reset link proves the mailbox as much as
  # the activation link does, so an unactivated account is activated here.
  #
  # FR-040 (clarified): and a lockout ends. Devise only unlocks on reset when the
  # unlock strategy includes :email; ours is :time, so without this the person
  # who just typed five wrong passwords and then reset would still be refused.
  def update
    super do |user|
      next unless user.errors.empty?

      user.activate!
      user.unlock_access! if user.access_locked? || user.failed_attempts.positive?
      log_event(:reset_completed, user)
    end
  end

  private

    # FR-032, research.md R16: the account id, never the address or the token.
    def log_event(event, user = nil)
      Rails.logger.info("[account_mail] event=#{event}#{" user_id=#{user.id}" if user}")
    end
end
