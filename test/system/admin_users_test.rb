require "application_system_test_case"

# 013 User Story 2: the administrator's view of who is registered.
#
# The controller test covers the contract — who is let in, what the response
# contains, in what order. What is asserted here is the part only a browser can
# answer: that the screen is reachable by following the menu, that the label on
# the administrator's row is actually on screen rather than merely in the markup,
# and that the page offers nothing to press.
class AdminUsersTest < ApplicationSystemTestCase
  setup do
    @administrator = users(:frank)
  end

  # FR-005: the way in is the menu, not a memorised address.
  test "the administrator reaches the users screen through the Admin menu" do
    log_in_as @administrator

    within ".site-bar" do
      find("summary", text: "Admin").click
      click_on "Users"
    end

    assert_current_path admin_users_path
    assert_selector "h1", text: "Registered users"
  end

  # FR-006/FR-007/FR-010: everyone who has registered, by email, oldest first.
  # The order is read off the screen and compared with the order the database
  # gives, so this asserts the rule rather than a fixed list.
  test "every registered account is on screen, oldest first" do
    log_in_as @administrator
    visit admin_users_path

    assert_selector ".data-table tbody tr", count: User.count

    on_screen = all(".data-table tbody td[data-label='Email']").map(&:text)

    assert_equal User.order(:created_at).pluck(:email), on_screen
  end

  # FR-012: visible, not just present. A label the reader cannot see is not a
  # label — which is why this asks for it as displayed text on the row.
  test "the administrator's own row is the one carrying the Admin label" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-row-#{@administrator.id}" do
      assert_text "Admin"
    end

    within "#admin-user-row-#{users(:carol).id}" do
      assert_no_text "Admin"
    end
  end

  # 013 FR-009 asserted this screen offered nothing to press. 015 added one
  # thing, the grant; 028 FR-001 moved it (and its new counterpart, revoke) onto
  # each account's own detail screen, so this screen is read-only again — no
  # control at all, and no "Actions" column to hold one.
  #
  # 020 narrows the field check, deliberately: the current-locker and email
  # filters are search inputs, not an account edit, so their presence does not
  # weaken what this test guards against.
  test "the screen offers no control but its own filters" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-directory" do
      assert_no_link "Edit"
      assert_no_link "Delete"
      assert_no_selector "button"

      # 028 FR-001: no "Actions" column header, and no per-row admin-rights
      # control of any kind — the whole column is gone, not left empty.
      assert_no_selector "th", text: "Actions"

      # 020 FR-004: the only fields on this screen are the current-locker and
      # email filters — nothing that edits an account.
      assert_selector "input[name='current_locker']"
      assert_selector "input[name='email']"
      assert_no_selector "input:not([name='current_locker']):not([name='email'])"
      assert_no_selector "textarea"
    end
  end

  # FR-018: the badge is the same on every administrator row; the line beneath it
  # is what says where the rights came from.
  test "an administrator row says whether the rights were claimed or granted" do
    log_in_as @administrator
    visit admin_users_path

    within "#admin-user-row-#{@administrator.id}" do
      assert_text "First registration"
    end

    within "#admin-user-row-#{users(:grace).id}" do
      assert_text "Granted by #{@administrator.email}"
    end
  end

  # FR-008: the same refusal the controller test asserts, seen the way a person
  # would meet it — sent back to the homepage with the reason on screen.
  test "a non-administrator who types the address is refused and told why" do
    log_in_as users(:carol)
    visit admin_users_path

    assert_current_path root_path
    assert_text ApplicationController::ADMINISTRATORS_ONLY_MESSAGE
  end

  # --- 015 FR-016: the site keeps an administrator -----------------------------

  # The whole arc, the way a person meets it: one administrator may leave while
  # another remains; the last one is stopped and told what to do; doing it lets
  # them leave. The refusal is only useful if the remedy is reachable from it.
  test "the last administrator is stopped from cancelling until someone else is promoted" do
    # grace's departure is the staging, not the subject: what this test is about
    # starts once frank is the only administrator left. Doing it through the
    # browser added a login, a page and a dialog that no assertion here depends
    # on — three more chances for a dropped interaction, for nothing.
    users(:grace).destroy

    log_in_as @administrator
    visit edit_user_registration_path
    accept_confirm { click_button "Cancel my account" }

    assert_text User::LAST_ADMINISTRATOR_MESSAGE
    assert_predicate User.find_by(email: @administrator.email), :present?

    # 028: the grant control lives on the detail screen now, not the list.
    visit admin_user_path(users(:carol))
    accept_confirm { click_button "Grant admin rights" }
    assert_text(/granted/i)

    visit edit_user_registration_path
    accept_confirm { click_button "Cancel my account" }
    assert_no_current_path edit_user_registration_path

    assert_nil User.find_by(email: @administrator.email)
  end

  # FR-019: the grant outlives the account that made it. grace was promoted by
  # frank; when frank goes, her row still says the rights were granted and when,
  # and says plainly that the account which granted them is no longer there.
  test "a grant survives the deletion of the administrator who made it" do
    log_in_as @administrator
    # 028: the grant control lives on the detail screen now, not the list.
    visit admin_user_path(users(:carol))
    accept_confirm { click_button "Grant admin rights" }
    assert_text(/granted/i)

    visit edit_user_registration_path
    accept_confirm { click_button "Cancel my account" }
    assert_no_current_path edit_user_registration_path

    log_in_as users(:grace)
    visit admin_users_path

    within "#admin-user-row-#{users(:grace).id}" do
      assert_text "Granted on"
      assert_text "(account removed)"
      assert_text "Admin"
    end
  end

  # The audits of this screen live in accessibility_test.rb with every other
  # screen's, and its behaviour at the two widths in responsive_test.rb with
  # every other list's — this file is the feature's own behaviour.
end
