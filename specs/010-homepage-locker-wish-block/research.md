# Phase 0 Research: Homepage Locker Wish Block

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-15

No `NEEDS CLARIFICATION` markers remained in the Technical Context — the five spec
clarifications settled scope, placement, content and precedence. What follows are
the design decisions that filling in that context forced, each recorded with the
alternative that was rejected.

## 1. Where the block's state comes from

**Decision**: Read `current_user.locker_wish` and `current_user.saved_locker_number`
directly in the partial. No new instance variable, no controller change.

**Rationale**: The homepage has two renderers — `HomeController#index` and
`LockerProfilesController#update`, which re-renders `home/index` with
`:unprocessable_entity` after a rejected locker edit. An instance variable set in
only one of them makes the block vanish exactly when a user has just made a
mistake, which is the failure mode `LoadsHomepageProposals` was extracted to fix
(see its header comment). Reading through `current_user` cannot be forgotten by a
second renderer. It also matches how this specific screen is already written:
`home/index.html.erb` calls `current_user.saved_floor` and
`LockerSwapProposal.active_for?(current_user)` inline, and `_locker_profile.html.erb`
reads `current_user.saved_floor` / `saved_locker_number` directly. `has_one`
memoizes on the user object, so the lookup happens at most once per request.

**Alternatives considered**:

- *A `LoadsHomepageLockerWish` concern included in both controllers* — mirrors the
  `LoadsHomepageProposals` precedent, but that concern exists because it loads four
  collections with eager-loaded counterparts; a whole file and an `include` in two
  controllers for one `has_one` read is the unjustified complexity Principle I
  asks to refactor away.
- *`@locker_wish = current_user.locker_wish` in each controller separately* —
  duplicated, and silently breaks the re-render path the day someone adds a third
  renderer.

## 2. Link, not button_to

**Decision**: All three controls are `link_to "<label>", locker_wishes_path,
class: "btn btn-primary"`.

**Rationale**: The control navigates; it changes nothing. `button_to` — used
elsewhere on this page for Withdraw, Cancel wish and Log out — emits a form and a
POST, which would be wrong for a GET destination, would need a route that does not
exist, and would break back-button behaviour. A link styled as a button keeps the
correct semantics for assistive technology (announced as a link, activated with
Enter) and satisfies FR-010 with no ARIA of its own. The site header already styles
navigation this way (`site-nav-link` → `locker_wishes_path`).

**Alternatives considered**:

- *`button_to ... method: :get`* — produces a form for a navigation, announced as a
  button, and fights Turbo's caching for no gain.
- *A bare text link* — FR-005's clarification explicitly asks for a button-styled
  control in all three states, so the invitation does not read as decoration.

## 3. Deciding "has a locker"

**Decision**: `current_user.saved_locker_number.present?` distinguishes the "switch"
invitation (FR-004) from the "want a locker" invitation (FR-005).

**Rationale**: `saved_locker_number` reads `locker_number_in_database`, which is the
value actually on file rather than the attribute — during a rejected locker edit the
attribute holds the input still being corrected, and the block must not flip state
because of a submission that was refused. The model normalizes `""` to `NULL`
(002 FR-002), so `present?` is a reliable answer. `_locker_profile.html.erb` uses the
same reader for the same question ("No locker assigned").

**Alternatives considered**:

- *`current_user.locker_number.present?`* — reads the in-memory attribute and would
  make a rejected edit change which invitation is shown.

## 4. Withholding the block before details are saved

**Decision**: Render the partial inside the existing `if current_user.saved_floor.present?`
branch of `home/index.html.erb`, immediately before `render "home/locker_profile"`.

**Rationale**: That condition is already the homepage's definition of "has this user
answered yet" (002), and it is exactly the precondition the clarification set. Placing
the render inside that branch satisfies FR-001a and FR-012 with one line and no second
condition to keep in sync. The floor is mandatory on every save path, so "floor on
file" and "details saved" are the same fact, including for the "I don't have a locker 😔"
path added in 009.

**Alternatives considered**:

- *A separate `unless current_user.saved_floor.nil?` guard inside the partial* — a
  second copy of the same rule, and it would leave the partial rendering an empty
  `<div>` into the stack.

## 5. Wish precedence over the invitations

**Decision**: Branch on the wish first: a persisted `locker_wish` wins regardless of
locker state; only then split on `saved_locker_number`.

**Rationale**: This is the spec's stated precedence (Edge Cases, FR-002 through FR-005)
and it makes the three states structurally exclusive — a single `if / elsif / else`
cannot produce two buttons or none, which is what SC-002 asserts. Testing the wish
with `persisted?` rather than truthiness matters if the object ever arrives from
`build_locker_wish`; on the homepage it comes straight from the association, so `nil`
is the no-wish case, but `persisted?` is correct under both.

## 6. Turbo Drive and staleness (FR-007)

**Decision**: No cache-control work, no Turbo Stream, no `data-turbo-permanent`.
System tests call `wait_for_turbo` before asserting on the block.

**Rationale**: Declaring or cancelling a wish redirects to `locker_wishes_path`, so the
homepage is re-rendered from scratch on the user's next visit and always reflects
current state. Turbo Drive does paint a cached snapshot first on a back-navigation, and
that snapshot can carry the *previous* state of this card — a real source of flake for
a test that asserts immediately. `wait_for_turbo` is the documented remedy already in
`ApplicationSystemTestCase` (the 008 lesson); nothing in the application needs to
change for it.

**Alternatives considered**:

- *Broadcasting a Turbo Stream update from the wish controller* — real-time freshness
  nobody asked for, a new dependency between two features, and FR-007 only requires
  correctness on the next homepage view.

## 7. Styling

**Decision**: Reuse `.card`, `.stack-tight`, `.card-title`, `.card-lead`, `.detail-term`,
`.detail-value`, `.row`, `.btn`, `.btn-primary`. Expect no stylesheet change.

**Rationale**: The wish state is a title plus one labelled value plus one button — the
shape `_locker_profile.html.erb` and `locker_wishes/_locker_wish_panel.html.erb`
already have. Principle III asks for the established pattern over a new one, and the
existing classes carry the contrast and focus treatment 008 verified. A new rule would
have to justify itself in review.

**Alternatives considered**:

- *A distinct accent treatment to make the block stand out* — untested contrast, a new
  pattern on a page that deliberately has one card language, and not asked for.

## 8. Test fixtures

**Decision**: Add one user fixture with a floor, no locker number, and no wish. Reuse
`dave` (locker, no wish) for FR-004, `bob` or `carol` (both have wishes) for FR-002/3,
and `alice` (no details at all) for FR-001a.

**Rationale**: The existing set has no user in the FR-005 state — `carol` is floor-only
but already carries `carol_wish`, and deleting a fixture wish inside a test is the
pattern `locker_wishes.yml` explicitly set out to avoid. One added fixture covers the
missing state without touching any existing test's assumptions. Note that adding a user
fixture also adds a row to the wish list and proposal history screens' expectations only
if that user has a wish or proposal — this one has neither, so no existing test moves.
