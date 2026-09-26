require "test_helper"

# 031 User Story 1/2: the site's authoritative "known locker" registry — one
# floor + locker number pair, belonging to one zone.
class LockerMapEntryTest < ActiveSupport::TestCase
  test "a locker number is required" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    entry = zone.locker_map_entries.new

    assert_not entry.valid?
    assert_includes entry.errors[:locker_number], "can't be blank"
  end

  # FR-007/FR-008/FR-012: unique per floor, site-wide — across zones, not just
  # within one.
  test "a locker number must be unique per floor, across zones, naming the zone that already holds it" do
    holder = Zone.create!(floor: "2", name: "Aile Nord")
    holder.locker_map_entries.create!(locker_number: "203")
    other_zone = Zone.create!(floor: "2", name: "Aile Sud")

    conflict = other_zone.locker_map_entries.new(locker_number: "203")
    assert_not conflict.valid?
    assert_includes conflict.errors[:locker_number],
                     I18n.t("locker_map_entry.messages.locker_taken", zone: "Aile Nord")

    other_floor_zone = Zone.create!(floor: "3", name: "Aile Nord")
    same_number_other_floor = other_floor_zone.locker_map_entries.new(locker_number: "203")
    assert same_number_other_floor.valid?, same_number_other_floor.errors.full_messages.to_sentence
  end

  # research.md R6: floor is derived from the parent zone, never settable
  # directly, so it can never drift from it.
  test "floor is derived from the parent zone" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    entry = zone.locker_map_entries.create!(locker_number: "203")

    assert_equal "2", entry.floor
  end

  test "the locker number is stripped of surrounding whitespace" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    entry = zone.locker_map_entries.create!(locker_number: " 203 ")

    assert_equal "203", entry.locker_number
  end

  test ".known? answers whether a floor + locker number pair is declared" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    zone.locker_map_entries.create!(locker_number: "203")

    assert LockerMapEntry.known?("2", "203")
    assert_not LockerMapEntry.known?("2", "999")
    assert_not LockerMapEntry.known?("3", "203")
    # normalizes its own input the same way the model does
    assert LockerMapEntry.known?("2", " 203 ")
  end

  # 032 FR-001–FR-004, research.md R1: the one batched lookup every screen that
  # shows a floor + locker number reads from.
  test ".zone_names_for resolves every declared pair in exactly one query, keyed by the pair" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    zone.locker_map_entries.create!(locker_number: "203")

    result = assert_queries_count(1) do
      LockerMapEntry.zone_names_for([ [ "2", "203" ], [ "2", "999" ] ])
    end

    assert_equal({ [ "2", "203" ] => "Aile Nord" }, result)
  end

  test ".zone_names_for returns {} for an empty or all-blank input, without querying" do
    assert_no_queries { assert_equal({}, LockerMapEntry.zone_names_for([])) }
    assert_no_queries { assert_equal({}, LockerMapEntry.zone_names_for([ [ nil, nil ], [ "", " " ] ])) }
  end

  test ".zone_name_for returns the zone's name for a declared pair, nil otherwise" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    zone.locker_map_entries.create!(locker_number: "203")

    assert_equal "Aile Nord", LockerMapEntry.zone_name_for("2", "203")
    assert_nil LockerMapEntry.zone_name_for("2", "999")
    assert_nil LockerMapEntry.zone_name_for(nil, nil)
  end

  # FR-007: a rename is reflected the very next time anything asks, since there
  # is no caching layer standing between the lookup and the database.
  test ".zone_name_for reflects a zone rename on the very next call" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    zone.locker_map_entries.create!(locker_number: "203")

    assert_equal "Aile Nord", LockerMapEntry.zone_name_for("2", "203")

    zone.update!(name: "Aile Sud")

    assert_equal "Aile Sud", LockerMapEntry.zone_name_for("2", "203")
  end

  test ".zone_name_for stops returning a pair once it is removed from its zone" do
    zone = Zone.create!(floor: "2", name: "Aile Nord")
    entry = zone.locker_map_entries.create!(locker_number: "203")

    assert_equal "Aile Nord", LockerMapEntry.zone_name_for("2", "203")

    entry.destroy!

    assert_nil LockerMapEntry.zone_name_for("2", "203")
  end
end
