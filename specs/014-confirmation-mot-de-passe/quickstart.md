# Quickstart: Validate Password Confirmation and Visibility Toggle on Signup

## Prerequisites

- Ruby 3.4.6 and Bundler installed; repo dependencies installed: `bundle install`
- Database prepared: `bin/rails db:create db:migrate` (no new migration in this feature; existing
  schema is unchanged)
- Tailwind assets built (dev): `bin/rails tailwindcss:build`, or via `bin/dev` if a `Procfile.dev`
  is present

## Run the app

```sh
bin/dev
# or: bin/rails server
```

Visit `http://localhost:3000/users/sign_up`.

## Validation scenarios

Each scenario maps to an acceptance scenario in [spec.md](./spec.md). Route/field details are in
[contracts/form-contract.md](./contracts/form-contract.md).

1. **Matching passwords succeed (User Story 1, Scenario 1)**
   - Enter the same value in "Password" and "Confirm password", plus a new email.
   - Submit. Expected: account created, redirected to `/` — same as before this feature.

2. **Mismatched passwords are blocked (User Story 1, Scenarios 2–4)**
   - Enter different values in "Password" and "Confirm password" (or leave "Confirm password"
     blank).
   - Submit. Expected: form re-rendered, no account created, and a "doesn't match the password
     above" style error is shown — distinct in wording from a "too short" password error.
   - Correct "Confirm password" to match, resubmit. Expected: signup now succeeds.

3. **Mismatch feedback timing (Clarifications, FR-004)**
   - Start typing into "Confirm password" without leaving the field. Expected: no mismatch message
     yet, even if the in-progress value currently differs from "Password".
   - Tab or click away from "Confirm password" while it still differs. Expected: mismatch message
     now appears.
   - Without leaving the field again, edit either "Password" or "Confirm password" until they
     match. Expected: the message disappears live, with no need to blur or resubmit.

4. **Reveal typed characters (User Story 2)**
   - Type into "Password", then activate its eye control. Expected: the field's content switches
     from masked dots to plain readable text.
   - Activate the same control again. Expected: it switches back to masked.
   - Repeat independently for "Confirm password", and confirm toggling one field's eye control
     never changes the other field's masked/revealed state.
   - Reload the page. Expected: both fields start masked again.

5. **Keyboard and assistive-technology operability (Edge Cases)**
   - Using only the keyboard (Tab / Shift+Tab / Enter or Space), reach and activate each eye
     control without a mouse.
   - Inspect the control's accessible name/state (e.g. via browser dev tools or a screen reader):
     it must change between "Show password" and "Hide password" (or equivalent), not rely on the
     icon's appearance alone.

## Automated verification

```sh
bin/rails test
bin/rails test:system
```

This must include (per the constitution's Testing Standards gate):
- Updated `test/system/signup_test.rb` / `test/controllers/registrations_controller_test.rb`
  filling in "Confirm password" wherever a successful signup is expected (research.md R6).
- New coverage for: mismatch blocking submission, the distinct error message, blur-then-live
  timing, independent per-field visibility toggles, and keyboard/AT operability (the existing
  `AccessibilityTest#"sign up is accessible"` axe check in `test/system/accessibility_test.rb`
  already re-runs against the changed page with no edits needed).

CI runs both commands on every pull request per the project constitution; a failure in either
blocks merge.
