# Implementation Plan: Login Greeting Popup

**Branch**: `036-login-greeting-popup` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/036-login-greeting-popup/spec.md`

## Summary

After a successful email/password sign-in, show a second popup reading "coucou" next to the existing
"Signed in successfully." one. No new UI is built: the sign-in action leaves a one-request flash message and
the shared flash partial (007/023) renders it as another toast, so auto-dismiss, hover pause, manual dismiss,
stacking, and screen-reader announcement come for free. A flash lives for exactly one request, which is what
makes "once per sign-in, never on reload" true without any state of our own.

## Technical Context

**Language/Version**: Ruby 3.4.6, Rails 8.1.4

**Primary Dependencies**: Devise 5.0.4, Turbo, Stimulus (existing `notification` and `toast-layer` controllers)

**Storage**: N/A. The flash rides the session cookie for one request.

**Testing**: Minitest (controller/integration tests) and Capybara system tests, as in `test/system/login_test.rb` and `test/system/notification_test.rb`

**Target Platform**: Web, server-rendered, all modern browsers

**Project Type**: Rails web application (single project)

**Performance Goals**: None beyond the page's own; one extra string rendered on one response per sign-in

**Constraints**: Every user-facing string goes through I18n with entries in both locale files (constitution III). Must not change layout (toasts are `position: fixed`).

**Scale/Scope**: One controller, one partial, two locale entries, tests

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / gate | Status | Note |
|---|---|---|
| I. Code Quality | Pass | Small override, single responsibility, RuboCop omakase run in CI |
| II. Testing Standards | Pass | Controller test and system tests listed in quickstart.md; written before the code |
| III. UX consistency | Pass | Reuses the 007/023 toast; text goes through I18n in `devise.en.yml` and `devise.fr.yml` (same value "coucou", spec FR-007) |
| III. Accessibility | Pass | Same `role="status"` and dismiss button as every toast; no new pattern |
| IV. Performance | Pass | Not a hot path; no measurement needed |
| Documentation gate | Pass | `docs/features.md` entry planned as a task |

Re-checked after Phase 1 design: no change, no violations. Complexity Tracking not needed.

## Project Structure

### Documentation (this feature)

```text
specs/036-login-greeting-popup/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── flash-and-screens.md
├── checklists/requirements.md
└── tasks.md              # /speckit-tasks, not created here
```

### Source Code (repository root)

```text
app/
├── controllers/users/sessions_controller.rb   # new: Devise sessions#create override, sets flash[:greeting]
└── views/layouts/_flash.html.erb              # add the greeting to the notifications list
config/
├── routes.rb                                  # devise_for: add sessions: "users/sessions"
└── locales/
    ├── devise.en.yml                          # devise.sessions.greeting: "coucou"
    └── devise.fr.yml                          # devise.sessions.greeting: "coucou"
test/
├── controllers/users/sessions_controller_test.rb   # new
└── system/login_test.rb (or notification_test.rb)   # extended
docs/features.md                                # feature-history entry
```

**Structure Decision**: Existing single Rails app. The controller joins `app/controllers/users/` beside
`passwords_controller.rb` and `confirmations_controller.rb`, the established place for Devise overrides.

## Complexity Tracking

No violations to justify.
