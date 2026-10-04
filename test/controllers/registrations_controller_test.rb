require "test_helper"

# 013 User Story 1, Acceptance Scenarios 1 and 2, through the path a person
# actually takes: Devise's signup form, not User.create! in a test.
#
# The model test proves the callback assigns the flag; this proves the callback
# is reached by the real registration, and that the resulting page is the one the
# administrator gets rather than the one everybody else gets. Those are different
# claims, and only the second of them would survive someone permitting :admin as
# a signup parameter or filtering the menu on something other than the flag.
class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  # 015: the cancellation tests at the foot of this file act as a signed-in
  # account, which the signup tests above never needed to do.
  include Devise::Test::IntegrationHelpers

  # FR-001: the first person to sign up on an untouched instance is the
  # administrator, with no setup step. destroy_all for the empty site the
  # requirement is written about — the fixtures are a site that already exists.
  test "the first signup on an empty site becomes the administrator" do
    User.destroy_all

    post user_registration_path, params: {
      user: { email: "founder@example.com", password: VALID_PASSWORD,
              password_confirmation: VALID_PASSWORD }
    }

    # 034 FR-003: signup no longer signs in; the account waits for activation.
    assert_redirected_to new_user_session_path
    assert_predicate User.find_by(email: "founder@example.com"), :admin?
  end

  # FR-003: and is shown the menu that goes with it — once activated and signed
  # in (034: signup itself no longer signs in, so the homepage comes after the
  # activation link, not straight after the form).
  test "the first signup, once activated, lands on a homepage carrying the Admin menu" do
    User.destroy_all

    post user_registration_path, params: {
      user: { email: "founder@example.com", password: VALID_PASSWORD,
              password_confirmation: VALID_PASSWORD }
    }
    founder = User.find_by!(email: "founder@example.com")
    founder.confirm
    sign_in founder
    get root_path

    assert_response :success
    assert_select "summary.site-submenu-toggle", text: "Admin"
    assert_select "a[href=?]", admin_users_path
  end

  # FR-002/FR-004: everybody after that gets an ordinary account and the
  # navigation they have always had.
  test "a later signup is an ordinary account with no Admin menu" do
    post user_registration_path, params: {
      user: { email: "newcomer@example.com", password: VALID_PASSWORD,
              password_confirmation: VALID_PASSWORD }
    }
    newcomer = User.find_by!(email: "newcomer@example.com")
    newcomer.confirm
    sign_in newcomer
    get root_path

    assert_response :success
    assert_not_predicate User.find_by(email: "newcomer@example.com"), :admin?
    assert_select "summary.site-submenu-toggle", count: 0
    assert_select "a[href=?]", admin_users_path, count: 0
  end

  # FR-002: the flag is not an attribute a signup gets to set. Asking for it
  # politely in the form parameters has to make no difference on a site that
  # already has an administrator.
  test "a signup cannot award itself the flag by asking for it" do
    post user_registration_path, params: {
      user: { email: "ambitious@example.com", password: VALID_PASSWORD,
              password_confirmation: VALID_PASSWORD, admin: true }
    }

    assert_not_predicate User.find_by(email: "ambitious@example.com"), :admin?
    # 015 FR-013: more than one administrator is possible now, so the question is
    # whether the set changed, not who the single answer is.
    assert_equal [ users(:frank), users(:grace) ].sort_by(&:id),
                 User.where(admin: true).order(:id).to_a
  end

  # 014 FR-002, FR-009: the two password fields have to agree, and that is
  # settled at the server. The form's live hint is an enhancement on top of this
  # check, never the check itself (research.md R1) — so a request that never went
  # near a browser is refused here just the same.
  test "a signup whose confirmation does not match the password is refused" do
    assert_no_difference -> { User.count } do
      post user_registration_path, params: {
        user: { email: "mistyped@example.com", password: VALID_PASSWORD,
                password_confirmation: "#{VALID_PASSWORD}x" }
      }
    end

    assert_response :unprocessable_entity
    assert_select "#error_explanation li", text: /doesn't match the password above/
  end

  # --- 029 FR-010: cancelling the super admin's account ------------------------
  #
  # The model refuses it; this is where that refusal has to become something the
  # person can read and act on. Devise's own destroy reports success regardless of
  # what the record did, which is the specific thing being corrected here.

  test "the super admin cannot cancel their account while others remain" do
    users(:grace).destroy
    sign_in users(:frank)

    assert_no_difference -> { User.count } do
      delete user_registration_path
    end

    assert_equal I18n.t("user.messages.super_admin_uncancellable"), flash[:alert]
    assert_nil flash[:notice]
  end

  # And they are still signed in afterwards: a refused cancellation must not log
  # somebody out of an account they still have.
  test "a refused cancellation leaves the administrator signed in" do
    users(:grace).destroy
    sign_in users(:frank)

    delete user_registration_path
    get root_path

    assert_response :success
  end

  # 034 analyze I1: the refusal lands back on the account page, still signed in,
  # with its message intact — not on the sign-in page, which would bounce a
  # signed-in person to the homepage and replace the refusal with "already
  # signed in".
  test "a refused cancellation returns to the account page with its message" do
    users(:grace).destroy
    sign_in users(:frank)

    delete user_registration_path

    assert_redirected_to edit_user_registration_path
    follow_redirect!
    assert_response :success
    assert_equal I18n.t("user.messages.super_admin_uncancellable"), flash[:alert]
  end

  # 029 FR-014: a granted administrator's own account is never restricted,
  # however many other admins remain — frank (the super admin) always does.
  test "a granted administrator can cancel while the super admin remains" do
    sign_in users(:grace)

    assert_difference -> { User.count }, -1 do
      delete user_registration_path
    end

    assert_nil flash[:alert]
  end

  test "a non-administrator can always cancel" do
    sign_in users(:carol)

    assert_difference -> { User.count }, -1 do
      delete user_registration_path
    end

    assert_nil flash[:alert]
  end

  # --- 016: the allowed email domains gate ------------------------------------
  #
  # The model test proves the validation refuses the record. These prove the
  # refusal is reached by the real signup and that the required sentence is on the
  # page the person is actually looking at — which is the requirement (FR-006),
  # and is not the same claim.
  #
  # No fixture configures a domain (research.md R5), so the tests above this line
  # sign accounts up unrestricted, exactly as they did before this feature.

  # FR-005, FR-006, SC-002.
  test "a signup on a domain outside the allow-list is refused with the required message" do
    AllowedEmailDomain.create!(domain: "allowed.example")

    assert_no_difference -> { User.count } do
      post user_registration_path, params: {
        user: { email: "person@other.example", password: VALID_PASSWORD,
                password_confirmation: VALID_PASSWORD }
      }
    end

    assert_response :unprocessable_entity
    assert_select "#error_explanation li", text: User::EMAIL_DOMAIN_NOT_ALLOWED_MESSAGE
  end

  # FR-005 acceptance scenario 3, SC-003: a permitted domain registers exactly as
  # any other signup does — nothing about the flow changed by the restriction
  # existing. (034: which now means created, unactivated, sent to sign in.)
  test "a signup on an allowed domain proceeds as it always did" do
    AllowedEmailDomain.create!(domain: "allowed.example")

    assert_difference -> { User.count }, 1 do
      post user_registration_path, params: {
        user: { email: "person@allowed.example", password: VALID_PASSWORD,
                password_confirmation: VALID_PASSWORD }
      }
    end

    assert_redirected_to new_user_session_path
  end

  # FR-007 through the real form: the address is folded before it is compared, so
  # the casing a person happens to type decides nothing.
  test "a signup matching an allowed domain in another casing is accepted" do
    AllowedEmailDomain.create!(domain: "allowed.example")

    assert_difference -> { User.count }, 1 do
      post user_registration_path, params: {
        user: { email: "Person@Allowed.Example", password: VALID_PASSWORD,
                password_confirmation: VALID_PASSWORD }
      }
    end
  end

  # FR-004, SC-003: with nothing configured the gate is not merely open, it is
  # absent. Stated explicitly rather than left to be inferred from the other tests
  # in this file passing, because it is the requirement that keeps this feature
  # from changing the site for anyone who never uses it.
  test "with no domain configured a signup on any domain is accepted" do
    assert_equal 0, AllowedEmailDomain.count

    assert_difference -> { User.count }, 1 do
      post user_registration_path, params: {
        user: { email: "anyone@wherever.example", password: VALID_PASSWORD,
                password_confirmation: VALID_PASSWORD }
      }
    end

    assert_redirected_to new_user_session_path
  end

  # FR-010: the restriction gates registration, not the people already through it.
  # An account whose domain is not on a newly configured list must still be able
  # to sign in — the failure mode that would lock an entire company out of its own
  # site the moment an administrator mistyped a domain.
  test "an existing account on a disallowed domain can still sign in" do
    AllowedEmailDomain.create!(domain: "allowed.example")

    post user_session_path, params: {
      user: { email: users(:carol).email, password: VALID_PASSWORD }
    }

    assert_redirected_to root_path
  end

  # --- 035: changing the password from the account page -----------------------

  NEW_PASSWORD = "brandnew456".freeze

  def change_password(current: VALID_PASSWORD, password: NEW_PASSWORD, confirmation: password)
    patch user_account_password_path, params: {
      password_change: { current_password: current, password: password, password_confirmation: confirmation }
    }
  end

  # The request log and Rails.logger, as one string, for the duration of the block.
  def captured_log
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    Rails.logger.broadcast_to(logger)
    yield
    io.string
  ensure
    Rails.logger.stop_broadcasting_to(logger)
  end

  # US1, FR-014, FR-017: back to the account page with the outcome, still
  # signed in.
  test "035: a valid change redirects to the account page and keeps this session" do
    sign_in users(:carol)

    log = captured_log { change_password }

    assert_redirected_to edit_user_registration_path
    assert_response :see_other
    assert flash[:password_changed]
    assert_includes log, "[password_change] event=changed user_id=#{users(:carol).id}"

    get edit_user_registration_path
    assert_response :success
    assert users(:carol).reload.valid_password?(NEW_PASSWORD)
  end

  # FR-019: nothing changes, and signing in comes back to the account page.
  test "035: without a session the change is refused and sign-in returns to the account page" do
    change_password

    assert_redirected_to new_user_session_path
    assert users(:carol).reload.valid_password?(VALID_PASSWORD)

    post user_session_path, params: { user: { email: users(:carol).email, password: VALID_PASSWORD } }
    assert_redirected_to edit_user_registration_path
  end

  # FR-007: there is no way to name another account.
  test "035: the change applies to the signed-in account whatever else is posted" do
    sign_in users(:carol)

    patch user_account_password_path, params: {
      id: users(:alice).id, user: { id: users(:alice).id },
      password_change: { current_password: VALID_PASSWORD, password: NEW_PASSWORD,
                         password_confirmation: NEW_PASSWORD }
    }

    assert users(:carol).reload.valid_password?(NEW_PASSWORD)
    assert users(:alice).reload.valid_password?(VALID_PASSWORD)
  end

  # US3, FR-013, FR-025, FR-026: a refusal re-renders the page, echoes no
  # password, and logs which rules failed — never the values.
  test "035: a refusal echoes no password and logs only the failed rules" do
    sign_in users(:carol)
    wrong = "guessing-#{SecureRandom.hex(4)}"
    short = "sh#{SecureRandom.hex(1)}"

    log = captured_log { change_password(current: wrong, password: short) }

    assert_response :unprocessable_content
    [ wrong, short ].each do |value|
      assert_not_includes response.body, value
      assert_not_includes log, value
    end
    assert_select "input[type=password][value]", count: 0
    assert_select "#error_explanation li", minimum: 2
    assert_match(/\[password_change\] event=refused user_id=#{users(:carol).id} reasons=\S*current_password_invalid/, log)
    assert users(:carol).reload.valid_password?(VALID_PASSWORD)
  end

  # Analyze I1: the password errors belong to the password card only.
  test "035: a refusal leaves the email form without errors" do
    sign_in users(:carol)

    change_password(password: "short")

    assert_select "form[action='#{user_registration_path}'] #error_explanation", count: 0
    assert_select "#error_explanation", count: 1
  end

  test "035: a throttled attempt is logged as such" do
    sign_in users(:carol)
    users(:carol).update_columns(password_change_failed_attempts: 5, password_change_locked_at: Time.current)

    log = captured_log { change_password }

    assert_response :unprocessable_content
    assert_includes log, "[password_change] event=throttled user_id=#{users(:carol).id}"
    assert users(:carol).reload.valid_password?(VALID_PASSWORD)
  end

  # FR-024: a failure while saving changes nothing and says so plainly.
  test "035: an error while saving leaves the password unchanged and says to try again" do
    sign_in users(:carol)
    User.class_eval do
      alias_method :__save_before_035_test, :save
      define_method(:save) { |**| raise ActiveRecord::ActiveRecordError, "disk on fire" }
    end

    log = captured_log { change_password }

    assert_response :unprocessable_content
    assert_includes response.body, ERB::Util.html_escape(I18n.t("activemodel.errors.models.password_change.failed"))
    assert_not_includes response.body, "disk on fire"
    assert_includes log, "[password_change] event=failed user_id=#{users(:carol).id}"
  ensure
    User.class_eval do
      alias_method :save, :__save_before_035_test
      remove_method :__save_before_035_test
    end
    assert users(:carol).reload.valid_password?(VALID_PASSWORD)
  end

  # US4, research.md R2: the email form no longer carries a password, and the
  # server does not accept one through it either.
  test "035: the email form cannot change the password" do
    sign_in users(:carol)

    assert_no_enqueued_emails do
      put user_registration_path, params: {
        user: { email: users(:carol).email, current_password: VALID_PASSWORD,
                password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
      }
    end

    assert users(:carol).reload.valid_password?(VALID_PASSWORD)
  end
end
