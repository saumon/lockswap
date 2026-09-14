# Quickstart: Validating the Visual Identity Refresh

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-14

How to run the refreshed app and prove it satisfies the spec. Implementation belongs in `tasks.md`; this is the run-and-verify guide.

---

## Prerequisites

- Ruby 3.4.6, Bundler
- Google Chrome (headless, for the system suite)
- `bin/setup` completed at least once

```bash
bundle install          # picks up axe-core-api
bin/rails tailwindcss:build
```

---

## Run it

```bash
bin/dev                 # rails server + tailwindcss:watch
```

Then visit <http://localhost:3000>. An unauthenticated visitor lands on the sign-in page; that is unchanged.

Seed users come from `test/fixtures/users.yml` (password `password123`) — or register a new account.

---

## Screens to walk

All 12, since FR-010 requires every one restyled:

| # | Screen | Path |
|---|---|---|
| 1 | Sign in | `/users/sign_in` |
| 2 | Sign up | `/users/sign_up` |
| 3 | Account settings | `/users/edit` |
| 4 | Home — no locker details yet | `/` |
| 5 | Home — locker profile saved | `/` |
| 6 | Home — edit disclosure open | `/` |
| 7 | Home — proposals received | `/` |
| 8 | Home — proposals sent | `/` |
| 9 | Home — exchange in progress | `/` |
| 10 | Locker wishes — with entries | `/locker_wishes` |
| 11 | Locker wishes — empty | `/locker_wishes` |
| 12 | Proposal history | `/locker_swap_proposals` |

---

## Automated checks

### Full suite — must be green (FR-029, SC-004b)

```bash
bin/rails test && bin/rails test:system
```

`test:prepare` is already chained to `tailwindcss:build`, so system tests always run against freshly compiled CSS. The system suite is single-worker by design; expect it to take a few minutes.

### Accessibility — the primary test evidence (FR-028, SC-004)

```bash
bin/rails test test/system/accessibility_test.rb
```

Every screen is audited against `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`. Zero violations required.

A failure names the rule and the offending node, e.g.:

```
Found 1 accessibility violation:
1) color-contrast: Elements must have sufficient color contrast (serious)
   <a class="btn-primary" href="/locker_wishes">
```

The only permitted exclusion is `color-contrast` on the brand wordmark, scoped to that element, carrying an inline comment citing WCAG 2.1 SC 1.4.3's logotype exemption. Any other suppression is a defect, not a fix.

### Font actually resolved — guards a silent failure (FR-005a, FR-026)

Propshaft **logs a warning and ships the unrewritten URL** when it cannot resolve a `url()`; it does not raise. A misconfigured font path therefore produces a working build and a broken font. Check explicitly:

```bash
bin/rails tailwindcss:build
bin/rails runner 'css = Rails.application.assets.load_path.find("tailwind.css").compiled_content
                  m = css[/url\("([^"]*nunito[^"]*)"\)/, 1]
                  abort "FONT NOT RESOLVED" unless m&.match?(/-[0-9a-f]{8,}\./)
                  puts "font resolves to: #{m}"'
```

`compiled_content` is the method that applies Propshaft's compilers — plain `content` returns the file unrewritten and would always look like a failure. A digested filename (`nunito-latin-variable-<hash>.woff2`) means resolution worked; a bare `nunito-latin-variable.woff2` means it is not resolving — check the file is present under `app/assets/fonts`, which Propshaft picks up simply by existing.

---

## Manual verification

### Reduced motion (FR-020, SC-006)

macOS: System Settings → Accessibility → Display → **Reduce motion**.
Or in Chrome DevTools: ⌘⇧P → *Emulate CSS prefers-reduced-motion: reduce*.

Reload and confirm no entrance animation, no hover lift, no logo flourish — and that every screen stays fully readable and operable.

### Motion, enabled (FR-016, FR-017, FR-019, FR-022)

- Content eases in once per page load; the page is clickable immediately.
- Buttons and cards respond to hover and to keyboard focus, and revert smoothly.
- A submitted form swaps its button label while in flight.
- The logo flourish plays **once** on sign-in and does not loop.
- **Scroll a long history page: nothing animates into view** (FR-016a, SC-006a).
- **Navigate between pages: no transition animation** (FR-016a, SC-006a).

### Keyboard (FR-024, SC-005)

Tab through each screen. Every focusable control shows a visible ring, distinct from hover. Nothing is reachable but invisible; nothing is visible but unreachable.

### Narrow viewport (FR-014, SC-007)

DevTools at 360px width. For each screen: no horizontal page scroll, no clipped control, brand and navigation both visible and not overlapping. Tables and wide rows may scroll inside their own container — the page body may not.

### Font loading (FR-026, SC-010)

DevTools → Network → throttle to *Slow 3G* → hard reload. Text must be readable in the fallback face throughout. No invisible-text gap. No jarring reflow when Nunito arrives.

### Zero third-party requests (FR-005a, SC-008a)

DevTools → Network → reload → sort by Domain. Every request must be same-origin. Any `fonts.googleapis.com` or `fonts.gstatic.com` entry is a failure.

### Performance evidence — required by Constitution IV (SC-008)

Lighthouse or the Performance panel, same conditions before and after:

```bash
git stash            # measure the pre-refresh baseline
# record First Contentful Paint
git stash pop        # measure again
```

Record both numbers in the PR. FCP must not be later than baseline. Added asset weight must stay within the 50KB gzipped budget — the 39KB font is nearly all of it.

### Brand consistency (SC-003)

```bash
grep -rn "LockerSwap" app/ public/ config/
```

Zero hits outside comments. This is a manual check by design: the chosen test evidence is accessibility-only, so spelling has no automated guard.

---

## Definition of done

- [ ] `bin/rails test` and `bin/rails test:system` green, nothing skipped
- [ ] `accessibility_test.rb` reports zero violations across all 12 screens
- [ ] Font resolves to a digested URL; zero third-party requests on load
- [ ] Reduced motion suppresses all motion; interface stays fully usable
- [ ] No scroll-triggered or page-transition animation anywhere
- [ ] Every screen clean at 360px with no horizontal page scroll
- [ ] FCP measured before and after, recorded in the PR, no regression
- [ ] Zero "LockerSwap" occurrences
- [ ] Every id in [contracts/preserved-dom.md](./contracts/preserved-dom.md) still present
