require "test_helper"

# 030 FR-013/FR-015: the rule behind every locker number save, checked on a bare
# model. The "left unchanged" half needs dirty tracking, so it is covered on
# User itself (UserTest).
class LockerNumberFormatValidatorTest < ActiveSupport::TestCase
  class Record
    include ActiveModel::Model

    attr_accessor :locker_number

    validates :locker_number, locker_number_format: true
  end

  test "any locker number is accepted while no format is set" do
    assert_predicate Record.new(locker_number: "anything"), :valid?
  end

  # FR-015: "no locker" is not a locker number, whatever the format.
  test "no locker number is accepted whatever the format" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}")

    assert_predicate Record.new(locker_number: nil), :valid?
  end

  test "a number that does not match is refused, naming the description" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}", description: "3 chiffres, ex. 042")
    record = Record.new(locker_number: "42")

    assert_not record.valid?
    assert_includes record.errors[:locker_number],
                    I18n.t("errors.messages.locker_number_format_mismatch", expected: "3 chiffres, ex. 042")
  end

  test "with no description, the refusal names the pattern itself" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}")
    record = Record.new(locker_number: "42")

    assert_not record.valid?
    assert_includes record.errors[:locker_number],
                    I18n.t("errors.messages.locker_number_format_mismatch", expected: "\\d{3}")
  end

  test "a number that matches is accepted" do
    LockerNumberFormat.current.update!(pattern: "\\d{3}")

    assert_predicate Record.new(locker_number: "042"), :valid?
  end
end
