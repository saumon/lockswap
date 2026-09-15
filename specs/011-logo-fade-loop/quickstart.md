# Quickstart: Validating the Looping Logo Fade

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Contract**: [contracts/brand-motion-loop.md](./contracts/brand-motion-loop.md)

## Prerequisites

- App running locally: `bin/rails server` (and `bin/rails tailwindcss:watch` if the CSS build isn't already running alongside it).
- A seeded user to sign in as (any fixture user, e.g. `users(:carol)` from `test/fixtures/users.yml`, or whatever account exists in your local `db/seeds.rb` data).
- Chrome/Chromium for the automated system tests (already configured via `test/application_system_test_case.rb`).

## Manual validation

1. **Sign-in screen loop**
   - Visit `/users/sign_in`.
   - Watch the large logo: it should fade up from a blur once (unchanged from before), then settle, then start a slow, continuous pulse between full brightness and a visibly dimmer state — roughly one dim-and-brighten cycle every 3 seconds, forever.
   - Confirm the pulse never makes the logo hard to see or shifts anything else on the page.

2. **Sign-up screen loop**
   - Visit `/users/sign_up`.
   - Same check as above — identical behavior.

3. **Header loop, signed in**
   - Sign in, land on the homepage.
   - Look at the small logo in the top-left of the header: it should already be pulsing (no entrance first — it starts pulsing immediately, since there is no one-shot flourish on the header mark).
   - Navigate to at least one other page (e.g. "Locker wishes") and confirm the header logo is still pulsing there too.
   - Click the header logo mid-pulse (at a dim moment, if you can time it) and confirm it still navigates to the homepage — the animation must never block interaction.

4. **Reduced motion**
   - Enable "reduce motion" at the OS level (macOS: System Settings → Accessibility → Display → Reduce Motion; or emulate it in Chrome DevTools via Rendering tab → "Emulate CSS media feature prefers-reduced-motion: reduce").
   - Revisit `/users/sign_in` and the signed-in homepage: both logos should now be static, fully opaque, with no pulsing and no leftover blur.

## Automated validation

Run the motion system tests, which cover the contract in `contracts/brand-motion-loop.md`:

```sh
bin/rails test test/system/motion_test.rb
```

Expect (after implementation):
- The rewritten "flourish" tests confirm the entrance still plays exactly once *and* the pulse now loops forever on the sign-in mark.
- A new or rewritten header test confirms the header mark loops (replacing the old "the header mark does not fade" assertion, which this feature intentionally reverses).
- The reduced-motion tests confirm both marks go fully static under `emulate_reduced_motion`.

Run the full accessibility/navigation suite too, since the header logo appears on every signed-in page and `wait_for_entrance` (used by `assert_axe_clean`) is being touched as part of this feature (see `research.md` D7):

```sh
bin/rails test test/system/
```

A useful sanity check for the D7 fix specifically: time a single `assert_axe_clean`-covered test before and after the change (e.g. `time bin/rails test test/system/accessibility_test.rb`) — it should not have grown by anywhere close to 5 seconds per assertion once the header's infinite loop is present.

## Expected outcome

All of the above pass with no manual follow-up: this is a self-contained CSS/view change with no migration, no background job, and no feature flag to toggle.
