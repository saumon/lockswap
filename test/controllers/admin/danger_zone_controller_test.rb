require "test_helper"

# 016: the Danger Zone screen itself — what an administrator sees on it, and the
# contract that decides who gets to see it at all.
#
# The system test covers the screen as a browser meets it. What is asserted here
# is what a browser cannot: that the address is refused when typed, bookmarked or
# guessed, which is the control — leaving the link out of the menu is a courtesy.
class Admin::DangerZoneControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "the administrator is let through" do
    sign_in users(:frank)

    get admin_danger_zone_path

    assert_response :success
  end

  # FR-003: the list is what the screen is for, so it shows every configured
  # domain. Counted against the table rather than a fixed number, so adding a
  # domain to the test cannot silently shrink what this covers.
  test "every configured domain is listed" do
    %w[beta.example alpha.example].each { |d| AllowedEmailDomain.create!(domain: d) }
    sign_in users(:frank)

    get admin_danger_zone_path

    assert_select "#danger-zone-allowed-domains .data-table tbody tr", count: AllowedEmailDomain.count
    assert_select "td", text: "alpha.example"
    assert_select "td", text: "beta.example"
  end

  # Ordered by domain, so the list reads predictably rather than in whatever order
  # the rows were added. Read from the database rather than written out, so this
  # states the rule and not a snapshot.
  test "domains are listed in alphabetical order" do
    %w[gamma.example alpha.example beta.example].each { |d| AllowedEmailDomain.create!(domain: d) }
    sign_in users(:frank)

    get admin_danger_zone_path

    listed = css_select("#danger-zone-allowed-domains .data-table tbody td[data-label='Domain']").map { |cell| cell.text.strip }

    assert_equal AllowedEmailDomain.order(:domain).pluck(:domain), listed
  end

  # FR-004 on screen: with nothing configured the screen has to say what that
  # means. "No domains" and "anyone may register" are the same fact, and an
  # administrator should not have to know that to read the page.
  test "an empty list says registration is open to any domain" do
    sign_in users(:frank)

    get admin_danger_zone_path

    assert_response :success
    assert_select "#danger-zone-allowed-domains-empty"
    assert_select "#danger-zone-allowed-domains .data-table tbody tr", count: 0
  end

  test "the empty-state message is gone once a domain is configured" do
    AllowedEmailDomain.create!(domain: "allowed.example")
    sign_in users(:frank)

    get admin_danger_zone_path

    assert_select "#danger-zone-allowed-domains-empty", count: 0
  end

  # FR-003: the screen offers the way to add one. The form is asserted by where it
  # posts, so it cannot drift to some other action and still pass.
  test "the screen offers a form that adds a domain" do
    sign_in users(:frank)

    get admin_danger_zone_path

    assert_select "form[action=?][method=?]", admin_allowed_email_domains_path, "post"
  end

  # 015 established the granted administrator as the case worth testing
  # separately: rights obtained by grant are the same rights, and every check on
  # the site keys off admin? rather than on how it was obtained.
  #
  # 029 FR-005/FR-006: this feature deliberately inverts that premise for the
  # danger zone specifically — grace has ordinary administrator rights, but only
  # the super admin (frank) may reach this screen now (research.md R2/R3).
  test "a granted administrator who is not the super admin is refused" do
    sign_in users(:grace)

    get admin_danger_zone_path

    assert_redirected_to root_path
    assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, flash[:alert]
  end

  # Same restriction on the write, mirroring "a signed-in non-administrator
  # cannot change the language" below but for a standard admin instead of a
  # non-admin.
  test "a granted administrator who is not the super admin cannot change the language" do
    sign_in users(:grace)

    patch admin_danger_zone_path, params: { site_language_setting: { language: "fr" } }

    assert_redirected_to root_path
    assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, flash[:alert]
    assert_equal "en", SiteLanguageSetting.current.language
  end

  # --- User Story 3: the refusals ---------------------------------------------
  #
  # FR-002. The site's standing rule for signed-in-only content: an anonymous
  # visitor is sent to sign in rather than told what is behind the door.

  test "an anonymous visitor is sent to the login page" do
    get admin_danger_zone_path

    assert_redirected_to new_user_session_path
  end

  test "a signed-in non-administrator is refused and told why" do
    sign_in users(:carol)

    get admin_danger_zone_path

    assert_redirected_to root_path
    assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, flash[:alert]
  end

  # Following the redirect matters: the refusal has to land somewhere usable with
  # the reason on screen, not bounce or loop.
  test "a refused visitor lands on the homepage with the reason shown" do
    sign_in users(:carol)

    get admin_danger_zone_path
    follow_redirect!

    assert_response :success
    assert_match ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, response.body
  end

  # FR-002 at its sharpest: the refusal must not leak the configuration it is
  # refusing access to. A redirect that still rendered the domains would satisfy
  # "access is refused" and fail the requirement.
  test "the refusal shows none of the configuration" do
    AllowedEmailDomain.create!(domain: "secret.example")
    sign_in users(:carol)

    get admin_danger_zone_path
    follow_redirect!

    assert_no_match(/secret\.example/, response.body)
  end

  # --- 025 User Story 1: #update — the language setting -----------------------

  test "the screen shows the current language, defaulting to English" do
    sign_in users(:frank)

    get admin_danger_zone_path

    assert_select "select#site_language_setting_language option[selected]", text: "English"
  end

  # FR-011: a saved change is reflected the next time the screen is opened.
  test "an administrator changes the language and it persists" do
    sign_in users(:frank)

    patch admin_danger_zone_path, params: { site_language_setting: { language: "fr" } }

    assert_redirected_to admin_danger_zone_path
    assert_equal "fr", SiteLanguageSetting.current.language
  end

  # Edge Case: saving without changing the field is a no-op, not an error.
  test "saving the already-selected language is accepted and changes nothing" do
    sign_in users(:frank)

    patch admin_danger_zone_path, params: { site_language_setting: { language: "en" } }

    assert_redirected_to admin_danger_zone_path
    assert_equal "en", SiteLanguageSetting.current.language
  end

  # FR-003: the setting is a closed choice; a value outside it is refused rather
  # than silently accepted or coerced.
  test "an invalid language is refused and the setting is unchanged" do
    sign_in users(:frank)

    patch admin_danger_zone_path, params: { site_language_setting: { language: "de" } }

    assert_response :unprocessable_entity
    assert_equal "en", SiteLanguageSetting.current.language
  end

  # FR-002: the same admin-only guard #show already has, on the write too.
  test "an anonymous visitor cannot change the language" do
    patch admin_danger_zone_path, params: { site_language_setting: { language: "fr" } }

    assert_redirected_to new_user_session_path
    assert_equal "en", SiteLanguageSetting.current.language
  end

  # --- 025 User Story 3: only administrators may change the language ----------

  # Distinct from the anonymous case above: a signed-in standard user is
  # refused with the site's standing "administrators only" message, the same
  # as any other admin-only destination (013 FR-008).
  test "a signed-in non-administrator cannot change the language" do
    sign_in users(:carol)

    patch admin_danger_zone_path, params: { site_language_setting: { language: "fr" } }

    assert_redirected_to root_path
    assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, flash[:alert]
    assert_equal "en", SiteLanguageSetting.current.language
  end
end
