# Contract: `current_floor` derivation and redirects

**Feature**: [spec.md](./../spec.md) | **Plan**: [plan.md](./../plan.md)

This extends 017's `contracts/locker-wish-filter.md` URL contract for the `current_floor` axis only.
`looking_for` is governed entirely by that existing contract and is not repeated here.

## Request → selection

For any `GET /locker_wishes` (the `index` action, including a fresh top-level visit, a frame-scoped
filter-link fetch, and a Back/Forward restoration of either kind — see research R1 for why these are
not distinguished):

| Query string | Resulting `current_floor` selection |
|---|---|
| No `current_floor` key at all | `current_user.locker_wish&.saved_floor` — a specific floor if the viewer has an active wish, `nil` ("All floors") if not |
| `current_floor=` (present, empty) | `nil` ("All floors") — a deliberate choice, held for the rest of the visit |
| `current_floor=<value>` (present, non-empty) | `<value>`, matched exactly as 017 already matches it — a deliberate choice, held for the rest of the visit |

A `POST /locker_wish` (declare/change) whose `save_locker_wish` fails re-renders `:index` from the
submitted params directly (no redirect) — the table above applies unchanged to that render, using
whatever `current_floor` the submitted form carried (see "Outgoing links" below for why it is always
present).

## Action → redirect address

| Action | Outcome | `current_floor` in the redirect target |
|---|---|---|
| `POST /locker_wish` (declare or change) | Saved | Explicitly set to `@locker_wish.saved_floor` (the new floor), overwriting whatever was submitted |
| `POST /locker_wish` (declare or change) | Rejected | N/A — re-renders `:index` in place, no redirect (see table above) |
| `DELETE /locker_wish` (cancel) | Always | Dropped from the redirect target entirely (`.except(:current_floor)`) — resolves to "All floors" on the next render via the no-active-wish branch of the request→selection table |

`looking_for` is carried forward on both redirects exactly as 017 already does, untouched by either row
above.

## Outgoing links (what this screen renders into its own `href`s and hidden fields)

- Every link the "Their Floor" filter bar renders (`locker_wishes/_floor_filter.html.erb`, both the
  "All floors" choice and each per-floor choice) encodes `current_floor` explicitly — `""` for "All
  floors", the floor value otherwise — never omitted, regardless of whether the *current* request's own
  `current_floor` came from the query string or was derived from the wish. This is what makes a single
  click "stick" for the rest of the visit (research R1): the next request this filter's own link
  produces always carries the key.
- The `looking_for` filter bar's links continue to encode whatever `current_floor` is currently in force
  (derived or explicit) so that changing one axis never loses the other — unchanged from 017, except
  that the value being preserved may now itself be a wish-derived one rather than only ever an
  explicitly-chosen one.
- The hidden fields carrying filter state into the declare (`LockerWishesController::DECLARE_FORM_ID`)
  and cancel (`CANCEL_FORM_ID`) forms, rendered in `_locker_wish_list.html.erb`, include `current_floor`
  unconditionally (previously conditional on `filter.filtering?`, per 017) — see research R4 for why a
  conditional field would silently drop a manual "All floors" choice on a rejected declare.

## Query budget (Principle IV)

Deriving `current_floor` from `current_user.locker_wish&.saved_floor` reads an association the
controller has already loaded by the time it runs (research R2). No query is added on any path. The
controller test asserts the index issues no more queries with an active wish present than without,
extending the existing 017/018 assertion of the same shape.

## Explicit non-goal

This contract does not attempt to distinguish "the viewer went Back/Forward to a state chosen earlier
this visit" from "the viewer opened a bookmarked or shared link that happens to encode the same
`current_floor` value" — both present the identical request, and both are resolved by the first table's
middle/bottom rows (respected as given). See research R1's "Known limitation, accepted."
