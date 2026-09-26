# 031 FR-010: the rule behind every locker profile save on the site (the user's
# own locker profile and an administrator's edit of it) — declared with
# `validates :locker_number, known_locker: true` (research.md R3).
#
# Three cases are deliberately let through:
# - the map has never had anything declared in it, site-wide: any locker
#   number is accepted, as before this feature (research.md R8 — mirrors
#   SiteFloorList/LockerNumberFormat's own "not configured" permissiveness,
#   and is what keeps every pre-existing save path working on a fresh site);
# - no locker number, or no floor: "I don't have a locker" is an answer, not a
#   pair to check, and a floor is presence's business (FR-015-equivalent);
# - **neither** the locker number **nor** the floor is changing: an
#   already-saved pair not yet declared in the map keeps validating until it
#   is next actually moving (FR-013). This is the OR of two attributes,
#   not the single-attribute skip SiteFloorValidator/LockerNumberFormatValidator
#   use — the pair, not either half alone, is what has to be known (research.md
#   R3, spec User Story 2 scenario 4).
class KnownLockerValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?
    return if record.floor.blank?
    return unless LockerMapEntry.exists?
    if record.respond_to?(:will_save_change_to_attribute?)
      return if !record.will_save_change_to_attribute?(attribute) && !record.will_save_change_to_attribute?(:floor)
    end

    record.errors.add(attribute, :locker_number_unknown) unless LockerMapEntry.known?(record.floor, value)
  end
end
