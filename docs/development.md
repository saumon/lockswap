# Development guide

## Localization

LockSwap is multilingual: **English** and **French** are both fully supported, with English as the
default on a fresh install. The language is a single, site-wide setting — not a per-user preference —
configured by an administrator from the **Danger Zone** screen
([`specs/025-multilingual-support/`](../specs/025-multilingual-support/spec.md)) and applied to every
visitor, signed in or not, on their very next page load.

* every user-facing string goes through Rails' own **I18n**, via `t()` in views — mostly the lazy
  `t(".…")` form, scoped to each view's own path — and `I18n.t()` in controllers and models; there is
  no hardcoded English literal left in a template, a flash message, or a validation error;
* two locale files, [`config/locales/en.yml`](../config/locales/en.yml) and
  [`config/locales/fr.yml`](../config/locales/fr.yml), are kept in lockstep, key for key. Devise's own
  strings (sign-in, sign-up, validation messages) are translated through the
  [`devise-i18n`](https://github.com/devise-i18n/devise-i18n) gem, and Rails/ActiveModel's own bundled
  messages through [`rails-i18n`](https://github.com/svenfuchs/rails-i18n) — this app's own
  `devise.en.yml`/`devise.fr.yml` carry only the handful of messages it deliberately overrides from
  either gem's defaults, such as the uniform sign-in failure message from feature 007;
* the active language is read **fresh on every request**, in an `ApplicationController` `around_action`
  that wraps the request in `I18n.with_locale(...)` rather than assigning `I18n.locale` directly — the
  block form is what keeps one request's language from leaking into the next request a reused Puma
  thread picks up. There is no caching layer: a language change saved from the Danger Zone is visible
  to every visitor on their very next request, and nobody has to sign out to see it;
* dates, times, and numbers deliberately **do not** change with the language: `fr.yml` pins
  `date`/`time`/`number` formatting back to the exact English values, overriding what `rails-i18n`
  would otherwise contribute for French, so a timestamp reads identically whichever language is
  selected — feature 032 adds one narrow, deliberate exception, a second fixed time format used only
  for the homepage's received-proposal timestamp, itself pinned identically in both languages rather
  than varying with the site's language the way it does not for any other date on the site;
* a dedicated test, [`test/i18n_completeness_test.rb`](../test/i18n_completeness_test.rb), diffs the two
  locale-file pairs directly and fails the suite if a key exists in English but has no French
  counterpart. That direct diff is the actual enforcement behind "every screen is fully translated" —
  `config.i18n.raise_on_missing_translations` alone only catches a string that was never extracted to
  a translation key in the first place, not one translated to English and left there.


## Tests and quality

```sh
bin/rails test         # models, controllers, views, and the single-breakpoint rule
bin/rails test:system  # end-to-end signup (password confirmation and reveal included), activation by email,
                       # password reset, email change, login, lockout, redirect,
                       # locker-details, wish, swap, notification, and admin flows,
                       # plus an accessibility audit of every screen, the reduced-motion behaviour,
                       # and a sweep of every screen at both a phone and a desktop viewport
bin/rubocop            # lint (zero warnings tolerated)
bin/brakeman           # static security analysis
```

CI replays all of it on every pull request ([`.github/workflows/ci.yml`](../.github/workflows/ci.yml));
a failure blocks the merge.

The accessibility audit runs as an ordinary system test, screen by screen, so a contrast failure or a
control that cannot be reached by keyboard breaks the build like any other regression. It carries one
documented exemption — the colour contrast of the brand wordmark, which the WCAG standard exempts as
a logotype — and that exemption is scoped to that one element and that one rule.

It has one blind spot worth naming: **no automated tool computes contrast over a gradient**, so the
white label on the accent buttons introduced in 021 passes the audit while measuring 1.87:1 at the
green end of its fill. That is a deliberate choice rather than an oversight, and it is the only thing
on the site below its bar — see feature 021 above, and the note on `--color-action-ink` in the
stylesheet, for the numbers and the two ways out.

Since 012 the same suite also drives the **viewport itself**, at a phone width and a desktop width,
and asserts the things that have to be true of every screen at both: that the page does not scroll
sideways, that the menu is in the treatment that width calls for, that the lists are in theirs, and
that every standalone control is a large enough target. It measures rather than assumes — the
assertion fails if it finds nothing to measure, because a check that quietly measures nothing passes
for ever.

One practical note: the system tests serve the **compiled** stylesheet. `bin/rails test:system`
rebuilds it for you, but running a single test file directly does not, so a stylesheet change that
has not been built will read as a failing assertion about the layout rather than as a missing step:

```sh
bin/rails tailwindcss:build && bin/rails test test/system/responsive_test.rb
```

`bin/dev` runs the watcher, so this does not come up while the app is running.


## Validate a feature by hand

Each feature ships a quickstart that walks through its acceptance scenarios by hand:

* [`specs/001-user-authentication/quickstart.md`](../specs/001-user-authentication/quickstart.md) —
  signup, login, the 30-day session, logout, the generic failure message, and the 15-minute lockout;
* [`specs/002-locker-floor-profile/quickstart.md`](../specs/002-locker-floor-profile/quickstart.md) —
  filling in a floor with and without a locker number, the rejected blank floor, a locker number
  already taken by someone else, and editing either value afterwards;
* [`specs/003-locker-search-wish/quickstart.md`](../specs/003-locker-search-wish/quickstart.md) —
  declaring a wish, the rejected blank floor, moving an existing wish to another floor, the list as
  other people see it, and cancelling;
* [`specs/004-locker-swap-proposal/quickstart.md`](../specs/004-locker-swap-proposal/quickstart.md) —
  proposing a swap, the refusals (yourself, a duplicate, someone already mid-swap), answering one
  either way, withdrawing, confirming the exchange and watching both lockers change hands (confirming
  is an administrator's step since 033 — see its quickstart below), and the history screen;
* [`specs/005-swap-lock-history-comment/quickstart.md`](../specs/005-swap-lock-history-comment/quickstart.md) —
  the edit control giving way while a proposal is outstanding, first-time details still accepted from
  someone who has none, the hold lifting once the swap is settled, and a history summary that stays
  put after both profiles have moved on;
* [`specs/006-locker-floor-uniqueness/quickstart.md`](../specs/006-locker-floor-uniqueness/quickstart.md) —
  the same locker number claimed on two different floors, the clash still refused on one and the same
  floor, moving a number to a free floor and being refused an occupied one, the vacated pair claimed
  by someone else, and the floor still required before any number is stored;
* [`specs/007-toast-notifications/quickstart.md`](../specs/007-toast-notifications/quickstart.md) —
  a confirmation arriving and leaving on its own, a refusal doing the same in its own colour,
  dismissing one by hand, the countdown holding while the pointer rests on it, two of them stacking,
  and the page underneath staying exactly where it was;
* [`specs/008-visual-identity-refresh/quickstart.md`](../specs/008-visual-identity-refresh/quickstart.md) —
  walking all twelve screens, the reduced-motion switch removing every animation while leaving the
  interface whole, no content waiting on a scroll to appear, the keyboard showing where it is
  throughout, nothing scrolling sideways at 360 px, the typeface loading without a flash of invisible
  text, and no request leaving for a third party;
* [`specs/009-locker-entry-pencil-edit/quickstart.md`](../specs/009-locker-entry-pencil-edit/quickstart.md) —
  entering a locker on first sight of the app, saying you have none and being asked for nothing but a
  floor, taking that back with the floor intact, the blank floor still refused on that path, the
  pencil opening the plain form pre-filled, and the explanation still taking the pencil's place while
  a swap is outstanding;
* [`specs/010-homepage-locker-wish-block/quickstart.md`](../specs/010-homepage-locker-wish-block/quickstart.md) —
  each of the three states on the account that produces it, the block absent entirely for an account
  that has filled in nothing, the wish appearing and disappearing on the homepage as it is declared
  and cancelled elsewhere, and the invitation still standing while a swap is outstanding;
* [`specs/011-logo-fade-loop/quickstart.md`](../specs/011-logo-fade-loop/quickstart.md) —
  the sign-in and sign-up logo doing its one-off entrance and then breathing on past it, the header
  mark breathing from first paint and still going after a navigation, the mark still clicking through
  to the homepage mid-fade, and the reduced-motion switch leaving both of them perfectly still;
* [`specs/012-responsive-layout-menu/quickstart.md`](../specs/012-responsive-layout-menu/quickstart.md) —
  narrowing the window through 768 px and watching the bar become a toggle and the lists become
  cards, the menu still opening and closing with JavaScript switched off, *Propose swap* on screen
  without a sideways swipe, and the two checks a headless browser cannot make: a form still usable
  with the on-screen keyboard up, and the page at 200% zoom;
* [`specs/013-admin-user-directory/quickstart.md`](../specs/013-admin-user-directory/quickstart.md) —
  signing up first on an empty instance and finding the Admin menu there, signing up second and
  finding nothing, the address refused when the second account types it anyway, the directory listing
  both accounts oldest first with the badge on one of them, and the administrator deleting their own
  account to watch the role pass to nobody — that last step is **superseded by 015**, which refuses
  the cancellation instead;
* [`specs/015-grant-admin-rights/quickstart.md`](../specs/015-grant-admin-rights/quickstart.md) —
  granting the role from the list and declining the confirmation first to watch nothing happen,
  signing in as the promoted account to find the menu there and grant the role onwards, the grant
  route refused for an account that never had the role, and the walk that proves the site keeps
  somebody in charge: administrators leaving one at a time until the last one is stopped, promoted
  somebody else, and then allowed to go — with the row they promoted still saying when it happened
  after they are gone;
* [`specs/014-confirmation-mot-de-passe/quickstart.md`](../specs/014-confirmation-mot-de-passe/quickstart.md) —
  signing up with the two passwords agreeing and then with them differing, the message staying away
  until the confirmation field is first left and clearing itself as the mistake is corrected, each eye
  revealing its own field and leaving the other alone, both fields masked again after a reload, and
  the toggle reached and worked from the keyboard;
* [`specs/016-danger-zone-email-domains/quickstart.md`](../specs/016-danger-zone-email-domains/quickstart.md) —
  listing a domain and watching a signup from anywhere else refused with the exact message while one
  from that domain goes through, lifting the restriction again by removing the last domain, the
  malformed and duplicate entries refused on the screen, a subdomain of a listed domain still refused
  until it is listed itself, an account whose domain is no longer allowed still signing in, and the
  screen and both of its write addresses refused to an account that is not an administrator;
* [`specs/017-locker-wishes-floor-filter/quickstart.md`](../specs/017-locker-wishes-floor-filter/quickstart.md) —
  narrowing on each floor in turn and then on both at once, clearing either one independently, the
  floors offered in numeric order with 10 last, somebody who has saved no floor of their own dropping
  out of the *Their floor* filter and coming back when it is cleared, a combination nobody satisfies
  saying so in its own words, a nonsense floor typed into the address, the filters surviving a save
  and a cancel of your own wish, and the two checks a headless browser makes awkwardly: moving across
  the choices with a keyboard without the list re-filtering, and the filter bar wrapping on a phone;
* [`specs/018-wishes-match-tag/quickstart.md`](../specs/018-wishes-match-tag/quickstart.md) —
  declaring a wish that reciprocates with someone else's and watching the tag appear on just that row,
  confirming it stays away with no wish of your own or no saved floor, confirming your own row never
  carries it, proposing a swap to a tagged row and watching the tag sit next to *Proposal pending*
  rather than disappear, the tag surviving a floor filter, and cancelling the wish to watch it go;
* [`specs/019-floor-filter-prefill/quickstart.md`](../specs/019-floor-filter-prefill/quickstart.md) —
  declaring a wish and watching *Their floor* narrow the list without touching it, leaving and
  returning (or simply reloading) to find it narrowed again, picking a floor by hand and watching it
  survive an unrelated filter change and the Back button before a genuine reload lets it go, changing
  the wish to move the filter with it even over a manual choice, a rejected change leaving it exactly
  as it was, cancelling to watch it fall back to *All floors* and stay there on the next visit, and
  *Looking for floor* left alone throughout;
* [`specs/020-admin-users-filters/quickstart.md`](../specs/020-admin-users-filters/quickstart.md) —
  reading each account's floor, locker and wish straight off the admin Users screen, narrowing by each
  filter alone and then combining several, an exact-match locker filter that ignores a matching
  substring, typing into the locker and email fields and watching the list settle a moment after
  typing stops, moving across the floor and role choices with a keyboard without the list re-filtering,
  a combination nobody satisfies showing its own message with every filter still visible, clearing a
  filter to watch the list widen back out, and granting administrator rights from a filtered list to
  find the same filters still applied on the way back;
* [`specs/022-align-floor-widgets/quickstart.md`](../specs/022-align-floor-widgets/quickstart.md) —
  reading the floor sought as one sentence on the homepage and on the locker wishes page, checking
  "Your locker" on a phone for one line per field against the desktop layout staying side by side,
  and confirming "Your locker" has no card border or background on the homepage while "Your locker
  search" above it keeps its own;
* [`specs/023-toast-redesign/quickstart.md`](../specs/023-toast-redesign/quickstart.md) —
  triggering a success and an error and telling them apart by icon and colour without reading the
  text, resizing and rotating the window to watch the bottom-right placement re-settle at both widths,
  shrinking the window's height to confirm nothing lands on a control about to be used, and firing
  several notifications in quick succession to watch the cap and the queue take over;
* [`specs/025-multilingual-support/quickstart.md`](../specs/025-multilingual-support/quickstart.md) —
  switching the Danger Zone's language setting and watching every screen, including one already open,
  follow it by the next page load, a fresh instance opening in English with nothing configured, a
  non-administrator finding no language control anywhere, and a date or a number staying in the same
  format regardless of which language is chosen;
* [`specs/026-locker-wish-expand-from-home/quickstart.md`](../specs/026-locker-wish-expand-from-home/quickstart.md) —
  pressing each homepage invitation and landing with the search zone already open and the cursor in
  Floor, reaching the same screen from the menu and finding it folded, reloading or going Back after an
  invitation to find the intention spent, and the person who already declared a search seeing nothing
  different;
* [`specs/027-admin-user-detail-view/quickstart.md`](../specs/027-admin-user-detail-view/quickstart.md) —
  clicking through from the Users list to one account's detail screen and finding the same address
  refused to a non-administrator, reading its floor, locker, standing search and full proposal history
  in one place, correcting its floor and locker from the pencil icon, cancelling its search behind a
  confirmation, and both actions leaving who did it and when on the screen afterward;
* [`specs/028-move-admin-grant-button/quickstart.md`](../specs/028-move-admin-grant-button/quickstart.md) —
  granting rights from the detail screen instead of the list, revoking them from that same screen
  behind the same plain confirmation, finding no revoke control anywhere on your own account, and
  watching a reverted account's grant history disappear rather than merely hide;
* [`specs/029-super-admin-role/quickstart.md`](../specs/029-super-admin-role/quickstart.md) —
  registering first on an empty instance and finding both admin rights and the Danger Zone, registering
  second and finding neither, a standard admin losing the Danger Zone entry from the menu and being
  refused the address directly, the super admin's badge and the Danger Zone still working exactly as
  before, and the one account that can never be cancelled while anyone else remains — until it is the
  only one left;
* [`specs/030-configurable-floors-locker-format/quickstart.md`](../specs/030-configurable-floors-locker-format/quickstart.md) —
  every floor field still free text before anything is saved, a floor list saved on the Danger Zone and
  cleaned up on the way in, each floor form turning into a choice from it in the order typed, a removed
  floor kept and marked rather than lost, a locker number format with its description refusing a number
  that does not follow it and accepting one that does, an invalid pattern refused with the old format
  still in force, and a granted administrator refused both settings;
* [`specs/031-locker-map-zones/quickstart.md`](../specs/031-locker-map-zones/quickstart.md) —
  declaring a zone with three locker numbers from the Locker Map, a duplicate zone name on the same
  floor refused and the same name accepted on another, a locker number already claimed by a different
  zone refused with that zone named, the screen itself refused to a standard account, an undeclared
  locker refused on both the self-service form and the admin editor, changing only the floor re-checking
  a pair whose locker number text never moved, and deleting a non-empty zone to watch its lockers go
  with it while an account already on one of them keeps displaying it but cannot re-save it;
* [`specs/032-locker-zone-visibility/quickstart.md`](../specs/032-locker-zone-visibility/quickstart.md) —
  declaring a zone for a locker and watching its name appear on the homepage, the locker search list, a
  received proposal, an exchange in progress, and both admin screens, an undeclared locker showing
  nothing extra on any of them, renaming the zone or removing the locker from it and watching every
  screen catch up on its next render with no separate step, and the swap-history screens confirmed to
  show none of it at all;
* [`specs/033-admin-swap-validation/quickstart.md`](../specs/033-admin-swap-validation/quickstart.md) —
  finding an accepted exchange in the Admin menu's Swap validations queue and validating it to watch both
  lockers change hands, refusing another with and without a reason and seeing nobody's locker move, both
  colleagues seeing *Awaiting validation* with nothing to press and the old confirm address
  answering 404, an exchange accepted before the upgrade showing up with no migration step, an
  administrator settling their own exchange, and a second administrator told the exchange was already
  decided;
* [`specs/034-email-confirmation-password-reset/quickstart.md`](../specs/034-email-confirmation-password-reset/quickstart.md) —
  signing up and finding the activation email in the development inbox, the right password refused
  until the link is followed, a resent email killing the previous link, the same answer for an unknown
  address, a password reset (mismatch, success, reused link, expired link, ending a lockout, activating
  an account), an email change confirmed from the new mailbox, and an administrator activating an
  account by hand.

