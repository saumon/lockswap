# Quickstart: Admin Role and User Directory

Manual validation of the acceptance scenarios in `spec.md`, once the feature is implemented. See
`contracts/admin-users.md` for the exact request/response rules and `data-model.md` for the `admin`
column these steps exercise.

## Prerequisites

```sh
bin/rails db:reset   # fresh database — the very first signup below must be the site's first account
bin/dev               # Puma + the Tailwind watcher
```

## 1 — The first account becomes administrator (User Story 1)

1. Visit `/users/sign_up` and register as `admin@example.com`.
2. **Expect**: after landing on the homepage, the signed-in navigation shows an "Admin" entry that
   was not there for any account before this feature — open it and confirm it reveals a "Users" link
   (FR-001, FR-003, FR-005).
3. Log out. Register a second account, `employee@example.com`.
4. **Expect**: this account's navigation has no "Admin" entry, at either the narrow (phone-width) or
   wide (desktop-width) treatment (FR-004).
5. While signed in as `employee@example.com`, visit `/admin/users` directly by address.
6. **Expect**: refused — redirected away with a flash message, never the Users list (FR-008).

## 2 — The administrator reviews every registered account (User Story 2)

1. Log back in as `admin@example.com`.
2. Open Admin → Users.
3. **Expect**: both `admin@example.com` and `employee@example.com` are listed, oldest first, each
   identified by email; the `admin@example.com` row carries an explicit "Admin" label the other row
   does not (FR-006, FR-007, FR-010, FR-012).
4. Register a third account, `newhire@example.com`, in a separate browser/session.
5. Reload the Admin → Users page as the administrator.
6. **Expect**: `newhire@example.com` now appears in the list too, still ordered oldest first
   (FR-006, FR-010).
7. Confirm there is no edit, delete, promote, or demote control anywhere on the page (FR-009).

## 3 — Edge case: the administrator's own account is later deleted

1. Still signed in as `admin@example.com`, use the existing "Cancel my account" control
   (`/users/edit`) to delete that account.
2. Sign in as `employee@example.com` (or any remaining account).
3. **Expect**: no account now shows an "Admin" entry in its navigation — administrator status was not
   transferred to anyone (FR-011).

## Automated coverage

These scenarios are also asserted by the automated suite added with this feature (see `tasks.md`
once generated): model tests for the bootstrap/race behavior on `User`, controller tests for the
`Admin::UsersController` authorization and listing contract, and system tests for the navigation
entry's visibility and the Users screen — the latter folded into the existing per-screen
accessibility (`test/system/accessibility_test.rb`) and responsive-viewport (`test/system/responsive_test.rb`)
sweeps rather than duplicated in a new one.
