# Implementation Plan: Visual Identity & Modern White-Theme Refresh

**Branch**: `008-visual-identity-refresh` | **Date**: 2026-09-14 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/008-visual-identity-refresh/spec.md`

## Summary

Give LockSwap a brand and a coherent white-theme visual system, then layer restrained motion on top.

The approach is deliberately conservative in machinery and ambitious in output. Everything is expressed through the stack already in the repo: Tailwind v4's CSS-first `@theme` block becomes the single source of design tokens, component classes replace the repeated utility strings currently copy-pasted across 22 ERB templates, and motion is pure CSS with one global reduced-motion kill switch. No JavaScript animation library, no build-step additions, no new runtime dependency.

The brand is split by medium rather than baked into one asset: the two-locker exchange **mark** is hand-authored inline SVG (scales perfectly, animatable, no font dependency), while the **wordmark** stays live HTML text set in the brand typeface. That split is what keeps `click_on "LockSwap"` working in the existing navigation test, gives FR-027's text fallback for free, and keeps the brand selectable and screen-reader-native instead of an image with alt text.

The one new dependency is `axe-core-api` in the test group, which turns FR-023–FR-025 from prose into assertions that run in the standard suite.

## Technical Context

**Language/Version**: Ruby 3.4.6, Rails 8.1.3.1

**Primary Dependencies**: Propshaft 1.3.2 (assets), tailwindcss-rails 4.6.0 / Tailwind CSS 4.3.3, importmap-rails 2.2.3, Turbo 2.0.23, Stimulus 1.3.4, Devise 5.0

**New Dependencies**: `axe-core-api` 4.13.0 (test group only — bundles its own `axe.min.js`, no npm). Nunito variable font files vendored into the repo (SIL OFL 1.1).

**Storage**: SQLite via Active Record — untouched by this feature. No migration, no schema change, no query change.

**Testing**: Minitest + Capybara 3.40 + selenium-webdriver 4.49 against headless Chrome. System suite runs single-worker (`parallelize(workers: 1)`) with `Capybara.default_max_wait_time = 5`. `tailwindcss:build` is already chained onto `test:prepare`, so system tests always run against freshly compiled CSS.

**Target Platform**: Server-rendered web app; current evergreen desktop and mobile browsers.

**Project Type**: Rails monolith, server-rendered ERB with Hotwire. No separate frontend.

**Performance Goals**: No regression in first meaningful paint (SC-008). Interaction feedback settles ≤200ms, page entrance completes ≤400ms (FR-019). Animation confined to compositor-friendly properties so scrolling holds 60fps on mid-range hardware (FR-021).

**Constraints**:
- Total added asset weight budget **≤50KB gzipped**. The Nunito latin variable subset is 39KB and covers weights 200–1000 in one file; the mark SVG is ~2KB inline. This is the whole budget spent.
- **Zero third-party origins at page load** (FR-005a, SC-008a).
- **No third-party request at page load** means the font is vendored, not linked.
- 22 ERB templates / 752 lines of view code is the entire restyle surface.

**Scale/Scope**: 12 user-facing screens, 22 ERB templates, 1 layout, 1 Stimulus controller. Small enough that the restyle is bounded and reviewable in one pass.

## Constitution Check

*GATE: evaluated before Phase 0 and re-evaluated after Phase 1 design. Both passes recorded.*

### I. Code Quality — PASS

The current templates repeat the same ~120-character Tailwind utility string for every button, field, and card. That is duplicated logic by any reasonable reading, and the constitution requires it be refactored rather than repeated. This plan's component-class layer (`contracts/component-contract.md`) is the refactor: one definition per element, reused everywhere. `rubocop-rails-omakase` must stay clean; ERB is not linted by it, so template consistency is enforced by the component contract instead. The token block and each component class carry a comment explaining intent, matching the density already present in this codebase's views.

### II. Testing Standards (NON-NEGOTIABLE) — PASS

Per the spec's clarification, test evidence is automated accessibility assertions on every screen plus the existing suite staying green.

- New `test/system/accessibility_test.rb` runs axe against all 12 screens, checking `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`. These fail before the work (the current palette has contrast failures) and pass after — satisfying "fail without the change, pass with it".
- Existing 10 system tests + 3 controller tests + 3 model tests must stay green. FR-029 forbids weakening or deleting an assertion; a test broken by restructuring gets updated to assert the same behaviour.
- Tests are deterministic: axe runs against a settled page and the suite is single-worker, so no flake is introduced.
- Coverage of core business logic does not move — no business logic is touched.

### III. User Experience Consistency — PASS

This principle *is* the feature. Terminology is unchanged by FR-015. Accessibility is verified automatically rather than by assertion in a PR description, which is stronger than the constitution asks for. The one user-visible addition (the tagline, FR-003a) is called out explicitly as required for breaking changes.

### IV. Performance Requirements — PASS WITH REQUIRED EVIDENCE

This feature adds bytes to the critical path for the first time in the project's history, so Principle IV applies directly and its evidence requirement is **not** waived:

- Before/after first-contentful-paint measurement is required in the PR (SC-008).
- Asset weight budget is stated above and is the governing number.
- No query, loop, or request-path change, so no latency or N+1 risk.
- Animation is restricted to `transform`/`opacity` to stay off the layout/paint path (FR-021).

**Gate result (pre-Phase 0): PASS. No violations, so Complexity Tracking is omitted.**

### Re-evaluation after Phase 1 design — PASS

Design surfaced one genuine tension and one governance note; neither is a violation.

**Tension (resolved):** FR-002 requires the artwork's green in the wordmark, while FR-023/SC-004 require zero contrast failures — and brand green `#0AB486` measures 2.66:1 on white, failing even the 3:1 non-text bar. Resolved on standards grounds rather than by compromise: WCAG 2.1 SC 1.4.3 exempts logotypes, so the wordmark is compliant at the authentic colour, and a separate `--color-brand-green-ink` (`#07795A`, 5.40:1) carries every functional green. The one axe exclusion this needs is scoped to the brand element, limited to the `color-contrast` rule, and carries an inline comment citing the exemption — the documented-suppression form Principle I requires, not a silent bypass. See [research.md](./research.md) D7.

