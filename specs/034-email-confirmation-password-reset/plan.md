# Implementation Plan: Email Confirmation of New Accounts and Password Reset by Email

**Branch**: `034-email-confirmation-password-reset` | **Date**: 2026-09-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/034-email-confirmation-password-reset/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Turn on Devise's `:confirmable` and `:recoverable` on `User`. That gives activation by emailed link,
refusing sign-in until activated (only after a correct password, so FR-006 comes for free), password reset
by emailed link, email-change reconfirmation (`reconfirmable` is already `true`), and the
password-changed notice (`send_password_change_notification`). The application code covers only the places
where Devise's defaults fall short of the spec, each one checked in the installed gem's source:

1. **Generic answers and a per-address 5-minute window** on "resend activation" and "forgot password".
   `config.paranoid` is turned on. It changes no visible message here, because 001 already made
   "locked" read as "invalid". Two `create` overrides add the throttle and the support log, and always
   give the same notice (research R2, R3).
2. **A fresh activation token on every resend**. Devise re-sends the *same* unexpired token, which breaks
   FR-012 (research R17 — hitguessr has this latent bug).
3. **A completed reset activates the account and lifts the lockout**. `PasswordsController#update` does
   this through a block, which Devise yields before it signs the user in (research R4, R5).
4. **Admin activation by hand**. A nested `admin/users/:id/activation` resource sets a new
   `confirmed_by_id` column, with the same shape as the three existing `*_by` attributions (research R14).
   It shares one atomic `User#activate!(by:)` with the reset path.

Mail is delivered with `deliver_later` through Solid Queue, which already runs in Puma. It renders in the
site language through an `ApplicationMailer` `around_action`. The configuration is hitguessr's
`MailerSettings` ported as `Lockswap::MailerSettings`: ENV, then credentials, then a default; SMTP is only
enabled when its four required keys are present. In development, with no SMTP, mail goes to
letter_opener_web. Existing accounts are backfilled as activated in the migration (clarified FR-010).

## Technical Context

**Language/Version**: Ruby 3.4.6 (unchanged)

**Primary Dependencies**: Rails 8.1.3; Devise 5.0.4 (`:confirmable` and `:recoverable` added, both
shipped with the gem); devise-i18n 1.16.1 (existing, provides the French framework strings); Turbo and
Stimulus through importmap, and Tailwind v4 through `tailwindcss-rails` (unchanged). **One new gem**:
`letter_opener_web`, in the development group only (research R12).

**Storage**: SQLite through Active Record. **Two migrations** on `users`:
(1) the six Devise columns and two unique token indexes, with the backfill `confirmed_at =
CURRENT_TIMESTAMP` for every existing row; (2) `confirmed_by_id`, a self-referential FK, indexed.
See [data-model.md](data-model.md).

**Testing**: Minitest, Rails system tests (Capybara, headless Chrome) and axe-core, all unchanged.
Mail is tested with `ActionMailer::TestHelper` / `ActiveJob::TestHelper`.

- **New tests**
  - `test/models/user_test.rb` additions: `activate!` (idempotent, leaves `unconfirmed_email` alone),
    `resend_activation!` (old token dead, `confirmation_sent_at` moved), and `send_devise_notification`
    enqueuing a job.
  - `test/controllers/users/confirmations_controller_test.rb`: the generic answer in all four branches,
    the throttle, and the three link-failure messages.
  - `test/controllers/users/passwords_controller_test.rb`: the generic answer, the throttle, reset
    activating an account, reset unlocking an account, and no mail for an unknown address.
  - `test/controllers/admin/user_activations_controller_test.rb`: admin only, `confirmed_by` recorded,
    already active, account gone.
  - `test/mailers/user_mailer_test.rb`: the four emails, both parts, both languages, link host, and no
    link in `password_change`.
  - `test/system/account_activation_test.rb`, `test/system/password_reset_test.rb`,
    `test/system/admin_user_activation_test.rb`.
  - `test/lib/mailer_settings_test.rb`: the ENV > credentials > default precedence, and
    `smtp_configured?`.
