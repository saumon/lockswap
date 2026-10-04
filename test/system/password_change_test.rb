require "application_system_test_case"

# 035: changing the password from the account page, through the browser. The
# rules themselves are proven in test/models/password_change_test.rb and the
# responses in the 035 section of registrations_controller_test.rb; this is
# what a person sees, and what happens to their other browsers.
class PasswordChangeTest < ApplicationSystemTestCase
  NEW_PASSWORD = "brandnew456".freeze

  setup do
    @carol = users(:carol)
  end

  def open_account_page_from_menu
    within("header") { find(".site-bar a.site-nav-identity").click }
    assert_selector "h1", text: I18n.t("devise.registrations.edit.heading")
    wait_for_turbo
  end

  def fill_password_form(current: VALID_PASSWORD, password: NEW_PASSWORD, confirmation: password)
    within "#password-change" do
      fill_in_reliably "Current password", with: current
      fill_in_reliably "New password", with: password
      fill_in_reliably "Confirm new password", with: confirmation
    end
  end

  def submit_password_form
    within("#password-change") { click_on I18n.t("devise.registrations.edit.password_submit") }
  end

  def focused_element_matches?(selector)
    page.evaluate_script("document.activeElement?.matches(#{selector.to_json}) ?? false")
  end

  def assert_signed_out_here
    visit root_path
    assert_current_path new_user_session_path
  end

  def assert_signed_in_here
    visit edit_user_registration_path
    assert_current_path edit_user_registration_path
  end

  # --- User Story 1 -----------------------------------------------------------

  test "from the menu, a password is changed and the page says what that did" do
    log_in_as @carol
    open_account_page_from_menu

    fill_password_form
    submit_password_form

    within ".form-success[role=status]" do
      assert_text I18n.t("devise.registrations.edit.password_changed_active")
      assert_text I18n.t("devise.registrations.edit.password_changed_sessions")
      assert_text I18n.t("devise.registrations.edit.password_changed_notified", email: @carol.email)
    end
    assert focused_element_matches?(".form-success"), "the success panel should have focus (FR-014)"

    # US1-5: the old password is refused, the new one works.
    click_on "Log out"
    assert_text "Signed out successfully."
    visit new_user_session_path
    fill_in_reliably "Email", with: @carol.email
    fill_in_reliably "Password", with: VALID_PASSWORD
    click_on "Log in"
    assert_text I18n.t("devise.failure.invalid", authentication_keys: "Email")

    log_in_as @carol, password: NEW_PASSWORD
  end

  # FR-003, FR-004, FR-006: three hidden fields, each with its own reveal
  # control, telling password managers which is which.
  test "the form asks for three hidden passwords, each with its own reveal control" do
    log_in_as @carol
    visit edit_user_registration_path

    within "#password-change" do
      assert_selector "input[type=password]", count: 3
      assert_field "Current password", type: "password", with: ""
      assert_selector "#password_change_current_password[autocomplete=current-password]"
      assert_selector "#password_change_password[autocomplete=new-password]"
      assert_selector "#password_change_password_confirmation[autocomplete=new-password]"
      assert_selector "button.field-visibility-toggle", count: 3
      assert_text I18n.t("devise.shared.password_hint", count: 8)
    end
  end

  # FR-023, analyze C1: disabled and saying so from the first click, and one
  # change — one notification — however many clicks follow.
  test "a second click while the change is in flight changes nothing more" do
    log_in_as @carol
    visit edit_user_registration_path
    wait_for_turbo

    # Hold the submission's request in flight, so the in-flight state can be
    # looked at — and clicked again — before the server answers. At fetch()
    # rather than turbo:before-fetch-request: Turbo only disables the submitter
    # once that event has been let through.
    page.execute_script(<<~JS)
      const send = window.fetch
      window.fetch = (resource, options = {}) => {
        if ((options.method || "GET").toUpperCase() === "GET") return send(resource, options)
        window.fetch = send
        return new Promise((resolve) => { window.resumeHeldSubmission = resolve })
          .then(() => send(resource, options))
      }
    JS

    fill_password_form
    submit_password_form

    submit = find("#password-change input[type=submit]")
    assert_predicate submit, :disabled?
    assert_equal I18n.t("devise.registrations.edit.password_submitting"), submit.value
    submit.click
    page.execute_script("window.resumeHeldSubmission()")

    assert_selector ".form-success"
    assert_equal 1, emails_to(@carol.email).size
  end

  # --- User Story 2 -----------------------------------------------------------

  test "every other browser is signed out, and this one stays signed in" do
    Capybara.using_session(:other_browser) { log_in_as @carol }

    log_in_as @carol
    visit edit_user_registration_path
    fill_password_form
    submit_password_form
    assert_selector ".form-success"

    Capybara.using_session(:other_browser) { assert_signed_out_here }
    assert_signed_in_here
  end

  # US2-2: a browser kept signed in by its 30-day cookie alone, as after a
  # restart, is signed out as well.
  test "a remembered browser elsewhere is signed out too" do
    Capybara.using_session(:other_browser) do
      log_in_as @carol
      restart_browser_session
      assert_signed_in_here
    end

    log_in_as @carol
    visit edit_user_registration_path
    fill_password_form
    submit_password_form
    assert_selector ".form-success"

    Capybara.using_session(:other_browser) { assert_signed_out_here }
  end

  # FR-017, research.md R4: the browser that made the change keeps its own
  # 30-day cookie — re-issued, since the change invalidated it like every other.
  test "the browser that made the change is still remembered after a restart" do
    log_in_as @carol
    visit edit_user_registration_path
    fill_password_form
    submit_password_form
    assert_selector ".form-success"

    restart_browser_session
    assert_signed_in_here
  end

  # --- User Story 3 -----------------------------------------------------------

  # FR-015, clarification Q2: caught while typing, held back on submit, and
  # nothing typed is lost.
  test "a too-short or mismatched new password is flagged before anything is sent" do
    log_in_as @carol
    visit edit_user_registration_path
    wait_for_turbo

    fill_password_form(password: "short", confirmation: "shorter")
    find_field("New password").send_keys(:tab)
    find_field("Confirm new password").send_keys(:tab)

    too_short = "New password #{I18n.t('activemodel.errors.models.password_change.attributes.password.too_short', count: 8)}"
    mismatch = "Confirm new password #{I18n.t('activemodel.errors.models.password_change.attributes.password_confirmation.confirmation')}"
    within "#password-change" do
      assert_selector "#password_change_password_error", text: too_short, visible: true
      assert_selector "#password_change_password_confirmation_error", text: mismatch, visible: true
    end

    submit_password_form

    assert_no_selector "#error_explanation"
    assert focused_element_matches?("#password_change_password"), "focus should go to the first field to fix"
    assert_field "Current password", with: VALID_PASSWORD
    assert_field "New password", with: "short"
    assert_field "Confirm new password", with: "shorter"
    assert @carol.reload.valid_password?(VALID_PASSWORD)
  end

  # US3-1, US3-5, US3-6, analyze I1: the server's refusal is announced and
  # focused, tied to its field, confined to the password card, and every
  # password field comes back empty.
  test "a wrong current password is explained on its field and the fields come back empty" do
    log_in_as @carol
    visit edit_user_registration_path

    fill_password_form(current: "not-my-password")
    submit_password_form

    within "#password-change" do
      assert_selector "#error_explanation[role=alert]"
      assert_selector "#password_change_current_password_error",
                      text: I18n.t("activemodel.errors.models.password_change.attributes.current_password.invalid")
      assert_field "Current password", with: ""
      assert_field "New password", with: ""
      assert_field "Confirm new password", with: ""
    end
    assert focused_element_matches?("#error_explanation"), "the error summary should have focus (FR-012)"
    within(".card", text: I18n.t("devise.registrations.edit.email_section_title")) do
      assert_no_selector "#error_explanation"
    end
  end

  # US3-7, FR-008: the fifth wrong guess closes the form for 15 minutes; the
  # session and the rest of the site are untouched.
  test "after five wrong current passwords the form waits, and the user stays signed in" do
    @carol.update_columns(password_change_failed_attempts: 4)
    log_in_as @carol
    visit edit_user_registration_path

    fill_password_form(current: "not-my-password")
    submit_password_form
    assert_selector "#error_explanation"

    fill_password_form
    submit_password_form

    assert_selector "#password_change_current_password_error",
                    text: I18n.t("activemodel.errors.models.password_change.attributes.current_password.throttled", count: 15)
    assert @carol.reload.valid_password?(VALID_PASSWORD)

    visit root_path
    assert_text "Welcome to LockSwap"
  end

  # FR-019, research.md R9: a form submitted from a session that was signed out
  # in the meantime changes nothing, and signing in comes back here.
  test "a session ended elsewhere changes nothing and returns to the account page after sign-in" do
    log_in_as @carol
    visit edit_user_registration_path
    wait_for_turbo

    Capybara.using_session(:other_browser) do
      log_in_as @carol
      visit edit_user_registration_path
      fill_password_form
      submit_password_form
      assert_selector ".form-success"
    end

    fill_password_form(current: NEW_PASSWORD, password: "yetanother789")
    submit_password_form

    assert_current_path new_user_session_path
    fill_in_reliably "Email", with: @carol.email
    fill_in_reliably "Password", with: NEW_PASSWORD
    click_on "Log in"

    assert_current_path edit_user_registration_path
    assert @carol.reload.valid_password?(NEW_PASSWORD)
  end

  # --- Accessibility (FR-027, constitution III) -------------------------------

  test "the account page is accessible empty, refused and after a change" do
    log_in_as @carol
    visit edit_user_registration_path
    assert_axe_clean
    assert_tab_order_follows_visual_order

    fill_password_form(current: "not-my-password")
    submit_password_form
    assert_selector "#error_explanation"
    assert_axe_clean

    fill_password_form
    submit_password_form
    assert_selector ".form-success"
    assert_axe_clean

    with_viewport(:phone) { assert_no_horizontal_overflow "the account page after a change" }
  end
end
