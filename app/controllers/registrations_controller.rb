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
end
