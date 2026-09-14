# Quickstart: Validate Auto-Dismissing Popup Notifications

Validates the feature end-to-end against the acceptance scenarios in [spec.md](./spec.md). See [data-model.md](./data-model.md) for the notification lifecycle and [contracts/notification-ui-contract.md](./contracts/notification-ui-contract.md) for the rendering contract.

## Prerequisites

- Ruby 3.4.6, Rails 8.1.3 installed (`bin/setup` if not already done).
- `bin/rails db:prepare` has been run (SQLite dev DB exists).
- A test/dev user account exists — sign up via `/users/sign_up` if needed.

## Manual verification (browser)

1. **Start the app**: `bin/dev` (Puma + Tailwind watcher via foreman), open `http://localhost:3000`.
2. **Success popup + auto-dismiss (User Story 1)**:
   - Sign in with valid credentials.
   - Expected: a "Signed in successfully." popup appears at the **top right, just below the header** (not a static banner pushed into page flow) and disappears on its own after ~3 seconds. Narrow the window to phone width and it shrinks to fit rather than running off the edge.
3. **Error popup + auto-dismiss (User Story 2)**:
   - Trigger a validation failure (e.g. submit an invalid/duplicate swap proposal, or sign in with a wrong password).
   - Expected: an error popup appears, visually distinct (red/rose) from a success popup (green/emerald), and also disappears automatically after ~3 seconds.
4. **Manual dismiss (User Story 3)**:
   - Trigger any popup, click its close control before the 3 seconds elapse.
   - Expected: it disappears immediately.
5. **Hover/focus pauses the countdown** (Clarifications):
   - Trigger a popup, hover the mouse over it (or Tab to focus it) and hold for >3 seconds.
   - Expected: it does NOT disappear while hovered/focused; moving away resumes the countdown from where it left off (not a fresh 3 seconds).
6. **Stacking (Edge Cases / FR-007)**:
   - No controller action sets both `notice` and `alert`, so this cannot be reached through the UI; it is covered by `test/views/layouts/flash_test.rb`, which renders the partial with both. To see it in a browser, set both in a console-driven request or temporarily add both to one `redirect_to`.
   - Expected: both appear, stacked in one column, neither standing in for the other.
7. **No layout shift (FR-005)**:
   - Observe page content while a popup is visible and after it disappears.
   - Expected: the main page content never shifts, no empty gap is left behind, and the header navigation is never covered.
8. **Screen reader spot-check (FR-008 / accessibility)**:
   - With a screen reader (e.g. VoiceOver), trigger a success and an error popup.
   - Expected: each is announced (status vs. alert urgency matches today's behavior).

## Automated verification

```sh
# Full system test suite (Capybara + Selenium), includes the new notification tests
bin/rails test:system

# Just the notification behaviour: appearance, auto-dismiss, hover-pause, manual
# dismiss, layout stability, long-message wrapping
bin/rails test test/system/notification_test.rb

# The partial itself: stacking, ARIA roles, the empty case, and the shipped
# three-second countdown
bin/rails test test/views/layouts/flash_test.rb

# Existing flows whose assertions must still pass unchanged
bin/rails test test/system/login_test.rb test/system/login_failure_test.rb test/system/locker_profile_test.rb
```

Expected: all pass, including existing `assert_no_selector "[role=alert]"`/equivalent assertions (the popup must be fully removed from the DOM on dismiss, per the [contract](./contracts/notification-ui-contract.md)).

Note: the system tests run a **shorter countdown than the one that ships** — `config/environments/test.rb` overrides `config.x.notification_auto_dismiss_ms` so the suite is not waiting out three real seconds per assertion. The shipped three seconds is asserted separately in `test/views/layouts/flash_test.rb`. The manual steps above use the real value, so time them against a dev server, not a test run.
