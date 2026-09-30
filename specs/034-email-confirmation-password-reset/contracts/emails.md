# Contract: Emails

**Feature**: 034-email-confirmation-password-reset

All four emails are Devise's own mailer actions (`Devise::Mailer`, parent `ApplicationMailer`), delivered
with `deliver_later`, rendered in the site language at send time (research R9), each as
`multipart/alternative` HTML + text (FR-026), through one layout (research R13).

| # | Devise action | Sent when | To | Link | Validity stated |
|---|---|---|---|---|---|
| 1 | `confirmation_instructions` | signup; resend; email change (`reconfirmable`) | the new account's address — or, for an email change, the **new** address | `user_confirmation_url(confirmation_token:)` | 24 hours |
| 2 | `reset_password_instructions` | reset requested (outside the 5-min window) | account's address | `edit_user_password_url(reset_password_token:)` | 6 hours |
| 3 | `password_change` | after any change to `encrypted_password` (`send_password_change_notification = true`) | account's address | none (FR-039) | — |

Row 1 has two wordings, chosen in the view by `@resource.pending_reconfirmation?` (Devise passes
`to: unconfirmed_email` for a change): **activate your account** vs **confirm your new address**.
That makes four distinct emails from three mailer actions.

`email_changed` (notification to the *old* address) stays **off** — not in the spec (listed as Outstanding
in the clarification report).

## Envelope

- **From**: `Lockswap::MailerSettings.mailer_sender(default: …)` via `Devise.mailer_sender`, e.g.
  `LockSwap <no-reply@lockswap.saumon.cc>`.
- **Subject**: `devise.mailer.<action>.subject` from `config/locales/devise.en.yml` / `devise.fr.yml` —
  overridden in the project files so both say "LockSwap" and the subject reads as the action:

| Key | en | fr |
|---|---|---|
| `devise.mailer.confirmation_instructions.subject` | Activate your LockSwap account | Activez votre compte LockSwap |
| `devise.mailer.reset_password_instructions.subject` | Reset your LockSwap password | Réinitialisez votre mot de passe LockSwap |
| `devise.mailer.password_change.subject` | Your LockSwap password was changed | Votre mot de passe LockSwap a été modifié |

The email-change variant needs its own subject. `Devise::Mailers::Helpers#headers_for` merges the caller's
`opts` last (5.0.4, `lib/devise/mailers/helpers.rb:44`), so a `UserMailer < Devise::Mailer`
(`config.mailer = "UserMailer"`) overrides `confirmation_instructions(record, token, opts = {})` to set
`opts[:subject] = t("mailer.reconfirmation_instructions.subject")` when `record.pending_reconfirmation?`,
then calls `super`: "Confirm your new LockSwap email address" / "Confirmez votre nouvelle adresse e-mail
LockSwap".

**Sender precedence trap**: `headers_for` drops Devise's `from` whenever the parent mailer has a
`default from:`. `ApplicationMailer` today declares `default from: "from@example.com"`, so once it becomes
Devise's parent (research R8) that placeholder would win. `ApplicationMailer`'s `default from:` must
therefore be set from `Lockswap::MailerSettings.mailer_sender`, the same value as `Devise.mailer_sender`.

## Body structure (FR-025)

```text
[LockSwap wordmark]
Heading — what this is             e.g. "Activate your account"
One sentence — why you got it      "Someone (hopefully you) created a LockSwap account with this address."
One sentence — what the link does  "Follow the link below to activate it; you can then sign in."
[ Button: action ]                 "Activate my account"     ← links only (1, 2)
Plain link, copyable               https://lockswap.saumon.cc/users/confirmation?confirmation_token=…
Validity                           "This link works for 24 hours." / "… 6 hours, and only once."
If it wasn't you                   "If you did not ask for this, ignore this email — nothing will change."
                                   (3: "If you did not do this, contact an administrator right away.")
Footer                             "LockSwap — locker swaps" (no unsubscribe: transactional)
```

Email 3 carries the time of the change (`l(Time.current, format: :long)`, in the site language) and
**no** link and no password (FR-039).

All strings live under `devise.mailer.*` (subjects) and `mailer.*` (bodies) in both locale pairs;
`test/i18n_completeness_test.rb` covers them automatically.

## Styling rules

- Inline `style=""` only; table-based layout, max width 560px, readable at 320px.
- Colours via `mail_color(:name)` (`app/helpers/mailer_helper.rb`), never a literal hex in ERB:

| name | value | token it mirrors |
|---|---|---|
| `:ink` | `#0A1F38` | `--color-ink` |
| `:ink_muted` | `#50607A` | `--color-ink-muted` |
| `:link` | `#0A5AC2` | `--color-link` (button fill, white text 6.45:1) |
| `:canvas` | `#F4F7FA` | `--color-canvas` |
| `:surface` | `#FFFFFF` | `--color-surface` |
| `:brand_green` | `#0AB486` | `--color-brand-green` (wordmark only) |
| `:rail_you` | `#0A77F1` | `--color-rail-you` (card hinge) |

- The card carries a 3px leading hinge in `:rail_you` — this email is about the reader's own account — and
  no shadow (CLAUDE.md).
- No uppercase, no eyebrow.

## Previews

`test/mailers/previews/devise_mailer_preview.rb` — one method per email (4), each rendered in the current
site language; visited at `/rails/mailers` in development to review the design by eye.
