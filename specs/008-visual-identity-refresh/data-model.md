# Phase 1 Data Model: The Design Token System

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-14

This feature persists nothing. Its "data model" is the token system — the named, single-source values every screen references instead of re-specifying locally (spec Key Entities: *Design token*). Tokens are declared once in `@theme` inside `app/assets/tailwind/application.css`; Tailwind v4 generates the matching utilities from each declaration.

Contrast ratios below are computed against white unless stated, and every one has been verified.

---

## Entity: Colour token

### Brand colours — the artwork, reproduced faithfully

Used in the logo and for decorative fills only. **Not** for functional text or meaning-carrying UI.

| Token | Value | Source in artwork | Contrast on white | Permitted use |
|---|---|---|---|---|
| `--color-brand-navy` | `#0E2A47` | "Locker" wordmark, tagline | 14.57:1 | Primary ink, headings, wordmark "Lock", dark fills |
| `--color-brand-green` | `#0AB486` | "Swap" wordmark, green arrow | 2.66:1 | **Logo only** + decorative fills. Never functional text. |
| `--color-brand-blue` | `#0A77F1` | Blue exchange arrow | 4.27:1 | Decorative, and large graphics only |
| `--color-locker-blue` | `#2588F3` | Blue locker face | 3.56:1 | Mark artwork only |
| `--color-locker-blue-deep` | `#014DA7` | Blue locker side | 8.01:1 | Mark artwork only |
| `--color-locker-green` | `#41D5A5` | Green locker face | 1.86:1 | Mark artwork only |
| `--color-locker-green-deep` | `#05776E` | Green locker side | 5.43:1 | Mark artwork only |

> **The rule that matters**: `--color-brand-green` at 2.66:1 fails even the 3:1 non-text threshold. It is legal in the wordmark solely because WCAG 2.1 SC 1.4.3 exempts logotypes. Anywhere else it is a contrast failure. See [research.md](./research.md) D7.

### Functional colours — derived, accessible

| Token | Value | Contrast | Role |
|---|---|---|---|
| `--color-ink` | `#0E2A47` | 14.57:1 | Body and heading text |
| `--color-ink-muted` | `#50607A` | 6.37:1 | Secondary text, help text, metadata |
| `--color-accent` | `#07795A` | 5.40:1 | Green text, primary button fill behind white text, confirmed status |
| `--color-accent-strong` | `#06684D` | 6.79:1 | Primary button hover / active |
| `--color-link` | `#0A5AC2` | 6.45:1 | Link text |
| `--color-canvas` | `#F7F9FB` | — | Page background (near-white) |
| `--color-surface` | `#FFFFFF` | — | Card and panel background |
| `--color-border` | `#D8E0E9` | 1.33:1 | Decorative separation only — never the sole carrier of meaning |
| `--color-border-strong` | `#C7D2DE` | 1.53:1 | Input borders at rest (paired with a visible label) |

### Status colours

Each pair is text-on-tint and verified ≥4.5:1. Per FR-025 every badge also carries a text label, so colour is never the sole signal.

| Status | Text | Tint | Contrast |
|---|---|---|---|
| Success / confirmed | `#07795A` | `#E6F7F1` | 4.87:1 |
| Error / declined | `#9F1239` | `#FFE4E6` | 6.68:1 |
| Info / pending | `#0A5AC2` | `#E3EDFD` | 5.47:1 |
| Neutral / withdrawn | `#0E2A47` | `#EEF2F6` | 12.96:1 |

**Validation rules**
- Every colour used for text MUST reach 4.5:1 against its actual background, or 3:1 at ≥18.66px bold / ≥24px.
- Every colour carrying meaning without text MUST reach 3:1.
- The logotype exemption applies to the wordmark and nothing else.

---

## Entity: Typography token

One family, one variable file (see [research.md](./research.md) D3).

| Token | Value |
|---|---|
| `--font-brand` | `"Nunito", ui-rounded, "Segoe UI", system-ui, sans-serif` |

The fallback stack is deliberately rounded-first so the pre-swap paint is not jarringly different in shape from the loaded face.

### Type scale

