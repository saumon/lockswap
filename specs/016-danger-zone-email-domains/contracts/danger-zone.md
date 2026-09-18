# Contract: Danger Zone – Allowed Email Domains

**Feature**: [spec.md](../spec.md) | **Date**: 2026-09-18

## Routes

```
GET    /admin/danger_zone                     →  Admin::DangerZoneController#show
                                                   admin_danger_zone_path

POST   /admin/allowed_email_domains            →  Admin::AllowedEmailDomainsController#create
                                                   admin_allowed_email_domains_path

DELETE /admin/allowed_email_domains/:id        →  Admin::AllowedEmailDomainsController#destroy
                                                   admin_allowed_email_domain_path(domain)
```

All three declared inside the existing `namespace :admin`, alongside `resources :users`. `#show` is a
singular `resource :danger_zone, only: :show`; the create/destroy pair is `resources
:allowed_email_domains, only: [:create, :destroy]`.

## Access contract (all three routes)

| Caller | Outcome |
|---|---|
| Anonymous | Redirect to `new_user_session_path` (`authenticate_user!`), nothing shown or changed |
| Signed in, not an administrator | Redirect to `root_path` with `flash[:alert]` = `ApplicationController::ADMINISTRATORS_ONLY_MESSAGE`, nothing shown or changed (FR-002) |
| Administrator | Proceeds as described below |

Identical rule, message and destination the Users list already uses — the same `before_action`
pair, restated on both new controllers rather than shared through inheritance tricks, matching how
`Admin::UsersController` already declares its own pair rather than a base admin controller.

## Danger Zone screen contract (`GET /admin/danger_zone`)

| State | What is shown |
|---|---|
| No domains configured | The list is empty; a line stating registration is currently open to any email domain (FR-004); the add-domain form is present |
| One or more domains configured | Each domain on its own row, with a "Remove" control per row; the add-domain form is present |

- **Add form**: one text field ("Domain", e.g. placeholder `company.com`), submitting `POST
  /admin/allowed_email_domains`.
- **Remove control**: a `button_to` per row submitting `DELETE
  /admin/allowed_email_domains/:id`, matching the confirm-before-acting precedent used for "Grant
  admin rights" (015) since removing a domain can immediately open or close registration to real
  people — the confirmation names the domain being removed.
- **Validation failure on add**: re-renders this same screen (existing list intact) with the
  Devise-style error partial (`devise/shared/error_messages`) showing the rejected entry's error,
  status `422`, mirroring `LockerProfilesController#update`'s pattern of re-rendering the origin
  screen rather than redirecting through a separate error page.

## Registration contract (changed — `RegistrationsController`, inherited from Devise)

| Configuration | Submitted email domain | Outcome |
|---|---|---|
| No domains configured | any | Registration proceeds exactly as before this feature (FR-004) |
| One or more domains configured | Matches one configured domain exactly (case-insensitive) | Registration proceeds exactly as before this feature (FR-005 acceptance scenario 3) |
| One or more domains configured | Does not match any configured domain | Registration refused; no account created; the existing Devise error partial shows exactly "Your email address domain is not allowed" (FR-005, FR-006) |

No new route: the existing `POST /users` (Devise `registerable`) gains one more way to fail
validation, alongside the email-format and uniqueness checks it already performs.

## Out of scope for this contract

- Editing a configured domain in place (removed and re-added instead, per data-model.md)
- Any notification when a domain is added or removed — this is a synchronous admin action with an
  inline flash, like every other admin write in this application
- Any effect on accounts that already exist, or on sign-in, password reset, or any flow other than
  new-account registration (FR-010)
