# Quickstart: Validate Locker and Floor Profile

## Prerequisites

- Ruby 3.4.6 and Bundler installed; repo dependencies installed: `bundle install`
- Database migrated (includes this feature's migration): `bin/rails db:migrate`
- An existing account to log in with (see 001-user-authentication's quickstart, or use a fixture
  user in a test/dev database)

## Run the app

```sh
bin/rails server
# or: bin/dev
```

Visit `http://localhost:3000`, log in.

## Validation scenarios

Each scenario maps to an acceptance scenario in [spec.md](./spec.md). Route/field details reference
[contracts/web-routes.md](./contracts/web-routes.md).

1. **Fill in floor and locker number for the first time (User Story 2)**
   - Log in as a user with no floor saved.
   - Expected: the homepage shows a form with two separate fields — floor and locker number.
   - Submit a floor value only, leaving locker number blank.
   - Expected: redirected to `/`, floor is now saved with no locker number recorded.
   - Submit the form again leaving the floor field blank.
   - Expected: rejected, told the floor is required, nothing saved.

2. **See my locker and floor on the homepage (User Story 1)**
   - Log in as the user from scenario 1 (floor set, no locker number).
   - Expected: homepage displays the floor and clearly shows "no locker assigned" — not an error.
   - Submit the form again with a locker number this time.
   - Expected: homepage now displays both the floor and the locker number.

3. **Locker number conflict (User Story 2, Edge Case)**
   - With two accounts, save a locker number on account A.
   - Log in as account B and submit the same locker number.
   - Expected: rejected, told that locker number is not available; account A's identity is never
     shown to account B.

4. **Update floor or locker number later (User Story 3)**
   - Log in as a user with both a floor and a locker number already saved.
   - Change only the floor.
   - Expected: homepage shows the new floor; the locker number is unchanged.
   - Clear the locker number field and submit.
   - Expected: homepage now shows "no locker assigned"; the floor remains unchanged.

## Automated verification

```sh
bin/rails test
bin/rails test:system
```

CI MUST run both commands on every pull request per the project constitution's Testing Standards
gate; a failure in either blocks merge.
