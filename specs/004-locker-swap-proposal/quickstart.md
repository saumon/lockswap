# Quickstart: Validate Locker Swap Proposals

## Prerequisites

- Ruby 3.4.6 and Bundler installed; repo dependencies installed: `bundle install`
- Database migrated (includes this feature's migration): `bin/rails db:migrate`
- At least two existing accounts, both with an active Locker Wish declared (see
  003-locker-search-wish's quickstart), to act as requester and recipient

## Run the app

```sh
bin/rails server
# or: bin/dev
```

Visit `http://localhost:3000`, log in, and navigate to `/locker_wishes` to send a proposal, or `/`
(the homepage) to act on one received, or `/locker_swap_proposals` for the history screen.

## Validation scenarios

Each scenario maps to an acceptance scenario in [spec.md](./spec.md). Route/field details reference
[contracts/web-routes.md](./contracts/web-routes.md).

1. **Propose a swap (User Story 1)**
   - Log in as User A. Have User B declare a locker wish (any floor).
   - Visit `/locker_wishes`. Expected: User B's row shows a "Propose swap" control.
   - Click it. Expected: redirected back, a pending proposal now exists from A to B.
   - Attempt to send another proposal to B before this one is decided. Expected: rejected — a
     pending proposal to B already exists (FR-018).
   - Attempt to send a proposal targeting yourself (User A). Expected: rejected (FR-002).

2. **Respond to a proposal (User Story 2)**
   - Log in as User B. Visit `/` (homepage). Expected: the pending proposal from A appears, with
     Accept and Decline controls.
   - Click Decline, optionally entering a comment, and submit.
   - Expected: redirected back; the proposal is now `declined`.
   - Log in as User A. Visit `/`. Expected: the decline appears once, with the comment if one was
     entered; reloading the homepage again no longer shows it (FR-007, FR-009).
   - Repeat steps 1–2 but click Accept instead. Expected: the proposal becomes `accepted`
     ("exchange in progress") for both A and B.

3. **See proposals on the homepage (User Story 3)**
   - As User A (after sending a still-pending proposal to a third user, C), visit `/`. Expected: the
     pending sent proposal to C appears, with a Withdraw control.
   - As User C, visit `/`. Expected: the pending received proposal from A appears, with Accept/
     Decline controls.

4. **Confirm the exchange (User Story 4)**
   - Continuing from the "Accept" branch of scenario 2 (A and B's exchange is `accepted`): note A's
     and B's current floor/locker (from `/` or their own profile).
   - Log in as User A and attempt to confirm. Expected: rejected — only the recipient (B) can
     confirm (FR-012).
   - Log in as User B and confirm.
   - Expected: redirected back; A's and B's floor/locker values are now swapped; the proposal is
     `completed`; any wish either of them had is gone from `/locker_wishes`.

5. **View proposal history (User Story 5)**
   - As User A, visit `/locker_swap_proposals`.
   - Expected: every proposal A sent or received appears (the declined-to-C one, the completed
     one with B, etc.), each with its date, status, and decline comment where applicable — read-only,
     no action controls.

6. **Withdraw a pending proposal (FR-019, FR-020)**
   - As User A, send a proposal to a user D with an active wish. Visit `/`.
   - Click Withdraw before D responds.
   - Expected: redirected back; the proposal is `withdrawn`; as User D, it no longer appears as
     actionable on `/`.

7. **"Already in an exchange" restrictions (FR-003, FR-004, Edge Cases)**
   - With A and B's exchange from scenario 2/4 still `accepted` (before confirming), log in as a
     third user E and attempt to propose to B. Expected: rejected — B already has an exchange in
     progress.
   - Log in as A (still `accepted`, pre-confirm) and attempt to propose to any other wisher.
     Expected: rejected — A cannot start a second swap while one is in progress.
   - Visit `/locker_wishes` as any user during this window. Expected: neither A's nor B's wish (if
     either had one) appears in the list.

## Automated verification

```sh
bin/rails test
bin/rails test:system
```

CI MUST run both commands on every pull request per the project constitution's Testing Standards
gate; a failure in either blocks merge. The `confirm!` swap is a constitution-designated
swap/lock execution path (Principle IV) — its PR must include a before/after performance measurement
even though the operation is a small, bounded transaction.
