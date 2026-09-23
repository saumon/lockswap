# Quickstart: Super Admin Role and Exclusive Danger Zone Access

**Feature**: [spec.md](./spec.md) | **Branch**: `029-super-admin-role`

Manual validation once the implementation lands (tasks.md covers the automated tests; this is the
end-to-end proof the pieces fit together, per `CLAUDE.md`'s "look at the page" guidance).

## Prerequisites

```bash
bin/rails tailwindcss:build   # only needed if a stylesheet rule changed — this feature shouldn't touch one
bin/rails db:test:prepare     # if migrations exist elsewhere on the branch; this feature adds none itself
```

Fixture users (`test/fixtures/users.yml`) already include an admin account; check which fixture (if any)
is the bootstrap admin (`admin_granted_at: nil`) versus a granted one before scripting a system test —
`CLAUDE.md` calls out that freshly created users make capture scripts flaky, so prefer fixtures.

## Scenario 1 — First registration becomes the super admin (User Story 1)

```bash
bin/rails runner '
  User.destroy_all
  u = User.create!(email: "first@example.com", password: "password123")
  raise "not admin" unless u.admin?
  raise "not super admin" unless u.super_admin?
  second = User.create!(email: "second@example.com", password: "password123")
  raise "unexpectedly admin" if second.admin?
  raise "unexpectedly super admin" if second.super_admin?
  puts "OK: first registrant is super admin, second is not"
'
```

Expected: prints `OK: ...`, no exceptions.

## Scenario 2 — Retroactive promotion on an already-running site (FR-013)

```bash
bin/rails runner '
  bootstrap = User.find_by(admin: true, admin_granted_at: nil)
  raise "no existing bootstrap admin to check" unless bootstrap
  raise "not promoted" unless bootstrap.super_admin?
  puts "OK: existing bootstrap admin is already the super admin, no migration needed"
'
```

Expected: prints `OK: ...` against today's development database with no data migration run — this is
the point of research.md R1 (the predicate is derived, so nothing needed to change on existing rows).

## Scenario 3 — Danger zone hidden and refused for a standard admin (User Story 2)

1. `bin/rails server`
2. Sign in as a standard (granted, non-bootstrap) admin fixture.
3. Open the Admin menu → confirm "Zone de danger" is absent, "Users" is present.
4. Visit `/admin/danger_zone` directly → confirm redirect to the homepage with the
   "administrators only" alert.
5. `curl` or a Capybara `page.driver.submit` a `PATCH /admin/danger_zone` or
   `POST /admin/allowed_email_domains` directly as that admin's session → confirm redirect/refusal, no
   record created and no language change persisted.

## Scenario 4 — Super admin keeps full danger zone control (User Story 3)

1. Sign in as the super admin fixture.
2. Admin menu → "Zone de danger" present and opens the screen.
3. Change the site language → confirm the success flash, in the new language.
4. Add then remove an allowed email domain → confirm both succeed as they did before this feature.

## Scenario 5 — No control can grant, transfer, or revoke the super admin role (User Story 4)

1. As the super admin, open a standard admin's detail screen (`/admin/users/:id`) → confirm no control
   offers to make them a super admin (there never was one — this is confirming none was added).
2. As a *different* standard admin (grant a second account standard admin rights first), open the super
   admin's own detail screen → confirm no "Revoke admin rights" button is rendered for that row.
3. Attempt `PATCH /admin/users/:id/revoke_admin` directly against the super admin's `id`, authenticated
   as that other standard admin → confirm redirect back to the super admin's detail screen with the
   "cannot be revoked" alert, and `User.find(id).super_admin?` is still `true` afterward.

## Scenario 6 — The super admin cannot cancel their own account while others exist (FR-010/FR-014)

1. Sign in as the super admin. Confirm at least one other account exists (any role).
2. Trigger account cancellation (Devise's destroy path) — even while another admin exists.
3. Confirm the request is refused with the new "can never be cancelled" message and the account still
   exists afterward — this holds regardless of how many other admins are on the site.
4. Sign in as a standard, granted admin instead (not the super admin) and cancel their own account while
   other accounts (including the super admin) remain — confirm this now succeeds unconditionally
   (FR-014: no "last administrator" refusal applies to anyone but the super admin anymore).
5. As a final check, delete every other account on the site, then sign in as the super admin (now the
   sole remaining account) and cancel — confirm this succeeds, the site has zero accounts, and the next
   registration becomes the new super admin (Scenario 1).

## Cleanup

```bash
git checkout -- .   # discard runner-script side effects if run against a shared dev database
```
