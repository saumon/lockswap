# Quickstart: Filter locker wishes by floor

Manual validation of the acceptance scenarios in `spec.md`, once the feature is implemented. See
`contracts/locker-wish-filter.md` for the exact parameter, frame and DOM rules, and `data-model.md`
for the scopes and the `FloorFilter` behaviour these steps exercise.

## Prerequisites

```sh
bin/rails db:reset   # fresh database
bin/dev              # Puma + the Tailwind watcher
```

Register a handful of accounts and give them lockers and wishes so that both axes have something to
filter on. The minimum that makes every step below observable:

| Account | Saved floor | Locker | Wish (looking for) |
|---|---|---|---|
| `you@example.com` | `1` | `A-102` | `3` |
| `bob@example.com` | `3` | `B-12` | `1` |
| `carol@example.com` | `3` | — | `10` |
| `dave@example.com` | `10` | `D-07` | `3` |
| `erin@example.com` | — | — | `3` |

`carol` has a floor but no locker, and `erin` has neither — they are the rows FR-012 and the
"Not set" display are validated against. Floors `3` and `10` together are what make the ordering rule
visible.

## 1 — Narrowing by the floor people are looking for (User Story 1)

1. Sign in as `you@example.com` and open **Locker wishes**.
2. **Expect**: every wish is listed, oldest first, and both filter groups read "All floors"
   (FR-003, User Story 3 scenario 4).
3. **Expect**: the "looking for floor" group offers `1`, `3`, `10` in that order — `10` last, not
   between `1` and `3` (FR-007, User Story 1 scenario 5).
4. Choose `3` in the "looking for floor" group.
5. **Expect**: only `dave` and `erin` remain (you are looking for `3` yourself, so your own row is
   listed too — User Story 1 scenario 4). Every remaining row still shows the same person, floors,
   locker and swap control as before (FR-013, FR-014).
6. **Expect**: the address now carries `?looking_for=3` (FR-018).

## 2 — Narrowing by the floor people currently occupy (User Story 2)

1. Return the first group to "All floors", then choose `3` in the **current floor** group.
2. **Expect**: only `bob` and `carol` remain — the two people whose saved floor is `3` — whatever
   they happen to be looking for.
3. **Expect**: `erin` is **not** listed: she has never saved a floor, and this is not reported as an
   error (FR-012, User Story 2 scenario 2).
4. Return that group to "All floors".
5. **Expect**: `erin` is listed again, her "Their floor" cell reading "Not set" as it does today
   (User Story 2 scenario 3).

## 3 — Combining and clearing (User Story 3)

1. Set "looking for floor" to `1` **and** "current floor" to `3`.
2. **Expect**: only `bob` remains — he is looking for `1` and is currently on `3`. A row matching only
   one of the two is not shown (FR-011).
3. **Expect**: both groups still offer their full set of floors — setting one did not remove choices
   from the other (FR-006, User Story 3 scenario 6).
4. Return one group to "All floors".
5. **Expect**: the list widens to everything matching the group still set, and only that group's
   selection remains marked as current.
6. Return the other to "All floors".
7. **Expect**: the full list is back, in its original order, and the address is bare `/locker_wishes`.

## 4 — The list updates in place (User Story 3, scenario 5)

1. Scroll down so the wish list fills the window and the declare panel is off-screen above.
2. Change either filter.
3. **Expect**: the page does **not** jump to the top. Only the list region changes; the declare panel
   and your scroll position are exactly where they were (FR-009, SC-006).
4. Try four more floors in a row without scrolling.
5. **Expect**: no scrolling was needed at any point (SC-006).
6. Press the browser **Back** button.
7. **Expect**: the previous filter state returns, list and controls together (FR-018).

## 5 — Nothing matches (User Story 4)

1. Set "looking for floor" to `10` and "current floor" to `1` — nobody is both.
2. **Expect**: a message saying no wish matches the chosen filters. It must **not** be the
   "Nobody is looking for a locker right now." wording (FR-016).
3. **Expect**: both selections are still shown as current, so you can relax either one
   (FR-015, User Story 3 scenario 7).
4. Edit the address by hand to `?looking_for=NOPE`.
5. **Expect**: the screen renders without error, the list is empty with the same no-match message,
   and `NOPE` is shown as the current selection with "All floors" one activation away (FR-020).

## 6 — The selections survive your own writes (FR-019)

1. Set "looking for floor" to `3`. Confirm your own row is listed.
2. In the declare panel, change your wish to `5` and save.
3. **Expect**: the confirmation "Locker search saved." appears, the filter is **still** on `3`, and
   your row has left the list because it no longer matches.
4. Change your wish back to `3`.
5. **Expect**: the filter is still on `3` and your row is back.
6. Submit the declare form with an empty floor.
7. **Expect**: the usual validation error, and the list below it is still filtered on `3`.
8. Cancel your wish.
9. **Expect**: "Locker search cancelled.", the filter still on `3`, your row gone.

## 7 — Keyboard and assistive technology (FR-008, FR-021, SC-008)

1. Using only the keyboard, Tab into the "looking for floor" group and move across its choices.
2. **Expect**: moving between choices changes **nothing** — the list re-filters only when you press
   Enter on one (FR-008, User Story 1 scenario 6).
3. **Expect**: each group announces its own name, so the two axes are distinguishable, and the choice
   in force is announced as current (FR-002, FR-021).
4. Reach and use "Propose swap" on a filtered row by keyboard alone.
5. **Expect**: it behaves exactly as it does from the unfiltered list (FR-014).

## 8 — Narrow widths (FR-023)

1. Narrow the window below the 48rem breakpoint.
2. **Expect**: the filter bar wraps onto multiple lines; the page does not scroll sideways, and the
   list restacks into one card per wish as it already does.

## Automated suites

```sh
bin/rails test                                          # unit + integration
bin/rails test:system                                   # browser, including axe-core
bin/rubocop                                             # zero warnings (Principle I)
```

Targeted runs while working:

```sh
bin/rails test test/models/floor_filter_test.rb
bin/rails test test/models/locker_wish_test.rb
bin/rails test test/controllers/locker_wishes_controller_test.rb
bin/rails test:system test/system/locker_wish_filter_test.rb
bin/rails test:system test/system/locker_wish_test.rb        # must pass unchanged (FR-013/FR-014)
```
