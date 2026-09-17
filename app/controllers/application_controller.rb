class ApplicationController < ActionController::Base
  include Devise::Controllers::Rememberable

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # 013 FR-008: said plainly rather than pretending the address does not exist.
  # A signed-in colleague who followed a stale link is not an intruder to be
  # stonewalled, and the site's habit elsewhere is to say what happened (007).
  ADMINISTRATORS_ONLY_MESSAGE = "That page is for administrators only.".freeze

  protected

    # 013 FR-004/FR-008: the access control itself. Leaving the "Admin" entry out
    # of a non-administrator's navigation is presentation; this is what refuses
    # the address when it is typed, bookmarked, or guessed.
    #
    # Lives here rather than on the one controller that uses it today because it
    # is the site's rule for administrator-only destinations, and the next one
    # should not have to re-derive it.
    #
    # Written to refuse on its own: paired with authenticate_user! there is always
    # a current_user by the time it runs, but a guard that would raise instead of
    # refusing if that pairing were ever forgotten is the wrong way round.
    def require_admin!
      return if current_user&.admin?

      redirect_to root_path, alert: ADMINISTRATORS_ONLY_MESSAGE
    end

    # FR-007: every successful sign-in — including the automatic one right after
    # signup — gets the 30-day persistent session. The spec asks for a blanket
    # 30-day session, so this is not an opt-in "remember me" checkbox.
    def after_sign_in_path_for(resource)
      remember_me(resource)
      super
    end

    # FR-009: logging out returns the visitor to the login page. Without this
    # they would be bounced off the homepage by authenticate_user!, which would
    # replace the "signed out" confirmation with a "please sign in" prompt.
    def after_sign_out_path_for(resource_or_scope)
      new_user_session_path
    end
end
