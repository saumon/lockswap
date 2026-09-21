# 016 FR-003: one domain that registration is allowed to use. The table as a
# whole is the spec's "Danger Zone Configuration" — there is no separate settings
# row, and an empty table means no restriction at all (FR-004), so the presence of
# any row here *is* the restriction (research.md R1).
class AllowedEmailDomain < ApplicationRecord
  # Edge Cases: " Company.COM " and "company.com" are the same domain, so they are
  # made the same string before anything else looks at them. Done here rather than
  # in a before_validation for the reason User#locker_number is: the column then
  # only ever holds one spelling, which is what lets the unique index below catch
  # a case-only duplicate and what lets the check at signup be a plain comparison
  # rather than a case-insensitive query (data-model.md "Normalization").
  normalizes :domain, with: ->(value) { value.to_s.strip.downcase }

  # Labels of letters, digits and inner hyphens, at least two of them, separated
  # by dots. Anchored, so nothing may surround it — which is what refuses the
  # plausible slip of typing an email address instead of a domain (FR-008).
  #
  # No /i, deliberately: the value has already been downcased by the time this
  # runs, and a case-insensitive pattern here would quietly accept an uppercase
  # value if that normalization were ever removed.
  DOMAIN_FORMAT = /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+\z/

  # Shows the shape rather than describing it: an administrator who typed their
  # own email address here needs to see what was wanted, not a restatement of the
  # rule they just broke.
  #
  # 025: kept as a plain frozen string, for existing tests that assert against it
  # by name — see User::LOCKER_NUMBER_TAKEN_MESSAGE's comment for why the live
  # validation message below is a lambda calling I18n.t instead of this constant.
  INVALID_DOMAIN_MESSAGE = "must look like company.com".freeze

  validates :domain, presence: true,
            format: { with: DOMAIN_FORMAT, allow_blank: true,
                      message: ->(_record, _data) { I18n.t("allowed_email_domain.messages.invalid_domain") } },
            uniqueness: true
end
