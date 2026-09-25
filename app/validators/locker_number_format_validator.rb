# 030 FR-013: a locker number must follow the format the super admin has set —
# the rule behind every locker number save (the user's own locker profile and
# an administrator's edit of it), declared with
# `validates :locker_number, locker_number_format: true` (research.md R5).
#
# Three cases are deliberately let through:
# - no format set: any locker number is accepted, as before this feature;
# - no locker number at all: "I don't have a locker" is an answer, not a number,
#   whatever the format (FR-015, 009);
# - a number that is not changing: one on file from before the format keeps
#   until it is next changed, and saving the form around it — say, to change
#   only the floor — is not a refusal (FR-017). The same reading
#   SiteFloorValidator takes for floors.
#
# The message names the format as users are meant to read it: the super admin's
# description when there is one, the pattern otherwise (clarification Q1).
class LockerNumberFormatValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.nil?
    return if record.respond_to?(:will_save_change_to_attribute?) && !record.will_save_change_to_attribute?(attribute)

    format = LockerNumberFormat.current
    return unless format.in_force?

    record.errors.add(attribute, :locker_number_format_mismatch, expected: format.display) unless format.matches?(value)
  end
end
