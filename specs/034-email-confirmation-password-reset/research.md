# Research: Email Confirmation of New Accounts and Password Reset by Email

**Feature**: 034-email-confirmation-password-reset | **Date**: 2026-09-29

Every decision below was checked against the installed Devise (`devise-5.0.4`, read from the gem's own
source where behaviour mattered) and against the reference project named in the request,
[saumon/hitguessr](https://github.com/saumon/hitguessr) (its `001-account-email-verification` feature,
`config/mailer_settings.rb`, `Users::ConfirmationsController`).

---

## R1 — Devise modules: turn on `:confirmable` and `:recoverable`, nothing else

**Decision**: `User` gains `:confirmable` and `:recoverable` alongside the existing
`:database_authenticatable, :registerable, :rememberable, :lockable, :validatable`. No third-party
extension (no `devise-async`, no custom token model).

**Rationale**: The two modules already implement, and hold the data for, nearly every spec requirement:

| Spec | Devise behaviour it rests on |
|---|---|
| FR-001/FR-002 | `:confirmable` sends `confirmation_instructions` in an `after_commit on: :create` |
| FR-005/FR-006 | `active_for_authentication?` is false while unconfirmed; the `DatabaseAuthenticatable` strategy only reaches that check *after* `valid_password?` succeeds, so a wrong password still fails as `:invalid` — FR-006 holds without code |
| FR-007 | `config.confirm_within = 24.hours` |
| FR-012 | **Not by default** — see R17: Devise reuses an unexpired token on resend; `User#resend_activation!` forces a fresh one |
| FR-018 | `config.reset_password_within = 6.hours` (already set); the token is cleared on successful reset (single use) and replaced on each new request |
| FR-021/FR-022 | `config.reconfirmable = true` (already set); `unconfirmed_email` column; the account-edit view already renders `waiting_confirmation_for` when `pending_reconfirmation?` |
| FR-039 | `config.send_password_change_notification = true` fires `password_change` from an `after_update` whenever `encrypted_password` changed — both the reset path and the account page |

**Alternatives considered**: hitguessr's runtime feature toggle (`ACCOUNT_EMAIL_CONFIRMATION_ENABLED`,
default *off* in development and test). Rejected: the spec makes activation unconditional, and a toggle
that is off in the test environment means the suite would not exercise the behaviour the feature exists
for. Tests instead mark fixture accounts as confirmed (R11).

---

## R2 — Generic responses: turn on `config.paranoid`, and still override the two `create` actions

**Decision**: Set `config.paranoid = true`. Also add `Users::ConfirmationsController#create` and
`Users::PasswordsController#create`. Whatever happened (sent, throttled, unknown address, already active),
they always redirect to the sign-in screen with Devise's `send_paranoid_instructions` notice.

**Rationale**: Paranoid mode has three effects in 5.0.4, and each was checked against this app:
- `DeviseController#successfully_sent?` always reports success, which covers FR-013 and FR-016 on the
  stock actions.
- The `DatabaseAuthenticatable` strategy hashes a password even for an unknown email (a timing side
  channel closed), and fails with `:invalid` rather than `:not_found_in_database`.
- `Lockable#unauthenticated_message` returns `:invalid` instead of `:locked`.

The last two change **nothing visible**. `config/locales/devise.en.yml` and `devise.fr.yml` already map
`invalid`, `not_found_in_database`, `locked` and `last_attempt` to the same "Invalid email or password"
sentence (001 FR-006). The overrides are still needed, because paranoid mode knows nothing about
FR-023's 5-minute window or FR-032's support log. Owning the redirect there also keeps the generic answer
true by construction, even if paranoid mode were ever switched off.

**Check**: `test/system/account_lockout_test.rb` and `login_failure_test.rb` must stay green unchanged.
That is the evidence that paranoid mode is invisible to 001.

