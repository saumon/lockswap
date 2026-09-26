require "test_helper"

# 031 User Story 1/3: creating, renaming, and (US3) deleting a zone.
class Admin::ZonesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "an admin creates a zone" do
    sign_in users(:grace)

    post admin_zones_path, params: { zone: { floor: "2", name: "Aile Nord" } }

    assert_redirected_to admin_locker_map_path
    assert_equal I18n.t("admin.zones.create.saved"), flash[:notice]
    assert Zone.exists?(floor: "2", name: "Aile Nord")
  end

  test "a blank name is refused" do
    sign_in users(:grace)

    post admin_zones_path, params: { zone: { floor: "2", name: "" } }

    assert_response :unprocessable_entity
    assert_not Zone.exists?(floor: "2")
  end

  # FR-004a
  test "a name duplicating an existing zone on the same floor is refused" do
    Zone.create!(floor: "2", name: "Aile Nord")
    sign_in users(:grace)

    post admin_zones_path, params: { zone: { floor: "2", name: "Aile Nord" } }

    assert_response :unprocessable_entity
    assert_equal 1, Zone.where(floor: "2", name: "Aile Nord").count
  end

  # FR-011
  test "a floor not in the site's configured list is refused" do
    SiteFloorList.current.update!(floors_text: "0, 1")
    sign_in users(:grace)

    post admin_zones_path, params: { zone: { floor: "9", name: "Aile Nord" } }

    assert_response :unprocessable_entity
    assert_not Zone.exists?(floor: "9")
  end

  test "an admin renames a zone" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    sign_in users(:grace)

    patch admin_zone_path(zone), params: { zone: { name: "Aile Nord Rénovée" } }

    assert_redirected_to admin_locker_map_path
    assert_equal I18n.t("admin.zones.update.saved"), flash[:notice]
    assert_equal "Aile Nord Rénovée", zone.reload.name
  end

  # FR-003/FR-004: the floor is fixed at creation.
  test "a submitted floor is ignored on rename" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    sign_in users(:grace)

    patch admin_zone_path(zone), params: { zone: { name: "Aile Nord", floor: "3" } }

    assert_equal "2", zone.reload.floor
  end

  test "renaming a zone that no longer exists redirects with zone_gone" do
    sign_in users(:grace)

    patch admin_zone_path(id: 999_999), params: { zone: { name: "Anything" } }

    assert_redirected_to admin_locker_map_path
    assert_equal I18n.t("admin.zones.update.zone_gone"), flash[:alert]
  end

  test "a standard account is refused" do
    sign_in users(:carol)

    post admin_zones_path, params: { zone: { floor: "2", name: "Aile Nord" } }

    assert_redirected_to root_path
    assert_not Zone.exists?(floor: "2")
  end

  test "a signed-out visitor is sent to sign in" do
    post admin_zones_path, params: { zone: { floor: "2", name: "Aile Nord" } }

    assert_redirected_to new_user_session_path
  end

  # US3, FR-006, research.md R4: cascading delete, no separate emptying step.
  test "deleting a zone destroys it and its locker map entries in one action" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    zone.locker_map_entries.create!(locker_number: "201")
    zone.locker_map_entries.create!(locker_number: "202")
    sign_in users(:grace)

    assert_difference "Zone.count", -1 do
      assert_difference "LockerMapEntry.count", -2 do
        delete admin_zone_path(zone)
      end
    end

    assert_redirected_to admin_locker_map_path
    assert_equal I18n.t("admin.zones.destroy.deleted"), flash[:notice]
  end

  # Idempotent: arriving second reports success, mirrors grant_admin.
  test "deleting an already-deleted zone reports success rather than erroring" do
    sign_in users(:grace)

    delete admin_zone_path(id: 999_999)

    assert_redirected_to admin_locker_map_path
    assert_equal I18n.t("admin.zones.destroy.deleted"), flash[:notice]
  end

  test "a standard account is refused on destroy" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    sign_in users(:carol)

    delete admin_zone_path(zone)

    assert_redirected_to root_path
    assert Zone.exists?(zone.id)
  end

  test "a signed-out visitor is sent to sign in on destroy" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")

    delete admin_zone_path(zone)

    assert_redirected_to new_user_session_path
  end
end
