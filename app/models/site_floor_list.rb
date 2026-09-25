# 030 FR-001: the floors that exist in the building, set by the super admin on
# the Danger Zone — the only source of choices for every floor entry field once
# it has been saved. Exactly one row, ever: .current is the only sanctioned way
# to read or create it, as with SiteLanguageSetting (025).
#
# `floors` is NULL until the first save, and that is a state rather than a gap:
# while it holds, every floor field stays free text and accepts anything, exactly
# as before this feature (FR-006). Nothing seeds it (clarification Q2).
class SiteFloorList < ApplicationRecord
  # Bounds on what one list can hold, so the select every floor field renders
  # and the check every save runs stay small (Principle IV).
  MAX_FLOORS = 50
  MAX_FLOOR_LENGTH = 20

  validate :floors_listed, if: :will_save_change_to_floors?

  # Singleton guard, as SiteLanguageSetting's: refuses a second row rather than
  # trusting every caller to go through .current.
  validate :only_one_row_may_exist, on: :create

  # The only way any other code reads or creates this row. On an empty table
  # this creates the not-configured row, so no seed is needed.
  def self.current
    first_or_create!(floors: nil)
  end

  # FR-006: false until the super admin has saved a list — the switch between
  # free-text floor fields and selectable ones.
  def configured? = floors.present?

  # FR-005: exact membership. Floors are labels, matched exactly as listed —
  # "02" is not "2".
  def offers?(floor) = Array(floors).include?(floor)

  # The Danger Zone edits the list as one comma-separated line, which is how the
  # super admin thinks of it ("0, 1, 2, 3").
  def floors_text = Array(floors).join(", ")

  # FR-002: spaces trimmed, empty entries dropped, a repeated floor kept once at
  # its first position. The order typed is kept, because it is the order every
  # floor field offers (clarification Q3) — a building's "RDC, 1, 2, Mezzanine"
  # is not something a sort could reconstruct.
  def floors_text=(text)
    self.floors = text.to_s.split(",").map(&:strip).compact_blank.uniq
  end

  private

    # FR-003: once a list is being saved it must hold at least one floor, which
    # also makes the return to "not configured" impossible — an empty line is
    # refused rather than read as "clear the list".
    def floors_listed
      if floors.blank?
        errors.add(:floors_text, I18n.t("floor_list.messages.required"))
      elsif floors.size > MAX_FLOORS
        errors.add(:floors_text, I18n.t("floor_list.messages.too_many", count: MAX_FLOORS))
      elsif (long = floors.find { |floor| floor.length > MAX_FLOOR_LENGTH })
        errors.add(:floors_text, I18n.t("floor_list.messages.floor_too_long", floor: long, count: MAX_FLOOR_LENGTH))
      end
    end

    def only_one_row_may_exist
      errors.add(:base, "only one floor list may exist") if self.class.exists?
    end
end