**Alternatives considered**: leaving paranoid off, with the overrides alone (hitguessr's choice). That
works for the two screens, but it misses the sign-in timing protection for free.

---

## R3 — Rate limit (FR-023): the `*_sent_at` columns, per account

**Decision**: Before sending, the two `create` overrides skip the send when
`confirmation_sent_at > 5.minutes.ago` (activation) or `reset_password_sent_at > 5.minutes.ago` (reset).
The response is the same generic notice either way. The window is a constant on each controller
(`RESEND_COOLDOWN = 5.minutes`), mirroring hitguessr's `RESEND_COOLDOWN_SECONDS`.

**Rationale**: Devise already stamps both columns when it issues a token, so the check needs no new state
and is exact per address, which is what FR-023 asks. The signup email itself stamps
`confirmation_sent_at`, so an immediate resend after signup is (correctly) throttled.

**Alternatives considered**: Rails 8 `rate_limit` (per-IP, cache-backed). It limits a *client*, not an
*address*, so it neither satisfies FR-023 nor protects a victim's inbox from requests spread across IPs.
It can be layered later if abuse appears; not needed for the spec.

---

## R4 — Completing a reset activates the account and ends the lockout (FR-019, FR-040)

**Decision**: `Users::PasswordsController#update` calls `super` with a block. When the reset succeeded
(`resource.errors.empty?`), the block calls `resource.activate!` (R6) and `resource.unlock_access!`
before Devise's own `sign_in`.

**Rationale**: Reading `app/controllers/devise/passwords_controller.rb#update` (5.0.4): the block is
yielded after `reset_password_by_token` and **before** the `active_for_authentication?` check and
`sign_in`. Devise's own unlock there is gated on `unlock_strategy_enabled?(:email)`, and LockSwap's strategy
is `:time` — so without this, a locked user would reset their password and then be refused. Doing both in
the block means Devise's existing `:updated` flash and sign-in run unchanged.

**Alternatives considered**: switching `unlock_strategy` to `:both` — it would also add unlock-by-email
instructions and a third email type nobody asked for.

---

## R5 — No `confirm` on reset; a dedicated conditional write

**Decision**: Activation outside the confirmation link (after a reset, or by an administrator) goes through
one model method, `User#activate!(by: nil)`, implemented as a single conditional `UPDATE … WHERE
confirmed_at IS NULL` (`update_all`), returning whether this call did the activation.

**Rationale**: Devise's `confirm` also promotes `unconfirmed_email` to `email` when a change is pending —
the spec (edge case, US7) says activating by hand must *not* confirm a pending new address. A conditional
update is also what makes the admin/link race (spec edge case) safe without a lock: whichever write lands
second changes zero rows and reports "already active".

**Alternatives considered**: `skip_confirmation!` + `save!` — runs validations and callbacks on a record
the admin never edited, and is not atomic against the concurrent link click.

---

## R6 — Outstanding activation links after an out-of-band activation (FR-038, edge case)

**Decision**: `activate!` leaves `confirmation_token` in place.

**Rationale**: Devise's `confirm_by_token` finds the account by that token and, because it is already
confirmed, answers `already_confirmed` — the spec's "already active, sign in" outcome. Clearing the token
would turn the same click into "unrecognised link", which is less helpful and no safer: in neither case is
anything activated. The link is therefore "invalid" in the only sense that matters (it activates nothing).

---

## R7 — Where the sign-up visitor lands

**Decision**: `RegistrationsController#after_inactive_sign_up_path_for` → `new_user_session_path`. Devise's
`signed_up_but_unconfirmed` notice is shown there, and the sign-in screen permanently carries the
"Didn't receive the activation email?" link.

**Rationale**: Devise's default inactive path is `root_path`, which `authenticate_user!` would bounce to
sign-in with a "please sign in" alert that *replaces* the notice. Flash messages on this site are
auto-dismissing toasts (023), so the durable guidance cannot live only in the toast: the resend link on
the sign-in screen is always present (FR-011), and the unconfirmed-refusal text points at it rather than
embedding a link inside a toast that disappears.

**Alternatives considered**: a dedicated "check your inbox" page. Clearer on first read, but it is a new
screen whose only content is one sentence the sign-in screen can already carry; deferred unless user
testing shows the toast is missed.

---

## R8 — Delivery off the request path (FR-028)

**Decision**: `User#send_devise_notification` is overridden to `devise_mailer.send(notification, self,
*args).deliver_later` (the Devise README's documented Active Job hook). `config.parent_mailer =
"ApplicationMailer"` so Devise's mails use the application layout, sender and locale handling.

**Rationale**: Solid Queue already runs inside Puma in production (`SOLID_QUEUE_IN_PUMA`), so no new
process. A mail server that is slow or down therefore never delays or fails signup, resend or reset
(FR-028). Development uses Rails' default `:async` adapter, which is enough.

**Note**: `:confirmable` sends from `after_commit`, so the job is only enqueued once the account row
exists — no job can race a rolled-back signup.

---

## R9 — The email's language (FR-024)

**Decision**: `ApplicationMailer` gets `around_action` that wraps delivery in
`I18n.with_locale(SiteLanguageSetting.current.language.to_sym)`, the same expression
`ApplicationController#switch_locale` uses.

**Rationale**: A mail delivered by a job runs outside any request, where `I18n.locale` is the default
`:en`; the site setting must be read explicitly. Reading it at render time means "the language in force
when sent" — the gap between enqueue and send is seconds.

---

## R10 — Mail configuration, carried over from hitguessr (FR-027, FR-029, FR-030, FR-031)

**Decision**: Port hitguessr's `config/mailer_settings.rb` as `Lockswap::MailerSettings`
(`config/mailer_settings.rb`, required from `config/application.rb`). Each value resolves
**ENV → `Rails.application.credentials` → default**:

| Setting | ENV | credentials key | default |
|---|---|---|---|
| SMTP host | `SMTP_ADDRESS` | `smtp.address` | — |
| port | `SMTP_PORT` | `smtp.port` | — |
| HELO domain | `SMTP_DOMAIN` | `smtp.domain` | — |
| user | `SMTP_USERNAME` | `smtp.user_name` | — |
| password | `SMTP_PASSWORD` | `smtp.password` | — |
| auth | `SMTP_AUTHENTICATION` | `smtp.authentication` | `plain` |
| STARTTLS | `SMTP_ENABLE_STARTTLS_AUTO` | `smtp.enable_starttls_auto` | `true` |
| cert check | `SMTP_OPENSSL_VERIFY_MODE` | `smtp.openssl_verify_mode` | — |
| sender | `SMTP_SENDER` / `MAILER_SENDER` | `smtp.sender` / `mailer.sender` | per env |
| link host | `APP_HOST` | `app.host` | per env |
| link port | `APP_PORT` | `app.port` | per env |
| link protocol | `APP_PROTOCOL` | `app.protocol` | per env |

`smtp_configured?` requires address, port, user_name and password; only then is `delivery_method = :smtp`
set. Defaults per environment:

- **production**: link host `lockswap.saumon.cc` (already in `config.hosts`), protocol `https`;
  `raise_delivery_errors = true` so a refused delivery raises inside the job and Solid Queue records the
  failed execution and its error (FR-031), alongside the job's log line.
- **development**: link host `localhost:3000`, protocol `http`. With SMTP configured, it is used and
  errors raise; without it, delivery goes to **letter_opener_web** (R12).
- **test**: `:test` delivery, unchanged; host `example.com`, unchanged.

Kamal: `config/deploy.yml` gains the non-secret `APP_HOST`, `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_SENDER`
under `env.clear` and `SMTP_USERNAME`, `SMTP_PASSWORD` under `env.secret`, fed from `.kamal/secrets`.
Either channel (ENV or credentials) works; ENV wins (FR-029).

**Alternatives considered**: hard-coding `smtp_settings` from credentials only (the Rails-generated
comment in `production.rb`) — no per-deployment override without re-encrypting credentials, which fails
FR-029's "without changing the application".

---

## R11 — Tests: fixtures confirmed, emails through the job queue

**Decision**:
- Every row in `test/fixtures/users.yml` gains `confirmed_at` (fixtures bypass callbacks, so no mail).
- Tests that build accounts with `User.create!` and then sign in pass `confirmed_at: Time.current`
  (3 files today: 12 call sites). A test that exercises activation deliberately omits it.
- Emails are asserted with `ActionMailer::TestHelper` (`assert_enqueued_email_with`,
  `deliver_enqueued_emails`); system tests pull the link out of the delivered mail with a small helper
  (`link_from_last_email`), then `visit` it.
- `signup_test.rb` changes meaning: signing up no longer signs in. That is the breaking change the spec
  describes and is called out as such (Constitution III).

**Rationale**: Keeps the suite exercising real activation (R1), and keeps the change to existing tests to
one mechanical attribute rather than a toggle.

---

## R12 — Viewing mail in development (FR-030): `letter_opener_web`

**Decision**: Add `letter_opener_web` to the `:development` group, used as the delivery method whenever
SMTP is not configured, and mounted at `/letter_opener` in development routes only.

**Rationale**: Development here runs on a remote box (`lockswap-dev.saumon.cc`, `devbox.saumon.cc`),
so `letter_opener` (opens a local browser) and `:file` delivery (read on the server's disk) are both
awkward; a web inbox served by the app itself is the one that works through the same URL as the app.
Development-only, never loaded in production, audited by the existing `bundler-audit` CI step.

**Alternatives considered**: `:file` delivery to `tmp/mails` — zero dependency but the link must be
copied out of a raw MIME file over SSH. Mailer previews (`test/mailers/previews`) are also added (R13),
but they render samples, not the mail actually sent, so they cannot complete a real activation.

---

## R13 — Email design within the design contract

**Decision**:
- One layout (`app/views/layouts/mailer.html.erb` + `.text.erb`) used by all four emails: the wordmark as
  text ("Lock" navy + "Swap" brand green, SC 1.4.3 brand exemption as on the site), a white card on the
  canvas colour, the body, a single action button, then the link as plain text (FR-025).
- Inline styles only (email clients strip `<style>` and ignore CSS variables). **No hex in ERB** (CLAUDE.md):
  colours come from `MailerHelper#mail_color(:ink)` etc., a Ruby hash whose values are copied from the
  stylesheet tokens with a comment naming each token — one place to update, and the ERB carries names.
- The button is a solid `--color-link` `#0A5AC2` fill with white text (6.45:1). The site's gradient accent
  fill is not used: gradients are unreliable across mail clients, and the white-on-gradient pairing is the
  contract's one known contrast exception, which should not be copied into a second medium.
- Fonts: `Nunito, system-ui, sans-serif` / `"JetBrains Mono", ui-monospace, monospace` stacks; webfonts
  are not loaded in mail. The link-as-text and dates use the mono stack (measured values).
- Mailer previews under `test/mailers/previews/` for all four emails in both languages, so the design is
  reviewed by looking, as CLAUDE.md asks.

---

## R14 — Admin activation route and attribution (FR-034 to FR-038)

**Decision**: `resource :activation, only: :create, controller: "user_activations"` nested under
`admin/users` → `POST /admin/users/:user_id/activation`, handled by `Admin::UserActivationsController`
(`authenticate_user!` + `require_admin!`). Attribution in a new `users.confirmed_by_id` (self-referential,
`dependent: :nullify` from the admin side) — the fourth instance of the
`admin_granted_by`/`locker_edited_by`/`search_cancelled_by` pattern. The timestamp is Devise's own
`confirmed_at`, not a second column.

**Rationale**: The nested singular resource mirrors 027's `admin/users/:id/locker_profile` and
`locker_wish` — each admin write on an account is its own controller with its own rules, never a general
`#update` (015 FR-014).

---

## R15 — Existing accounts (FR-010, clarified)

**Decision**: The migration that adds the Devise columns runs
`UPDATE users SET confirmed_at = CURRENT_TIMESTAMP WHERE confirmed_at IS NULL` in its `up`.

**Rationale**: The timestamp is the release moment — honest about when these accounts entered the
"activated" state, and the admin detail screen will show exactly that. Using `created_at` would claim an
activation that never happened. `confirmed_by_id` stays NULL (not activated by an admin).

---

## R16 — Support log (FR-032)

**Decision**: One `Rails.logger.info` line per event, tagged `[account_mail]`, carrying the event name and
the **user id** (never the email, never a token): `activation_sent`, `activation_resent`,
`activation_throttled`, `activated_by_link`, `activated_by_reset`, `activated_by_admin`, `reset_sent`,
`reset_throttled`, `reset_completed`, `password_change_notified`. Requests for unknown addresses log the
event with no id.

**Rationale**: hitguessr logs the email; LockSwap's `filter_parameter_logging` already treats `:email` as
sensitive, so the log uses the id, which support can resolve on the admin screen.

---

## R17 — Devise reuses the activation token on resend; force a new one (FR-012)

**Finding**: `Devise::Models::Confirmable#generate_confirmation_token` (5.0.4,
`lib/devise/models/confirmable.rb:248-255`) keeps the existing `confirmation_token` whenever it is present
and not expired — and in that branch does **not** touch `confirmation_sent_at`. So a stock
`resend_confirmation_instructions` within 24 hours emails the *same* link again: every earlier email keeps
working, which contradicts FR-012, and the resent link still expires 24 hours after the *first* email, not
the new one. hitguessr's controller comment ("Devise replaces the previous token") is wrong on this point;
its spec's FR-011 is not actually met by that code.

**Decision**: `User#resend_activation!` sets `self.confirmation_token = nil` and then calls
`resend_confirmation_instructions`. With the token blank, Devise takes its "else" branch: a new
`Devise.friendly_token`, a new `confirmation_sent_at`, saved with `save(validate: false)`, then mailed.
`Users::ConfirmationsController#create` calls this method, never Devise's resend directly.

**Test that pins it**: model test — resend, then `User.confirm_by_token(old_raw_token)` has an error on
`confirmation_token`, and the new token activates; and `confirmation_sent_at` moved forward.

**Not affected**: the reset token. `Recoverable#set_reset_password_token` always generates a fresh token
and stamps `reset_password_sent_at`, so FR-018's "newest only" holds without help.
