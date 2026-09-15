# Phase 0 Research: Looping Logo Fade Animation

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-15

No Technical Context field was left as `NEEDS CLARIFICATION` — this is a small, self-contained CSS/view change in a codebase whose motion conventions are already established (feature 008). The decisions below resolve the "how" for each functional requirement rather than filling stack-choice gaps.

---

## D1: Visual form of the loop

**Decision**: A new `@keyframes brand-fade-pulse` that only moves `opacity`, between `1` and `0.6`, via a `0%, 100% { opacity: 1; } 50% { opacity: 0.6; }` keyframe run with `animation-iteration-count: infinite`.

**Rationale**: Confirmed with the user during `/speckit-specify` — the loop must read as a calm "breathing" pulse, not a repeat of the existing `brand-fade-in` entrance (which also moves `filter: blur()` and `transform: scale()`, and is written to run exactly once with `both` fill). Looping `brand-fade-in` itself would restart from a blurred, scaled-down frame every ~1.1s forever, which is jarring rather than eye-catching, and would violate the stylesheet's own transform/opacity-only rule for anything that isn't a one-off static-screen flourish.

**Alternatives considered**:
- Looping the existing `brand-fade-in` keyframes with `infinite`: rejected — restarts from blur/scale every cycle, visually jarring, and the codebase's comment on that rule explicitly treats "a logo that fades in on every navigation" as a defect ("a tic, not a flourish"), which a looped blur-in would effectively become.
- `animation-direction: alternate` on a two-frame `0%/100%` keyframe: equivalent in the browser to the `50%` midpoint approach chosen, but harder to reason about when composed with a second, entrance animation in the same `animation` shorthand list (see D4) — an explicit midpoint keyframe keeps both animations' timelines independent and easy to read in one declaration.

## D2: Opacity floor and cycle duration

**Decision**: Dim to ~60% opacity at the pulse's low point; one full cycle (full → dim → full) takes ~3 seconds.

**Rationale**: Confirmed with the user during `/speckit-clarify`. 60% keeps the logo clearly, continuously legible (never approaches the near-invisible range that would fail FR-008/edge-case "never fully disappear") while still being visually obvious enough to "attract the eye" per the feature's stated purpose. A 3-second cycle reads as deliberate and calm rather than anxious (a ~1.5s cycle) or barely perceptible (a ~5s cycle) — appropriate for an animation that, per D3, runs indefinitely on every page.

**New token**: `--motion-brand-loop: 3000ms`, declared alongside the existing `--motion-brand: 1100ms` / `--motion-flourish: 900ms` tokens in the `:root` motion block, following the codebase's existing pattern of one named duration per distinct animation rather than a bare literal in the rule.

## D3: Loop scope and duration of run

**Decision**: The loop runs indefinitely on both surfaces (sign-in/sign-up mark, header mark), on every page, for as long as the element is visible — no fixed cycle count, no fade-out-after-N-seconds behavior, and no dedicated on-screen pause/stop control beyond the existing `prefers-reduced-motion` mechanism.

**Rationale**: Confirmed with the user during `/speckit-clarify`, matching the literal request ("tourne en boucle"). A dedicated pause control was considered and explicitly rejected by the user as disproportionate UI for a small decorative brand element; the existing reduced-motion opt-out (already required sitewide by FR-020 in feature 008) remains the sole way to stop it, which is consistent with how every other animation in this stylesheet is gated — there are no per-component opt-outs elsewhere either.

**Alternatives considered**:
- A visible pause/stop affordance near the logo (WCAG 2.2.2-style control): rejected by explicit user choice — out of proportion for this element, and inconsistent with the site's existing "one global switch" approach to motion (see the stylesheet's own comment on the reduced-motion block: "One global switch rather than per-component opt-outs, which get forgotten").
- Looping only for a limited time (e.g., a few cycles after each page load) then settling static: rejected by explicit user choice in favor of matching the literal, indefinite request.

## D4: Composing the loop with the existing one-shot entrance

**Decision**: Introduce a `.brand-mark-loop` class carrying the pulse animation on its own (`animation-delay: 0s`, i.e. the default — starts immediately). Where an element carries **both** `.brand-mark-flourish` (the existing one-shot entrance) and `.brand-mark-loop` (the sign-in/sign-up mark), a more specific compound-selector rule — `.brand-mark-flourish.brand-mark-loop` — declares **both** animations together in a single `animation` shorthand list, with the loop's `animation-delay` set to `var(--motion-brand)` (1100ms) so it starts exactly when the entrance's `both`-held final frame is reached:

