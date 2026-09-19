# Quickstart: "It's a match!" tag on locker wishes

Manual validation of the acceptance scenarios in `spec.md`, once the feature is implemented. See
`contracts/match-tag.md` for the exact text, position and presence rules, and `data-model.md` for the
reciprocity formula these steps exercise.

## Prerequisites

```sh
bin/rails db:reset   # fresh database
bin/dev              # Puma + the Tailwind watcher
```

Register a handful of accounts and give them lockers and wishes so a genuine reciprocal pair exists:

| Account | Saved floor | Wish (looking for) |
|---|---|---|
| `you@example.com` | `3` | `7` |
| `henry@example.com` | `7` | `3` |
| `bob@example.com` | `3` | `5` |
| `carol@example.com` | — | `7` |

(Note: these are fresh accounts registered by hand against a reset dev database, unrelated to the
`henry`/`iris` test fixtures in `test/fixtures/users.yml` — the name is reused here only for
consistency with the automated tests, not because they share any data.)

`you` and `henry` reciprocate exactly (your current floor `3` is henry's desired floor, and henry's
current floor `7` is your desired floor). `bob` shares your current floor but wants a different one —
a one-directional near-miss. `carol` wants your current floor but has no saved floor of her own, so
her side of the comparison can never be satisfied.

## 1 — The one reciprocal row is tagged, and only that one (User Story 1)

1. Sign in as `you@example.com`, declare a wish for floor `7`, and open **Locker wishes**.
2. **Expect**: henry's row carries `It's a match!` inside the Swap cell, alongside the "Propose swap"
   button (Acceptance Scenario 1, 9; contract "Position").
3. **Expect**: bob's row and carol's row do not carry the tag (Acceptance Scenario 2).
4. Propose a swap to `henry` (or have another account propose one to `you`, whichever the current
   swap-proposal fixtures make easiest), then reload the list.
5. **Expect**: henry's row now shows `It's a match!` alongside "Proposal pending", not in place of it
   (Acceptance Scenario 10).

## 2 — No tag anywhere without the viewer's own reciprocating wish

1. Sign in as an account that has **not** declared a wish and open **Locker wishes**.
2. **Expect**: no row carries the tag, regardless of how the floors line up (Acceptance Scenario 3).
3. Sign in as an account with a wish but no saved current floor.
4. **Expect**: no row carries the tag (Acceptance Scenario 4).

## 3 — The viewer's own row is never tagged

1. Sign in as `you@example.com` with current floor `3` and wish `7`. Manually set your own saved
   floor to `7` and your wish to `3` (mirroring yourself) if the fixtures allow it, or confirm by
   inspection that your own row's Swap cell reads "This is you" only.
2. **Expect**: your own row never carries the tag, even though the formula's two comparisons would
   otherwise both hold (Acceptance Scenario 6).

## 4 — The tag survives filtering

1. As `you@example.com` from Scenario 1, apply the "looking for floor" filter for `3` — henry's wish
   is for floor `3`, so his row is the only one shown.
2. **Expect**: henry's row still carries the tag exactly as it did unfiltered (Acceptance Scenario 7).

## Query-budget check

With the reciprocal pair from the table above signed in as `you@example.com`, and separately with
`henry`'s wish removed so no row matches, confirm in the controller test (not manually) that `#index`
issues the same number of SQL queries in both cases — see `contracts/match-tag.md`'s query-budget
contract.
