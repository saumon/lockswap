# Research: Locker Map (Zones per Floor)

**Feature**: 031-locker-map-zones

## R1: `LockerWish` has no locker number — the spec named a screen that does not exist

The spec's first draft assumed the locker wish form (`locker_wishes/_locker_wish_form.html.erb`) collects a
locker number, the same way the locker profile forms do. It does not: `locker_wishes` (`db/schema.rb`) has
only `floor` and `user_id`; `LockerWish` (`app/models/locker_wish.rb`) validates only `:floor`. A wish is "I
want a locker on this floor," never a specific locker number.

**Decision**: The spec was corrected before this plan (FR-009/FR-010, User Story 2) to name only the two
save paths that actually write a floor + locker number pair together: `LockerProfilesController#update`
(self-service) and `Admin::UserLockerProfilesController#update` (admin editing on a user's behalf). Both
already share one validation context, `User#save(context: :locker_profile_update)`.

**Alternatives considered**: Extending `LockerWish` to carry a locker number was not considered — it is out
of scope and would change what a "wish" means, which the feature description never asked for.

## R2: Reuse `shared/_floor_field` for a zone's (creation-only) floor picker — as one standalone form, not one per floor section

030's `shared/_floor_field` partial renders a `<select>` of `SiteFloorList.current.floors` once configured,
or a text field otherwise, and merges in `form.object.saved_floor` if it is no longer offered. `Zone`'s
floor is fixed at creation (031 clarification) and never re-rendered in an editable form afterward, so the
"no longer offered but already saved" branch is unreachable for a zone in practice — but giving `Zone` the
same `saved_floor` method (`floor_in_database`, mirroring `User`/`LockerWish`) lets the *new-zone* form
reuse the partial exactly as-is (`form.object.saved_floor` is simply `nil` for an unsaved record).

**Correction (found by `/speckit-analyze`, finding C1)**: the first draft of this plan put one new-zone form
inside each *existing* per-floor section, with the floor fixed by which section it sat under (a
`hidden_field`, not `shared/_floor_field` at all). That is a bootstrapping deadlock: `@floors` is only ever
the site's configured list, or — while unconfigured — the floors that already have a zone. On a fresh
install (`SiteFloorList` unconfigured, no zone yet — the documented baseline), there is no section to put a
form in, so a regular admin (FR-001 deliberately never requires the super admin who alone can configure
`SiteFloorList`) can never create the first zone at all.

**Decision**: the "add a zone" form is **one standalone form on the screen, not nested in any floor
section**, and it is the one place `shared/_floor_field` is actually rendered — free text while
`SiteFloorList` is unconfigured, a select once it is, exactly like every other floor field on the site. It
creates a zone on whatever floor is typed or chosen, whether or not that floor already has a section.
Existing zones are still grouped into read-only per-floor sections underneath it, purely for display
(`Admin::LockerMapController#show`/`LoadsLockerMap`, unchanged).

**Alternatives considered**: A bespoke `<select>` for zones only — rejected, would duplicate
`shared/_floor_field`'s branching for no behavioral difference. One form per floor section (the original,
flawed draft) — rejected per the correction above.

## R3: The "known locker" check needs both attributes, so "skip when unchanged" ORs them

`SiteFloorValidator` and `LockerNumberFormatValidator` each guard one attribute and skip when *that*
attribute (`will_save_change_to_attribute?`) is not changing — the grandfather rule from 030. The new check
is over the **pair** (floor, locker number): a user who changes only their floor, keeping the same
locker-number text, is asking for a different pair than what was saved, and that pair must be checked too
(spec User Story 2, scenario 4).

**Decision**: `KnownLockerValidator` (an `EachValidator` on `:locker_number`, reading `record.floor`) skips
only when **neither** `:locker_number` **nor** `:floor` is changing — the OR, not the single-attribute
check 030's validators use. (It also skips entirely while the map is empty site-wide — R8, discovered
during implementation.)

## R8: The known-locker check must be permissive while the map is empty, site-wide — found during implementation

**Correction (found by running the existing suite during `/speckit-implement`, before this was asked as a
clarifying question)**: FR-010 as first specified rejected *every* floor + locker save the instant
`KnownLockerValidator` shipped, because the map starts empty and FR-013's grandfather clause only covers
data already saved *before* release (via `update_columns`-style writes), not ordinary saves through the
normal form path. Running the suite surfaced 13 failures in the non-system tests alone (`user_test.rb`,
`locker_profiles_controller_test.rb`, `admin/user_locker_profiles_controller_test.rb`) before system tests
were even run — every one of them a pre-existing test saving a floor + locker pair that had never been
"declared" anywhere, which is exactly what the whole test suite (and a fresh production site) does by
default. In production this would mean no user could save a locker at all until an admin fully
pre-populated the map first.

