# Quickstart: Validate Locker Field Lock & Swap History Comment

## Prerequisites

- Ruby 3.4.6 and Bundler installed; repo dependencies installed: `bundle install`
- Database migrated (includes this feature's migration): `bin/rails db:migrate`
- At least two existing accounts with saved floor/locker details, able to create a swap proposal
  between them (see 004-locker-swap-proposal's quickstart for how to get two users into a `pending`,
  `accepted`, `declined`, or `completed` proposal)

## Run the app

```sh
bin/rails server
# or: bin/dev
```

Visit `http://localhost:3000`, log in, and navigate to `/` (homepage, locker profile section) or
`/locker_swap_proposals` (history).

## Validation scenarios

Each scenario maps to an acceptance scenario in [spec.md](./spec.md). Route/field details reference
[contracts/web-routes.md](./contracts/web-routes.md).

1. **Floor/locker locked while a proposal is pending (User Story 1, scenarios 1-2)**
   - Log in as User A, who has a saved floor and locker number. Send a swap proposal to User B (see
     004's quickstart for how). Visit `/`.
   - Expected: the "Edit locker details" disclosure is replaced by a locked notice; the saved floor
     and locker number are still displayed as before.
   - Log in as User B (the recipient, before deciding). Visit `/`.
   - Expected: same locked notice for B.

2. **Locked while in progress, unlocked once resolved (User Story 1, scenarios 3-5)**
   - Continuing from scenario 1: as User B, accept the proposal. Visit `/` as A or B.
   - Expected: still locked (now `accepted`).
   - As B, confirm the exchange (004's flow). Visit `/` as A or B.
   - Expected: the lock is gone — the "Edit locker details" disclosure is available again for both,
     and a floor/locker number change now succeeds.

3. **First-time entry is never blocked (User Story 1, scenario 6)**
   - As a third user, C, with no locker number saved yet, send or receive a proposal so C has an
     active one. Visit `/`.
   - Expected: C still sees the plain first-time entry form for whichever field is unset (never a
     locked notice for a field that has nothing saved yet); submitting a locker number for the first
     time succeeds even though C has an active proposal.

4. **Bypassed-UI rejection still shows the error (defensive path)**
   - While locked (scenario 1), submit `PATCH /locker_profile` directly with a changed floor (e.g.
     via a saved form or `curl` with a valid session).
   - Expected: 422, the homepage re-renders with the "Edit locker details" disclosure open and a
     validation error naming the floor as locked.

5. **History shows an automatic summary on every status (User Story 2)**
   - Using the pending, declined, and completed proposals created in scenarios 1-2 (and 004's
     quickstart), visit `/locker_swap_proposals` as each involved user.
   - Expected: every row's new "Locker details" column is filled in automatically — "proposed"
     wording for the pending/declined rows, "exchanged" wording for the completed row — with no
     manual entry. The existing "Comment" column is unaffected (still shows only a user-entered
     decline comment, when present).

6. **History stays accurate after a later profile edit (snapshot / "no drift")**
   - After the exchange in scenario 2 completes and the lock lifts, change User A's floor to a new
     value from `/`.
   - Revisit `/locker_swap_proposals` as User A.
   - Expected: the completed proposal's "Locker details" column still shows the original pre-swap
     values from scenario 2 — unaffected by the just-made edit.

## Automated verification

```sh
bin/rails test
bin/rails test:system
```

CI MUST run both commands on every pull request per the project constitution's Testing Standards
gate; a failure in either blocks merge.
