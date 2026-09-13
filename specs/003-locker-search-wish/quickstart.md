# Quickstart: Validate Locker Search Wish

## Prerequisites

- Ruby 3.4.6 and Bundler installed; repo dependencies installed: `bundle install`
- Database migrated (includes this feature's migration): `bin/rails db:migrate`
- At least two existing accounts to log in with (see 001-user-authentication's quickstart, or use
  fixture users in a test/dev database)

## Run the app

```sh
bin/rails server
# or: bin/dev
```

Visit `http://localhost:3000`, log in, then navigate to `/locker_wishes`.

## Validation scenarios

Each scenario maps to an acceptance scenario in [spec.md](./spec.md). Route/field details reference
[contracts/web-routes.md](./contracts/web-routes.md).

1. **Declare a wish for the first time (User Story 1)**
   - Log in as a user with no active wish (locker assigned or not — either is fine, FR-002).
   - Visit `/locker_wishes`. Expected: a "I'm looking for a locker" button, no floor field visible yet.
   - Click it. Expected: a floor field appears.
   - Submit with the floor field left blank.
   - Expected: rejected, told the floor is required, nothing recorded.
   - Submit again with a floor value.
   - Expected: redirected back to `/locker_wishes`; the page now shows this user's active wish for
     that floor, with a "Cancel wish" control and a "Change floor" disclosure instead of the
     original button.

2. **Update an existing wish rather than duplicating it (User Story 1, Edge Case)**
   - As the user from scenario 1, open "Change floor" and submit a different floor.
   - Expected: redirected back; the page shows only one active wish for this user, now at the new
     floor — never two.

3. **See who is looking for a locker, and where (User Story 2)**
   - Log in as a second user and declare a wish for a different floor (scenario 1).
   - Log in as a third, uninvolved user and open `/locker_wishes`.
   - Expected: both wishing users appear, each with their sought floor, their email, and their
     current floor/locker number — showing "Not set" for a floor never saved and "No locker
     assigned" for no locker, never as errors.
   - Log out of the third user and back in as the first or second user.
   - Expected: their own wish appears in the list alongside the other's, not hidden.
   - Have every wishing user cancel (scenario 4), then reload `/locker_wishes` as any user.
   - Expected: the list renders empty, not as an error.

4. **Cancel a wish (User Story 3)**
   - As a user with an active wish, click "Cancel wish".
   - Expected: redirected back to `/locker_wishes`; their row is gone from the list for every
     viewer; the page now shows the original "I'm looking for a locker" button for them again.
   - Click "I'm looking for a locker" again and declare a new floor.
   - Expected: succeeds exactly as in scenario 1 — no leftover state from the cancelled wish.

## Automated verification

```sh
bin/rails test
bin/rails test:system
```

CI MUST run both commands on every pull request per the project constitution's Testing Standards
gate; a failure in either blocks merge.
