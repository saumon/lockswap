# Contract: Danger Zone – Site Language Setting

**Feature**: [spec.md](../spec.md) | **Date**: 2026-09-21

## Routes

```
GET   /admin/danger_zone   →  Admin::DangerZoneController#show    (existing, from 016 — unchanged path/verb)
                               admin_danger_zone_path

PATCH /admin/danger_zone   →  Admin::DangerZoneController#update  (NEW)
                               admin_danger_zone_path
```

`resource :danger_zone, only: [:show, :update], controller: "danger_zone"` — 016's existing `only:
:show` gains `:update`, in the same `namespace :admin` alongside `resources :users` and `resources
:allowed_email_domains`.

## Access contract (`#update`, in addition to the existing `#show` contract from 016)

| Caller | Outcome |
|---|---|
| Anonymous | Redirect to `new_user_session_path` (`authenticate_user!`), setting unchanged |
| Signed in, not an administrator | Redirect to `root_path` with `flash[:alert]` = `ApplicationController::ADMINISTRATORS_ONLY_MESSAGE`, setting unchanged (FR-002) |
| Administrator | Proceeds as described below |

Same `before_action :authenticate_user!` / `before_action :require_admin!` pair already declared on
this controller for `#show` — nothing new to add, since both actions share the one controller.

## Danger Zone screen contract (`GET /admin/danger_zone`, extended)

The screen gains one section above the existing allowed-domains section:

| Element | Behavior |
|---|---|
| Language `select` | Two options, "French" and "English", pre-selected to `SiteLanguageSetting.current.language` (FR-011) |
| Submit button | Labeled to save just this section (e.g. "Save language"), `PATCH admin_danger_zone_path` |

- **Unchanged field**: submitting with the already-selected value re-saves the same value — a no-op
  in effect, satisfying the Edge Case "administrator saves without changing the language field".
- **Success**: redirect to `GET /admin/danger_zone` with a flash notice naming the newly active
  language, itself shown in whichever language is now current (e.g. "Language updated to French." /
  "Langue mise à jour : Anglais." depending on the *new* value, not the old one).
- **Invalid value** (only reachable by a tampered request outside the closed `select`, since the UI
  itself offers no third option): re-renders `#show` with the existing form-error partial
  (`devise/shared/error_messages`, the same component 016 already reuses), status `422`, current
  language unchanged.

## Site-wide contract (every request, every route in the application — not just Danger Zone)

| State | Behavior |
|---|---|
| `SiteLanguageSetting.current.language == "en"` | Every `t()`/`t(".…")` call across every view, every Devise-rendered screen, and every notification e-mail resolves to its English text; `<html lang="en">` |
| `SiteLanguageSetting.current.language == "fr"` | Same, resolved to French; `<html lang="fr">` |
| A saved change from one to the other | Takes effect for every subsequent request from every user — administrator or not, signed in or not — starting with the very next request each of them makes (FR-008); no cookie, session value, or per-user record is consulted |

This is enforced by `ApplicationController`'s `around_action` (research.md R2), which every
controller in the application inherits — this contract is not specific to the Danger Zone screen
itself, only configured from it.

## Out of scope for this contract

- Any per-user or per-browser override of the site language (spec Assumptions) — the `select` on the
  Danger Zone screen is the only place the value can be read or changed.
- Any change to date, time, or number formatting when the language changes (Clarifications,
  2026-09-21) — those continue to render in one fixed format regardless of `SiteLanguageSetting.current`.
- Translation of user-entered or user-generated content (FR-009) — `t()` is never called on a
  record's own attribute values (a name, a comment, an e-mail address, a locker/floor identifier).
