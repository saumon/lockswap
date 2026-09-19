# Quickstart: Users Screen — Locker Details and Filters

**Feature**: [spec.md](./spec.md) | **Branch**: `020-admin-users-filters`

Manual validation of the three user stories, once implementation lands. Mirrors
`specs/017-locker-wishes-floor-filter/quickstart.md`'s shape.

## Prerequisites

```bash
bin/rails db:prepare
bin/rails server
```

You need at least:
- One administrator account (the first to register becomes one automatically — 013 FR-001).
- Several standard accounts spanning at least two different floors, at least one with a locker
  number and one without, and at least one that has never saved a floor.
- At least one account with an active locker search wish, and at least one without.

The fastest way to get this state is `bin/rails db:seed` if the project seeds cover it, or by
registering a handful of accounts through the UI and filling in floor/locker/wish from the homepage
and locker-wishes screen as an ordinary user would.

## User Story 1 — See each account's locker, floor and wish at a glance

1. Sign in as the administrator.
2. Open **Admin → Users**.
3. For the account with a floor and locker saved: confirm the row shows both values, matching what
   that account's own homepage shows.
4. For the account with a floor but no locker: confirm the row shows the floor and
   "No locker assigned" (not blank, not an error).
5. For the account that has never saved a floor: confirm the row shows "Not set" for the floor,
   visually distinct from "No locker assigned".
6. For the account with an active wish: confirm the row states it is looking for a locker and names
   the floor, matching the locker wishes screen.
7. For an account with no active wish: confirm the row says so plainly.

**Expected**: every value on every row matches what that same account shows on its own homepage and
on the locker wishes screen. Nothing about the existing "Admin" badge or "Grant admin rights" control
has changed.

## User Story 2 — Narrow the list to a specific locker, floor, role or email

1. On **Admin → Users**, pick one floor in the "Current floor" filter.
2. **Expected**: the table updates in place (the filter bar and page position stay put) to show only
   accounts on that floor. The address bar now includes `?current_floor=<value>`.
3. Clear that filter ("All floors"), then type a locker number into the "Current locker" field.
4. **Expected**: after a brief pause (no need to press Enter or click anything), the list narrows to
   the one account holding that exact locker number. Typing a locker number nobody holds narrows the
   list to nothing (see User Story 3).
5. Clear it, then type part of an email address into the "Email" field.
6. **Expected**: the list narrows to every account whose email contains that text, updating shortly
   after typing stops.
7. Set the "Role" filter to "Admin".
8. **Expected**: only administrator accounts are shown.
9. Combine two or more filters at once (for example, a floor and a role).
10. **Expected**: only accounts matching all the active filters are shown.
11. Reload the page from the address bar with no query parameters.
12. **Expected**: every registered account is shown again, unfiltered.
13. With a floor filter active, use the keyboard to move focus across the floor filter's links without
    activating one (e.g., Tab through them).
14. **Expected**: the list does not change until a link is actually activated.

## User Story 3 — Recognise that a filter combination matches nobody

1. Set a combination of filters (for example, a floor and a role) that no registered account
   satisfies.
2. **Expected**: a clear message states that no account matches the current filters — not a blank
   table, not the page's ordinary loading state. All four filter controls still show what was
   selected/typed.
3. Relax or clear one filter.
4. **Expected**: the list returns to showing whichever accounts now match the remaining filters.

## Cross-check: filters survive granting admin rights (FR-016)

1. Set one or more filters so the list shows a mix of standard accounts.
2. Click "Grant admin rights" on one of the shown standard accounts and confirm the dialog.
3. **Expected**: after the redirect, the same filters are still applied (visible in both the filter
   controls and the address bar), and the promoted account either still appears (marked as
   Admin now) or has dropped out of the list if the promotion made it stop matching (for example, a
   Role filter set to "Standard").

## Regression checks

- `test/system/admin_users_test.rb` and `test/system/locker_wish_filter_test.rb` both pass unchanged
  — confirms this feature did not disturb 013/015's existing screen or 017's filter feature.
- `bin/rails test test/controllers/admin/users_controller_test.rb test/models/user_test.rb test/models/role_filter_test.rb test/system/admin_users_filter_test.rb`
