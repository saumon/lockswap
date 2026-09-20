# Quickstart: Compact floor/locker label alignment

This is a Tailwind CSS + ERB view change with no external interface, so there
is no `contracts/` directory for this feature — validation is visual, per
CLAUDE.md's "How to check the work" section, plus the existing and
newly-added system tests.

## Prerequisites

- Local Rails dev environment runnable (`bin/dev` or equivalent), with the
  test database seeded from fixtures (`bin/rails db:test:prepare` if needed).
- Fixture users available: `bob` (floor `3`, locker number `B12` — has both
  values, no wish) and `carol` (floor `2`, no locker number, has a saved
  locker wish `carol_wish` — see `test/fixtures/users.yml` and
  `test/fixtures/locker_wishes.yml`). Use fixture users, not freshly created
  ones, per CLAUDE.md ("freshly created ones make the menu toggle flaky in
  capture scripts").

## Step 1 — Rebuild the stylesheet after every CSS change

```bash
bin/rails tailwindcss:build
```

Run this after each edit to `app/assets/tailwind/application.css` before
looking at the page.

## Step 2 — Visual check via a throwaway system test

Write a temporary test under `test/system/` (delete it once you've looked at
the screenshots) that:

1. Logs in as `users(:carol)` and visits the homepage — screenshot at default
   viewport to check User Story 1 (floor number inline with "Looking for a
   locker on floor").
2. Logs in as `users(:bob)` and visits the homepage:
   - Default (desktop) viewport — screenshot to confirm the "Your locker"
     block's desktop two-column layout (Floor / Locker number side by side)
     is unchanged, and that "Your locker search"/"Add your locker details"
     still render as cards while "Your locker" no longer has a card
     border/background (User Story 3).
   - `with_viewport(:phone)` — screenshot to confirm "Floor" + `3` sit on one
     line and "Locker number" + `B12` sit on one line (User Story 2).
3. Calls `wait_for_entrance` before each `page.save_screenshot` (per
   CLAUDE.md's entrance-animation guidance) and saves to `tmp/design/`.

Read the resulting PNGs, confirm all three acceptance criteria visually, then
delete the throwaway test.

## Step 3 — Run the real automated tests

```bash
bin/rails test test/system/homepage_locker_wish_test.rb
bin/rails test test/system/locker_profile_test.rb
bin/rails test test/system/responsive_test.rb
bin/rails test test/stylesheet_breakpoint_test.rb
```

Expected outcome: all pass, including any new/updated assertions added for
this feature per Constitution Principle II — existing ID-based selectors
(`#locker-profile-floor`, `#home-locker-wish-floor`, etc.) must still resolve
to the same values, and `stylesheet_breakpoint_test.rb` must still find only
the 48rem / 47.999rem breakpoint pair in the stylesheet.

## Step 4 — Lint

```bash
bin/rubocop
```

No new Ruby logic is introduced, but any touched `.rb` test files must still
pass the Omakase lint per Constitution Principle I.
