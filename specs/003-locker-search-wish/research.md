# Phase 0 Research: Locker Search Wish

The technology stack is fixed by the existing codebase (Ruby on Rails 8.1.3 monolith, established in
001-user-authentication, extended in 002-locker-floor-profile) — there are no framework/language
choices left open. The open questions are about how to model a per-user "I'm looking for a locker"
declaration that is visible across users, and where to put the declare/view/cancel UI. All
`NEEDS CLARIFICATION` items are resolved below.

## Where the wish lives: a new table, not new `users` columns

- **Decision**: Introduce a new `locker_wishes` table (`user_id`, `floor`), associated
  `belongs_to :user` / `has_one :locker_wish`, rather than adding a nullable `wish_floor` column
  directly to `users` (the approach 002 took for `floor`/`locker_number`).
- **Rationale**: 002's research explicitly rejected a separate table for the locker *profile*
  because that data has "no independent lifecycle, no relationships to other entities, and no need
  to exist before a `User` does." A Locker Wish is different on exactly those points:
  - It has an independent lifecycle distinct from the profile — it is *declared* and *cancelled*
    ("Exists independently of whether the owning user currently has a locker assigned. Removed
    entirely when the user cancels it" — spec Key Entities), not merely edited in place like a
    profile field.
  - It is displayed cross-user, on its own listing (User Story 2) rather than folded into a single
    user's own page — a `WHERE floor IS NOT NULL` scan over `users` would work, but it conflates a
    row genuinely representing another concept ("who is looking, and where") with the `users` table,
    which the spec itself calls out as a separate Key Entity.
  - Keeping it off `users` keeps `User` focused on authentication + the existing profile fields
    (Constitution Principle I, single responsibility) instead of accreting an unrelated column for
    every future per-user feature.
- **Alternatives considered**: A nullable `wish_floor` string column on `users`, mirroring
  `locker_number` (rejected for the reasons above — this is not simply "one more optional field on
  the profile", it is a separate entity with declare/cancel semantics and its own display surface).

## Enforcing "at most one active wish per user"

- **Decision**: `locker_wishes.user_id` carries a DB unique index. The controller looks up
  `current_user.locker_wish` before writing; if found, it updates that row's `floor` in place
  (FR-004); if not, it builds a new one. A `rescue ActiveRecord::RecordNotUnique` backstop handles
  the case where two submissions for the same user race each other past the initial lookup — the
  loser re-fetches the row the winner just created and updates its floor, so the user still ends up
  with exactly one wish holding their latest floor rather than an error.
- **Rationale**: The same reasoning 002 used for `locker_number` uniqueness applies: an
  application-level "does a wish already exist" check is not race-safe on its own (two concurrent
  double-clicks of "I'm looking for a locker" could both pass the check before either commits). The
  unique index is the actual correctness guarantee (FR-003, SC-003); folding the race into an update
  rather than surfacing an error keeps the user-visible behavior identical to the non-race path
  (FR-004 already says a second declare updates the existing wish).
- **Alternatives considered**: Relying on the application-level lookup alone (rejected — not
  race-safe); surfacing the race as a generic error and asking the user to retry (rejected — worse
  UX than silently doing what FR-004 already specifies, and inconsistent with it).

## Floor: format and validation

- **Decision**: `floor` is a plain, required `string` column with only `presence: true` validation
  — no format constraint, no shared list with `users.floor`.
- **Rationale**: FR-008 asks for consistency with how floor is handled elsewhere (free-form,
  non-blank only). Rails' `presence` validation already treats a whitespace-only string as blank
  (`ActiveSupport`'s `String#blank?`), so no extra trimming/normalization step is needed to satisfy
  the "blank or only whitespace" edge case — the same mechanism 002 already relies on for
  `users.floor`.
- **Alternatives considered**: Sharing a single `FLOOR_OPTIONS` list or format validator between
  `User` and `LockerWish` (rejected — nothing in the spec constrains floor values beyond non-blank,
  and no such list exists today for `users.floor` either).

## Identifying wishing users to viewers

- **Decision**: The wish list shows `wish.user.email` as the identifier (per the resolved
  clarification), plus `wish.user.saved_floor` and `wish.user.saved_locker_number` — both already
  public accessors on `User` from 002 — for the "current floor and locker number" columns.
- **Rationale**: Reuses existing data and existing accessors verbatim; no schema change and no new
  concept beyond the wish itself. `saved_floor`/`saved_locker_number` already return `nil` naturally
  when unset, which is exactly the "not set" / "no locker assigned" state the list needs to render
  (Edge Case).
- **Alternatives considered**: Adding a display name field (rejected by the clarification answer —
  email is sufficient and avoids a schema change).

## Where the declare/view/cancel UI lives

- **Decision**: A new `LockerWishesController` with `index` (list all wishes + the viewer's own
  declare/cancel/edit controls), `create` (declare, or update-in-place per FR-004), and `destroy`
  (cancel) — routed as `resources :locker_wishes, only: [:index]` plus
  `resource :locker_wish, only: [:create, :destroy]` (the singular form omits `:id` from the path,
  since a user only ever acts on their own one wish, mirroring 002's `resource :locker_profile,
  only: :update`). A new page rather than folding this into the homepage, since User Story 2 is
  inherently a *cross-user* view, unlike the homepage's single-user profile display.
- **Rationale**: Keeps the homepage (001/002) unchanged and keeps this feature's own concern —
  declaring/browsing/cancelling wishes — in one controller with a single, clear responsibility
  (Constitution Principle I), consistent with 002's reasoning for keeping `LockerProfilesController`
  separate from Devise's controllers.
- **"I'm looking for a locker" as a reveal, not an always-open form**: the button is a `<details>`
  `<summary>` that reveals the floor field only once clicked (FR-005, FR-006), the same
  no-JavaScript disclosure pattern 002 used for "Edit locker details" — keyboard- and
  screen-reader-operable natively, and keeps this codebase's Stimulus-controller count at zero. A
  rejected submission (blank floor) re-renders the index page with the disclosure forced open via
  `errors.any?`, exactly as 002 does, so the reported error always has a form visible to correct it
  in. Once a user has an active wish, the same disclosure is relabeled "Change floor" and a separate
  "Cancel wish" button (`button_to ... method: :delete`) is shown alongside it.
- **Alternatives considered**: Adding the button/form to the existing homepage (rejected — the wish
  list itself needs a page of its own regardless, since it shows every user, and putting the
  declare/cancel controls there next to what they act on is the least-navigation-to-understand
  layout); a full RESTful `locker_wishes` resource with `new`/`edit`/`show` (rejected — same
  reasoning as 002: the entry point is a single button/disclosure, not a separate page per action).

## Ordering the wish list

- **Decision**: Order by `created_at ASC` (declaration order — first-declared, first-listed).
- **Rationale**: The spec places no requirement on ordering (Assumptions: "no pagination or floor
  filtering required"); declaration order is the simplest deterministic choice and needs no
  additional index or user input to produce.
- **Alternatives considered**: Alphabetical by email, or grouped by floor (rejected — no
  requirement calls for either, and declaration order is simpler to reason about and test).

## Testing strategy

- **Decision**: `test/models/locker_wish_test.rb` for the presence validation, the `belongs_to`
  association, and the unique-index race backstop (mirroring
  `test/controllers/locker_profiles_controller_test.rb`'s hand-rolled `save` stub, since no mocking
  gem is bundled); `test/system/locker_wish_test.rb` (Capybara, headless Chrome — same tooling as
  001/002) covering User Story 1–3's acceptance scenarios end-to-end through the real page.
- **Rationale**: Matches the constitution's Testing Standards principle and the project's existing,
  already-configured test stack — no new test dependency.
- **Alternatives considered**: RSpec (rejected — not used anywhere in this codebase).

**Output**: All Technical Context items resolved; no `NEEDS CLARIFICATION` markers remain.
