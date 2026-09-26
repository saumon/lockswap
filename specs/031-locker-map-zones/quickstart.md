# Quickstart: validating 031 end to end

## Prerequisites

```sh
bin/rails db:migrate            # creates zones, locker_map_entries
bin/rails tailwindcss:build     # after any stylesheet change
```

## Automated checks

```sh
bin/rails test test/models/zone_test.rb test/models/locker_map_entry_test.rb test/models/user_test.rb
bin/rails test test/validators/known_locker_validator_test.rb
bin/rails test test/controllers/admin/locker_map_controller_test.rb \
               test/controllers/admin/zones_controller_test.rb \
               test/controllers/admin/locker_map_entries_controller_test.rb \
               test/controllers/locker_profiles_controller_test.rb \
               test/controllers/admin/user_locker_profiles_controller_test.rb
bin/rails test test/system/admin_locker_map_test.rb
bin/rails test test/system/locker_profile_test.rb
bin/rails test test/i18n_completeness_test.rb test/stylesheet_breakpoint_test.rb
bin/rails test && bin/rails test test/system     # full suite, as CI runs it
bin/rubocop && bin/brakeman --no-pager
```

## Manual scenarios (`users(:grace)` is a granted, non-super admin; `users(:carol)` is a standard user —
CLAUDE.md: fixture users, not freshly created ones, for capture-script stability)

1. **As `grace`**, open the Locker Map from the admin submenu (visible without needing `super_admin?`).
   Create zone "Aile Nord" on floor "2" with lockers 201, 202, 203 (US1, FR-002–FR-005).
2. **Try to name a second zone on floor "2"** "Aile Nord" again: refused inline, existing zone unchanged
   (FR-004a).
3. **Try to declare locker 203 on floor "2"** in a different zone: refused, message names "Aile Nord"
   (FR-008).
4. **As `carol`** (standard user), request `GET /admin/locker_map` directly: redirected home with the
   "administrators only" alert (FR-001).
5. **As `carol`**, save locker profile floor "2" / locker "999" (not declared): refused, "not a recognized
   locker" (US2 scenario 1, FR-010).
6. **As `carol`**, save floor "2" / locker "203": succeeds (US2 scenario 2).
7. **As `grace`**, edit `carol`'s locker from the admin account editor to floor "2" / locker "999": refused
   the same way (US2 scenario 3).
8. **As `carol`, with floor "2" / locker "203" already saved**, change only the floor to "3" (where "203" is
   not declared), leaving the locker number text as "203": refused — the pair, not either half alone, must
   be known (US2 scenario 4).
9. **Delete zone "Aile Nord"** (non-empty) from the Locker Map: it and its three lockers disappear in one
   action; `carol`'s already-saved floor "2" / locker "203" still displays on her profile unchanged, but
   re-saving that same pair (by her or by `grace`) is now refused until a zone declares it again (US3,
   FR-006, FR-013).
10. **Look at the page** (CLAUDE.md "How to check the work"): a throwaway system test that screenshots the
    Locker Map at desktop and `with_viewport(:phone)` into `tmp/design/`. Check zone cards hang on the
    default (navy, `--color-rail-system`) hinge — a zone is neither "you" nor "them" — floor/locker numbers
    render in `--font-mono` `.data-value`, and the per-floor layout stays single-column per CLAUDE.md's
    "no side-by-side controls" rule.
