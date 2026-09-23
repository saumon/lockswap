require "test_helper"

# 016 FR-003: adding a domain to the allow-list and taking one off it.
#
# The two writes behind the Danger Zone screen. Kept apart from the screen's own
# controller test for the same reason the actions are on their own controller:
# the screen is a screen, and this is the resource it manages (research.md R3).
class Admin::AllowedEmailDomainsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # --- Adding (User Story 1) --------------------------------------------------

  test "an administrator adds a domain and is told it took effect" do
    sign_in users(:frank)

    assert_difference -> { AllowedEmailDomain.count }, 1 do
      post admin_allowed_email_domains_path, params: { allowed_email_domain: { domain: "allowed.example" } }
    end

    assert_redirected_to admin_danger_zone_path
    assert_not_nil flash[:notice]
    assert_equal "allowed.example", AllowedEmailDomain.last.domain
  end

  # Edge Cases: the entry is normalized on the way in, so what an administrator
  # pastes decides nothing about what is stored.
  test "a domain is stored normalized" do
    sign_in users(:frank)

    post admin_allowed_email_domains_path, params: { allowed_email_domain: { domain: "  Allowed.EXAMPLE  " } }

    assert_equal "allowed.example", AllowedEmailDomain.last.domain
  end

  # FR-008: a malformed entry is refused, nothing is saved, and the administrator
  # is put back on the screen with the reason — not bounced to a blank page or
  # redirected somewhere that has lost the error.
  test "a malformed domain is refused and the reason is shown on the screen" do
    sign_in users(:frank)

    assert_no_difference -> { AllowedEmailDomain.count } do
      post admin_allowed_email_domains_path, params: { allowed_email_domain: { domain: "not a domain" } }
    end

    assert_response :unprocessable_entity
    assert_select "#error_explanation li", text: /#{Regexp.escape(AllowedEmailDomain::INVALID_DOMAIN_MESSAGE)}/
  end

  # And the screen it re-renders is still the whole screen: a rejected addition
  # must not take the existing configuration off the page with it.
  test "a refused addition leaves the existing list on screen" do
    AllowedEmailDomain.create!(domain: "already.example")
    sign_in users(:frank)

    post admin_allowed_email_domains_path, params: { allowed_email_domain: { domain: "not a domain" } }

    assert_select "td", text: "already.example"
  end

  # Edge Cases: the same domain twice is refused rather than silently duplicated.
  test "a duplicate domain is refused" do
    AllowedEmailDomain.create!(domain: "allowed.example")
    sign_in users(:frank)

    assert_no_difference -> { AllowedEmailDomain.count } do
      post admin_allowed_email_domains_path, params: { allowed_email_domain: { domain: "ALLOWED.example" } }
    end

    assert_response :unprocessable_entity
  end

  test "a blank domain is refused" do
    sign_in users(:frank)

    assert_no_difference -> { AllowedEmailDomain.count } do
      post admin_allowed_email_domains_path, params: { allowed_email_domain: { domain: "" } }
    end

    assert_response :unprocessable_entity
  end

  # FR-005 from the far end: adding a domain is what actually closes registration
  # to everyone else. Asserted through the real signup, because the configuration
  # having a row in it is not the requirement — the refusal is.
  test "adding a domain closes registration to every other domain" do
    sign_in users(:frank)
    post admin_allowed_email_domains_path, params: { allowed_email_domain: { domain: "allowed.example" } }
    delete destroy_user_session_path

    assert_no_difference -> { User.count } do
      post user_registration_path, params: {
        user: { email: "person@other.example", password: VALID_PASSWORD,
                password_confirmation: VALID_PASSWORD }
      }
    end
  end

  # --- Removing (User Story 2) ------------------------------------------------

  test "an administrator removes a domain and is told it took effect" do
    domain = AllowedEmailDomain.create!(domain: "allowed.example")
    sign_in users(:frank)

    assert_difference -> { AllowedEmailDomain.count }, -1 do
      delete admin_allowed_email_domain_path(domain)
    end

    assert_redirected_to admin_danger_zone_path
    assert_not_nil flash[:notice]
  end

  # FR-003: one domain off the list, the rest of it untouched.
  test "removing one domain leaves the others in place" do
    kept = AllowedEmailDomain.create!(domain: "kept.example")
    removed = AllowedEmailDomain.create!(domain: "removed.example")
    sign_in users(:frank)

    delete admin_allowed_email_domain_path(removed)

    assert_equal [ kept ], AllowedEmailDomain.all.to_a
  end

  # User Story 2, FR-004: the escape hatch, and the requirement that makes this
  # feature reversible. Removing the last domain does not merely empty a table —
  # it reopens registration to everybody, which is the claim worth asserting.
  test "removing the last domain reopens registration to any domain" do
    domain = AllowedEmailDomain.create!(domain: "allowed.example")
    sign_in users(:frank)

    delete admin_allowed_email_domain_path(domain)
    delete destroy_user_session_path

    assert_difference -> { User.count }, 1 do
      post user_registration_path, params: {
        user: { email: "person@other.example", password: VALID_PASSWORD,
                password_confirmation: VALID_PASSWORD }
      }
    end
  end

  # Removing one of several is not the escape hatch: the remaining domains still
  # gate registration. The complement of the test above, so neither can pass by
  # accident of the other's wording.
  test "removing one of several domains leaves the restriction in force" do
    AllowedEmailDomain.create!(domain: "kept.example")
    removed = AllowedEmailDomain.create!(domain: "removed.example")
    sign_in users(:frank)

    delete admin_allowed_email_domain_path(removed)
    delete destroy_user_session_path

    assert_no_difference -> { User.count } do
      post user_registration_path, params: {
        user: { email: "person@removed.example", password: VALID_PASSWORD,
                password_confirmation: VALID_PASSWORD }
      }
    end
  end

  # A screen drawn before somebody else removed the same domain is stale, not
  # wrong. Arriving second reports success, because the outcome asked for holds —
  # the same reading 015 took for granting to an account already promoted.
  test "removing a domain that is already gone says so rather than failing" do
    domain = AllowedEmailDomain.create!(domain: "allowed.example")
    gone = domain.id
    domain.destroy
    sign_in users(:frank)

    delete admin_allowed_email_domain_path(gone)

    assert_redirected_to admin_danger_zone_path
    assert_nil flash[:alert]
    assert_not_nil flash[:notice]
  end

  # --- User Story 3: the refusals ---------------------------------------------
  #
  # FR-002, and the half of it no browser can reach. A system test can confirm
  # the screen is absent from a non-administrator's navigation; whether these
  # addresses are refused when aimed at directly is an HTTP question, and it is
  # the one that decides whether the restriction means anything — this resource
  # controls who may join the site.

  test "an anonymous visitor cannot add a domain" do
    assert_no_difference -> { AllowedEmailDomain.count } do
      post admin_allowed_email_domains_path, params: { allowed_email_domain: { domain: "sneaky.example" } }
    end

    assert_redirected_to new_user_session_path
  end

  test "a signed-in non-administrator cannot add a domain and is told why" do
    sign_in users(:carol)

    assert_no_difference -> { AllowedEmailDomain.count } do
      post admin_allowed_email_domains_path, params: { allowed_email_domain: { domain: "sneaky.example" } }
    end

    assert_redirected_to root_path
    assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, flash[:alert]
  end

  test "an anonymous visitor cannot remove a domain" do
    domain = AllowedEmailDomain.create!(domain: "allowed.example")

    assert_no_difference -> { AllowedEmailDomain.count } do
      delete admin_allowed_email_domain_path(domain)
    end

    assert_redirected_to new_user_session_path
  end

  # The sharpest case: removing the last domain is what reopens the site to
  # everybody, so this is the request anyone probing the restriction would send.
  test "a signed-in non-administrator cannot remove a domain and so cannot reopen registration" do
    domain = AllowedEmailDomain.create!(domain: "allowed.example")
    sign_in users(:carol)

    assert_no_difference -> { AllowedEmailDomain.count } do
      delete admin_allowed_email_domain_path(domain)
    end

    assert_redirected_to root_path
    assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, flash[:alert]

    # And the restriction is still in force afterwards, which is the point.
    delete destroy_user_session_path

    assert_no_difference -> { User.count } do
      post user_registration_path, params: {
        user: { email: "person@other.example", password: VALID_PASSWORD,
                password_confirmation: VALID_PASSWORD }
      }
    end
  end

  # --- 029 User Story 2: the danger zone narrows to the super admin only ------
  #
  # Same refusal as the non-administrator tests above, but for an account that
  # does have ordinary administrator rights — grace is granted, not the super
  # admin, so these actions (the writes behind the danger zone screen) are
  # refused to her too now (FR-005/FR-006).

  test "a signed-in standard admin cannot add a domain and is told why" do
    sign_in users(:grace)

    assert_no_difference -> { AllowedEmailDomain.count } do
      post admin_allowed_email_domains_path, params: { allowed_email_domain: { domain: "sneaky.example" } }
    end

    assert_redirected_to root_path
    assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, flash[:alert]
  end

  test "a signed-in standard admin cannot remove a domain and so cannot reopen registration" do
    domain = AllowedEmailDomain.create!(domain: "allowed.example")
    sign_in users(:grace)

    assert_no_difference -> { AllowedEmailDomain.count } do
      delete admin_allowed_email_domain_path(domain)
    end

    assert_redirected_to root_path
    assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, flash[:alert]

    # And the restriction is still in force afterwards, which is the point.
    delete destroy_user_session_path

    assert_no_difference -> { User.count } do
      post user_registration_path, params: {
        user: { email: "person@other.example", password: VALID_PASSWORD,
                password_confirmation: VALID_PASSWORD }
      }
    end
  end
end