**Governance note:** the constitution's Development Workflow names `master` as the integration branch; this repository uses `dev`, and the feature branch does not yet exist (the session is still on `dev`). Worth reconciling in the constitution or the workflow, but it does not block this feature.

**Per-principle after design:**

- **I. Code Quality** — the component layer removes ~120-character utility strings duplicated across 22 templates; net reduction in repetition. One suppression, documented.
- **II. Testing Standards** — `accessibility_test.rb` fails before the change (current palette has contrast failures) and passes after. Existing suite preserved; [contracts/preserved-dom.md](./contracts/preserved-dom.md) exists specifically so restructuring does not force test rewrites. Deterministic: single-worker, no new timing dependency.
- **III. UX Consistency** — accessibility is machine-verified per screen rather than asserted in a PR description. The single user-visible addition (tagline) is called out as the breaking-change disclosure requires.
- **IV. Performance** — 39KB measured, budget stated, FCP evidence required in the PR, animation restricted to compositor properties. No query or request-path change.

**Re-check result: PASS.**

## Project Structure

### Documentation (this feature)

```text
specs/008-visual-identity-refresh/
├── plan.md              # This file
├── research.md          # Phase 0 — technical decisions with rationale
├── data-model.md        # Phase 1 — the design token system
├── quickstart.md        # Phase 1 — how to run and validate
├── contracts/
│   ├── brand-assets.md      # Mark, lockups, icons, clear space, minimum sizes
│   ├── component-contract.md # One treatment per UI element, all states
│   └── preserved-dom.md      # The DOM surface the test suite depends on
├── checklists/
│   └── requirements.md  # Spec quality checklist (16/16)
└── tasks.md             # Phase 2 — created by /speckit-tasks, NOT by this command
```

### Source Code (repository root)

