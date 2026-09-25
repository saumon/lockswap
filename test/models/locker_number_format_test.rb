require "test_helper"

# 030 User Story 3: the locker number format — what a pattern accepts, what is
# refused as a pattern, and the examples the Danger Zone shows beside it.
#
# No fixture file for this table: "no format" is the baseline every other test
# runs under (research.md R10).
class LockerNumberFormatTest < ActiveSupport::TestCase
  def format_for(pattern, description: nil)
    LockerNumberFormat.new(pattern: pattern, description: description)
  end

  test ".current creates the one row, with no format in force" do
    format = LockerNumberFormat.current

    assert_predicate format, :persisted?
    assert_nil format.pattern
    assert_not format.in_force?
    assert_equal format, LockerNumberFormat.current
  end

  test "a second row is refused" do
    LockerNumberFormat.current

    second = LockerNumberFormat.new(pattern: "\\d")

    assert_not second.valid?
    assert_includes second.errors[:base], "only one locker number format may exist"
  end

  # FR-010. `(?x)\d{3} #` compiles on its own but not once anchored — the
  # extended-mode comment swallows the closing `)\z` — so it is the case that
  # proves the anchored form is what gets validated (research.md R4, analysis C1).
  test "a pattern that is not a valid regular expression is refused" do
    [ "[0-9", "(\\d", "*", "\\d{3}(?#", "(?x)\\d{3} #" ].each do |pattern|
      format = format_for(pattern)

      assert_not format.valid?, "expected #{pattern.inspect} to be refused"
      assert_includes format.errors[:pattern], I18n.t("locker_number_format.messages.invalid_pattern")
    end
  end

  # Ruby reads an unclosed brace as a literal, so this one is a valid pattern —
  # it just matches "12{3" (research.md R4).
  test "an unclosed brace is a valid pattern" do
    assert_predicate format_for("\\d{3"), :valid?
  end

  test "a pattern longer than 200 characters is refused" do
    assert_not format_for("\\d" * 101).valid?
    assert_predicate format_for("1" * 200), :valid?
  end

  test "a description longer than 100 characters is refused" do
    assert_not format_for("\\d{3}", description: "x" * 101).valid?
    assert_predicate format_for("\\d{3}", description: "x" * 100), :valid?
  end

  # FR-009 / User Story 3 scenario 4: clearing the pattern clears the format,
  # and a description on its own means nothing, so it goes too.
  test "a blank pattern means no format and takes the description with it" do
    format = LockerNumberFormat.current
    format.update!(pattern: "\\d{3}", description: "3 digits")

    format.update!(pattern: "  ", description: "3 digits")

    assert_nil format.pattern
    assert_nil format.description
    assert_not format.in_force?
  end

  test "pattern and description are stripped" do
    format = format_for("  \\d{3}  ", description: "  3 digits  ")
    format.validate

    assert_equal "\\d{3}", format.pattern
    assert_equal "3 digits", format.description
  end

  # FR-014: the whole value, never a part of it; surrounding spaces ignored.
  test "a pattern matches the whole value and ignores surrounding spaces" do
    format = format_for("\\d{3}")

    assert format.matches?("042")
    assert format.matches?(" 042 ")
    %w[42 0421 A42 12345].each { |value| assert_not format.matches?(value), value }
    assert_not format.matches?("042\n999")
  end

  test "anchors typed by the super admin change nothing" do
    format = format_for("^\\d{3}$")

    assert format.matches?("042")
    assert_not format.matches?("0421")
    assert_not format.matches?("042\n999")
  end

  # The pattern is grouped before it is anchored, so an alternation still has to
  # match the whole value on either side.
  test "an alternation must match the whole value" do
    format = format_for("\\d{3}|A\\d{2}")

    assert format.matches?("A12")
    assert format.matches?("123")
    assert_not format.matches?("A123")
    assert_not format.matches?("1234")
  end

  test "matching is case-sensitive, as written" do
    assert_not format_for("[A-Z]\\d{2}").matches?("b12")
  end

  # FR-018: a check that cannot finish in time is a refusal, not an exception.
  # A back-reference is what Ruby's match cache cannot make linear, so it is the
  # case the timeout still guards.
  #
  # The value carries the "b" the pattern requires, so Onigmo cannot rule the
  # match out up front and has to backtrack; measured to exceed the limit.
  test "a match that runs out of time is refused rather than raised" do
    format = format_for("(a*)*\\1b")
    assert_not Regexp.linear_time?(Regexp.new(format.pattern))

    assert_not format.matches?("a" * 40 + "cb")
  end

  # A row written before the anchored-form validation existed must not take the
  # locker profile save down with it.
  test "a stored pattern that no longer compiles matches nothing instead of raising" do
    LockerNumberFormat.current.update_columns(pattern: "(?x)\\d{3} #")

    assert_not LockerNumberFormat.current.matches?("042")
  end

  test "users are shown the description, or the pattern when there is none" do
    assert_equal "3 chiffres, ex. 042", format_for("\\d{3}", description: "3 chiffres, ex. 042").display
    assert_equal "\\d{3}", format_for("\\d{3}").display
  end

  # SC-004: the examples table computes its results with #matches?, so what it
  # claims is what the site does. These are the outcomes it must show — a change
  # to the matcher that moved any of them would change what the screen says.
  test "every example shows the outcome the site actually enforces" do
    expected = {
      "\\d{3}" => { "042" => true, "42" => false, "1234" => false },
      "\\d{1,3}" => { "7" => true, "042" => true, "1234" => false },
      "[A-Z]\\d{2}" => { "B12" => true, "b12" => false, "B123" => false },
      "\\d{2}-\\d{2}" => { "01-15" => true, "0115" => false },
      "(A|B)\\d{3}" => { "A042" => true, "C042" => false }
    }

    assert_equal expected.keys, LockerNumberFormat::EXAMPLES.map { |example| example[:pattern] }

    LockerNumberFormat::EXAMPLES.each do |example|
      outcomes = example[:samples].index_with { |sample| format_for(example[:pattern]).matches?(sample) }

      assert_equal expected.fetch(example[:pattern]), outcomes, example[:pattern]
    end
  end
end
