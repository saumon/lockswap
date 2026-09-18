# Quickstart: Grant Administrator Rights

Manual validation of the acceptance scenarios in `spec.md`, once the feature is implemented. See
`contracts/grant-admin.md` for the exact request/response rules and `data-model.md` for the columns
these steps exercise.

## Prerequisites

```sh
bin/rails db:reset   # fresh database — the first signup below must be the site's first account
bin/dev              # Puma + the Tailwind watcher
```

Register three accounts in this order, logging out between each: `first@example.com` (becomes the
bootstrap administrator), `bob@example.com`, `carol@example.com`.

## 1 — An administrator promotes a standard account (User Story 1)

1. Sign in as `first@example.com` and open Admin → Users.
2. **Expect**: `bob` and `carol` each carry a "Grant admin rights" button; the administrator's own row
   carries none (FR-001, FR-002).
3. Activate the button on `bob`'s row.
4. **Expect**: a confirmation naming `bob@example.com` and stating the grant cannot be undone. Nothing
   has changed yet (FR-003, FR-004).
5. Decline it.
6. **Expect**: `bob` is still a standard account; the list is exactly as it was (FR-005).
7. Activate the button again and validate the confirmation.
8. **Expect**: no password is asked for (FR-020); the list reloads with a success notification, `bob`'s
   row carries the same `Admin` badge as the administrator's own (FR-006, FR-008, FR-010), and no
   grant button remains on that row (FR-002).
9. **Expect**: `bob`'s row reads `Granted by first@example.com on <today>`, and `first`'s row reads
   `First registration` (FR-018).
10. **Expect**: `first@example.com` is still an administrator — the navigation still shows "Admin"
    (FR-013).

## 2 — The promoted account has real administrator capability (User Story 2)

1. Log out; sign in as `bob@example.com`.
2. **Expect**: the navigation now shows "Admin" (FR-007).
3. Open Admin → Users.
4. **Expect**: the full list opens, exactly as it does for `first` (FR-007).
5. Grant rights to `carol` and validate the confirmation.
6. **Expect**: `carol` becomes an administrator, her row reading `Granted by bob@example.com on
   <today>` — a granted administrator can promote others (FR-007, FR-013).

## 3 — Guardrails (User Story 3)

1. Log out; register a fourth account, `dave@example.com`.
2. Visit `/admin/users` directly by address.
3. **Expect**: refused, redirected away with the administrators-only message (013 FR-008).
4. From a terminal, aim the grant route itself at an account while signed in as `dave`:

   ```sh
   # Expect a redirect away, and dave still a standard account afterwards.
   # The browser session is what matters here — the controller test covers this
   # case exactly; this step is the by-hand confirmation of it.
   ```

   **Expect**: refused; no account's rights change (FR-009).

## 4 — The last administrator cannot walk out (FR-016)

1. Sign in as `carol` (administrator) and cancel her account from the account page.
   **Expect**: succeeds — `first` and `bob` are still administrators.
2. Sign in as `bob` and cancel his account. **Expect**: succeeds — `first` remains.
3. Sign in as `first` and try to cancel. **Expect**: refused, with a message saying to grant
   administrator rights to another account first. The account is intact (FR-016).
4. Grant rights to `dave`, then cancel `first` again. **Expect**: succeeds — `dave` is administrator.
5. Open Admin → Users as `dave`.
   **Expect**: `dave`'s row reads `Granted on <today> (account removed)` — the grant outlived the
   account that made it (FR-019).

## Automated suites

```sh
bin/rails test                 # models + controllers
bin/rails test:system          # Capybara / headless Chrome, including the axe sweep
bin/rubocop && bin/brakeman    # Quality Gates (Constitution)
```

The system suite covers the confirmation, the button's absence on administrator rows, the provenance
line and the accessible name; the controller suite covers the refusals and the already-an-administrator
case, which a browser cannot reach.
