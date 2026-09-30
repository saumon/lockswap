---

description: "Task list for feature implementation"
---

# Tasks: Email Confirmation of New Accounts and Password Reset by Email

**Input**: Design documents from `/specs/034-email-confirmation-password-reset/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R17), data-model.md, contracts/routes-and-screens.md,
contracts/emails.md, contracts/mail-configuration.md, quickstart.md (all present)

**Tests**: Included and REQUIRED. The constitution (Principle II, NON-NEGOTIABLE) requires a failing-first
automated test for every new behaviour. Two tests in particular must fail against stock Devise before the
fix goes in: T049, the token reuse on resend (research R17), and T037, a reset not activating an
account or lifting a time-strategy lockout (research R4).

**Organization**: Tasks are grouped by the spec's seven user stories. US1–US3 are P1, US4–US5 are P2,
and US6–US7 are P3.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: Which user story the task belongs to (US1–US7)
- Every task names its exact file path(s)

## Path Conventions

This is the single Rails monolith at the repository root (`app/`, `config/`, `db/`, `test/`), unchanged
from every earlier feature.

---

## Phase 1: Setup

**Purpose**: The one new dependency, and the mail-settings module every later phase reads.

- [X] T001 Add `gem "letter_opener_web"` to the `group :development do` block in `Gemfile`, with a comment citing 034 research R12: development runs on a remote box, so mail has to be readable through the app's own URL. Run `bundle install` and commit the `Gemfile.lock` change.
- [X] T002 [P] Create `config/mailer_settings.rb` defining `module Lockswap::MailerSettings` (`module_function`), ported from hitguessr's `Hitguessr::MailerSettings` **without** `confirmation_feature_enabled?` (research R1). It must provide:
  - `smtp_settings`: a compacted hash of `address`, `port` (integer), `domain`, `user_name`, `password`, `authentication` (symbol, default `:plain`), `enable_starttls_auto` (boolean, default `true`) and `openssl_verify_mode`.
  - `smtp_configured?`: true when `address`, `port`, `user_name` and `password` are all present.
  - `default_url_options(default_host:, default_port: nil, default_protocol: nil)`.
  - `mailer_sender(default:)`.
  - The private-style helpers `setting`, `integer_setting`, `boolean_setting` and `symbol_setting`.

  Every value resolves **ENV → `Rails.application.credentials.dig(namespace, key)` → default**, and an empty ENV value counts as unset. The ENV and credential names are exactly those in the table in `contracts/mail-configuration.md`. Add a header comment naming that contract and hitguessr as the origin.
- [X] T003 Add `require_relative "mailer_settings"` near the top of `config/application.rb`, after `require "rails/all"` or the equivalent requires and before `module Lockswap`, so the environment files and initializers can call `Lockswap::MailerSettings`. This depends on T002.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The schema, the Devise modules, delivery through the job queue, the site-language mailer
base, the email layout, and bringing every existing test in line with "accounts must be activated".

**⚠️ CRITICAL**: No user story phase can start until this phase is complete. Once T008 turns on
`:confirmable`, every fixture and every `User.create!` that signs in must be confirmed, or the whole suite
fails.

- [X] T004 Create the migration `db/migrate/<timestamp>_add_devise_confirmable_and_recoverable_to_users.rb` (`ActiveRecord::Migration[8.1]`). Use `up`/`down`, not `change`, because of the backfill.
  - In `up`, add:
    - `confirmation_token :string`
    - `confirmed_at :datetime`
    - `confirmation_sent_at :datetime`
    - `unconfirmed_email :string`
    - `reset_password_token :string`
    - `reset_password_sent_at :datetime`

    All are nullable, as data-model.md specifies.
  - Add `add_index :users, :confirmation_token, unique: true` and `add_index :users, :reset_password_token, unique: true`.
  - Then run `execute "UPDATE users SET confirmed_at = CURRENT_TIMESTAMP WHERE confirmed_at IS NULL"`. The comment must cite FR-010 (clarified: every existing account is activated at release) and research R15 (the release time, not `created_at`, because using `created_at` would claim an activation that never happened).
  - `down` removes the two indexes and the six columns.
- [X] T005 Create the migration `db/migrate/<timestamp+1>_add_confirmed_by_to_users.rb` with `add_reference :users, :confirmed_by, foreign_key: { to_table: :users }, index: true`. It is nullable. Comment: FR-036, the administrator who activated this account by hand. It has the same shape as `admin_granted_by_id`, `locker_edited_by_id` and `search_cancelled_by_id`. This depends on T004 only for timestamp ordering.
- [X] T006 Run `bin/rails db:migrate` and commit the regenerated `db/schema.rb`. The `users` table must show the seven new columns, the unique indexes `index_users_on_confirmation_token` and `index_users_on_reset_password_token`, `index_users_on_confirmed_by_id`, and the new foreign key. This depends on T004 and T005.
- [X] T007 [P] In `test/fixtures/users.yml`, add `confirmed_at: <%= Time.current %>` to **every** fixture row (all 12). Add a header comment: 034, fixtures are activated accounts, and a test about activation builds its own unconfirmed account (research R11).
- [X] T008 Edit `app/models/user.rb`:
  - **Modules**: change the `devise` call to `devise :database_authenticatable, :registerable, :recoverable, :confirmable, :rememberable, :lockable, :validatable`. Extend the existing per-module comment block with two lines:
    - `:recoverable` — password reset by emailed link (034 FR-014 to FR-020).
    - `:confirmable` — activation by emailed link, and reconfirmation of a changed address (034 FR-001 to FR-012, FR-021).
  - **Attribution**: add the pair below, next to the other `*_by` pairs, with a comment citing 034 FR-036. `:nullify` is used for the same reason as the three pairs above: the activation outlives the administrator who performed it.
    ```ruby
    belongs_to :confirmed_by, class_name: "User", optional: true, inverse_of: :activations_made
    has_many :activations_made, class_name: "User", foreign_key: :confirmed_by_id, dependent: :nullify, inverse_of: :confirmed_by
    ```
  - **Delivery**: add a public `send_devise_notification(notification, *args)` returning `devise_mailer.send(notification, self, *args).deliver_later`. Comment: FR-028, so signup, resend and reset never wait on or fail because of SMTP (research R8).

  This depends on T006.
- [X] T009 Edit `config/initializers/devise.rb`:
  - `config.mailer_sender = Lockswap::MailerSettings.mailer_sender(default: "LockSwap <no-reply@#{Rails.env.production? ? "lockswap.saumon.cc" : "localhost"}>")`
  - Uncomment and set:
    - `config.parent_mailer = "ApplicationMailer"`
    - `config.mailer = "UserMailer"`
    - `config.paranoid = true`, with a comment citing research R2: the locked and not-found messages already read as "Invalid email or password" (001 FR-006), so this changes no visible text and adds timing protection on sign-in.
    - `config.confirm_within = 24.hours` (FR-007)
    - `config.send_password_change_notification = true` (FR-039)
  - Keep `reconfirmable = true` and `reset_password_within = 6.hours`, now citing 034 FR-021 and FR-018 in their comments.

  This depends on T003.
- [X] T010 [P] Rewrite `app/mailers/application_mailer.rb`:
  - `default from: -> { Devise.mailer_sender }`. Comment: `Devise::Mailers::Helpers#headers_for` drops Devise's own `from` whenever the parent mailer has a `default from:`, so the placeholder `from@example.com` would otherwise win (contracts/emails.md, "Sender precedence trap").
  - `layout "mailer"`
  - `helper :mailer`
  - `around_action :use_site_language`, where the private method `use_site_language(&block)` calls `I18n.with_locale(SiteLanguageSetting.current.language.to_sym, &block)`. Comment: FR-024, research R9. A job runs outside any request, so the site setting must be read here.
