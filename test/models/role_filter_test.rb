require "test_helper"

# 020: the fixed, closed choice pair (FR-006) — no database, no derivation.
class RoleFilterTest < ActiveSupport::TestCase
  test "the choices are the fixed pair, in order" do
    assert_equal %w[Admin Standard], RoleFilter.new(selection: nil).choices
  end

  test "no selection means the axis is not filtering" do
    assert_not RoleFilter.new(selection: nil).filtering?
  end

  test "an empty or whitespace-only selection is the same as none" do
    [ "", "   " ].each do |blank|
      filter = RoleFilter.new(selection: blank)

      assert_not filter.filtering?, "#{blank.inspect} should mean all roles"
      assert_nil filter.selection
    end
  end

  test "a selection names the choice in force" do
    filter = RoleFilter.new(selection: "Admin")

    assert_predicate filter, :filtering?
    assert filter.current?("Admin")
    assert_not filter.current?("Standard")
  end
end
