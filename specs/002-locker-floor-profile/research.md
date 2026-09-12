# Phase 0 Research: Locker and Floor Profile

The technology stack is fixed by the existing codebase (Ruby on Rails 8.1.3 monolith, established in
feature 001-user-authentication) — there are no framework/language choices left open. The open
questions for this feature are about how to model and validate two new, optional-and-independent
attributes on the existing `User` record without breaking the existing authentication feature. All
`NEEDS CLARIFICATION` items are resolved below.

## Where the data lives

- **Decision**: Add `floor` and `locker_number` as two new nullable columns directly on the existing
  `users` table, rather than introducing a separate `locker_profiles` table.
- **Rationale**: The spec's own Key Entity ("User Locker Profile") is explicitly a 1:1 extension of
  the user account with no independent lifecycle, no relationships to other entities, and no need to
  exist before a `User` does. A second table would add a join with no behavioral benefit — pure
  premature abstraction for a two-column extension.
- **Alternatives considered**: A separate `locker_profiles` table with a `belongs_to :user`
  (rejected — adds a migration, a model, and a join for data that is always read and written
  together with the user record and never independently).

## Floor: presence rule without breaking unrelated `User` updates

- **Decision**: Validate `floor` presence with `validates :floor, presence: true, on: :locker_profile_update`,
  and only run that validation context from the new locker-profile save action — never as a
  blanket, context-less validation on `User`.
- **Rationale**: `User` already has other legitimate update paths that must keep working before a
  floor is ever set — most importantly Devise's own account-update flow (email/password changes).
  A brand-new user has `floor: nil` until they complete User Story 2; if `presence: true` were
  applied unconditionally, `current_user.update(...)` calls made by *any* other feature (present or
  future) would start failing validation for that user until they filled in a floor, which is an
  unrelated and surprising coupling. Scoping the validation to a dedicated `on:` context confines
  the "floor is required" rule to exactly the one save path the spec (FR-007) is talking about.
