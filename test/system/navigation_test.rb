require "application_system_test_case"

# The site-wide navigation in app/views/layouts/application.html.erb.
class NavigationTest < ApplicationSystemTestCase
  test "the wordmark takes a logged-in visitor back to the homepage" do
    log_in_as users(:carol)
    visit locker_wishes_path
    assert_no_text "Welcome to LockSwap"

    click_on "LockSwap"

    assert_current_path root_path
    assert_text "Welcome to LockSwap"
  end
end
