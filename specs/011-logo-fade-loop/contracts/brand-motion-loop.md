# Contract: Looping Brand-Mark Fade

**Feature**: [../spec.md](../spec.md) | **Plan**: [../plan.md](../plan.md) | **Date**: 2026-09-15

This project has no external API; its "contract" is the CSS animation surface and the view-partial locals other templates render against. This document is the interface an implementer builds to and a reviewer checks against — the reasoning behind each choice lives in [../research.md](../research.md).

---

## CSS contract

### New token

```css
:root {
  /* alongside the existing --motion-brand, --motion-flourish, --ease-brand */
  --motion-brand-loop: 3000ms;
}
```

### New keyframes

```css
@keyframes brand-fade-pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.6; }
}
```

- MUST NOT animate any property other than `opacity`.
- The `50%` value (`0.6`) MUST NOT be lowered without re-confirming with product — it is the agreed floor (spec FR-004), not an arbitrary midpoint.

### New rules

Declared inside the existing `@media (prefers-reduced-motion: no-preference)` block, immediately after the current `.brand-mark-flourish` rule:

```css
@media (prefers-reduced-motion: no-preference) {
  .brand-mark-flourish {
    animation: brand-fade-in var(--motion-brand) var(--ease-brand) 1 both;
  }

  .brand-mark-loop {
    animation: brand-fade-pulse var(--motion-brand-loop) ease-in-out infinite;
  }

  /* Compound rule wins over .brand-mark-loop alone via specificity (two
     classes > one). Required because the `animation` shorthand replaces the
     whole animation list per matching rule rather than merging across rules
     — see research.md D4. */
  .brand-mark-flourish.brand-mark-loop {
    animation:
      brand-fade-in var(--motion-brand) var(--ease-brand) 1 both,
      brand-fade-pulse var(--motion-brand-loop) ease-in-out infinite;
    animation-delay: 0s, var(--motion-brand);
  }
}
```

**Invariants**

1. An element with `.brand-mark-loop` and **not** `.brand-mark-flourish` MUST start pulsing immediately (delay `0s`).
2. An element with **both** classes MUST NOT visibly pulse until the entrance has fully settled — the loop's delay MUST equal `var(--motion-brand)`.
3. Under `prefers-reduced-motion: reduce`, neither rule applies (both live inside the `no-preference` media block) — the mark is painted static at opacity `1`, matching how `.brand-mark-flourish` alone already behaves today.
4. No rule here may set `animation-iteration-count` to anything but `infinite` for the pulse component, or anything but `1` for the entrance component.

---

## View-partial contract

### `shared/_brand_mark.html.erb`

New local, added to the doc comment block at the top of the file next to the existing `flourish` entry:

```
Locals:
  size        rendered height in px (width follows the artwork's 649:547 ratio)
  aria_hidden true when adjacent text already names the brand, which is the
              usual case; false makes it a labelled standalone image
  flourish    true to arm the one-off arrow animation (sign-in / sign-up only)
  pulse       true to arm the continuous fade loop (FR-003 / FR-005)
```

```erb
<%
  pulse = false if !defined?(pulse) || pulse.nil?
%>
<svg data-brand-mark
     class="brand-mark<%= " brand-mark-flourish" if flourish %><%= " brand-mark-loop" if pulse %>"
     ...
```

**Contract**: `pulse` and `flourish` are independent booleans. Every existing and future call site of this partial must pick both explicitly (or accept both defaulting to `false`) rather than assuming one implies the other.

### `shared/_brand_lockup.html.erb`

```erb
<%= render "shared/brand_mark", size: 32, pulse: true %>
```

**Contract**: the header mark is armed with `pulse: true` and **never** `flourish: true` — an entrance flourish on every navigation would still be "a tic, not a flourish" (unchanged rule from feature 008), independent of the new loop.

### `shared/_brand_stacked.html.erb`

```erb
<%= image_tag "brand-mark.png",
      ...
      class: "brand-mark brand-mark-flourish brand-mark-loop" %>
```

**Contract**: this view renders a raster `<img>` directly (not through `_brand_mark`), so both classes are added to its existing `class` attribute literally, not via a partial local.

---

## Test contract (what must be provably true)

Automated coverage (system tests, `test/system/motion_test.rb`) MUST demonstrate, per FR-001 through FR-009:

| Requirement | Provable via |
|---|---|
| FR-001 / FR-002: sign-in and sign-up marks loop indefinitely, past the entrance | `getComputedStyle(...).animationName` includes `brand-fade-pulse`; its `animationIterationCount` component reads `infinite` |
| FR-003: header mark loops on every page while signed in | Same assertion against `header [data-brand-mark]` |
| FR-004: oscillates 100% ↔ ~60% | Sample `getAnimations()` at `currentTime` set to the keyframe's `50%` point and read `getComputedStyle(...).opacity` |
| FR-005: ~3s cycle, indefinite | `getComputedStyle(...).animationDuration` component ≈ `3s`; iteration count `infinite` |
| FR-006: loop starts only after the entrance | Loop's `animationDelay` component equals the entrance's `animationDuration` (`var(--motion-brand)`, 1100ms) |
| FR-007: reduced motion suppresses it entirely | Under `emulate_reduced_motion`, `animationName` is `none` on both marks (unchanged assertion style from the existing suite) |
| FR-008: no layout/position change | No new assertion needed beyond the existing opacity-only keyframe — nothing in the contract touches `transform`, `width`, `height`, or position |
| FR-009: header mark stays clickable | Existing `navigation_test.rb` coverage (`click_on "LockSwap"`) continues to pass unmodified — this contract must not add `pointer-events: none` or any interaction-blocking property |

See `research.md` D8 for the two existing assertions this feature must rewrite because they assert the prior (non-looping) behavior, and D7 for the coupled `wait_for_entrance` scoping fix required for the accessibility-audit helper to keep resolving promptly once an infinite animation exists on the page.
