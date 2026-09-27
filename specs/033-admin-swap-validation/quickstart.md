# Quickstart: Administrator Validation of Locker Swap Exchanges

**Feature**: [spec.md](./spec.md) | **Branch**: `033-admin-swap-validation`

Manual validation once the implementation lands (tasks.md covers the automated tests; this is the
end-to-end proof the pieces fit together, per `CLAUDE.md`'s "look at the page" guidance).

## Prerequisites

```bash
bin/rails tailwindcss:build   # the new admin screen and the simplified homepage card are new markup —
                               # run this after any stylesheet-relevant view change
bin/rails db:migrate          # applies the new admin_decided_by_id column
```

Fixture users (`test/fixtures/users.yml`): `frank` is the super admin (bootstrap), `grace` is a standard
granted admin, `bob` has floor "3"/locker "B12", `carol` has floor "2" and no locker. No fixture proposal is
`accepted` (`test/fixtures/locker_swap_proposals.yml`'s own comment: an accepted one would hide both
parties' wishes from unrelated tests) — build one for these scenarios instead, exactly as the existing test
suite already does.

```bash
bin/rails runner '
  p = LockerSwapProposal.create!(requester: User.find_by!(email: "bob@example.com"),
                                  recipient: User.find_by!(email: "carol@example.com"),
                                  status: :accepted, decided_at: Time.current)
  puts "accepted proposal id: #{p.id}"
'
```

## Scenario 1 — An administrator validates an accepted exchange (User Story 1)

1. `bin/rails server`
2. Sign in as `grace@example.com` (standard admin) / `password123`.
3. Open the Admin menu → the new "Validations d'échanges" / "Swap validations" link is present.
4. Visit it (`/admin/swap_validations`) → the bob/carol exchange from Prerequisites is listed, with both
   emails and their current floor/locker.
5. Click "Valider" / "Validate" on that row.
6. Confirm: redirected back to the list with a success notice; the row is gone; `bob.reload.floor == "2"`
   and `carol.reload.floor == "3"` (their lockers swapped); the proposal is `completed?`.
7. Sign out, sign in as `frank@example.com` (the super admin) instead, repeat steps 3–4 on a freshly built
   accepted proposal → confirm the screen and the validate action work identically for the super admin
   (spec.md Acceptance Scenario 1.3 — this screen is not super-admin-exclusive).

## Scenario 2 — An administrator refuses an accepted exchange, with and without a comment (User Story 2)

1. Build a second accepted proposal (Prerequisites' script, any two eligible fixture users).
2. As `grace`, open `/admin/swap_validations`, click "Refuser" / "Refuse" to open the disclosure, leave the
   comment blank, submit.
3. Confirm: the exchange is `declined?`, neither party's floor/locker changed, no comment is recorded, and
   both parties are free to appear in a new proposal (`LockerSwapProposal.in_progress_for?` is now false for
   both).
4. Repeat with a third accepted proposal, this time typing a reason before submitting.
5. Confirm the reason is saved on `decline_comment` and would render in that proposal's history row the same
   way an ordinary recipient decline comment already does (`locker_swap_proposals/_history_table.html.erb`).

## Scenario 3 — Standard users lose the self-confirm control (User Story 3)

1. Build a fourth accepted proposal between two non-admin fixture users (e.g. `dave`/`erin`, after clearing
   any conflicting fixture state).
2. Sign in as the requester → homepage shows "En attente de validation" / "Awaiting validation" and the
   new waiting-for-admin paragraph, no button.
3. Sign out, sign in as the recipient → the same label and the same paragraph (not the old, different
   "confirm it yourself" copy) — no button either.
4. As either party, `curl`/Capybara a direct `PATCH` to the old `/locker_swap_proposals/:id/confirm` path →
   confirm it 404s (the route no longer exists — research.md R8).
5. Open that same proposal's row in `locker_swap_proposals/index` (the self-service history screen, still
   showing it as not-yet-decided) → confirm its status badge also reads "En attente de validation" / "Exchange
   awaiting validation", not the retired "Échange en cours" (research.md R12).

## Scenario 4 — Already-accepted exchanges appear with no migration step (Clarification 1 / research.md R11)

1. Before running `db:migrate` for this feature (or on a copy of the database from just before it), create
   an accepted proposal exactly as in Prerequisites.
2. Apply this feature's migration and deploy the code.
3. As an admin, open `/admin/swap_validations` → confirm the pre-existing accepted proposal appears in the
   queue exactly like one accepted after deployment, with `admin_decided_by` `nil` until acted on.

## Scenario 5 — An administrator can validate or refuse their own exchange (Clarification 2 / research.md R10)

1. Build an accepted proposal where `grace` (a standard admin) is one of the two parties (requester or
   recipient).
2. Sign in as `grace`, open `/admin/swap_validations` → the exchange she is party to is listed like any
   other.
3. Validate (or refuse) it → confirm it succeeds exactly as it would for a row she has no personal stake in;
   no extra confirmation or block appears.

## Scenario 6 — Two administrators racing the same decision (Edge Cases, research.md R6)

Best proven at the controller-test layer (two requests, not two browser sessions), but can be approximated
manually:

1. Build an accepted proposal. Open its row in two browser sessions signed in as two different admins (or
   note its `validate_admin_swap_validation_path`/`refuse_admin_swap_validation_path`).
2. From session A, validate it. Confirm success.
3. From session B (which still shows the now-stale row), submit refuse on the same id.
4. Confirm session B is redirected with an "already decided" alert, the proposal is still `completed?` (not
   overwritten to `declined?`), and neither party's locker details changed a second time.

## Cleanup

```bash
git checkout -- .   # discard runner-script side effects if run against a shared dev database
```