- [X] T011 [P] Create `app/mailers/user_mailer.rb` with `class UserMailer < Devise::Mailer`. It overrides `confirmation_instructions(record, token, opts = {})`: when `record.pending_reconfirmation?`, it sets `opts[:subject] = I18n.t("mailer.reconfirmation_instructions.subject")`, then calls `super`. Comment: `headers_for` merges `opts` last (devise 5.0.4, `lib/devise/mailers/helpers.rb:44`), and the email-change mail needs its own subject (contracts/emails.md). Add `helper :mailer` and `default template_path: "devise/mailer"`.
- [X] T012 [P] Create `app/helpers/mailer_helper.rb` with:
  - `MAIL_COLORS = { ink: "#0A1F38", ink_muted: "#50607A", link: "#0A5AC2", canvas: "#F4F7FA", surface: "#FFFFFF", brand_green: "#0AB486", rail_you: "#0A77F1" }.freeze`, one comment per entry naming the stylesheet token it mirrors (`--color-ink` and so on).
  - `def mail_color(name) = MAIL_COLORS.fetch(name)`.
  - `MAIL_FONT_WRITTEN = "Nunito, system-ui, -apple-system, 'Segoe UI', sans-serif"` and `MAIL_FONT_MEASURED = "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace"`.
  - A header comment: CLAUDE.md forbids hex in ERB and email clients ignore CSS variables, so the email templates read colours from here by name (research R13).
- [X] T013 Rewrite `app/views/layouts/mailer.html.erb` as a table-based layout: an outer table on `mail_color(:canvas)` and an inner 560px-max card on `mail_color(:surface)`. The card has a 3px left border in `mail_color(:rail_you)` (the hinge; the email concerns the reader's own account) and **no** shadow. Use inline `style=""` only and **no hex literal** anywhere. The wordmark is text: "Lock" in `mail_color(:ink)` and "Swap" in `mail_color(:brand_green)` (the SC 1.4.3 brand exemption, as on the site), in `MAIL_FONT_WRITTEN`. Then `<%= yield %>`, then a footer line `t("mailer.layout.footer")` in `mail_color(:ink_muted)`. Set `<html lang="<%= I18n.locale %>">` and a viewport meta tag. Rewrite `app/views/layouts/mailer.text.erb` as `LockSwap`, a blank line, `yield`, then `-- ` and the footer. This depends on T012.
- [X] T014 Create the shared partials `app/views/devise/mailer/_action.html.erb` (locals: `label:`, `url:`, `validity:`) and `app/views/devise/mailer/_action.text.erb`.
  - The HTML partial renders:
    1. A bulletproof button (a table cell with `background-color: mail_color(:link)`, a white link text, 6.45:1, and padding).
    2. A line `t("mailer.shared.copy_link")`.
    3. The URL as plain text in `MAIL_FONT_MEASURED`.
    4. The `validity` sentence.
  - The text partial renders `label: url` and then the validity sentence.

  These cover FR-025 and FR-026 for every email that carries a link.
- [X] T015 [P] Add the shared mail strings to `config/locales/en.yml` and `config/locales/fr.yml` under a new top-level `mailer:` key:
  - `mailer.layout.footer`: en "LockSwap — locker swaps", fr "LockSwap — échanges de casiers".
  - `mailer.shared.copy_link`: en "If the button does not work, copy this address into your browser:", fr "Si le bouton ne fonctionne pas, copiez cette adresse dans votre navigateur :".
- [X] T016 In `config/locales/devise.en.yml` and `config/locales/devise.fr.yml`, set these subjects (contracts/emails.md):
  - `devise.mailer.confirmation_instructions.subject`: "Activate your LockSwap account" / "Activez votre compte LockSwap"
  - `devise.mailer.reset_password_instructions.subject`: "Reset your LockSwap password" / "Réinitialisez votre mot de passe LockSwap"
  - `devise.mailer.password_change.subject`: "Your LockSwap password was changed" / "Votre mot de passe LockSwap a été modifié"
- [X] T017 [P] Update the three tests that create accounts which then sign in so those accounts are activated, by passing `confirmed_at: Time.current` to their `User.create!` calls: `test/controllers/registrations_controller_test.rb`, `test/system/motion_test.rb` and `test/models/user_test.rb`. Grep `User.create` in each file and change only the calls whose account is later signed in or used as `current_user`. Add a one-line comment at the first such call: "034: an account must be activated before it can sign in."
- [X] T018 [P] Add an email helper module `test/support/mail_helpers.rb` (and `require` it from `test/test_helper.rb`, including it in `ActiveSupport::TestCase` and `ActionDispatch::IntegrationTest`), with:
  - `link_from_last_email(pattern)`: runs `deliver_enqueued_emails`, then takes `ActionMailer::Base.deliveries.last`, reads its text part and returns the first URL matching `pattern` (for example `%r{/users/confirmation\?confirmation_token=}`), converted to a path so it can be `visit`ed.
  - `emails_to(address)`: the delivered mails whose `to` includes `address`.

  The module includes `ActionMailer::TestHelper` and `ActiveJob::TestHelper`.
- [X] T019 Run `bin/rails test` and `bin/rails test:system`. **Every existing test must pass except** the tests that expect signup to sign in: `test/system/signup_test.rb`'s two ("a visitor creates an account and lands on the homepage", "a new account is signed in persistently"), `test/controllers/registrations_controller_test.rb`'s signup tests that `assert_redirected_to root_path` or expect the Admin menu straight after `post user_registration_path`, and any `test/system/admin_danger_zone_test.rb` step that signs up through the form and expects the homepage. US1 rewrites all of these (T024, T024a). (analyze U1) If anything else fails, fix the fixture or `create!` call it points to before going on. `account_lockout_test.rb` and `login_failure_test.rb` passing unchanged is the evidence required by research R2 (paranoid mode is invisible to 001). This depends on T007–T018.

**Checkpoint**: The schema is in place, both Devise modules are on, mail is sent in the background in the
site language, the suite is green apart from the two signup tests US1 redefines.

---

## Phase 3: User Story 1 — Activate a new account from the confirmation email (Priority: P1) 🎯 MVP

**Goal**: After signup the visitor is told to check their inbox and is not signed in. The email carries an
activation link, and following it activates the account and sends them to sign in.

**Independent Test**: Register a new address, check that exactly one activation email is enqueued to it,
follow its link, then sign in with the chosen password and reach the homepage.

### Tests for User Story 1 ⚠️ Write first; confirm they fail before implementing

- [X] T020 [P] [US1] In `test/models/user_test.rb`, add:
  - `send_devise_notification` enqueues `ActionMailer::MailDeliveryJob` instead of delivering inline (`assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob`).
  - A newly created account (no `confirmed_at`) is `!confirmed?` and `!active_for_authentication?`, and exactly one `confirmation_instructions` email is enqueued for it on create.
  - A fixture account is `confirmed?` (FR-010 through T007).
- [X] T021 [P] [US1] Create `test/controllers/users/confirmations_controller_test.rb` (`ActionDispatch::IntegrationTest`) with the `show` tests below. The key messages are those in contracts/routes-and-screens.md.
  - A valid token confirms, redirects to `new_user_session_path` with the `devise.confirmations.confirmed` notice, and does **not** sign in (`get root_path` then redirects to sign-in).
  - A token older than 24 hours (`travel 25.hours`) gives 422 and the `users.confirmations.expired` text, and the account stays unconfirmed.
  - A second visit to a used token gives 422 and `users.confirmations.already_active`.
  - A garbage token gives 422 and `users.confirmations.unrecognised`.
- [X] T022 [P] [US1] Create `test/mailers/user_mailer_test.rb` with the `confirmation_instructions` tests (use `UserMailer.confirmation_instructions(user, "tok")`):
  - It is multipart with HTML and text parts (FR-026).
  - The subject is "Activate your LockSwap account".
  - Both parts contain `http://example.com/users/confirmation?confirmation_token=tok` (FR-027).
  - Both parts contain the 24-hour validity sentence and the "did not ask" sentence (FR-025).
  - The `from` is `Devise.mailer_sender`, not `from@example.com`.
  - With `SiteLanguageSetting.current.update!(language: "fr")`, the subject is "Activez votre compte LockSwap" (FR-024).
  - The HTML contains no `#` followed by six hex digits outside `style` attributes. This is a guard that the ERB used `mail_color`: assert that the template source files contain no `/#[0-9A-Fa-f]{6}/`.
- [X] T023 [P] [US1] Create `test/system/account_activation_test.rb`:
  - Sign up with "new.person@example.com" (password "password123" twice). Expect: the current path is the sign-in page, the text of `devise.registrations.signed_up_but_unconfirmed` is visible, and "Welcome to LockSwap" is **not** visible.
  - `visit link_from_last_email(%r{confirmation_token=})`. Expect: the "confirmed" notice on sign-in.
  - Log in with that email and password. Expect: "Welcome to LockSwap".

  Add `assert_axe_clean` on the sign-in page after the redirect.
- [X] T024 [US1] Rewrite the two signup-lands-signed-in tests in `test/system/signup_test.rb`:
  - "a visitor creates an account and lands on the homepage" becomes "a visitor creates an account and is asked to activate it": the account is created, the path is `new_user_session_path` and the notice is visible.
  - "a new account is signed in persistently" becomes "an activated account gets the persistent session": sign up, follow the link, log in, `restart_browser_session`, and the user is still on the homepage (001 FR-007 now applies from the first real sign-in).

  Header comment: 034, a breaking change, because signup no longer signs in (spec US1-1, plan Constraints).

### Implementation for User Story 1

- [X] T024a [US1] Rewrite the signup-then-signed-in expectations outside `signup_test.rb` (analyze U1). In `test/controllers/registrations_controller_test.rb`, each signup now `assert_redirected_to new_user_session_path` and the account is `!confirmed?`. The 013 "first signup lands on a homepage carrying the Admin menu" test becomes: signup, then `User.last.confirm`, then `sign_in`, then the Admin menu is present. In `test/system/admin_danger_zone_test.rb`, any step that signs up through the form confirms the account (`User.find_by(email:).confirm`) and logs in before continuing. Also add a test that the super admin's refused cancellation still shows its refusal message and stays signed in (guards T025's `#destroy` change, analyze I1).
- [X] T025 [US1] In `app/controllers/registrations_controller.rb`, add a protected `after_inactive_sign_up_path_for(_resource)` returning `new_user_session_path`. Comment: research R7. Devise's default (`root_path`) would be bounced by `authenticate_user!` with a "please sign in" alert that replaces the "check your inbox" notice. Update the class header comment: signup now creates an unactivated account (034 FR-003), and `after_sign_up_path_for` only applies if an account is ever created already active. **Also** change `#destroy`'s refusal redirect from `after_inactive_sign_up_path_for(resource)` to `edit_user_registration_path` (analyze I1): the refused super admin is signed in, so sending them to the sign-in page would bounce them to root with "already signed in" and lose the refusal message.
- [X] T026 [US1] Create `app/controllers/users/confirmations_controller.rb` (`class Users::ConfirmationsController < Devise::ConfirmationsController`) with `show` only for now:
  - Call `self.resource = resource_class.confirm_by_token(params[:confirmation_token])`.
  - **Success**: log `[account_mail] event=activated_by_link user_id=<id>`. When the confirmed record was an **email change** (`resource.saved_change_to_email?`), set the notice to `t("users.confirmations.email_changed")` ("Your new email address is confirmed." / "Votre nouvelle adresse e-mail est confirmée."); otherwise use `set_flash_message!(:notice, :confirmed)`. Redirect to `signed_in? ? root_path : new_user_session_path` (analyze I2: the email-change link is usually followed while signed in). Activation never signs in by itself (spec US1-2).
  - **Failure**: set `@outcome` to `:expired` when `resource.errors.added?(:email, :confirmation_period_expired, period: …)` (or when `resource.errors.details[:email]` has that error key), to `:already_active` for `:already_confirmed`, and to `:unrecognised` otherwise. Then `render :new, status: :unprocessable_content`.

  Add a header comment mapping each branch to FR-006 or FR-008.
