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

  # --- 020 User Story 1: locker, floor and wish on every row ------------------

  # FR-001/FR-002: the same values the account's own homepage shows, read off the
  # row rather than assumed from the fixture, so the test states the rule.
  test "each row shows the account's saved floor and locker, or their absence" do
    sign_in users(:frank)

    get admin_users_path

    assert_select "#admin-user-row-#{users(:bob).id}-floor", text: users(:bob).saved_floor
    assert_select "#admin-user-row-#{users(:bob).id}-locker", text: users(:bob).saved_locker_number

    assert_select "#admin-user-row-#{users(:carol).id}-floor", text: users(:carol).saved_floor
    assert_select "#admin-user-row-#{users(:carol).id}-locker", text: "No locker assigned"

    assert_select "#admin-user-row-#{users(:alice).id}-floor", text: "Not set"
  end

  # FR-003: whether the account is looking for a locker, and on which floor.
  test "each row shows the account's active wish, or that it has none" do
    sign_in users(:frank)

    get admin_users_path

    assert_select "#admin-user-row-#{users(:bob).id}-wish",
                  text: "Looking for floor #{users(:bob).locker_wish.saved_floor}"
    assert_select "#admin-user-row-#{users(:dave).id}-wish", text: "Not looking for a locker"
  end

  # Principle IV: the Wish column reads user.locker_wish for every row; without
  # eager-loading it that is a query per row, which would grow with the number of
  # registered accounts.
  test "listing the accounts costs the same however many have declared a wish" do
    sign_in users(:frank)

    get admin_users_path
    baseline = count_queries { get admin_users_path }

    User.insert_all!((1..5).map do |n|
      {
        email: "wisher#{n}@example.com",
        encrypted_password: Devise::Encryptor.digest(User, VALID_PASSWORD),
        floor: "9", created_at: Time.current, updated_at: Time.current
      }
    end)

    assert_equal baseline, count_queries { get admin_users_path }
  end

  # --- 020 User Story 2: the four filters --------------------------------------

  test "the current-locker filter narrows to the account holding that exact locker" do
    sign_in users(:frank)

    get admin_users_path, params: { current_locker: users(:quinn).locker_number }

    listed = css_select(".data-table tbody td[data-label='Email']").map { |cell| cell.text.strip }

    assert_equal [ users(:quinn).email ], listed
  end

  # FR-007: exact, not a substring — "1" must not also match locker "10".
  test "the current-locker filter does not match a locker number by substring" do
    sign_in users(:frank)
    User.insert_all!([ {
      email: "shortlocker@example.com",
      encrypted_password: Devise::Encryptor.digest(User, VALID_PASSWORD),
      floor: "3", locker_number: "1", created_at: Time.current, updated_at: Time.current
    } ])

    get admin_users_path, params: { current_locker: "1" }

    listed = css_select(".data-table tbody td[data-label='Email']").map { |cell| cell.text.strip }

    assert_equal [ "shortlocker@example.com" ], listed
  end

  test "the current-floor filter narrows to accounts on that exact floor" do
    sign_in users(:frank)

    get admin_users_path, params: { current_floor: users(:judy).floor }

    listed = css_select(".data-table tbody td[data-label='Email']").map { |cell| cell.text.strip }

    assert_equal [ users(:judy).email ], listed
  end

  test "the role filter narrows to administrators or to standard accounts" do
    sign_in users(:frank)

    get admin_users_path, params: { role: "admin" }
    listed = css_select(".data-table tbody td[data-label='Email']").map { |cell| cell.text.strip }
    assert_equal User.where(admin: true).order(:created_at).pluck(:email), listed

    get admin_users_path, params: { role: "standard" }
    listed = css_select(".data-table tbody td[data-label='Email']").map { |cell| cell.text.strip }
    assert_equal User.where(admin: false).order(:created_at).pluck(:email), listed
  end

  # An unrecognized value is data-model.md's "must not error" rule (research.md
  # R5) — the request must succeed and apply no role restriction.
  test "an unrecognized role value applies no restriction rather than erroring" do
    sign_in users(:frank)

    get admin_users_path, params: { role: "superuser" }

    assert_response :success
    assert_select ".data-table tbody tr", count: User.count
  end

  test "the email filter narrows to accounts whose email contains the text, case-insensitively" do
    sign_in users(:frank)

    get admin_users_path, params: { email: "QUINN" }

    listed = css_select(".data-table tbody td[data-label='Email']").map { |cell| cell.text.strip }

    assert_equal [ users(:quinn).email ], listed
  end

  # FR-009: combined filters narrow to accounts matching every one of them, not
  # accounts matching any one.
  test "combining filters narrows to accounts matching every one of them" do
    sign_in users(:frank)

    get admin_users_path, params: { role: "standard", current_floor: users(:bob).floor }

    listed = css_select(".data-table tbody td[data-label='Email']").map { |cell| cell.text.strip }

    assert_equal [ users(:bob).email ], listed
  end

  # Principle IV: the filters compose into WHERE clauses on the one query, not
  # extra queries of their own.
  test "the filtered index issues no more queries than the unfiltered one" do
    sign_in users(:frank)

    baseline = count_queries { get admin_users_path }
    filtered = count_queries do
      get admin_users_path, params: { current_locker: "x", current_floor: "x", role: "admin", email: "x" }
    end

    assert_operator filtered, :<=, baseline
  end

  # FR-015: filtering removes non-matching rows without reordering the ones that
  # remain.
  test "filtered results keep the same registration-order sequence" do
    sign_in users(:frank)

    get admin_users_path, params: { role: "standard" }

    listed = css_select(".data-table tbody td[data-label='Email']").map { |cell| cell.text.strip }

    assert_equal User.where(admin: false).order(:created_at).pluck(:email), listed
  end

  # FR-012: filtering is strictly a read-only view — nothing about an account
  # changes because of how it was looked up.
  test "exercising every filter changes no account's data" do
    sign_in users(:frank)
    before = User.order(:id).map { |u| u.attributes.slice("email", "floor", "locker_number", "admin") }

    get admin_users_path, params: { current_locker: users(:quinn).locker_number }
    get admin_users_path, params: { current_floor: users(:bob).floor }
    get admin_users_path, params: { role: "admin" }
    get admin_users_path, params: { email: "quinn" }
    get admin_users_path # cleared

    after = User.order(:id).map { |u| u.attributes.slice("email", "floor", "locker_number", "admin") }

    assert_equal before, after
  end

  # FR-014: the refusal does not depend on whether a filter happens to be set.
  #
  # 028: the grant no longer carries or is reached with filter params (it moved
  # off the filtered list entirely — research.md R2), so this narrows to what it
  # can still meaningfully assert: the index refusal with filters attached, and
  # the grant refusal alongside it.
  test "a non-administrator's request is refused even with filter params attached" do
    sign_in users(:carol)

    get admin_users_path, params: { role: "admin", email: "x" }
    assert_redirected_to root_path

    assert_no_changes -> { users(:dave).reload.admin? } do
      patch grant_admin_admin_user_path(users(:dave))
    end
    assert_redirected_to root_path
  end

  # --- 020 User Story 3: a filter combination matching nobody -----------------

  # FR-011: told plainly, and distinct from there being no accounts at all
  # (which cannot happen on this screen — see data-model.md "No-Match State").
  test "a filter combination matching nobody shows the no-match message" do
    sign_in users(:frank)

    get admin_users_path, params: { role: "admin", current_floor: users(:bob).floor }

    assert_select "#admin-user-directory-no-match", text: /no account matches/i
    assert_select ".data-table", count: 0
  end

  # The chosen values are still on screen, so the administrator can see and
  # relax what they are filtered on.
  test "the no-match message still shows the filters that were set" do
    sign_in users(:frank)

    get admin_users_path, params: { role: "admin", current_floor: users(:bob).floor }

    assert_select "#admin-user-filter-role [aria-current=?]", "true", text: "Admin"
    assert_select "#admin-user-filter-current-floor [aria-current=?]", "true", text: users(:bob).floor
  end

  # 013 FR-009 made this screen read-only and this test said so: no form, no
  # button, no input. 015 adds exactly one write — the grant — so the assertion
  # narrows to what is still forbidden (015 FR-014) rather than being deleted.
  # Granting is the only capability here; nothing removes rights, edits an account
  # or deletes one.
  #
  # 020 adds two text filters (current locker, email), which are search inputs
  # over the existing list, not an account edit — so the "no form but the grant"
  # half of this test is narrowed to allow exactly those two GET forms, and the
  # "no text input" assertion is narrowed to name them rather than forbid every
  # input outright (analyze finding D1).
  test "the screen offers no control but the grant and its own filters" do
    sign_in users(:frank)

    get admin_users_path

    assert_select "#admin-user-directory form" do |forms|
      forms.each do |form|
        next if form["method"] == "get" # the two filter forms

        assert_equal grant_admin_admin_user_path(id_in(form)), form["action"],
                     "the only non-filter form on this screen should be a grant"
      end
    end

    # Each of the two text filters is one visible field, plus a hidden
    # pass-through of the same name inside the other filter's form (so
    # submitting one never drops the other) — the count is on the visible
    # field alone.
    assert_select "#admin-user-directory input[type=?][name=?]", "text", "current_locker", count: 1
    assert_select "#admin-user-directory input[type=?][name=?]", "text", "email", count: 1
    assert_select "#admin-user-directory input[type=?]:not([name=current_locker]):not([name=email])",
                  "text", count: 0
    assert_select "#admin-user-directory a[data-turbo-method=?]", "delete", count: 0
  end

  # 015 FR-006, FR-010: the grant itself. 028: redirects to the account's own
  # detail screen now, not the list (research.md R1).
  test "an administrator grants rights and is told it took effect" do
    sign_in users(:frank)

    assert_changes -> { users(:carol).reload.admin? }, from: false, to: true do
      patch grant_admin_admin_user_path(users(:carol))
    end

    assert_redirected_to admin_user_path(users(:carol))
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

    assert_redirected_to admin_user_path(users(:grace))
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

  # --- 028 User Story 2: revoking a different administrator's rights ----------

  # FR-009, FR-012, FR-018: the revoke itself, redirecting to the target's own
  # detail screen and clearing every trace of the earlier grant.
  test "an administrator revokes a different administrator's rights and is told it took effect" do
    sign_in users(:frank)

    assert_changes -> { users(:grace).reload.admin? }, from: true, to: false do
      patch revoke_admin_admin_user_path(users(:grace))
    end

    assert_redirected_to admin_user_path(users(:grace))
    assert_not_nil flash[:notice]
    grace = users(:grace).reload
    assert_nil grace.admin_granted_at
    assert_nil grace.admin_granted_by
  end

  # FR-007: no password or other credential is asked for, the same as the grant
  # (mirrors "the grant asks for no credential" above).
  test "the revoke asks for no credential" do
    sign_in users(:frank)

    patch revoke_admin_admin_user_path(users(:grace))

    assert_not_predicate users(:grace).reload, :admin?
  end

  # FR-014: revoking an already-standard account is not a failure.
  test "revoking rights from an account that is not an administrator reports success" do
    sign_in users(:frank)

    patch revoke_admin_admin_user_path(users(:carol))

    assert_redirected_to admin_user_path(users(:carol))
    assert_not_nil flash[:notice]
    assert_nil flash[:alert]
    assert_not_predicate users(:carol).reload, :admin?
  end

  # FR-013: the same account-gone handling #grant_admin already has.
  test "revoking rights from an account that no longer exists says so" do
    sign_in users(:frank)
    gone = users(:dave).id
    users(:dave).destroy

    patch revoke_admin_admin_user_path(gone)

    assert_redirected_to admin_users_path
    assert_equal Admin::UsersController::ACCOUNT_GONE_MESSAGE, flash[:alert]
  end

  # FR-010: refused the same way the grant already is.
  test "an anonymous visitor cannot revoke rights" do
    assert_no_changes -> { users(:grace).reload.admin? } do
      patch revoke_admin_admin_user_path(users(:grace))
    end

    assert_redirected_to new_user_session_path
  end

  test "a signed-in non-administrator cannot revoke rights and is told why" do
    sign_in users(:carol)

    assert_no_changes -> { users(:grace).reload.admin? } do
      patch revoke_admin_admin_user_path(users(:grace))
    end

    assert_redirected_to root_path
    assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, flash[:alert]
  end

  # --- 028 User Story 3: an administrator cannot revoke their own rights ------

  # FR-011, Acceptance Scenario 2: refused even by direct request, independent of
  # what the view ever rendered (research.md R3).
  test "an administrator cannot revoke their own rights" do
    sign_in users(:frank)

    assert_no_changes -> { users(:frank).reload.admin? } do
      patch revoke_admin_admin_user_path(users(:frank))
    end

    assert_redirected_to admin_user_path(users(:frank))
    assert_not_nil flash[:alert]
  end

  # Acceptance Scenario 3: the rule is not special-cased to the bootstrap
  # administrator — a granted administrator targeting themselves is refused the
  # same way.
  test "a granted administrator cannot revoke their own rights either" do
    sign_in users(:grace)

    assert_no_changes -> { users(:grace).reload.admin? } do
      patch revoke_admin_admin_user_path(users(:grace))
    end

    assert_redirected_to admin_user_path(users(:grace))
    assert_not_nil flash[:alert]
  end

  # --- 027 User Story 1: the detail screen, and who may reach it --------------

  test "an administrator can view another account's detail screen" do
    sign_in users(:frank)

    get admin_user_path(users(:bob))

    assert_response :success
    assert_select "body", text: /#{Regexp.escape(users(:bob).email)}/
  end

  # Edge Case: the same capabilities apply to the administrator's own account as
  # to any other, since the Users list already permits clicking any row.
  test "an administrator can view their own detail screen" do
    sign_in users(:frank)

    get admin_user_path(users(:frank))

    assert_response :success
  end

  test "an anonymous visitor requesting a user's detail screen is sent to sign in" do
    get admin_user_path(users(:bob))

    assert_redirected_to new_user_session_path
  end

  test "a non-administrator requesting a user's detail screen is refused" do
    sign_in users(:carol)

    get admin_user_path(users(:bob))

    assert_redirected_to root_path
    assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, flash[:alert]
  end

  # FR-011-equivalent for this screen: a vanished account is a message, not a 404.
  test "requesting the detail screen for a vanished account says so" do
    sign_in users(:frank)
    gone = users(:dave).id
    users(:dave).destroy

    get admin_user_path(gone)

    assert_redirected_to admin_users_path
    assert_equal Admin::UsersController::ACCOUNT_GONE_MESSAGE, flash[:alert]
  end

  # --- 027 User Story 2: search status and proposal history -------------------

  # FR-004: bob's fixture wish (bob_wish, floor "7").
  test "the detail screen shows the account's standing wish and its floor" do
    sign_in users(:frank)

    get admin_user_path(users(:bob))

    assert_select "#admin-user-search-status", text: /#{Regexp.escape(users(:bob).locker_wish.saved_floor)}/
  end

  # FR-005: bob is also the recipient on the pending alice_pending_to_bob fixture
  # — a wish and an active proposal can coexist (research.md R6), and both must
  # show.
  test "the detail screen shows an account's active proposal alongside its wish" do
    sign_in users(:frank)

    get admin_user_path(users(:bob))

    assert_select "#admin-user-search-status" do
      assert_select ".detail-value-empty", count: 0
    end
  end

  # FR-005: quinn has no wish and no fixture proposal at all.
  test "the detail screen states plainly when there is no search in progress" do
    sign_in users(:frank)

    get admin_user_path(users(:quinn))

    assert_select "#admin-user-search-status.detail-value-empty"
  end

  # FR-006/FR-007: every one of dave's proposals (sent, declined) is in the
  # history; an account with none shows the empty state instead.
  test "the detail screen lists every proposal the account sent or received" do
    sign_in users(:frank)

    get admin_user_path(users(:dave))

    assert_select "#admin-user-detail-history-row-#{locker_swap_proposals(:dave_declined_to_carol).id}"
  end

  test "the detail screen states plainly when there is no proposal history" do
    sign_in users(:frank)

    get admin_user_path(users(:quinn))

    assert_select "#admin-user-detail-history-empty"
    assert_select ".data-table", count: 0
  end

  # Principle IV, research.md R5/R6: two bounded queries per collection, not one
  # scaling with every other account's own proposals.
  test "the detail screen's query cost does not scale with other accounts' proposals" do
    sign_in users(:frank)

    get admin_user_path(users(:dave))
    baseline = count_queries { get admin_user_path(users(:dave)) }

    User.insert_all!((1..5).map do |n|
      {
        email: "other#{n}@example.com",
        encrypted_password: Devise::Encryptor.digest(User, VALID_PASSWORD),
        floor: "9", created_at: Time.current, updated_at: Time.current
      }
    end)
    User.where(email: (1..5).map { |n| "other#{n}@example.com" }).find_each do |other|
      LockerSwapProposal.new(requester: users(:erin), recipient: other).save(validate: false)
    end

    assert_equal baseline, count_queries { get admin_user_path(users(:dave)) }
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
