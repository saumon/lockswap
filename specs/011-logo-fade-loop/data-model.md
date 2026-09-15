# Phase 1 Data Model: Looping Logo Fade Animation

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-15

This feature persists nothing and introduces no domain entities — no database table, model, or user-facing record is added, read, or changed. What it does add is one new named value to the existing design-token system (introduced in feature 008) and two new modifier classes on the existing brand-mark component. Both are documented here in the same "entity" shape 008 used, since they are the closest thing this feature has to a data model.

---

## Entity: Motion token (new value)

Extends the existing motion token table (`app/assets/tailwind/application.css`, `:root` block) with one addition:

| Token | Value | Use |
|---|---|---|
| `--motion-brand-loop` | `3000ms` | Duration of one full pulse cycle (full → ~60% → full opacity) of the looping logo fade |

Existing tokens this feature reads but does not change: `--motion-brand` (1100ms, the one-shot entrance duration — reused as the loop's start delay on elements that also carry the entrance) and `--ease-brand` (the entrance's easing curve — not reused by the loop, which uses the standard `ease-in-out` keyword; see `research.md` D1).

**Validation rules**
- The loop MUST oscillate between 100% and ~60% opacity only (FR-004) — never lower, so the mark never approaches illegibility (edge case in spec.md).
- The loop MUST be declared only inside `@media (prefers-reduced-motion: no-preference)` (`research.md` D6), matching every other animation in this stylesheet — never left to the global reduced-motion override alone.
- The loop's `animation-iteration-count` MUST be `infinite` (FR-005) — this is the one motion token in the system with no fixed iteration count, so it is called out explicitly rather than assumed from the pattern of every prior token (all of which run once).

## Entity: Brand-mark modifier class (new)

Extends the existing brand-mark component (feature 008's "Brand asset" entity) with one new CSS class, alongside the existing `.brand-mark-flourish`:

| Class | Declares | Applied to |
|---|---|---|
| `.brand-mark-loop` | The `brand-fade-pulse` animation, `animation-delay: 0s` (starts immediately) | The header's 32px mark (`shared/_brand_lockup.html.erb`, via the `_brand_mark` partial's new `pulse` local) |
| `.brand-mark-flourish.brand-mark-loop` (compound) | Both `brand-fade-in` (once) **and** `brand-fade-pulse` (infinite, delayed by `--motion-brand` so it starts when the entrance ends) | The sign-in/sign-up mark (`shared/_brand_stacked.html.erb`'s `<img>`) |

See `research.md` D4 for why the compound rule exists (the `animation` shorthand does not merge across separate matching rules) and `contracts/brand-motion-loop.md` for the full CSS contract.

**Validation rules**
- `.brand-mark-loop` alone (no `.brand-mark-flourish`) MUST start at cycle-time zero — no entrance precedes it on the header, so there is nothing to wait for (FR-003).
- `.brand-mark-flourish.brand-mark-loop` together MUST NOT let the two animations visually overlap — the loop's delay MUST equal the entrance's full duration (`var(--motion-brand)`), so the pulse's first dim begins only once the entrance's `both`-held final frame is already showing (FR-006, edge case in spec.md).
- Neither class may set anything other than `opacity` in the pulse keyframes — the stylesheet's transform/opacity-only convention applies to this rule same as every other non-flourish animation (FR-008).

## Component locals (view-layer contract)

`shared/_brand_mark.html.erb` gains one new boolean local, independent of the existing `flourish` local:

| Local | Default | Effect |
|---|---|---|
| `pulse` | `false` | Appends `brand-mark-loop` to the rendered SVG's `class` attribute |

Existing local, unchanged: `flourish` (default `false`) — appends `brand-mark-flourish`.

**Call sites**

| View | `flourish:` | `pulse:` | Resulting classes |
|---|---|---|---|
| `shared/_brand_lockup.html.erb` (site header, 32px) | *(omitted → false)* | `true` | `brand-mark brand-mark-loop` |
| `shared/_brand_stacked.html.erb` (sign-in/sign-up, raster `<img>`, not this partial) | — | — | `brand-mark brand-mark-flourish brand-mark-loop` (both classes added directly to the `<img>` tag) |

## State transitions

No entity here has persistent state. The only "transition" is the animation hand-off on the sign-in/sign-up mark — entrance (`brand-fade-in`, plays once) → loop (`brand-fade-pulse`, plays forever) — which is expressed entirely as CSS timing (`animation-delay`), not as an application state machine. Nothing in this feature reads or writes the database.
