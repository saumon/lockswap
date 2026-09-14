# Phase 0 Research: Visual Identity & Modern White-Theme Refresh

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-14

Every decision below was verified against the installed gems and the live network rather than recalled. Where a claim was checked, the check is stated.

---

## D1 — Design tokens live in Tailwind v4's `@theme` block

**Decision**: Express all tokens as CSS custom properties inside `@theme { … }` in `app/assets/tailwind/application.css`. No `tailwind.config.js`.

**Rationale**: The project runs `tailwindcss-ruby` 4.3.3 (verified in `Gemfile.lock`), and Tailwind v4 is CSS-first: `@theme` both defines the custom property and generates the matching utilities, so `--color-brand-navy` yields `bg-brand-navy`, `text-brand-navy`, `border-brand-navy` automatically. One declaration produces both the token and its utilities, which is exactly the "single source" FR-009 asks for.

**Alternatives considered**: A JS config file — v4 supports it via `@config` but it is legacy, splits the source of truth across two languages, and buys nothing here. Raw CSS variables without `@theme` — would define the values but generate no utilities, forcing `[color:var(--x)]` arbitrary values throughout the templates.

---

## D2 — All new CSS goes in the Tailwind entrypoint, never in `app/assets/stylesheets/application.css`

**Decision**: `app/assets/tailwind/application.css` is the only file edited. `app/assets/stylesheets/application.css` stays the comment-only manifest it is today.

**Rationale**: Verified in `propshaft-1.3.2/lib/propshaft/helper.rb` — `stylesheet_link_tag :app` expands to *every* CSS file under `app/assets/**/*.css` and emits a separate `<link>` for each. The layout would therefore load both `builds/tailwind.css` and `stylesheets/application.css`, and which one wins depends on emitted link order. Keeping everything in the single compiled file removes that dependency entirely rather than reasoning about it.

Verified that `app/assets/tailwind` is excluded from the Propshaft load path by `Tailwindcss::Engine`, so the entrypoint is never served raw — only its compiled output.

---

## D3 — Nunito, self-hosted, variable, latin subset

**Decision**: Nunito variable (weights 200–1000) in a single self-hosted `.woff2`, latin subset.

**Rationale**:
- **Character match.** The artwork's letterforms are a heavy geometric sans with circular bowls and softly rounded terminals. Nunito is the closest widely-available match, and critically it is *rounded* — Poppins and Outfit are geometric but have flat, cut terminals, which reads colder than the logo.
- **One file covers everything.** The variable axis spans 200–1000, so the light tagline and the extra-bold wordmark come from the same 39KB download. A static-weight family would need three or four separate files.
- **Measured, not estimated.** Fetched the Google Fonts CSS and then the latin `.woff2` itself: **39,152 bytes**, `font/woff2`. That is the entire type budget.
- **Licence.** SIL OFL 1.1 — self-hosting and redistribution are permitted, provided `OFL.txt` ships alongside the font. That file is listed in the plan's structure for exactly this reason.

