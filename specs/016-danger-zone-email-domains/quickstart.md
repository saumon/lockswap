# Quickstart: Danger Zone – Allowed Email Domains

Manual validation of the acceptance scenarios in `spec.md`, once the feature is implemented. See
`contracts/danger-zone.md` for the exact request/response rules and `data-model.md` for the table
these steps exercise.

## Prerequisites

```sh
bin/rails db:reset   # fresh database
bin/dev              # Puma + the Tailwind watcher
```

Register one account first, `admin@example.com` — it becomes the site's bootstrap administrator (013
FR-001).

## 1 — An administrator restricts sign-up to specific email domains (User Story 1)

1. Sign in as `admin@example.com` and open Admin → Danger Zone.
2. **Expect**: the domain list is empty, and a line states registration is currently open to any
   email domain.
3. Add `allowed.example`.
4. **Expect**: the list now shows `allowed.example` with a remove control; no page reload is needed to
   see it.
5. Log out. Attempt to register `person@other.example`.
6. **Expect**: registration is refused; no account is created; the page shows exactly "Your email
   address domain is not allowed" (FR-006, SC-002).
7. Attempt to register `person@allowed.example`.
8. **Expect**: registration succeeds exactly as it would have before this feature existed (FR-005
   acceptance scenario 3, SC-003).

## 2 — An administrator lifts the restriction (User Story 2)

1. Sign in as `admin@example.com`, open Admin → Danger Zone, and remove `allowed.example`.
2. **Expect**: a confirmation naming the domain being removed appears before it is actually removed;
   after confirming, the list is empty again and the "open to any domain" line reappears.
3. Log out. Attempt to register `anyone@whatever.example`.
4. **Expect**: registration succeeds — no restriction remains (FR-004, SC-003).

## 3 — Only administrators can reach the Danger Zone (User Story 3)

1. Register a standard account, `person@example.com`, and sign in as it.
2. **Expect**: no "Admin" entry appears in the navigation at all.
3. Visit `/admin/danger_zone` directly by address.
4. **Expect**: refused, redirected away with the administrators-only message (FR-002, SC-004).
5. From a terminal, aim the create/destroy routes at the resource directly while signed in as
   `person@example.com`:

   ```sh
   # Expect a redirect away in both cases, and no change to the configured domains.
   # The browser session is what matters here — the controller test covers this
   # case exactly; this step is the by-hand confirmation of it.
   ```

## 4 — Edge cases worth confirming by hand

1. **Casing**: with `Allowed.Example` entered as the configuration, register
   `person@allowed.example`. **Expect**: accepted (FR-007 — case-insensitive).
2. **No automatic subdomains**: with `company.com` configured, attempt to register
   `person@mail.company.com`. **Expect**: refused — only `company.com` itself is accepted unless
   `mail.company.com` is added as its own entry (Clarifications, 2026-09-18).
3. **Malformed entry**: try adding `not a domain` on the Danger Zone screen. **Expect**: rejected with
   a validation error; the existing list is unchanged.
4. **Duplicate entry**: try adding a domain that is already in the list, in a different case (e.g.
   `COMPANY.com` when `company.com` is already present). **Expect**: rejected as a duplicate.
5. **Existing accounts unaffected**: with an existing account on a domain that is *not* in a newly
   saved allow-list, confirm that account can still sign in normally (FR-010).

## Automated suites

```sh
bin/rails test                 # models + controllers
bin/rails test:system          # Capybara / headless Chrome, including the axe sweep
bin/rubocop && bin/brakeman    # Quality Gates (Constitution)
```

The system suite covers the full Danger Zone screen (add, remove, confirmation, empty state) and the
end-to-end refused/accepted registration cases; the controller and model suites cover the admin-only
guard, the validation edge cases above, and the exact error text — faster to run and easier to isolate
than driving every case through a browser.
