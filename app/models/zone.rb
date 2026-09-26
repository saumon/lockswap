# 031 FR-002/FR-003: a named group of lockers, declared by an admin on the
# Locker Map screen, located on exactly one floor. The floor is set once, at
# creation, and no controller action ever assigns it again (031
# clarification) — so `site_floor` below needs no `on:` restriction of its
# own: it already no-ops whenever `floor` is not changing (SiteFloorValidator),
# and since nothing ever changes it after creation, it is naturally inert on
# every later save without having to say so explicitly.
class Zone < ApplicationRecord
  MAX_NAME_LENGTH = 60

  has_many :locker_map_entries, dependent: :destroy

  normalizes :name, with: ->(value) { value.to_s.strip.presence }

  # FR-004a: unique per floor, not site-wide — the same name is fine on a
  # different floor.
  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH },
            uniqueness: { scope: :floor, message: ->(_record, _data) { I18n.t("zone.messages.name_taken") } }

  # FR-011: a zone can only be declared on a floor the rest of the site also
  # recognizes.
  validates :floor, presence: true, site_floor: true

  # research.md R2: solely so the standalone new-zone form can render
  # `shared/_floor_field` unmodified, the same interface `User`/`LockerWish`
  # already give it.
  def saved_floor = floor_in_database
end