**Self-hosting rationale** (settled in the spec's clarification, recorded here for completeness): a third-party font host receives the IP address of every visitor, which EU courts have treated as a GDPR violation for EU-facing sites, and this product is French-facing. It also adds a DNS lookup and TLS handshake to a second origin on the critical render path, which SC-008 forbids regressing. Note that `config/initializers/content_security_policy.rb` is entirely commented out, so no CSP change is needed either way — self-hosting is chosen on privacy and performance grounds, not CSP.

**Alternatives considered**: Quicksand (too light and geometric at heavy weights); Baloo 2 (rounder than the artwork, and its heavy weights are cartoonish); Poppins (right geometry, wrong terminals); system font stack (zero bytes but abandons FR-005 entirely).

---

## D4 — `app/assets/fonts/` needs no configuration

**Decision**: Create `app/assets/fonts/` and put the `.woff2` in it. No `assets.paths` entry.

**Correction.** This entry first claimed the opposite — that a new directory under `app/assets` is *not* picked up and must be registered explicitly, "the single easiest thing to get wrong in the whole feature" — and the feature shipped with a redundant `config.assets.paths <<` line on that basis. The claim was wrong, and the way it was reached is worth recording: the live path list was printed **before** `app/assets/fonts` existed, so of course it was absent, and the line added straight afterwards appeared to be what fixed it.

What actually settled it: creating `app/assets/brand/` for an unrelated reason and finding it already on the load path, having registered nothing. **Propshaft globs every subdirectory of `app/assets`.** The explicit line was removed and the font still resolves to `/assets/nunito-latin-variable-a6de09cc.woff2`.

**What remains true** is the failure mode in D5: an unresolvable `url()` is logged at warn level and shipped unrewritten rather than raising, so a font that does not resolve produces a working build and a silently broken face. That is still worth the explicit check in the quickstart — just not for the reason first given.

---

## D5 — Referencing the font from CSS

**Decision**: In `@font-face`, write `src: url("nunito-latin-variable.woff2") format("woff2");` — a bare filename, no path.

**Rationale**: Read `propshaft-1.3.2/lib/propshaft/compiler/css_asset_urls.rb`. For a bare filename, `resolve_path` joins it to the asset's own logical dirname. The compiled stylesheet's logical path is `tailwind.css`, whose dirname is `.`, so the resolved lookup is `nunito-latin-variable.woff2` against the whole load path — which D4 has just made resolvable. The compiler then rewrites it to the digested URL.

**Failure mode worth knowing**: if resolution fails, `asset_url` logs `Unable to resolve …` at warn level and emits the *original* unrewritten URL. It does not raise. A misconfigured font path therefore ships a silently broken font rather than failing the build, which is why `quickstart.md` includes an explicit assertion that the served CSS contains a digested font URL.

---

## D6 — Mark as inline SVG, wordmark as live HTML text

**Decision**: Split the brand across two media. The two-locker exchange **mark** is SVG rendered inline via a partial. The **wordmark** "LockSwap" is real HTML text styled with the brand typeface and the two-tone colour split.

**Update after review**: the mark was first hand-authored from the artwork by eye, and it was not faithful enough. It is now a **trace of the supplied artwork itself** — the crop is separated into its eight flat colour regions by nearest-colour assignment, each region vectorised with potrace, and the layers reassembled with the two door faces and the two arrows carrying the gradients the original has. The shapes, the perspective and the palette are the artwork's own rather than an approximation of it. The cost is size: roughly 16KB of path data inline, about 6.8KB gzipped, against roughly 2KB for the drawing it replaced.

**Rationale**:
- **It keeps the existing test passing.** `test/system/navigation_test.rb` does `click_on "LockSwap"`. Capybara matches links by visible text; matching by `aria-label` requires `Capybara.enable_aria_label = true`, which this project does not set. An image-only brand link would break that test and force exactly the kind of test rewrite FR-029 is designed to discourage.
- **FR-027's fallback comes for free.** If the SVG fails to render there is still a styled, correctly-coloured, clickable text wordmark — no `onerror` handling, no second asset.
- **No font-to-path conversion.** Outlining the wordmark into SVG paths would need a font tooling step in the build; live text needs none, stays selectable, scales with the type scale, and is natively announced by screen readers (FR-007).
- **Inline, not `<img>`.** The mark must recolour with tokens and animate its arrows (FR-022); an external `<img>` can do neither.

**Consequence**: the mark alone — no text — is what becomes the favicon and app icon, which is correct anyway at 16–32px where a wordmark is illegible.

**Alternatives considered**: A single SVG containing outlined wordmark text (breaks `click_on`, needs font tooling, not selectable); an `<img>` tag with alt text (no recolouring, no animation, and `click_on` would depend on alt text matching).

---

## D7 — The brand green fails contrast as functional text, so the palette splits in two

**Decision**: Keep the authentic artwork colours for the brand itself, and derive a separate set of accessible tokens for functional UI. Specifically, `--color-brand-green: #0AB486` is used **only** in the logo and for decorative fills; `--color-brand-green-ink: #07795A` is used for every piece of green text, every green button fill behind white text, and any green that carries meaning.

**Rationale**: This is the sharpest tension in the feature, and it is real. Computed WCAG 2.1 ratios against white:

| Token | Ratio on white | AA text (4.5:1) | AA large / UI (3:1) |
|---|---|---|---|
| Brand navy `#0E2A47` | 14.57:1 | PASS | PASS |
| Brand green `#0AB486` | **2.66:1** | **FAIL** | **FAIL** |
| Brand blue `#0A77F1` | 4.27:1 | **FAIL** | PASS |
| Locker blue face `#2588F3` | 3.56:1 | FAIL | PASS |
| Locker green face `#41D5A5` | 1.86:1 | FAIL | FAIL |

The brand green fails even the 3:1 non-text threshold, so it cannot carry meaning as an icon or border either, and white text on a `#0AB486` button is 2.66:1 — nowhere near legible. FR-002 demands the artwork's green for the wordmark while FR-023 and SC-004 demand zero contrast failures; taken naively these contradict.

**Resolution**: WCAG 2.1 SC 1.4.3 explicitly exempts logotypes — *"Text that is part of a logo or brand name has no contrast requirement."* The wordmark is therefore compliant at the authentic colour, and no compromise of brand fidelity is needed. Everything that is *not* the logo uses the derived ink tokens.

**Practical consequence for the axe suite**: axe-core cannot know an element is a logotype, so it will flag the wordmark's `color-contrast`. The accessibility test excludes the brand lockup from that one rule, scoped to that element only, with an inline comment citing SC 1.4.3 — which is precisely the form of documented suppression the constitution's Code Quality principle requires.

**Derived accessible tokens** (all verified by computation):

| Purpose | Value | Ratio | Check |
|---|---|---|---|
| Green text / green fill behind white | `#07795A` | 5.40:1 | PASS |
| Green fill hover | `#06684D` | 6.79:1 | PASS |
| Link / accent blue | `#0A5AC2` | 6.45:1 | PASS |
| Muted body text | `#50607A` | 6.37:1 | PASS |
| Success badge `#07795A` on `#E6F7F1` | — | 4.87:1 | PASS |
| Error badge `#9F1239` on `#FFE4E6` | — | 6.68:1 | PASS |
| Info badge `#0A5AC2` on `#E3EDFD` | — | 5.47:1 | PASS |

---

## D8 — `axe-core-api` only; not `axe-core-capybara`

**Decision**: Add `gem "axe-core-api"` to the `:test` group. Do **not** add `axe-core-capybara`.

**Rationale**: Unpacked both gems (4.13.0) and read their sources.
- `axe-core-capybara` is a convenience configurator whose `set_driver` reassigns `Capybara.default_driver` and `Capybara.javascript_driver` and constructs its own `Capybara::Selenium::Driver`. This project already sets `driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]` in `ApplicationSystemTestCase`; letting the gem override that would discard the headless configuration and the screen size the existing tests depend on.
- `axe-core-api` alone is sufficient. `Axe::Core#wrap_driver` unwraps anything responding to `:driver`, so Capybara's `page` can be handed straight in. `Capybara::Selenium::Driver` responds to both `execute_script` and `evaluate_script`, so it takes the `ExecEvalScriptAdapter2` path — compatible as-is.
- The gem **bundles `node_modules/axe-core/axe.min.js`** and loads it from its own gem dir (`Axe::Configuration#jslib_path`). No npm, no importmap pin, no vendored JS.

**Minitest assertion shape** — there is no official Minitest matcher (the `be_axe_clean` matcher is RSpec-only), so the helper wraps the plain API:

```ruby
run   = Axe::API::Run.new.according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
audit = Axe::Core.new(page).call(run)
assert audit.passed?, audit.failure_message
```

`Audit#passed?` is `results.violations.count == 0` and `#failure_message` renders the violating nodes, so failures report which element broke which rule rather than just "false".

**Alternatives considered**: Injecting `axe.min.js` by hand via `execute_script` (reimplements the gem, including its iframe and `runPartial` handling); `axe-core-rspec` (wrong test framework).

---

## D9 — Motion is pure CSS

**Decision**: No animation library. Transitions on component classes, one keyframe entrance, one keyframe logo flourish.

**Rationale**:
- **Turbo makes the entrance free.** Turbo Drive replaces `<body>` on navigation, so a CSS animation bound to the content wrapper re-runs on every page render with no JavaScript and no Stimulus controller.
- **Turbo makes the in-progress state free too.** `data-turbo-submits-with` on a submit button is native to turbo-rails 2.x and swaps the button's label while the form is in flight — FR-018 satisfied without custom code.
- **Compositor-only properties.** Animation is restricted to `transform` and `opacity`. Nothing animates `width`, `height`, `top`, or `box-shadow`, which are the usual causes of the scroll jank FR-021 forbids.
- Importmap already carries Stimulus; adding a motion library would mean a new pin and new bytes for behaviour CSS handles natively.

**Reduced motion** (FR-020): a single global block, rather than per-component opt-outs that get forgotten:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

Near-zero rather than `none` so that `animationend`/`transitionend` listeners still fire and nothing depends on an event that never arrives. FR-016b independently requires content to be visible regardless, so entrance animations must animate *from* a visible state or set their final state outside the keyframe.

---

## D10 — Icons and manifest

**Decision**: Replace `public/icon.svg` and `public/icon.png` with the mark; fix `app/views/pwa/manifest.json.erb`.

**Rationale**: `public/icon.svg` is currently a red circle placeholder (`<circle … fill="red"/>`) and the manifest declares `"theme_color": "red"` and `"background_color": "red"` with a description of `"LockSwap."`. All of it is Rails scaffolding that was never updated, and FR-006 covers it. Theme colour becomes brand navy, background white.

The maskable icon entry needs the mark inset within the safe zone — a maskable icon is cropped to a circle on Android, and a mark drawn edge-to-edge loses its arrows.

---

## D11 — Restructuring is safe because the tests key off ids

**Decision**: Take the layout freedom FR-015a grants, constrained by an explicit preserved-DOM contract.

**Rationale**: Audited every selector in the system suite. The tests reference **stable DOM ids** (`#swap-proposals-received`, `#locker-profile-floor`, `#swap-proposal-history-row-<id>`, and so on), ARIA roles (`[role=status]`, `[role=alert]`), the `<main>` element, and two `<summary>` labels — but **not a single CSS class**. Class-level restyling is therefore entirely free, and structural change is safe as long as that specific surface survives.

Two structural constraints follow and are non-negotiable:
- The `<details>`/`<summary>` disclosures must stay disclosures. Tests do `find("summary", text: "Edit locker details")` and `find("summary", text: "Decline")`. They are also already the accessible, JS-free choice, and the existing view comments say so — replacing them with a Stimulus toggle would be a regression in both senses.
- `<main>` must remain, and the flash overlay must keep taking no layout space. `notification_test.rb` measures `find("main").native.rect` before and after a notification and asserts the rectangle is identical, so the flash must stay `fixed`.

The full surface is enumerated in [contracts/preserved-dom.md](./contracts/preserved-dom.md).

---

## Open questions

None. No `NEEDS CLARIFICATION` remains from the Technical Context.
