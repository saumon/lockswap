class ApplicationController < ActionController::Base
  include Devise::Controllers::Rememberable

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  protected

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
