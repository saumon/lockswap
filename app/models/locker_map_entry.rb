# 031 FR-005 through FR-008, FR-012: the declaration that one floor + locker
# number pair exists and belongs to one zone — the site's authoritative
# "known locker" registry. Every existing locker-number field is validated
# against it (KnownLockerValidator).
class LockerMapEntry < ApplicationRecord
  belongs_to :zone

  # research.md R6: derived from the parent zone, never settable directly, so
  # it can never drift from it — the zone's own floor is itself immutable
  # after creation.
  before_validation { self.floor = zone&.floor }

  normalizes :locker_number, with: ->(value) { value.to_s.strip.presence }

  # FR-008: the friendly pre-check, naming the zone that already holds this
  # floor + locker number. The unique index on (floor, locker_number) is the
  # actual, race-safe guarantee (research.md R6) — this validator only makes
  # the common case a clear message instead of a raised exception.
  validates :locker_number, presence: true,
            uniqueness: { scope: :floor, message: ->(entry, _data) {
              holder = LockerMapEntry.joins(:zone).find_by(floor: entry.floor, locker_number: entry.locker_number)
              I18n.t("locker_map_entry.messages.locker_taken", zone: holder&.zone&.name)
            } }

  # FR-010: the one query KnownLockerValidator calls. Normalizes its own
  # input the same way the model does, so a validator call from `User`
  # (already normalized) and a direct call agree.
  def self.known?(floor, locker_number)
    floor = floor.to_s.strip.presence
    locker_number = locker_number.to_s.strip.presence
    return false if floor.nil? || locker_number.nil?

    exists?(floor: floor, locker_number: locker_number)
  end

  # 032 FR-001–FR-004, research.md R1: the one place every screen that shows a
  # floor + locker number asks "what zone, if any, currently claims it?" — one
  # query regardless of how many pairs are asked for, so a list of N rows never
  # costs N queries (Principle IV, contracts/zone-lookup.md).
  #
  # A pair not currently declared is simply absent from the result — never
  # present with a `nil` value — so callers read "no zone" with plain `Hash#[]`.
  def self.zone_names_for(pairs)
    normalized = pairs.map { |floor, locker_number|
      [ floor.to_s.strip.presence, locker_number.to_s.strip.presence ]
    }.uniq.reject { |floor, locker_number| floor.nil? || locker_number.nil? }

    return {} if normalized.empty?

    floors = normalized.map(&:first).uniq
    locker_numbers = normalized.map(&:last).uniq

    joins(:zone).where(floor: floors, locker_number: locker_numbers)
                .pluck(:floor, :locker_number, "zones.name")
                .each_with_object({}) do |(floor, locker_number, zone_name), result|
      pair = [ floor, locker_number ]
      result[pair] = zone_name if normalized.include?(pair)
    end
  end

  # The single-pair convenience wrapper every single-record screen calls.
  def self.zone_name_for(floor, locker_number)
    pair = [ floor.to_s.strip.presence, locker_number.to_s.strip.presence ]
    zone_names_for([ pair ])[pair]
  end
end