- [X] T027 [US1] In `config/routes.rb`, change `devise_for :users, controllers: { registrations: "registrations" }` to also map `confirmations: "users/confirmations", passwords: "users/passwords"`. Extend the comment: 034 contracts/routes-and-screens.md. The passwords controller arrives in US3. Until then the mapping must point at an existing class, so create an empty `class Users::PasswordsController < Devise::PasswordsController; end` in `app/controllers/users/passwords_controller.rb` in this task.
- [X] T028 [US1] Create `app/views/devise/confirmations/new.html.erb` using the auth shell (`content_for :title`, `content_for :hide_site_header, true`, `.auth-page`, `render "shared/brand_stacked"`, `.card.stack`, `h1.page-title`).
  - When `@outcome` is set, show a `div.form-errors role="alert"` with `t(".outcome.#{@outcome}")`. For `:already_active`, also show a `.meta` link `t(".sign_in")` → `new_user_session_path`.
  - Then show `p.card-lead` `t(".lead")` and a `form_for(resource, as: resource_name, url: confirmation_path(resource_name), html: { method: :post, class: "stack-tight", novalidate: true })` with an email `.field`, prefilled with `resource.email` only when it is present (use `resource.pending_reconfirmation? ? resource.unconfirmed_email : resource.email`), and `f.submit t(".submit"), class: "btn btn-primary w-full", data: { turbo_submits_with: t(".submitting") }`.
  - Finish with a `.meta` link back to sign-in.

  This view is also US4's resend screen. Its `create` action arrives in T053.
- [X] T029 [US1] Add the keys to `config/locales/en.yml` and `config/locales/fr.yml`:
  - `devise.confirmations.new.title`: "Resend the activation email" / "Renvoyer l'e-mail d'activation"
  - `.lead`: "Enter the address you signed up with and we will send a new activation link." / "Saisissez l'adresse utilisée à l'inscription : nous vous enverrons un nouveau lien d'activation."
  - `.submit`: "Send the link" / "Envoyer le lien"
  - `.submitting`: "Sending…" / "Envoi…"
  - `.sign_in`: "Sign in" / "Se connecter"
  - `.outcome.expired`: "This activation link has expired. Request a new one below." / "Ce lien d'activation a expiré. Demandez-en un nouveau ci-dessous."
  - `.outcome.already_active`: "This account is already active. You can sign in." / "Ce compte est déjà actif. Vous pouvez vous connecter."
  - `.outcome.unrecognised`: "This activation link is not valid. Request a new one below." / "Ce lien d'activation n'est pas valide. Demandez-en un nouveau ci-dessous."

  Also override these in `config/locales/devise.en.yml` and `devise.fr.yml`:
  - `devise.registrations.signed_up_but_unconfirmed`: "Your account is created. We have sent you an email: follow its link to activate your account, then sign in." / "Votre compte est créé. Nous vous avons envoyé un e-mail : suivez son lien pour activer votre compte, puis connectez-vous."
  - `devise.confirmations.confirmed`: "Your account is active. You can sign in." / "Votre compte est activé. Vous pouvez vous connecter."
