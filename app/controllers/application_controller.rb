class ApplicationController < ActionController::Base
  include Devise::Controllers::Rememberable

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # 025 FR-008: read fresh on every request, wrapped as a block rather than a
  # bare I18n.locale= assignment, so this request's language can never leak
  # into the next request Puma hands the same thread (research.md R2). No
  # caching, no session/cookie: a saved change is visible to every request the
  # moment it is saved, which is what makes FR-008's "no later than the next
  # page load, no sign-out required" true without any invalidation to get wrong.
  around_action :switch_locale

  # 013 FR-008: said plainly rather than pretending the address does not exist.
  # A signed-in colleague who followed a stale link is not an intruder to be
  # stonewalled, and the site's habit elsewhere is to say what happened (007).
  #
  # 025: kept as a plain frozen string for existing tests that assert against it
  # by name; #require_admin! calls I18n.t("application.administrators_only")
  # instead of this constant — an explicit (non-lazy) key, since require_admin!
  # is shared across every controller that guards an admin-only destination, not
  # scoped to one controller/action pair the way t(".…") lazy lookup assumes.
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

      redirect_to root_path, alert: I18n.t("application.administrators_only")
    end

    # 029 FR-006: the danger zone's own admin-only guard, one tier further.
    # Structurally identical to require_admin! above — refuses on its own, same
    # message, same reasoning — differing only in the predicate checked
    # (research.md R2/R3, contracts/super-admin-access.md). The message is
    # deliberately the same one a non-admin already sees rather than a distinct
    # "super admins only" string: a standard admin's refusal reads exactly like
    # anyone else's, revealing nothing about a more privileged tier existing.
    def require_super_admin!
      return if current_user&.super_admin?

      redirect_to root_path, alert: I18n.t("application.administrators_only")
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

    def switch_locale(&action)
      I18n.with_locale(SiteLanguageSetting.current.language.to_sym, &action)
    end
end
