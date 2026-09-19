# Research: "It's a match!" tag on locker wishes

## R1: Compare `saved_floor`, not `floor`

**Decision**: Both sides of the reciprocity comparison read `saved_floor` — `User#saved_floor` for
current floors, `LockerWish#saved_floor` for desired floors — never the plain `floor` attribute.

**Rationale**: `#index` re-renders through `load_wish_list` on a rejected `#create` too. In that path,
`@locker_wish.floor` (and, since `@locker_wish` is the same object as `current_user.locker_wish`,
`current_user.locker_wish.floor`) holds the invalid input the viewer is being asked to correct, not
what is actually on file. Both `User` and `LockerWish` already define `saved_floor` for exactly this
reason ("the value on file... while a rejected change is being re-displayed the attribute holds the
input being corrected" — `LockerWish#saved_floor`'s own comment). Reusing it means the match tag can
never flicker on or off a row based on an input that was never saved.

**Alternatives considered**: Reading `floor`/`user.floor` directly — rejected because it is wrong on
exactly the one request (a rejected declare) where correctness matters most: the viewer would see a
tag react to their own typing before they had saved anything.

## R2: Compute the viewer's own floors once, in the controller

**Decision**: `LockerWishesController#load_wish_list` gains one more once-per-request read, following
the existing shape of `@viewer_in_progress` and `@pending_recipient_ids`: the viewer's own current
floor (`current_user.saved_floor`) and their own wish's desired floor
(`current_user.locker_wish&.saved_floor`), exposed as `@viewer_current_floor` and `@viewer_wish_floor`.
The per-row comparison is a method on `LockerWish` taking both values as arguments.

**Rationale**: `current_user` is already loaded once by Devise; `current_user.locker_wish` is a
`has_one` already read by `own_locker_wish` earlier in the same action, so this adds no query beyond
what already happens. Passing the two floors into the model method (rather than the method reading
`current_user` itself) keeps `LockerWish` from needing any notion of "the viewer" — it only ever
compares floor values it already has or is given, matching how `owner_on_floor` and `looking_for`
already take a plain floor value rather than a user.

**Alternatives considered**: A helper method in `LockerWishesHelper` doing the comparison — rejected
because the comparison is a property of a `LockerWish` relative to two floors, not a presentation
concern; keeping it on the model makes it reachable from the model test suite without a view context.

## R3: No new CSS — reuse `.badge.badge-success`

**Decision**: The tag renders as `<span class="badge badge-success">It's a match!</span>`, the same
component already used elsewhere in the app for a positive status.

**Rationale**: Constitution III requires reusing an established pattern over inventing one; the badge
component already exists, is already verified for contrast (`.badge-success` pairs are ">= 4.5:1",
per the CSS's own comment), and already coexists with plain text in the same cell (the "Swap" column
already mixes a `badge-info` "Proposal pending" with plain `<span class="meta">` text). No new class,
no new CSS file edit.

**Alternatives considered**: A new dedicated "match" visual treatment (e.g., a highlighted row or a
new badge color) — rejected as unjustified new surface area for a binary status the badge vocabulary
already expresses, and the Clarifications session already settled the tag into the existing status
family rather than a new one.

## R4: Two fixture gaps to close — reciprocity, and a second reciprocating row

**Decision**: Add two fixture users whose current floor and wish floor each reciprocate with `bob`
(floor `3`, wish `7`) — `henry` (floor `7`, wish `3`) and `iris` (floor `7`, wish `3`) — so a genuine
match exists in test data, and so a test can confirm more than one row is tagged at once for the same
viewer (spec FR-007, Acceptance Scenario 8).

**Rationale**: Surveying the current fixtures (`bob`: floor 3 → wish 7; `carol`: floor 2 → wish 5;
`erin`: floor 5, no wish; `judy`: wish 10, no floor; `karl`: no floor → wish 3; `dave`: floor + locker,
no wish; `alice`: neither) confirms no two currently reciprocate. Every acceptance scenario needs at
least one row that does, and Acceptance Scenario 8 specifically needs two, so declaring both gaps here
— rather than discovering them while writing the first test — keeps task planning accurate about what
data is actually available before tasks are written.

`erin` was the first name considered for the single reciprocating account, and is wrong: she already
exists in `test/fixtures/users.yml` (floor `5`, no locker, no wish) and is load-bearing for feature
010's `test/system/homepage_locker_wish_test.rb`, which signs in as her specifically for the "answered
the locker question, no locker, no wish declared" state. Repurposing her floor and adding a wish would
break that test; adding a second `erin:` key would fail fixture loading outright. `henry` and `iris`
are unused names in both fixture files.

**Alternatives considered**: Building the reciprocal pairs inline in each test via `LockerWish.create!`
— rejected for consistency with how every other locker-wishes suite already draws its data from
fixtures, and because two shared fixture pairs can be reused across the model, controller and system
tests this feature adds.
