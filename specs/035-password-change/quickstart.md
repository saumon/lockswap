# Quickstart: validating 035

**Feature**: 035-password-change. Contracts: [contracts/routes-and-screens.md](contracts/routes-and-screens.md).
Model: [data-model.md](data-model.md).

## Prerequisites

```sh
bin/rails db:migrate          # adds the two throttle columns
bin/rails tailwindcss:build   # if the stylesheet changed
```

## Automated

```sh
bin/rails test test/models/password_change_test.rb
bin/rails test test/controllers/registrations_controller_test.rb
bin/rails test:system TEST=test/system/password_change_test.rb
bin/rails test test/i18n_completeness_test.rb test/documentation_links_test.rb
bin/rails test && bin/rails test:system   # full suite, CI gate
```

What the tests must prove (each fails without the change):

| Scenario | Expected |
|---|---|
| Menu → account page | identity link reaches `/users/edit` at phone and desktop widths |
| Correct change | 303 to account page, success panel lists 3 statements, old password refused at sign-in, new accepted |
| Second browser session (`Capybara.using_session`) | next request → sign-in |
| Second browser with only a remember-me cookie | not signed in after the change |
| Changing browser's own remember-me cookie | still signs it in after the session cookie is dropped |
| Reset link issued before the change | refused afterwards |
| Notification | exactly one `password_change` mail enqueued on success, none on refusal |
| Wrong current password | 422, error on that field only, no mail, other sessions still valid |
| 5 wrong in a row, then the correct one | 6th refused as throttled without checking; still signed in; sign-in elsewhere works |
| 15 minutes later (`travel`) | accepted again |
| Too short / mismatch, with JS | no request sent, hint shown, typed values intact |
| Same, server side (direct PATCH) | 422 with field errors, fields empty |
| New = current | 422, `same_as_current` |
| `PUT /users` carrying `password` | password unchanged |
| Expired session then PATCH | sign-in, then lands on `/users/edit` |
| Logs | no password value in `log/test.log` for any of the above |

## By eye (CLAUDE.md "How to check the work")

Throwaway system test as `users(:carol)`: visit `/users/edit`, `wait_for_entrance`, screenshot to
`tmp/design/` — empty form, refused form, success panel — at desktop and `with_viewport(:phone)`. Check the
tab order follows the visual order, and the success panel and error summary both take focus. Delete the test.

## Manually (development)

1. `bin/dev`, sign in as one user in two browsers.
2. In browser A: menu → email → Change password → submit.
3. Browser A stays signed in. Browser B's next click lands on sign-in.
4. `/letter_opener` shows one "password changed" email.
