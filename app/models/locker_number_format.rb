# 030 FR-009: the format every entered locker number must follow, set by the
# super admin on the Danger Zone as a regular expression — plus, optionally, the
# plain-language wording users are shown in its place (clarification Q1). Exactly
# one row, ever: .current is the only sanctioned way to read or create it, as
# with SiteLanguageSetting (025).
#
# A NULL pattern is "no format": any locker number is accepted, exactly as
# before this feature.
class LockerNumberFormat < ApplicationRecord
  MAX_PATTERN_LENGTH = 200
  MAX_DESCRIPTION_LENGTH = 100

  # FR-018: how long one value may take to check. Ruby 3.4's match cache already
  # makes the classic catastrophic patterns linear; a back-reference is what it
  # cannot memoise, and this is the bound for those (research.md R4).
  MATCH_TIMEOUT = 0.1

  # FR-012: the reference patterns the Danger Zone shows beside the field. Only
  # the patterns and their samples live here — whether each sample is accepted is
  # never written down, but computed with #matches? when the table is drawn, so
  # the screen cannot claim what the site does not do (SC-004, research.md R8).
  # The meanings are locale keys under admin.danger_zone.show.format_examples.
  EXAMPLES = [
    { pattern: "\\d{3}", key: :three_digits, samples: %w[042 42 1234] },
    { pattern: "\\d{1,3}", key: :one_to_three_digits, samples: %w[7 042 1234] },
    { pattern: "[A-Z]\\d{2}", key: :letter_then_two_digits, samples: %w[B12 b12 B123] },
    { pattern: "\\d{2}-\\d{2}", key: :two_pairs_with_dash, samples: %w[01-15 0115] },
    { pattern: "(A|B)\\d{3}", key: :a_or_b_then_three_digits, samples: %w[A042 C042] }
  ].freeze

  normalizes :pattern, :description, with: ->(value) { value.to_s.strip.presence }

  # FR-009: a description without a pattern describes nothing, so clearing the
  # pattern clears it too rather than leaving it to resurface with the next one.
  before_validation { self.description = nil if pattern.nil? }

  validates :pattern, length: { maximum: MAX_PATTERN_LENGTH }
  validates :description, length: { maximum: MAX_DESCRIPTION_LENGTH }
  validate :pattern_compiles

  # Singleton guard, as SiteLanguageSetting's.
  validate :only_one_row_may_exist, on: :create

  # The only way any other code reads or creates this row. On an empty table
  # this creates the no-format row, so no seed is needed.
  def self.current
    first_or_create!
  end

  # True once the super admin has saved a pattern — the switch every locker
  # number check and hint reads.
  def in_force? = pattern.present?

  # FR-013/FR-014, and the only matcher on the site: the enforcing validator and
  # the examples table both call it, so they cannot disagree. The value is
  # stripped and must match in full.
  #
  # A check that runs out of time is a refusal (FR-018). So is a stored pattern
  # that does not compile — only reachable for a row written around the
  # validation below, and not worth taking every locker save down for.
  def matches?(value)
    anchored_regexp.match?(value.to_s.strip)
  rescue Regexp::TimeoutError, RegexpError
    false
  end

  # Clarification Q1: what users are shown in a hint or an error — the super
  # admin's own wording when there is one, the pattern itself otherwise.
  def display = description.presence || pattern

  private

    # FR-014: the whole value, never a part of it. The pattern is grouped before
    # it is anchored so an alternation cannot escape the anchors, and \A…\z
    # rather than ^…$ because the latter are line anchors in Ruby — which is also
    # why anchors the super admin types change nothing.
    def anchored_regexp
      Regexp.new("\\A(?:#{pattern})\\z", timeout: MATCH_TIMEOUT)
    end

    # FR-010: the anchored form is what gets compiled, not the raw source. They
    # can disagree — `(?x)\d{3} #` is valid alone, but its comment swallows the
    # closing `)\z` once anchored — and validating the raw source would let
    # through a pattern that raises on every check (research.md R4, analysis C1).
    def pattern_compiles
      return if pattern.nil?

      anchored_regexp
    rescue RegexpError
      errors.add(:pattern, I18n.t("locker_number_format.messages.invalid_pattern"))
    end

    def only_one_row_may_exist
      errors.add(:base, "only one locker number format may exist") if self.class.exists?
    end
end
