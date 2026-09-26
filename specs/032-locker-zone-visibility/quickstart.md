# Quickstart: Locker Zone Visibility Across Screens

Manual, end-to-end validation that the feature works as specified. Assumes a working local setup
(`bin/rails db:prepare`, `bin/rails server`) and fixture users (e.g. `carol` — an admin — and `grace` — a
standard user), per this repo's own testing conventions.

## Prerequisites

1. Sign in as an admin fixture user.
2. Open the Locker Map screen (`/admin/locker_map`).
3. Create a zone, e.g. "Aile Nord" on floor "2", and add locker number "203" to it (031's existing screen —
   no change from this feature).
4. Assign floor "2" / locker "203" to a standard fixture user (e.g. `grace`), either as that user via their
   own homepage, or as the admin via that user's account detail page's locker editor.

## Scenario 1 — Own locker (US1)

- Sign in as `grace`.
- Visit the homepage.
- **Expect**: the "Your locker" card shows Floor, Locker number and Zone as three fields in the same
  grid, side by side at desktop width — "Aile Nord", with no colon on its label, styled identically to
  Floor and Locker number (not the inline "Zone: …" sentence used on the other screens below).

## Scenario 2 — Swap-decision screens (US2)

- As a second standard user with a declared wish, visit the locker search list.
- **Expect**: `grace`'s row shows its own dedicated "Zone" column reading "Aile Nord", separate from the
  "Their locker" column.
- Propose a swap to `grace`; sign in as `grace` and view the received proposal on the homepage.
- **Expect**: the proposal reads "Floor 2 · Locker 203 · Zone Aile Nord" on one line, with the sent date
  on its own line below it (in `day/month/year à hour:minute` format).
- Accept the proposal; view the "exchange in progress" card as either party.
- **Expect**: the counterpart's locker line reads "… · Zone Aile Nord" alongside their floor and locker.

## Scenario 3 — Admin screens (US3)

- As the admin, visit the account directory (`/admin/users`).
- **Expect**: `grace`'s row shows its own dedicated "Zone" column reading "Aile Nord", separate from the
  "Locker" column.
- Open `grace`'s account detail page.
- **Expect**: the zone is shown as a third field alongside Floor and Locker, inline ("Zone: Aile Nord").

## Scenario 4 — Swap history shows none of this

- After a swap involving a mapped locker completes, visit the self-service history screen
  (`/locker_swap_proposals`) as either party, and the admin account detail page's history table for
  either account.
- **Expect**: the "Locker details" column reads only "Proposed: Floor 2, Locker 203 for …" (or
  "Exchanged: …" once completed) — no zone name anywhere in it. This was shipped and then explicitly
  withdrawn: a single column can't cleanly carry two different people's zones in one row.

## Edge cases to check

- **Unmapped locker**: assign a user a locker number never declared in the Locker Map (or on a floor with no
  zones). **Expect**: floor/locker show exactly as before this feature, with no zone text — Scenarios 1 and
  4 show nothing extra; the two dedicated-column screens (Scenario 2's search list, Scenario 3's account
  directory) show the "No zone" placeholder instead, matching their neighbouring "Not set"/"No locker
  assigned" columns.
- **No locker at all**: a user with nothing saved. **Expect**: the existing "no locker assigned" wording,
  unchanged; no zone field or column value in its place.
- **Rename**: rename "Aile Nord" to "Aile Sud" on the Locker Map screen, then reload each screen above.
  **Expect**: every one now reads "Aile Sud", with no separate step.
- **Removed from zone**: remove locker "203" from its zone (or delete the zone) on the Locker Map screen,
  then reload each screen above. **Expect**: no zone name shown anywhere for that locker; `grace`'s own
  saved floor/locker value is untouched.
- **Empty Locker Map**: on a fresh install with nothing ever declared, confirm every screen above shows no
  zone anywhere, matching pre-feature behavior exactly.

## Automated coverage

Full regression coverage lives in the test suite (see `plan.md` → Technical Context → Testing); this
quickstart is a fast, human-verifiable sanity pass, not a replacement for it.
