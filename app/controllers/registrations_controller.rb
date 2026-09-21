# Signup (FR-001). Subclasses Devise so the account creation, validation, and
# automatic sign-in behaviour stay Devise's; only the post-signup destination
# is application-specific.
class RegistrationsController < Devise::RegistrationsController
  protected

    # FR-005: a new account lands on the homepage. Deferring to the sign-in path
    # rather than returning root_path directly means signup also picks up the
    # 30-day persistent session that ApplicationController grants there (FR-007).
    def after_sign_up_path_for(resource)
      after_sign_in_path_for(resource)
    end

  public

    # 015 FR-016: Devise's own destroy calls resource.destroy and then reports
    # success whatever came back, so the last administrator would be told their
    # account had been cancelled while it sat there intact. The refusal itself is
    # the model's (User#keep_an_administrator_for_the_remaining_accounts, which
    # throws :abort); this turns it into something the person can read and act on.
    #
    # Only the refusal is handled here. A destroy that goes through is Devise's
    # business — sign-out, flash, redirect — so it is handed straight back to
    # super rather than reimplemented.
    def destroy
      return super if resource.destroy

      redirect_to after_inactive_sign_up_path_for(resource),
                  alert: resource.errors[:base].first || I18n.t("user.messages.last_administrator")
    end
end
