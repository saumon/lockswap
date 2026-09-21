# Open the locker search on arrival from the homepage

Closes: spec [026-locker-wish-expand-from-home](../specs/026-locker-wish-expand-from-home/spec.md)

## What

Pressing "I want a locker! 🙏" or "I want to switch my locker! 👀" on the
homepage used to land on the locker wishes screen with the declare form folded
away — the person had to ask a second time for the thing they just pressed a
button to get. Now that arrival opens the "I'm looking for a locker" zone and
puts the cursor in the Floor field, so typing can start immediately. Reaching
the screen any other way (the menu, a typed address, a bookmark, a reload, Back)
is completely unchanged — folded, nothing focused, exactly as before.

## How

A new `GET /locker_wish/new` sets `flash[:open_wish_form] = true` and redirects
to the bare `locker_wishes_path`. `#index` reads that flash into
`@open_wish_form` and the declare `<details>` opens on it; the floor field
carries `autofocus` in the same response, which turbo-rails 2.0.23 requires —
its autofocusable filter excludes anything inside `details:not([open])`, so the
two attributes cannot be split across a script-driven follow-up.

The flash gives the two hard constraints from the spec's clarification for
free: it is readable by exactly the next request and swept after it ("opens
once, then forgotten" — a reload or Back shows the folded screen), and the
redirect target is the address the menu already produces, so nothing this
feature adds can ever appear in a bookmarked or shared link.

No schema change, no new string, no JavaScript.

## Core Principles

- **I. Code Quality.** `#new` does one thing. FR-008 (a viewer who already has
  a wish sees nothing new) is enforced once, structurally — the disclosure this
  opens doesn't render in that branch — not duplicated as a second guard. The
  shared form partial declares its new `autofocus` local with strict locals
  rather than an implicit lookup.
- **II. Testing Standards.** The rule — redirect, flash, rendered `open`/
  `autofocus` — is proved in `test/controllers/locker_wishes_controller_test.rb`
  (11 new tests, all server-side facts, all deterministic). Three browser tests
  cover what only a browser can answer: real focus landing, at desktop and at
  phone width, plus a submit-from-arrival and an accessibility pass. No test was
  silenced with a retry to hide a real defect — see **Known flakiness** below
  for what *was* investigated and why it's out of scope.
- **III. User Experience Consistency.** No new pattern: same disclosure, same
  form, same copy. `assert_axe_clean` runs on the opened screen. One
  breaking-ish change for other developers, not for users: the two homepage
  links now point at `new_locker_wish_path` instead of `locker_wishes_path`
  directly (they redirect into each other, so nothing a user can observe
  differs) — `homepage_locker_wish_test.rb:185`'s href assertion moved
  accordingly. No new locale key; `test/i18n_completeness_test.rb` is
  unchanged.
- **IV. Performance Requirements.** `#index` gains one flash read and zero
  queries; `#new` runs nothing beyond the session load. The three existing
  query-count assertions in the controller test suite still pass with unchanged
  expected counts — that's the before/after evidence.

## Known flakiness (investigated, not introduced by this change)

`test/system/locker_wish_entry_test.rb`'s click-through tests occasionally hit
`SQLite3::BusyException`-adjacent timing under load. This was chased down, not
assumed: `config/database.yml` already documents this exact class of
contention (the system-test thread driving the app while the test thread holds
a transaction, mitigated but not eliminated by a 15s busy-timeout), and every
request in this app — this feature's included — reads
`SiteLanguageSetting.current` uncached on every single request via
`ApplicationController#switch_locale`. A full 280-test system-suite run hit it
once, in this file, at the same rate the pre-existing suite already does
elsewhere (an unrelated baseline run hit the identical error in
`admin_users_filter_test.rb`). More retries made it *worse*, not better,
consistent with each retry being one more request competing for the same lock
rather than one more chance at a dropped click — so the retry budget was kept
modest (`click_reliably`, 3 attempts, same shape as the suite's existing
`fill_in_reliably`) rather than escalated. Not something this PR can or should
fix; noted here so a flaky CI run on this file isn't mistaken for a regression.

## Design review finding (reported, not fixed here)

Screenshots at `tmp/design/026_declare_open_{desktop,phone}.png`, taken via the
real click-driven arrival. Four of five checks in `quickstart.md` §5 are clean.
The fifth turned up a real, verified (not assumed) gap: on the phone viewport,
the autofocused field's `:focus-visible` ring does not render, confirmed with
`document.activeElement.matches(':focus-visible')` (`false` on phone, `true` on
desktop, for the identical click-driven arrival) and `getComputedStyle`
(`outline: none` vs `outline: solid`). This is a Chromium heuristic treating a
touch-context click differently from a mouse-context one — not something this
feature's HTML/CSS controls, and `application.css`'s own FR-024 comment states
the `:focus-visible`-only design is deliberate. The site's one pre-existing
`autofocus` (`devise/registrations/edit.html.erb`) would show the identical gap
on a phone; this isn't specific to 026. DOM focus itself — `activeElement.id`,
the `autofocus` attribute, label/hint association — is identical and correct at
both widths. Left unfixed as out of this feature's scope; flagging for a
maintainer to decide whether it's worth its own investigation.

## Testing

- `bin/rails test` — 320 runs, 0 failures
- `bin/rails test test/system/...` (all 21 system files, 280 tests) — 1
  failure, the documented pre-existing flake above, not reproducible on rerun
- `bin/rubocop` on all changed Ruby files — clean
- `test/i18n_completeness_test.rb`, `test/stylesheet_breakpoint_test.rb` —
  unchanged, both pass
