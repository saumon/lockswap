# 034: the activation link (User Story 1, FR-006/FR-008) and asking for a new one
# (User Story 4, FR-011 to FR-013, FR-023).
#
# Devise's own controller is kept for everything except two things it does not
# do the way the spec asks: #show says *which* way a link failed, and whether it
# confirmed an account or a changed address; #create answers identically whatever
# happened and holds each address to one email per five minutes.
class Users::ConfirmationsController < Devise::ConfirmationsController
  # FR-023: one activation email per address per five minutes.
  RESEND_COOLDOWN = 5.minutes

  # FR-011 to FR-013, FR-023. Whatever the address turns out to be — waiting for
  # activation, already active, throttled, or unknown — the visitor sees the same
  # sentence on the same page, so the screen cannot be used to learn who has an
  # account (research.md R2/R3).
  def create
    email = params.dig(resource_name, :email).to_s.strip.downcase
    user = User.find_by(email: email) if email.present?

    if user.nil?
      log_event(:resend_unknown_email)
    elsif user.confirmed?
      log_event(:resend_for_active, user)
    elsif user.confirmation_sent_at.present? && user.confirmation_sent_at > RESEND_COOLDOWN.ago
      log_event(:activation_throttled, user)
    else
      # Never Devise's resend_confirmation_instructions directly: it re-sends the
      # same unexpired token, which would leave every earlier email working
      # (research.md R17, FR-012).
      user.resend_activation!
    end

    redirect_to new_user_session_path, notice: I18n.t("devise.confirmations.send_paranoid_instructions")
  end

  # FR-006: a good link activates and sends the person to sign in — it never
  # signs them in by itself (US1-2). FR-008: a bad one says which of three ways
  # it is bad, each with its own next step, on the resend screen.
  #
  # analyze I2: the same link also confirms a changed address (User Story 6),
  # usually followed while signed in. That case says what changed and stays
  # where a signed-in person belongs, rather than sending them to the sign-in
  # page, which would bounce them with "already signed in".
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])

    if resource.errors.empty?
      log_event(:activated_by_link, resource)
      notice = resource.saved_change_to_email? ? I18n.t("devise.confirmations.email_changed") : I18n.t("devise.confirmations.confirmed")

      redirect_to(signed_in?(resource_name) ? root_path : new_user_session_path, notice: notice)
    else
      @outcome = failure_outcome(resource)
      render :new, status: :unprocessable_content
    end
  end

  private

    def failure_outcome(record)
      case record.errors.details[:email].pluck(:error)
      in [ *, :confirmation_period_expired, * ] then :expired
      in [ *, :already_confirmed, * ] then :already_active
      else :unrecognised
      end
    end

    # FR-032, research.md R16: the account id, never the address or the token.
    def log_event(event, user = nil)
      Rails.logger.info("[account_mail] event=#{event}#{" user_id=#{user.id}" if user}")
    end
end
