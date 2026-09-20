# Phase 0 Research: Modernized Toast Notifications

All items below were resolved during specification (see spec.md's Clarifications) or by inspecting the existing implementation; no NEEDS CLARIFICATION markers remain.

## 1. Placement mechanism

**Decision**: Move the notification layer from `position: sticky` (anchored inside `<main>`, offset by `calc(var(--size-bar) + var(--spacing-4))` to clear the header) to `position: fixed`, pinned to the bottom-right of the viewport.

**Rationale**: Resolved directly in the 2026-09-20 clarification session as the recommended, modern option. It also removes one of the three documented "couplings that break silently" in CLAUDE.md (the toast layer's dependency on `--size-bar`), which is a net simplification: a fixed bottom-right layer no longer needs to know the header's height at all, and there is no bottom navigation bar in this app to collide with (navigation lives entirely in the header/menu panel).

**Alternatives considered**:
- Keep top-right, header-anchored (status quo) — rejected: explicitly the less-modern option in the clarification question, and keeps the `--size-bar` coupling risk alive.
- Top-center, header-anchored — rejected: risks colliding with the app's centered/gradient page titles (`.page-head`) on narrow screens, and was not the option chosen.

## 2. Type icon

**Decision**: Add a small inline SVG icon (decorative, `aria-hidden="true"`) to the left of the message text — a check-mark glyph for success, an alert/exclamation glyph for error — self-hosted directly in the partial (no icon font, no external CDN).

**Rationale**: Resolved in the clarification session as the recommended option, matching what current well-regarded toast components do (icon-forward type signaling) and strengthening FR-002's "more than one signal" requirement. The icon is `aria-hidden` because the notification's ARIA role (`status`/`alert`) plus its text already carry the semantic meaning to assistive technology — the icon would otherwise cause redundant/confusing announcement.

**Alternatives considered**:
- Icon font / npm icon package — rejected: introduces a new dependency where the app currently self-hosts every asset (fonts, brand mark); against the project's established convention.
- Emoji glyphs — rejected: renders inconsistently across platforms/fonts and is not on-brand for a typographically deliberate app (CLAUDE.md's Typography section).
- No icon, color + text only — rejected: this was the non-recommended option in the clarification question; the app's badges already use this pattern, and the point of this redesign is to move past the dated look, not repeat it.

## 3. Success/error visual distinction

**Decision**: Keep the existing colored left edge (`border-left`, using the unchanged `--color-status-success` / `--color-status-error` tokens) at a hinge/rail-like width consistent with the app's established "colored edge = category" grammar (card hinges, data-row rails), and add the new type icon in the same status color next to the message text. The card surface, radius, and shadow are refined for the new size/spacing (Phase 1), but the color mechanism itself is unchanged.

**Rationale**: This is both the lowest-risk and most on-brand option. It reuses tokens already in place (satisfies FR-008), keeps `test/system/notification_test.rb`'s existing `border-left-color` assertion valid without rewriting its intent (only whatever pixel/shape values change), and mirrors how the rest of the redesigned app already signals category with a colored edge rather than inventing a new mechanism (e.g. a fully tinted background) for this one component.

**Alternatives considered**:
- Drop the border, use a fully tinted background (like `.badge`) — rejected: a bigger visual departure from the rest of the app's card language, and would force re-verifying contrast at message-text sizes against a tinted ground rather than reusing the surface/ink pair already proven at ≥4.5:1.

## 4. Visible-count cap and queue (FR-010)

**Decision**: Cap the number of simultaneously visible notifications at 3; a 4th and further queued notification is held back and only rendered into the layer once an earlier one clears (auto-dismissed or manually dismissed). This requires a small new Stimulus controller (`toast_layer_controller.js`) on the `.toast-layer` element to mediate visibility, since the existing `notification_controller.js` only manages one toast's own countdown and knows nothing about its siblings.

**Rationale**: 3 matches the threshold already named in the spec's SC-004 ("3 or more notifications... each remains readable at some point"), and is the same default used by widely-referenced modern toast components (e.g. a visible-toasts cap of 3), so it is a safe, unsurprising choice rather than an arbitrary number.

**Alternatives considered**:
- No cap (status quo) — rejected: this is exactly the crowding failure mode FR-010 was added to prevent; the spec's edge case for 5+ notifications requires a queue.
- Cap of 1 (replace-in-place, à la many mobile OS notification banners) — rejected: more disruptive change to existing behavior (FR-005 already requires multiple to stack), and would hide information (e.g. an error arriving while a success is still visible) rather than queueing it.

## 5. Existing test coupling to update

**Finding** (not a decision, a constraint carried into Phase 2 tasks): `test/system/notification_test.rb` asserts on `[role=status]` / `[role=alert]` selectors (kept), the exact `border-left-color` computed value (kept, since the color mechanism is unchanged per §3), and `<main>`'s bounding rect being identical with/without a notification present (kept — trivially still true, and easier to guarantee once the layer is `position: fixed` and fully out of flow rather than relying on the current `sticky` + `height: 0` trick). No test needs a behavioral rewrite; new tests are additive (placement, icon presence, cap/queue).
