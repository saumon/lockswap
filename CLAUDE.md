# LockSwap — design contract

This file exists so a new session does not restart from a generic SaaS default.
Everything below was decided deliberately, most of it against a measurement.
Change it if there is a reason; do not drift into it by accident.

The implementation is `app/assets/tailwind/application.css`. That file carries
the reasoning at the site of each rule and is the source of truth for values —
this file is the contract, and says what must stay true and why.

---

## The one idea: the swap axis

The logo is two lockers, one blue and one green, changing places along circular
arrows. That is the only idea this interface is built on, and the two colours
carry a fixed meaning everywhere. They are never spent on decoration.

| token | meaning |
|---|---|
| `--color-rail-you` `#0A77F1` | what is the reader's: their locker, their wish, their row, a proposal they sent |
| `--color-rail-them` `#0AB486` | somebody else's: the pool, their offer, a proposal received |
| `--color-rail-system` `#0A1F38` | neither — shells, reference, read-only |
| `--color-rail-alert` `#9F1239` | destructive |

Where it shows up:

- **Cards are hung on a 3px hinge** down the leading edge, coloured from the
  axis (`.card--you` / `.card--them` / `.card--alert`, navy by default). This
  replaces the drop shadow — an identical soft grey shadow under every card is
  exactly what makes a page of cards read as one undifferentiated mass. Cards
  have a border, a hinge, and no shadow.
- **Data rows carry a 2px leading rail**, green on hover, and permanently
  coloured where the row has a side (`data-rail="you"` / `"them"`). Below the
  breakpoint the row becomes a card and the rail becomes its edge.
- **Page titles** carry the axis as a gradient, blue at the top to green at the
  bottom — a page belongs to neither side, it is where the two meet.
- **The hairline under the header** runs blue to green, left to right.

Colour is never the only signal. Every rail is doubled by words on screen
("This is you", a Direction column reading Sent/Received) and every badge
carries a text label.

---

## Palette

Six colours carry the site. Every pair in use has a computed contrast ratio
written next to it in the stylesheet — ratios are computed, never estimated.

```
--color-ink          #0A1F38   16.11:1   text, structure
--color-ink-muted    #50607A    6.36:1   secondary text
--color-accent       #07795A    5.40:1   green TEXT (never a fill)
--color-link         #0A5AC2    6.45:1   link text, focus ring
--color-canvas       #F4F7FA             page ground, carries the grid
--color-surface      #FFFFFF             cards and panels
```

Plus the four status pairs (`success` / `error` / `info` / `neutral`, each a
text colour on a tint, each ≥ 4.5:1) and the brand colours, which reproduce the
logo and are **not** a general-purpose palette.

`--color-brand-green` `#0AB486` is 2.66:1 on white. It is legal in the wordmark
only because WCAG 2.1 SC 1.4.3 exempts a brand name. Green **text** anywhere
else is `--color-accent`.

### The accent fill

One fill for every action on the site — the primary button, the row action, and
the filter choice in force are the same object at two sizes. There is no second
treatment; do not invent one.

It is the swap axis as a gradient, and both ends are lifted from the mark
itself: `#3499FD` is the top stop of the blue door's own gradient in
`shared/_brand_mark`, `#41D5A5` is the green door's face.

The image is declared **blue → green → blue** at `background-size: 200%`, so
half is visible at a time: at rest blue → green, on hover the window slides and
shows green → blue. The control does not brighten or move — **it reverses**. On
a product about two people exchanging places that is the only hover it should
have.

> **Known exception.** `--color-action-ink` is `#FFFFFF`, which measures 2.95:1
> on the blue end and 1.87:1 on the green, against a 4.5:1 bar. It was set white
> by explicit instruction; ink (`#0A1F38`) measures 5.62:1 and 8.91:1 on the
> same ramp. This is the only thing in the stylesheet below its bar. The two
> ways out are in the token's comment. If an audit flags one thing, it is this.

---

## Typography

Two families, two jobs. Both self-hosted from `app/assets/fonts`, one variable
file each, latin subset, SIL OFL.

- **Nunito** — the logo's own face. Everything *written*: headings, prose,
  labels. Tight tracking (−0.02 to −0.03em) at display sizes.
- **JetBrains Mono** — everything *measured*: floor numbers, locker numbers,
  e-mail addresses, dates, table column headings, filter chips and all buttons.
  Tabular figures, so a column lines up on the digit.

The contrast between the two — rounded humanist against rigid mono — is the
typographic idea. Neither family does the other's job anywhere.

Measured values in a table get `.data-value` per cell, opted in, because a cell
holding prose or a control is not a measurement. Buttons are `--font-mono` at
`--text-label`, `.btn-sm` at `--text-data` so it matches a filter chip exactly.

**No uppercase anywhere.** No eyebrows.

---

## The chrome

