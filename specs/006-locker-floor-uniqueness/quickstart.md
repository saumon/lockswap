# Quickstart: Validate Per-Floor Locker Number Uniqueness

## Prerequisites

- Ruby 3.4.6 and Bundler installed; repo dependencies installed: `bundle install`
- Database migrated (includes this feature's index migration): `bin/rails db:migrate`
- Two existing accounts to log in with, each able to reach the homepage (see
  001-user-authentication's quickstart, or use fixture users in a test/dev database)

## Run the app

```sh
bin/rails server
# or: bin/dev
```

Visit `http://localhost:3000`, log in.

## Validation scenarios

Each scenario maps to an acceptance scenario in [spec.md](./spec.md). Route/field details reference
[contracts/web-routes.md](./contracts/web-routes.md).

1. **Claim a locker number already used on another floor (User Story 1)**
   - Log in as Account A, save floor "1" and locker number "001".
   - Log out; log in as Account B, save floor "2" and locker number "001".
   - Expected: Account B's submission succeeds — the homepage shows floor "2", locker "001".
   - Log back in as Account A.
   - Expected: still shows floor "1", locker "001", unaffected by Account B's claim.

2. **Blocked from claiming a locker already taken on the same floor (User Story 2)**
   - With Account A still on floor "1" / locker "001" from scenario 1, log in as a third Account C.
   - Submit floor "1" and locker number "001" (same floor as Account A, same number).
   - Expected: rejected, told that locker number is not available *on that floor*; Account A's
     identity is never shown to Account C.
   - Resubmit as Account A their own existing floor "1" / locker "001" unchanged.
   - Expected: succeeds as a no-op — a user is never blocked by their own existing claim.

3. **Change floor while keeping the same locker number (User Story 3)**
   - As Account A (floor "1", locker "001"), change floor to "3" while keeping locker number "001",
     where no one holds "001" on floor "3".
   - Expected: succeeds — homepage now shows floor "3", locker "001".
   - Log in as Account C, submit floor "1" and locker number "001" (the pair Account A just vacated).
   - Expected: succeeds — the vacated pair is immediately claimable by someone else.
   - As a new Account D, save floor "3" and attempt locker number "001" (now held by Account A on
     floor "3" from the step above).
   - Expected: rejected, told that locker number is not available on that floor.

4. **Floor is still required for a locker number (Edge Case, FR-007/FR-008)**
   - Log in as a fresh account with no floor and no locker number on file.
   - Attempt to save a locker number with the floor field left blank.
   - Expected: rejected, told the floor is required — the locker number is never stored without a
     floor.

## Automated verification

```sh
bin/rails test
bin/rails test:system
```

CI MUST run both commands on every pull request per the project constitution's Testing Standards
gate; a failure in either blocks merge.
