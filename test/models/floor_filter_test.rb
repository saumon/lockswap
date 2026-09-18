require "test_helper"

# 017: the ordering rule (FR-007) and the keep-the-selection-visible rule
# (FR-015, FR-020), both of which belong to one axis of the filter and to neither
# model. No database is touched — a FloorFilter is handed the floors that were
# found and the value that was asked for, and answers what the view needs.
class FloorFilterTest < ActiveSupport::TestCase
  # --- FR-007: the order the choices are offered in --------------------------

  # The whole reason this rule exists: sorted as text, "10" lands between "1" and
  # "2", which reads as a bug to anyone scanning for their floor.
  test "floors that read as numbers are offered in numeric order" do
    filter = FloorFilter.new(selection: nil, available: %w[10 3 1 2])

    assert_equal %w[1 2 3 10], filter.choices
  end

  # Basements sort where they belong rather than after everything else.
  test "a negative floor sorts ahead of the positive ones" do
    filter = FloorFilter.new(selection: nil, available: %w[1 -1 0])

    assert_equal %w[-1 0 1], filter.choices
  end

  test "floors that do not read as numbers come after every number, alphabetically" do
    filter = FloorFilter.new(selection: nil, available: %w[Sous-sol 10 RDC 2])

    assert_equal %w[2 10 RDC Sous-sol], filter.choices
  end

  # Deliberate, and recorded in research R4: Integer() keeps the numeric group to
  # whole floors, so "3.5" is grouped with the words rather than given a
  # surprising position among the numbers.
  test "a fractional floor is treated as a word, not a number" do
    filter = FloorFilter.new(selection: nil, available: %w[3.5 10 2])

    assert_equal %w[2 10 3.5], filter.choices
  end

  # Ruby's Integer() reads a leading zero as octal unless a base is given, which
  # would put "010" before "9". The spec's edge case also requires "3" and "03" to
  # be adjacent and in a settled order rather than one that varies between runs.
  test "leading zeroes are read in base ten and order consistently" do
    filter = FloorFilter.new(selection: nil, available: %w[9 010 3 03])

    assert_equal %w[03 3 9 010], filter.choices
    assert_equal filter.choices, FloorFilter.new(selection: nil, available: %w[03 010 3 9]).choices
  end

  test "blank and duplicate floors are not offered" do
    filter = FloorFilter.new(selection: nil, available: [ "3", "3", "", "   ", nil, "5" ])

    assert_equal %w[3 5], filter.choices
  end

  # --- FR-003: what "all floors" means --------------------------------------

  test "no selection means the axis is not filtering" do
    assert_not FloorFilter.new(selection: nil, available: %w[3]).filtering?
  end

  # ?looking_for= is how a browser sends an empty field; it means all floors, not
  # "the floor named empty string".
  test "an empty or whitespace-only selection is the same as none" do
    [ "", "   " ].each do |blank|
      filter = FloorFilter.new(selection: blank, available: %w[3])

      assert_not filter.filtering?, "#{blank.inspect} should mean all floors"
      assert_nil filter.selection
    end
  end

  test "a selection that names a floor is filtering on it" do
    filter = FloorFilter.new(selection: "3", available: %w[3 5])

    assert_predicate filter, :filtering?
    assert filter.current?("3")
    assert_not filter.current?("5")
  end

  # The spec rules out normalisation, so the value is matched as it arrived.
  test "a selection is not trimmed or otherwise rewritten" do
    assert_equal " 3 ", FloorFilter.new(selection: " 3 ", available: %w[3]).selection
  end

  # --- FR-015 / FR-020: a selection no floor carries -------------------------

  # The pair the clarify pass found in conflict: FR-004/FR-005 offer only floors
  # that exist, FR-015 says the selection stays visible. Both hold if the
  # selection is appended when it is missing.
  test "a selection absent from the available floors is still offered, and marked current" do
    filter = FloorFilter.new(selection: "7", available: %w[3 5])

    assert_equal %w[3 5 7], filter.choices
    assert filter.current?("7")
  end

  # FR-020: junk arriving in the address is an empty result the viewer can see and
  # undo, not an error and not a silent reset to the full list.
  test "a selection matching nothing at all is still offered" do
    filter = FloorFilter.new(selection: "NOPE", available: %w[3 5])

    assert_equal %w[3 5 NOPE], filter.choices
    assert_predicate filter, :filtering?
  end

  test "a selection already among the available floors is not offered twice" do
    filter = FloorFilter.new(selection: "3", available: %w[3 5])

    assert_equal %w[3 5], filter.choices
  end

  test "no selection appends nothing" do
    filter = FloorFilter.new(selection: nil, available: %w[3 5])

    assert_equal %w[3 5], filter.choices
  end

  # User Story 4, Acceptance Scenario 2: nothing to filter is not an error.
  test "no available floors and no selection offers nothing" do
    assert_empty FloorFilter.new(selection: nil, available: []).choices
  end
end
