require "application_system_test_case"

# 014 spec.md User Story 2: either password field can be read back in plain
# text, on its own. A typo in a field of dots is something you only find out
# about later, from the wrong side of a login form.
class PasswordVisibilityTest < ApplicationSystemTestCase
  PASSWORD = "#user_password".freeze
  CONFIRMATION = "#user_password_confirmation".freeze

  setup { visit new_user_registration_path }

  # Acceptance Scenarios 1 and 2 (FR-005): it reveals, and it puts it back.
  test "the password field's eye control reveals it and masks it again" do
    fill_in_reliably "Password", with: "password123"
    assert_masked PASSWORD

    find("button[aria-label='Show password']").click

    assert_revealed PASSWORD
    assert_field "Password", with: "password123"

    find("button[aria-label='Hide password']").click

    assert_masked PASSWORD
  end

  # Acceptance Scenario 3 (FR-006): two fields, two controls, and neither one
  # speaks for the other. Revealing what you are checking should not put the
  # other field on screen for whoever else is in the room.
  test "each field's eye control acts only on its own field" do
    fill_in_reliably "Password", with: "password123"
    fill_in_reliably "Confirm password", with: "password123"

    find("button[aria-label='Show confirm password']").click

    assert_revealed CONFIRMATION
    assert_masked PASSWORD

    find("button[aria-label='Show password']").click

    assert_revealed PASSWORD
    assert_revealed CONFIRMATION

    find("button[aria-label='Hide confirm password']").click

    assert_masked CONFIRMATION
    assert_revealed PASSWORD
  end

  # Acceptance Scenario 4 (FR-007): revealed stays revealed while you type. The
  # point is to watch the keys land, which is no use if it re-masks after each
  # one.
  test "characters typed after revealing stay readable" do
    find("button[aria-label='Show password']").click
    fill_in_reliably "Password", with: "password"

    find(PASSWORD).send_keys("123")

    assert_revealed PASSWORD
    assert_field "Password", with: "password123"
  end

  # Edge Case (FR-007): the reveal lasts as long as the visit and no longer —
  # coming back to the page should not put a password on screen for someone who
  # did not ask for it this time.
  test "a fresh page load starts both fields masked" do
    find("button[aria-label='Show password']").click
    find("button[aria-label='Show confirm password']").click
    assert_revealed PASSWORD
    assert_revealed CONFIRMATION

    page.refresh

    assert_masked PASSWORD
    assert_masked CONFIRMATION
  end

  # Edge Case (FR-008): reachable and operable without a pointer, and the state
  # is carried by the control's name rather than by the shape of an icon — which
  # is the whole of the information for anyone who is not looking at it.
  test "the eye control is reachable and operable from the keyboard" do
    fill_in_reliably "Password", with: "password123"

    find(PASSWORD).send_keys(:tab)

    assert_equal "Show password", focused_aria_label

    page.driver.browser.action.send_keys(:enter).perform

    assert_revealed PASSWORD
    assert_equal "Hide password", focused_aria_label
  end

  private

    def assert_masked(field)
      assert_selector "#{field}[type='password']"
    end

    def assert_revealed(field)
      assert_selector "#{field}[type='text']"
    end

    def focused_aria_label
      page.evaluate_script("document.activeElement.getAttribute('aria-label')")
    end
end
