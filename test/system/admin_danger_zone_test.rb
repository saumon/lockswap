require "application_system_test_case"

# 016: the Danger Zone screen as a person actually meets it.
#
# The controller tests cover the contract — who is let in, what the response
# holds, what is refused. What is asserted here is the part only a browser can
# answer: that the screen is reachable by following the menu, that what the
# administrator configures on it really does gate somebody else's signup, and
# that the empty state says so in words on screen rather than merely in markup.
class AdminDangerZoneTest < ApplicationSystemTestCase
  setup do
    @administrator = users(:frank)
  end

  # FR-001: the way in is the menu, not a memorised address.
  test "the administrator reaches the Danger Zone through the Admin menu" do
    log_in_as @administrator

    within ".site-bar" do
      find("summary", text: "Admin").click
      click_on "Danger Zone"
    end

    assert_current_path admin_danger_zone_path
    assert_selector "h1", text: "Danger Zone"
  end

  # FR-004: the screen states what an empty list means, because "no domains
  # configured" and "anybody may register" are the same fact and the reader
  # should not have to know that.
  test "an empty list says registration is open to any domain" do
    log_in_as @administrator
    visit admin_danger_zone_path

    # Scoped to the empty state itself. The screen also carries a standing
    # explanation of what the list does, which mentions any email domain in
    # passing — an unscoped match would find that instead and pass whether or not
    # the empty state was ever rendered.
    within "#danger-zone-allowed-domains-empty" do
      assert_text(/open to any email domain/i)
    end
  end

  # FR-003, User Story 1 acceptance scenario 1: added, listed, and still there on
  # the next visit — persisted rather than merely echoed back.
  test "a domain is added and is still there on the next visit" do
    log_in_as @administrator
    visit admin_danger_zone_path

    fill_in_reliably "Domain", with: "allowed.example"
    click_on "Add domain"

    assert_text "allowed.example"
    assert_no_selector "#danger-zone-allowed-domains-empty"

    visit admin_danger_zone_path

    assert_text "allowed.example"
  end

  # FR-008: a malformed entry is refused on screen, with the reason and with the
  # rest of the configuration intact.
  test "a malformed entry is refused with the reason on screen" do
    AllowedEmailDomain.create!(domain: "already.example")
    log_in_as @administrator
    visit admin_danger_zone_path

    fill_in_reliably "Domain", with: "not a domain"
    click_on "Add domain"

    assert_text AllowedEmailDomain::INVALID_DOMAIN_MESSAGE
    assert_text "already.example"
    assert_equal 1, AllowedEmailDomain.count
  end

  # --- User Story 3: who can see it -------------------------------------------

  # FR-002: not hidden, not disabled — absent. A standard account is never sent
  # the link at all, which is what the condition in the menu partial does; the
  # refusal behind it is the controller test's subject.
  test "a standard account has no Danger Zone entry and no Admin menu at all" do
    log_in_as users(:carol)

    assert_no_selector "summary.site-submenu-toggle", text: "Admin"
    assert_no_link "Danger Zone", visible: :all
    assert_no_selector %(a[href="#{admin_danger_zone_path}"]), visible: :all
  end

  # The complement, so the assertion above cannot pass by the menu being broken
  # for everybody: the administrator does get the entry, in the same disclosure
  # as "Users".
  test "an administrator's Admin menu carries the Danger Zone beside Users" do
    log_in_as @administrator

    within ".site-bar" do
      find("summary", text: "Admin").click

      assert_link "Users", visible: true
      assert_link "Danger Zone", visible: true
    end
  end

  # --- 029 User Story 2: the danger zone narrows to the super admin only ------

  # The missing middle case between the two tests above: grace has ordinary
  # administrator rights (so the Admin menu and "Users" are hers to see), but is
  # not the super admin, so "Danger Zone" is not (FR-007).
  test "a standard admin sees Users but not Danger Zone in the Admin menu" do
    log_in_as users(:grace)

    within ".site-bar" do
      find("summary", text: "Admin").click

      assert_link "Users", visible: true
      assert_no_link "Danger Zone", visible: :all
    end
  end

  # FR-006: hiding the link is presentation; this is the refusal that matters,
  # met the way a person would meet it, mirroring the equivalent non-administrator
  # test in test/system/admin_users_test.rb.
  test "a standard admin who types the Danger Zone address is refused and told why" do
    log_in_as users(:grace)
    visit admin_danger_zone_path

    assert_current_path root_path
    assert_text ApplicationController::ADMINISTRATORS_ONLY_MESSAGE
  end

  # --- User Story 2: lifting the restriction ---------------------------------

  # FR-003: removing a domain can reopen the site to everybody, so it is guarded
  # the way the site guards its other consequential writes — the confirmation
  # naming what is about to happen, as "Grant admin rights" does.
  test "the confirmation names the domain and declining changes nothing" do
    domain = AllowedEmailDomain.create!(domain: "allowed.example")
    log_in_as @administrator
    visit admin_danger_zone_path

    # FR-002-equivalent for this control: a column of buttons all reading
    # "Remove" says nothing about which row it is on, so each one's accessible
    # name carries the domain. Asserted here, where the name is read, rather than
    # left to the audit — axe checks a button *has* a name, not that it says which.
    assert_selector %(#allowed-email-domain-row-#{domain.id} button[aria-label="Remove allowed.example"])

    message = dismiss_confirm do
      within("#allowed-email-domain-row-#{domain.id}") { click_button "Remove" }
    end

    assert_includes message, "allowed.example"
    assert_text "allowed.example"
    assert_equal 1, AllowedEmailDomain.count
  end

  # User Story 2 acceptance scenario 2: removed, and the screen says what that
  # now means — the empty state is the statement that the restriction is off.
  test "removing the last domain empties the list and says registration is open" do
    domain = AllowedEmailDomain.create!(domain: "allowed.example")
    log_in_as @administrator
    visit admin_danger_zone_path

    accept_confirm do
      within("#allowed-email-domain-row-#{domain.id}") { click_button "Remove" }
    end

    assert_selector "#danger-zone-allowed-domains-empty"
    assert_no_text "allowed.example"
    assert_equal 0, AllowedEmailDomain.count
  end

  # And the consequence, through somebody else's signup: the restriction is not
  # merely absent from the screen, it is absent from registration (FR-004).
  test "a signup refused a moment ago succeeds once the domain is removed" do
    domain = AllowedEmailDomain.create!(domain: "allowed.example")
    log_in_as @administrator
    visit admin_danger_zone_path

    accept_confirm { within("#allowed-email-domain-row-#{domain.id}") { click_button "Remove" } }
    assert_selector "#danger-zone-allowed-domains-empty"

    click_on "Log out"
    assert_text "Log in"

    assert_difference -> { User.count }, 1 do
      visit new_user_registration_path
      fill_in_reliably "Email", with: "person@other.example"
      fill_in_reliably "Password", with: VALID_PASSWORD
      fill_in_reliably "Confirm password", with: VALID_PASSWORD
      click_on "Create account"

      assert_text "Welcome to LockSwap"
    end
  end

  # User Story 1, end to end and through two different people: the administrator
  # configures the list, and it is somebody else's signup that is refused by it.
  # This is the acceptance scenario the feature exists for, and no unit test
  # spans both halves of it.
  test "a configured domain refuses a signup from elsewhere and admits one from itself" do
    log_in_as @administrator
    visit admin_danger_zone_path
    fill_in_reliably "Domain", with: "allowed.example"
    click_on "Add domain"
    assert_text "allowed.example"

    click_on "Log out"
    assert_text "Log in"

    # FR-006: the exact sentence, on screen, and no account behind it.
    assert_no_difference -> { User.count } do
      visit new_user_registration_path
      fill_in_reliably "Email", with: "person@other.example"
      fill_in_reliably "Password", with: VALID_PASSWORD
      fill_in_reliably "Confirm password", with: VALID_PASSWORD
      click_on "Create account"

      assert_text User::EMAIL_DOMAIN_NOT_ALLOWED_MESSAGE
    end

    assert_no_text "Welcome to LockSwap"

    # FR-005 acceptance scenario 3: the permitted domain registers as it always did.
    assert_difference -> { User.count }, 1 do
      visit new_user_registration_path
      fill_in_reliably "Email", with: "person@allowed.example"
      fill_in_reliably "Password", with: VALID_PASSWORD
      fill_in_reliably "Confirm password", with: VALID_PASSWORD
      click_on "Create account"

      assert_text "Welcome to LockSwap"
    end
  end
  # --- 030 User Story 1: the site's floors ------------------------------------

  # FR-006 on screen: before the first save, the section says floors are still
  # typed freely, rather than showing an empty list.
  test "the floors section says floors are free text until a list is saved" do
    log_in_as @administrator
    visit admin_danger_zone_path

    within "#danger-zone-floors" do
      assert_selector "#danger-zone-floors-empty", text: /typed freely/i
    end
  end

  # FR-001/FR-002, acceptance scenarios 1 and 3: saved, cleaned up, and still
  # there on the next visit.
  test "a floor list is saved, cleaned up, and still there on the next visit" do
    log_in_as @administrator
    visit admin_danger_zone_path

    fill_in_reliably "Floors", with: "RDC, 1, 2, 2, , 3"
    click_on "Save floors"

    assert_text "Floors saved."
    assert_field "Floors", with: "RDC, 1, 2, 3"
    assert_no_selector "#danger-zone-floors-empty"

    visit admin_danger_zone_path

    assert_field "Floors", with: "RDC, 1, 2, 3"
  end

  # FR-003, acceptance scenario 4: the refusal is shown in the floors card and
  # nowhere else, and the list in force is untouched.
  test "an empty floor list is refused inside its own card" do
    SiteFloorList.current.update!(floors_text: "0, 1")
    log_in_as @administrator
    visit admin_danger_zone_path

    fill_in_reliably "Floors", with: " , "
    click_on "Save floors"

    within("#danger-zone-floors") { assert_selector ".form-errors" }
    within("#danger-zone-language") { assert_no_selector ".form-errors" }
    within("#danger-zone-allowed-domains") { assert_no_selector ".form-errors" }
    assert_equal %w[0 1], SiteFloorList.current.reload.floors
  end

  # The newer site-wide settings sit between the language and the domains.
  test "the floors section sits between the language and the domains" do
    log_in_as @administrator
    visit admin_danger_zone_path

    ids = all(".card[id^='danger-zone-']").map { |card| card[:id] }

    assert_operator ids.index("danger-zone-language"), :<, ids.index("danger-zone-floors")
    assert_operator ids.index("danger-zone-floors"), :<, ids.index("danger-zone-allowed-domains")
  end
  # --- 030 User Story 3: the locker number format -----------------------------

  test "the format section sits between the floors and the domains" do
    log_in_as @administrator
    visit admin_danger_zone_path

    ids = all(".card[id^='danger-zone-']").map { |card| card[:id] }

    assert_operator ids.index("danger-zone-floors"), :<, ids.index("danger-zone-locker-format")
    assert_operator ids.index("danger-zone-locker-format"), :<, ids.index("danger-zone-allowed-domains")
  end

  # FR-012, acceptance scenario 1: examples with their results, in words.
  test "the examples show each pattern with accepted and refused samples, in words" do
    log_in_as @administrator
    visit admin_danger_zone_path

    within "#locker-format-examples" do
      assert_selector "tbody tr", count: LockerNumberFormat::EXAMPLES.size

      within(:xpath, ".//tbody/tr[.//td[normalize-space()='\\d{3}']]") do
        assert_selector ".locker-format-sample", text: /042\s*Accepted/
        assert_selector ".locker-format-sample", text: /42\s*Refused/
        assert_selector ".locker-format-sample", text: /1234\s*Refused/
      end
    end
  end

  # FR-006-style statement for the format, then acceptance scenario 2.
  test "a format and its description are saved and shown on the next visit" do
    log_in_as @administrator
    visit admin_danger_zone_path

    within("#danger-zone-locker-format") { assert_selector "#danger-zone-locker-format-empty" }

    fill_in_reliably "Pattern", with: "\\d{3}"
    fill_in_reliably "Description", with: "3 chiffres, ex. 042"
    click_on "Save format"

    assert_text "Locker number format saved."
    assert_no_selector "#danger-zone-locker-format-empty"

    visit admin_danger_zone_path

    assert_field "Pattern", with: "\\d{3}"
    assert_field "Description", with: "3 chiffres, ex. 042"
  end

  # FR-010, acceptance scenario 3: refused in its own card, previous format kept.
  test "an invalid pattern is refused inside its own card" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}")
    log_in_as @administrator
    visit admin_danger_zone_path

    fill_in_reliably "Pattern", with: "[0-9"
    click_on "Save format"

    within("#danger-zone-locker-format") { assert_text "is not a valid regular expression" }
    within("#danger-zone-floors") { assert_no_selector ".form-errors" }
    assert_equal "\\d{3}", LockerNumberFormat.current.reload.pattern
  end

  # Acceptance scenario 4: clearing the pattern lifts the format.
  test "clearing the pattern says any locker number is accepted again" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}", description: "3 digits")
    log_in_as @administrator
    visit admin_danger_zone_path

    fill_in_reliably "Pattern", with: ""
    click_on "Save format"

    assert_text "Locker number format removed"
    assert_selector "#danger-zone-locker-format-empty"
    assert_not LockerNumberFormat.current.reload.in_force?
  end
end
