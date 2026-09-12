# Quickstart: Validate User Signup and Login

## Prerequisites

- Ruby 3.4.6 and Bundler installed
- SQLite3 available locally (bundled by default on macOS/Linux)
- Repo dependencies installed: `bundle install`
- Database prepared: `bin/rails db:create db:migrate`
- Tailwind assets built (dev): `bin/rails tailwindcss:build` (or via `bin/dev` if using the
  generated `Procfile.dev`)

## Run the app

```sh
bin/rails server
# or, if a Procfile.dev is present (Puma + Tailwind watcher):
bin/dev
```

Visit `http://localhost:3000`.

## Validation scenarios

Each scenario below maps to an acceptance scenario in [spec.md](./spec.md). Route paths reference
[contracts/web-routes.md](./contracts/web-routes.md).

1. **Create an account (User Story 1)**
   - Visit `/users/sign_up`, submit a new email and an 8+ character password.
   - Expected: redirected to `/`, account now exists.
   - Then submit the same email again at `/users/sign_up`.
   - Expected: form re-rendered with a "has already been taken" error, no duplicate account created.

2. **Log in and reach the homepage (User Story 2)**
   - With the account from step 1, log out if signed in, then visit `/users/sign_in` and submit the
     correct email/password.
   - Expected: redirected straight to `/` (homepage) within the same request.
   - Close and reopen the browser (or clear the session cookie but keep the remember cookie) and
     revisit `/`.
   - Expected: still logged in, homepage shown without re-entering credentials (session ≤ 30 days).
   - Log out via the sign-out control.
   - Expected: subsequent visit to `/` redirects to `/users/sign_in`.

3. **Handle incorrect login attempts (User Story 3)**
   - At `/users/sign_in`, submit an email with no matching account.
   - Expected: generic "Invalid Email or password." message, not logged in.
   - Submit the correct email with a wrong password 5 times in a row.
   - Expected: after the 5th failure, the account is locked; a 6th attempt — even with the correct
     password — still fails with the same generic message.
   - Wait 15 minutes (or adjust `Devise.unlock_in` in a test/staging config to a shorter value for
     faster manual verification) and retry with the correct password.
   - Expected: login succeeds, `failed_attempts` resets.

4. **Unauthenticated access to the homepage**
   - While logged out, visit `/` directly.
   - Expected: redirected to `/users/sign_in`, homepage content never rendered.

5. **Already-logged-in redirect**
   - While logged in, visit `/users/sign_up` or `/users/sign_in` directly.
   - Expected: redirected to `/`.

## Automated verification

Run the full test suite (Minitest + Rails system tests) covering the scenarios above:

```sh
bin/rails test
bin/rails test:system
```

CI MUST run both commands on every pull request per the project constitution's Testing Standards
gate; a failure in either blocks merge.
