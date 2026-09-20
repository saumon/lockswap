# Phase 0 Research: Compact floor/locker label alignment

No items in the Technical Context were marked `NEEDS CLARIFICATION` — this is
a small, well-scoped view/CSS change on an existing Rails app with an existing
design system. Research here is confirming which existing pattern to reuse for
each of the three changes, per Constitution Principle I (no duplicated
component definitions) and the CLAUDE.md rule "one definition per component."

## 1. Inlining the floor number in "Your locker search"

**Decision**: Change the markup from a two-line `<dl>` (`<dt>` sentence on one
line, `<dd class="detail-value">` floor number on the next) to a single
inline statement where the floor number sits inside or immediately after the
sentence, keeping the value visually distinguished with the existing
`.detail-value` styling (monospace, tabular figures) but flowed inline rather
than block-stacked.

**Rationale**: `.detail-value` is already the site's convention for a
"measured" value (floor numbers, locker numbers) — CLAUDE.md's Typography
section states these get `--font-mono` specifically because they are
measured. Reusing it inline (rather than introducing a new inline-value class)
keeps the "one definition per component" rule intact and keeps the visual
language (monospace digits) consistent with every other floor/locker number
on the site.

**Alternatives considered**:
- *New dedicated "inline stat" component*: rejected — would duplicate
  `.detail-value`'s font/weight/tabular-nums declarations for no behavioral
  difference, violating the "no duplicated logic" rule in Principle I.
- *Flexbox row with `dt`/`dd` as flex items*: viable CSS approach but the
  `<dl>` here only has one term/value pair, so a plain inline flow (or an
  inline-block `.detail-value` with no forced margin-top) is simpler than
  introducing a flex container for a single pair.

## 2. Inline label+value for "Your locker" on mobile

**Decision**: On the mobile side of the existing single breakpoint (below
48rem), change each field group inside `.detail-grid` so its `.detail-term`
and `.detail-value` sit on the same line, instead of the current
label-above-value stack. The existing `@media (min-width: 48rem)` rule that
switches `.detail-grid` to two side-by-side columns is preserved untouched —
only the *mobile* (below-breakpoint) internal stacking of each pair changes.

**Rationale**: `.detail-grid` / `.detail-term` / `.detail-value` is already
the single established pattern for floor+locker-number pairs (confirmed by
codebase search — no other floor-pairing utility exists). CLAUDE.md's "One
definition per component" rule and the "one breakpoint, 48rem" enforced test
(`test/stylesheet_breakpoint_test.rb`) both require adjusting the existing
rule rather than introducing a second breakpoint or a second label/value
component.

**Alternatives considered**:
- *A second, mobile-specific detail component*: rejected — would violate the
  one-definition-per-component rule and duplicate styling that already exists.
- *A new media query at a different width*: rejected outright —
  `test/stylesheet_breakpoint_test.rb` reads the stylesheet as text and fails
  on any width other than 48rem / 47.999rem.

## 3. Removing the card treatment from homepage "Your locker"

**Decision**: `app/views/home/_locker_profile.html.erb` has exactly one call
site — `home/index.html.erb:53` (confirmed by searching the codebase for
every render of this partial) — so the card wrapper (`.card.card--you`) on
its root element is changed unconditionally to a plain element (no border,
background, or hinge), with the heading and `.detail-grid` content inside it
left otherwise unchanged. No rendering-context flag is introduced.

**Rationale**: Since the partial is only ever rendered from the homepage
today, a flag to select between "boxed" and "card-less" rendering would be a
parameter with a single possible value at every call site — exactly the kind
of speculative, unused-elsewhere flexibility the project avoids ("Don't
design for hypothetical future requirements"). Changing the partial directly
keeps one definition of the component (Principle I / "one definition per
component") without adding dead conditional logic. If a second, boxed call
site is ever needed, the wrapper can be reintroduced as a local at that time.

**Alternatives considered**:
- *Duplicate the partial for the homepage*: rejected — creates a second
  definition of the same component that will drift, directly against
  Principle I and "one definition per component."
- *A rendering-context flag (e.g. mirroring the existing `editable:` local)
  passed from `home/index.html.erb`*: rejected as premature — `editable:`
  earns its keep because the partial is rendered with both `true` and `false`
  today; a boxed/card-less flag would have only one call site ever passing
  one value, so it adds a branch with no real variation to justify it.
- *CSS-only override (e.g., a homepage-scoped class that resets `.card`'s
  border/background/hinge)*: viable, but produces a `.card` that silently
  isn't one wherever it's applied, which is more surprising to a future
  reader than removing the classes at the single source; rejected in favor
  of editing the partial's root element directly.
