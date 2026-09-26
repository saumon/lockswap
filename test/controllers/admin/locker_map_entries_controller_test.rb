require "test_helper"

# 031 User Story 1/3: declaring and (US3) removing a locker number within a
# zone.
class Admin::LockerMapEntriesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "an admin declares a locker number" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    sign_in users(:grace)

    post admin_zone_locker_map_entries_path(zone), params: { locker_map_entry: { locker_number: "203" } }

    assert_redirected_to admin_locker_map_path
    assert_equal I18n.t("admin.locker_map_entries.create.saved"), flash[:notice]
    entry = zone.locker_map_entries.find_by(locker_number: "203")
    assert entry
    assert_equal "2", entry.floor
  end

  test "a blank locker number is refused" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    sign_in users(:grace)

    post admin_zone_locker_map_entries_path(zone), params: { locker_map_entry: { locker_number: "" } }

    assert_response :unprocessable_entity
    assert_equal 0, zone.locker_map_entries.count
  end

  # FR-008
  test "a locker number already claimed by a different zone on the same floor is refused, naming that zone" do
    holder = Zone.create!(floor: "2", name: "Aile Nord")
    holder.locker_map_entries.create!(locker_number: "203")
    other_zone = Zone.create!(floor: "2", name: "Aile Sud")
    sign_in users(:grace)

    post admin_zone_locker_map_entries_path(other_zone), params: { locker_map_entry: { locker_number: "203" } }

    assert_response :unprocessable_entity
    assert_select "body", text: /Aile Nord/
    assert_equal 0, other_zone.locker_map_entries.count
  end

  # finding H1
  test "declaring a locker under a zone that no longer exists redirects with zone_gone" do
    sign_in users(:grace)

    post admin_zone_locker_map_entries_path(zone_id: 999_999), params: { locker_map_entry: { locker_number: "203" } }

    assert_redirected_to admin_locker_map_path
    assert_equal I18n.t("admin.locker_map_entries.create.zone_gone"), flash[:alert]
    assert_not LockerMapEntry.exists?(locker_number: "203")
  end

  test "a standard account is refused" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    sign_in users(:carol)

    post admin_zone_locker_map_entries_path(zone), params: { locker_map_entry: { locker_number: "203" } }

    assert_redirected_to root_path
    assert_equal 0, zone.locker_map_entries.count
  end

  test "a signed-out visitor is sent to sign in" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")

    post admin_zone_locker_map_entries_path(zone), params: { locker_map_entry: { locker_number: "203" } }

    assert_redirected_to new_user_session_path
  end

  # US3, FR-006
  test "deleting an entry removes only it, leaving the zone and its other entries intact" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    keep = zone.locker_map_entries.create!(locker_number: "201")
    remove = zone.locker_map_entries.create!(locker_number: "202")
    sign_in users(:grace)

    delete admin_zone_locker_map_entry_path(zone, remove)

    assert_redirected_to admin_locker_map_path
    assert_equal I18n.t("admin.locker_map_entries.destroy.deleted"), flash[:notice]
    assert Zone.exists?(zone.id)
    assert LockerMapEntry.exists?(keep.id)
    assert_not LockerMapEntry.exists?(remove.id)
  end

  test "deleting an already-gone entry reports success rather than erroring" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    sign_in users(:grace)

    delete admin_zone_locker_map_entry_path(zone, id: 999_999)

    assert_redirected_to admin_locker_map_path
    assert_equal I18n.t("admin.locker_map_entries.destroy.deleted"), flash[:notice]
  end
end
