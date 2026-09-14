require "application_system_test_case"

# The site-wide navigation in app/views/layouts/application.html.erb.
class NavigationTest < ApplicationSystemTestCase
  # 008: the signed-out screens carry no header. They already lead with the full
  # stacked lock-up, so a bar would show the brand twice, and it would hold
  # nothing else — every control in it is behind user_signed_in?.
  test "the sign-in and sign-up screens have no header bar" do
    visit new_user_session_path
    assert_no_selector "header"
    assert_no_selector "nav[aria-label=Main]"
    assert_selector "[data-brand-mark]", visible: :all

    visit new_user_registration_path
    assert_no_selector "header"
    assert_selector "[data-brand-mark]", visible: :all
  end

  test "a signed-in visitor gets the header back" do
    log_in_as users(:carol)

    assert_selector "header nav[aria-label=Main]"
    assert_link "Locker wishes"
    assert_link "Proposal history"
  end

  test "the wordmark takes a logged-in visitor back to the homepage" do
    log_in_as users(:carol)
    visit locker_wishes_path
    assert_no_text "Welcome to LockSwap"

    click_on "LockSwap"

    assert_current_path root_path
    assert_text "Welcome to LockSwap"
  end
end
