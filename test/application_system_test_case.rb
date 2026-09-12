require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  private

    # Logs in through the real form, then waits for the homepage so that the
    # browser has actually applied the session cookies before the test moves on.
    def log_in_as(user, password: VALID_PASSWORD)
      visit new_user_session_path
      fill_in "Email", with: user.email
      fill_in "Password", with: password
      click_on "Log in"
      assert_text "Welcome to LockSwap"
    end

    # Drops the session (non-persistent) cookie and leaves the persistent
    # "remember me" cookie in place — what closing and reopening a browser does.
    def restart_browser_session
      page.driver.browser.manage.delete_cookie(Rails.application.config.session_options[:key])
    end
end
