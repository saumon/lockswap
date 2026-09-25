# 030 FR-005: a floor must be one the super admin has listed — the single rule
# behind every floor save on the site (the user's own locker profile, an
# administrator's edit of it, and a locker wish), declared on each model with
# `validates :floor, site_floor: true` rather than restated per model
# (research.md R3).
#
# Three cases are deliberately let through:
# - no list saved yet: floors are free text until the first save (FR-006);
# - a blank floor: whether one is required is the presence rule's business;
# - a floor that is not changing: a record on a floor since removed from the
#   list keeps it until it is next edited, and saving it untouched — say, to
#   change only the locker number — is not a refusal (FR-007, FR-011). The same
#   "is it actually moving" reading User#locker_details_held_by_active_swap uses.
class SiteFloorValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?
    return if record.respond_to?(:will_save_change_to_attribute?) && !record.will_save_change_to_attribute?(attribute)

    floor_list = SiteFloorList.current
    return unless floor_list.configured?

    record.errors.add(attribute, :floor_not_offered) unless floor_list.offers?(value)
  end
end
