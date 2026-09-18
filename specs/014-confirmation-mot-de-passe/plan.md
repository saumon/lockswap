# Implementation Plan: Password Confirmation and Visibility Toggle on Signup

**Branch**: `014-confirmation-mot-de-passe` | **Date**: 2026-09-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/014-confirmation-mot-de-passe/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

The signup page gains a second "Confirm password" field; submission is blocked whenever it does
not exactly match "Password" (including when left blank). Each password field gets its own "eye"
control to reveal/hide its typed characters, independently of the other field. Technical approach:
no new route, controller, model, or migration — the `User` model already validates password
confirmation via Devise's `:validatable` module and Devise's `sign_up` parameter sanitizer already
permits `password_confirmation`, so the server-side gate is activated simply by rendering the field
in `app/views/devise/registrations/new.html.erb`. Two small Stimulus controllers add the
client-side "eye" toggle (one instance per field, independent by construction) and a blur-then-live
mismatch hint that only enhances — never replaces — the server-side check, consistent with the
form's existing `novalidate` philosophy.

## Technical Context

**Language/Version**: Ruby 3.4.6

**Primary Dependencies**: Ruby on Rails 8.1.3; Devise 5.0.4 (`:validatable` module's existing
`validates_confirmation_of :password`, already active on `User` — no gem/version change);
Stimulus (`@hotwired/stimulus`, already vendored via importmap) for the two new small controllers;
Tailwind CSS v4.3 (existing `.field`, `.field-input`, `.field-hint`, `.field-error` design tokens)

**Storage**: N/A — no new persisted data; `password_confirmation` is Devise's existing virtual,
non-persisted attribute (see [data-model.md](./data-model.md))

**Testing**: Minitest (controller test) + Capybara/Selenium system tests (existing
`test/system/signup_test.rb`, `test/system/accessibility_test.rb`, updated and extended)

**Target Platform**: Linux server, containerized (Docker), deployed with Kamal — unchanged from 001

**Project Type**: Web application — same Rails monolith; this feature edits one existing view and
adds two small JS controllers, no new frontend/backend split

**Performance Goals**: SC-003 (reveal typed password in under 1 second) is a same-tick client-side
DOM change with no network round trip, trivially met; no new performance-sensitive path introduced

**Constraints**: MUST NOT weaken the signup form's existing `novalidate` design (server is the
enforcement authority; client-side script is a hint layered on top — research.md R1, R3); MUST
update the existing signup-success system/controller tests, which will otherwise start failing once
an unfilled "Confirm password" field submits as `""` instead of being absent (research.md R6)

**Scale/Scope**: Small — one view template (`new.html.erb`), one locale file addition, two new
Stimulus controllers (~30–50 lines each), test updates/additions; zero new routes, controllers,
models, or migrations

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Checked against `.specify/memory/constitution.md` v1.0.1:

| Principle | Check | Status |
| - | - | - |
| I. Code Quality | No new duplicated validation logic — reuses Devise's existing `validates_confirmation_of` (research.md R1). Two Stimulus controllers each have one clear responsibility (visibility toggle; mismatch-timing hint), mirroring the existing `locker_entry_choice_controller.js` shape. No RuboCop-flagged Ruby changes (view/locale edits only). | PASS |
| II. Testing Standards (NON-NEGOTIABLE) | Every FR (001–009) gets Minitest/system-test coverage before done; existing signup tests updated rather than left to silently start failing (research.md R6); CI runs full suite on every PR per project convention. | PASS |
| III. User Experience Consistency | Reuses the exact `password_confirmation` field pattern already present on the account-settings page (`edit.html.erb`) and the site's existing accessible icon-button convention (`_locker_profile.html.erb`'s `aria-label` + `aria-hidden`/`focusable="false"` SVG pattern) rather than inventing a new one. Accessibility (keyboard operability, non-icon-only state) is explicit in FR-008 and already covered by the existing `AccessibilityTest#"sign up is accessible"` axe check, which will re-run against the changed page with no test edits required. | PASS |
| IV. Performance Requirements | Not a performance-sensitive path — all new behavior is either a same-tick client-side toggle or reuses an existing, already-indexed validation path (single in-memory string comparison); no new query, loop, or network call. | PASS |

No violations identified; Complexity Tracking table is not needed.

**Post-Phase 1 re-check**: Re-evaluated after producing research.md, data-model.md, contracts/,
and quickstart.md. The concrete design (locale-key addition for a distinct error message, two
narrowly-scoped Stimulus controllers, blur-then-live timing resolved via `/speckit-clarify`)
introduces no new dependency, route, model, or migration beyond what was already assessed above.
All four principles remain PASS; no Complexity Tracking entries required.

## Project Structure

### Documentation (this feature)

```text
specs/014-confirmation-mot-de-passe/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── form-contract.md
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/
├── views/
│   └── devise/
│       ├── registrations/
│       │   └── new.html.erb            # add "Confirm password" field + render the field partial for both passwords (FR-001, FR-005)
│       └── shared/
│           └── _password_field.html.erb # new: one password input plus its own eye toggle, rendered once per field (FR-005, FR-006)
├── javascript/
│   └── controllers/
│       ├── password_visibility_controller.js   # new: per-field eye toggle (FR-005, FR-006, FR-007, FR-008)
│       └── password_confirmation_controller.js # new: blur-then-live mismatch hint (FR-003, FR-004)
├── assets/
│   └── tailwind/
│       └── application.css             # add styles for the eye-toggle button positioned against .field-input (reuses existing tokens)
└── models/
    └── user.rb                          # UNCHANGED — validation already present (research.md R1)

config/
└── locales/
    └── devise.en.yml                    # add password_confirmation.confirmation message (FR-003, research.md R2)

test/
├── system/
│   ├── signup_test.rb                   # update existing tests to fill "Confirm password"; add the mismatch and blur-then-live timing scenarios
│   ├── password_visibility_test.rb      # new: the eye toggles, kept out of signup_test.rb because they are a separate concern of the same page
│   └── accessibility_test.rb            # UNCHANGED — existing "sign up is accessible" axe check already covers the new markup
└── controllers/
    └── registrations_controller_test.rb # update existing tests to include password_confirmation param
```

**Structure Decision**: No new app-level directories. This feature is a targeted edit to the
existing Rails monolith's signup view, plus two small additions under the existing
`app/javascript/controllers/` convention and one locale-file addition — matching the structure
already established by feature 001 (Devise-based auth) and 009/012 (small, focused Stimulus
controllers).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations — table not applicable.