```css
.brand-mark-loop {
  animation: brand-fade-pulse var(--motion-brand-loop) ease-in-out infinite;
}

.brand-mark-flourish.brand-mark-loop {
  animation:
    brand-fade-in var(--motion-brand) var(--ease-brand) 1 both,
    brand-fade-pulse var(--motion-brand-loop) ease-in-out infinite;
  animation-delay: 0s, var(--motion-brand);
}
```

**Rationale**: The CSS `animation` shorthand is not additive across separate rules matching the same element — whichever matching rule wins the cascade replaces the *entire* animation list, it does not merge lists from two different rules. Since the sign-in/sign-up mark needs both animations running (sequentially, not overlapping — FR-006), the combined declaration has to live in one rule that fires only when both classes are present; higher selector specificity (two classes vs. one) makes that rule win over the plain `.brand-mark-loop` rule automatically, with no `!important` and no `:not()` needed.

**Alternatives considered**:
- Driving the hand-off with a JS `animationend` listener that adds the loop class once the entrance finishes: rejected — adds a Stimulus controller and a moving part for something CSS timing alone already expresses exactly, and the codebase's stated approach to motion is "CSS-first, JS only where CSS cannot express it" (see the mark's own inline-SVG rationale: "an external image cannot be driven by the stylesheet" is the *only* place JS-adjacent complexity was accepted, and only because of the image-vs-inline constraint, not for timing).
- Two independent `animation-name`/`animation-duration`/… longhand properties instead of the shorthand, to avoid the "shorthand replaces the whole list" gotcha entirely: possible, but the shorthand form is what the rest of this stylesheet already uses everywhere else (`animation: name duration ease count fill`), and splitting only this one rule into five longhand declarations would be the kind of inconsistency Principle I flags for reviewer pushback.

## D5: Arming the header mark

**Decision**: Add a `pulse` local to `shared/_brand_mark.html.erb`, sibling to the existing `flourish` local, defaulting to `false`. It appends `brand-mark-loop` to the SVG's `class` attribute independently of `flourish`. `shared/_brand_lockup.html.erb` (the header's horizontal lockup) renders the mark with `pulse: true` (and, as today, no `flourish:` — the header must never carry the one-shot entrance). `shared/_brand_stacked.html.erb` (sign-in/sign-up) is a raster `<img>`, not the `_brand_mark` partial, so it gets `brand-mark-loop` added directly to its existing `class="brand-mark brand-mark-flourish"` attribute.

**Rationale**: Mirrors the existing `flourish` local exactly — same partial, same "boolean local arms a modifier class" shape, same doc-comment convention at the top of the file. Keeping `flourish` and `pulse` as two independent locals (rather than collapsing them into one enum-like local) lets each of the three call sites (header: pulse only; sign-in/sign-up img: both; anywhere else the mark might render standalone in future, e.g. favicon-adjacent contexts: neither) express exactly the combination it needs without a hidden coupling between "has an entrance" and "loops forever."

## D6: Reduced motion

**Decision**: Both the `.brand-mark-loop` rule and the `.brand-mark-flourish.brand-mark-loop` compound rule are declared inside the stylesheet's existing `@media (prefers-reduced-motion: no-preference)` block, alongside the current `.brand-mark-flourish` rule — not left to the separate global `@media (prefers-reduced-motion: reduce) { * { animation-duration: 0.01ms !important; animation-iteration-count: 1 !important; ... } }` override to neutralize them.

**Rationale**: This matches the codebase's own stated preference for the explicit-scoping approach over relying on the global `!important` override, and keeps a single, consistent pattern for every animation this stylesheet declares: reduced-motion visitors get *no animation declared at all* for the brand mark, rather than one iteration of a flattened-to-0.01ms animation. Functionally the two approaches would both resolve to a static, fully-opaque logo here (unlike the blur-in entrance, the pulse never starts below full opacity, so there is no failure mode where a stalled first frame would leave it invisible) — but explicit scoping is the established, load-bearing pattern in this file and diverging from it for only this one rule would be inconsistent for no benefit.

## D7: A pre-existing test helper assumes no animation ever runs indefinitely

