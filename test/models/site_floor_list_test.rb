require "test_helper"

# 030 User Story 1: the site's floor list — how a comma-separated line becomes
# the ordered list every floor field offers, and what is refused.
#
# No fixture file for this table, for the reason SiteLanguageSettingTest gives:
# `fixtures :all` would load it into every test in the suite, and "not
# configured" has to stay the baseline everything else runs under (FR-006,
# research.md R10).
class SiteFloorListTest < ActiveSupport::TestCase
  test ".current creates the one row, not configured" do
    list = SiteFloorList.current

    assert_predicate list, :persisted?
    assert_nil list.floors
    assert_not list.configured?
    assert_equal list, SiteFloorList.current
  end

  test "a second row is refused" do
    SiteFloorList.current

    second = SiteFloorList.new(floors_text: "1")

    assert_not second.valid?
    assert_includes second.errors[:base], "only one floor list may exist"
  end

  # FR-002: spaces trimmed, blanks dropped, a duplicate kept once — and the order
  # is the one typed, not a computed sort (clarification Q3).
  test "the typed line is cleaned up and keeps its order" do
    list = SiteFloorList.current
    list.floors_text = " 3, ,RDC, 1, 3 , 2"

    assert_equal %w[3 RDC 1 2], list.floors
    assert_equal "3, RDC, 1, 2", list.floors_text
  end

  # FR-003: nothing left after the clean-up is refused, and the list in force is
  # untouched.
  test "an empty list is refused and the previous one kept" do
    list = SiteFloorList.current
    list.update!(floors_text: "0, 1")

    assert_not list.update(floors_text: " , ,")
    assert_includes list.errors[:floors_text], I18n.t("floor_list.messages.required")
    assert_equal %w[0 1], list.reload.floors
  end

  test "a first save of an empty list is refused too" do
    assert_not SiteFloorList.current.update(floors_text: "")
    assert_nil SiteFloorList.current.reload.floors
  end

  test "more than fifty floors are refused" do
    list = SiteFloorList.current

    assert_not list.update(floors_text: (1..51).to_a.join(","))
    assert_includes list.errors[:floors_text], I18n.t("floor_list.messages.too_many", count: SiteFloorList::MAX_FLOORS)
    assert list.update(floors_text: (1..50).to_a.join(","))
  end

  test "a floor longer than twenty characters is refused" do
    list = SiteFloorList.current
    long = "x" * 21

    assert_not list.update(floors_text: "1, #{long}")
    assert_includes list.errors[:floors_text],
                    I18n.t("floor_list.messages.floor_too_long", floor: long, count: SiteFloorList::MAX_FLOOR_LENGTH)
    assert list.update(floors_text: "x" * 20)
  end

  test "offers? answers whether a floor is in the list" do
    list = SiteFloorList.current
    list.update!(floors_text: "0, 1, 2")

    assert list.offers?("2")
    assert_not list.offers?("7")
    assert_not list.offers?("02")
  end
end
