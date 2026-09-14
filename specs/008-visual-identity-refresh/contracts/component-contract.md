# Contract: Interface Components

**Feature**: [../spec.md](../spec.md) | **Tokens**: [../data-model.md](../data-model.md) | **Date**: 2026-09-14

FR-011 requires one treatment per recurring element, reused everywhere. This is that set. Each component is defined once in the component layer of `app/assets/tailwind/application.css`; templates reference the class and never re-specify the utilities.

**Universal rules, applying to every component below:**

- **Focus.** A visible focus indicator on every focusable control, distinct from hover, never colour alone (FR-024). One shared treatment: a 2px `--color-link` ring offset 2px from the element. Use `:focus-visible` so pointer clicks do not leave rings behind, and never remove an outline without replacing it.
- **Contrast in every state.** Rest, hover, focus, active, disabled, in-progress, and error each hold their obligations. A disabled control still has to be readable — dim the background, not the text below 4.5:1.
- **Motion.** `transform` and `opacity` only, `--motion-fast`/`--motion-base`, neutralised by the global reduced-motion block.
- **Meaning is never colour alone** (FR-025). Every status carries a text label.

---

## Button

Three variants. Shared: `--radius-md`, `--text-label` weight 600, ≥44px touch target, `transition: background-color var(--motion-fast), transform var(--motion-base)`.

| Variant | Rest | Hover | Active | Disabled |
|---|---|---|---|---|
| Primary | `--color-accent` fill, white text (5.40:1) | `--color-accent-strong`, lift `translateY(-1px)` | `translateY(0)` | 45% opacity fill, `cursor: not-allowed`, text kept ≥4.5:1 |
| Secondary | `--color-surface` fill, `--color-border-strong` border, `--color-ink` text | `--color-canvas` fill | as hover, no lift | same rule |
| Destructive | transparent fill, `#9F1239` text, `#9F1239` border | `#FFE4E6` fill | as hover | same rule |

**In-progress** (FR-018): `data-turbo-submits-with="<label>"` — native to turbo-rails, swaps the label while the form is in flight, no custom JS.

> **Constraint from [preserved-dom.md](./preserved-dom.md) §3**: the primary style must work on `<input type="submit">`, so it uses **no pseudo-elements and no child elements**. No icon slots, no spinner elements inside buttons.

---

## Form field

| Part | Treatment |
|---|---|
| Label | `--text-label`, `--color-ink`, always visible — never a placeholder standing in for a label |
| Input | `--radius-sm`, 1px `--color-border-strong`, `--color-surface` fill, `--space-3` padding, `--text-body` |
| Focus | shared focus ring; border darkens to `--color-link` |
| Help text | `--text-sm`, `--color-ink-muted` (6.37:1), wired with `aria-describedby` |
| Error | border `#9F1239`, message below in `#9F1239` (6.68:1) prefixed with a warning glyph so the error is not colour-only |
| Disabled | `--color-canvas` fill, `--color-ink-muted` text |

Input font size stays ≥1rem — a smaller value makes iOS Safari zoom on focus.

---

## Card and panel

`--color-surface` fill, `--radius-lg`, 1px `--color-border`, `--shadow-sm`, `--space-6` padding. Interactive cards only: hover to `--shadow-md` and `translateY(-2px)` over `--motion-base`.

Cards separate content through whitespace, border, and shadow — never a heavy grey fill (FR-012). A card is not a button: if the whole card is clickable, it contains a real link or button that carries the accessible name, rather than a click handler on the `<div>`.

---

## Disclosure

Native `<details>`/`<summary>` — preserved, not reimplemented ([preserved-dom.md](./preserved-dom.md) §2).

Summary is styled as a card header with `cursor: pointer`, `list-style: none` plus a rotating chevron driven by `[open]`. Rotation animates `transform` over `--motion-base`. The shared focus ring applies to `summary`, which is natively focusable.

---

## Status badge

`--radius-full`, `--text-label`, `--space-1`/`--space-3` padding, text-on-tint pairs from [data-model.md](../data-model.md). Always contains its label as text.

| Status | Pair | Contrast |
|---|---|---|
| Completed / Exchanged / accepted | `#07795A` on `#E6F7F1` | 4.87:1 |
| Declined | `#9F1239` on `#FFE4E6` | 6.68:1 |
| Proposed / Received / Sent / pending | `#0A5AC2` on `#E3EDFD` | 5.47:1 |
| Withdrawn | `#0E2A47` on `#EEF2F6` | 12.96:1 |

---

## Empty state

Centred block inside a card: muted mark or icon at low opacity, `--text-h3` headline, `--text-sm` `--color-ink-muted` explanation, optional primary action. Existing empty-state copy is preserved verbatim (`#locker-wish-list-empty`, `#swap-proposal-history-empty`).

---

## Toast notification

Restyled only — behaviour, roles, and Stimulus wiring are feature 007's and stay untouched.

`--color-surface` fill, `--radius-md`, `--shadow-lg`, 4px left accent bar in the status colour, `--color-ink` body text. Enters with `opacity` + `translateY(8px)` over `--motion-base`.

Stays `position: fixed` — `notification_test.rb` asserts `<main>`'s rectangle is byte-identical with and without a notification present. Keeps `max-width` with `width: 100%` so a long message grows downward rather than bursting sideways.

---

## Brand lockup

Three arrangements in [brand-assets.md](./brand-assets.md). The header lockup is a single `<a>` to `root_path` containing the inline mark plus the visible text wordmark. Mark gets `aria-hidden="true"` — the adjacent text already names the link, and a duplicate accessible name is noise for a screen reader.

Hover: mark scales to `1.03` over `--motion-base`. Focus: shared ring on the whole link.

---

## Application shell

| Part | Treatment |
|---|---|
| Body | `--color-canvas`, `--font-brand`, `--color-ink`, antialiased |
| Header | `--color-surface`, 1px bottom `--color-border`, lockup left, navigation right |
| Nav links | `--text-label`, `--color-ink-muted`, hover `--color-ink`, shared focus ring |
| `<main>` | centred column, `--space-6` side padding, `--space-8` top/bottom |
| Entrance | `<main>` content fades and rises 8px over `--motion-entrance`, once per render |

Header navigation must not overlap the brand at 360px (US1 scenario 5). The signed-in user's email is the element that truncates or hides — never the brand, never the controls (Edge Cases).

Entrance animation must animate *from* a visible final state so content is readable even if the animation never runs (FR-016b).

---

## Verification

- Every screen passes `assert_axe_clean` (FR-028).
- No component defined twice; no utility string repeated across templates where a component class exists (FR-011, Constitution I).
- Keyboard walk of each screen shows a visible focus indicator on every control (SC-005).
