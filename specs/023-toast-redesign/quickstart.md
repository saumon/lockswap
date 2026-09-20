# Quickstart: Validating the Modernized Toast Notifications

Prerequisites: a working local Rails setup (`bin/setup` already run), the app's fixture users available (`users(:carol)` etc. — see CLAUDE.md, freshly created users make menu-toggle capture flaky).

## 1. Build the stylesheet after any CSS change

```bash
bin/rails tailwindcss:build
```

Run this after every edit to `app/assets/tailwind/application.css` before visually checking anything below.

## 2. See the redesigned toast in the browser

Write a throwaway system test under `test/system/` (per CLAUDE.md's "How to check the work"):

```ruby
require "application_system_test_case"

class ToastDesignPreviewTest < ApplicationSystemTestCase
  test "capture the redesigned toast" do
    log_in_as users(:carol)
    wait_for_entrance
    page.save_screenshot("tmp/design/toast-success.png")
  end
end
```

Run it, look at `tmp/design/toast-success.png`, then delete the test. Repeat triggering an error path (e.g. an invalid sign-in) to capture the error variant, and again `with_viewport(:phone)` for the narrow treatment.

## 3. Validate against the spec's acceptance scenarios

- **Placement (User Story 2)**: trigger a notification at desktop width — it must appear fixed to the bottom-right corner, never over the header/nav or the content just interacted with. Resize/rotate to phone width — it must re-settle without going off-screen or under a control.
- **Short viewport (edge case)**: shrink the browser window's *height* (not just width) so the page is a tall form on a short screen, then trigger a notification — it must not land on top of a control the user is about to use (e.g. a submit button pinned near the bottom).
- **Type distinction (User Story 1, FR-002)**: trigger a success and an error notification; confirm each shows its icon, its status color on the left edge, and the message — and that covering the icon+color (e.g. squinting) still leaves the text distinguishable.
- **Stacking + cap (User Story 3, FR-010)**: trigger 4+ notifications in quick succession (e.g. hit an action that flashes, then immediately trigger others via distinct Turbo Stream responses or a scripted burst in the test). Confirm at most 3 are visible at once, all fully legible, and the 4th appears only once one of the first three clears.
- **Behavior preserved (FR-006, FR-007)**: re-run the existing `test/system/notification_test.rb` suite — auto-dismiss timing, hover/focus pause, manual dismiss, and the `<main>` rect equality test must all still pass.

```bash
bin/rails test test/system/notification_test.rb
```

## 3b. Measuring the two qualitative success criteria

SC-001 and SC-002 are judged by people, not by a test suite — do not skip them as "not automatable":

- **SC-001** (≥80% prefer the new look): put tasks.md's "before" screenshot (Setup phase) and "after" screenshot (end of User Story 1) side by side and show them to at least 5 people who haven't seen this feature before (teammates are fine). Ask a single yes/no: "does the new one look more consistent with the rest of the app?" ≥80% (at least 4 of 5) must say yes. Record the tally in the PR description.
- **SC-002** (identify type within 1 second, without reading text): show a teammate a screen recording or a live trigger of a success and an error toast, one at a time, each covered/blurred except for its icon+color for the first second; ask them to say "success" or "error" as soon as they can. If they consistently answer correctly before the message text would be readable, it passes. This is a spot-check (2-3 people), not a formal study.

## 4. Accessibility spot-check

- Tab to a visible notification's dismiss button — it must be reachable by keyboard alone, and the countdown must already be paused for it (per FR-006, inherited from 007's pause-on-focus).
- Confirm the new `.toast-icon` is `aria-hidden="true"` — a screen reader should announce the role (`status`/`alert`) and message text once, not the icon separately.
- Check computed contrast on the new visual treatment (message text against its background, per FR-009's ≥4.5:1 bar) — measure, do not estimate, per CLAUDE.md.
- Trigger a notification with the browser's dev tools open to the Animations/Performance panel (or `getComputedStyle(el).transitionDuration`/`animationDuration`) and confirm its entrance settles within `--motion-entrance` (240ms) and its exit does not linger past the same budget (FR-004, SC-006).

## Expected outcome

All items in spec.md's Acceptance Scenarios pass, `notification_test.rb` (existing + new assertions) passes, and `bin/rails tailwindcss:build` completes without introducing any raw hex value or new breakpoint width (`test/stylesheet_breakpoint_test.rb` must still pass).
