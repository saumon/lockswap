# Quickstart: Site Language Setting (French/English)

Manual validation of the acceptance scenarios in `spec.md`, once the feature is implemented. See
`contracts/danger-zone-language.md` for the exact request/response rules and `data-model.md` for the
setting these steps exercise.

## Prerequisites

```sh
bin/rails db:reset   # fresh database
bin/dev              # Puma + the Tailwind watcher
```

Register one account first, `admin@example.com` — it becomes the site's bootstrap administrator (013
FR-001).

## 1 — A fresh installation starts in English (User Story 2)

1. Before signing in, visit the sign-in screen.
2. **Expect**: every label ("Log in", "Email", "Password", etc.) is in English (SC-002).
3. Sign in as `admin@example.com` and open Admin → Danger Zone.
4. **Expect**: the language section shows "English" as the current setting, with no configuration
   action having been taken yet (FR-005).

## 2 — An administrator sets the site's language (User Story 1)

1. On the Danger Zone screen's language section, select "French" and save.
2. **Expect**: a confirmation appears, itself in French; the language section still shows "French" as
   current on this same page.
3. Browse to a handful of different screens while still signed in as the administrator — the
   homepage, Admin → Users, a locker wish screen.
4. **Expect**: every label, button, and heading on each of those screens is in French, including
   screens the administrator did not directly navigate from Danger Zone (FR-006).
5. In a second, separate signed-out browser session (or an incognito window), visit the sign-in
   screen.
6. **Expect**: it is in French too, with no sign-in required to see the change (User Story 3
   acceptance scenario 2; the setting is site-wide, not tied to the administrator's own session).
7. On the Danger Zone screen, switch the setting back to "English" and save.
8. **Expect**: every screen reverts to English, confirming the switch is reversible in both
   directions (Acceptance Scenario 3).

## 3 — Only administrators can change the language (User Story 3)

1. Register a standard account, `person@example.com`, and sign in as it.
2. **Expect**: no "Admin" entry appears in the navigation at all, and no language control is offered
   anywhere else in the product.
3. Visit `/admin/danger_zone` directly by address.
4. **Expect**: refused, redirected away with the administrators-only message; the configured language
   is unchanged.
5. While signed in as `person@example.com` with a browser or OS locale set to French, view any
   screen.
6. **Expect**: the screen still follows the site-wide setting (whatever an administrator last saved),
   not the browser's own locale (Acceptance Scenario 2).

## 4 — Edge cases worth confirming by hand

1. **Mid-session change**: open two browser tabs signed in as the same standard user. In one, an
   administrator (a third session) changes the language while the user is mid-page in the other tab.
   Navigate to any link in that open tab. **Expect**: the new language appears on that next
   navigation, with no sign-out required.
2. **Dates and numbers stay fixed**: with the language set to French, view a screen showing a
   timestamp (e.g. Admin → Users' "last active" column, or a swap proposal's date). **Expect**: the
   date format is unchanged from what it shows in English — only the surrounding labels changed
   (Clarifications, 2026-09-21).
3. **User content unaffected**: with the language set to French, view a locker wish or swap comment
   containing a person's name or free-text comment. **Expect**: that text is shown exactly as
   entered, unchanged (FR-009, SC-004).
4. **No-op save**: on the Danger Zone screen, save the language section without changing the
   selection. **Expect**: no error, and the setting remains what it already was.

## Automated suites

```sh
bin/rails test                 # models + controllers, including SiteLanguageSetting
bin/rails test:system          # Capybara / headless Chrome, including the axe sweep and a French pass
bin/rubocop && bin/brakeman    # Quality Gates (Constitution)
```

`config.i18n.raise_on_missing_translations = true` in the test environment means `bin/rails test` and
`bin/rails test:system` already fail on any view still calling `t()` for a key missing from either
`config/locales/en.yml` or `config/locales/fr.yml` — a full pass of the suite is itself evidence that
SC-003 (no mixed-language screens) holds, not just a smoke check.
