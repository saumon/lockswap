# Research: Login Greeting Popup

## R1: Where to hook "successful sign-in"

**Decision**: Override Devise `sessions#create` in a new `Users::SessionsController` and set the greeting in the
block `super` yields once the user is signed in.

**Rationale**: This is exactly the password-sign-in path and nothing else, matching spec FR-004. Sign-up's automatic
sign-in goes through `registrations#create` and password reset through `passwords#update`, so neither triggers it.
The repo already overrides Devise controllers in `app/controllers/users/`.

**Alternatives considered**:
- Warden `after_authentication` hook: also fires for remember-me cookie logins and the post-signup sign-in, which would
  violate "not when already authenticated" (spec FR-004).
- `after_sign_in_path_for` (already overridden in `ApplicationController`): runs for sign-up too, and it is a path
  resolver, not the place for a side effect.

## R2: How to guarantee "once, not again on reload"

**Decision**: Use a flash entry (`flash[:greeting]`).

**Rationale**: Flash is removed after the next request by design, so reloads and later navigation never see it
(FR-003) with no flag to clear. Turbo caching is handled by the `data-turbo-temporary` wrapper already in the partial.

**Alternatives considered**: a session flag cleared by JavaScript or by the first render (extra state, easy to leak);
a cookie (same, plus client trust).

## R3: How to show it

**Decision**: Add `[ flash[:greeting], "status", "toast-success" ]` to the notifications list in
`app/views/layouts/_flash.html.erb`.

**Rationale**: Reuses the toast, giving auto-dismiss, hover/focus pause, dismiss button, stacking and the 3-toast cap
(FR-005, FR-006) with no new CSS or JavaScript. Two toasts at once (this plus "Signed in successfully.") is within the
existing cap of 3 and is already a supported case (007 edge case).

**Alternatives considered**: a modal dialog (blocks the page, contradicts the assumption that "popup" means the 007
notification); a dedicated partial and Stimulus controller (duplicates existing behavior, violates constitution III).

## R4: Translation

**Decision**: Key `devise.sessions.greeting`, value "coucou" in both `devise.en.yml` and `devise.fr.yml`.

**Rationale**: The constitution forbids hardcoded strings and requires both locale files, while the spec requires the
same text in every language (FR-007). Identical values satisfy both, and `test/i18n_completeness_test.rb` keeps them
in sync. The key is used with the explicit path because it is read in a controller action of a Devise controller.

## R5: Landing page

**Decision**: Nothing to do. Devise redirects once to the stored location or the root, and the flash survives that
single hop onto whatever page it is (FR-002). A landing page that itself redirects again would drop it, which is the
same limitation the existing "Signed in successfully." notice has.
