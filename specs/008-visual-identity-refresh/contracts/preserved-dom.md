# Contract: Preserved DOM Surface

**Feature**: [../spec.md](../spec.md) | **Date**: 2026-09-14

FR-015a grants freedom to restructure layouts. This contract is the boundary of that freedom.

Everything listed here is depended on by the existing test suite, by assistive technology, or by both. It survives the refresh unchanged. Everything *not* listed — every CSS class, every wrapper `<div>`, every ordering and grouping decision — is free to change.

Audited across `test/system/*.rb` and `test/controllers/*.rb`. **The suite references zero CSS classes**, which is what makes restyling safe and restructuring tractable.

---

## 1. DOM ids — must survive

Referenced directly by `assert_selector`, `within`, or `find`.

| id | Template |
|---|---|
| `error_explanation` | `devise/shared/_error_messages.html.erb` |
| `locker-profile` | `home/_locker_profile.html.erb` |
| `locker-profile-floor` | `home/_locker_profile.html.erb` |
| `locker-profile-locker-number` | `home/_locker_profile.html.erb` |
| `locker-profile-locked` | `home/index.html.erb` |
| `locker-wish-panel` | `locker_wishes/_locker_wish_panel.html.erb` |
| `locker-wish-floor` | `locker_wishes/_locker_wish_form.html.erb` |
| `locker-wish-list` | `locker_wishes/_locker_wish_list.html.erb` |
| `locker-wish-list-empty` | `locker_wishes/_locker_wish_list.html.erb` |
| `swap-exchange-in-progress` | `home/_swap_exchange_in_progress.html.erb` |
| `swap-proposals-received` | `home/_swap_proposals_received.html.erb` |
| `swap-proposals-sent` | `home/_swap_proposals_sent.html.erb` |
| `swap-proposals-declined` | `home/_swap_proposals_declined.html.erb` |
| `swap-proposal-history` | `locker_swap_proposals/index.html.erb` |
| `swap-proposal-history-empty` | `locker_swap_proposals/index.html.erb` |

### Generated id patterns — must survive, including suffixes

| Pattern | Template |
|---|---|
| `locker-wish-row-<user.id>` | `locker_wishes/_locker_wish_list.html.erb` |
| `locker-wish-row-<user.id>-person` | ″ |
| `locker-wish-row-<user.id>-floor` | ″ |
| `locker-wish-row-<user.id>-current-floor` | ″ |
| `locker-wish-row-<user.id>-current-locker` | ″ |
| `swap-proposal-history-row-<proposal.id>` | `locker_swap_proposals/index.html.erb` |
| `swap-proposal-history-row-<proposal.id>-locker-details` | ″ |
| `swap-proposal-history-row-<proposal.id>-comment` | ″ |

The `-locker-details` and `-comment` suffixed elements are used as `within` scopes, so they must remain **containers** of their text, not siblings of it.

Also preserved: `locker_number_hint`, `locker_wish_floor_hint`, `password_hint` — these are `aria-describedby` targets. Breaking them breaks screen-reader help text, which the new accessibility suite will catch.

---

## 2. Elements and roles — must survive

| Requirement | Why |
|---|---|
| `<main>` element | `notification_test.rb` measures `find("main").native.rect` before and after a flash and asserts the rectangle is **identical**. The flash overlay must therefore stay `position: fixed` and take no layout space. |
| `[role=status]` on notices, `[role=alert]` on alerts | Asserted directly; also how the messages reach screen readers. |
| `<details>` / `<summary>` disclosures | `find("summary", text: "Edit locker details")` and `find("summary", text: "Decline")`. Keep them native disclosures — they are already the accessible, JS-free choice and the existing view comments say so. |
| `data-turbo-temporary` on the flash container | Keeps a spent message out of Turbo's page cache. |
| Stimulus wiring on notifications | `data-controller="notification"`, the duration value, and the four `mouseenter`/`mouseleave`/`focusin`/`focusout` actions. Feature 007's behaviour is explicitly out of scope for change. |

---

## 3. Submit controls — must remain `<input type="submit">`

Two assertions match on the element type *and* its `value`:

```ruby
assert_selector "input[type=submit][value='Save locker details']"
assert_selector "input[type=submit][value='Save my wish']"
```

Converting these to `<button>` breaks both tests. Keep `f.submit`; style it with a component class.

> This is the one place where the component contract bends to the markup rather than the reverse: the primary button treatment must be expressible on an `<input>`, which means **no pseudo-elements and no child elements** in the primary button style. Spinners and icons inside buttons are therefore out for these two controls.

---

## 4. Field labels — must survive

`fill_in` matches on label text, so these strings and their label-to-input association are fixed: **Email**, **Password**, **Floor**, **Why? (optional)**.

Field `name` attributes are asserted directly: `user[floor]`, `user[locker_number]`, `locker_wish[floor]`.

---

## 5. Accessible names of controls — must survive

`click_on` matches visible text (this project does **not** enable `Capybara.enable_aria_label`, so an `aria-label` alone will not match):

**LockSwap** · Locker wishes · Proposal history · Log out · Log in · Create account · Save locker details · Save my wish · Cancel wish · Propose swap · Accept · Withdraw · Confirm decline · Confirm exchange completed

> **The brand link must keep the visible text "LockSwap".** This is the single constraint that decides the logo architecture: the header brand is a mark plus *live text*, never an image alone. See [../research.md](../research.md) D6.

---

## 6. Body text — must survive verbatim

FR-015 forbids rewording, and these are asserted directly. Non-exhaustive but load-bearing:

"Welcome to LockSwap" · "Your swap proposals" · "Everyone looking for a locker" · "Proposal pending" · "Exchange confirmed" · "You already have an exchange in progress" · status labels **Proposed / Received / Sent / Declined / Withdrawn / Completed / Exchanged** · locker summaries in the exact form `Floor 3, locker B12` and `Floor 2, no locker assigned` · all validation messages ("Email can't be blank", "Password must be at least 8 characters long.", "Locker number is not available on that floor", …) · all flash messages ("Signed out successfully.", "Swap proposal sent.", …).

---

## 7. The one permitted addition

The brand tagline **"Find the locker that suits you"** on the sign-in and sign-up pages (FR-003a). It carries no control and no behaviour. Nothing else may be added.

---

## Verification

`bin/rails test:system` passing is the check. A test that fails here has caught a contract breach — fix the template, not the test. Where a test genuinely must change because structure moved, FR-029 requires it be **updated to assert the same behaviour**, never deleted or weakened.