- **Alternatives considered**: Unconditional `validates :floor, presence: true` on `User` (rejected
  for the reason above); enforcing presence only in the controller with no model validation
  (rejected — would leave the model layer able to silently persist an invalid blank floor from any
  other future code path, contradicting FR-007's "MUST reject").

## Floor: format

- **Decision**: Store `floor` as a plain `string` column with no format constraint beyond
  non-blank, per the confirmed clarification (free-form value, no predefined floor list).
- **Rationale**: Directly matches the spec's clarified answer; avoids introducing and maintaining a
  building-specific floor list that nothing in the spec calls for.
- **Alternatives considered**: `integer` column (rejected — floors are sometimes non-numeric, e.g.
  "RDC"/"Ground", and the spec explicitly confirmed free-form input); a `floors` lookup table
  (rejected by the clarification answer).

## Locker number: optional and unique across users

- **Decision**: Store `locker_number` as a nullable `string` column. Normalize any blank
  (empty/whitespace) submitted value to `nil` before validation/save (a `before_validation`
  callback), so "no locker" is always represented as SQL `NULL`, never `""`. Validate uniqueness
  with `validates :locker_number, uniqueness: true, allow_nil: true, on: :locker_profile_update`,
  backed by a DB-level `unique` index on `locker_number`.
- **Rationale**:
  - Normalizing blank to `NULL` matters because both SQLite's unique index and Rails' own
    `uniqueness` validator treat multiple `NULL`s as distinct from each other but treat repeated
    `""` as a real, colliding duplicate value — without normalization, the second user who leaves
    the field blank would incorrectly be told the empty string is "already taken."
  - `allow_nil: true` is required, not optional: Rails' uniqueness validator does *not* skip `nil`
    values by default — it checks `WHERE locker_number IS NULL` and would treat every other
    "no locker assigned" user as a conflicting duplicate, incorrectly blocking everyone but the
    first user who has no locker. `allow_nil: true` makes "no locker" (`nil`) exempt from the
    uniqueness check entirely, matching the confirmed clarification that "no locker" is fully
    expected and not a conflict.
  - The application-level `uniqueness` validation gives a good, immediate error message on the
    common path, but is not race-safe by itself (two simultaneous requests can both pass the
    SELECT-based check before either INSERT/UPDATE commits). The DB unique index is the actual
    correctness guarantee under concurrency (FR-011, SC-005); the controller catches the resulting
    `ActiveRecord::RecordNotUnique` as a backstop and surfaces the same user-facing message.
  - Rails' default uniqueness error message ("has already been taken") satisfies the clarified
    requirement to reject the conflicting save without disclosing which other account holds the
    locker — it names only the value, never the other user.
- **Alternatives considered**: `allow_blank: true` alone without normalizing to `nil` first
  (rejected — leaves `""` stored inconsistently depending on code path, and `allow_blank` still
  requires the blank-normalization to avoid storing distinguishable `""` vs `nil` rows); enforcing
  uniqueness only at the DB layer with no model validation (rejected — would surface a raw,
  non-actionable `ActiveRecord::RecordNotUnique` exception as the primary UX instead of a form
  error, failing FR-011's "MUST be rejected ... told that locker number is not available").

## Where the save action lives

- **Decision**: A new, single-purpose `LockerProfilesController` with only an `update` action,
  mounted as a singular resource (`resource :locker_profile, only: :update`), rather than adding
  locker/floor fields to Devise's own registration/account-update controller.
- **Rationale**: Keeps Devise's controllers focused purely on authentication (Constitution
  Principle I — single, clear responsibility) and keeps this feature's validation context
  (`:locker_profile_update`) isolated to a save path this feature owns outright, so it can be
  extended (e.g. User Story 3 edits) without touching authentication code at all.
- **Alternatives considered**: Extending `RegistrationsController` (rejected — mixes authentication
  concerns with locker/floor profile concerns in one controller); a full RESTful
  `locker_profiles` resource with `new`/`edit`/`show` (rejected — the spec calls for the entry point
  to be the homepage itself, not a separate page; `update` is the only action ever invoked, whether
  filling in the value for the first time or changing it later per User Story 3).

## Where it's displayed and entered

- **Decision**: `HomeController#index` (already the authenticated landing page from
  001-user-authentication) branches on whether a floor is already saved:
  - **Nothing saved yet** — the form is rendered openly, with no control to click first, so the
    prompt is unmissable (FR-005, User Story 2).
  - **Already saved** — the display partial is rendered (User Story 1), followed by the same form
    partial, pre-filled, inside a `<details>` whose `<summary>` is the "Edit locker details"
    control. The form appears only once that control is activated (User Story 3).

  No new route is needed to *view* this information, only the existing `PATCH /locker_profile` to
  save it.
- **Rationale**: Matches the spec's explicit requirement that "the homepage" is what offers the
  entry form (FR-005) and displays the saved values (FR-003/FR-004). Keeping the form behind an
  edit control for someone who has already answered means the homepage reports a settled state
  instead of permanently presenting an open form — the stakeholder asked for this directly. One
  partial still backs both cases, so the first fill-in and a later edit remain the same
  `PATCH /locker_profile` action with the same markup and validation.
- **Why `<details>` rather than a Stimulus controller**: the disclosure needs no application state,
  and `<details>` is keyboard- and screen-reader-operable out of the box, survives Turbo page
  replacement without re-initialisation, and keeps this codebase's count of hand-written JavaScript
  controllers at zero. A Stimulus controller would add a file and a lifecycle to maintain for
  behaviour the browser already implements.
- **A rejected edit must reopen the disclosure**: the failure path re-renders the homepage, so the
  `<details>` is marked `open` whenever `current_user.errors.any?`. Without that, a user whose edit
  was rejected would be shown an error with no visible form to correct it in.
- **Alternatives considered**: A dedicated `/locker_profile` show/edit page (rejected — spec is
  explicit that this happens on the homepage); an always-visible pre-filled form for every user
  (rejected by the stakeholder after review — it left an open form permanently on the homepage of
  users who had already answered).

## Testing strategy

- **Decision**: Extend `test/models/user_test.rb` with unit coverage for the new validations/
  normalization (presence-only-in-context, uniqueness with `nil` exemption, blank-to-nil
  normalization), and add `test/system/locker_profile_test.rb` (Minitest + Rails system tests,
  matching the existing 001 suite's tooling exactly) covering the User Story 1–3 acceptance
  scenarios end-to-end through the real homepage and form.
- **Rationale**: Matches the constitution's Testing Standards principle and the project's existing,
  already-configured test stack (Minitest, fixtures, Capybara headless Chrome) — no new test
  dependency is introduced.
- **Alternatives considered**: RSpec (rejected — not used anywhere in this codebase).

**Output**: All Technical Context items resolved; no `NEEDS CLARIFICATION` markers remain.
