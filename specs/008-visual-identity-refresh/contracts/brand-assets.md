# Contract: Brand Assets

**Feature**: [../spec.md](../spec.md) | **Date**: 2026-09-14

Defines the mark, the three arrangements, and the icon set. Colours are the artwork values from [../data-model.md](../data-model.md); the architectural reasoning is [../research.md](../research.md) D6.

---

## The mark

Two lockers exchanging position, drawn in light 3/4 perspective, with two curved arrows forming a rotation around them.

**Geometry**: 64×64 viewBox, hand-authored SVG.

| Element | Fill | Detail |
|---|---|---|
| Left locker, face | `--color-locker-blue` `#2588F3` | Rounded rectangle, `rx` ≈ 3/64 of width |
| Left locker, side | `--color-locker-blue-deep` `#014DA7` | Narrow parallelogram, left edge |
| Right locker, face | `--color-locker-green` `#41D5A5` | Mirrored |
| Right locker, side | `--color-locker-green-deep` `#05776E` | Right edge |
| Vent slots | locker's own deep tone | Three short bars, upper third |
| Handle | locker's own deep tone | Vertical rounded bar, inner edge |
| Top arrow (left → right) | `--color-brand-blue` `#0A77F1` | Arcs over the lockers, head on the right |
| Bottom arrow (right → left) | `--color-brand-green` `#0AB486` | Arcs under, head on the left |

**Rules**
- `fill="currentColor"` is **not** used — the mark is polychrome by definition.
- No `<text>` in the mark. It must stay legible at 16px, where lettering is mud.
- Inline in the page (not `<img>`) wherever it must recolour or animate.
- `aria-hidden="true"` whenever adjacent text already names the brand; a standalone mark takes `role="img"` with `<title>LockSwap</title>`.
- Minimum rendered size **20px**. Clear space on all sides ≥ 25% of the mark's width.

---

## Arrangement 1 — horizontal lockup (site header)

Mark at 32px, then the wordmark, separated by `--space-3`.

**Wordmark**: live HTML text, `--font-brand` weight 800, `--text-h2` size, `letter-spacing: -0.01em`.

- `Lock` → `--color-brand-navy` `#0E2A47`
- `Swap` → `--color-brand-green` `#0AB486`

The split is a `<span>` inside the link. The link's accessible name must read as the single word **LockSwap** — no whitespace between the spans, no `aria-label` substituting for the text.

> **Contrast note.** `#0AB486` on white is 2.66:1. This is permitted *only* because WCAG 2.1 SC 1.4.3 exempts text that is part of a logo or brand name. The exemption covers this wordmark and nothing else in the product. The axe suite excludes this element from `color-contrast` with an inline comment citing the exemption.

At <400px the mark stays and the wordmark stays — both are small enough to fit. The navigation collapses first.

---

## Arrangement 2 — mark alone

Favicon, app icon, compact contexts, empty-state decoration (reduced opacity).

---

## Arrangement 3 — stacked lockup (sign-in, sign-up)

Vertically centred: mark at 72px → `--space-4` → wordmark at `--text-display` (2.5rem, weight 800) → `--space-2` → tagline.

**Tagline**: "Find the locker that suits you" — English per FR-003a. `--text-sm`, weight 400, `--color-ink-muted` (6.37:1 — this is ordinary text and gets no logo exemption).

**Flourish** (FR-022): on these pages only, the two arrows trace their arcs once via `stroke-dashoffset`, `--motion-flourish` (900ms), `animation-iteration-count: 1`. Never loops. Suppressed under reduced motion. The mark must be complete and correct at rest, so the animation ends on the resting state and content never depends on it.

---

## Icons

| File | Size | Content |
|---|---|---|
| `public/icon.svg` | 512×512 viewBox | Mark on transparent |
| `public/icon.png` | 512×512 | Mark on white |

Both currently a red-circle placeholder; both replaced (FR-006).

**Manifest** (`app/views/pwa/manifest.json.erb`):

| Key | From | To |
|---|---|---|
| `theme_color` | `"red"` | `"#0E2A47"` |
| `background_color` | `"red"` | `"#FFFFFF"` |
| `description` | `"LockSwap."` | A real sentence |
| `icons` | two identical entries | `any` full-bleed + `maskable` inset |

The maskable icon must sit inside the safe zone — Android crops maskable icons to a circle, and a mark drawn edge-to-edge loses its arrow heads. Inset the artwork to the central 80%.

---

## Naming

The product is **LockSwap** everywhere (FR-008). The artwork's "LockerSwap" spelling is superseded; the stray occurrence in `app/views/home/index.html.erb` is corrected. Zero occurrences of "LockerSwap" may remain in user-visible output (SC-003).

---

## Verification

- Mark renders sharply at 200% zoom and on high-DPI (SC-002) — inherent to vector, confirmed by eye.
- Header brand link is reachable by `click_on "LockSwap"` — covered by the existing `navigation_test.rb`.
- Brand element exposes its name to assistive technology (FR-007) — covered by `assert_axe_clean`.
- Spelling consistency (SC-003) and logo sharpness (SC-002) are verified by **review, not automated test** — the consequence of choosing accessibility-only test evidence, recorded in the plan's risk table.
