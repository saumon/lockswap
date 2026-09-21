# Quickstart: validating 026 — open the locker search on arrival from the homepage

How to prove this feature works, in the order that fails fastest. Implementation
belongs in `tasks.md`; this is the run-and-check guide.

## Prerequisites

```bash
bin/setup                 # once, if this tree has not been prepared
bin/rails db:test:prepare
```

A headless Chrome is needed for the system tests. If the only Chrome on the
machine is the one Selenium Manager downloaded (the common WSL case),
`test/application_system_test_case.rb` already resolves it; `CHROME_BIN` points
at a specific build if you need one.

---

## 1. The fast loop — the rule, without a browser

Everything about *when* the zone opens is a server-side fact: a redirect, a flash
entry, and whether the rendered `<details>` carries `open`. Run these first; they
are seconds, not minutes.

```bash
bin/rails test test/controllers/locker_wishes_controller_test.rb
```

**What must be true**

| Check | Requirement |
|---|---|
| `GET new_locker_wish_path` redirects to `locker_wishes_path` — the bare path, no query string | FR-003 |
| Following that redirect renders the declare disclosure with `open` | FR-004 |
| A plain `GET locker_wishes_path` renders it **without** `open` | FR-006 |
| A second `GET locker_wishes_path` straight after the intention-carrying one renders it without `open` | FR-002 |
| A viewer who already has a wish, arriving via `new_locker_wish_path`, gets the persisted panel with "Change floor" closed and no `autofocus` anywhere | FR-008 |
| An anonymous `GET new_locker_wish_path` is sent to sign-in and creates nothing | spec Edge Cases |
| Nothing was written: `LockerWish.count` is unchanged across all of the above | FR-012 |

**The regression half matters as much.** These existing tests in the same file
must still pass untouched — they are the evidence for SC-006 and for the
Principle IV measurement:

- `filtering issues no more queries than not filtering`
- `deriving current_floor from an active wish costs no extra queries`
- `rendering the list issues the same number of queries whether or not a match is present`
- the `current_floor` derivation group (`a fresh request with no current_floor param…` onwards)

---

## 2. The journeys — browser, kept deliberately small

```bash
bin/rails test:system test/system/locker_wish_entry_test.rb
```

Three click-throughs, no more (research R8 explains why the count is capped):

| Scenario | Fixture | Asserts |
|---|---|---|
| "I want a locker! 🙏" → open + focused | `erin` (floor 5, no locker, no wish) | FR-004, FR-005 |
| "I want to switch my locker! 👀" → open + focused | `dave` (floor 4, locker D07, no wish) | FR-004, FR-005 |
| The same at phone width, inside `with_viewport(:phone)` | `erin` | FR-015 |

Focus is checked by asking the browser, not by inspecting markup:

```ruby
assert_equal "locker_wish_floor",
  page.evaluate_script("document.activeElement.id")
```

Then, on the same opened screen:

- `assert_axe_clean` — Principle III's accessibility gate.
- Type a floor and submit without touching anything else; the wish is saved
  (FR-007, spec US1 scenario 3).
- Reload, and assert the disclosure is folded and `document.activeElement` is the
  body (FR-002, spec US1 scenario 5).

**Use `wait_for_turbo` after the click, and assert on content, never on
`assert_current_path`.** The address is by design the same one the menu produces,
so it says nothing about whether the feature worked. `test/system/homepage_locker_wish_test.rb`
carries a header comment about three tests deleted for exactly this click-through
flake — read it before adding a fourth.

---

## 3. The regression sweep

```bash
bin/rails test:system test/system/locker_wish_test.rb
bin/rails test:system test/system/homepage_locker_wish_test.rb
```

**`locker_wish_test.rb` is Story 2's evidence and must pass unchanged.** Its
first test — "the wish page asks which floor only once the button is clicked" —
reaches the screen through the menu and asserts the field does not exist yet.
That test failing means this feature leaked the open state onto every arrival,
which is the exact failure mode Story 2 exists to catch. Do not adjust it.

**`homepage_locker_wish_test.rb` needs one line changed**, at `:185`: the href
assertion inside "an active swap proposal does not change the block" becomes
`new_locker_wish_path`. Nothing else in that file should move — in particular
"every state offers exactly one control and no form" must still pass, since the
invitations stay links.

**`access_control_test.rb` is not touched.** That file covers screens an
anonymous visitor could open; `/locker_wish/new` renders nothing, and what
matters about it is a redirect chain — so the anonymous case sits in the
controller test (§1), beside the other anonymous locker-wish cases.

---

## 4. The gates

```bash
bin/rails test test/i18n_completeness_test.rb     # expect: no change, no new key
bin/rails test test/stylesheet_breakpoint_test.rb # expect: no change, no media query added
bin/rubocop
bin/rails tailwindcss:build                        # only if the stylesheet was touched — it should not be
```

Then the whole suite:

```bash
bin/rails test && bin/rails test:system
```

---

## 5. Look at the page

Tests are not enough for design (CLAUDE.md). Per its recipe: write a throwaway
system test under `test/system/`, log in as `erin`, `visit new_locker_wish_path`,
`wait_for_entrance`, `page.save_screenshot` into `tmp/design/`, run it, read the
image, delete the test. Repeat inside `with_viewport(:phone)`.

**What to look for, and why each is a real hazard here**

1. **The open disclosure does not shove the wish list off the fold.** The panel
   sits above the list; an open form pushes the list down. If the person cannot
   see that a list exists, the screen has become a form and stopped being the
   page the product is about.
2. **The focus ring is on the Floor field and is visible.** The shared
   `:focus-visible` ring must be intact — removing an outline without restoring
   it is one of CLAUDE.md's enforced rules. A field focused with no visible ring
   is worse than no focus at all.
3. **Nothing sits behind the frosted bar.** If the page did scroll, the
   `scroll-padding-top` at `application.css:348` should have cleared it. Sample
   the screenshot rather than eyeballing it if it looks close.
4. **The entrance still completes inside its budget** and the field is focused
   from the first frame, not after the animation. This feature adds no animation;
   if the page suddenly feels slower, something was added that should not have
   been.
5. **At phone width, the field is above the on-screen keyboard.** The emulator
   will not raise a keyboard, so this one is a judgement call from the
   screenshot plus a check on a real device if one is at hand.

---

## Done when

- [ ] Controller tests cover every rule in §1, and fail on a tree without the route
- [ ] Three browser tests cover the two journeys and phone parity; focus asserted via `document.activeElement`
- [ ] `locker_wish_test.rb` passes **unchanged** — Story 2's regression guard
- [ ] `homepage_locker_wish_test.rb:185` updated; nothing else in that file moved
- [ ] The anonymous case is covered in the controller test, with a comment saying why it is not in `access_control_test.rb`
- [ ] i18n, breakpoint and rubocop gates clean; no new locale key, no new media query
- [ ] Screenshots read at both widths, against the five points in §5