- [X] T030 [US1] Create `app/views/devise/mailer/confirmation_instructions.html.erb` and `.text.erb` for the **activation** wording. The reconfirmation branch arrives in US6, so for now wrap the body in `unless @resource.pending_reconfirmation?`. The body is:
  - `h1` `t("mailer.confirmation_instructions.heading")`
  - `p` `.why`
  - `p` `.what`
  - `render "devise/mailer/action", label: t(".button"), url: confirmation_url(@resource, confirmation_token: @token), validity: t(".validity")`
  - `p` `.not_you`

  Use `mail_color` and the font constants only. Add to both `en.yml` and `fr.yml` under `mailer.confirmation_instructions`:
  - `heading`: "Activate your account" / "Activez votre compte"
  - `why`: "Someone — hopefully you — created a LockSwap account with this address." / "Quelqu'un — vous, espérons-le — a créé un compte LockSwap avec cette adresse."
  - `what`: "Follow the link below to activate it. You can then sign in." / "Suivez le lien ci-dessous pour l'activer. Vous pourrez ensuite vous connecter."
  - `button`: "Activate my account" / "Activer mon compte"
  - `validity`: "This link works for 24 hours." / "Ce lien est valable 24 heures."
  - `not_you`: "If you did not create this account, ignore this email: it will never be activated." / "Si vous n'avez pas créé ce compte, ignorez cet e-mail : il ne sera jamais activé."

  (Use explicit `t("mailer.confirmation_instructions.…")` keys, not lazy ones: the Devise mailer's lazy scope is `devise.mailer.…`.)
- [X] T031 [US1] Add `[account_mail] event=activation_sent user_id=<id>` logging. Put it in `User#send_devise_notification` (T008) as `Rails.logger.info` with the event name derived from `notification` (for example `confirmation_instructions` → `activation_sent`, `reset_password_instructions` → `reset_sent`, `password_change` → `password_change_notified`). It logs the id only, never the email or token (FR-032, research R16).

**Checkpoint**: Signup sends an activation email, the account activates by link, and it signs in
afterwards. US1 is shippable on its own (spec SC-001, SC-003).

---

## Phase 4: User Story 2 — Refuse sign-in until the account is activated (Priority: P1)

**Goal**: An unactivated account cannot sign in even with the right password, and the message says why.
A wrong password still reads as generic, and a refusal sends no email.

**Independent Test**: Create an account without activating it, sign in with the correct credentials, and
check that the sign-in is refused with the activation message and that no email is enqueued.

### Tests for User Story 2 ⚠️ Write first; confirm they fail before implementing

- [X] T032 [P] [US2] Create `test/controllers/users/sessions_activation_test.rb` (`ActionDispatch::IntegrationTest`) that builds `User.create!(email: "pending@example.com", password: "password123", password_confirmation: "password123")` (unconfirmed), then clears the enqueued jobs. Cover:
  - `post user_session_path` with the right password: not signed in, and the flash equals `I18n.t("devise.failure.unconfirmed")` (FR-005).
  - The same with the wrong password: the flash equals `I18n.t("devise.failure.invalid", authentication_keys: "Email")` (FR-006).
  - `assert_no_enqueued_emails` across both attempts (FR-009).
  - After `user.confirm`, the right password signs in (SC-004 inverse, spec US2 edge case).
- [X] T033 [P] [US2] Add a system test to `test/system/account_activation_test.rb`: an unconfirmed account logs in with the right password and sees the unconfirmed message text; the page still offers the "Didn't receive the activation email?" link. That link arrives in T054, so write the assertion now and expect it to fail until US4.

### Implementation for User Story 2

- [X] T034 [US2] Override `devise.failure.unconfirmed` in `config/locales/devise.en.yml` and `devise.fr.yml`: "Your account is not activated yet. Follow the link in the email we sent you, or request a new one below." / "Votre compte n'est pas encore activé. Suivez le lien de l'e-mail que nous vous avons envoyé, ou demandez-en un nouveau ci-dessous." Comment: FR-005. The toast disappears, so the text points to the permanent link on the page rather than containing one (research R7).
- [X] T035 [US2] Verify, and document in a comment above the `devise` call in `app/models/user.rb`, that FR-006 needs no code. `Devise::Strategies::DatabaseAuthenticatable` validates the password before `active_for_authentication?` is consulted, so an unactivated account with a wrong password fails as `:invalid`. T032 pins this.

**Checkpoint**: US1 and US2 together satisfy the request's core sentence: "L'utilisateur ne peut pas se
connecter sans avoir cliqué sur le lien d'activation."

---

## Phase 5: User Story 3 — Reset a forgotten password by email (Priority: P1)

**Goal**: A "Forgot your password?" link leads to a request screen, which always gives a generic answer.
The emailed link leads to a new-password screen. Saving there signs the user in, activates the account
if needed, lifts any lockout, and sends a "password changed" email.

**Independent Test**: From sign-in, request a reset for an active fixture account, follow the link, set a
new password, and check that it works, that the old one is refused, and that a password-changed mail
was sent.

### Tests for User Story 3 ⚠️ Write first; confirm they fail before implementing

- [X] T036 [P] [US3] Create `test/controllers/users/passwords_controller_test.rb`:
  - `create` for `users(:alice).email` enqueues one `reset_password_instructions` email and redirects to `new_user_session_path` with the `devise.passwords.send_paranoid_instructions` notice (FR-015).
  - `create` for "nobody@example.com" gives the same redirect and notice, with `assert_no_enqueued_emails` (FR-016).
  - Two `create` calls within 5 minutes enqueue one email; after `travel 6.minutes`, a third enqueues a second (FR-023).
  - `update` with a valid token and matching passwords signs in and changes the password, and the old password is no longer `valid_password?` (FR-019). It also enqueues a `password_change` email (FR-039).
  - `update` with mismatched passwords gives 422 and keeps the token usable (a second, valid `update` succeeds; US3-5).
  - `update` reusing a consumed token gives 422 and the `reset_password_token` error (US3-6).
  - `update` after `travel 7.hours` gives 422 and the expired error (FR-018).
- [X] T037 [US3] In the same file (after T036), add the two correction tests that **must fail against stock Devise**:
  - (a) An unconfirmed account (`User.create!` without `confirmed_at`) completes a reset: `user.reload.confirmed?` is true, `confirmed_by_id` is nil, and the session is signed in (FR-019 clarified, research R4/R5).
  - (b) A locked account (`user.lock_access!`) completes a reset: `!user.reload.access_locked?`, `failed_attempts == 0`, and it is signed in (FR-040, research R4).
  - (c) An unconfirmed account with a pending `unconfirmed_email` set directly in the database keeps its `email` after a reset. `activate!` does not promote `unconfirmed_email` (research R5).
- [X] T038 [P] [US3] Add to `test/mailers/user_mailer_test.rb`:
  - `reset_password_instructions` is multipart, has the subject "Reset your LockSwap password", links `http://example.com/users/password/edit?reset_password_token=tok` in both parts, and contains "6 hours" / "6 heures" and the only-once sentence.
  - `password_change` is multipart, has the subject "Your LockSwap password was changed", contains the formatted time and the "contact an administrator" sentence, and contains **no** `http` link in either part (FR-039).
- [X] T039 [P] [US3] Create `test/system/password_reset_test.rb`:
  - From sign-in, click "Forgot your password?", enter alice's email and submit; the generic notice appears.
  - `visit link_from_last_email(%r{reset_password_token=})`; fill in mismatched passwords and see the signup mismatch message; fill in a matching pair and see "Welcome to LockSwap".
  - Log out, then log in with the old password (refused) and with the new one (succeeds).

  Add `assert_axe_clean` on both the forgot-password and new-password screens.
- [X] T040 [P] [US3] Add to `test/models/user_test.rb`:
  - `activate!` on an unconfirmed account returns `true` and sets `confirmed_at`.
  - A second call returns `false` and does not move `confirmed_at`.
  - `activate!(by: admin)` sets `confirmed_by`.
  - `activate!` leaves `email` and `unconfirmed_email` unchanged and enqueues no email.

### Implementation for User Story 3

- [X] T041 [US3] In `app/models/user.rb`, add these public methods with comments citing data-model.md:
  - `activate!(by: nil)`:
    ```ruby
    now = Time.current
    activated = User.where(id: id, confirmed_at: nil).update_all(confirmed_at: now, confirmed_by_id: by&.id, updated_at: now) == 1
    self.confirmed_at, self.confirmed_by_id = User.where(id: id).pick(:confirmed_at, :confirmed_by_id)
    clear_attribute_changes(%i[confirmed_at confirmed_by_id])
    activated
    ```
    Comment: the in-memory record MUST carry the new `confirmed_at` before Devise's `sign_in` in `passwords#update`, or Warden rejects it as inactive (analyze A1). One conditional UPDATE, so a concurrent link click and an admin click cannot both activate (spec US7 edge case). It never promotes `unconfirmed_email`, unlike Devise's `confirm` (research R5).
  - `activated_by_admin? = confirmed_at.present? && confirmed_by_id.present?`
- [X] T042 [US3] Implement `app/controllers/users/passwords_controller.rb`:
  - `RESEND_COOLDOWN = 5.minutes`.
  - **`create`**:
    - `email = params.dig(resource_name, :email).to_s.strip.downcase`
    - `user = User.find_by(email: email) if email.present?`
    - When `user` exists and `(user.reset_password_sent_at.nil? || user.reset_password_sent_at <= RESEND_COOLDOWN.ago)`, call `user.send_reset_password_instructions`. Otherwise log `reset_throttled` (with `user_id`) or `reset_unknown_email` (no id).
    - Always `redirect_to new_user_session_path, notice: I18n.t("devise.passwords.send_paranoid_instructions")`.
  - **`update`**:
    ```ruby
    super do |user|
      next unless user.errors.empty?
      user.activate!
      user.unlock_access! if user.access_locked? || user.failed_attempts.positive?
      log(:reset_completed, user)
    end
    ```
    Comment: Devise yields before its `active_for_authentication?` check and `sign_in` (5.0.4, `passwords_controller.rb#update`). Devise's own unlock is gated on the `:email` unlock strategy, and ours is `:time` (research R4).

  Add a private `log(event, user = nil)` writing `[account_mail] event=… user_id=…`. Header comment maps the actions to FR-014 through FR-020, FR-023 and FR-040.
- [X] T043 [US3] In `app/views/devise/sessions/new.html.erb`, under the existing "no account" `.meta` paragraph, add `<p class="meta"><%= link_to t(".forgot_password"), new_user_password_path, class: "auth-link" %></p>` (FR-014). Add `devise.sessions.new.forgot_password` to `en.yml` ("Forgot your password?") and `fr.yml` ("Mot de passe oublié ?").
- [X] T044 [US3] Create `app/views/devise/passwords/new.html.erb` using the auth shell, as in T028. It contains:
  - `h1` `t(".title")`
  - `p.card-lead` `t(".lead")`
  - `form_for(resource, as: resource_name, url: password_path(resource_name), html: { method: :post, class: "stack-tight", novalidate: true })` with an email `.field` (`autocomplete: "email"`)
  - `f.submit t(".submit"), class: "btn btn-primary w-full", data: { turbo_submits_with: t(".submitting") }`
  - a `.meta` link back to sign-in

  Keys in `en.yml` and `fr.yml` under `devise.passwords.new`:
  - `title`: "Forgot your password?" / "Mot de passe oublié ?"
  - `lead`: "Enter your address and we will email you a link to choose a new password." / "Saisissez votre adresse : nous vous enverrons un lien pour choisir un nouveau mot de passe."
  - `submit`: "Send the link" / "Envoyer le lien"
  - `submitting`: "Sending…" / "Envoi…"
  - `back`: "Back to sign in" / "Retour à la connexion"
- [X] T045 [US3] Create `app/views/devise/passwords/edit.html.erb`, mirroring `devise/registrations/new.html.erb`'s password block exactly: the `password-confirmation` controller on the form, `render "devise/shared/password_field"` for both fields with `subject:` values, `password_hint` with `@minimum_password_length`, and the hidden live mismatch hint. It posts `form_for(resource, as: resource_name, url: password_path(resource_name), html: { method: :put, class: "stack-tight", novalidate: true, data: { controller: "password-confirmation" } })` with `f.hidden_field :reset_password_token`.
  - Render `devise/shared/error_messages`.
  - **Additionally**, when `resource.errors.include?(:reset_password_token)`, render a `.meta` link `t(".request_new")` → `new_user_password_path` (FR-020).
  - Keys in `en.yml` and `fr.yml` under `devise.passwords.edit`:
    - `title`: "Choose a new password" / "Choisissez un nouveau mot de passe"
    - `password_subject`: "new password" / "nouveau mot de passe"
    - `password_confirmation_subject`: "confirm new password" / "confirmation du nouveau mot de passe"
    - `submit`: "Save my new password" / "Enregistrer" (shortened: the longer French label overflowed the button at phone width)
    - `submitting`: "Saving…" / "Enregistrement…"
    - `request_new`: "Request a new link" / "Demander un nouveau lien"
  - Add `activerecord.attributes.user.reset_password_token` ("This link" / "Ce lien") so that the full error message reads "This link has expired, please request a new one."
- [X] T046 [US3] Create `app/views/devise/mailer/reset_password_instructions.html.erb` and `.text.erb` with the heading, why, what, and `render "devise/mailer/action", …, url: edit_password_url(@resource, reset_password_token: @token), validity: t("mailer.reset_password_instructions.validity")`, then not_you. Add to both locale files under `mailer.reset_password_instructions`:
  - `heading`: "Choose a new password" / "Choisissez un nouveau mot de passe"
  - `why`: "Someone asked to reset the password of the LockSwap account for this address." / "Quelqu'un a demandé à réinitialiser le mot de passe du compte LockSwap associé à cette adresse."
  - `what`: "Follow the link below to choose a new one." / "Suivez le lien ci-dessous pour en choisir un nouveau."
  - `button`: "Choose a new password" / "Choisir un nouveau mot de passe"
  - `validity`: "This link works for 6 hours, and only once." / "Ce lien est valable 6 heures, une seule fois."
  - `not_you`: "If you did not ask for this, ignore this email: your password will not change." / "Si vous n'avez rien demandé, ignorez cet e-mail : votre mot de passe ne changera pas."
- [X] T047 [US3] Create `app/views/devise/mailer/password_change.html.erb` and `.text.erb` with no action partial and **no link** (FR-039): the heading, then `t("mailer.password_change.body", time: l(Time.current, format: :long))`, then `t("mailer.password_change.not_you")`. Add to both locale files:
  - `heading`: "Your password was changed" / "Votre mot de passe a été modifié"
  - `body`: "The password of your LockSwap account was changed on %{time}." / "Le mot de passe de votre compte LockSwap a été modifié le %{time}."
  - `not_you`: "If you did not do this, contact an administrator right away." / "Si ce n'est pas vous, contactez immédiatement un administrateur."
- [X] T048 [US3] Override the Devise strings in `devise.en.yml` and `devise.fr.yml`:
  - `devise.passwords.send_paranoid_instructions`: "If an account exists for this address, we have sent it a link to choose a new password." / "Si un compte existe pour cette adresse, nous lui avons envoyé un lien pour choisir un nouveau mot de passe."
  - `devise.passwords.updated`: "Your password has been changed. You are signed in." / "Votre mot de passe a été modifié. Vous êtes connecté."

**Checkpoint**: Password recovery exists for the first time (SC-005). The three P1 stories are complete.

---

## Phase 6: User Story 4 — Request a new activation email (Priority: P2)

**Goal**: A permanent link on sign-in leads to a resend screen with a generic answer, a 5-minute window,
and a fresh token on each send, so older links stop working.

**Independent Test**: With an unactivated account, request a new email, check that the first link is now
refused and the new one activates the account.

### Tests for User Story 4 ⚠️ Write first; confirm they fail before implementing

- [X] T049 [P] [US4] Add to `test/models/user_test.rb` the test that **must fail against stock Devise** (research R17). Create an unconfirmed user and capture `old = user.confirmation_token`. Then `travel 6.minutes` and call `user.resend_activation!`. Expect:
  - `user.reload.confirmation_token != old`
  - `confirmation_sent_at` has moved forward
  - `User.confirm_by_token(old).errors[:confirmation_token]` is present
  - `User.confirm_by_token(user.confirmation_token)` has no errors

  Also: `resend_activation!` on a confirmed account enqueues nothing.
- [X] T050 [P] [US4] Add to `test/controllers/users/confirmations_controller_test.rb` the `create` tests:
  - An unconfirmed address, more than 5 minutes after signup, enqueues one email and redirects to sign-in with `devise.confirmations.send_paranoid_instructions` (FR-011).
  - An unconfirmed address within 5 minutes of signup enqueues nothing, with the same redirect and notice (FR-023).
  - An active address (`users(:alice)`) enqueues nothing, with the same response (FR-013).
  - An unknown address enqueues nothing, with the same response (FR-013).
  - Mixed-case, space-padded input (" Pending@Example.com ") matches.
- [X] T051 [P] [US4] Add to `test/system/account_activation_test.rb`: sign up, `travel 6.minutes`, click "Didn't receive the activation email?" on sign-in, submit the address, and see the generic notice. Then visit the **first** email's link: refused as unrecognised. Visit the **second**: activated. Add `assert_axe_clean` on the resend screen.

### Implementation for User Story 4

- [X] T052 [US4] In `app/models/user.rb`, add `resend_activation!`:
  ```ruby
  self.confirmation_token = nil
  resend_confirmation_instructions
  ```
  Comment: devise 5.0.4 `Confirmable#generate_confirmation_token` (lines 248–255) re-sends the **same** token while it is unexpired, without moving `confirmation_sent_at`. That would leave every earlier email working, against FR-012. Blanking the token forces Devise's fresh-token branch (research R17). Devise's `pending_any_confirmation` already makes it a no-op for an active account.
- [X] T053 [US4] Add `create` to `app/controllers/users/confirmations_controller.rb`, following the shape of T042:
  - `RESEND_COOLDOWN = 5.minutes`
  - normalise the email
  - `user = User.find_by(email:)`
  - if `user && !user.confirmed? && (user.confirmation_sent_at.nil? || user.confirmation_sent_at <= RESEND_COOLDOWN.ago)`, call `user.resend_activation!` and log `activation_resent`
  - otherwise log `activation_throttled`, `resend_for_active` or `resend_unknown_email`
  - always `redirect_to new_user_session_path, notice: I18n.t("devise.confirmations.send_paranoid_instructions")`

  Never call Devise's `resend_confirmation_instructions` directly.
- [X] T054 [US4] In `app/views/devise/sessions/new.html.erb`, under the forgot-password link (T043), add `<p class="meta"><%= link_to t(".no_activation_email"), new_user_confirmation_path, class: "auth-link" %></p>` (FR-011). Add `devise.sessions.new.no_activation_email` to `en.yml` ("Didn't receive the activation email?") and `fr.yml` ("Vous n'avez pas reçu l'e-mail d'activation ?").
- [X] T055 [US4] Override `devise.confirmations.send_paranoid_instructions` in `devise.en.yml` and `devise.fr.yml`: "If this address belongs to an account that is not yet activated, we have sent it a new activation link." / "Si cette adresse correspond à un compte pas encore activé, nous lui avons envoyé un nouveau lien d'activation."

**Checkpoint**: A lost or expired activation email is recoverable without support. T033 (US2) now
passes.

---

## Phase 7: User Story 5 — Operators configure outgoing email per environment (Priority: P2)

**Goal**: SMTP, the sender and the link host come from ENV or credentials per deployment. Development
without SMTP shows mail in a web inbox, and production records delivery failures.

**Independent Test**: With `SMTP_*` and `APP_HOST` set, the resulting `ActionMailer` configuration uses
SMTP, the given sender and the given host. With none set in development, the delivery method is
`:letter_opener_web`.

### Tests for User Story 5 ⚠️ Write first; confirm they fail before implementing

- [X] T056 [P] [US5] Create `test/lib/mailer_settings_test.rb` (`ActiveSupport::TestCase`), stubbing `ENV` with `ClimateControl`-style helpers written inline (save, set and restore in `ensure`; no new gem) and `Rails.application.credentials` with `stub(:dig, …)`. Cover:
  - ENV wins over credentials.
  - Credentials are used when ENV is unset or empty.
  - The default is used when both are missing.
  - `integer_setting` casts `"587"` to `587`.
  - `boolean_setting` casts `"false"` to `false`.
  - `smtp_configured?` is false when `SMTP_PASSWORD` is missing and true with all four present.
  - `mailer_sender` prefers `SMTP_SENDER` over `MAILER_SENDER`.
  - `default_url_options` compacts nil port and protocol.

### Implementation for User Story 5

- [X] T057 [US5] In `config/environments/production.rb`, replace `config.action_mailer.default_url_options = { host: "example.com" }` and the commented SMTP block with:
  ```ruby
  config.action_mailer.default_url_options = Lockswap::MailerSettings.default_url_options(default_host: "lockswap.saumon.cc", default_protocol: "https")
  config.action_mailer.raise_delivery_errors = true
  ```
  Then, if `Lockswap::MailerSettings.smtp_configured?`, set `delivery_method = :smtp` and `smtp_settings = Lockswap::MailerSettings.smtp_settings`. Otherwise add `config.after_initialize { Rails.logger.warn("[account_mail] SMTP is not configured; account emails will fail to deliver") }`. Comments must cite FR-027, FR-029, FR-031 and contracts/mail-configuration.md.
- [X] T058 [US5] In `config/environments/development.rb`, replace the `default_url_options` line with `Lockswap::MailerSettings.default_url_options(default_host: "localhost", default_port: 3000, default_protocol: "http")`. Set `raise_delivery_errors = Lockswap::MailerSettings.smtp_configured?`. If configured, use `:smtp` with the settings; else use `config.action_mailer.delivery_method = :letter_opener_web` (FR-030, research R12).
- [X] T059 [US5] In `config/routes.rb`, add `mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?`, with a comment citing 034 FR-030. It is never mounted in production or test.
- [X] T060 [US5] In `config/deploy.yml`, add `SMTP_USERNAME` and `SMTP_PASSWORD` under `env.secret`, and `APP_HOST: lockswap.saumon.cc`, `SMTP_ADDRESS`, `SMTP_PORT: 587` and `SMTP_SENDER: "LockSwap <no-reply@lockswap.saumon.cc>"` under `env.clear`. Leave `SMTP_ADDRESS` as a commented placeholder the operator fills in, and comment that the credentials `smtp:` keys are the alternative. In `.kamal/secrets`, add `SMTP_USERNAME=$SMTP_USERNAME` and `SMTP_PASSWORD=$SMTP_PASSWORD`, with a comment: never commit a raw value.
- [X] T061 [US5] In `README.md`'s "🚢 Deploy" section, add a "### Mail" subsection. It contains the ENV/credentials table from contracts/mail-configuration.md, the rule that SMTP is only used when address, port, user and password are all set, the production failure visibility (Solid Queue failed executions plus the log), and the development inbox at `/letter_opener`.

**Checkpoint**: The app can actually send mail in production and be exercised in development.

---

## Phase 8: User Story 6 — Confirm a changed email address (Priority: P3)

**Goal**: Changing the address on the account page sends a "confirm your new address" email to the new
address. The old address stays in force until the link is followed.

**Independent Test**: Change the email on the account page. The old address still signs in and the
account page names the pending address. Follow the link sent to the new address; only the new address
then signs in.

### Tests for User Story 6 ⚠️ Write first; confirm they fail before implementing

- [X] T062 [P] [US6] Add to `test/mailers/user_mailer_test.rb`: for a user with `unconfirmed_email` set, `UserMailer.confirmation_instructions(user, "tok", to: user.unconfirmed_email)` is addressed to the new address, has the subject "Confirm your new LockSwap email address" ("Confirmez votre nouvelle adresse e-mail LockSwap" in fr), and the body contains the reconfirmation heading, not "Activate your account".
- [X] T063 [P] [US6] Create `test/system/email_change_test.rb`:
  - `log_in_as(users(:alice))`, open the account page, change the email to "alice.new@example.com" and enter the current password.
  - Expect the `update_needs_confirmation` notice and the text "alice.new@example.com" in the waiting hint.
  - Log out, then log in with alice@example.com (still works).
  - `visit link_from_last_email(%r{confirmation_token=})`, log out if needed, then log in with alice.new@example.com (works) and alice@example.com (refused).

### Implementation for User Story 6

- [X] T064 [US6] Complete `app/views/devise/mailer/confirmation_instructions.html.erb` and `.text.erb` with the `@resource.pending_reconfirmation?` branch, using the same structure and `mailer.reconfirmation_instructions.*` keys. Add to both locale files:
  - `subject`: "Confirm your new LockSwap email address" / "Confirmez votre nouvelle adresse e-mail LockSwap"
  - `heading`: "Confirm your new address" / "Confirmez votre nouvelle adresse"
  - `why`: "This address was entered as the new email of a LockSwap account." / "Cette adresse a été saisie comme nouvel e-mail d'un compte LockSwap."
  - `what`: "Follow the link below to confirm it. Until then, the account keeps its previous address." / "Suivez le lien ci-dessous pour la confirmer. D'ici là, le compte conserve son adresse précédente."
  - `button`: "Confirm this address" / "Confirmer cette adresse"
  - `validity`: "This link works for 24 hours." / "Ce lien est valable 24 heures."
  - `not_you`: "If you did not ask for this, ignore this email: nothing will change." / "Si vous n'avez rien demandé, ignorez cet e-mail : rien ne changera."
- [X] T065 [US6] Override `devise.registrations.update_needs_confirmation` in `devise.en.yml` and `devise.fr.yml`: "Your account is updated. We have sent a link to your new address: your email will change once you follow it." / "Votre compte est mis à jour. Nous avons envoyé un lien à votre nouvelle adresse : votre e-mail changera une fois ce lien suivi." Check that `devise.registrations.edit.waiting_confirmation_for` exists in both `en.yml` and `fr.yml` (the account page already renders it). Add it if not: "Waiting for confirmation of: %{email}" / "En attente de confirmation : %{email}".

**Checkpoint**: The guarantee of US1 ("the address on file reaches its holder") cannot be bypassed by
editing the address.

---

## Phase 9: User Story 7 — An administrator activates an account by hand (Priority: P3)

**Goal**: The admin Users list and detail screen show "Not activated". An admin can activate from the
detail screen, which records who did it and when, and no email is sent.

**Independent Test**: Create an unactivated account. The list and the detail screen show it as not
activated. Activate it from the detail screen: the provenance is shown, the control disappears, and the
holder can sign in.

### Tests for User Story 7 ⚠️ Write first; confirm they fail before implementing

- [X] T066 [P] [US7] Create `test/controllers/admin/user_activations_controller_test.rb` (`include Devise::Test::IntegrationHelpers`), mirroring `test/controllers/admin/user_locker_wishes_controller_test.rb`'s structure:
  - An admin posts `admin_user_activation_path(pending)`: `pending.reload.confirmed?`, `confirmed_by == admin`, a redirect to `admin_user_path(pending)` with the `.activated` notice, and `assert_no_enqueued_emails` (FR-035, FR-036, FR-038).
  - Posting again gives the `.already_active` notice, and `confirmed_by` is unchanged.
  - A standard user gets a redirect to root with `I18n.t("application.administrators_only")` and the account stays unconfirmed (FR-037).
  - Anonymous access redirects to sign-in.
  - An unknown id redirects to `admin_users_path` with the `.account_gone` alert.
  - The old activation link, followed after a manual activation, yields `already_active` (FR-038, research R6).
- [X] T067 [P] [US7] Add to `test/models/user_test.rb`: destroying the admin who activated an account nullifies `confirmed_by_id` and keeps `confirmed_at` (FR-036).
- [X] T068 [P] [US7] Create `test/system/admin_user_activation_test.rb`:
  - Log in as the fixture admin, with an unconfirmed `User.create!` in setup.
  - On Admin → Users, that row shows "Not activated" and a fixture row does not.
  - Open its detail screen: "Not activated" is shown. Accept the confirm with `accept_confirm_reliably { click_button "Activate account" }`.
  - Expect the notice, "Activated by <admin email> on", and no "Activate account" button.
  - Log out; the account logs in.

  Add `assert_axe_clean` on the detail screen in both states.

### Implementation for User Story 7

- [X] T069 [US7] In `config/routes.rb`, inside `namespace :admin` → `resources :users`, add `resource :activation, only: :create, controller: "user_activations"`, with a comment citing 034 FR-035 and research R14 (a nested singular resource, like 027's `locker_profile`/`locker_wish`; never a general `#update`, 015 FR-014).
- [X] T070 [US7] Create `app/controllers/admin/user_activations_controller.rb` with `before_action :authenticate_user!` and `before_action :require_admin!`.
  - `create`:
    - `user = User.find_by(id: params[:user_id])`; if nil, `redirect_to admin_users_path, alert: t(".account_gone")`.
    - `activated = user.activate!(by: current_user)`.
    - Log `activated_by_admin user_id=… admin_id=…` when `activated`.
    - `redirect_to admin_user_path(user), notice: activated ? t(".activated", email: user.email) : t(".already_active", email: user.email)`.
  - Header comment citing FR-035 to FR-038: it sends no email, and the conditional UPDATE in `activate!` settles the race with a link click.
  - Keys in `en.yml` and `fr.yml` under `admin.user_activations.create`:
    - `activated`: "%{email} is now activated." / "%{email} est maintenant activé."
    - `already_active`: "%{email} was already activated." / "%{email} était déjà activé."
    - `account_gone`: "That account no longer exists." / "Ce compte n'existe plus."
- [X] T071 [US7] In `app/controllers/admin/users_controller.rb#show`, add `:confirmed_by` to the `User.includes(…)` list, with a comment: 034 FR-036, the activating admin's email without a second query. `index` needs no change, because `confirmed_at` is a column on rows already loaded.
- [X] T072 [US7] In `app/views/admin/users/index.html.erb`, in the email cell, when `user.confirmed_at.nil?`, wrap the existing link and a `<span class="badge badge-neutral"><%= t(".not_activated") %></span>` in `<div class="cell-stack">`. Otherwise render exactly as today. Add a comment citing FR-034: the badge's words carry the meaning, not its tint (008 FR-025). Keys under `admin.users.index`: `not_activated`: "Not activated" / "Non activé".
- [X] T073 [US7] In `app/views/admin/users/show.html.erb`:
  - **Activation row**: add a `<div>` to the `detail-grid` right after "Joined", with `dt` `t(".activation_label")` and a `dd` whose `id` is `admin-user-detail-activation`:
    - when not activated: `t(".not_activated")`, with class `detail-value-empty`
    - when `@user.activated_by_admin?` and `@user.confirmed_by` is present: `t(".activated_by", email: @user.confirmed_by.email, date: l(@user.confirmed_at, format: :long))`
    - when `activated_by_admin?` but the admin's account is gone: `t(".activated_by_removed_admin", date: …)`
    - otherwise: `t(".activated_on", date: …)`
  - **Activate button**: immediately after the grant/revoke controls, when `@user.confirmed_at.nil?`, add
    ```erb
    button_to t(".activate_button"), admin_user_activation_path(@user), method: :post,
      data: { confirm: activate_message, turbo_confirm: activate_message },
      aria: { label: t(".activate_aria_label", email: @user.email) },
      class: "btn btn-secondary btn-sm"
    ```
    where `activate_message = t(".activate_confirm", email: @user.email)`.
  - Keys in `en.yml` and `fr.yml` under `admin.users.show`:
    - `activation_label`: "Activation" / "Activation"
    - `not_activated`: "Not activated" / "Non activé"
    - `activated_on`: "Activated on %{date}" / "Activé le %{date}"
    - `activated_by`: "Activated by %{email} on %{date}" / "Activé par %{email} le %{date}"
    - `activated_by_removed_admin`: "Activated by an administrator whose account has since been removed, on %{date}" / "Activé par un administrateur dont le compte a depuis été supprimé, le %{date}"
    - `activate_button`: "Activate account" / "Activer le compte"
    - `activate_aria_label`: "Activate the account %{email}" / "Activer le compte %{email}"
    - `activate_confirm`: "Activate %{email}? They will be able to sign in without the email." / "Activer %{email} ? Cette personne pourra se connecter sans l'e-mail."

**Checkpoint**: Support has a way out when email delivery fails (SC-009). All seven stories are
complete.

---

## Phase 10: Polish & Cross-Cutting Concerns

- [X] T074 [P] Create `test/mailers/previews/devise_mailer_preview.rb` (`class DeviseMailerPreview < ActionMailer::Preview`) with four methods: `activation`, `reconfirmation`, `reset_password` and `password_change`. Each builds an unsaved `User.new(email: "preview@example.com")` (plus `unconfirmed_email` for reconfirmation) and calls `UserMailer.…(user, "preview-token", …)`. Check that `config.action_mailer.preview_paths` includes `test/mailers/previews` (the Rails default).
- [X] T075 [P] Add the four new auth screens (forgot password, new password with a real token from `user.send(:set_reset_password_token)`, resend activation, and the confirmation failure page) to `test/system/accessibility_test.rb`, with `assert_axe_clean` on each, in the file's existing style.
- [X] T076 Look at the work (CLAUDE.md, "How to check the work"). Run `bin/rails tailwindcss:build`. Write a throwaway `test/system/zz_design_capture_test.rb` that screenshots the sign-in page (with the two new links), forgot password, new password, resend activation, and the admin detail of an unactivated account, at desktop and `with_viewport(:phone)`, calling `wait_for_entrance` and saving to `tmp/design/`. Read every image. Also open `/rails/mailers` in development and check the four emails at 320px and 600px in both languages. Fix anything off-contract, then **delete** the throwaway test.
- [X] T077 Run `bin/rubocop`, `bin/brakeman --no-pager`, `bin/bundler-audit` and `bin/importmap audit`, and fix every finding (Constitution quality gates).
- [X] T078 Run the full `bin/rails test` and `bin/rails test:system` (including `test/i18n_completeness_test.rb` and `test/stylesheet_breakpoint_test.rb`); all must pass.
- [X] T079 Walk through `specs/034-email-confirmation-password-reset/quickstart.md` scenarios 1–23 against a development server with letter_opener_web, and note any divergence. — *Done as: every scenario covered by the automated suites (controller, mailer and system tests), plus a development smoke run of signup → letter_opener_web inbox (FR-030). Scenario 23 (a real SMTP server refusing delivery) was not exercised: no SMTP server was available.*
- [X] T080 [P] Update the Notes of `specs/034-email-confirmation-password-reset/checklists/requirements.md`. The "Decisions taken by default" sentence is stale since `/speckit-clarify`: a reset now activates the account and ends the lockout, and admin tooling exists (US7).
- [X] T081 Draft the PR description. It must include:
  - the principles touched, one line each
  - the **breaking change** (signup no longer signs in)
  - the new gem (letter_opener_web, development only) and why
  - the two Devise corrections (R4, R17), each with the test that proves it
  - the operator steps (SMTP env/credentials in `deploy.yml` and secrets) (Constitution Development Workflow)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none. T003 depends on T002.
- **Foundational (Phase 2)**: depends on Setup. T004 → T005 → T006 → T008. T009 depends on T003. T013 depends on T012. T019 closes the phase and depends on everything in it. **This phase blocks every story.**
- **US1 (Phase 3)**: after Foundational.
- **US2 (Phase 4)**: after Foundational. Its T033 link assertion only passes once US4's T054 lands.
- **US3 (Phase 5)**: after Foundational, and it needs US1's T027 (routes and the stub passwords controller). T041 (`activate!`) is also used by US7.
- **US4 (Phase 6)**: after US1, because it extends `Users::ConfirmationsController` and reuses the `confirmations/new` view.
- **US5 (Phase 7)**: after Setup T002/T003 and Foundational. It is independent of US1–US4 and US6–US7.
- **US6 (Phase 8)**: after US1's T030 (the confirmation mail view it completes).
- **US7 (Phase 9)**: after US3's T041 (`activate!`).
- **Polish (Phase 10)**: after all the desired stories.

### Within Each User Story

Tests come first and must fail. Then the model, controller, view and locale work, in that order. Each
story's checkpoint is its independent test.

### Parallel Opportunities

- Phase 2: T007, T010, T011, T012, T015, T017 and T018 touch different files.
- Every story's test tasks marked [P] (for example T020, T021, T022 and T023) touch different files.
- After Foundational, US5 can run alongside US1. After US1, US4 and US6 can run alongside each other.
  After US3, US7 can run alongside US4, US5 and US6.
- The same-file conflicts to watch are `config/routes.rb` (T027, T059, T069), `app/models/user.rb`
  (T008, T041, T052), `app/views/devise/sessions/new.html.erb` (T043, T054), and the four locale files,
  which almost every story touches. Serialise edits to those files.

---

## Parallel Example: Foundational Phase

```bash
Task: "T007 Confirm every fixture row in test/fixtures/users.yml"
Task: "T010 ApplicationMailer sender + site-language around_action in app/mailers/application_mailer.rb"
Task: "T011 UserMailer < Devise::Mailer in app/mailers/user_mailer.rb"
Task: "T012 MailerHelper colour map in app/helpers/mailer_helper.rb"
Task: "T018 Mail test helpers in test/support/mail_helpers.rb"
```

## Parallel Example: User Story 1

```bash
Task: "T020 Model tests for delivery + unconfirmed state in test/models/user_test.rb"
Task: "T021 Confirmations#show tests in test/controllers/users/confirmations_controller_test.rb"
Task: "T022 confirmation_instructions mailer tests in test/mailers/user_mailer_test.rb"
Task: "T023 Signup → email → activate → sign in in test/system/account_activation_test.rb"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Phase 1 Setup, then Phase 2 Foundational (T019 green except the two signup tests).
2. US1, then **validate** (quickstart scenarios 2, 5, 6, 7).
3. US2, then **validate** (quickstart 3, 4). This already meets the request's core sentence.
4. Do **not** deploy the MVP without US5. Production cannot send mail until its SMTP wiring lands, and
   without mail no new account can ever activate. For a real release, the smallest safe cut is
   **US1 + US2 + US4 + US5**.

### Incremental Delivery

1. Foundation, then US1 + US2 (activation enforced).
2. US3: password recovery exists for the first time.
3. US4 + US5: recoverable activation and a working production mailer. **This is the first releasable
   increment.**
4. US6: the email-change loophole is closed.
5. US7: an admin escape hatch for delivery failures.
6. Polish: look at every screen and email, audits, PR.

### Notes

- [P] tasks touch different files and depend on no unfinished task.
- Commit after each task or logical group, and stop at any checkpoint to validate that story on its own.
- Every new user-facing string goes into **both** locale files of its pair in the same task
  (`test/i18n_completeness_test.rb` enforces this).
