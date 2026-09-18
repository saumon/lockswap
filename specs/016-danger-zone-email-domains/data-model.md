# Phase 1 Data Model: Danger Zone – Allowed Email Domains

**Feature**: [spec.md](./spec.md) | **Research**: [research.md](./research.md) | **Date**: 2026-09-18

One new table. One small addition to an existing model.

## AllowedEmailDomain (new — `allowed_email_domains`)

This table *is* the spec's "Danger Zone Configuration" — there is no separate settings row; the
collection of these rows, empty or not, is the whole of that entity (research.md R1).

| Column | Type | Null | Default | Purpose |
|---|---|---|---|---|
| `domain` | `string` | no | — | A single allowed domain, e.g. `"company.com"` (FR-003). Normalized to lowercase, stripped of surrounding whitespace, before validation and save. |
| `created_at` / `updated_at` | `datetime` | no | — | Standard Active Record timestamps. |

### Indexes

| Index | Purpose |
|---|---|
| `UNIQUE (domain)` | Backs `validates :domain, uniqueness: true` (FR-003 Edge Cases: no functional duplicates). Safe against a case-only duplicate because `domain` is always stored lowercase — see Normalization below. |

### Normalization

```ruby
normalizes :domain, with: ->(value) { value.to_s.strip.downcase }
```

Same pattern `User#locker_number` already uses. This is what makes the unique index actually catch
case-only duplicates ("Company.com" vs "company.com") and what removes the need for a
`case_sensitive: false` uniqueness option — the column only ever holds one case.

### Validations

| Rule | Requirement |
|---|---|
| `presence: true` | An empty entry is rejected rather than silently ignored (Edge Cases). |
| `format:` against a domain-shaped pattern (at least one label, a dot, and a final label; no spaces, no `@`) | Rejects entries like `"not a domain"` or a full email address typed by mistake (FR-008, Edge Cases). |
| `uniqueness: true` | Rejects a domain already in the list (Edge Cases: "the same domain twice"). |

### Lifecycle

Created via `Admin::AllowedEmailDomainsController#create`, destroyed via `#destroy`. No update action —
changing a domain is remove-then-add, keeping the resource's only two operations exactly the two the
spec's Edge Cases describe (add, remove), with nothing else to validate a partial-edit state for.

## User (existing — `users`)

No columns change. One validation added.

### Validation added

```ruby
EMAIL_DOMAIN_NOT_ALLOWED_MESSAGE = "Your email address domain is not allowed".freeze

validate :email_domain_allowed, on: :create

private

def email_domain_allowed
  allowed_domains = AllowedEmailDomain.pluck(:domain)
  return if allowed_domains.empty?                                      # FR-004: nothing configured → unrestricted
  submitted_domain = email.to_s.split("@").last.to_s.downcase
  return if allowed_domains.include?(submitted_domain)                  # FR-005/FR-007: exact, case-insensitive

  errors.add(:base, EMAIL_DOMAIN_NOT_ALLOWED_MESSAGE)                    # FR-006
end
```

| Detail | Requirement |
|---|---|
| `on: :create` | The rule can only ever fire while a new record is being created — i.e. registration — never on a later `update` of an existing account, which is what makes FR-010 true without a separate flag or flow check. |
| Error added to `:base`, not `:email` | `resource.errors.full_messages` (rendered by the existing `devise/shared/error_messages` partial) prefixes an attribute-scoped message with the humanized attribute name. A `:base` error renders exactly as written, which is required here: the spec's error text is the whole sentence, not a fragment to be prefixed with "Email ". |
| One `pluck` query, not a query per configured domain | `AllowedEmailDomain.pluck(:domain)` loads the (administrator-sized, not user-sized) list once as plain strings; matching is then an in-memory `Array#include?`. Bounded regardless of how many people register (Principle IV). |
| Runs alongside Devise's own `:validatable` email-format/uniqueness checks | Both can add errors to the same failed save; there is no ordering dependency between them, since each checks something the other does not. |

### States this feature does not add

No new column, no new state on `User`. Whether registration succeeds depends entirely on the current
contents of `allowed_email_domains` at the moment of the attempt (spec Edge Cases: evaluated at
submission time, not cached or snapshotted).
