# Signup (FR-001). Subclasses Devise so account creation and validation stay
# Devise's; only where the person is sent afterwards is application-specific.
#
# 034 FR-003: signup now creates an unactivated account and does not sign in —
# see after_inactive_sign_up_path_for. after_sign_up_path_for only applies if
# an account is ever created already active.
class RegistrationsController < Devise::RegistrationsController
  # 035, research.md R1: the password form is a member of the controller that
  # owns the account page, so a refusal can re-render that page with Devise's
  # helpers in place. Devise's own prepend gives it resource = current_user, the
  # same as #edit and #update.
  prepend_before_action :authenticate_scope!, only: [ :edit, :update, :destroy, :update_password ]

  # 035 FR-019, research.md R9: Devise's failure app only remembers where a GET
  # was going, so a password form submitted from an expired session would land
  # on the homepage after sign-in. Declared after the line above so that, being
  # prepended last, it runs first — before authenticate_scope! turns the
  # visitor away.
  prepend_before_action :return_to_account_page_after_sign_in, only: :update_password

  protected

    # FR-005: a new account lands on the homepage. Deferring to the sign-in path
    # rather than returning root_path directly means signup also picks up the
    # 30-day persistent session that ApplicationController grants there (FR-007).
    def after_sign_up_path_for(resource)
      after_sign_in_path_for(resource)
    end

    # 034 FR-003, research.md R7: to sign in, carrying the "check your inbox"
    # notice. Devise's default is root_path, which authenticate_user! would
    # bounce to the sign-in page with a "please sign in" alert that replaces the
    # notice.
    def after_inactive_sign_up_path_for(_resource)
      new_user_session_path
    end

  public

    # 035: the account page carries the password form as well as the email one.
    def edit
      @password_change = PasswordChange.new(user: resource)
      super
    end

    # 035 PATCH /users/account/password. Only ever acts on the signed-in account:
    # the user comes from the session, never from params (FR-007).
    def update_password
      @password_change = PasswordChange.new(user: resource, **password_change_params)

      if save_password_change
        keep_this_session_signed_in
        log_password_change(:changed)
        flash[:password_changed] = true
        redirect_to edit_user_registration_path, status: :see_other
      else
        render :edit, status: :unprocessable_content
      end
    end

    # 029 FR-010, research.md R6: Devise's own destroy calls resource.destroy and
    # then reports success whatever came back, so the super admin would be told
    # their account had been cancelled while it sat there intact. The refusal
    # itself is the model's (User#prevent_super_admin_cancellation, which throws
    # :abort); this turns it into something the person can read and act on.
    #
    # Only the refusal is handled here. A destroy that goes through is Devise's
    # business — sign-out, flash, redirect — so it is handed straight back to
    # super rather than reimplemented.
    def destroy
      return super if resource.destroy

      # 034 analyze I1: back to the account page, explicitly. This used to borrow
      # after_inactive_sign_up_path_for, which now points at the sign-in page —
      # and the refused super admin is still signed in, so that page would bounce
      # them to the homepage with "already signed in" in place of this message.
      redirect_to edit_user_registration_path,
                  alert: resource.errors[:base].first || I18n.t("user.messages.super_admin_uncancellable")
    end

  protected

    # 035 research.md R2: email and the current password, nothing else. Devise's
    # default also permits password and password_confirmation; hiding the fields
    # would not stop a hand-made PUT /users from changing the password here,
    # past the throttle and the session handling of #update_password.
    def account_update_params
      params.require(:user).permit(:email, :current_password)
    end

  private

    # 035 FR-024: an unexpected failure changes nothing and is said plainly; the
    # technical detail goes to the log, never to the page.
    def save_password_change
      saved = @password_change.save
      log_password_change(@password_change.errors.of_kind?(:current_password, :throttled) ? :throttled : :refused) unless saved
      saved
    rescue ActiveRecord::ActiveRecordError => error
      log_password_change(:failed, error: error.class.name)
      resource.reload
      @password_change.fail!
      false
    end

    # 035 FR-016/FR-017, research.md R4. Both sign-ins Devise keeps for this
    # browser carry the password's bcrypt salt (users has no remember_token
    # column), so the change has just invalidated them here as everywhere else.
    # That is what signs every other browser out. This one is put back: the
    # session is re-serialized with the new salt, and the 30-day cookie every
    # sign-in grants (001 FR-007, ApplicationController#after_sign_in_path_for)
    # is re-issued — without it this browser would be signed out at its next
    # restart.
    def keep_this_session_signed_in
      bypass_sign_in(resource, scope: resource_name)
      remember_me(resource)
    end

    # 035 FR-025, research.md R12: account and outcome, and for a refusal the
    # rules that failed — never a value.
    def log_password_change(event, error: nil)
      reasons = (@password_change.errors.details.flat_map { |attribute, details|
        details.map { |detail| "#{attribute}_#{detail[:error]}" }
      }.join(",") if event == :refused)

      Rails.logger.info(
        "[password_change] event=#{event} user_id=#{resource.id}" \
        "#{" reasons=#{reasons}" if reasons}#{" error=#{error}" if error}"
      )
    end

    def return_to_account_page_after_sign_in
      store_location_for(resource_name, edit_user_registration_path) unless user_signed_in?
    end

    # 035 FR-007: the three values and nothing else — no id, no email.
    def password_change_params
      params.require(:password_change)
            .permit(:current_password, :password, :password_confirmation)
            .to_h.symbolize_keys
    end
end
