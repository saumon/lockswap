require "application_system_test_case"
require "timeout"

# 008 User Story 3: motion that makes the product feel responsive, and vanishes
# entirely for anyone who has asked their system for less of it.
#
# These assertions are written so they FAIL before the motion work lands, as
# Constitution Principle II requires: before it, no component carries a
# transition at all, so both the "there is motion" and the "motion is
# suppressed" cases are false rather than vacuously true.
class MotionTest < ApplicationSystemTestCase
  setup do
    @user = users(:carol)
  end

  # FR-017: interactive elements respond to hover and keyboard focus.
  test "interactive components carry a transition at rest" do
    log_in_as @user
    visit locker_wishes_path

    assert_operator seconds_in(transition_duration_of(".btn")), :>, 0.01,
      "expected the button component to carry a real transition (FR-017)"
  end

  # FR-020: the reduced-motion preference suppresses it again.
  test "reduced motion collapses every transition" do
    emulate_reduced_motion
    log_in_as @user
    visit locker_wishes_path

    assert_operator seconds_in(transition_duration_of(".btn")), :<, 0.001,
      "expected motion to be suppressed under prefers-reduced-motion (FR-020)"
  end

  # FR-020 / SC-006: and the interface is still entirely usable without it.
  test "every control and every piece of information survives reduced motion" do
    emulate_reduced_motion
    log_in_as users(:bob)

    assert_text "Welcome to LockSwap"
    assert_selector "#swap-proposals-received"
    within("#swap-proposals-received") { assert_selector "button", text: "Accept" }

    visit locker_wishes_path
    assert_selector "#locker-wish-list"
    assert_selector "input[type=submit][value='Save my wish']", visible: :all
  end

  # FR-016b: content is readable whether or not the entrance animation ran, so
  # the keyframe ends on its final state. SC-006b: and it gets there within the
  # 400ms bound, which is what keeps the entrance feeling instant rather than
  # like something the reader has to wait out.
  test "the page entrance settles to fully visible, within its bound" do
    log_in_as @user

    duration = seconds_in(page.evaluate_script(
      "getComputedStyle(document.querySelector('.page-enter')).animationDuration"
    ))
    assert_operator duration, :<=, 0.4, "page entrance must complete within 400ms (SC-006b)"

    settled = Timeout.timeout(5) do
      loop do
        opacity = page.evaluate_script("getComputedStyle(document.querySelector('.page-enter')).opacity")
        break opacity if opacity.to_f >= 1.0
        sleep 0.05
      end
    end

    assert_equal 1.0, settled.to_f
  end

  # SC-006b: interaction feedback settles within 200ms.
  test "interaction feedback settles within its bound" do
    log_in_as @user
    visit locker_wishes_path

    assert_operator seconds_in(transition_duration_of(".btn")), :<=, 0.2,
      "interaction feedback must settle within 200ms (SC-006b)"
  end

  # FR-016a / SC-006a: no scroll-triggered reveals. Content far down a long page
  # is already visible; scrolling is not what makes it appear.
  test "content further down the page is visible without scrolling to it" do
    20.times { |i| LockerWish.create!(user: User.create!(email: "filler#{i}@example.com", password: VALID_PASSWORD), floor: "#{i + 1}") }

    log_in_as @user
    visit locker_wishes_path

    last_row = all("#locker-wish-list tbody tr").last
    assert_equal "1", page.evaluate_script(
      "getComputedStyle(arguments[0]).opacity", last_row.native
    )
  end

  # FR-016a / SC-006a: navigating between screens plays no transition either.
  test "navigating between screens plays no page transition" do
    log_in_as @user
    click_on "Proposal history"

    assert_selector "#swap-proposal-history"
    assert_no_selector ".turbo-page-transition"
  end

  # 008 FR-022: the logo fades in on the full-brand screens, once, and settles
  # fully visible. Staged — mark, then wordmark, then tagline — so the brand
  # assembles rather than arriving all at once.
  #
  # 011 adds a second animation to the mark, the perpetual pulse. The entrance is
  # still a single pass and is still what this test is about; the pulse gets its
  # own tests below.
  test "the logo fades in on the sign-in screen and settles" do
    visit new_user_session_path

    # Asserted on the declaration rather than by watching playState: an animation
    # reports its final opacity a frame before it reports itself finished, so
    # polling for "nothing running" races the last frame for no added meaning.
    assert_equal "1", animations_on(".brand-mark-flourish").fetch("brand-fade-in")["iterations"],
      "the entrance itself must still be a single pass (008 FR-022)"

    # Wait for the whole entrance, not just the opacity: the blur runs on past the
    # point where the logo is fully opaque, and stopping at opacity would assert
    # against a logo that is still soft.
    wait_for_brand_entrance

    # By now the pulse is running, and more often than not it is mid-dip. Park it
    # at full opacity first: what this measures is where the entrance left the
    # brand, not where the loop happens to have got to.
    park_brand_pulse

    assert_equal [ 1.0, 1.0, 1.0 ], brand_opacities

    # It resolves sharp: a blur left behind would be a permanently soft logo.
    # The animation's fill holds the final keyframe, so this reads blur(0px)
    # rather than none — both mean no blur.
    assert_match(/\A(none|blur\(0(\.0+)?px\))\z/, page.evaluate_script(
      "getComputedStyle(document.querySelector('.brand-mark-flourish')).filter"
    ))
  end

  # The fade has to be long enough and gentle enough to actually read as one.
  # An earlier attempt reused --ease-out, which is cubic-bezier(0.16, 1, 0.3, 1)
  # and reaches ~90% of its value in the first quarter of its duration; the
  # entrance was over before the eye registered it had begun.
  test "the logo fade is slow enough to be seen" do
    visit new_user_session_path

    duration = seconds_in(page.evaluate_script(
      "getComputedStyle(document.querySelector('.brand-mark-flourish')).animationDuration"
    ))
    assert_operator duration, :>=, 0.8, "the brand entrance must be a visible fade, not a snap"

    # Caught mid-flight it is genuinely blurred, not merely slightly transparent.
    blur = page.evaluate_script(<<~JS)
      (() => {
        const m = document.querySelector('.brand-mark-flourish');
        m.getAnimations().forEach(a => { a.currentTime = 150; });
        return getComputedStyle(m).filter;
      })()
    JS
    assert_match(/blur\((1[0-9]|[89])[.\d]*px\)/, blur,
      "expected a pronounced blur partway through the fade, got #{blur}")
  end

  # 011 FR-001 / FR-004 / FR-005 / FR-006: once the entrance has had its one say,
  # the mark keeps breathing, so the brand stays the thing that catches the eye on
  # the screen a visitor meets first.
  test "the sign-in logo keeps pulsing after the entrance settles" do
    visit new_user_session_path

    declared = animations_on(".brand-mark-flourish")
    pulse = declared.fetch("brand-fade-pulse")

    assert_equal "infinite", pulse["iterations"], "the pulse must never stop (FR-005)"
    assert_in_delta 3.0, seconds_in(pulse["duration"]), 0.001,
      "one dim-and-brighten cycle is ~3s (FR-005)"

    # Chained to the entrance by delay rather than by an animationend listener:
    # the pulse's first frame lands exactly where the entrance's held final frame
    # already is, so the hand-off is invisible and the two never compound.
    assert_in_delta seconds_in(declared.fetch("brand-fade-in")["duration"]),
      seconds_in(pulse["delay"]), 0.001,
      "the loop must wait out the entrance before it starts (FR-006)"

    trough = at_pulse_trough(".brand-mark-flourish")

    assert_equal "0.6", trough["opacity"],
      "the mark dims to 60% at the bottom of the cycle, never further (FR-004)"
    assert_equal trough["before"], trough["at"],
      "the pulse must not move or resize the mark (FR-008)"
  end

  # FR-002: and the sign-up screen is the same screen as far as the brand is
  # concerned — both are full-brand, both get the loop.
  test "the sign-up logo keeps pulsing after the entrance settles" do
    visit new_user_registration_path

    assert_equal "infinite",
      animations_on(".brand-mark-flourish").fetch("brand-fade-pulse")["iterations"]

    trough = at_pulse_trough(".brand-mark-flourish")

    assert_equal "0.6", trough["opacity"]
    assert_equal trough["before"], trough["at"]
  end

  # FR-020 / FR-016b: a reduced-motion visitor gets no fade at all, rather than a
  # flattened one — the animation is not declared for them, so the logo is simply
  # painted at full opacity and can never be left invisible by an entrance that
  # failed to run.
  test "reduced motion shows the logo immediately, with no animation declared" do
    emulate_reduced_motion
    visit new_user_session_path
    assert_selector ".brand-stacked"

    assert_equal [ 1.0, 1.0, 1.0 ], brand_opacities

    # Exactly "none", which is also what makes this the 011 FR-007 assertion: the
    # pulse is declared in the same no-preference block as the entrance, so a
    # reduced-motion visitor gets neither. Anything else here — including a
    # flattened "brand-fade-pulse" — means the loop escaped the block.
    assert_equal "none", page.evaluate_script(
      "getComputedStyle(document.querySelector('.brand-mark-flourish')).animationName"
    )
    # And no blur left hanging on it either.
    assert_equal "none", page.evaluate_script(
      "getComputedStyle(document.querySelector('.brand-mark-flourish')).filter"
    )
  end

  # 011 FR-003: the header mark pulses too, so the brand is alive wherever it
  # appears rather than only on the way in.
  #
  # It still must not carry the entrance — a logo that fades up out of a blur on
  # every navigation is a tic rather than a flourish, which is why `flourish` and
  # `pulse` stayed two separate locals instead of one.
  test "the header mark pulses" do
    log_in_as @user

    declared = animations_on("header [data-brand-mark]")

    assert_equal [ "brand-fade-pulse" ], declared.keys,
      "the header mark loops, and does nothing else — no entrance (008 FR-022)"
    assert_equal "infinite", declared["brand-fade-pulse"]["iterations"]

    # Nothing in front of it to wait for, unlike the full-brand screens.
    assert_in_delta 0.0, seconds_in(declared["brand-fade-pulse"]["delay"]), 0.001

    trough = at_pulse_trough("header [data-brand-mark]")

    assert_equal "0.6", trough["opacity"]
    assert_equal trough["before"], trough["at"],
      "the pulse must not move or resize the header mark (FR-008)"
  end

  # FR-003: on every page, not just the one the user landed on.
  test "the header mark keeps pulsing across page navigation" do
    log_in_as @user
    assert_equal "infinite",
      animations_on("header [data-brand-mark]").fetch("brand-fade-pulse")["iterations"]

    click_on "Locker wishes"
    assert_selector "#locker-wish-list"

    assert_equal "infinite",
      animations_on("header [data-brand-mark]").fetch("brand-fade-pulse")["iterations"]
  end

  # FR-007: and the reduced-motion visitor gets a still header mark, for the same
  # reason and by the same mechanism as the full-brand screens above.
  test "reduced motion leaves the header mark still" do
    emulate_reduced_motion
    log_in_as @user

    assert_equal "none", page.evaluate_script(
      "getComputedStyle(document.querySelector('header [data-brand-mark]')).animationName"
    )
    assert_equal "1", page.evaluate_script(
      "getComputedStyle(document.querySelector('header [data-brand-mark]')).opacity"
    )
  end

  private

    # Every CSS animation declared on the first element matching `selector`, keyed
    # by name. The shorthand can declare more than one at a time — the full-brand
    # mark runs its one-off entrance and its perpetual pulse together — and
    # getComputedStyle reports those as parallel comma-separated lists, so reading
    # any single property in isolation tells you nothing about which animation it
    # belongs to.
    def animations_on(selector)
      page.evaluate_script(<<~JS, selector)
        (() => {
          const style = getComputedStyle(document.querySelector(arguments[0]));
          const parts = (value) => value.split(",").map(v => v.trim());
          const names = parts(style.animationName);
          const durations = parts(style.animationDuration);
          const delays = parts(style.animationDelay);
          const iterations = parts(style.animationIterationCount);
          return Object.fromEntries(names.map((name, i) => [ name, {
            duration: durations[i], delay: delays[i], iterations: iterations[i]
          } ]));
        })()
      JS
    end

    # Blocks until the brand entrance has finished. The pulse is excluded because
    # it never finishes by design — waiting on "every animation" would wait out
    # the timeout on every call.
    def wait_for_brand_entrance(timeout: 5)
      Timeout.timeout(timeout) do
        sleep 0.05 until page.evaluate_script(<<~JS)
          document.getAnimations()
            .filter(a => a.animationName !== 'brand-fade-pulse')
            .every(a => a.playState !== 'running')
        JS
      end
    end

    # Pins every pulse to the start of its delay — ahead of its first frame, where
    # the mark is at full opacity — and freezes it, so a measurement taken after
    # this is not racing the loop.
    def park_brand_pulse
      page.execute_script(<<~JS)
        document.getAnimations()
          .filter(a => a.animationName === 'brand-fade-pulse')
          .forEach(a => { a.currentTime = 0; a.pause(); });
      JS
    end

    # Winds the mark's pulse to the bottom of its cycle and reports both what the
    # dip costs in opacity and whether the box moved getting there. Opacity is the
    # only property the keyframes touch, so the two boxes must be identical.
    def at_pulse_trough(selector)
      page.evaluate_script(<<~JS, selector)
        (() => {
          const mark = document.querySelector(arguments[0]);
          const box = () => {
            const r = mark.getBoundingClientRect();
            return [ r.x, r.y, r.width, r.height ];
          };
          const before = box();
          const pulse = mark.getAnimations()
            .find(a => a.animationName === 'brand-fade-pulse');
          const timing = pulse.effect.getComputedTiming();
          pulse.currentTime = (timing.delay || 0) + (timing.duration / 2);
          pulse.pause();
          return { opacity: getComputedStyle(mark).opacity, before: before, at: box() };
        })()
      JS
    end

    def brand_opacities
      page.evaluate_script(<<~JS).map(&:to_f)
        ['.brand-mark-flourish', '.brand-stacked .brand-wordmark', '.brand-stacked .brand-tagline']
          .map(s => getComputedStyle(document.querySelector(s)).opacity)
      JS
    end

    def transition_duration_of(selector)
      page.evaluate_script(
        "getComputedStyle(document.querySelector(arguments[0])).transitionDuration", selector
      )
    end
end