This is the opposite of how the codebase's two existing sibling registries behave:
`SiteFloorList`/`LockerNumberFormat` (030) are both permissive while unconfigured — absence of
configuration is never read as "nothing is allowed" — and every pre-existing test relies on that baseline
(030 research.md R10: "not configured" stays the default every existing test runs under).

**Decision** (031 clarification, session 2026-09-26): `KnownLockerValidator` adds one more early return,
`return unless LockerMapEntry.exists?` — while the map has never had a single entry declared anywhere on
the site, the check is a no-op, exactly matching `SiteFloorList`/`LockerNumberFormat`'s own posture. The
moment an admin declares the first locker in any zone, on any floor, the check activates everywhere at
once (FR-013a). No pre-existing test needed to change.

**Alternatives considered**: Requiring the map to be pre-populated before release (rewriting the ~13+
broken tests, and every system test that saves a floor/locker, to first create matching `LockerMapEntry`
rows) was the literal shape of the original FR-010/FR-013 and is exactly what this correction replaces —
the blast radius made it clearly the wrong default, not merely inconvenient for tests.

## R4: Cascading zone deletion is `dependent: :destroy`, not a manual guard

031 clarification: deleting a non-empty zone removes it and its locker numbers in one action, with no
"empty it first" requirement.

**Decision**: `Zone has_many :locker_map_entries, dependent: :destroy`. `Admin::ZonesController#destroy`
calls `zone.destroy` with no pre-check; Rails cascades. Already-saved `User` rows pointing at one of the
deleted pairs are untouched (FR-013) — nothing here touches `users`.

**Alternatives considered**: `dependent: :restrict_with_error` (block deletion while children exist) was the
literal shape of the *other* option in the clarification question and is exactly what was declined.

## R5: Zone name uniqueness is scoped to floor, matched exactly (case-sensitive)

031 clarification fixed *that* zone names must be unique per floor; it did not fix case sensitivity, which
has no user-facing stakes raised in the spec. The codebase's existing exact-match convention for
identifying strings (`SiteFloorList#offers?`, `LockerWish.looking_for`) is case-sensitive, plain `=`
comparison — no collation trick like the `NOCASE` one `users.email` uses for lookup convenience.

**Decision**: `validates :name, uniqueness: { scope: :floor }` — SQLite's default (case-sensitive) string
comparison, consistent with every other exact-match rule in the app. Not a user-facing ambiguity worth a
clarification question; a plain default.

## R6: `locker_map_entries.floor` is denormalized from `zones.floor`, for a real DB-level compound index

`Zone` already carries `floor`; `LockerMapEntry belongs_to :zone` could look it up through the association.
But FR-007's uniqueness ("declared in at most one zone at a time, site-wide") is exactly the same shape as
`users`' existing `(floor, locker_number)` unique index (006) — and that index is what actually closes the
race two concurrent admin submissions could otherwise both pass validation and then both insert (the same
reasoning `User#save`'s callers already rescue `ActiveRecord::RecordNotUnique` for).

**Decision**: `locker_map_entries.floor` is a real column, set once from `zone.floor` in a
`before_validation` and never reassigned afterward (R4/031 clarification: a zone's floor cannot change, so
this can never drift). A DB unique index on `(floor, locker_number)` is the actual guarantee; the model
`uniqueness` validator (scoped to `:floor`) gives the friendly, zone-naming message from FR-008, and the two
write controllers rescue `ActiveRecord::RecordNotUnique` for the race, mirroring
`LockerProfilesController#save_locker_profile` exactly.

## R7: Screen access is `require_admin!`, not `require_super_admin!`

The feature description says "administrateurs," and 031's spec resolved this as an assumption already
(regular admin, not the narrower super-admin-only Danger Zone role). Confirmed against the codebase:
`Admin::UsersController` (an ordinary admin destination) uses `before_action :require_admin!`;
`Admin::DangerZoneController`/`Admin::AllowedEmailDomainsController`/`Admin::FloorListController`/
`Admin::LockerNumberFormatController` use the stricter `require_super_admin!`. The Locker Map screen is
ordinary content administration (declaring what exists), not a site-wide danger-zone setting, so it follows
the `Admin::UsersController` precedent.

**Decision**: `Admin::LockerMapController`, `Admin::ZonesController`, `Admin::LockerMapEntriesController`
all use `before_action :require_admin!`. The nav link is placed in `shared/_site_menu_items.html.erb`
alongside "Users" (`current_user.admin?`), not inside the `current_user.super_admin?` block that gates
"Danger Zone."
