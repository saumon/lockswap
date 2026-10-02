# Email

Since feature 034, LockSwap sends email. It is not optional: **a new account cannot sign in until it
has been activated from an emailed link**, so a production instance that cannot send mail is an
instance nobody new can join. This section explains what is sent and why, then how to point the
application at your SMTP server, step by step.

### What is sent, and when

| Email | Sent when | To | Contains |
| --- | --- | --- | --- |
| **Activate your account** | someone signs up; or asks again from *Didn't receive the activation email?* on the sign-in page | the address they signed up with | a link that activates the account — valid **24 hours** |
| **Confirm your new address** | a signed-in user changes their email on the account page | the **new** address | a link that makes the change take effect — valid **24 hours**; until then the old address stays in force |
| **Reset your password** | someone uses *Forgot your password?* on the sign-in page | the account's address | a link to choose a new password — valid **6 hours**, **once** |
| **Your password was changed** | any password change, by reset link or from the account page | the account's address | the time of the change, and "contact an administrator if this wasn't you" — **no link** |

Every email is sent in both an HTML and a plain-text version, in the site's language (the Danger
Zone setting, [025](../specs/025-multilingual-support/spec.md)) at the moment it is sent, and gives its
link twice: as a button and as a plain address that can be copied.

A few rules sit around them, so the emails cannot be used against the people receiving them:

* **the resend and reset screens always give the same answer**, whether or not the address has an
  account, so they cannot be used to find out who is registered;
* **one email of each kind per address every 5 minutes** — asking again sooner shows the same answer
  and sends nothing;
* **only the newest link works**: asking for a new activation or reset email invalidates the previous
  ones;
* **a failed sign-in never sends anything** by itself.

### How it works

```text
 request (signup, reset…)            background job                    your SMTP server
 ───────────────────────────        ──────────────────────────         ─────────────────
 answers the person at once   ──►   Solid Queue, inside Puma     ──►   delivers the email
 (never waits on the mail           renders the email in the
  server, never fails because        site's language, then
  of it)                             hands it over by SMTP
```

* Emails are built by Devise's own mailer (`UserMailer`, a thin subclass of `Devise::Mailer`) and
  delivered with `deliver_later`, so they go through **Solid Queue**, which already runs inside Puma in
  production (`SOLID_QUEUE_IN_PUMA: true` in `config/deploy.yml`). There is no separate worker to run.
