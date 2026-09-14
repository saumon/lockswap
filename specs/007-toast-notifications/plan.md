# Implementation Plan: Auto-Dismissing Popup Notifications

**Branch**: `007-toast-notifications` | **Date**: 2026-09-14 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/007-toast-notifications/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Replace the app's static, persistent flash banner (`app/views/layouts/_flash.html.erb`, rendered inline at the top of `<main>`) with popup ("toast") notifications that auto-dismiss 3 seconds after appearing, pause their countdown on hover/keyboard focus, can be dismissed manually, stack when more than one message is present, and preserve the existing accessible role semantics (`role="status"` for notices, `role="alert"` for alerts) relied upon by existing system tests. Implementation is a Stimulus controller driving a fixed-position notification container — no new JS dependency, no change to controller-side flash-setting code (`notice:`/`alert:` keys are untouched), consistent with the existing Rails 8 + Hotwire + importmap stack.

## Technical Context

**Language/Version**: Ruby 3.4.6 (Rails 8.1.3), JavaScript (ES modules via importmap, no bundler/npm)

**Primary Dependencies**: Rails 8.1 (Propshaft, Puma), Devise 5 (auth, source of most existing flash messages), Turbo Rails + Stimulus Rails (Hotwire), Tailwind CSS v4 (`tailwindcss-rails`), `importmap-rails`

**Storage**: N/A — notifications are ephemeral, client-rendered from the Rails flash hash; nothing is persisted

**Testing**: Minitest (Rails default) with Capybara + Selenium WebDriver for system tests (`test/system/*_test.rb`); existing tests assert on `[role=alert]` presence/absence (e.g. `test/system/login_failure_test.rb`, `test/system/locker_profile_test.rb`)

**Target Platform**: Server-rendered web app viewed in modern desktop/mobile browsers with JavaScript enabled (confirmed acceptable default per spec Clarifications — no no-JS fallback required)

**Project Type**: Single Rails web application (monolith; no separate frontend/backend split)

**Performance Goals**: N/A — purely presentational change to an already-rendered page; no new network calls or backend work

**Constraints**: No new JavaScript dependency/npm package (importmap-only, matching existing `stimulus-rails`/`turbo-rails` usage); notification element must be fully removed from the DOM on dismiss (not just hidden) so existing `assert_no_selector "[role=alert]"`-style assertions keep working; must not alter existing flash-triggering controller/Devise code or message wording (FR-009)

**Scale/Scope**: Single shared layout partial + one small Stimulus controller; touches every page that can set `notice`/`alert` (effectively the whole app, but as one shared component, not per-page changes)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Code Quality**: Change is confined to one shared partial + one small, single-responsibility Stimulus controller (show/schedule-dismiss/pause/resume/manual-dismiss). No duplicated logic across pages since all flash rendering already funnels through the one shared `_flash` partial. PASS.
- **II. Testing Standards (NON-NEGOTIABLE)**: Existing system tests already assert flash presence/absence via `[role=alert]`/`[role=status]`; this feature requires updating/adding system tests that assert (a) a notification appears, (b) it disappears within the auto-dismiss window without interaction, (c) hover/focus pauses the countdown, (d) manual dismiss removes it immediately. Task breakdown must include these as automated tests, not manual verification only. PASS (planned, enforced in tasks.md).
- **III. User Experience Consistency**: Reuses the existing success/error color convention (emerald/rose) and existing ARIA roles (`status`/`alert`) rather than inventing new ones; directly implements the accessibility requirement (pause-on-hover/focus) called out in the spec Clarifications to satisfy the constitution's accessibility-verification gate. PASS.
- **IV. Performance Requirements**: Not a performance-sensitive path (no network calls, no on-chain/transaction interaction, no unbounded loops/queries) — before/after measurement is not applicable. N/A, noted rather than skipped silently.

No violations requiring justification; Complexity Tracking table below is left empty.

**Post-Design Re-check** (after Phase 1 research/data-model/contracts, below): All four gates still PASS/N/A as above — the chosen design (Stimulus controller + fixed-position container, no new dependency, preserved `status`/`alert` roles, DOM removal on dismiss) introduces nothing that changes this assessment.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── views/
│   └── layouts/
│       ├── application.html.erb   # renders the notification container (replaces inline _flash render)
│       └── _flash.html.erb        # modified: renders popup markup instead of static inline banner
├── javascript/
│   └── controllers/
│       ├── index.js                # unchanged — already eager-loads all controllers
│       └── notification_controller.js  # new: show/auto-dismiss/pause-resume/manual-dismiss behavior
└── assets/
    └── tailwind/
        └── application.css        # unchanged (plain `@import "tailwindcss"`); utility classes only

test/
├── system/
│   ├── login_test.rb              # updated: assert popup appears + auto-dismisses on sign-in
│   ├── locker_profile_test.rb     # updated: existing role=alert assertions remain valid
│   ├── login_failure_test.rb      # updated: existing role=alert assertions remain valid
│   └── notification_test.rb       # new: dedicated coverage for stacking, manual dismiss, hover-pause
└── controllers/                   # unchanged — controllers still set notice:/alert: as today
```

**Structure Decision**: Single Rails web application (no frontend/backend split — Option 1/2 templates above do not apply as-is). All changes live inside the existing `app/` and `test/` trees already used by this repo; no new top-level directories are introduced. The feature is one shared layout partial plus one new Stimulus controller, consumed by every page that already sets Rails `flash[:notice]`/`flash[:alert]` — no per-controller changes are needed since all flash rendering already funnels through the single `layouts/_flash` partial.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations — this section is intentionally empty.
