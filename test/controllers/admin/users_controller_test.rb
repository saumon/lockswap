require "test_helper"

# 013: who is allowed through to the administrator screens, and who is turned
# away at the door.
#
# This is the half of FR-004 the browser cannot test. A system test can only
# confirm the menu entry is absent; whether the address behind it is actually
# refused when typed, bookmarked, or guessed is an HTTP question, and it is the
# one that matters — hiding the link is a convenience, this is the control.
class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # The site's standing rule for signed-in-only content: an anonymous visitor is
  # sent to sign in rather than told what is behind the door.
  test "an anonymous visitor is sent to the login page" do
    get admin_users_path

    assert_redirected_to new_user_session_path
  end

  # FR-008: the refusal is here, at the request, not in the template that decides
  # whether to draw a link.
  test "a signed-in non-administrator is refused and told why" do
    sign_in users(:carol)

    get admin_users_path

    assert_redirected_to root_path
    assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, flash[:alert]
  end

  # Following the redirect matters: the refusal has to land somewhere usable with
  # the reason on screen, not bounce or loop.
  test "a refused visitor lands on the homepage with the reason shown" do
    sign_in users(:carol)

    get admin_users_path
    follow_redirect!

    assert_response :success
    assert_match ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, response.body
  end

  test "the administrator is let through" do
    sign_in users(:frank)

    get admin_users_path

    assert_response :success
  end

  # --- What the screen reports (User Story 2) -------------------------------

  # FR-006: every account, with none quietly left off — the administrator's own
  # included. Counted against the table rather than a fixed number so adding a
  # fixture cannot silently shrink what this covers.
  test "every registered account is listed, the administrator's own included" do
    sign_in users(:frank)

    get admin_users_path

    assert_select ".data-table tbody tr", count: User.count
    assert_select "td", text: users(:frank).email
    assert_select "td", text: users(:carol).email
  end

  # FR-007/FR-010: identified by email, in registration order, oldest first. The
  # expectation is read from the database rather than written out, so the test
  # states the rule and not a snapshot of today's fixtures.
  test "accounts are listed by email in registration order, oldest first" do
    sign_in users(:frank)

    get admin_users_path

    listed = css_select(".data-table tbody td[data-label='Email']").map { |cell| cell.text.strip }

    assert_equal User.order(:created_at).pluck(:email), listed
    assert_equal users(:frank).email, listed.first, "the administrator registered first"
  end

  # FR-012: the administrator's row says so outright, rather than leaving it to
  # be inferred from being at the top of the list.
  # 015 FR-013: this asserted exactly one "Admin" badge on the page, which was the
  # truth when only one account could ever hold the rights. Now any number can, so
  # it asserts what 013 FR-012 actually meant — the badge marks administrators and
  # marks nobody else — by counting against the administrators there are.
  test "administrator rows are labelled and no other row is" do
    sign_in users(:frank)

    get admin_users_path

    [ users(:frank), users(:grace) ].each do |administrator|
      assert_select "#admin-user-row-#{administrator.id}" do
        assert_select ".badge", text: "Admin"
      end
    end

    assert_select "#admin-user-row-#{users(:carol).id}" do
      assert_select ".badge", text: "Admin", count: 0
    end

    assert_select ".badge", text: "Admin", count: User.where(admin: true).count
  end

  # 013 FR-009 made this screen read-only and this test said so: no form, no
  # button, no input. 015 adds exactly one write — the grant — so the assertion
  # narrows to what is still forbidden (015 FR-014) rather than being deleted.
  # Granting is the only capability here; nothing removes rights, edits an account
  # or deletes one.
  test "the screen offers no control but the grant" do
    sign_in users(:frank)

    get admin_users_path

    assert_select "#admin-user-directory form" do |forms|
      forms.each do |form|
        assert_equal grant_admin_admin_user_path(id_in(form)), form["action"],
                     "the only form on this screen should be a grant"
      end
    end

    assert_select "#admin-user-directory input[type=?]", "text", count: 0
    assert_select "#admin-user-directory a[data-turbo-method=?]", "delete", count: 0
  end

  # 015 FR-006, FR-010: the grant itself.
  test "an administrator grants rights and is told it took effect" do
    sign_in users(:frank)

    assert_changes -> { users(:carol).reload.admin? }, from: false, to: true do
      patch grant_admin_admin_user_path(users(:carol))
    end

    assert_redirected_to admin_users_path
    assert_not_nil flash[:notice]
    assert_equal users(:frank), users(:carol).reload.admin_granted_by
  end

  # FR-013: giving the rights away does not spend them.
  test "the granting administrator keeps their own rights" do
    sign_in users(:frank)

    patch grant_admin_admin_user_path(users(:carol))

    assert_predicate users(:frank).reload, :admin?
  end

  # FR-020: no password, no second factor — the confirmation in the browser is the
  # only step, exactly as it is for "Cancel my account".
  test "the grant asks for no credential" do
    sign_in users(:frank)

    patch grant_admin_admin_user_path(users(:carol))

    assert_predicate users(:carol).reload, :admin?
  end

  # Principle IV, research.md R5: the provenance line reads the grantor for every
  # administrator row. Through the association that is a query per row; the
  # controller loads it up front instead. Asserted as a count so a later edit
  # cannot quietly drop the `includes` — on a fixture-sized table nothing else
  # would show it.
  test "listing the accounts costs the same however many were granted rights" do
    sign_in users(:frank)

    get admin_users_path
    baseline = count_queries { get admin_users_path }

    User.insert_all!((1..5).map do |n|
      {
        email: "granted#{n}@example.com",
        encrypted_password: Devise::Encryptor.digest(User, VALID_PASSWORD),
        admin: true, admin_granted_at: Time.current, admin_granted_by_id: users(:frank).id,
        created_at: Time.current, updated_at: Time.current
      }
    end)

    assert_equal baseline, count_queries { get admin_users_path }
  end

  # 015 User Story 2, FR-007: rights obtained by grant are the same rights. grace
  # was granted hers; everything below is asserted with her rather than with the
  # bootstrap administrator, because the whole question is whether anything in the
  # site distinguishes the two. Nothing should — every check keys off admin?.
  test "a granted administrator is let into the users list" do
    sign_in users(:grace)

    get admin_users_path

    assert_response :success
    assert_select ".data-table tbody tr", count: User.count
  end

  test "a granted administrator can grant rights in turn" do
    sign_in users(:grace)

    assert_changes -> { users(:carol).reload.admin? }, from: false, to: true do
      patch grant_admin_admin_user_path(users(:carol))
    end

    assert_equal users(:grace), users(:carol).reload.admin_granted_by
  end

  # FR-013 again, from the far end: a chain of grants leaves everyone in it an
  # administrator. Nothing is spent by being passed on.
  test "granting onwards leaves every administrator in the chain" do
    sign_in users(:grace)

    patch grant_admin_admin_user_path(users(:carol))

    [ users(:frank), users(:grace), users(:carol) ].each do |account|
      assert_predicate account.reload, :admin?
    end
  end

  # --- 015 User Story 3: the refusals -----------------------------------------
  #
  # This is the half of FR-009 no browser can reach. A system test can confirm the
  # button is absent from a non-administrator's screen; whether the address behind
  # it is refused when aimed at directly is an HTTP question, and it is the one
  # that decides whether roles mean anything.

  test "an anonymous visitor cannot grant rights" do
    assert_no_changes -> { users(:carol).reload.admin? } do
      patch grant_admin_admin_user_path(users(:carol))
    end

    assert_redirected_to new_user_session_path
  end

  test "a signed-in non-administrator cannot grant rights and is told why" do
    sign_in users(:carol)

    assert_no_changes -> { users(:dave).reload.admin? } do
      patch grant_admin_admin_user_path(users(:dave))
    end

    assert_redirected_to root_path
    assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, flash[:alert]
  end

  # FR-009 at its sharpest: a non-administrator cannot promote themselves, which
  # is the request anyone probing this would actually send.
  test "a non-administrator cannot grant rights to themselves" do
    sign_in users(:carol)

    patch grant_admin_admin_user_path(users(:carol))

    assert_not_predicate users(:carol).reload, :admin?
  end

  # FR-012: a list drawn before somebody else granted the same rights is stale,
  # not wrong. Arriving second reports success, because the outcome asked for is
  # the outcome that holds.
  test "granting to an account that is already an administrator reports success" do
    sign_in users(:frank)

    patch grant_admin_admin_user_path(users(:grace))

    assert_redirected_to admin_users_path
    assert_not_nil flash[:notice]
    assert_nil flash[:alert]
    assert_predicate users(:grace).reload, :admin?
  end

  # FR-012: and it does not rewrite when those rights were obtained.
  test "granting again leaves the recorded origin as it was" do
    sign_in users(:frank)
    original_at = users(:grace).admin_granted_at

    patch grant_admin_admin_user_path(users(:grace))

    assert_equal original_at, users(:grace).reload.admin_granted_at
  end

  # FR-011: the account cancelled itself between the list being drawn and the
  # button being pressed. A 404 would blame the administrator for a race they did
  # not run; this says what happened and puts them back on the list.
  test "granting to an account that no longer exists says so" do
    sign_in users(:frank)
    gone = users(:dave).id
    users(:dave).destroy

    patch grant_admin_admin_user_path(gone)

    assert_redirected_to admin_users_path
    assert_equal Admin::UsersController::ACCOUNT_GONE_MESSAGE, flash[:alert]
  end

  private

    # The id embedded in an admin-user-row form's action, for the read-only check
    # above. Read off the row's own element rather than the action, so the action
    # is what is being asserted rather than what is being assumed.
    def id_in(form)
      form.ancestors("tr").first["id"].delete_prefix("admin-user-row-")
    end

    # No query-counting helper is bundled, so this is the usual subscription.
    # SCHEMA and TRANSACTION rows are noise here — they do not grow with the
    # number of rows on the page, which is the whole question.
    def count_queries
      count = 0
      counter = ->(_name, _start, _finish, _id, payload) do
        count += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ])
      end

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
      count
    end
end
