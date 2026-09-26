require "application_system_test_case"

# 008 FR-028 / SC-004: the automated accessibility coverage for every screen.
#
# This is the feature's primary test evidence. A visual refresh has no business
# logic to unit-test, so what gets asserted instead is what the refresh actually
# promises: contrast, visible focus, accessible naming and heading order, on
# every screen, as part of the standard suite.
#
# assert_axe_clean carries one documented exemption — colour contrast on the
# brand wordmark, per WCAG 2.1 SC 1.4.3. See test/application_system_test_case.rb.
class AccessibilityTest < ApplicationSystemTestCase
  setup do
    @user = users(:carol)
  end

  # --- Brand (User Story 1) -------------------------------------------------

  test "the header brand is a mark plus the product name" do
    log_in_as @user

    within "header" do
      assert_selector "a svg[data-brand-mark]", visible: :all
      assert_selector "a", text: "LockSwap"
    end
  end

  # FR-003a: the tagline is rendered in English so it matches the interface, and
  # the French original from the source artwork never reaches a page.
  test "the sign-in page shows the stacked lockup with the English tagline" do
    visit new_user_session_path

    # The auth screens carry the supplied artwork as an image rather than the
    # vector trace the header uses, so this matches on the marker, not the tag.
    assert_selector "[data-brand-mark]", visible: :all
    assert_text "Find the locker that suits you"
    assert_no_text "Trouvez le casier"
  end

  # --- Every screen (User Story 2) ------------------------------------------

  test "sign in is accessible" do
    visit new_user_session_path
    assert_axe_clean
  end

  test "sign up is accessible" do
    visit new_user_registration_path
    assert_axe_clean
  end

  test "account settings is accessible" do
    log_in_as @user
    visit edit_user_registration_path
    assert_axe_clean
  end

  # alice has neither floor nor locker — the "not yet asked" case.
  test "home without locker details is accessible" do
    log_in_as users(:alice)
    assert_axe_clean

    # 009: taking the first-entry choice leaves a different set of controls on
    # screen — a field gone, one trigger swapped for another — so the screen it
    # turns into is audited in its own right.
    wait_for_turbo
    click_on "I don't have a locker 😔"
    assert_axe_clean
  end

  # carol has a floor on file, so the saved profile and its disclosure render.
  test "home with a saved locker profile is accessible" do
    log_in_as @user
    assert_axe_clean
  end

  # dave has a floor and locker on file and no *active* proposal, so the edit
  # disclosure is offered rather than locked.
  test "home with the edit disclosure open is accessible" do
    log_in_as users(:dave)
    # 009: the control is a pencil now, so it is found by its accessible name —
    # which this audit is also, in passing, checking it still has.
    find("summary[aria-label='Edit locker details']").click
    assert_axe_clean
  end

  # 030 SC-007: once a floor list is saved the floor becomes a <select>, so both
  # the first-entry form and the pencil editor are audited with it — the editor
  # with the "(no longer offered)" option a removed floor brings with it.
  test "home first entry with a floor list saved is accessible" do
    SiteFloorList.current.update!(floors_text: "0, 1, 3")
    log_in_as users(:alice)
    assert_selector "select[name='user[floor]']"
    assert_axe_clean
  end

  test "home editor with a floor list saved is accessible" do
    # carol is on floor 2, which this list leaves out — so the editor also
    # carries the "(no longer offered)" option.
    SiteFloorList.current.update!(floors_text: "0, 1, 3")
    log_in_as users(:carol)
    wait_for_turbo
    find("summary[aria-label='Edit locker details']").click
    # Visible, so the audit below runs on the open editor rather than on a
    # closed disclosure whose contents axe would skip.
    assert_selector "select[name='user[floor]']"
    assert_selector "select[name='user[floor]'] option", text: "(no longer offered)", visible: :all
    assert_axe_clean
  end

  # bob is the recipient of alice_pending_to_bob.
  # 010: the third state of the locker wish block — erin has answered the locker
  # question with "no locker" and declared no wish. The other two states are
  # already on screen in the audits around this one: carol carries a wish, dave
  # carries a locker and no wish.
  test "home with the ask-for-a-locker invitation is accessible" do
    log_in_as users(:erin)

    assert_selector "#home-locker-wish"
    assert_axe_clean
  end

  test "home with a received proposal is accessible" do
    log_in_as users(:bob)
    assert_selector "#swap-proposals-received"
    assert_axe_clean
  end

  # alice is the requester of alice_pending_to_bob.
  test "home with a sent proposal is accessible" do
    log_in_as users(:alice)
    assert_selector "#swap-proposals-sent"
    assert_axe_clean
  end

  # dave's proposal to carol was declined and not yet acknowledged.
  test "home with a declined proposal is accessible" do
    log_in_as users(:dave)
    assert_selector "#swap-proposals-declined"
    assert_axe_clean
  end

  test "home with an exchange in progress is accessible" do
    # bob is the valid recipient here: an accepted proposal requires the
    # recipient to be looking for a locker, and bob_wish is the fixture wish.
    LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob), status: :accepted)
    log_in_as users(:bob)
    assert_selector "#swap-exchange-in-progress"
    assert_axe_clean
  end

  # 019: @user (carol) has an active wish (floor "5") nobody currently
  # occupies, so a bare visit would auto-fill "Their floor" and land on the
  # no-match state instead of the populated list this test means to check.
  # Neutralised so the intended state is what's actually audited.
  test "the locker wish list is accessible" do
    log_in_as @user
    visit locker_wishes_path(current_floor: "")
    assert_selector "#locker-wish-list"
    assert_axe_clean
  end

  # 019: the auto-selected state itself — reached without any filter
  # interaction, unlike "a filtered locker wish list is accessible" below —
  # gets its own accessibility pass with rows actually present.
  test "a locker wish list narrowed by an auto-selected Their floor is accessible" do
    log_in_as users(:bob) # wish floor "7" — matches henry and iris

    visit locker_wishes_path

    assert_selector "#locker-wish-filter-current-floor a[aria-current='true']", text: "7"
    assert_selector "#locker-wish-row-#{users(:henry).id}"
    assert_axe_clean
  end

  test "an empty locker wish list is accessible" do
    LockerWish.delete_all
    log_in_as @user
    visit locker_wishes_path
    assert_selector "#locker-wish-list-empty"
    assert_axe_clean
  end

  # 017 FR-021 / SC-008: the two filter axes, and the states they can put the
  # list into.

  # 019: @user (carol) has an active wish (floor "5") that would otherwise
  # auto-fill "Their floor" and exclude bob (current floor "3") — this test is
  # about the looking-for axis, so current_floor is neutralised explicitly.
  test "a filtered locker wish list is accessible" do
    log_in_as @user
    visit locker_wishes_path(looking_for: "7", current_floor: "")
    assert_selector "#locker-wish-row-#{users(:bob).id}"
    assert_axe_clean
  end

  # 018: bob reciprocates with henry and iris, so this is the one state that
  # renders the "It's a match!" badge.
  test "a locker wish list with a match tag is accessible" do
    log_in_as users(:bob)
    visit locker_wishes_path
    assert_text "It's a match!"
    assert_axe_clean
  end

  test "a locker wish list matching no filter is accessible" do
    log_in_as @user
    visit locker_wishes_path(looking_for: "7", current_floor: "10")
    assert_selector "#locker-wish-list-no-match"
    assert_axe_clean
  end

  # FR-002/FR-021: two axes means two distinguishable landmarks, named with the
  # list's own column wording rather than an invented vocabulary — and the choice
  # in force is announced, not merely coloured.
  # 019: @user (carol) has an active wish, so current_floor must be pinned to
  # "" explicitly for the "All floors" assertion below to hold — otherwise it
  # would auto-fill to her wish's floor rather than stay unfiltered.
  test "each floor filter is its own named landmark, with the choice in force announced" do
    log_in_as @user
    visit locker_wishes_path(looking_for: "7", current_floor: "")

    assert_selector "#locker-wish-filter-looking-for[aria-label='Looking for floor']"
    assert_selector "#locker-wish-filter-current-floor[aria-label='Their floor']"

    within("#locker-wish-filter-looking-for") { assert_selector "a[aria-current='true']", text: "7" }
    within("#locker-wish-filter-current-floor") { assert_selector "a[aria-current='true']", text: "All floors" }
  end

  test "the proposal history is accessible" do
    log_in_as @user
    visit locker_swap_proposals_path
    assert_selector "#swap-proposal-history"
    assert_axe_clean
  end

  test "an empty proposal history is accessible" do
    log_in_as users(:bob)
    LockerSwapProposal.delete_all
    visit locker_swap_proposals_path
    assert_selector "#swap-proposal-history-empty"
    assert_axe_clean
  end

  # 013: the administrator's screen is audited like every other one. frank rather
  # than carol throughout this section — he is the only account that can reach it.
  #
  # 028: the grant control and the provenance line moved to the detail screen
  # (audited separately in admin_user_detail_test.rb's own accessibility
  # coverage); this screen is read-only again, so the wait is on the provenance
  # line alone.
  test "the administrator's users screen is accessible" do
    log_in_as users(:frank)
    visit admin_users_path
    assert_selector "#admin-user-directory"
    assert_text "First registration"
    assert_axe_clean
  end

  # 020: the admin Users screen's four filters, audited the same way 017's two
  # already are above — a filtered list, the no-match state, and the two link
  # filters as named landmarks with the choice in force announced.
  test "a filtered admin users list is accessible" do
    log_in_as users(:frank)
    visit admin_users_path(role: "standard")
    assert_no_text users(:grace).email
    assert_axe_clean
  end

  test "an admin users list matching no filter is accessible" do
    log_in_as users(:frank)
    visit admin_users_path(role: "admin", current_floor: users(:bob).floor)
    assert_selector "#admin-user-directory-no-match"
    assert_axe_clean
  end

  test "the two text filters have accessible labels" do
    log_in_as users(:frank)
    visit admin_users_path

    assert_selector "label[for='admin-user-filter-current-locker']"
    assert_selector "label[for='admin-user-filter-email']"
    assert_axe_clean
  end

  test "each admin users link filter is its own named landmark, with the choice in force announced" do
    log_in_as users(:frank)
    visit admin_users_path(current_floor: users(:bob).floor)

    assert_selector "#admin-user-filter-current-floor[aria-label='Current floor']"
    assert_selector "#admin-user-filter-role[aria-label='Role']"

    within("#admin-user-filter-current-floor") { assert_selector "a[aria-current='true']", text: users(:bob).floor }
    within("#admin-user-filter-role") { assert_selector "a[aria-current='true']", text: "All roles" }
  end

  # 016: the Danger Zone is audited like every other screen, in both of its
  # states. The empty one is not a trivial case here — it is a different page
  # (a statement where the table would be), and it is the state the screen is in
  # on any site that has never configured a domain.
  test "the empty Danger Zone is accessible" do
    log_in_as users(:frank)
    visit admin_danger_zone_path

    assert_selector "#danger-zone-allowed-domains-empty"
    assert_axe_clean
  end

  test "the Danger Zone with configured domains is accessible" do
    AllowedEmailDomain.create!(domain: "allowed.example")
    log_in_as users(:frank)
    visit admin_danger_zone_path

    # Both the list and the control on it, rendered before the audit runs —
    # otherwise the audit would quietly cover the empty state twice.
    assert_selector ".data-table tbody tr", minimum: 1
    assert_selector "button", text: "Remove"
    assert_axe_clean
  end

  # FR-008: the refused-entry state, which carries the form-error component and
  # the field described by it. A validation message that is on screen but not
  # associated with anything is the failure mode worth auditing for.
  test "the Danger Zone showing a refused entry is accessible" do
    log_in_as users(:frank)
    visit admin_danger_zone_path

    fill_in_reliably "Domain", with: "not a domain"
    click_on "Add domain"

    assert_text AllowedEmailDomain::INVALID_DOMAIN_MESSAGE
    assert_axe_clean
  end

  # 016, the same reasoning as the grant controls above: axe checks a button has
  # an accessible name, not that the name says which row it is on. A column of
  # controls reading "Remove" passes an audit and still leaves a screen reader
  # user counting rows.
  test "each remove control is distinguishable by name alone" do
    %w[alpha.example beta.example].each { |d| AllowedEmailDomain.create!(domain: d) }
    log_in_as users(:frank)
    visit admin_danger_zone_path

    # assert_selector first, and with a count: `all` does not wait, so on a page
    # still settling it returns whatever happens to be in the DOM at that instant
    # — which is how this read one control where the markup has two.
    assert_selector "#danger-zone-allowed-domains button[aria-label]", count: 2

    names = all("#danger-zone-allowed-domains button[aria-label]").map { |button| button[:"aria-label"] }

    assert_equal 2, names.length
    assert_equal names.uniq, names, "two remove controls share an accessible name"
    names.each { |name| assert_match(/\ARemove \S+\.\S+\z/, name) }
  end

  # 031 finding M2: this screen's audits live here, not inline in
  # admin_locker_map_test.rb — the same per-screen-audit home every other
  # feature's new screen uses (e.g. the Danger Zone audits just above, 030's
  # floor-select audits below). grace is a granted (non-super) admin, since
  # `require_admin!` is this screen's actual guard (research.md R7).
  test "the locker map is accessible" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    zone.locker_map_entries.create!(locker_number: "203")
    log_in_as users(:grace)

    visit admin_locker_map_path

    assert_text "Aile Nord"
    assert_axe_clean
  end

  # FR-004a: the standalone new-zone form's refused state carries the
  # form-error component, the same failure mode worth auditing 016's own
  # refused-domain test above checks for.
  test "the locker map's new-zone form shows an accessible error" do
    log_in_as users(:grace)
    visit admin_locker_map_path

    within("#new-zone-form") { click_on "Create zone" }

    assert_selector ".form-errors"
    assert_axe_clean
  end

  # 031 US3, finding M2: the remove/delete controls are new interactive
  # elements on this screen, audited here the same way T023's original pair
  # covers the rest of it.
  test "the locker map's destroy controls are accessible" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    zone.locker_map_entries.create!(locker_number: "203")
    log_in_as users(:grace)

    visit admin_locker_map_path

    # 031 density pass: the per-locker remove control is icon-only (×), named
    # by aria-label rather than by visible text (mirrors .toast-dismiss, 023).
    assert_selector "button[aria-label='Remove 203']"
    assert_selector "button", text: "Delete zone"
    assert_axe_clean
  end

  # 013 FR-003: the Admin menu open, which is a state that exists on one account's
  # pages and nobody else's — so it would never be looked at unless asked for by
  # name. Audited at both treatments for the same reason 012 audits the panel:
  # the menu is rendered into two containers and only one of them is ever on.
  test "the open Admin submenu is accessible in the bar" do
    log_in_as users(:frank)

    with_viewport(:desktop) do
      visit root_path
      find(".site-bar summary", text: "Admin").click
      assert_link "Users", visible: true
      assert_axe_clean
    end
  end

  test "the open Admin submenu is accessible in the panel" do
    log_in_as users(:frank)

    with_viewport(:phone) do
      visit root_path
      find(".site-menu-toggle").click
      find(".site-menu-panel summary", text: "Admin").click
      assert_link "Users", visible: true
      assert_axe_clean
    end
  end

  # --- Tab order (FR-015b) --------------------------------------------------
  #
  # Restructuring a layout is allowed; walking it out of order is not. These are
  # the three screens whose structure changes most, so they are the ones where a
  # reordered DOM would go unnoticed.

  test "tab order follows visual order on the home page" do
    log_in_as users(:bob)
    assert_no_selector "[role=status]"   # let the sign-in notification go first
    assert_tab_order_follows_visual_order
  end

  # 019: @user (carol)'s wish floor ("5") matches nobody, so a bare visit
  # would auto-fill "Their floor" and land on the no-match state — leaving no
  # interactive rows for a tab-order check to prove anything about.
  test "tab order follows visual order on the locker wish list" do
    log_in_as @user
    visit locker_wishes_path(current_floor: "")
    assert_selector "#locker-wish-list"
    assert_tab_order_follows_visual_order
  end

  # The proposal history is deliberately absent here: it is read-only, with no
  # focusable control inside <main> at all, so there is no tab order on it to
  # get wrong. Its restructuring is covered by the axe audit above instead.

  # --- 012: the narrow treatment --------------------------------------------

  # FR-024: the accessibility audit runs at the phone width too, to the same
  # conformance level, and covers the state with the menu panel open — which is
  # a state that only exists below the breakpoint and would otherwise never be
  # audited at all.
  test "the homepage is accessible at the phone width" do
    log_in_as @user

    with_viewport(:phone) do
      assert_axe_clean
    end
  end

  test "the open menu panel is accessible" do
    log_in_as @user

    with_viewport(:phone) do
      find(".site-menu-toggle").click
      assert_selector ".site-menu-panel a", text: "Locker wishes", visible: true

      assert_axe_clean
    end
  end

  # FR-005d: the restacked lists are the R2 gate. Flipping display on table
  # elements drops their implicit roles, so this is what proves the explicit
  # roles put them back — and that a screen-reader user still meets each record
  # as a set of labelled fields rather than as loose text.
  # 019: @user (carol)'s wish floor ("5") matches nobody currently on it, so a
  # bare visit would auto-fill "Their floor" and empty the list — the opposite
  # of what the guard below needs. Neutralised explicitly.
  test "the locker wishes list is accessible as stacked cards" do
    log_in_as @user
    visit locker_wishes_path(current_floor: "")

    with_viewport(:phone) do
      # Guard against a vacuous pass: an empty list renders no table at all, and
      # auditing the empty state would prove nothing about the restack.
      assert_selector ".data-table tbody tr", minimum: 1

      assert_axe_clean
    end
  end

  test "the proposal history is accessible as stacked cards" do
    log_in_as users(:bob)
    visit locker_swap_proposals_path

    with_viewport(:phone) do
      assert_selector ".data-table tbody tr", minimum: 1

      assert_axe_clean
    end
  end

  test "the users screen is accessible as stacked cards" do
    log_in_as users(:frank)
    visit admin_users_path

    with_viewport(:phone) do
      assert_selector ".data-table tbody tr", minimum: 1

      assert_axe_clean
    end
  end

  # FR-024 for the signed-out screens. They carry no header, so the menu is not
  # in play here — what is being audited is the auth column itself at the width
  # a new visitor most often meets it at.
  test "sign in is accessible at the phone width" do
    with_viewport(:phone) do
      visit new_user_session_path
      assert_axe_clean
    end
  end

  test "sign up is accessible at the phone width" do
    with_viewport(:phone) do
      visit new_user_registration_path
      assert_axe_clean
    end
  end
end
