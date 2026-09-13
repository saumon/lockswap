require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # One process, whatever the suite grows to. Minitest parallelises past 50 tests,
  # and 003 pushed the system suite over that line: eleven workers meant eleven
  # Pumas and eleven browsers competing for the same cores, and tests started
  # failing on expired waits instead of on behaviour. These tests were written —
  # and their timings tuned in 002 — for a browser that gets the machine to
  # itself. The unit suite still parallelises; it is fast and has no browser.
  parallelize(workers: 1)

  # Capybara's 2-second default is tight for a Selenium + Puma + Turbo round trip
  # and produced intermittent failures — a login that had not landed yet read as a
  # login that had failed. Waiting longer costs nothing when the page is ready.
  Capybara.default_max_wait_time = 5

  private

    # ChromeDriver drops keystrokes when the machine is busy: they are reported
    # as delivered, the field stays empty, and the form then submits blank — the
    # failure surfacing later, somewhere that has nothing to do with typing.
    # Measured on a loaded machine at roughly one interaction in ten, on plain
    # fields of fully loaded pages, the application never involved.
    #
    # Retyping is safe because the value is checked: a field the application
    # itself cleared would still fail the assertion below rather than be papered
    # over, so this cannot hide a real defect.
    def fill_in_reliably(locator, with:)
      3.times do
        fill_in locator, with: with
        return if has_field?(locator, with: with, wait: 1)
      end

      assert_field locator, with: with
    end

    # Logs in through the real form, then waits for the homepage so that the
    # browser has actually applied the session cookies before the test moves on.
    def log_in_as(user, password: VALID_PASSWORD)
      visit new_user_session_path
      fill_in_reliably "Email", with: user.email
      fill_in_reliably "Password", with: password
      click_on "Log in"
      assert_text "Welcome to LockSwap"
    end

    # Drops the session (non-persistent) cookie and leaves the persistent
    # "remember me" cookie in place — what closing and reopening a browser does.
    def restart_browser_session
      page.driver.browser.manage.delete_cookie(Rails.application.config.session_options[:key])
    end
end