| Token | Size / line-height | Weight | Use |
|---|---|---|---|
| `--text-display` | 2.5rem / 1.1 | 800 | Stacked lockup wordmark |
| `--text-h1` | 1.875rem / 1.2 | 800 | Page title |
| `--text-h2` | 1.25rem / 1.3 | 700 | Section heading |
| `--text-h3` | 1rem / 1.4 | 700 | Card heading |
| `--text-body` | 1rem / 1.6 | 400 | Body copy |
| `--text-sm` | 0.875rem / 1.5 | 400 | Help text, metadata |
| `--text-label` | 0.875rem / 1.4 | 600 | Form labels, badges |

**Validation rules**
- Body text MUST NOT fall below 1rem; help text MUST NOT fall below 0.875rem.
- `@font-face` MUST declare `font-display: swap` (FR-026).
- Only the latin subset ships (FR-005b).

---

## Entity: Spacing, radius, shadow

| Token | Value | Use |
|---|---|---|
| `--space-1` … `--space-8` | 0.25 / 0.5 / 0.75 / 1 / 1.5 / 2 / 3 / 4 rem | 4px-based rhythm; all spacing snaps to a step |
| `--radius-sm` | 0.5rem | Inputs, badges, small controls |
| `--radius-md` | 0.875rem | Buttons |
| `--radius-lg` | 1.25rem | Cards and panels |
| `--radius-full` | 9999px | Pills, avatars |
| `--shadow-sm` | `0 1px 2px rgb(14 42 71 / 0.05)` | Resting card |
| `--shadow-md` | `0 4px 12px rgb(14 42 71 / 0.08)` | Raised card, hover |
| `--shadow-lg` | `0 12px 32px rgb(14 42 71 / 0.12)` | Overlay, flash notification |

Shadows are tinted with the brand navy rather than neutral black — a grey shadow on a white canvas reads muddy, a navy-tinted one reads clean and ties back to the palette.

**Validation rules**
- Region separation uses whitespace, `--shadow-*`, and `--color-border` — never a heavy grey background block (FR-012).
- No arbitrary spacing values in templates; every value resolves to a step.

---

## Entity: Motion token

| Token | Value | Use |
|---|---|---|
| `--motion-fast` | 120ms | Colour and border feedback |
| `--motion-base` | 180ms | Hover lift, focus ring |
| `--motion-entrance` | 320ms | Page content entrance |
| `--motion-flourish` | 900ms | One-off logo exchange animation |
| `--ease-out` | `cubic-bezier(0.16, 1, 0.3, 1)` | Entrances — decelerating, settles confidently |
| `--ease-in-out` | `cubic-bezier(0.4, 0, 0.2, 1)` | Reversible state changes |

**Validation rules**
- Interaction feedback MUST settle ≤200ms; entrance MUST complete ≤400ms (FR-019). `--motion-base` and `--motion-entrance` sit inside those bounds with headroom.
- Only `transform` and `opacity` may be animated (FR-021).
- Every token is neutralised by the global reduced-motion block (FR-020).
- No animation may loop indefinitely (FR-022).

---

## Entity: Brand asset

Three arrangements, one mark. Full geometry, clear space, and minimum sizes in [contracts/brand-assets.md](./contracts/brand-assets.md).

| Asset | Composition | Where |
|---|---|---|
| Mark | Inline SVG: two lockers + two exchange arrows | Header lockup, stacked lockup, favicon, app icon |
| Horizontal lockup | Mark + HTML wordmark, side by side | Site header, every page |
| Stacked lockup | Mark above wordmark above tagline | Sign-in, sign-up |

The wordmark is live HTML text, not SVG paths — see [research.md](./research.md) D6.

---

## Entity: Interface component

Each recurring element has exactly one definition and one set of states (rest, hover, focus, active, disabled, in-progress, error). Full contract in [contracts/component-contract.md](./contracts/component-contract.md).

Components: button (primary / secondary / destructive), form field, label, help text, validation error, card, panel, disclosure, status badge, empty state, toast notification, brand lockup.

**Validation rules**
- A component is defined once and reused; a second definition of the same element is a defect (FR-011).
- Every interactive component MUST have a visible focus state distinguishable from hover, and not signalled by colour alone (FR-024).
- Every state MUST hold its contrast obligations, not just the resting state — a disabled or hovered control still has to be readable.

---

## State transitions

No entity here has persistent state. The only transitions are transient interaction states on components, which the component contract defines per element. Nothing in this feature reads or writes the database.
