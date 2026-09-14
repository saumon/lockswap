# Phase 0 Research: Auto-Dismissing Popup Notifications

No `NEEDS CLARIFICATION` markers remain in the Technical Context — the stack is fully determined by the existing app (Rails 8.1 + Hotwire + importmap, Minitest/Capybara). The research below covers the implementation-approach decisions needed to satisfy the spec's functional requirements within that stack.

## Decision 1: Mechanism — Stimulus controller, no new JS dependency

**Decision**: Implement the popup/auto-dismiss/pause/manual-dismiss behavior as a small Stimulus controller (`app/javascript/controllers/notification_controller.js`), registered via the existing `eagerLoadControllersFrom` importmap setup (`app/javascript/controllers/index.js`) — no code changes needed there.

**Rationale**: The app already uses Stimulus for client-side behavior and importmap-rails for JS dependency management (no npm/bundler). A Stimulus controller keeps the feature consistent with the existing pattern (Constitution Principle I: reuse existing conventions) and avoids introducing any new dependency footprint for what is a small, self-contained behavior.

**Alternatives considered**:
- *Third-party toast library (e.g., pinned via importmap from a CDN)* — rejected: adds an external dependency and CDN-availability risk for behavior that's ~40 lines of vanilla JS; violates Code Quality's "unjustified complexity" guidance.
- *Turbo Stream broadcast for notifications* — rejected: unnecessary indirection: the flash message is already present in the initial page response (via `redirect_to ..., notice:`/`alert:`), there is no need for a second round-trip or broadcast channel to deliver it.

## Decision 2: Rendering location and layout impact

**Decision**: Keep flash rendering in the existing shared partial (`app/views/layouts/_flash.html.erb`), but change its markup from an inline `<p>` block inside `<main>`'s normal flow to a `position: fixed` overlay container (e.g. top-of-viewport, stacked vertically), and keep the single `<%= render "layouts/flash" %>` call in `application.html.erb` unchanged.

**Rationale**: Satisfies FR-005 (must not shift or permanently occupy space in the main content layout) with the smallest possible change — one partial, one call site, already used by every page. `position: fixed` removes the element from document flow entirely, so its presence/absence never affects surrounding content layout.

**Alternatives considered**:
- *New dedicated layout region above `<header>`* — rejected: unnecessary layout-file churn when a `fixed` position achieves the same visual result without moving the render call.

## Decision 3: Preserving accessible roles and existing test contracts

**Decision**: Each individual notification element keeps the roles already in use today — `role="status"` for a notice/success message, `role="alert"` for an error message — rather than introducing a single wrapping `aria-live` region. On dismiss (automatic or manual), the element is fully removed from the DOM (not just visually hidden via CSS), preserving the semantics existing system tests already rely on (e.g. `assert_no_selector "[role=alert]"` in `test/system/locker_profile_test.rb`).

**Rationale**: `role="status"` and `role="alert"` are themselves implicit ARIA live regions (polite and assertive respectively), so screen readers announce them without any extra wrapping container. Keeping the same role per message type means no existing test needs to change its *selector*, only what it additionally asserts (timing, hover-pause). Full DOM removal (vs. `hidden`/`display:none`) keeps `assert_no_selector` assertions meaningful.

**Alternatives considered**:
- *Single shared `aria-live="polite"` wrapper for all messages* — rejected: would flatten the success/error urgency distinction (`status` vs `alert`) that both the spec (FR-002, visually distinguishable) and existing tests depend on.

## Decision 4: Auto-dismiss timer with pause-on-hover/focus

**Decision**: The Stimulus controller schedules a `setTimeout` for 3000ms on connect. On `mouseenter`/`focusin`, it clears the pending timeout and records elapsed time; on `mouseleave`/`focusout`, it reschedules a new timeout for the *remaining* time (not a full reset to 3000ms), per the spec Clarifications decision ("pause ... resume"). Manual dismiss (close button click) clears any pending timeout and removes the element immediately.

**Rationale**: Directly implements the spec's clarified FR-003 behavior and satisfies the constitution's accessibility-verification gate (Principle III) by giving keyboard/mouse users reading time instead of a hard 3-second cutoff.

**Alternatives considered**:
- *Restart at full 3000ms on hover-out* — considered but the spec clarification specifically chose "resume" (continue the remaining countdown) over a full restart; restart was Option A's less-precise cousin and not what was confirmed.

## Decision 5: Stacking multiple simultaneous notifications

**Decision**: The fixed-position container is a simple vertical flex stack; each notification is an independent instance of the same Stimulus controller with its own timer. New notifications append to the stack (existing ones are unaffected). No maximum-count cap is introduced (the app realistically never sets more than one `notice` and one `alert` per single redirect today).

**Rationale**: Satisfies FR-007 (present all messages, none silently dropped) with the simplest structure; matches actual current usage (controllers set at most `notice` OR `alert` per redirect, occasionally the same page shows both from a prior Devise step plus a custom redirect — never more than two in practice).

**Alternatives considered**:
- *Queue with a max-visible cap and overflow indicator* — rejected as unnecessary complexity for a case that doesn't occur in current usage (YAGNI, per Constitution Principle I).

## Decision 6: JavaScript-availability baseline

**Decision**: No no-JS fallback rendering path is implemented; per the spec Clarifications, the system may assume JavaScript is always available (consistent with the app's existing reliance on Turbo Drive/Stimulus for other interactive behavior).

**Rationale**: Matches the explicit spec decision; avoids maintaining two parallel rendering paths (static banner + popup) for a case the product doesn't need to support.
