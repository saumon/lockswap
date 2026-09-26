# Research: Locker Zone Visibility Across Screens

No open `NEEDS CLARIFICATION` markers reached this phase — the one ambiguity the spec surfaced (whether
swap history shows a live or historically-snapshotted zone) was resolved in `/speckit-clarify` before
planning began (spec.md's Clarifications section, confirming the spec's own already-stated assumption).
The decisions below are technical-approach research, not open spec questions.

## R1: One shared, batched lookup rather than a query per screen

**Decision**: Add exactly two public methods to the existing `LockerMapEntry` model (031):

- `LockerMapEntry.zone_names_for(pairs)` — given an array of `[floor, locker_number]` pairs, returns a
  `Hash` keyed by the same normalized `[floor, locker_number]` pairs, valued by the zone's `name`, omitting
  any pair that is not currently declared. One query (`joins(:zone).where(floor: ..., locker_number: ...)`),
  regardless of how many pairs are asked for.
- `LockerMapEntry.zone_name_for(floor, locker_number)` — the single-pair convenience wrapper, built on top
  of `.zone_names_for([[floor, locker_number]])`, for the screens that only ever need one answer.

**Rationale**: Every touched screen asks the same question — "is this floor + locker number pair declared,
and if so under what zone name?" — the same shape `LockerMapEntry.known?` already answers for validation
(031). Centralizing it means a rename, a locker's removal from its zone, or the Locker Map being emptied
site-wide (FR-005/FR-007) is correct everywhere the instant it is true in the database, with no second place
that could drift. Batching by pairs (rather than one query per row) keeps every list/table screen at the
same "one additional query, not one per row" cost `Admin::UsersController#index`'s existing
`includes(:admin_granted_by, :locker_wish)` already holds itself to (Principle IV).

**Alternatives considered**:
- *A `belongs_to :zone` association added directly on `User`/`LockerWish`/`LockerSwapProposal`.* Rejected:
  031 deliberately keeps `Zone`/`LockerMapEntry` as the sole source of truth, addressed only by
  `(floor, locker_number)` — a stored foreign key on `User` would need to be kept in sync on every Locker
  Map edit (rename, delete, reassignment) instead of simply being asked fresh each time, reintroducing
  exactly the staleness risk FR-007 rules out.
- *A per-row query wherever a floor/locker is displayed.* Rejected outright on Principle IV grounds for any
  list/table screen; even for single-record screens, a shared method is simpler to test once than to
  re-verify at each of four call sites.

## R2: Where the lookup gets called — view-local for single records, controller-batched for lists

**Decision**: The account holder's own locker card, a swap proposal received, and the exchange-in-progress
card call `LockerMapEntry.zone_name_for` directly in the view/partial, at the same place the floor/locker
value itself is already read. The admin account detail page's own locker display does the same in its
controller (`@locker_zone_name`), since it is a single record. The three list/table screens — the admin
account directory, the locker search list, and the swap-history table — batch every visible row's pair
through `.zone_names_for` once in the controller action and hand the resulting `Hash` down as an ivar.

**Rationale**: `home/_locker_profile.html.erb`'s own existing comment already documents why it reads
`current_user` directly rather than through an ivar set by only one of its two renderers
(`HomeController` and `LockerProfilesController`, on a rejected edit) — a single, cheap, already-indexed
lookup fits that same constraint with no new plumbing. List/table screens have no such multi-renderer
concern, so batching once in the controller (the same place `Admin::UsersController#index` already loads
`@users` with its `includes`) is both simpler and Principle-IV-correct.

**Alternatives considered**: Batching everywhere, even single-record screens, for uniformity. Rejected as
needless ceremony — a single-record `.zone_name_for` call is already one bounded, indexed query; forcing it
through a Hash built for exactly one entry adds a data structure with no performance or correctness benefit.

## R3: Swap history needs a side-aware accessor, not a change to `floor_and_locker_summary`

**Decision**: Add `LockerSwapProposal#locker_sides`, returning the same two `[floor, locker_number]` pairs
(requester, then recipient) that `floor_and_locker_summary`'s private `sides` computation already derives —
preserving its existing pending/accepted-vs-settled branching exactly. `floor_and_locker_summary` itself is
**not** modified. The history table view collects every row's pairs via `#locker_sides`, resolves them all
in one `.zone_names_for` call in the controller, and renders each side's zone as its own small element next
to (never inside) the existing summary text.

**Rationale**: `floor_and_locker_summary` returns one already-tested, already-translated joined sentence per
proposal ("Proposed: Floor 2, Locker 203 for Floor 3, Locker 110"). Folding a zone name into that string
would either require re-templating already-covered I18n copy or produce a zone name indistinguishable from
the locker number it sits next to — directly against FR-008. Keeping the summary untouched and adding the
zone as a sibling element is also the only way to satisfy FR-008 in a single, existing text cell.

**Alternatives considered**: Reconstructing the same pairs from scratch in the history-table view. Rejected
— it would duplicate `floor_and_locker_summary`'s private branching (pending/accepted read live user
attributes; settled proposals read the frozen `_at_resolution` columns) a second time, the exact kind of
duplicated logic Constitution I (Code Quality) singles out for refactoring rather than repetition.

## R4: Presentation reuses existing neutral styling; no new colour, no new component

**Decision**: The zone label is rendered as a small, clearly separate text element using an already-defined
neutral style (in the same family as `.meta`), never the swap-axis blue/green, and always paired with its
own visible word (e.g., a "Zone" label), consistent with CLAUDE.md's "colour is never the only signal" rule
and its stated meaning for `--color-rail-system` (neither side — shells, reference, read-only) — which is
exactly what a zone is here: neither party's, just a fact about the locker.

**Rationale**: A zone belongs to neither side of the swap axis (031 already treats zone cards this way on
the Locker Map screen itself, hanging them on the default navy hinge rather than `--you`/`--them`). Reusing
an existing neutral treatment, rather than introducing a new colour or component, satisfies both CLAUDE.md's
"one definition per component" rule and Constitution III's reuse-existing-patterns requirement.

**Alternatives considered**: A new dedicated "zone chip" component with its own colour. Rejected as an
unjustified new pattern for a small, low-frequency piece of read-only text — CLAUDE.md explicitly warns
against inventing a second treatment where the site already has vocabulary that fits.

## R5: No schema change

**Decision**: No migration. This feature reads the existing `zones` / `locker_map_entries` tables (031) and
writes nothing new.

**Rationale**: Confirmed by the 2026-09-26 clarification — swap history shows whichever zone currently
claims a floor + locker pair, live, with no historical snapshot, so no new column or table is needed on
`LockerSwapProposal` (or anywhere else) to remember what zone applied in the past.