- **The header is frosted glass**: `--color-bar` (white at 58%) over
  `--color-bar-blur` (`blur(24px) saturate(180%)`), sticky at the top. It is the
  page's one translucent surface.
- **The menu panel is the same material**, and full width on a phone — one
  surface continuing the bar downwards, no radius, no side borders.
- **The canvas is not blank**: a navy grid at 5%, 24px pitch, the locker bank
  the product is about.

### Three couplings that break silently

1. **`backdrop-filter` on the header must stay on `.site-header::before`.** An
   element with a backdrop-filter becomes a *Backdrop Root*: its descendants'
   own backdrop-filters stop seeing the page. With the filter on `.site-header`,
   the menu panel declared a blur and rendered a flat tint. Moving it "back to
   where it belongs" reintroduces that bug.
2. **`--size-bar` is the bar's published height**, and three rules depend on it
   agreeing: `.site-nav { min-height }` fixes the bar to it rather than letting
   the tallest control decide, and both `html { scroll-padding-top }` and
   `.toast-layer { top }` clear it. Change one without the others and a toast,
   or anything the keyboard scrolls into view, lands behind the glass.
3. **The menu panel sits at `z-index: 60`, above the toast layer's 50.** A toast
   may cover the closed chrome; it may not land in the middle of an open menu.

---

## Layout

- One column, `max-width: 68rem`, left-aligned. Headings flush left.
- **Page titles live outside cards**, on the canvas, in `.page-head`.
- Card padding is `--spacing-5` (24px). Radii are tight: 12px at the largest. A
  20px corner is the most generic thing a card can do.
- Prefer intrinsic responsive layout (`flex-wrap`, `auto-fit`/`minmax`) over
  media queries.

> **Do not put content side by side if both columns contain controls.**
> `assert_tab_order_follows_visual_order` compares strictly top-then-left with
> 24px of tolerance, so two cards side by side whose controls sit at different
> heights fail it. This is why the homepage is a single column despite the room.

---

## Motion

Budget, from 008's FR-019: **interaction settles in 200ms, the page entrance
completes in 400ms.** The entrance chain is exactly at its bound — a 160ms
stagger plus a 240ms rise — so nothing may be added to it without shortening
`--motion-stagger`.

- The page fades; its blocks rise 10px, staggered 40ms apart; each card's hinge
  is drawn downwards. The fade and the rise are deliberately split so the two
  opacities never multiply.
- Rows and chips transition colour only. Buttons lift on hover and press with
  `scale(0.97)`.
- **Animate transform and opacity only.** Two exceptions exist, each documented
  at its own rule: the brand mark's one-off blur, and the accent fill's
  `background-position` sweep. Both are single small elements, on interaction or
  once per page, never during scroll. Do not add a third casually.
- Entrance animations are declared **only inside
  `@media (prefers-reduced-motion: no-preference)`**, never flattened by
  duration alone — an animation starting at `opacity: 0` and relying on
  fill-mode is one stalled frame away from invisible content.

---

## Rules that are enforced, not just preferred

- **No raw hex in a template.** A colour in an ERB file is a defect; add a token.
- **One breakpoint, 48rem** (and `47.999rem` for its exclusive complement). No
  other width may appear in a media query — `test/stylesheet_breakpoint_test.rb`
  reads the stylesheet as text and fails on anything else.
- **`.btn-primary` must work on `<input type="submit">`.** No pseudo-elements, no
  child elements, no icon slots, no spinner. Two system tests match that element
  by its `value`. `.btn-arrow`'s `::after` is scoped to `a.btn-arrow` for this
  reason.
- **One definition per component.** A second rule for the same element is a
  defect; edit the first.
- **Never remove a focus outline** without putting the shared `:focus-visible`
  ring back.

---

## How to check the work

Tests are not enough for design; look at the page.

- `bin/rails tailwindcss:build` after every stylesheet change.
- To see a screen, write a throwaway system test under `test/system/` that logs
  in, visits, calls `wait_for_entrance`, and `page.save_screenshot`s to
  `tmp/design/`; run it, read the image, delete the test. `with_viewport(:phone)`
  gives the narrow treatment. Use fixture users (`users(:carol)`); freshly
  created ones make the menu toggle flaky in capture scripts.
- **Measure, do not estimate.** Every contrast claim in the stylesheet came from
  a computation, and the ones about glass came from sampling the rendered PNG —
  the ground behind a label under the bar, the total variation of content behind
  the panel. If a claim cannot be measured, do not write it as a number.

---

## What this design is not

The brief that produced it ruled these out explicitly, and they are the defaults
a new session will drift back into:

- cards that are all the same white box with the same grey shadow
- small uppercase eyebrows above headings
- cream backgrounds with a terracotta accent
- a dark mode (the theme is light, framed by one dark-ish glass bar)
- a white header separated from a white page by a grey hairline
- a flat vivid green as the only accent, with white text on it