- **Updated tests**
  - `test/fixtures/users.yml`: every row gets `confirmed_at`.
  - `test/system/signup_test.rb`: signup no longer signs in.
  - `test/controllers/registrations_controller_test.rb`, `test/system/motion_test.rb` and
    `test/models/user_test.rb`: accounts that sign in are created with `confirmed_at`.
  - `test/system/accessibility_test.rb`: the four new screens.
  - `test/i18n_completeness_test.rb`: automatic.

**Target Platform**: Linux server, Docker + Kamal (unchanged). `config/deploy.yml` and `.kamal/secrets`
gain the SMTP and `APP_HOST` entries ([contracts/mail-configuration.md](contracts/mail-configuration.md)).

**Project Type**: Web. A server-rendered Rails monolith, single project (unchanged).

**Performance Goals**: Signup, resend and reset return without waiting on SMTP (FR-028). The mail work is
one `INSERT` into the Solid Queue tables per email. Every lookup is by unique index: `email`,
`confirmation_token`, or `reset_password_token`. The admin Users list reads `confirmed_at` from the rows it
already loads, so it adds no query per row. The detail screen's `confirmed_by` joins the existing
`includes(…)`. No swap or lock execution path is touched.

**Constraints**:
- Every new string goes into both `en.yml` and `fr.yml`, or into both `devise.en.yml` and
  `devise.fr.yml` (Constitution III).
- No hex in ERB (CLAUDE.md). Email colours come from `MailerHelper#mail_color` (research R13).
- `.btn-primary` stays usable on `<input type="submit">`. Every new form uses `f.submit`, as sign-in
  does.
- One breakpoint. The new screens reuse `.auth-page` and add no media query.
- No token or email address is written to the log (FR-032, research R16). `filter_parameter_logging`
  already filters `:token` and `:email`.
- **Breaking change** (Constitution III): signing up no longer signs the person in. The PR must call this
  out.

**Scale/Scope**:
- **Code**
  - 1 model: `User`.
  - 1 new mailer class (`UserMailer < Devise::Mailer`), and `ApplicationMailer` edited.
  - 1 helper (`MailerHelper`).
  - 3 new controllers (`Users::ConfirmationsController`, `Users::PasswordsController`,
    `Admin::UserActivationsController`), and `RegistrationsController` changed by one method.
- **Views**
  - 3 new auth views: `passwords/new`, `passwords/edit`, `confirmations/new`.
  - 3 new mailer views, each in HTML and text, plus the 2 layouts rewritten.
  - 2 admin views edited and `sessions/new` edited.
- **Config**
  - 1 config module (`config/mailer_settings.rb`).
  - 3 environment files, the Devise initializer, routes, and `deploy.yml` / `secrets`.
- **Other**
  - 2 migrations and 4 locale files.
  - README: a Mail subsection.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|---|---|
| I. Code Quality | PASS. Devise does the work wherever its default meets the spec. Custom code exists only where the default was measured against the spec and found short (R2, R4, R5, R17), and each spot carries a comment citing the requirement. There is one activation write (`activate!`) shared by the reset path and the admin path, not two. The mail configuration is one module read by every environment. |
| II. Testing Standards | PASS. Each requirement has a named test file (see Testing). The two Devise behaviours this plan corrects — token reuse on resend, and reset not unlocking — each get a test that fails against stock Devise. Fixtures are confirmed rather than having the behaviour switched off in test (R1, R11). Mail tests are deterministic: they use the test adapter, with no sleeps or polling. |
| III. User Experience Consistency | PASS. The new screens reuse the auth shell, the signup password partial and its Stimulus controllers, the error block, and toasts. The admin additions reuse the `badge`, `cell-stack` and `detail-grid` classes and the grant/revoke `button_to` confirm pattern. Every string exists in both locales. Every new screen gets an axe audit. The breaking change is declared. |
| IV. Performance Requirements | PASS. SMTP is off the request path (`deliver_later`). Lookups are by unique index. The admin list adds no per-row query. There are no unbounded loops or queries. No critical swap or lock path is touched, so no before/after benchmark is required. |

