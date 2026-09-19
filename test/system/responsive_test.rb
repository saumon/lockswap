require "application_system_test_case"

# 012: the responsive behaviour of the site, asserted at the viewports the
# feature is held to (FR-022).
#
# The breakpoint is a single value — 48rem / 768px — and it is exact: 767px is
# the narrow treatment, 768px is the wide one (FR-018b). Everything here is
# therefore written against a specific width rather than against "mobile" or
# "desktop" as a vibe, and with_viewport drives the viewport itself so those
# widths mean what they say.
class ResponsiveTest < ApplicationSystemTestCase
  setup do
    @user = users(:carol)
  end

  # --- The helper itself ----------------------------------------------------

  # Proves with_viewport actually moves the number media queries read, before
  # anything else relies on it. A helper that silently did nothing would make
  # every assertion below pass at whatever width the suite happens to run.
  test "with_viewport drives the width that media queries see" do
    visit new_user_session_path

    with_viewport(:phone) do
      assert page.evaluate_script('matchMedia("(max-width: 47.999rem)").matches'),
        "expected the narrow treatment at the phone viewport"
      assert_equal 390, page.evaluate_script("document.documentElement.clientWidth")
    end

    with_viewport(:desktop) do
      assert page.evaluate_script('matchMedia("(min-width: 48rem)").matches'),
        "expected the wide treatment at the desktop viewport"
    end
  end

  # --- The breakpoint (FR-018, FR-018a, FR-018b) ----------------------------

  # The boundary is exact, not approximate. 767px is narrow, 768px is wide, and
  # there is no width in between that behaves as neither. Asserted through
  # .detail-grid because that is the one rule that already switched on width —
  # 012 FR-018a moved it from 40rem to the one breakpoint, and this is what
  # would catch it being moved back or left behind.
  test "the breakpoint is exactly 768px, with nothing in between" do
    log_in_as @user
    visit root_path

    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: 767, height: 900, deviceScaleFactor: 0, mobile: true
    )
    @emulated_metrics = true
    assert_equal 1, detail_grid_columns, "767px must get the narrow treatment"

    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: 768, height: 900, deviceScaleFactor: 0, mobile: false
    )
    assert_equal 2, detail_grid_columns, "768px must get the wide treatment"
  ensure
    clear_viewport_override
  end

  # --- The data lists (FR-005) ----------------------------------------------

  # 019: @user (carol) has an active wish (floor "5") nobody currently occupies,
  # so a bare visit would auto-fill "Their floor" to "5" and empty the list —
  # unrelated to the breakpoint behaviour this test checks. Neutralised.
  test "the wish list is stacked cards on a phone and a table on a desktop" do
    log_in_as @user
    visit locker_wishes_path(current_floor: "")
    assert_selector ".data-table tbody tr", minimum: 1

    with_viewport(:phone) do
      assert_equal "block", computed_display(".data-table tbody tr"),
        "records must render as stacked cards below the breakpoint"
      # Clipped, not removed. Every cell carries its own label in this form, so
      # the header is visually redundant — but the <th> cells have to stay in
      # the accessibility tree, which display:none would take them out of
      # (FR-005d). So the assertion is "occupies no space", not "is gone".
      header_box = page.evaluate_script(
        "document.querySelector('.data-table thead').getBoundingClientRect().height"
      )
      assert_operator header_box, :<=, 1,
        "the header row must take up no space in the card form"
      assert_selector ".data-table thead th", visible: :all, minimum: 1
    end

    with_viewport(:desktop) do
      assert_equal "table-row", computed_display(".data-table tbody tr"),
        "records must render as table rows at and above the breakpoint"
    end
  end

  # FR-005a: every value carries a visible label naming the column it came from,
  # and that label is the column's own heading rather than a second wording that
  # could drift away from it.
  test "every cell is labelled with the text of its column heading" do
    log_in_as @user
    visit locker_wishes_path

    mismatches = page.evaluate_script(<<~JS)
      (() => {
        const headings = Array.from(document.querySelectorAll(".data-table thead th"))
          .map(th => th.textContent.trim());
        const bad = [];
        document.querySelectorAll(".data-table tbody tr").forEach(row => {
          Array.from(row.children).forEach((cell, i) => {
            const label = cell.getAttribute("data-label");
            if (label !== headings[i]) bad.push({ index: i, label: label, heading: headings[i] });
          });
        });
        return bad;
      })()
    JS

    assert_empty mismatches,
      "data-label must match its column heading exactly: " + mismatches.inspect
  end

  # SC-004a / FR-005b: the point of the restack. "Propose swap" is the primary
  # action of the product, and on a phone it has to be on screen rather than
  # behind a sideways swipe nobody discovers.
  # 019: as above — @user (carol)'s wish floor matches nobody, so the list must
  # be explicitly unfiltered for this test's unrelated assertion to hold.
  test "the propose-swap control is on screen at phone width" do
    log_in_as @user
    visit locker_wishes_path(current_floor: "")

    with_viewport(:phone) do
      assert_button "Propose swap"
      assert_no_horizontal_overflow "the locker wishes list"

      within_viewport = page.evaluate_script(<<~JS)
        (() => {
          const btn = Array.from(document.querySelectorAll("input[type=submit], button"))
            .find(el => (el.value || el.textContent).trim() === "Propose swap");
          if (!btn) return null;
          const r = btn.getBoundingClientRect();
          return r.left >= 0 && r.right <= document.documentElement.clientWidth;
        })()
      JS

      assert_equal true, within_viewport,
        "Propose swap must sit inside the viewport, not off its right edge"
    end
  end

  # 017 FR-023: the filters are a row of links, so the narrow treatment is that
  # they wrap. Asserted the way the rest of this file asserts it — by measuring
  # that nothing escapes the viewport — rather than by reading the stylesheet.
  test "the floor filters wrap rather than overflow at phone width" do
    log_in_as @user
    visit locker_wishes_path

    with_viewport(:phone) do
      assert_selector "#locker-wish-filters"
      assert_no_horizontal_overflow "the locker wishes filters"

      escaping = page.evaluate_script(<<~JS)
        (() => {
          const limit = document.documentElement.clientWidth;
          return Array.from(document.querySelectorAll("#locker-wish-filters a"))
            .filter(el => {
              const r = el.getBoundingClientRect();
              return r.left < 0 || r.right > limit;
            })
            .map(el => el.textContent.trim());
        })()
      JS

      assert_empty escaping, "floor choices escaping the viewport: #{escaping.inspect}"
    end
  end

  # And they are still usable once wrapped: choosing one narrows the list at phone
  # width exactly as it does at desktop width.
  #
  # 019: @user (carol)'s wish floor ("5") would otherwise auto-fill "Their
  # floor" and exclude bob (current floor "3") once looking-for is narrowed to
  # "7" — this test is about the looking-for axis, so current_floor is
  # neutralised explicitly.
  test "a floor filter still works at phone width" do
    log_in_as @user
    visit locker_wishes_path(current_floor: "")

    with_viewport(:phone) do
      within("#locker-wish-filter-looking-for") { click_on "7" }

      assert_selector "#locker-wish-row-#{users(:bob).id}"
      assert_no_selector "#locker-wish-row-#{users(:karl).id}"
    end
  end

  test "the proposal history is stacked cards on a phone" do
    log_in_as users(:bob)
    visit locker_swap_proposals_path
    assert_selector ".data-table tbody tr", minimum: 1

    with_viewport(:phone) do
      assert_equal "block", computed_display(".data-table tbody tr")
      assert_no_horizontal_overflow "the proposal history"
    end
  end

  # 013: the administrator's users screen is a table too, so it owes FR-005 the
  # same debt as the two above — one labelled card per account below the
  # breakpoint, the table above it. frank because he is the only account that can
  # open the screen at all.
  test "the users screen is stacked cards on a phone and a table on a desktop" do
    log_in_as users(:frank)
    visit admin_users_path
    assert_selector ".data-table tbody tr", minimum: 1

    with_viewport(:phone) do
      assert_equal "block", computed_display(".data-table tbody tr")
      assert_no_horizontal_overflow "the users screen"
    end

    with_viewport(:desktop) do
      assert_equal "table-row", computed_display(".data-table tbody tr")
    end
  end

  # 015: the screen gained a fourth column and the Role cell gained a second line
  # of text beneath the badge. Both are the kind of change that fits a desktop
  # table and then pushes a phone sideways, which is exactly what FR-001 forbids —
  # and the row carrying the longest provenance line is the one to measure.
  # 015: the card form lays each cell out as label-then-value, and takes every
  # child of the cell as its own item — so the provenance line, added beneath the
  # badge, wrapped onto the next row and landed in the *label* column, reading as
  # a heading for the field below it. Asserted as geometry rather than by eye:
  # the line has to start where the badge starts, not where the label starts.
  test "an administrator row's provenance line sits in the value column" do
    log_in_as users(:frank)
    visit admin_users_path

    with_viewport(:phone) do
      [ users(:frank), users(:grace) ].each do |administrator|
        measured = role_cell_geometry(administrator)

        assert_equal measured["badgeLeft"], measured["lineLeft"],
                     "the provenance line should start where the badge does, not at the label"
        assert_operator measured["badgeLeft"], :>, measured["cellLeft"],
                        "the value column should sit to the right of the label column"
        assert_operator measured["badgeWidth"], :<, measured["cellWidth"] / 2,
                        "the badge should keep its own width rather than stretch across the cell"
      end
    end
  end

  test "the users screen still fits a phone with a grant control and provenance" do
    log_in_as users(:frank)
    visit admin_users_path

    with_viewport(:phone) do
      assert_selector "button", text: "Grant admin rights"
      assert_text "Granted by"
      assert_no_horizontal_overflow "the users screen with grant controls"
      assert_touch_targets_at_least 44
    end
  end

  # FR-007 for the one control 013 adds. The sweep below runs as carol, who has
  # no Admin menu to measure, so the administrator's own row of the navigation
  # would otherwise never be held to the touch target rule.
  test "the Admin menu is a real touch target at phone width" do
    log_in_as users(:frank)

    with_viewport(:phone) do
      visit admin_users_path
      find(".site-menu-toggle").click
      assert_selector ".site-menu-panel summary", text: "Admin", visible: true

      assert_touch_targets_at_least 44
    end
  end

  # The three boxes the assertion above compares, measured in one pass so the
  # page cannot move between them. Rounded: sub-pixel differences are not what
  # any of this is about.
  def role_cell_geometry(administrator)
    page.evaluate_script(<<~JS)
      (() => {
        const cell = document.querySelector('#admin-user-row-#{administrator.id} td[data-label="Role"]');
        const box = (el) => el.getBoundingClientRect();
        const c = box(cell), b = box(cell.querySelector('.badge')), l = box(cell.querySelector('p'));
        return {
          cellLeft: Math.round(c.left), cellWidth: Math.round(c.width),
          badgeLeft: Math.round(b.left), badgeWidth: Math.round(b.width),
          lineLeft: Math.round(l.left)
        };
      })()
    JS
  end

  # 016: the Danger Zone is a table too, so it owes 012 FR-005 the same debt as
  # the screens above — one labelled card per domain below the breakpoint, the
  # table above it. It also carries a form and a control per row, which is the
  # combination most likely to push a phone sideways.
  test "the Danger Zone is stacked cards on a phone and a table on a desktop" do
    %w[alpha.example beta.example].each { |d| AllowedEmailDomain.create!(domain: d) }
    log_in_as users(:frank)
    visit admin_danger_zone_path
    assert_selector ".data-table tbody tr", minimum: 1

    with_viewport(:phone) do
      assert_equal "block", computed_display(".data-table tbody tr")
      assert_no_horizontal_overflow "the Danger Zone"
      assert_touch_targets_at_least 44
    end

    with_viewport(:desktop) do
      assert_equal "table-row", computed_display(".data-table tbody tr")
    end
  end

  # The empty state is a different layout — a statement and a form, no table at
  # all — so it is swept in its own right rather than assumed to follow.
  test "the empty Danger Zone holds up at the narrow widths" do
    log_in_as users(:frank)

    [ :minimum, :phone ].each do |size|
      with_viewport(size) do
        visit admin_danger_zone_path
        assert_selector "#danger-zone-allowed-domains-empty"
        assert_no_horizontal_overflow "the empty Danger Zone at #{size}"
      end
    end
  end

  # --- No horizontal overflow, anywhere (FR-001, FR-022a) -------------------

  test "no signed-in screen scrolls sideways at the narrow widths" do
    log_in_as @user

    [ :minimum, :phone ].each do |size|
      with_viewport(size) do
        { "the homepage" => root_path,
          "the locker wishes list" => locker_wishes_path,
          "the proposal history" => locker_swap_proposals_path,
          "the account edit screen" => edit_user_registration_path }.each do |name, path|
          visit path
          assert_no_horizontal_overflow "#{name} at #{size}"
        end
      end
    end
  end

  # --- Controls are real targets on every signed-in screen (FR-007) ---------

  # The sweep that turns FR-007 from a stylesheet intention into a fact. It runs
  # across screens rather than on one, because an undersized control is exactly
  # the sort of thing that survives on the page nobody thought to check.
  test "every standalone control is a real touch target at phone width" do
    log_in_as @user

    with_viewport(:phone) do
      { "the homepage" => root_path,
        "the locker wishes list" => locker_wishes_path,
        "the proposal history" => locker_swap_proposals_path,
        "the account edit screen" => edit_user_registration_path }.each do |name, path|
        visit path
        assert_touch_targets_at_least 44
      rescue Minitest::Assertion => e
        flunk "#{name}: #{e.message}"
      end
    end
  end

  # FR-004: a group of controls that sits in a row on a wide screen has to wrap
  # or stack on a narrow one rather than run off the edge. Asserted by measuring
  # that every control stays inside the viewport, which is the outcome the
  # requirement is really about.
  test "control groups wrap rather than overflow at phone width" do
    log_in_as users(:bob)

    with_viewport(:phone) do
      visit root_path

      escaping = page.evaluate_script(<<~JS)
        (() => {
          const limit = document.documentElement.clientWidth;
          return Array.from(document.querySelectorAll(".btn, .site-nav-link"))
            .filter(el => el.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true }))
            .filter(el => {
              const r = el.getBoundingClientRect();
              return r.left < 0 || r.right > limit;
            })
            .map(el => (el.innerText || el.value || "").trim().slice(0, 30));
        })()
      JS

      assert_empty escaping, "controls escaping the viewport: #{escaping.inspect}"
    end
  end

  # --- The signed-out screens (User Story 3) --------------------------------

  # These are already a narrow centred column, so the expectation is that little
  # or nothing needs to change. That is exactly why they are asserted rather
  # than assumed: they are the first thing a new visitor on a phone sees.
  test "the auth screens fit and function at the narrow widths" do
    [ :minimum, :phone ].each do |size|
      with_viewport(size) do
        visit new_user_session_path
        assert_no_horizontal_overflow "sign in at #{size}"
        assert_touch_targets_at_least 44

        visit new_user_registration_path
        assert_no_horizontal_overflow "sign up at #{size}"
        assert_touch_targets_at_least 44
      end
    end
  end

  test "signing in from a phone works and its result is readable" do
    with_viewport(:phone) do
      visit new_user_session_path
      fill_in_reliably "Email", with: @user.email
      fill_in_reliably "Password", with: VALID_PASSWORD
      click_on "Log in"

      assert_text "Welcome to LockSwap"
      assert_no_horizontal_overflow "the homepage after signing in"
    end
  end

  # --- The two-width sweep (FR-022, FR-023) ---------------------------------

  # Every screen, at both widths, asserting the things that are true of all of
  # them: the page does not scroll sideways, and the menu is in the treatment
  # that width calls for. This is the check that catches a screen nobody thought
  # to look at, which is why it is written as a sweep rather than per screen.
  SIGNED_IN_SCREENS = {
    "the homepage" => :root_path,
    "the locker wishes list" => :locker_wishes_path,
    "the proposal history" => :locker_swap_proposals_path,
    "the account edit screen" => :edit_user_registration_path
  }.freeze

  test "every signed-in screen holds up at both widths" do
    log_in_as @user

    with_viewport(:phone) do
      SIGNED_IN_SCREENS.each do |name, path|
        visit send(path)
        assert_no_horizontal_overflow "#{name} at phone width"
        assert_selector ".site-menu-toggle", visible: true
        assert_no_selector ".site-bar", visible: true
      end
    end

    with_viewport(:desktop) do
      SIGNED_IN_SCREENS.each do |name, path|
        visit send(path)
        assert_no_horizontal_overflow "#{name} at desktop width"
        assert_selector ".site-bar", visible: true
        assert_no_selector ".site-menu-toggle", visible: true
      end
    end
  end

  # SC-006: the keyboard has to walk the page in the order the eye does, in both
  # treatments — restacking a layout is allowed, reordering it underneath
  # somebody navigating by Tab is not.
  test "the keyboard walks the page in visual order at both widths" do
    log_in_as @user

    with_viewport(:phone) do
      visit locker_wishes_path
      assert_tab_order_follows_visual_order
    end

    with_viewport(:desktop) do
      visit locker_wishes_path
      assert_tab_order_follows_visual_order
    end
  end

  private





    # The rendered column count of the detail grid, read from the computed
    # style rather than from the declaration, so this reflects what the browser
    # actually did.
    # The display the browser actually resolved for the first match, which is
    # what distinguishes the card form from the table form.
    def computed_display(selector)
      page.evaluate_script(<<~JS)
        (() => {
          const el = document.querySelector(#{selector.inspect});
          return el ? getComputedStyle(el).display : "missing";
        })()
      JS
    end

    def detail_grid_columns
      page.evaluate_script(<<~JS)
        (() => {
          const el = document.querySelector(".detail-grid");
          if (!el) return 0;
          return getComputedStyle(el).gridTemplateColumns.split(" ").length;
        })()
      JS
    end
end
