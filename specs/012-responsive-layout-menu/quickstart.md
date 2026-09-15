# Quickstart: Validating the responsive layout and menu

**Feature**: 012-responsive-layout-menu

How to run the feature and prove it works. Implementation detail belongs in
`tasks.md`; this is the run-and-check guide.

## Prerequisites

```bash
bin/setup                  # if this is a fresh checkout
```

Chrome must be resolvable by the system tests. `ApplicationSystemTestCase`
resolves it via Selenium Manager and honours `CHROME_BIN` if you need to point
at a specific build.

## Run the app

```bash
bin/dev                    # Rails + the Tailwind watcher (see Procfile.dev)
```

Then sign in at <http://localhost:3000> and resize the window across 768px.

## The automated gates

```bash
# The whole suite — what CI runs.
bin/rails test test/system

# Just this feature's sweeps.
bin/rails test test/system/responsive_test.rb
bin/rails test test/system/site_menu_test.rb

# Accessibility, now including the phone width.
bin/rails test test/system/accessibility_test.rb

# Non-regression on the screens this feature touches.
bin/rails test test/system/navigation_test.rb \
               test/system/locker_wish_test.rb \
               test/system/locker_swap_proposal_test.rb

# Lint.
bin/rubocop
```

> **Rebuild the stylesheet before running system tests.** The suite serves
> `app/assets/builds/tailwind.css`, not `app/assets/tailwind/application.css`.
> A stylesheet change that has not been compiled reads as a failing assertion
> about the layout rather than as a missing build step, which is a confusing
> way to spend ten minutes. `bin/rails test:system` runs `tailwindcss:build`
> for you; running a single test file directly does not, so:
>
> ```bash
> bin/rails tailwindcss:build && bin/rails test test/system/responsive_test.rb
> ```
>
> `bin/dev` runs the watcher, so this does not apply while the app is running.

> **`bin/ci` is not enough for this feature.** `config/ci.rb` leaves
> `step "Tests: System"` commented out, and `bin/rails test` excludes system
> tests by default. GitHub Actions does run them, in its own `system-test` job,
> so run `bin/rails test:system` locally before pushing rather than relying on
> `bin/ci` being green.

Expected: green. A failure in `responsive_test.rb` names the width it was at.

## Manual checks

Three things the automated suite cannot cover.

### 1. The breakpoint, by eye

Sign in, then narrow the window through 768px.

| At | Expect |
|---|---|
| ≥ 768px | full bar: brand, both destinations, your email, Log out. No toggle. |
| ≤ 767px | brand + toggle only. Tapping the toggle reveals all four. |
| ≤ 767px, list screens | records as labelled cards; "Propose swap" visible without swiping |
| any width | no horizontal page scrollbar |

### 2. No-script baseline (FR-010b, SC-006a)

Disable JavaScript in DevTools (Command Palette → "Disable JavaScript"), reload
at a narrow width, and confirm:

- the toggle still opens and closes the panel
- every destination and Log out are reachable
- only Escape and outside-click dismissal are missing

### 3. Deferred items

Recorded in the plan as manual-only; note the result in the PR.

- **FR-008** — on a real phone, open the locker-profile and locker-wish forms
  and confirm the field being edited and its submit control stay reachable with
  the on-screen keyboard up.
- **SC-008** — at desktop width, set browser zoom to 200% and confirm no content
  or control is lost.

## Quick self-check on the single-breakpoint rule

FR-018 says one breakpoint, site-wide. Match media queries only — `max-width`
is also an ordinary property, used on five container rules, so a bare
`grep max-width` gives false positives:

```bash
grep -nE "@media[^{]*(min|max)-width" app/assets/tailwind/application.css
```

This should return only `48rem` and `47.999rem`. Today it returns one line, the
`40rem` `.detail-grid` rule this feature is required to move (FR-018a); any
other width afterwards is a defect.

## What "done" looks like

- `bin/rails test` and `bin/rubocop` green
- both manual checks above pass
- the two deferred items verified by hand and recorded in the PR
- the PR describes which existing patterns were reused (Principle III) and notes
  the added CI cost (Principle IV)
