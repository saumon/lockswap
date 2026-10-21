# Quickstart: Login Greeting Popup

## Prerequisites

`bin/setup`, then the fixtures' users (for example `alice`) are available to tests.

## Automated checks

```bash
bin/rails test test/controllers/users/sessions_controller_test.rb   # flash set only on successful sign-in
bin/rails test:system TEST=test/system/login_test.rb                # popup visible, then gone
bin/rails test test/i18n_completeness_test.rb                       # both locales carry the key
bin/rubocop
```

## Manual validation

1. `bin/dev`, open the sign-in page, sign in with a valid account.
   Expected: two popups, "Signed in successfully." and "coucou". Both fade on their own; either can be dismissed.
2. Reload the page, then open another page. Expected: no "coucou".
3. Sign out, submit a wrong password. Expected: the usual error, no "coucou".
4. Create an account. Expected: no "coucou" (sign-up is out of scope).
5. Set the site language to French in the admin danger zone and sign in again. Expected: still "coucou".

Maps to spec: scenarios 1 to 3 of Story 1, 1 and 2 of Story 2, FR-007.
