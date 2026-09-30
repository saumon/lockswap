# Quickstart: validating feature 034

**Feature**: 034-email-confirmation-password-reset

How to prove the feature works end to end. Behaviour details live in
[contracts/routes-and-screens.md](contracts/routes-and-screens.md),
[contracts/emails.md](contracts/emails.md) and
[contracts/mail-configuration.md](contracts/mail-configuration.md); the data in
[data-model.md](data-model.md).

## Prerequisites

```bash
bundle install                    # letter_opener_web (development group)
bin/rails db:migrate              # Devise columns + confirmed_by; backfills existing accounts
bin/rails tailwindcss:build
bin/dev                           # web + css
```

With no `SMTP_*` set, development mail goes to **http://localhost:3000/letter_opener**.

To try a real server locally instead:

```bash
SMTP_ADDRESS=smtp.example.org SMTP_PORT=587 SMTP_USERNAME=… SMTP_PASSWORD=… \
SMTP_SENDER="LockSwap <no-reply@example.org>" bin/dev
```

## Automated checks

```bash
bin/rails test                     # models, controllers, mailers, i18n completeness
bin/rails test:system              # browser flows + axe audits
bin/rubocop && bin/brakeman --no-pager && bin/bundler-audit
```

Expected: all green; `test/i18n_completeness_test.rb` passes with the new `mailer.*`, `users.*`,
`admin.user_activations.*` and `devise.*` keys present in both languages.

## Manual scenarios

| # | Do | Expect | Spec |
|---|---|---|---|
| 1 | Existing DB: sign in as an account that existed before migrating | Signs in as before; admin detail shows "Activated on <migration time>" | FR-010, SC-007 |
| 2 | Sign up with a new address | Sign-in screen, "check your inbox" notice; **not** signed in; one mail in letter_opener | US1-1, FR-003 |
| 3 | Sign in with that account's right password | Refused: "activate your account first…"; no new mail appears | US2-1, FR-009 |
| 4 | Same, wrong password | Generic invalid-credentials message | US2-2, FR-006 |
| 5 | Open the mail; check HTML and text parts | Button + plain link, "24 hours", "if it wasn't you"; in the site language | FR-025/26, FR-024 |
| 6 | Follow the link | Sign-in screen, "account activated"; now signs in | US1-2/3 |
| 7 | Follow the same link again | "Already active — sign in" | edge case |
| 8 | Sign up again (B); request a new activation email at once | Generic notice; **no** second mail (5-min window) | FR-023 |
| 9 | Wait 5 min (or set `confirmation_sent_at` back in the console), request again; follow the **first** link | First link refused as unrecognised; second link activates | FR-012 |
| 10 | Request activation / reset for `nobody@example.com` | Same generic notices as for a real address; no mail | FR-013, FR-016, SC-006 |
| 11 | Sign-in screen → "Forgot your password?" → real address | Generic notice; reset mail with "6 hours, only once" | US3-1/2 |
| 12 | Follow it; enter mismatched passwords | Signup's mismatch message; link still works | US3-5 |
| 13 | Enter a valid pair | Signed in; old password refused afterwards; a "password changed" mail arrives with no link | US3-4, FR-039 |
| 14 | Follow the reset link again | "Link already used" + "request a new one" | US3-6 |
| 15 | Lock an account (5 wrong passwords), then complete a reset | Signed in immediately | FR-040 |
| 16 | Unactivated account B: complete a reset | Signed in; admin detail shows "Activated on …" (no admin named) | FR-019 |
| 17 | Account page: change email | "Awaiting confirmation for …" shown; old address still signs in; mail sent to the **new** address with the "confirm your new address" wording | US6 |
| 18 | Follow it | Only the new address signs in | US6-2 |
| 19 | As admin: Admin → Users | Unactivated rows show "Not activated" badge; others unchanged | FR-034 |
| 20 | Open an unactivated account; "Activate account", confirm | Notice; detail shows "Activated by <you> on …"; the control is gone; the account signs in; no mail sent | FR-035/36/38 |
| 21 | As a standard user, `POST /admin/users/:id/activation` (e.g. from the console with a session, or a controller test) | Refused with "administrators only" | FR-037 |
| 22 | Switch site language to English in the Danger Zone; repeat 2 | Mail in English | FR-024 |
| 23 | Development: stop the SMTP server (or set a wrong `SMTP_PORT`) and sign up | Signup still succeeds instantly; the failed job is visible in the log / `SolidQueue::FailedExecution` in production | FR-028, FR-031 |

## Looking at it (CLAUDE.md)

- `/rails/mailers` — the four email previews; check at 320px and 600px, both languages.
- A throwaway system test that screenshots the four new auth screens and the admin detail (desktop and
  `with_viewport(:phone)`) to `tmp/design/`; read the images, then delete the test.
