require "test_helper"

# 031 FR-010: the one rule behind every locker profile save on the site,
# checked on a bare model. The "left unchanged" half needs dirty tracking
# (research.md R3's OR of two attributes), so it is covered on User
# (UserTest) instead — mirrors SiteFloorValidatorTest's own split.
class KnownLockerValidatorTest < ActiveSupport::TestCase
  class Record
    include ActiveModel::Model

    attr_accessor :floor, :locker_number

    validates :locker_number, known_locker: true
  end

  test "a blank locker number is left to the presence rules" do
    assert_predicate Record.new(floor: "2", locker_number: ""), :valid?
    assert_predicate Record.new(floor: "2", locker_number: nil), :valid?
  end

  test "a blank floor is a no-op" do
    assert_predicate Record.new(floor: "", locker_number: "203"), :valid?
    assert_predicate Record.new(floor: nil, locker_number: "203"), :valid?
  end

  # FR-013a, research.md R8: the map's own "not configured" baseline — every
  # pair is accepted while nothing has ever been declared anywhere, mirroring
  # SiteFloorList/LockerNumberFormat.
  test "any pair is accepted while the map is empty, site-wide" do
    assert_predicate Record.new(floor: "2", locker_number: "999"), :valid?
  end

  # Once anything at all is declared, the check activates everywhere — even
  # for a floor with nothing declared on it.
  test "an undeclared pair is refused once the map has at least one entry anywhere" do
    Zone.create!(floor: "9", name: "Elsewhere").locker_map_entries.create!(locker_number: "1")
    record = Record.new(floor: "2", locker_number: "999")

    assert_not record.valid?
    assert_includes record.errors[:locker_number], I18n.t("errors.messages.locker_number_unknown")
  end

  test "a declared pair is accepted" do
    Zone.create!(floor: "2", name: "Aile Nord").locker_map_entries.create!(locker_number: "203")

    assert_predicate Record.new(floor: "2", locker_number: "203"), :valid?
  end
end
