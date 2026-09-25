# Quickstart: validating 030 end to end

## Prerequisites

```sh
bin/rails db:migrate            # creates site_floor_lists, locker_number_formats
bin/rails tailwindcss:build     # after any stylesheet change
```

## Automated checks

```sh
bin/rails test test/models/site_floor_list_test.rb test/models/locker_number_format_test.rb \
               test/models/user_test.rb test/models/locker_wish_test.rb
bin/rails test test/controllers/admin/floor_list_controller_test.rb \
               test/controllers/admin/locker_number_format_controller_test.rb
bin/rails test:system TEST=test/system/admin_danger_zone_test.rb
bin/rails test:system TEST=test/system/locker_profile_test.rb
bin/rails test test/i18n_completeness_test.rb test/stylesheet_breakpoint_test.rb
bin/rails test && bin/rails test:system     # full suite, as CI runs it
bin/rubocop && bin/brakeman --no-pager
```

## Manual scenarios (as `users(:frank)`, the super admin; `users(:grace)` is the granted admin)

1. **Nothing configured**: every floor field is still a text box, and any locker number is accepted
   (FR-006).
2. **Save floors** "RDC, 1, 2, 2, , 3" on the danger zone. After the reload the field reads
   "RDC, 1, 2, 3". The home locker profile, the locker wish declaration and the admin account editor
   each offer a select with exactly RDC, 1, 2, 3 in that order (US1, US2).
3. **Submit a blank floor list**: it is refused inside the floors card, and the old list is kept.
4. **Remove floor 3** while a user is on 3: that user's profile still shows 3, the select shows
   "3 (no longer offered)" selected, saving the form unchanged succeeds, and choosing 7 through a
   crafted request is refused (FR-007, FR-011).
5. **Save the pattern** `\d{3}` with the description "3 chiffres, ex. 042". The examples table shows
   `\d{3}`: 042 Accepted, 42 Refused, 1234 Refused. The locker number hint reads "Required format:
   3 chiffres, ex. 042". Saving 42 is refused with the description in the message. Saving " 042 " saves
   "042". Clearing the number is accepted (US3, US4, FR-015).
6. **Save the pattern** `[0-9`: it is refused, and `\d{3}` stays in force (FR-010).
7. **As a granted (non-super) admin**, `PATCH /admin/floor_list` redirects home with the "administrators
   only" alert (FR-019).
8. **Switch the site language** and repeat step 5: every new label, hint and message is in French.
9. **Look at the page** (CLAUDE.md "How to check the work"): a throwaway system test that screenshots the
   danger zone at desktop and `with_viewport(:phone)` into `tmp/design/`. Check the two new cards hang on
   the alert hinge, the examples table becomes cards below 48rem, and the badges carry words.
