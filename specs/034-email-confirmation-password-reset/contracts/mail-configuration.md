# Contract: Mail Configuration (operator-facing)

**Feature**: 034-email-confirmation-password-reset

## `Lockswap::MailerSettings` (`config/mailer_settings.rb`)

Required from `config/application.rb` before `Application` is defined, so the environment files and the
Devise initializer can call it. Ported from hitguessr's `Hitguessr::MailerSettings`, minus the
confirmation feature toggle (research R1).

```text
smtp_settings            → Hash (compact; only the keys that resolved)
smtp_configured?         → address, port, user_name, password all present
default_url_options(default_host:, default_port: nil, default_protocol: nil) → Hash
mailer_sender(default:)  → String
```

Each value resolves **ENV → encrypted credentials → default**; an empty ENV value counts as unset.

| ENV | credentials | Used for | Default |
|---|---|---|---|
| `SMTP_ADDRESS` | `smtp.address` | SMTP host | — |
| `SMTP_PORT` | `smtp.port` | SMTP port (integer) | — |
| `SMTP_DOMAIN` | `smtp.domain` | HELO domain | — |
| `SMTP_USERNAME` | `smtp.user_name` | auth user | — |
| `SMTP_PASSWORD` | `smtp.password` | auth password | — |
| `SMTP_AUTHENTICATION` | `smtp.authentication` | `plain` / `login` / `cram_md5` | `plain` |
| `SMTP_ENABLE_STARTTLS_AUTO` | `smtp.enable_starttls_auto` | STARTTLS | `true` |
| `SMTP_OPENSSL_VERIFY_MODE` | `smtp.openssl_verify_mode` | `peer` / `none` | — |
| `SMTP_SENDER`, then `MAILER_SENDER` | `smtp.sender`, then `mailer.sender` | From address | per env, below |
| `APP_HOST` | `app.host` | host in email links | per env |
| `APP_PORT` | `app.port` | port in email links | per env |
| `APP_PROTOCOL` | `app.protocol` | scheme in email links | per env |

## Per environment

| | production | development | test |
|---|---|---|---|
| link host / protocol | `lockswap.saumon.cc` / `https` | `localhost:3000` / `http` | `example.com` (unchanged) |
| sender default | `LockSwap <no-reply@lockswap.saumon.cc>` | `LockSwap <no-reply@localhost>` | same as dev |
| delivery when SMTP configured | `:smtp` | `:smtp` | `:test` (always) |
| delivery when not configured | Rails default (`:smtp` to localhost) — fails and is recorded | `:letter_opener_web`, inbox at `/letter_opener` | `:test` |
| `raise_delivery_errors` | `true` | `true` only when SMTP configured | Rails default |
| queue | Solid Queue in Puma (unchanged) | `:async` (unchanged) | test adapter via `ActiveJob::TestHelper` |

Production with SMTP unconfigured logs one warning at boot:
`[account_mail] SMTP is not configured; account emails will fail to deliver`.

## Kamal (`config/deploy.yml`, `.kamal/secrets`)

```yaml
env:
  secret:
    - RAILS_MASTER_KEY
    - SMTP_USERNAME
    - SMTP_PASSWORD
  clear:
    SOLID_QUEUE_IN_PUMA: true
    APP_HOST: lockswap.saumon.cc
    SMTP_ADDRESS: <mail host>
    SMTP_PORT: 587
    SMTP_SENDER: "LockSwap <no-reply@lockswap.saumon.cc>"
```

`.kamal/secrets` gains `SMTP_USERNAME=$SMTP_USERNAME` and `SMTP_PASSWORD=$SMTP_PASSWORD` (read from the
deployer's environment or password manager, never committed). Alternatively put the same keys under
`smtp:` in `bin/rails credentials:edit` and leave the ENV unset — ENV wins when both exist.

## Failure visibility (FR-031)

A refused delivery raises inside `ActionMailer::MailDeliveryJob`. Solid Queue records it as a failed
execution (`solid_queue_failed_executions`, with the error) and the job logs it. The user-facing screen
already answered (FR-028), and the user can request the email again once delivery works. No automatic
retry is added: a retry would re-send a link the user may already have re-requested.

## README

The Deploy section gains a "Mail" subsection listing the ENV table above and the letter_opener_web URL
for development.
