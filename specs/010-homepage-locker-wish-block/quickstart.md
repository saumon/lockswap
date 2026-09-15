# Quickstart: Validating the Homepage Locker Wish Block

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Contract**: [contracts/homepage-locker-wish-block.md](./contracts/homepage-locker-wish-block.md)

## Prerequisites

- Ruby 3.4.6 and the bundle installed (`bundle install`)
- Chrome available to Selenium for system tests — set `CHROME_BIN` if the only Chrome is
  the one Selenium Manager downloaded (see `test/application_system_test_case.rb`)
- No migration to run: this feature changes no schema

## Automated validation

```bash
# The feature's own coverage — all three states, the withheld case, precedence,
# navigation, and the active-proposal case
bin/rails test test/system/homepage_locker_wish_test.rb

# The screens this block sits on stay accessible (008 FR-028)
bin/rails test test/system/accessibility_test.rb

# Nothing on the homepage or the wish flow regressed
bin/rails test test/system/locker_profile_test.rb test/system/locker_wish_test.rb

# Full suite + lint, as the merge gates require
bin/rails test && bin/rails test:system && bin/rubocop
```

Expected: green. A new user fixture is added by this feature; if an unrelated test starts
failing on a count of users, wishes, or proposal rows, that test was asserting on fixture
totals and the assertion — not the fixture — needs revisiting.

## Manual validation

Start the app with `bin/dev`, then sign in as each fixture account below. The password for
every fixture user is `password123`.

| Sign in as | Fixture state | Expect on the homepage |
|------------|---------------|------------------------|
| `bob@example.com` | Locker B12 on floor 3, wish for floor 7 | Block shows floor **7** and a **Review locker wishes! 🥷** button — and does *not* repeat floor 3 / B12, which the card below already shows |
| `carol@example.com` | Floor 2, no locker, wish for floor 5 | Block shows floor **5** and the same **Review locker wishes! 🥷** button — the wish wins even with no locker |
| `dave@example.com` | Locker D07 on floor 4, no wish | Block shows **I want to switch my locker! 👀** and no wish values |
| the new fixture user | Floor on file, no locker, no wish | Block shows **I want a locker! 🙏** and no wish values |
| `alice@example.com` | Nothing on file | **No block at all** — only the "Add your locker details" card |

Then check the behaviours the table cannot express:

1. **Placement (FR-012)** — as any user above who sees the block: it sits below the swap
   sections and directly above the "Your locker" card.
2. **Navigation (FR-006)** — activate the control in each state; it lands on
   `/locker_wishes` in one action, from a click and from Enter on a keyboard-focused
   control alike.
3. **Freshness (FR-007)** — as `dave`, declare a wish on the wish page, return to the
   homepage: the block now shows that wish and the review button. Cancel the wish and
   return: it is back to **I want to switch my locker! 👀**.
4. **Onboarding (FR-001a)** — as `alice`, save locker details by either path, including
   "I don't have a locker 😔". The block appears on the next homepage view, in the state
   matching what was saved.
5. **Active proposal (FR-013)** — as a user whose locker details are frozen by an active
   proposal (the card below shows the "cannot be changed while you have an active swap
   proposal" explanation): the block is unchanged and its control still works.
6. **Keyboard and reader (FR-010)** — Tab to the control: it takes visible focus in
   reading order, is announced as a link, and its accessible name is the button's label.

## What would mean the design drifted

This feature is expected to touch `app/views/home/index.html.erb`, one new partial, and
test files only. If implementation finds itself editing `config/routes.rb`, a controller, a
model, a migration, the stylesheet, or adding JavaScript, stop and re-read
[research.md](./research.md) — each of those was considered and ruled out, and a genuine
need to revisit one belongs in the plan before it lands in the code.