```text
app/
├── assets/
│   ├── fonts/                       # NEW — must be added to config.assets.paths
│   │   ├── nunito-latin-variable.woff2
│   │   └── OFL.txt                  # SIL OFL 1.1, required by the licence
│   ├── images/
│   │   └── brand/                   # NEW — standalone mark for non-inline use
│   ├── tailwind/
│   │   └── application.css          # REWRITTEN — @theme tokens, @font-face, components
│   └── builds/tailwind.css          # generated; never edited by hand
├── javascript/controllers/
│   └── notification_controller.js   # unchanged behaviour; styling only
└── views/
    ├── shared/                      # NEW — brand partials
    │   ├── _brand_mark.html.erb     # inline SVG, the two-locker exchange mark
    │   ├── _brand_lockup.html.erb   # mark + wordmark, header
    │   └── _brand_stacked.html.erb  # mark over wordmark over tagline, auth pages
    ├── layouts/
    │   ├── application.html.erb     # header rebuilt around the lockup
    │   └── _flash.html.erb          # restyled; roles and Stimulus wiring preserved
    ├── devise/                      # 5 templates restyled
    ├── home/                        # 6 templates restyled
    ├── locker_wishes/               # 4 templates restyled
    ├── locker_swap_proposals/       # 1 template restyled
    └── pwa/manifest.json.erb        # theme colours, icon entries

config/initializers/assets.rb        # add app/assets/fonts to the load path

public/
├── icon.svg                         # REPLACED — currently a red circle placeholder
└── icon.png                         # REPLACED — rendered from the mark

test/
├── application_system_test_case.rb  # add assert_axe_clean helper
└── system/
    └── accessibility_test.rb        # NEW — axe across all 12 screens

Gemfile                              # axe-core-api in the :test group
```

**Structure Decision**: Standard Rails monolith, no new top-level directories. Two additions inside existing conventions: `app/assets/fonts/` (needs an explicit `assets.paths` entry — verified, Propshaft does not pick it up automatically) and `app/views/shared/` for the three brand partials. Everything else is an edit to a file that already exists.

## Approach by Phase

### Foundation — tokens, font, brand assets

Rewrite `app/assets/tailwind/application.css` as the single styling source: `@theme` tokens, `@font-face`, then a component layer. All new CSS goes here, never into `app/assets/stylesheets/application.css` — `stylesheet_link_tag :app` emits a separate `<link>` for every CSS file under `app/assets/**`, so keeping one file avoids depending on link order entirely.

Vendor the font, add the assets path, hand-author the mark SVG, build the three brand partials, replace the placeholder icons, fix the manifest's `"theme_color": "red"`.

### Story 1 (P1) — brand on every screen

Header rebuilt around `_brand_lockup`. Auth pages get `_brand_stacked` with the English tagline. This is independently shippable: after it, the site is branded even though the rest is still on the old styling.

### Story 2 (P1) — the white visual system

Apply component classes across all 22 templates, screen by screen. Layout restructuring is permitted here (FR-015a) but every id in `contracts/preserved-dom.md` survives.

### Story 3 (P2) — motion

CSS transitions on the component classes, one entrance animation, `data-turbo-submits-with` for in-progress states, the logo flourish, and the global reduced-motion block. Last because motion on an inconsistent layout is worse than no motion.

### Verification

`assert_axe_clean` helper, `accessibility_test.rb`, full suite green, FCP measurement for the PR.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Restructuring breaks system tests that key off DOM ids | `contracts/preserved-dom.md` enumerates every id, role, `<main>`, and `<summary>` text the suite depends on. Treat it as a checklist, not a suggestion. |
| `url()` to the font silently fails to resolve | Propshaft logs a warning and leaves the URL unrewritten rather than raising — a broken font would ship quietly. Quickstart includes an explicit check that the served CSS contains a digested font path. |
| Font adds weight to the critical path | One 39KB variable file, latin subset, all weights. `font-display: swap` prevents invisible text (FR-026). Measured in the PR per Principle IV. |
| Contrast failures from brand colours | Brand green `#0AB486` on white is ~2.6:1 — **fails** for text. `data-model.md` defines a darker `--color-brand-green-ink` for text use and reserves `#0AB486` for large text, icons, and fills. |
| Animation causing scroll jank | `transform`/`opacity` only; no animation of `width`, `height`, `top`, or `box-shadow`. |
| SC-002 and SC-003 have no automated check | Accepted consequence of choosing accessibility-only test evidence. Both are verified by review; noted here so the gap is explicit rather than discovered later. |

## Out of Scope

Dark theme, localisation, any new page, any copy change beyond the tagline, visual-regression snapshotting, scroll-triggered reveals, page-to-page transition animations.
