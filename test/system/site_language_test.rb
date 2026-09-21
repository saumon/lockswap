require "application_system_test_case"

# 025: the site language setting as a person actually meets it — an
# administrator changing it from the Danger Zone screen, and the effect
# landing on screens far from that one, for everyone, without anyone
# signing out.
class SiteLanguageTest < ApplicationSystemTestCase
  setup do
    @administrator = users(:frank)
  end

  # User Story 1, Acceptance Scenario 2/3: switching to French and back to
  # English, checked on several different screens — not just the one the
  # administrator changed it from, and reversible. This is the one test in
  # this file that exercises the actual admin-facing switching mechanism
  # end to end; the other two below set the language directly and focus on
  # what the rest of the site does with it.
  test "switching the language applies across the site and is reversible" do
    log_in_as @administrator
    visit admin_danger_zone_path

    select "French", from: "site_language_setting_language"
    click_on "Save language"

    assert_text "Zone de danger"
    within "#danger-zone-language" do
      assert_selector "select#site_language_setting_language option[selected]", text: "Français"
    end

    log_out_under("fr")
    visit new_user_registration_path
    assert_text "Créer votre compte"

    sign_in_under_current_locale(@administrator, "fr")
    visit admin_danger_zone_path
    select "Anglais", from: "site_language_setting_language"
    click_on "Enregistrer la langue"

    assert_text "Danger Zone"

    log_out_under("en")
    visit new_user_registration_path
    assert_text "Create your account"
  end

  # FR-012 / Clarifications 2026-09-21: dates keep one fixed format regardless
  # of language — only the surrounding labels change. Read from the proposal
  # history screen, a plain read-only list, rather than the homepage: the
  # homepage's declined-proposal tile marks itself acknowledged (and stops
  # appearing) the first time its owner sees it, which would make a
  # before/after comparison of "the same tile" impossible.
  #
  # The language is set directly rather than through the admin UI: that path
  # is already exercised end to end by the test above, and this one is about
  # what a *different* signed-in user's screen does once it is set, not about
  # the switching mechanism itself — sidestepping a sign-out/sign-in dance
  # under two different users and two different languages in one test.
  test "dates keep the same format under French" do
    proposal = LockerSwapProposal.find_by!(requester: users(:dave), status: :declined)

    log_in_as users(:dave)
    visit locker_swap_proposals_path
    # td.meta.data-value is the "Sent" column specifically — the only cell in
    # the row carrying both classes together — found by class rather than by
    # data-label text, which is itself translated.
    english_date = find("#swap-proposal-history-row-#{proposal.id} td.meta.data-value").text

    SiteLanguageSetting.current.update!(language: "fr")
    visit locker_swap_proposals_path

    assert_text english_date
  end

  # FR-009/SC-004: user-entered content is never translated or altered.
  test "user-entered content is unchanged under French" do
    log_in_as users(:dave)

    SiteLanguageSetting.current.update!(language: "fr")
    visit locker_swap_proposals_path

    assert_text "Found another swap" # dave's own decline_comment, verbatim
  end

  # User Story 2: on a fresh installation — no SiteLanguageSetting row ever
  # created, which is exactly the transactional-test starting state, since
  # research.md R9/T052 deliberately keep no fixture for this table — every
  # visitor sees English by default, and the Danger Zone screen confirms it.
  test "a fresh installation defaults to English" do
    assert_equal 0, SiteLanguageSetting.count

    visit new_user_session_path
    assert_text "Log in"

    log_in_as @administrator
    visit admin_danger_zone_path

    within "#danger-zone-language" do
      assert_selector "select#site_language_setting_language option[selected]", text: "English"
    end
  end

  # User Story 3: a standard user gets no language control anywhere, and the
  # site-wide setting is what their screens follow — not their own browser/OS
  # locale, which this test leaves at its default (there being no per-user
  # locale concept anywhere in this feature for it to override in the first
  # place — spec Assumptions).
  test "a standard user has no language control and follows the site-wide setting" do
    log_in_as users(:carol)

    assert_no_selector "summary.site-submenu-toggle" # the "Admin" submenu itself
    assert_no_link "Danger Zone"
    assert_no_selector "select#site_language_setting_language"

    SiteLanguageSetting.current.update!(language: "fr")
    visit root_path

    assert_text "Bienvenue sur"
    assert_no_selector "select#site_language_setting_language"
  end

  private

    # click_on "Log out" only works while the site is in English — every other
    # system test relies on that. Looking the label up through I18n directly,
    # for the language the caller already knows is current, avoids guessing
    # at a CSS selector for what is otherwise the exact same button.
    def log_out_under(language)
      button = find(:button, I18n.t("shared.site_menu_items.log_out", locale: language), visible: true)
      # Not button.click: Selenium's native click intermittently no-ops on
      # this exact button (reproduced directly — the element at its own
      # click-point coordinates is itself, so it is not a hit-testing/overlay
      # problem). A JS-dispatched click bypasses whatever native-click quirk
      # that is.
      page.execute_script("arguments[0].click()", button.native)
      # Mirrors login_test.rb's own "logging out ends the session" test:
      # waiting for the sign-in path is what actually blocks until the
      # sign-out request's redirect has landed. A subsequent `visit` issued
      # before that would abandon the in-flight request mid-navigation,
      # leaving the session looking authenticated.
      assert_current_path new_user_session_path
      wait_for_turbo
    end

    # log_in_as asserts English copy throughout (the field labels, the submit
    # button, "Welcome to LockSwap"), so it cannot be reused once the site
    # language has changed. Field ids are stable across locales — Rails derives
    # them from the attribute name, not the translated label — so this signs in
    # the same way, using I18n directly for the one piece of text it needs
    # (the submit button) instead of a locale-specific literal.
    def sign_in_under_current_locale(user, language, password: VALID_PASSWORD)
      visit new_user_session_path
      fill_in_reliably "user_email", with: user.email
      fill_in_reliably "user_password", with: password
      click_on I18n.t("devise.sessions.new.submit", locale: language)
      wait_for_turbo
    end
end
