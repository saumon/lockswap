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

  # FR-022: the logo fades in on the full-brand screens, once, and settles fully
  # visible. Staged — mark, then wordmark, then tagline — so the brand assembles
  # rather than arriving all at once.
  test "the logo fades in on the sign-in screen and settles" do
    visit new_user_session_path

    assert_equal "brand-fade-in", page.evaluate_script(
      "getComputedStyle(document.querySelector('.brand-mark-flourish')).animationName"
    )

    # Wait for the whole entrance, not just the opacity: the blur runs on past the
    # point where the logo is fully opaque, and stopping at opacity would assert
    # against a logo that is still soft.
    Timeout.timeout(5) do
      sleep 0.05 until page.evaluate_script(
        "document.getAnimations().every(a => a.playState !== 'running')"
      )
    end

    assert_equal [ 1.0, 1.0, 1.0 ], brand_opacities

    # Asserted on the declaration rather than by watching playState: an animation
    # reports its final opacity a frame before it reports itself finished, so
    # polling for "nothing running" races the last frame for no added meaning.
    assert_equal "1", page.evaluate_script(
      "getComputedStyle(document.querySelector('.brand-mark-flourish')).animationIterationCount"
    ), "the flourish must play once, never loop (FR-022)"

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

  # FR-020 / FR-016b: a reduced-motion visitor gets no fade at all, rather than a
  # flattened one — the animation is not declared for them, so the logo is simply
  # painted at full opacity and can never be left invisible by an entrance that
  # failed to run.
  test "reduced motion shows the logo immediately, with no animation declared" do
    emulate_reduced_motion
    visit new_user_session_path
    assert_selector ".brand-stacked"

    assert_equal [ 1.0, 1.0, 1.0 ], brand_opacities
    assert_equal "none", page.evaluate_script(
      "getComputedStyle(document.querySelector('.brand-mark-flourish')).animationName"
    )
    # And no blur left hanging on it either.
    assert_equal "none", page.evaluate_script(
      "getComputedStyle(document.querySelector('.brand-mark-flourish')).filter"
    )
  end

  # The header mark must not fade: a logo that animates on every navigation is a
  # tic rather than a flourish.
  test "the header mark does not fade" do
    log_in_as @user

    assert_equal "none", page.evaluate_script(
      "getComputedStyle(document.querySelector('header [data-brand-mark]')).animationName"
    )
  end

  private

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
