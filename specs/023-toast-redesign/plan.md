# Implementation Plan: Modernized Toast Notifications

**Branch**: `023-toast-redesign` | **Date**: 2026-09-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/023-toast-redesign/spec.md`

## Summary

Redesign the app's existing toast/flash notification component (shipped in 007's behavior and 008's first visual pass) so it reads as part of the current, redesigned interface instead of the original plain white box. The visual refresh covers size/spacing, a type icon alongside the existing status color, and a move from the current header-anchored top-right position to a viewport-fixed bottom-right position — resolved in the 2026-09-20 clarification session. All existing behavior (3s auto-dismiss, hover/focus pause, manual dismiss, screen-reader announcement, zero layout footprint) is preserved unchanged; the only new behavior is a visible-count cap with a queue for bursts of 4+ simultaneous notifications (FR-010).

## Technical Context

**Language/Version**: Ruby 3.4.6, Rails 8.1 (server-rendered ERB), Stimulus (JavaScript, no build-step framework)

**Primary Dependencies**: `turbo-rails`, `stimulus-rails`, `tailwindcss-rails`, `devise` (source of most flash-triggering redirects); no new gems or JS packages required

**Storage**: N/A — notifications are transient, sourced from the existing Rails flash (`notice`/`alert`); no persistence

**Testing**: Minitest system tests (Capybara + Selenium) under `test/system`; existing coverage in `test/system/notification_test.rb` must be extended, not replaced

**Target Platform**: Browser, all pages of the web app; both supported widths (the app's single 48rem breakpoint)

**Project Type**: Single Rails monolith (server-rendered views + Tailwind + Stimulus) — no frontend/backend split

**Performance Goals**: Entrance/exit motion settles within the app's existing 200ms interaction budget (CLAUDE.md Motion section); no measurable delay added to page load or Turbo navigation

**Constraints**:
- Must follow `app/assets/tailwind/application.css`'s design contract (CLAUDE.md): reuse existing color tokens only (`--color-status-success`, `--color-status-error`, `--color-surface`, `--color-ink`, etc.), no raw hex in templates, single 48rem breakpoint, animate `transform`/`opacity` only, preserve the shared `:focus-visible` ring, one rule per component.
- Must not regress `test/system/notification_test.rb`'s existing assertions on behavior (auto-dismiss timing, pause/resume, manual dismiss, zero `<main>` layout shift, screen-reader roles); assertions tied to the *current* visual details (e.g. the `border-left-color` check) may need updating to match the new look, but the underlying behavior they protect must still hold.
- Any icon introduced must be self-hosted inline SVG, consistent with the app's existing self-hosted-asset convention (fonts, brand mark) — no icon font or external CDN dependency.
- New behavior (FR-010's visible-count cap) must not alter the existing flash-sourcing mechanism (`notice`/`alert` in `_flash.html.erb`) in a way that changes what triggers a notification.

**Scale/Scope**: One shared partial (`app/views/layouts/_flash.html.erb`), its component styles in `application.css`, and its Stimulus controller(s) — used across every page in the app (~15 existing trigger points: sign-in/out/up, password/account changes, email confirmation, account unlock, locker profile, locker wishes, swap proposals). No new models, migrations, or routes.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Code Quality** — No new complexity class introduced; the component stays a single partial + one component's worth of CSS + a small Stimulus controller extension. PASS.
- **II. Testing Standards (NON-NEGOTIABLE)** — `test/system/notification_test.rb` already covers the behavior this redesign must not break; new assertions are needed for the new placement, icon presence, and the visible-count cap (FR-010). Plan requires updating/extending this file before merge, not replacing its behavioral coverage. PASS (pending Phase 2 tasks including test updates).
- **III. User Experience Consistency** — Reuses the app's existing status color tokens and its established "color is never the only signal" convention (text label + now an icon); placement change is explicitly a user-facing behavior change and is called out in the spec's Clarifications and will be called out in the PR per this principle. PASS.
- **IV. Performance Requirements** — Not a swap/lock execution path; no on-chain or hot transactional code touched. Motion stays within the existing documented budget. PASS, no benchmark required.

No violations requiring the Complexity Tracking table.

**Post-Design Re-check** (after Phase 1 artifacts): data-model.md introduces one new client-side controller (`toast_layer_controller.js`) and no persistence; contracts/toast-component.md keeps every selector/attribute existing tests already assert on. This does not change any gate above — all four still PASS, and the new cap/queue behavior in data-model.md is exactly the additional test surface anticipated under Testing Standards.

## Project Structure

### Documentation (this feature)

```text
specs/023-toast-redesign/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── toast-component.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── views/
│   └── layouts/
│       └── _flash.html.erb          # Toast partial: DOM structure, ARIA roles, icon markup (updated)
├── assets/
│   └── tailwind/
│       └── application.css          # .toast, .toast-layer, .toast-success/-error, .toast-dismiss,
│                                     #   .toast-icon rules (updated; component lives in @layer components)
└── javascript/
    └── controllers/
        ├── notification_controller.js  # Existing per-toast countdown/pause/dismiss (unchanged behavior)
        └── toast_layer_controller.js   # New: mediates the visible-count cap and reveal queue (FR-010)

test/
└── system/
    └── notification_test.rb         # Existing behavioral coverage, extended for placement/icon/cap
```

**Structure Decision**: Single Rails monolith — the feature is implemented entirely within the existing `app/views/layouts`, `app/assets/tailwind`, and `app/javascript/controllers` directories, plus its existing system test file. No new top-level structure, no new project, no split frontend/backend.

## Complexity Tracking

*No Constitution Check violations — table intentionally left empty.*
