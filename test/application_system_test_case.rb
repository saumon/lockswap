require "test_helper"
require "axe/api"
require "axe/core"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Tells chromedriver where Chrome is, which Rails otherwise leaves it to guess.
  #
  # Rails resolves the chromedriver path eagerly — Browser#preload, so parallel
  # workers do not race to download it — and assigns it to Service.driver_path.
  # Selenium's DriverFinder then short-circuits on that path for the rest of the
  # run (paths_from_service), returning a driver path and nothing else: the
  # browser path Selenium Manager hands back alongside it is dropped, so
  # options.binary is never set and chromedriver is left to find Chrome itself.
  #
  # It finds one on any machine with a system install, which is why CI and most
  # laptops never see this. Where the only Chrome is the one Selenium Manager
  # downloaded into ~/.cache/selenium — no system install, the common case under
  # WSL — there is nothing on PATH to find and every system test dies before it
  # starts, on "session not created: cannot find Chrome binary".
  #
  # Asking Selenium Manager directly bypasses the short-circuit. Where a system
  # Chrome does exist this resolves to it and changes nothing; CHROME_BIN is
  # there to point at a specific build without editing this file.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.binary ||= ENV["CHROME_BIN"].presence || begin
      Selenium::WebDriver::SeleniumManager.binary_paths("--browser", "chrome")["browser_path"]
    rescue StandardError => e
      # Leave it unset rather than failing here: where Chrome is on PATH,
      # chromedriver still finds it on its own and the run is unaffected.
      Rails.logger.debug { "Selenium Manager could not resolve a Chrome binary: #{e.message}" }
      nil
    end
  end

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

  # 008 FR-028: every screen is audited for accessibility as part of the standard
  # suite, so a violation blocks merge rather than waiting to be noticed.
  #
  # axe-core-api ships no Minitest matcher — be_axe_clean is RSpec-only — so this
  # wraps the plain API. Capybara's `page` is handed straight to Axe::Core, whose
  # wrap_driver unwraps anything responding to #driver.
  #
  #   within:    audit only part of the page, for screens not yet restyled
  #   excluding: drop a subtree from the audit
  #   skipping:  drop a rule, which needs a comment at the call site saying why
  def assert_axe_clean(within: nil, excluding: nil, skipping: nil)
    # Audit the settled page. The entrance animation fades content in over a few
    # hundred milliseconds, and axe measures whatever colour is on screen at the
    # moment it runs — mid-fade that is the text blended into the background,
    # which reports a contrast failure that no reader ever sees. Waiting is not
    # papering over anything: the settled state is the state being asserted.
    wait_for_entrance

    exclusions = Array(excluding) + [ LOGOTYPE ]

    # Pass one: every rule, everywhere except the wordmark.
    audit_page(within:, excluding: exclusions, skipping:)

    # Pass two: the wordmark, under every rule except colour contrast.
    #
    # The brand green is #0AB486, which is 2.66:1 on white — below both the
    # 4.5:1 text bar and the 3:1 non-text bar. It stays that colour because
    # WCAG 2.1 SC 1.4.3 exempts "text that is part of a logo or brand name"
    # from the contrast requirement, and this is the wordmark. axe cannot know
    # an element is a logotype, so the exemption has to be stated here.
    #
    # The exemption is deliberately narrow: one rule, one element. Every other
    # rule still applies to the wordmark, and every other element on the page
    # is still held to contrast — including anything else green, which uses
    # --color-accent (#07795A, 5.40:1) precisely because this exemption does
    # not extend to it.
    audit_page(within: LOGOTYPE, skipping: Array(skipping) + [ "color-contrast" ]) if page.has_css?(LOGOTYPE, wait: 0)
  end

  # FR-015b: restructuring a layout is allowed, but the keyboard must still walk
  # it in the order the eye does. Driving this with real Tab presses rather than
  # reading the DOM is the point — tabindex, disabled and visibility all change
  # what is reachable, and only the browser knows the true answer.
  def assert_tab_order_follows_visual_order(row_tolerance: 24)
    rects = keyboard_tab_rects
    assert_operator rects.size, :>=, 2, "expected at least two focusable elements on the page"

    rects.each_cons(2) do |a, b|
      same_row = (b["top"] - a["top"]).abs <= row_tolerance
      ordered = same_row ? b["left"] >= a["left"] : b["top"] > a["top"]

      assert ordered,
        "tab order jumps backwards: #{a["name"].inspect} at (#{a["top"]},#{a["left"]}) " \
        "then #{b["name"].inspect} at (#{b["top"]},#{b["left"]})"
    end
  end

  # The brand wordmark, which carries the one documented axe exemption.
  LOGOTYPE = ".brand-wordmark".freeze

  # Blocks until Turbo has replaced its cached preview with the real page.
  #
  # Turbo Drive paints a cached snapshot first and marks it with
  # <html data-turbo-preview> while the fresh copy is still in flight. A click
  # that lands on the preview acts on a DOM about to be thrown away: a disclosure
  # opened there is closed again the moment the real page arrives, and the test
  # then fails looking for a field that is present but hidden. Waiting for the
  # attribute to clear removes the race at its source rather than retrying
  # around it.
  def wait_for_turbo(timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

    loop do
      previewing = page.evaluate_script(
        "document.documentElement.hasAttribute('data-turbo-preview')"
      )
      return unless previewing
      return if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
  end

  # Emulates the OS "reduce motion" preference for the rest of the test.
  # Chromium's driver carries DriverExtensions::HasCDP, so this is available
  # without any extra gem.
  #
  # The emulation is cleared in teardown. The browser is shared across tests in
  # this single-worker suite, so leaving it set would silently put every later
  # test into reduced motion — and a test asserting motion exists would then
  # pass for the wrong reason.
  def emulate_reduced_motion
    @emulated_media = true
    page.driver.browser.execute_cdp(
      "Emulation.setEmulatedMedia",
      features: [ { name: "prefers-reduced-motion", value: "reduce" } ]
    )
  end

  # 012 FR-022: the viewports this feature is held to. One breakpoint at 48rem
  # (768px) separates the narrow treatment from the wide one, so :phone is a
  # width that is unambiguously below it and :desktop one unambiguously above —
  # :desktop is the suite's existing screen_size, so every test that does not
  # ask for a viewport keeps running at exactly the size it always did.
  #
  # :minimum is the 320px floor from FR-022a. It is swept for overflow only: it
  # is the width where a layout breaks first, and it is not otherwise sampled.
  VIEWPORTS = {
    minimum: [ 320, 568 ],
    phone: [ 390, 844 ],
    desktop: [ 1400, 1400 ]
  }.freeze

  # Runs the block with the viewport overridden to one of VIEWPORTS.
  #
  # This drives the *viewport*, not the OS window. resize_to sets the outer
  # window, which leaves the viewport smaller by whatever the browser chrome
  # happens to occupy — an unknown offset, and useless for a test whose entire
  # subject is a breakpoint at an exact width. setDeviceMetricsOverride sets the
  # number media queries actually read.
  #
  # Cleared in teardown for the same reason emulate_reduced_motion is: the
  # browser is shared across tests in this single-worker suite, so a leaked
  # override would silently put every later test at phone width — and a test
  # asserting the desktop bar would then fail for a reason that has nothing to
  # do with the code under test.
  def with_viewport(name)
    width, height = VIEWPORTS.fetch(name)
    @emulated_metrics = true
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 0, mobile: name != :desktop
    )
    yield
  ensure
    clear_viewport_override
  end

  # FR-001 / FR-022a: the page itself must never scroll sideways. The table is
  # allowed its own scroll container above the breakpoint; the document is not.
  def assert_no_horizontal_overflow(context = nil)
    overflow = page.evaluate_script(<<~JS)
      (() => {
        const el = document.documentElement;
        return { scroll: el.scrollWidth, client: el.clientWidth };
      })()
    JS

    assert_operator overflow["scroll"], :<=, overflow["client"],
      "page scrolls horizontally#{" at #{context}" if context}: " \
      "scrollWidth #{overflow["scroll"]} exceeds clientWidth #{overflow["client"]}"
  end

  # FR-007 / FR-025: standalone controls have to be a real target under a thumb.
  #
  # Measured rather than asserted by inspection, and scoped to the controls the
  # requirement actually names. Links sitting inline in a sentence are exempt
  # (FR-007a) — a 44px-tall link inside a paragraph would wreck the line
  # spacing, which is why the recognised target-size guidance carves them out.
  # checkVisibility rather than a rect test. A control inside a closed <details>,
  # or inside the treatment container that is display:none at this width, still
  # reports a bounding box — measuring those would fail this assertion on
  # controls no one can reach, and would have hidden the ones that matter.
  STANDALONE_CONTROLS = ".btn, .site-nav-link, summary, input[type=submit], button".freeze
  INLINE_LINK_EXEMPT = ".auth-link".freeze

  def assert_touch_targets_at_least(minimum = 44)
    # Measure the settled page, for the same reason assert_axe_clean does.
    # Content fades in, and checkVisibility(checkOpacity: true) reports an
    # element mid-fade as not visible — so a control measured too early is not
    # measured at all, and the assertion quietly has nothing to check. The
    # signed-in screens happened to be past their entrance by the time the
    # assertion ran; the auth screens, which carry the longer brand flourish,
    # were not.
    wait_for_entrance

    measured = page.evaluate_script(<<~JS)
      (() => {
        const exempt = #{INLINE_LINK_EXEMPT.inspect};
        return Array.from(document.querySelectorAll(#{STANDALONE_CONTROLS.inspect}))
          .filter(el => !el.matches(exempt) && !el.closest(exempt))
          .filter(el => el.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true }))
          .map(el => {
            const r = el.getBoundingClientRect();
            const name = (el.innerText || el.value || el.getAttribute("aria-label") || el.tagName || "").trim();
            return { name: name.slice(0, 40), w: Math.round(r.width), h: Math.round(r.height) };
          });
      })()
    JS

    # Without this, a page where the selector matched nothing — or where the
    # visibility filter turned out to reject everything — would pass this
    # assertion silently, and would keep passing after the rule it is meant to
    # protect had been deleted.
    assert_not_empty measured,
      "no standalone controls were measured; the assertion would pass vacuously"

    undersized = measured.select { |t| t["w"] < minimum || t["h"] < minimum }

    assert_empty undersized,
      "controls below the #{minimum}px touch target: " +
        undersized.map { |t| "#{t["name"].inspect} #{t["w"]}x#{t["h"]}" }.join(", ")
  end

  # 022: a label and its value read as one line when their vertical centers
  # coincide — measured rather than assumed, the same way keyboard_tab_rects
  # measures reading order instead of trusting DOM position alone.
  def assert_same_line(a, b, context = nil)
    rect_a = element_rect(a)
    rect_b = element_rect(b)

    assert_in_delta (rect_a["top"] + rect_a["bottom"]) / 2.0,
      (rect_b["top"] + rect_b["bottom"]) / 2.0, 4,
      "expected #{a.inspect} and #{b.inspect} to sit on the same line#{" (#{context})" if context}"
  end

  # The inverse of assert_same_line: top_selector's box ends at or above
  # bottom_selector's box starts, i.e. label-above-value rather than inline.
  def assert_stacked(top_selector, bottom_selector, context = nil)
    top_rect = element_rect(top_selector)
    bottom_rect = element_rect(bottom_selector)

    assert_operator top_rect["bottom"], :<=, bottom_rect["top"] + 1,
      "expected #{top_selector.inspect} to sit above #{bottom_selector.inspect}#{" (#{context})" if context}"
  end

  teardown do
    if @emulated_media
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
      @emulated_media = nil
    end

    clear_viewport_override
  end

  # 012: safe to call when nothing is overridden, so teardown does not have to
  # know whether the test used with_viewport.
  def clear_viewport_override
    return unless @emulated_metrics

    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    @emulated_metrics = nil
  end

  # Chrome reports a 0.01ms duration as "1e-05s", so compare numerically rather
  # than against a spelling.
  def seconds_in(css_duration)
    css_duration.to_s.split(",").first.to_s.strip.sub(/s\z/, "").to_f
  end

  private

    # Blocks until the page entrance has finished, so colours are measured at
    # their final values. Returns immediately on a page with no entrance.
    #
    # "Finished" means every animation that is going to finish has: the entrance
    # is staggered across descendants — the tagline on the full-brand screens
    # starts 340ms in and is real text that the colour-contrast audit reads — so
    # this deliberately waits on the whole document rather than on .page-enter's
    # own animations, and stopping at the wrapper would measure text mid-fade.
    #
    # Animations declared to loop forever (011: the brand mark's pulse, which is
    # on screen on every page) are excluded rather than waited for. They never
    # reach a non-running state, so including them would turn every call into a
    # full `timeout` stall, and they are perpetual by design: there is no settled
    # state of theirs to wait for.
    def wait_for_entrance(timeout: 5)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

      loop do
        settled = page.evaluate_script(<<~JS)
          (() => {
            const el = document.querySelector(".page-enter");
            if (!el) return true;
            if (typeof document.getAnimations !== "function") return true;
            return document.getAnimations()
              .filter(a => a.effect.getTiming().iterations !== Infinity)
              .every(a => a.playState !== "running");
          })()
        JS

        return if settled
        return if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.05
      end
    end

    def element_rect(selector)
      page.evaluate_script(<<~JS)
        (() => {
          const el = document.querySelector(#{selector.to_json});
          const r = el.getBoundingClientRect();
          return { top: r.top, bottom: r.bottom, left: r.left, right: r.right };
        })()
      JS
    end

    def audit_page(within: nil, excluding: nil, skipping: nil)
      run = Axe::API::Run.new.according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
      run = run.within(*Array(within)) if within
      run = run.excluding(*Array(excluding)) if excluding.present?
      run = run.skipping(*Array(skipping)) if skipping.present?

      audit = Axe::Core.new(page).call(run)
      assert audit.passed?, audit.failure_message
    end

    # Walks the page with real Tab presses, returning the position and a readable
    # name for each element the keyboard reaches inside <main>, in the order it
    # reaches them.
    #
    # Scoped to the content of <main> deliberately, and fixed overlays are
    # skipped. The header banner and the notification overlay are both pinned to
    # the viewport, so their coordinates say nothing about the reading order of
    # the document; and the walk wraps back round to the header once it runs off
    # the end of the content. The notification also dismisses itself after a few
    # seconds, so counting it would make the walk depend on timing.
    def keyboard_tab_rects(limit: 60)
      # Reset sequential focus navigation to the start of the document. Clicking
      # the body is not enough: Chrome resumes tabbing from wherever the click
      # landed, so the walk would start in the middle of the page.
      page.execute_script(<<~JS)
        document.body.setAttribute("tabindex", "-1");
        document.body.focus();
        document.body.removeAttribute("tabindex");
        window.scrollTo(0, 0);
      JS

      rects = []
      entered_main = false

      limit.times do
        page.driver.browser.action.send_keys(:tab).perform
        focused = page.evaluate_script(<<~JS)
          (() => {
            const el = document.activeElement;
            if (!el || el === document.body) return null;
            const r = el.getBoundingClientRect();
            const name = (el.innerText || el.value || el.getAttribute("aria-label") || el.tagName || "").trim();
            const overlay = el.closest("[role=status], [role=alert]") ||
                            (el.closest("main > div") && getComputedStyle(el.closest("main > div")).position === "fixed");
            return {
              inMain: !!el.closest("main") && !overlay,
              top: Math.round(r.top),
              left: Math.round(r.left),
              name: name.slice(0, 40)
            };
          })()
        JS

        break if focused.nil?

        if focused["inMain"]
          entered_main = true
          rects << focused.slice("top", "left", "name")
        elsif entered_main
          break # walked off the end of the content and back into the chrome
        end
      end

      rects
    end

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

      # The browser is shared across this single-worker suite, so the homepage is
      # usually in Turbo's cache by the time anyone logs in. Turbo paints that
      # cached copy as a preview and replaces it a moment later with the real
      # response — and "Welcome to LockSwap" is in both, so the assertion above
      # can match the preview and let a test start interacting with a DOM that is
      # about to be thrown away.
      #
      # This closes that window, so every test that logs in starts from the page
      # it thinks it is looking at. It is not a proven cure for the suite's
      # residual flakiness — that survives this change — but the race is real and
      # this is where it belongs.
      wait_for_turbo
    end

    # Drops the session (non-persistent) cookie and leaves the persistent
    # "remember me" cookie in place — what closing and reopening a browser does.
    def restart_browser_session
      page.driver.browser.manage.delete_cookie(Rails.application.config.session_options[:key])
    end
end
