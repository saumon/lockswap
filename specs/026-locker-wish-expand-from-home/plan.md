# Implementation Plan: Open the locker search on arrival from the homepage

**Branch**: `026-locker-wish-expand-from-home` | **Date**: 2026-09-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/026-locker-wish-expand-from-home/spec.md`

## Summary

The homepage's two invitations to declare a locker search ("I want a locker! 🙏",
"I want to switch my locker! 👀") currently land on `/locker_wishes` with the
declare form folded away, so the person has to ask a second time for the thing
they just pressed a button to get. This feature makes those two arrivals — and
only those two — open the "I'm looking for a locker" disclosure and put the
cursor in the Floor field.

The approach is a **flash-backed, redirect-normalised intention**: the two links
point at a new `GET /locker_wish/new`, which sets one flash entry and redirects
to the bare `locker_wishes_path`. The flash is readable by exactly one
subsequent request and swept after it, which is the spec's "spent by one arrival"
(FR-002); the redirect means the address the person ends on is byte-identical to
the menu's, which is the spec's "address unchanged" (FR-003). The index render
turns that flash into `<details open>` and an `autofocus` on the floor field, in
the same response — which turbo-rails 2.0.23 requires, since its autofocusable
filter explicitly skips anything inside `details:not([open])` (research R3).

No new model, no new column, no JavaScript, no new user-facing string.

## Technical Context

**Language/Version**: Ruby 3.4.6, Rails 8.1.3.1

**Primary Dependencies**: turbo-rails 2.0.23 (autofocus-on-render; verified in
the vendored asset, research R3), stimulus-rails 1.3.4 (not used by this
feature), Devise, importmap-rails, tailwindcss-rails 4.6.0

**Storage**: SQLite via Active Record. **This feature adds no schema change and
no migration.** The one piece of state it introduces lives in the Rails flash,
i.e. the session cookie, for exactly one request.

**Testing**: Minitest — `test/controllers/locker_wishes_controller_test.rb` for
the rule, `test/system/` (Capybara + headless Chrome + axe) for the two journeys
and the accessibility evidence. `test/i18n_completeness_test.rb` and
`test/stylesheet_breakpoint_test.rb` run as always; neither should have anything
new to say.

**Target Platform**: Server-rendered web, one light theme, one breakpoint at
48rem. Desktop and phone treatments are the same behaviour here (FR-015).

**Project Type**: Rails MVC monolith (single project).

**Performance Goals**: Unchanged. The index action gains one flash read and zero
queries; the existing query-count assertions in the controller test are the
before/after evidence (research R7). The new `#new` action renders nothing.

**Constraints**: FR-003 — the address must stay indistinguishable from the
menu's, which rules out a query parameter or a fragment. FR-014 — focus must land
clear of the sticky header, already handled by `html { scroll-padding-top }` at
`app/assets/tailwind/application.css:348`. Motion budget untouched: this feature
adds no animation.

**Scale/Scope**: Two view files, one controller, one route, one locale-free
change. Roughly 15 lines of application code and a comparable weight of comment,
plus tests.

## Constitution Check

*GATE: passed before Phase 0. Re-checked after Phase 1 — see the bottom of this
section.*

### I. Code Quality

| Obligation | How this plan meets it |
|---|---|
| Lint clean | `bin/rubocop` over the touched files. No suppressions anticipated. |
| Single responsibility | `#new` does one thing: record the intention and send the person where the form lives. The index action gains one line. |
| No duplicated logic | FR-008 is enforced **once**, by the view branch that already exists, not also by a `persisted?` check in the controller (research R6). |
| Public interfaces documented | `_locker_wish_form.html.erb` gains a strict-locals declaration naming its new `autofocus` local, so its interface is stated at the partial. Every new rule carries its reasoning at the site, per CLAUDE.md. |

### II. Testing Standards (NON-NEGOTIABLE)

Tests fail without the change and pass with it — specifically, the controller
test asserting `details[open]` after the redirect fails today because no such
route exists.

Determinism is the live risk, not coverage. `test/system/homepage_locker_wish_test.rb`
records three tests deleted for exactly the flake this feature's Story 1 invites:
click the homepage control, assert what came next. Research R8 sets the four
mitigations, the most important being that the rule is proved in controller
tests and the browser is asked only for what only a browser can answer (focus
landed; focus landed at phone width too). No coverage regression: the feature
adds behaviour and tests for it, and removes none.

### III. User Experience Consistency

| Obligation | How this plan meets it |
|---|---|
| Reuse existing patterns | The disclosure, the form, the summary, the field, the hint and the submit control are all the ones already on screen (FR-007). No second treatment is introduced. |
| Accessibility verified | `assert_axe_clean` on the opened screen. `<details>` keeps its native keyboard and screen-reader semantics; the focused field is announced with its own `<label>` and its `aria-describedby` hint, both already present. |
| Breaking changes called out | One, and it is internal: the two homepage links change `href` from `/locker_wishes` to `/locker_wish/new`. `homepage_locker_wish_test.rb:185` asserts that href and must be updated. Nothing a user can see changes about the links. |
| i18n coverage | **No new user-facing string.** The gate still runs; it should report no change. If implementation somehow needs copy, both locale files get it. |

