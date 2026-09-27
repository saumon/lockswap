require "application_system_test_case"

# 033 User Story 1: an administrator validates an accepted exchange from the
# queue, in the browser.
#
# Refusing is not driven through the browser here. It needs the refuse
# <details> opened, and in this environment a ChromeDriver click on a
# .tile-disclosure-summary is dropped outright — reported as delivered, no
# pointer/mouse/click event reaches the page (checked with a capture-phase
# document listener), repeatedly for the same element — the dropped-interaction
# class application_system_test_case.rb's fill_in_reliably already documents.
# A test that depends on it cannot be deterministic (Principle II), so refusal
# is covered deterministically instead: its behaviour in
# test/controllers/admin/swap_validations_controller_test.rb, and the form's
# wiring (field, label, target) in the same file's "renders the refuse form"
# test.
class AdminSwapValidationTest < ApplicationSystemTestCase
  setup do
    @admin = users(:grace)
    @proposal = LockerSwapProposal.create!(requester: users(:dave), recipient: users(:bob),
                                           status: :accepted, decided_at: Time.current)
  end

  # FR-001: reachable from the Admin menu. Asserted as present and pointing at
  # the screen rather than clicked open, for the reason above.
  test "the Admin menu links to the queue" do
    log_in_as @admin

    within ".site-bar" do
      assert_link "Swap validations", href: admin_swap_validations_path, visible: :all
    end
  end

  # FR-002.
  test "the queue shows both parties and their lockers" do
    log_in_as @admin
    visit admin_swap_validations_path

    within "#swap-validation-row-#{@proposal.id}" do
      assert_text users(:dave).email
      assert_text users(:bob).email
      assert_text "Floor 4, locker D07"
      assert_text "Floor 3, locker B12"
    end
  end

  # User Story 1, FR-004.
  test "an admin validates an exchange and both lockers change hands" do
    log_in_as @admin
    visit admin_swap_validations_path

    within("#swap-validation-row-#{@proposal.id}") { click_on "Validate" }

    assert_text "Exchange validated"
    assert_no_selector "#swap-validation-row-#{@proposal.id}"
    assert_selector "#admin-swap-validations-empty"
    assert_equal [ "3", "B12" ], [ users(:dave).reload.floor, users(:dave).locker_number ]
    assert_equal [ "4", "D07" ], [ users(:bob).reload.floor, users(:bob).locker_number ]
  end

  test "a standard user has no way into the queue" do
    log_in_as users(:carol)

    visit admin_swap_validations_path

    assert_current_path root_path
    assert_text ApplicationController::ADMINISTRATORS_ONLY_MESSAGE
  end
end