**Decision**: `test/application_system_test_case.rb`'s private `wait_for_entrance` helper (used by every `assert_axe_clean` call, which per FR-028 runs on essentially every system test) must stop waiting on animations that never finish, by filtering them out of the check:

```diff
- return document.getAnimations().every(a => a.playState !== "running");
+ return document.getAnimations()
+   .filter(a => a.effect.getTiming().iterations !== Infinity)
+   .every(a => a.playState !== "running");
```

**Implementation note (2026-09-15)**: this was first specified as narrowing the query to `el.getAnimations()` (the `.page-enter` element's own animations). That was wrong and was corrected during implementation: the entrance is staggered across *descendants* of `.page-enter` — the sign-in tagline starts 340ms in and is real text the colour-contrast audit reads — so scoping to the wrapper would have returned after ~320ms, mid-fade, and risked exactly the false contrast failures the helper exists to prevent. Excluding infinite animations keeps the original document-wide intent while dropping only the animations that have no settled state to wait for.

**Rationale**: Today this is a latent bug with no observable effect, because nothing on any page runs an animation longer than the `.page-enter` entrance itself finishes settling. Once the header mark carries an infinite-duration pulse (present on essentially every signed-in page, per FR-003), `document.getAnimations().every(...)` can never become `true` again — the helper will always fall through to its 5-second deadline instead of returning as soon as the actual entrance settles. That does not break correctness (the audit still eventually runs, at the now-final opacity), but it silently adds up to 5 seconds to *every* `assert_axe_clean` call across the system suite, which is exactly the kind of unmeasured regression Principle IV (Performance Requirements) says must not ship unexamined. Fixing the helper to scope to the entrance element's own animations is a one-line, low-risk change that restores the original fast-path behavior and is required as part of this feature rather than filed separately, since this feature is what exposes the bug.

**Measured (2026-09-15)**: with the fix, `test/system/accessibility_test.rb` runs 19 tests in 21.7s. With the fix reverted and the header pulse present, 12 of those same tests took 64.1s — ~5.3s of dead wait per `assert_axe_clean` call, matching the helper's 5-second deadline exactly. The premise held.

**Scope note**: This is a test-infrastructure correctness fix coupled to this feature, not a product-code change and not a Constitution Check violation requiring a Complexity Tracking entry — it is included here because leaving it out would mean this feature ships a measurable, silent CI slowdown.

## D8: Existing assertions that this feature deliberately contradicts

**Decision**: Two existing tests in `test/system/motion_test.rb` assert the exact behavior this feature reverses, and must be rewritten (not deleted, not skipped) as part of implementation:

- `"the flourish must play once, never loop (FR-022)"` — currently asserts `getComputedStyle(...).animationIterationCount == "1"` on `.brand-mark-flourish`. Once that element carries two animations (D4), `animationIterationCount` reports a comma-separated list (`"1, infinite"` in source order). The rewritten test must assert the *entrance* animation specifically still runs once, and separately assert the *loop* animation runs `infinite` — proving both halves of the new behavior rather than just deleting the old guarantee.
- `"the header mark does not fade"` — currently asserts `getComputedStyle(document.querySelector('header [data-brand-mark]')).animationName == "none"`. This is now false by design (FR-003); the rewritten test must assert the header mark's animation is the new loop (`brand-fade-pulse`, `infinite`), not that it has none.
- `"the logo fades in on the sign-in screen and settles"` — its wait loop (`document.getAnimations().every(a => a.playState !== 'running')`) has the identical problem as D7 once the sign-in mark also carries the infinite loop after its entrance: it will never see "every animation not running" and will always hit its own `Timeout.timeout(5)`. It must instead wait specifically for the entrance animation (filterable by `a.animationName === "brand-fade-in"` or by scoping to the element and ignoring the still-running loop) to finish before sampling final opacity/blur.

**Rationale**: Constitution Principle II is explicit that tests are the primary evidence the product works, and that they must be fixed rather than silenced when behavior intentionally changes. These three assertions are the direct, textual embodiment of the "never loop" / "header never fades" decisions from feature 008 that this feature is asked to reverse; leaving them red (or deleting them) would either block merge or quietly remove the only regression coverage for the *entrance* half of the behavior, which the spec (FR-006) still requires to keep working.

**Out of scope for this document**: the exact new assertions and any additional coverage (e.g., a system test for the header pulse itself, and one for reduced-motion suppression of both surfaces) are enumerated as concrete test tasks in `tasks.md` by `/speckit-tasks`, not designed here.