### IV. Performance Requirements

No measurement invented, and none needed (research R7): the index render gains
no query, the new action runs none beyond the session load, and the extra round
trip is on a human-initiated navigation rather than a swap/lock path. The
existing query-count assertions must still pass unchanged — that is the evidence.

### Post-Phase-1 re-check

Re-evaluated after the contract and quickstart were written. No gate moved.
The design introduces no new component, no new string, no new query, no new
animation and no JavaScript, so the three gates that usually bite a UI change
(consistency, i18n, motion budget) have nothing to bite. The Complexity Tracking
table below is empty because there is nothing to justify.

## Project Structure

### Documentation (this feature)

```text
specs/026-locker-wish-expand-from-home/
├── plan.md              # This file
├── spec.md              # Feature specification (clarified 2026-09-21)
├── research.md          # Phase 0 output — R1..R8
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── checklists/
│   └── requirements.md  # Spec quality checklist, 16/16
├── contracts/
│   └── locker-wish-entry.md   # Phase 1 output — the route + render contract
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source code (repository root)

```text
config/
├── routes.rb                              # + :new on `resource :locker_wish`
└── locales/{en,fr}.yml                    # unchanged — no new string

app/
├── controllers/
│   └── locker_wishes_controller.rb        # + #new; #index reads the flash
└── views/
    ├── home/
    │   └── _locker_wish.html.erb          # two links repointed at new_locker_wish_path
    └── locker_wishes/
        ├── _locker_wish_panel.html.erb    # the declare <details> opens on the flag
        └── _locker_wish_form.html.erb     # + strict-locals `autofocus:` on the floor field

test/
├── controllers/
│   └── locker_wishes_controller_test.rb   # the rule: redirect, flash, open/folded, FR-008
└── system/
    ├── locker_wish_entry_test.rb          # NEW — the two journeys, focus, phone, axe
    └── homepage_locker_wish_test.rb       # href assertion at :185 updated; US3 href added
```

**Structure Decision**: The existing Rails MVC layout, unchanged. The feature is
one controller action, one route and three view edits; there is no new layer to
place and nothing that wants a service object. `#new` belongs on
`LockerWishesController` because `resource :locker_wish` already routes there and
the action's `authenticate_user!` then comes from the `before_action` that is
already on the class.

## Key design decisions

Each is argued in full in [research.md](./research.md); this is the index.

1. **Flash + redirect, not a query parameter** (R1). The clarify pass reversed
   the specify pass's assumption here, and the redirect is what buys FR-003.
2. **A custom flash key renders nothing** (R2). `layouts/_flash.html.erb` reads
   `notice` and `alert` by name and never iterates the hash, so
   `flash[:open_wish_form]` is invisible to the toast layer. It must **not** be
   added to `add_flash_types`.
3. **`open` and `autofocus` must ship in the same response** (R3). Turbo's
   autofocusable filter skips `details:not([open])`. This is the single detail
   most likely to be broken by a later "improvement" that opens the disclosure
   from script.
4. **FR-008 is enforced by the view branch, not twice** (R6). The declare
   disclosure only exists for a viewer with no wish, so the guard is structural.
5. **`autofocus` is a partial local, not an instance variable** (R6). The form
   partial serves both the declare and the "Change floor" call sites; passing the
   flag in keeps the two from having to know about each other.
6. **The browser is asked only what only it can answer** (R8). The redirect, the
   flash and the rendered `open` attribute are all server-side facts and belong
   in controller tests, away from the click-through flake this file's history
   already documents.

## Risks

| Risk | Mitigation |
|---|---|
| The Story 1 system tests re-enter the documented click-through flake (R8). | Prove the rule in controller tests; keep browser tests to the three that need focus. Use `erin` and `dave`, whose homepages fit the viewport. `wait_for_turbo` after the click. Assert on content, never on `assert_current_path` — the address is deliberately the same as the menu's. |
| Someone later opens the disclosure from JavaScript and silently loses focus (R3). | The reason lives in a comment at the `autofocus` attribute, where it will be read by whoever is about to move it. |
| The flash key is later rendered as a toast by a well-meaning change to `_flash.html.erb`. | Keep it out of `add_flash_types`, and name it for what it does (`open_wish_form`) rather than for a message. |
| The anonymous case lands in the wrong file. | `test/system/access_control_test.rb` covers *screens* an anonymous visitor could open; `/locker_wish/new` renders nothing, and what matters about it is a redirect chain. It goes in the controller test beside the other anonymous locker-wish cases, with a comment saying why. |
| A reviewer reads the extra redirect as waste. | It is the mechanism, not overhead: it is what makes the final address indistinguishable from the menu's. Recorded in R1 with its cost stated. |

## Complexity Tracking

No Constitution Check violations. Nothing to justify.
