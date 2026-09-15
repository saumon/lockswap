# Contract: Signed-in menu DOM and ARIA

**Feature**: 012-responsive-layout-menu
**Requirements**: FR-009 – FR-017, FR-010a–c, FR-010b-i/ii

## Structure

Rendered once, from `app/views/shared/_site_menu.html.erb`, inside the existing
`<nav aria-label="Main">`. Only rendered when `user_signed_in?`, as today.

```html
<details class="site-menu" data-controller="site-menu">
  <summary class="site-menu-toggle" aria-label="Menu">…icon…</summary>

  <div class="site-menu-panel">
    <a class="site-nav-link" href="/locker_wishes">Locker wishes</a>
    <a class="site-nav-link" href="/locker_swap_proposals">Proposal history</a>
    <span class="site-nav-identity">user@example.com</span>
    <form …>  <button class="btn btn-secondary">Log out</button>  </form>
  </div>
</details>
```

The brand lock-up stays a sibling of the `<details>`, outside it, so it remains
visible at every width (FR-012).

## Behavioural contract

| # | Guarantee | Width | Needs script |
|---|---|---|---|
| 1 | Toggle opens and closes the panel | narrow | no |
| 2 | Toggle is keyboard-operable and announces expanded/collapsed | narrow | no |
| 3 | A second activation always closes the panel | narrow | no |
| 4 | Escape closes the panel | narrow | yes |
| 5 | Activating outside the panel closes it | narrow | yes |
| 6 | Following a panel link leaves the panel closed on the next page | narrow | yes |
| 7 | Focus returns to the toggle on close | narrow | no (native) |
| 8 | Toggle absent; destinations, identity and sign-out laid out in the bar | wide | no |

Rows 1–3, 7 and 8 are the **no-script baseline** (FR-010b). Rows 4–6 are
**enhancements** (FR-010b-i); their absence must never leave a user stuck
(FR-010b-ii).

## Accessible naming

- The toggle's accessible name comes from `aria-label` because it has no text
  content. The name must describe navigation, not the icon (FR-017).
- `<summary>` supplies `aria-expanded` natively — **do not hand-write it**, and
  do not add `role="button"`; both break the native semantics this pattern was
  chosen for.
- The wordmark keeps its existing accessible name so `click_on "LockSwap"`
  continues to work in `navigation_test.rb`.

## CSS contract

| Class | Responsibility |
|---|---|
| `.site-menu` | the `<details>` host; dissolved above the breakpoint |
| `.site-menu-toggle` | the `<summary>`; 2.75rem square; hidden above the breakpoint |
| `.site-menu-panel` | the disclosure body below the breakpoint, a flex row above it |
| `.site-nav-link` | unchanged above the breakpoint; ≥ 2.75rem tall inside the panel |
| `.site-nav-identity` | unchanged; still the element that truncates (FR-013) |

Wide-width neutralisation, per [research R1](../research.md#r1--rendering-one-menu-that-is-a-disclosure-below-48rem-and-a-plain-bar-above):

```css
@media (min-width: 48rem) {
  .site-menu { display: contents; }
  .site-menu::details-content { content-visibility: visible; }
  .site-menu-toggle { display: none; }
}
```

## Stimulus controller contract

`site_menu_controller.js` — **enhancement only**. It must not be required for
the menu to open or close.

| Action | Effect |
|---|---|
| `keydown.esc` on the document | clear `open`, return focus to the summary |
| `click` outside `.site-menu` | clear `open` |
| `turbo:load` / `disconnect` | ensure `open` is cleared, so no panel survives a navigation |

The controller only ever *removes* the `open` attribute. It never adds it —
adding is the browser's job via the summary, which is what keeps the no-script
baseline intact.

## Forbidden

- Rendering the destinations, identity or sign-out control more than once.
- Any `aria-expanded`, `aria-controls` or `role` hand-written onto the summary.
- Any script that gates whether the menu can be opened.
- A focus trap. The panel is a disclosure in the document flow, not a modal.
