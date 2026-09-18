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

  test "the locker wish list is accessible" do
    log_in_as @user
    visit locker_wishes_path
    assert_selector "#locker-wish-list"
    assert_axe_clean
  end

  test "an empty locker wish list is accessible" do
    LockerWish.delete_all
    log_in_as @user
    visit locker_wishes_path
    assert_selector "#locker-wish-list-empty"
    assert_axe_clean
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
  test "the administrator's users screen is accessible" do
    log_in_as users(:frank)
    visit admin_users_path
    assert_selector "#admin-user-directory"
    # 015: the grant control and the provenance line are on this screen now, so
    # the audit that was already here covers them — provided they are actually
    # rendered when it runs, which is what these two wait for.
    assert_selector "button", text: "Grant admin rights"
    assert_text "First registration"
    assert_axe_clean
  end

  # 015 FR-015: axe checks the button has an accessible name; it cannot check the
  # name says which account. A column of controls reading "Grant admin rights"
  # passes an audit and still leaves a screen reader user counting rows, which the
  # requirement forbids — so the distinctness is asserted here directly.
  test "each grant control is distinguishable by name alone" do
    log_in_as users(:frank)
    visit admin_users_path

    names = all("button[aria-label]").map { |button| button[:"aria-label"] }

    assert_operator names.length, :>=, 2
    assert_equal names.uniq, names, "two grant controls share an accessible name"
    names.each { |name| assert_match(/\A Grant\ administrator\ rights\ to\ \S+@\S+ \z/x, name) }
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

  test "tab order follows visual order on the locker wish list" do
    log_in_as @user
    visit locker_wishes_path
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
  test "the locker wishes list is accessible as stacked cards" do
    log_in_as @user
    visit locker_wishes_path

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
