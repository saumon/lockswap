# Phase 0 Research: Streamlined Locker Entry & Pencil-Icon Edit

All Technical Context fields were resolved directly from the existing codebase (Rails 8.1 monolith, Hotwire, Tailwind v4, Minitest/Capybara/Selenium/axe-core) — no NEEDS CLARIFICATION markers remain. The decisions below cover the implementation-shape questions left open by the spec (which intentionally stayed technology-agnostic).

## Decision 1: How to implement the two mutually-exclusive first-entry views

**Decision**: A small, single-purpose Stimulus controller (`locker_entry_choice_controller`) toggles between the "enter locker" view (floor + locker-number fields, the default) and the "I don't have a locker 😔" view (floor field only), and clears the locker-number input's value whenever the "no locker" view is chosen.

**Rationale**: The spec's clarified answer requires that choosing "no locker" both hides the locker-number field *and* not silently carry over a value the user may have already typed into it (declaring "no locker" is only meaningful if a stray typed number doesn't still get submitted). A pure-CSS approach (e.g., radio inputs plus `:has()` selectors) can hide the field visually but cannot clear its value without JavaScript, so the two approaches would have to be combined anyway. A single small Stimulus controller is simpler than a mixed CSS/JS solution and matches the codebase's existing precedent for this kind of interactive-but-simple behavior (`notification_controller.js`).

**Alternatives considered**:
- *CSS-only `:has()` toggle with radio inputs*: rejected — cannot clear the hidden field's value, leaving a latent data-integrity edge case (a typed-then-hidden locker number could still submit).
- *Full page reload per choice (server round-trip)*: rejected — adds latency and complexity for a purely client-side presentational choice; nothing here needs the server to decide which fields to show.

## Decision 2: Where and how the pencil-icon edit control replaces the current disclosure

**Decision**: Keep the existing `<details>`/`<summary>` element (zero-JS, keyboard- and screen-reader-accessible disclosure, already used for this exact purpose per the 002-era code comment), but move it inside `_locker_profile.html.erb`'s card header next to the "Your locker" heading, and replace the summary's visible text ("Edit locker details") with an inline SVG pencil icon and an `aria-label="Edit locker details"` attribute on the `<summary>` element itself — carrying the accessible name directly via the attribute rather than via hidden text, which also avoids Capybara's ambiguous visibility handling of clipped `sr-only` elements in system tests.

**Rationale**: FR-007–FR-009 call for an icon-only control that still exposes an accessible name — `<details>`/`<summary>` already satisfies keyboard operability and exposes its content as the accessible name, so putting the icon (and hidden text) inside it costs nothing new in JS or ARIA wiring. The stylesheet already has a lighter-weight nested-disclosure pattern (`.tile-disclosure` / `.tile-disclosure-summary`) distinct from the heavier standalone `.disclosure` card used today — this feature's icon-only control is a natural extension of that existing "small, quiet, nested" visual language rather than a new pattern, satisfying Constitution Principle III (reuse established patterns).

**Alternatives considered**:
- *A separate JS-driven icon button that shows/hides the form via Stimulus*: rejected — would duplicate the accessibility behavior `<details>` already provides for free, adding a second JS mechanism alongside Decision 1's for no benefit.
- *A modal/dialog for editing*: rejected — bigger UX and accessibility surface (focus trapping, dedicated close affordance) for no requirement in the spec; the existing inline-reveal pattern already works and User Story 2 only asks to change the trigger, not the reveal mechanism.

## Decision 3: Inline SVG vs. an icon font/library for the pencil glyph

**Decision**: Hand-author a small inline SVG pencil icon directly in the view partial, `aria-hidden="true"`, sized via the existing spacing scale.

**Rationale**: Matches the project's established icon convention from 008 (`app/views/shared/_brand_mark.html.erb` is a hand-authored inline SVG) and avoids adding any new dependency (no icon font, no CDN, consistent with the importmap-only JS setup and the CSP-conscious "vendor everything" approach already used for the brand typeface).

**Alternatives considered**:
- *An icon font or an external icon package*: rejected — new dependency for a single glyph; inline SVG is smaller and already the house style.

## Decision 4: No backend/contract changes

**Decision**: Reuse `PATCH /locker_profile` (`LockerProfilesController#update`) and its `user[floor]` / `user[locker_number]` params unchanged; no new endpoint, param, or persisted attribute is introduced for "declared no locker" — it is represented the same way it already is (a blank/nil `locker_number`), per the spec's assumptions.

**Rationale**: The spec explicitly scopes this feature to how the *choice* is presented, not to the underlying data model; a first-time user choosing "I don't have a locker 😔" and a later user clearing the locker-number field both need to produce the identical, already-validated "no locker" state.

**Alternatives considered**:
- *Adding a `has_locker` boolean or similar declared-intent flag*: rejected — no requirement calls for distinguishing "declared no locker" from "just has a blank locker number"; doing so would add schema and validation surface the spec never asks for.
