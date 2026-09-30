# Signup (FR-001). Subclasses Devise so account creation and validation stay
# Devise's; only where the person is sent afterwards is application-specific.
#
# 034 FR-003: signup now creates an unactivated account and does not sign in —
# see after_inactive_sign_up_path_for. after_sign_up_path_for only applies if
# an account is ever created already active.
class RegistrationsController < Devise::RegistrationsController
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
end
