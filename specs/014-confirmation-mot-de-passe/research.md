# Phase 0 Research: Password Confirmation and Visibility Toggle on Signup

No open `NEEDS CLARIFICATION` markers remain in the spec (resolved during `/speckit-clarify`).
The items below are implementation-approach decisions made while surveying the existing codebase,
not spec ambiguities.

## R1: Server-side match enforcement (FR-002, FR-009)

- **Decision**: Do not write any new validation. `User` already includes Devise's `:validatable`
  module (`app/models/user.rb`), which ships `validates_confirmation_of :password, if:
  :password_required?`. Devise's default `sign_up` parameter sanitizer already permits
  `password_confirmation` (`DEFAULT_PERMITTED_ATTRIBUTES[:sign_up] = [:password,
  :password_confirmation]`), and `RegistrationsController` inherits that sanitizer unchanged.
  Adding the field to the view is sufficient to activate real server-side enforcement.
- **Rationale**: The codebase already enforces this exact rule on the account-settings page
  (`app/views/devise/registrations/edit.html.erb` already has a `password_confirmation` field
  against the same model validation). Reusing it keeps the two password-confirmation experiences
  in the app backed by one validation rule, per the constitution's Code Quality principle
  (no duplicated logic).
- **Alternatives considered**: A custom `validate :passwords_match` on `User` — rejected as
  duplicate logic Devise already provides. A JavaScript-only check — rejected because it would not
  hold if JavaScript is disabled, breaking FR-002/FR-009's unconditional "MUST prevent" wording and
  the project's own existing convention (the signup form is already `novalidate`, with the code
  comment: "the server validates every field, so all four failure modes ... are reported the same
  way instead of some by the browser and some by the app").

## R2: Distinguishable mismatch message (FR-003)

- **Decision**: Add a locale override for the confirmation validation's error key
  (`activerecord.errors.models.user.attributes.password_confirmation.confirmation`) in
  `config/locales/devise.en.yml` (alongside the existing custom `password.too_short` /
  `email.invalid` / `email.taken` copy), written in the same second-person, actionable tone as the
  file's existing strings.
- **Rationale**: Rails' built-in default ("Password confirmation doesn't match Password") is
  already technically distinct from the "too short" message, but the file's existing custom copy
  establishes a house tone (e.g., "must be at least %{count} characters long.") that the new
  message should match rather than falling back to a generic Rails default.
- **Alternatives considered**: Leaving the default Rails message in place — rejected only for tone
  consistency, not correctness; it would still satisfy FR-003's distinguishability requirement on
  its own.

## R3: Live mismatch feedback timing (FR-004, resolved via `/speckit-clarify`)

- **Decision**: A small Stimulus controller enhances the existing server round-trip with
  client-side feedback: no message while the visitor is still in their first pass through
  "Confirm password"; the check first runs on that field's `blur`; after that first check, it
  re-runs live on every `input` event on either field.
- **Rationale**: This is a progressive enhancement over the server-side gate (R1), not a
  replacement for it — with JavaScript disabled, the visitor still gets FR-002 enforcement on
  submit, just without the live hint. This matches the signup form's existing `novalidate`
  philosophy: the server is the source of truth, and client-side script only makes the true
  answer visible sooner.
- **Alternatives considered**: Live-per-keystroke from the very first character — rejected in
  `/speckit-clarify` as too eager (flashes an error while a visitor is still mid-typing a
  correct value). Submit-only feedback — rejected as it fails SC-004 (mismatch must clear within
  the same interaction, without a resubmit round trip).

## R4: Visibility toggle control (FR-005–FR-008)

- **Decision**: One Stimulus controller (`password_visibility_controller.js`), instantiated twice
  — once scoped to the "Password" field's wrapper, once to "Confirm password"'s — each pairing one
  `<input>` with its own toggle `<button type="button">`. Toggling swaps the input's `type`
  between `password` and `text`, and updates the button's `aria-pressed` and `aria-label` (e.g.
  "Show password" ↔ "Hide password"), following the same accessible icon-button pattern already
  used for the locker-profile edit trigger (`app/views/home/_locker_profile.html.erb`: `aria-label`
  on the interactive element, `aria-hidden="true" focusable="false"` on the decorative inline SVG).
- **Rationale**: Two independent controller instances make FR-006 (toggling one field must not
  affect the other) true by construction — there is no shared state to accidentally couple. This
  follows the same single-responsibility shape as the existing `locker_entry_choice_controller.js`.
- **Alternatives considered**: One controller instance with `passwordTarget`/`confirmTarget` pairs
  and index-tracking — rejected as unnecessary bookkeeping for two fields that are already
  independent by definition; two small instances are simpler to read and test.

## R5: Scope boundary — account-settings ("edit") page is untouched

- **Note (not a decision requiring action)**: `app/views/devise/registrations/edit.html.erb`
  already renders a bare `password_confirmation` field with no visibility toggle. The spec's
  Assumptions section scopes this feature to the signup/registration form only. This plan
  deliberately does not touch `edit.html.erb`; a future feature could extend the same
  `password_visibility_controller.js` there if desired.

## R6: Existing test fixtures must be updated

- **Note (risk, carried into tasks)**: `test/system/signup_test.rb` and
  `test/controllers/registrations_controller_test.rb` currently submit signup forms filling in only
  `Password`, relying on `password_confirmation` being absent (`nil`, which Devise's confirmation
  validator always skips). Once the view renders a "Confirm password" field, an unfilled field
  submits as an empty string (`""`), which the validator does **not** skip — every currently
  -passing "successful signup" test will start failing the new confirmation check unless updated to
  also fill in "Confirm password". Per the constitution's Testing Standards principle, these
  existing tests must be updated alongside the new ones, not worked around.
