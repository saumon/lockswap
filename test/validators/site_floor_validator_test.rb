require "test_helper"

# 030 FR-005/FR-006: the one rule behind every floor save on the site, checked on
# a bare model so it is exercised apart from User's and LockerWish's own rules.
# The "left unchanged" half needs dirty tracking, so it is covered on the real
# models (UserTest, LockerWishTest).
class SiteFloorValidatorTest < ActiveSupport::TestCase
  class Record
    include ActiveModel::Model

    attr_accessor :floor

    validates :floor, site_floor: true
  end

  test "any floor is accepted while no list is saved" do
    assert_predicate Record.new(floor: "anything at all"), :valid?
  end

  test "a blank floor is left to the presence rules" do
    SiteFloorList.current.update!(floors_text: "0, 1")

    assert_predicate Record.new(floor: ""), :valid?
    assert_predicate Record.new(floor: nil), :valid?
  end

  test "a floor outside the list is refused" do
    SiteFloorList.current.update!(floors_text: "0, 1")
    record = Record.new(floor: "7")

    assert_not record.valid?
    assert_includes record.errors[:floor], I18n.t("errors.messages.floor_not_offered")
  end

  test "a listed floor is accepted" do
    SiteFloorList.current.update!(floors_text: "0, 1")

    assert_predicate Record.new(floor: "1"), :valid?
  end
end