* If the SMTP server refuses a message or cannot be reached, the job fails, the error is written to
  the log, and Solid Queue keeps it as a **failed execution** (see [Troubleshooting](#troubleshooting-email)).
  Nobody is stuck: the person can ask for the email again, and an administrator can activate an
  account by hand from **Admin → Users → the account → Activate account**.
* Every email is logged as one line carrying the account's **id** — never its address, never a
  token — for example `[account_mail] event=activation_sent user_id=42`.

### Configuring the SMTP server

All mail settings are read by [`config/mailer_settings.rb`](../config/mailer_settings.rb), in this
order — the first one that has a value wins:

1. an **environment variable** (an empty value counts as unset);
2. the application's **encrypted credentials** (`bin/rails credentials:edit`);
3. a built-in **default**.

| Environment variable | Credentials key | What it is | Default |
| --- | --- | --- | --- |
| `SMTP_ENABLED` | `smtp.enabled` | set to `false` to turn SMTP off even when everything below is configured (in development, mail then goes to the `/letter_opener` inbox) | `true` |
| `SMTP_ADDRESS` | `smtp.address` | SMTP server host name — **required** | — |
| `SMTP_PORT` | `smtp.port` | SMTP port — **required**, normally `587` | — |
| `SMTP_USERNAME` | `smtp.user_name` | login — **required** | — |
| `SMTP_PASSWORD` | `smtp.password` | password or app password — **required** | — |
| `SMTP_AUTHENTICATION` | `smtp.authentication` | `plain`, `login` or `cram_md5` | `plain` |
| `SMTP_ENABLE_STARTTLS_AUTO` | `smtp.enable_starttls_auto` | upgrade the connection with STARTTLS when the server offers it | `true` |
| `SMTP_DOMAIN` | `smtp.domain` | the domain announced to the server (HELO) | none (the SMTP library's own) |
| `SMTP_OPENSSL_VERIFY_MODE` | `smtp.openssl_verify_mode` | `peer` (verify the certificate) or `none` | the certificate is verified |
| `SMTP_SENDER`, else `MAILER_SENDER` | `smtp.sender`, else `mailer.sender` | the From address, e.g. `LockSwap <no-reply@your-company.com>` | `LockSwap <no-reply@lockswap.saumon.cc>` |
| `APP_HOST` | `app.host` | the host name people reach LockSwap by — **every link in every email is built on it** | `lockswap.saumon.cc` |
| `APP_PROTOCOL` | `app.protocol` | `https` or `http` | `https` |
| `APP_PORT` | `app.port` | only if LockSwap is reached on a non-standard port | none |

**SMTP is switched on only when all four required settings are present** — address, port,
username and password — **and `SMTP_ENABLED` is not `false`**. With any of them missing, the whole
SMTP configuration is ignored: production logs `[account_mail] SMTP is not configured; account emails
will fail to deliver` at boot (or `SMTP is disabled (SMTP_ENABLED=false)`), and every email fails.
Check for that line after any change (see [Checking it works](#checking-it-works)).

`SMTP_ENABLED` is read like every other setting, so the environment can override the credentials in
either direction: `SMTP_ENABLED=false` in one machine's `.env` switches off a server configured in the
credentials, and `SMTP_ENABLED=true` switches back on one the credentials disabled with
`enabled: false`.

If the credentials cannot be decrypted (a `master.key` that does not match the file), the mail
settings print `[account_mail] the credentials could not be decrypted (wrong master key?)` and read
the environment only. The application itself still refuses to start with a wrong key — Rails needs
`secret_key_base` from those credentials — but `bin/rails credentials:edit` gets far enough to tell
you so.

> **Ports.** Use the server's **submission port, `587`, with STARTTLS** (the default behaviour).
> Implicit TLS on port `465` is **not supported** by the current settings: there is no
> `SMTP_TLS`/`SMTP_SSL` option, and STARTTLS is always requested. If your provider offers only 465,
> ask for 587 — virtually all of them support both. Port `25` works for an internal relay that takes
> a login; set `SMTP_ENABLE_STARTTLS_AUTO=false` if that relay rejects STARTTLS.

> **The sender address.** Use an address on a domain your SMTP account is allowed to send for;
> most providers reject or rewrite anything else. For mail that lands in the inbox rather than in
> spam, that domain should publish SPF and DKIM records for the provider — ask whoever manages your
> company's DNS.

#### Option A — Kamal environment variables (recommended)

The non-secret values go in [`config/deploy.yml`](../config/deploy.yml), the secret ones are read from
your machine through [`.kamal/secrets`](../.kamal/secrets) and never committed. Both files already carry
the lines, commented out.

1. In `config/deploy.yml`, uncomment and fill in:

   ```yaml
   env:
     secret:
       - RAILS_MASTER_KEY
       - SMTP_USERNAME
       - SMTP_PASSWORD
     clear:
       SOLID_QUEUE_IN_PUMA: true
       SMTP_ADDRESS: smtp.your-provider.com
       SMTP_PORT: 587
       SMTP_SENDER: "LockSwap <no-reply@your-company.com>"
       APP_HOST: lockswap.your-company.com
       # SMTP_AUTHENTICATION: login     # only if your provider needs it
   ```

2. In `.kamal/secrets`, uncomment:

   ```sh
   SMTP_USERNAME=$SMTP_USERNAME
   SMTP_PASSWORD=$SMTP_PASSWORD
   ```

   These read the values from the environment of the machine you deploy from. Either export them in
   your shell before deploying, or have them fetched from your password manager — see the examples at
   the top of `.kamal/secrets`:

   ```sh
   export SMTP_USERNAME='lockswap@your-company.com'
   export SMTP_PASSWORD='the-password-or-app-password'
   ```

3. Deploy: `kamal deploy`. Environment variables and secrets only reach the container when it is
   (re)created, so any later change to them needs another `kamal deploy` too.

#### Option B — encrypted credentials

Nothing to export and nothing in `deploy.yml`: the values travel inside the image, encrypted with the
master key the container already receives (`RAILS_MASTER_KEY`).

```sh
bin/rails credentials:edit
```

```yaml
smtp:
  address: smtp.your-provider.com
  port: 587
  user_name: lockswap@your-company.com
  password: the-password-or-app-password
  sender: "LockSwap <no-reply@your-company.com>"
  # authentication: login
app:
  host: lockswap.your-company.com
```

Save, commit `config/credentials.yml.enc` (never `config/master.key`), and deploy. If both options are
used, **the environment variable wins** for each setting it defines.

#### Option C — plain Docker

The same variables work with any container runner:

```sh
docker run -d -p 3000:80 -v lockswap_storage:/rails/storage \
  -e RAILS_MASTER_KEY=$(cat config/master.key) \
  -e SMTP_ADDRESS=smtp.your-provider.com -e SMTP_PORT=587 \
  -e SMTP_USERNAME=lockswap@your-company.com -e SMTP_PASSWORD='…' \
  -e SMTP_SENDER='LockSwap <no-reply@your-company.com>' \
  -e APP_HOST=lockswap.your-company.com \
  lockswap
```

#### Examples by provider

These are starting points — check your provider's own documentation for the current values.

| Provider | `SMTP_ADDRESS` | `SMTP_PORT` | `SMTP_AUTHENTICATION` | Notes |
| --- | --- | --- | --- | --- |
| Microsoft 365 / Exchange Online | `smtp.office365.com` | `587` | `login` | SMTP AUTH must be enabled for the mailbox by your Microsoft 365 administrator; the sender must be that mailbox or one it may send as. |
| Google Workspace / Gmail | `smtp.gmail.com` | `587` | `plain` | Use an **app password** (requires 2-step verification), not the account password. |
| Transactional services (Brevo, Mailgun, SendGrid, Postmark…) | the service's SMTP host | `587` | `plain` | Use the SMTP credentials the service generates, and verify your sending domain with it first. |
| Internal company relay | your relay's host | `587` or `25` | as your relay expects | Works when the relay takes a login. A relay that accepts mail **without** authentication is **not supported** today: SMTP only switches on with a username and password, and those are then always offered to the server, which an unauthenticated relay refuses. |

#### Checking it works

1. **Look for the warning at boot.** No line means SMTP is configured:

   ```sh
   kamal app logs --since 10m --grep account_mail
   ```

2. **Send yourself a test email** from the running container — it uses exactly the settings the
   application uses, and touches no account:

   ```sh
   kamal app exec --reuse "bin/rails runner 'ActionMailer::Base.mail(from: Devise.mailer_sender, to: \"you@your-company.com\", subject: \"LockSwap SMTP test\", body: \"It works.\").deliver_now'"
   ```

   It either arrives, or the command prints the error the SMTP server answered with.

3. **Try the real thing**: sign up with a test address, check the activation email arrives and that
   its link opens **your** site (if it points elsewhere, `APP_HOST` is wrong), then delete the test
   account from its account page.

#### Troubleshooting email

* **Emails that failed** are kept by Solid Queue. List the latest ones with their errors:

  ```sh
  kamal app exec --reuse "bin/rails runner 'SolidQueue::FailedExecution.last(5).each { |f| puts f.created_at, f.exception_class, f.message, \"\" }'"
  ```

* **`Net::SMTPAuthenticationError`** — wrong username or password, an account password where an app
  password is required, or SMTP AUTH disabled for that mailbox.
* **`Net::OpenTimeout` / `Errno::ECONNREFUSED`** — wrong host or port, or the server's outbound port is
  blocked by a firewall or the hosting provider (many block port 25; use 587).
* **`OpenSSL::SSL::SSLError` / certificate errors** — the server presents a certificate that does not
  match its name or is self-signed. Prefer fixing the certificate or using the host name it was issued
  for; `SMTP_OPENSSL_VERIFY_MODE=none` turns the check off and should be a last resort on an internal
  network only.
* **`Net::SMTPFatalError` mentioning the sender** — the provider refuses the From address: set
  `SMTP_SENDER` to an address that account is allowed to send as.
* **The email arrives but its link is wrong** — set `APP_HOST` (and `APP_PROTOCOL`/`APP_PORT` if
  needed) to the address people actually use.
* **Someone never received their activation email** — they can use *Didn't receive the activation
  email?* on the sign-in page, or an administrator can activate the account by hand from its page in
  **Admin → Users**. The account's line in the log (`user_id=…`) shows whether an email was sent.

### Email in development

You do not need an SMTP server to work on LockSwap:

* with no `SMTP_*` set — or with `SMTP_ENABLED=false`, whatever else is configured — every email is
  caught by [letter_opener_web](https://github.com/fgrehm/letter_opener_web) and shown in a web inbox
  at **[`/letter_opener`](http://localhost:3000/letter_opener)** — open it, click the email, follow
  the link. Nothing leaves the machine;
* the four emails can be previewed, without sending anything, at
  **[`/rails/mailers`](http://localhost:3000/rails/mailers)** (in the site's current language — switch
  it from the Danger Zone to see the other);
* to try a real server, set the same `SMTP_*` variables when starting the app (see below);
* if you reach the development app by another address than `localhost:3000` (a remote dev box, for
  instance), set `APP_HOST`, `APP_PORT` and `APP_PROTOCOL` so the links in the emails point back to it.

Emails are sent in the background in development too (Active Job's in-process adapter), so they
appear in the inbox a moment after the page answers.

#### Setting the variables in development

These variables are read **once, when the server starts** (`config/environments/development.rb`), so
set them before starting it and restart it after any change.

The simplest way is a **`.env` file at the root of the project**. `bin/dev` starts the app through
[foreman](https://github.com/ddollar/foreman), which loads `.env` automatically; the file is already
ignored by git (`/.env*` in `.gitignore`), so nothing in it can be committed by accident.

Reached through an HTTPS reverse proxy — for example `https://lockswap-dev.saumon.cc`:

```sh
# .env — read by bin/dev (foreman), never committed
APP_HOST=lockswap-dev.saumon.cc
APP_PROTOCOL=https
```

Leave `APP_PORT` out in that case: without it, links use the protocol's standard port (443 for
`https`). Reached directly on Rails' own port, without a proxy:

```sh
APP_HOST=devbox.saumon.cc
APP_PORT=3000
APP_PROTOCOL=http
```

The `SMTP_*` variables can go in the same file to try a real mail server — or, when a real server
is configured in the development credentials, a single line keeps this machine on the inbox instead:

```sh
SMTP_ENABLED=false   # send nothing; every email goes to /letter_opener
```

The full set, for a real server:

```sh
SMTP_ADDRESS=smtp.your-provider.com
SMTP_PORT=587
SMTP_USERNAME=you@your-company.com
SMTP_PASSWORD=the-password-or-app-password
```

Then start the app with `bin/dev` as usual. Two other ways work too:

* **for one run only**, on the command line: `APP_HOST=lockswap-dev.saumon.cc APP_PROTOCOL=https bin/dev`;
* **for every run**, exported from your shell (for instance in `~/.bashrc`):
  `export APP_HOST=lockswap-dev.saumon.cc`.

Things to know:

* **`bin/rails server` started on its own does not read `.env`** — foreman does, not Rails. Use one of
  the two other ways with it;
* **the host name must be one Rails accepts**: `lockswap-dev.saumon.cc` and `devbox.saumon.cc` are
  already in `config.hosts` in `config/environments/development.rb`; any other name has to be added
  there, or Rails blocks the request;
* **to check**, sign up with a test address, open the email in `/letter_opener` and look at the
  activation link: it must start with the address you use in your browser.

### Changing the emails

| To change… | Edit |
| --- | --- |
| the wording (both languages) | `mailer.*` in [`config/locales/en.yml`](../config/locales/en.yml) and [`fr.yml`](../config/locales/fr.yml) |
| the subject lines | `devise.mailer.*.subject` in [`config/locales/devise.en.yml`](../config/locales/devise.en.yml) / [`devise.fr.yml`](../config/locales/devise.fr.yml); the email-change subject is `mailer.reconfirmation_instructions.subject` |
| the layout | [`app/views/layouts/mailer.html.erb`](../app/views/layouts/mailer.html.erb) and `mailer.text.erb` |
| each email's body | [`app/views/devise/mailer/`](../app/views/devise/mailer/) (`.html.erb` and `.text.erb` for each) |
| the colours | [`app/helpers/mailer_helper.rb`](../app/helpers/mailer_helper.rb) — copies of the stylesheet's design tokens, by name; templates must not contain a raw hex value (a test enforces it) |
| how long links last | `confirm_within` (24 h) and `reset_password_within` (6 h) in [`config/initializers/devise.rb`](../config/initializers/devise.rb) — and the sentences stating it in the locale files |

Every string must exist in both locale files; `bin/rails test` fails otherwise.