No violations. Complexity Tracking is not needed.

### Post-Design Re-Check (after Phase 1)

Re-evaluated against research.md (R1 to R17), data-model.md and the three contracts. All four principles
still **PASS**:

- **I**: the design found one more Devise gap (R17, token reuse) and closed it with one three-line model
  method rather than a custom token scheme. `UserMailer` exists only to vary one subject line (emails.md).
- **II**: quickstart.md maps 23 manual scenarios to requirement IDs, and each automated file above covers
  its requirement.
- **III**: contracts/routes-and-screens.md fixes the reused classes and partials. contracts/emails.md keeps
  the mail within the design contract: token-mirrored colours, a hinge and no shadow, no uppercase, and no
  copy of the site's one known contrast exception.
- **IV**: data-model.md indexes both token columns (unique) and `confirmed_by_id`.

## Project Structure

### Documentation (this feature)

```text
specs/034-email-confirmation-password-reset/
├── plan.md                          # This file
├── research.md                      # Phase 0 (R1–R17)
├── data-model.md                    # Phase 1
├── quickstart.md                    # Phase 1
├── contracts/
│   ├── routes-and-screens.md        # Phase 1
│   ├── emails.md                    # Phase 1
│   └── mail-configuration.md        # Phase 1
├── checklists/requirements.md       # from /speckit-specify
└── tasks.md                         # Phase 2 (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
Gemfile                                        # + letter_opener_web (development)
config/
├── mailer_settings.rb                         # new — Lockswap::MailerSettings (from hitguessr)
├── application.rb                             # require_relative "mailer_settings"
├── environments/{development,production}.rb   # URL options, SMTP when configured, fallbacks
├── initializers/devise.rb                     # mailer_sender, parent_mailer, mailer, confirm_within,
│                                              #   send_password_change_notification, paranoid
├── routes.rb                                  # devise_for controllers; admin activation; letter_opener (dev)
├── deploy.yml                                 # + APP_HOST, SMTP_* env
└── locales/{en,fr,devise.en,devise.fr}.yml    # screens, mails, admin, subjects
.kamal/secrets                                 # + SMTP_USERNAME, SMTP_PASSWORD
db/migrate/
├── <ts>_add_devise_confirmable_and_recoverable_to_users.rb   # + backfill
└── <ts>_add_confirmed_by_to_users.rb
app/
├── models/user.rb                             # modules, confirmed_by, activate!, resend_activation!,
│                                              #   send_devise_notification
├── mailers/
│   ├── application_mailer.rb                  # sender from MailerSettings, site-locale around_action
│   └── user_mailer.rb                         # new — Devise::Mailer subclass, reconfirmation subject
├── helpers/mailer_helper.rb                   # new — mail_color
├── controllers/
│   ├── registrations_controller.rb            # + after_inactive_sign_up_path_for
│   ├── users/confirmations_controller.rb      # new
│   ├── users/passwords_controller.rb          # new
│   └── admin/user_activations_controller.rb   # new
└── views/
    ├── layouts/mailer.{html,text}.erb         # rewritten
    ├── devise/mailer/                          # new — confirmation_instructions, reset_password_instructions,
    │                                          #   password_change (.html + .text)
    ├── devise/sessions/new.html.erb           # + two links
    ├── devise/passwords/{new,edit}.html.erb   # new
    ├── devise/confirmations/new.html.erb      # new
    └── admin/users/{index,show}.html.erb      # activation badge / row / control
test/  (see Technical Context → Testing)
README.md                                      # Deploy → Mail
```

**Structure Decision**: The single Rails monolith, as in every earlier feature. The Devise controller
overrides go under `app/controllers/users/`, Devise's conventional namespace for scoped overrides, while
the existing `RegistrationsController` stays where it is. The admin write sits next to its 027 siblings in
`app/controllers/admin/`.

## Complexity Tracking

*No violations. Table omitted.*
