# Quickstart: Pre-fill "Their Floor" filter from the viewer's wish

Manual validation of the acceptance scenarios in `spec.md`, once the feature is implemented. See
`contracts/current-floor-sync.md` for the exact request/redirect rules these steps exercise, and
`research.md` R1 for what "fresh screen entry" means precisely (and its one known limitation).

## Prerequisites

```sh
bin/rails db:reset   # fresh database
bin/dev              # Puma + the Tailwind watcher
```

Register a couple of accounts so "Their Floor" has something to narrow to:

| Account | Saved floor | Wish (looking for) |
|---|---|---|
| `you@example.com` | `1` | — (not declared yet) |
| `bob@example.com` | `5` | `1` |
| `carol@example.com` | `7` | `3` |

## 1 — Declaring a wish pre-fills the filter (User Story 1)

1. Sign in as `you@example.com` and open **Locker wishes**.
2. **Expect**: "Their floor" reads "All floors" (no wish declared yet).
3. In "Your locker search," declare a wish for floor `5`.
4. **Expect**: "Locker search saved.", and without touching any filter, "Their floor" now shows `5` and
   "Everyone looking for a locker" lists only `bob` (the person on floor `5`) — spec Story 1, scenario 1.
5. **Expect**: the address now reads `?current_floor=5`.

## 2 — The pre-fill survives leaving and coming back (SC-005)

1. Navigate away (e.g. to the homepage) and back to **Locker wishes** via the site navigation.
2. **Expect**: "Their floor" already shows `5` and the list is already narrowed to it — no interaction
   needed. Reload the page (browser refresh); the same holds.

## 3 — A manual change holds for the rest of the visit, then resets (Story 1, scenarios 4–6)

1. Still on the narrowed view from step 1, manually change "Their floor" to `7`.
2. **Expect**: the list now shows `carol` instead of `bob` — the manual choice applies immediately.
3. Change "Looking for floor" to `3` (an unrelated axis) and back to "All floors".
4. **Expect**: "Their floor" is still `7` throughout — an unrelated interaction does not reset it.
5. Press the browser **Back** button enough times to return to the `?current_floor=5` state from step 1.
6. **Expect**: "Their floor" shows `5` again — Back reproduces what was chosen earlier in the visit, not
   a re-derived value.
7. Reload the page (or leave and come back via the navigation).
8. **Expect**: "Their floor" is back to `5` — a fresh screen entry re-derives it from the wish,
   discarding whatever was manually chosen during the visit that just ended.

## 4 — Changing the wish's floor updates the filter (Story 1, scenario 2)

1. In "Your locker search," change the floor to `7`.
2. **Expect**: "Locker search saved.", "Their floor" now reads `7` — overwriting whatever it held
   before, manual or not — and the list narrows to `carol`.

## 5 — A rejected change leaves the filter alone (Story 1, scenario 3)

1. Manually set "Their floor" to `5`.
2. Submit the "Change floor" form with an empty floor.
3. **Expect**: the usual validation error, and "Their floor" is still `5` — nothing was pre-filled by
   the failed attempt.

## 6 — Cancelling resets the filter (User Story 2)

1. With a wish still active and "Their floor" showing its floor, cancel the wish via **Cancel wish**.
2. **Expect**: "Locker search cancelled.", "Their floor" reads "All floors", and the full list is shown.
3. Reload the page.
4. **Expect**: "Their floor" is still "All floors" — there is no wish left to derive a floor from.

## 7 — A pre-filled floor that matches nobody (Story 1, scenario 7)

1. Declare a wish for a floor nobody currently holds a locker on (e.g. `99`).
2. **Expect**: "Their floor" shows `99`, and the list shows the existing "No wish matches these
   filters." message — not an error, not the unfiltered list.

## 8 — "Looking for floor" is never touched by any of this (Story 1, scenario 8; User Story 2, scenario 3)

1. Set "Looking for floor" to `1`.
2. Declare, change, and cancel a wish in turn.
3. **Expect**: "Looking for floor" stays on `1` throughout every one of those actions; only
   "Their floor" reacts.

## Automated suites

```sh
bin/rails test                                          # unit + integration
bin/rails test:system                                   # browser, including axe-core
bin/rubocop                                             # zero warnings (Principle I)
```

Targeted runs while working:

```sh
bin/rails test test/controllers/locker_wishes_controller_test.rb
bin/rails test:system test/system/locker_wish_filter_test.rb
bin/rails test:system test/system/locker_wish_test.rb        # must pass unchanged
```
