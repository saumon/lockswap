# 025 FR-004: the site-wide interface language, not a per-user preference.
# Exactly one row, ever — .current is the only sanctioned way to read or create
# it, so no other code queries this table directly (data-model.md).
class SiteLanguageSetting < ApplicationRecord
  # FR-005/SC-002: what a fresh install behaves as before an administrator has
  # ever saved this screen.
  DEFAULT_LANGUAGE = "en".freeze

  # FR-003: exactly two choices, made unrepresentable any other way — the same
  # reasoning as AllowedEmailDomain#domain's format validation.
  validates :language, presence: true, inclusion: { in: %w[en fr] }

  # Singleton guard (data-model.md): refuses a second row rather than trusting
  # every future caller to only ever call .current. Scoped on: :create so an
  # ordinary #update (the only write path this feature has) is never blocked
  # by the row it is updating.
  validate :only_one_row_may_exist, on: :create

  # The only way any other code reads or creates this row (data-model.md
  # "Class-level access"). On an empty table this both creates and returns the
  # default-language row, which is what makes User Story 2 true with no
  # separate migration-time seed.
  def self.current
    first_or_create!(language: DEFAULT_LANGUAGE)
  end

  private

    def only_one_row_may_exist
      errors.add(:base, "only one site language setting may exist") if self.class.exists?
    end
end
