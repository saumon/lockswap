# Phase 1 Data Model: Password Confirmation and Visibility Toggle on Signup

## No new persisted entity

This feature introduces no database migration and no new `ActiveRecord` model or column. It
activates and surfaces a validation rule that already exists on the `User` model (see
[research.md](./research.md) R1) and adds purely client-side, non-persisted UI state.

## Entity: Signup Form Password Fields (spec-level concept)

Maps to Devise's virtual (non-persisted) `password` and `password_confirmation` attributes on
`User`, plus two pieces of transient, per-field, browser-only UI state that are never sent to the
server and never stored.

| Field | Persisted? | Type | Notes |
| - | - | - | - |
| `password` | No (virtual attribute; persisted only as `encrypted_password` via bcrypt) | string | Existing field (001); unchanged by this feature. |
| `password_confirmation` | No (virtual attribute, Devise `attr_accessor`) | string | Newly exposed in the signup view (014). Compared to `password` by `validates_confirmation_of :password` (already active on `User`, from `:validatable`). Required to match exactly, including when blank (FR-002). |
| `passwordRevealed` (Password field) | No — client-only, in-memory | boolean | Drives whether the "Password" input's `type` is `password` or `text` (FR-005, FR-007). Resets to `false` (masked) on every fresh page load; never sent to the server. |
| `confirmationRevealed` (Confirm password field) | No — client-only, in-memory | boolean | Same as above, scoped independently to the "Confirm password" input (FR-006). |
| `confirmationTouched` | No — client-only, in-memory | boolean | Set the first time the "Confirm password" field is blurred; gates when live mismatch feedback begins (FR-004, per `/speckit-clarify` decision). |

### Validation rules (already active; unchanged by this feature)

- `password_confirmation` MUST equal `password` exactly (including case and whitespace) whenever
  either is present, per Devise's `validates_confirmation_of :password, if: :password_required?`.
  `password_required?` is true for any new (`!persisted?`) record, so it always applies at signup —
  FR-002.
- The confirmation-mismatch error MUST render under a distinct, dedicated locale key so its wording
  differs from the `password.too_short` message — FR-003 (see research.md R2).

### State transitions (client-side UI state only; no persisted state machine)

```text
[page load] --> passwordRevealed=false, confirmationRevealed=false, confirmationTouched=false
passwordRevealed=false --(visitor activates Password's eye control)--> passwordRevealed=true
passwordRevealed=true  --(visitor activates Password's eye control again)--> passwordRevealed=false
# confirmationRevealed follows the identical, fully independent cycle for its own field (FR-006).

confirmationTouched=false --(visitor blurs Confirm password field for the first time)--> confirmationTouched=true
# Before this transition: no mismatch message is shown, regardless of content (per /speckit-clarify).
# After this transition: mismatch message is shown/cleared live on every edit to either field (FR-004).
```

## Relationships

None. This feature does not add, change, or remove any relationship between `User` and any other
entity.
