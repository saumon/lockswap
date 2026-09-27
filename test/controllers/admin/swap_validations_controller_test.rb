require "test_helper"

# 033: the administrator's queue of accepted swap proposals, and the two
# decisions taken from it.
class Admin::SwapValidationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def accepted_proposal(requester: users(:dave), recipient: users(:bob), decided_at: Time.current)
    LockerSwapProposal.create!(requester: requester, recipient: recipient, status: :accepted,
                               decided_at: decided_at)
  end

  # --- Foundational: FR-001, FR-002, FR-003 ----------------------------------

  test "a non-admin is refused" do
    sign_in users(:carol)

    get admin_swap_validations_path

    assert_redirected_to root_path
    assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE, flash[:alert]
  end

  test "an anonymous visitor is refused" do
    get admin_swap_validations_path

    assert_redirected_to new_user_session_path
  end

  test "an admin sees every accepted proposal, oldest first" do
    older = accepted_proposal(decided_at: 2.days.ago)
    newer = accepted_proposal(requester: users(:henry), recipient: users(:judy), decided_at: 1.hour.ago)
    sign_in users(:grace)

    get admin_swap_validations_path

    assert_response :success
    assert_select "#swap-validation-row-#{older.id}", text: /dave@example.com.*bob@example.com/m
    assert_select "#swap-validation-row-#{newer.id}", text: /henry@example.com.*judy@example.com/m
    assert_operator response.body.index("swap-validation-row-#{older.id}"), :<,
                    response.body.index("swap-validation-row-#{newer.id}")
  end

  # Clarification 1: nothing distinguishes an exchange accepted before this
  # feature shipped — it is accepted, so it is listed.
  test "a proposal in any other state is not listed" do
    sign_in users(:grace)

    get admin_swap_validations_path

    assert_response :success
    LockerSwapProposal.find_each do |proposal|
      assert_select "#swap-validation-row-#{proposal.id}", count: 0
    end
    assert_select "#admin-swap-validations-empty"
  end

  # FR-006: the refuse form, checked at the markup the browser receives — see
  # test/system/admin_swap_validation_test.rb for why not through a browser.
  test "renders the refuse form with its optional comment for each listed exchange" do
    proposal = accepted_proposal
    sign_in users(:grace)

    get admin_swap_validations_path

    assert_select "#swap-validation-row-#{proposal.id} details.tile-disclosure" do
      assert_select "summary", text: "Refuse"
      assert_select "form[action=?]", refuse_admin_swap_validation_path(proposal) do
        assert_select "input[name=_method][value=patch]"
        assert_select "label[for=refuse-comment-#{proposal.id}]", text: "Reason (optional)"
        assert_select "textarea#refuse-comment-#{proposal.id}[name=?]", "locker_swap_proposal[decline_comment]"
        assert_select "textarea[required]", count: 0
        assert_select "input[type=submit][value=?]", "Confirm refusal"
      end
    end
  end

  # --- User Story 1: FR-004, FR-010, FR-014 ----------------------------------

  test "an admin validates a listed exchange" do
    proposal = accepted_proposal
    sign_in users(:grace)

    patch validate_admin_swap_validation_path(proposal)

    assert_redirected_to admin_swap_validations_path
    assert_equal I18n.t("admin.swap_validations.validate.validated"), flash[:notice]
    assert_predicate proposal.reload, :completed?
    assert_equal users(:grace), proposal.admin_decided_by
    assert_equal [ "3", "B12" ], [ users(:dave).reload.floor, users(:dave).locker_number ]
    assert_equal [ "4", "D07" ], [ users(:bob).reload.floor, users(:bob).locker_number ]
  end

  # spec.md Acceptance Scenario 1.3: not reserved to the super admin.
  test "the super admin can validate too" do
    proposal = accepted_proposal
    sign_in users(:frank)

    patch validate_admin_swap_validation_path(proposal)

    assert_predicate proposal.reload, :completed?
    assert_equal users(:frank), proposal.admin_decided_by
  end

  # Clarification 2, research.md R10.
  test "an administrator can validate an exchange they are party to" do
    proposal = accepted_proposal(requester: users(:grace), recipient: users(:bob))
    sign_in users(:grace)

    patch validate_admin_swap_validation_path(proposal)

    assert_predicate proposal.reload, :completed?
  end

  # research.md R6: another administrator decided it first.
  test "validating an exchange that was already decided is refused and changes nothing" do
    proposal = accepted_proposal
    proposal.decline!(nil, by: users(:frank))
    sign_in users(:grace)

    patch validate_admin_swap_validation_path(proposal)

    assert_redirected_to admin_swap_validations_path
    assert_equal I18n.t("admin.swap_validations.validate.already_decided"), flash[:alert]
    assert_predicate proposal.reload, :declined?
    assert_equal "D07", users(:dave).reload.locker_number
  end

  test "a non-admin cannot validate" do
    proposal = accepted_proposal
    sign_in users(:bob)

    patch validate_admin_swap_validation_path(proposal)

    assert_redirected_to root_path
    assert_predicate proposal.reload, :accepted?
  end

  # --- User Story 2: FR-005..FR-008, FR-010, FR-014 --------------------------

  test "an admin refuses a listed exchange without a comment" do
    proposal = accepted_proposal
    sign_in users(:grace)

    patch refuse_admin_swap_validation_path(proposal)

    assert_redirected_to admin_swap_validations_path
    assert_equal I18n.t("admin.swap_validations.refuse.refused"), flash[:notice]
    assert_predicate proposal.reload, :declined?
    assert_nil proposal.decline_comment
    assert_equal users(:grace), proposal.admin_decided_by
    assert_equal [ "4", "D07" ], [ users(:dave).reload.floor, users(:dave).locker_number ]
    assert_equal [ "3", "B12" ], [ users(:bob).reload.floor, users(:bob).locker_number ]
  end

  test "an admin refuses a listed exchange with a comment" do
    proposal = accepted_proposal
    sign_in users(:grace)

    patch refuse_admin_swap_validation_path(proposal),
          params: { locker_swap_proposal: { decline_comment: "Physical swap did not happen" } }

    assert_equal "Physical swap did not happen", proposal.reload.decline_comment
  end

  test "a refused exchange no longer counts either party as in an exchange" do
    proposal = accepted_proposal
    sign_in users(:grace)

    patch refuse_admin_swap_validation_path(proposal)

    assert_not LockerSwapProposal.in_progress_for?(users(:dave))
    assert_not LockerSwapProposal.in_progress_for?(users(:bob))
  end

  test "refusing an exchange that was already validated is refused and changes nothing" do
    proposal = accepted_proposal
    proposal.confirm!(by: users(:frank))
    sign_in users(:grace)

    patch refuse_admin_swap_validation_path(proposal)

    assert_equal I18n.t("admin.swap_validations.refuse.already_decided"), flash[:alert]
    assert_predicate proposal.reload, :completed?
    assert_equal users(:frank), proposal.admin_decided_by
  end

  test "a non-admin cannot refuse" do
    proposal = accepted_proposal
    sign_in users(:bob)

    patch refuse_admin_swap_validation_path(proposal)

    assert_redirected_to root_path
    assert_predicate proposal.reload, :accepted?
  end
end
