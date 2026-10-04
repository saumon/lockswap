# Implementation Plan: Change Password from the Account Page

**Branch**: `035-password-change` | **Date**: 2026-10-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/035-password-change/spec.md`

## Summary

Give the password its own section on the existing account page, reachable from a new menu link, with three
fields (each with the 014 show/hide control), live length and match checks, a throttle of 5 wrong current
passwords per 15 minutes, and a persistent success panel naming the three outcomes.

Most of the security behaviour already exists in Devise 5.0.4 and only needs proving by tests:
- Other sessions and remember-me cookies are bound to the password's bcrypt salt, so they die with it.
- Reset tokens are cleared when the password changes.
- 034 already sends the notification email.

What has to be built:
- re-issue this browser's own remember-me cookie, which dies with the others;
- stop the email form from accepting a password;
- the throttle, the form object, the split view and the menu link.

## Technical Context

**Language/Version**: Ruby 3.4.6, Rails 8.1.4

**Primary Dependencies**: Devise 5.0.4 (database_authenticatable, registerable, recoverable, confirmable,
rememberable, lockable, validatable), Turbo 2.0.23, Stimulus 1.3.4, Tailwind (via tailwindcss-rails)

**Storage**: SQLite; one migration adding two columns to `users`

**Testing**: Minitest; controller tests, model tests, Capybara system tests (`ApplicationSystemTestCase`)

**Target Platform**: Linux server, modern browsers (`allow_browser versions: :modern`)

**Project Type**: Server-rendered Rails web application

**Performance Goals**: One bcrypt comparison per submission (two when the new password is compared with
the current one), plus one row update. Not on a swap/lock path; no measurement required by Principle IV.

**Constraints**:
- No password value is ever rendered back or logged.
- Every string exists in en and fr.
- One breakpoint (48rem).
- `.btn-primary` must work on `<input type="submit">`.

**Scale/Scope**: one controller action, one form object, one migration, one view split, one Stimulus
extension, one menu link, about 20 locale keys per language

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / gate | Status | How |
|---|---|---|
| I. Code Quality | ✅ | Form object owns the rules; the controller only orchestrates. Each new method is commented with its FR, following the codebase's existing practice. |
| II. Testing (non-negotiable) | ✅ | Model, controller and system tests for every row of the quickstart table, written first. Time-dependent cases use `travel`, so they're deterministic. |
| III. UX consistency | ✅ with one justified addition | Reuses the 014 password field partial, `password-confirmation` controller, error-summary partial, `.card`, `.btn-primary`, `turbo_submits_with`. **New**: an in-page success panel instead of a toast. It's justified in research R8 because a toast that dismisses itself can't reliably carry three statements (SC-006). It reuses the existing success token pair. |
| III. i18n gate | ✅ | All keys in en/fr, enforced by `test/i18n_completeness_test.rb`. |
| IV. Performance | ✅ N/A | Not a performance-sensitive path. No unbounded query. The counter is incremented in one atomic UPDATE. |
| Documentation gate | ✅ planned | Row and entry in `docs/features.md`. No README section is added (CLAUDE.md). |
| Design contract (CLAUDE.md) | ✅ | Single column (both cards have controls). No raw hex. Page title outside cards as today. No uppercase. |

**Post-design re-check (after Phase 1)**: unchanged; no violations, Complexity Tracking empty.

## Project Structure

### Documentation (this feature)

```text
specs/035-password-change/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/routes-and-screens.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
db/migrate/2026100…_add_password_change_throttle_to_users.rb   # new (R5)
app/models/password_change.rb                                  # new form object (R3, R5)
app/controllers/registrations_controller.rb                    # + update_password, account_update_params (R1, R2, R4, R9)
config/routes.rb                                               # + devise_scope route (contract)
app/views/devise/registrations/edit.html.erb                   # split into two cards
app/views/devise/registrations/_email_form.html.erb            # new partial
app/views/devise/registrations/_password_form.html.erb         # new partial, incl. success panel
app/views/shared/_site_menu_items.html.erb                     # identity becomes a link (R11)
app/javascript/controllers/password_confirmation_controller.js # + optional length check, submit guard (R7)
app/assets/tailwind/application.css                            # success panel, only if no existing rule fits
config/locales/{en,fr}.yml                                     # strings (contract)
docs/features.md                                               # documentation gate

test/models/password_change_test.rb                            # new
test/controllers/registrations_controller_test.rb              # extended
test/system/password_change_test.rb                            # new
test/system/email_change_test.rb                               # adjusted to the split form
test/system/site_menu_test.rb                                  # identity link
```

**Structure Decision**: the existing Rails monolith layout. The feature extends the controller and view
that already own the account page rather than adding a parallel page (research R1).

## Phase summary

- **Phase 0, research**: [research.md](research.md) R1–R12. No open unknowns.
- **Phase 1, design**: [data-model.md](data-model.md),
  [contracts/routes-and-screens.md](contracts/routes-and-screens.md), [quickstart.md](quickstart.md).

## Risks

- **Double submission without JavaScript** can sign the changing browser out, because the second request
  carries the old salt (R10). The change still happens once. This is accepted and documented, not
  engineered around.
- **The existing `email_change_test.rb`** fills in "Current password" (line 14). After the split, that
  label appears in both cards, and Capybara will raise an ambiguous match. The test needs scoping with
  `within` the email card, and the new tests the same way. Field `id`s don't collide, because the two forms
  have different param keys (`user_current_password` and `password_change_current_password`).
- **Turbo and focus**: the success panel and error summary must take focus after a Turbo redirect or
  render, which needs checking in the system test rather than assuming.

## Complexity Tracking

None.
