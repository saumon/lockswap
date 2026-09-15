# Quickstart: Streamlined Locker Entry & Pencil-Icon Edit

Validates this feature end-to-end against a running instance of the app. See [data-model.md](./data-model.md) for the underlying fields and [contracts/locker-profile-update.md](./contracts/locker-profile-update.md) for the reused endpoint.

## Prerequisites

- Ruby 3.4.6, Rails 8.1 app dependencies installed (`bundle install`)
- SQLite dev database migrated and seeded with test fixtures (`bin/rails db:test:prepare` for the test DB; fixtures in `test/fixtures/users.yml`)
- Headless Chrome available for Selenium (already required by the existing system-test suite)

## Setup

```sh
bin/setup            # installs gems, prepares the database
bin/rails server      # or: bin/dev, if a Procfile.dev is present
```

## Scenario A — First-time user enters a locker

1. Sign up or log in as a user with no `floor` saved (e.g., fixture `alice`).
2. On landing on `/`, confirm the "Add your locker details" card is shown with the "entering-locker" view active by default: a `Floor` field and a `Locker number` field, plus an "I don't have a locker 😔" control.
3. Fill in `Floor` and `Locker number`, submit.
4. **Expected**: redirected to `/`, "Your locker" card now shows both values, flash notice "Locker details saved."

## Scenario B — First-time user declares no locker

1. Log in as a user with no `floor` saved.
2. Click "I don't have a locker 😔".
3. **Expected**: the `Locker number` field disappears from view (and any previously typed value in it is cleared); only `Floor` remains.
4. Submit with a `Floor` value.
5. **Expected**: redirected to `/`, "Your locker" card shows the floor and "No locker assigned".

## Scenario C — Switching between the two views before submitting

1. Log in as a user with no `floor` saved.
2. Type a value into `Floor`.
3. Click "I don't have a locker 😔", then click "Actually, I have a locker" (or equivalent back control).
4. **Expected**: the `Floor` value typed in step 2 is still present; the `Locker number` field is visible again.

## Scenario D — Submitting the no-locker view without a floor

1. Log in as a user with no `floor` saved.
2. Click "I don't have a locker 😔", leave `Floor` blank, submit.
3. **Expected**: `422`, "Floor can't be blank" shown, no data saved.

## Scenario E — Editing saved details via the pencil icon

1. Log in as a user with an existing floor and locker number (e.g., fixture `bob`, no active swap proposal).
2. On the "Your locker" card, confirm there is **no** visible "Edit locker details" text — only an icon-only pencil control in the card header.
3. Click the pencil icon.
4. **Expected**: the standard floor/locker-number form appears, pre-filled with the current values.
5. Change the floor, submit.
6. **Expected**: "Your locker" card reflects the new floor; locker number unchanged.

## Scenario F — Accessibility

1. Repeat Scenario E using a screen reader (or inspect the accessible name via browser devtools / axe).
2. **Expected**: the pencil control announces "Edit locker details" (or equivalent) despite no visible text.
3. Run the project's axe-core system-test audit (`assert_axe_clean`) against the homepage in both the first-entry and saved-profile states.
4. **Expected**: no new violations.

## Scenario G — Existing lock behavior is preserved

1. Log in as a user with an active swap proposal holding their locker details (005 behavior).
2. **Expected**: neither the pencil icon nor any edit form is shown; the existing explanatory message ("cannot be changed while you have an active swap proposal…") is shown instead, exactly as before this feature.

## Automated coverage

Run the updated system test suite:

```sh
bin/rails test test/system/locker_profile_test.rb
```

All existing assertions must still pass (updated for the new pencil-icon trigger in place of the "Edit locker details" summary text), plus new coverage for Scenarios A–D above.
