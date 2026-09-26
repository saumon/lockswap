require "test_helper"

# 031 User Story 1: a named group of lockers, fixed to one floor at creation.
#
# No fixture file for this table: the map starts empty on every fresh test
# database, matching FR-013's premise for a real deployment (tasks.md
# Conventions).
class ZoneTest < ActiveSupport::TestCase
  test "a name is required" do
    zone = Zone.new(floor: "2")

    assert_not zone.valid?
    assert_includes zone.errors[:name], "can't be blank"
  end

  # FR-004a: unique per floor, not site-wide.
  test "a name must be unique among the zones on the same floor, but may repeat on another" do
    Zone.create!(floor: "2", name: "Aile Nord")

    same_floor = Zone.new(floor: "2", name: "Aile Nord")
    assert_not same_floor.valid?
    assert_includes same_floor.errors[:name], I18n.t("zone.messages.name_taken")

    other_floor = Zone.new(floor: "3", name: "Aile Nord")
    assert other_floor.valid?, other_floor.errors.full_messages.to_sentence
  end

  test "a name longer than sixty characters is refused" do
    zone = Zone.new(floor: "2", name: "x" * 61)

    assert_not zone.valid?
    assert_includes zone.errors[:name], "is too long (maximum is #{Zone::MAX_NAME_LENGTH} characters)"

    zone.name = "x" * 60
    assert zone.valid?, zone.errors.full_messages.to_sentence
  end

  test "a floor is required" do
    zone = Zone.new(name: "Aile Nord")

    assert_not zone.valid?
    assert_includes zone.errors[:floor], "can't be blank"
  end

  # FR-011: reuses SiteFloorValidator unchanged.
  test "a floor outside the site's list is refused once one is configured" do
    SiteFloorList.current.update!(floors_text: "0, 1, 2")
    zone = Zone.new(floor: "7", name: "Aile Nord")

    assert_not zone.valid?
    assert_includes zone.errors[:floor], I18n.t("errors.messages.floor_not_offered")

    zone.floor = "2"
    assert zone.valid?, zone.errors.full_messages.to_sentence
  end

  test "any floor is accepted while no list is configured" do
    zone = Zone.new(floor: "anything", name: "Aile Nord")

    assert zone.valid?, zone.errors.full_messages.to_sentence
  end

  # research.md R2: solely so the new-zone form can reuse shared/_floor_field.
  test "saved_floor reads the persisted floor and is nil on a new record" do
    zone = Zone.new(floor: "2", name: "Aile Nord")
    assert_nil zone.saved_floor

    zone.save!
    assert_equal "2", zone.saved_floor
  end

  # FR-006, research.md R4: deleting a zone cascades to its locker map entries.
  test "deleting a zone destroys its locker map entries too" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    zone.locker_map_entries.create!(locker_number: "201")
    zone.locker_map_entries.create!(locker_number: "202")

    assert_difference "LockerMapEntry.count", -2 do
      zone.destroy
    end
  end
end
