# Contract: Locker wish floor filters

**Feature**: [spec.md](../spec.md) | **Date**: 2026-09-18

The feature adds no route and no endpoint. What it adds is a parameter contract on an existing GET, a
frame contract the browser relies on, and a DOM contract the tests assert against. All three are
stated here so the implementation and the suites cannot drift apart.

## Routes

```
GET    /locker_wishes            →  LockerWishesController#index     locker_wishes_path
POST   /locker_wish              →  LockerWishesController#create    locker_wish_path
DELETE /locker_wish              →  LockerWishesController#destroy    locker_wish_path
```

Unchanged — `config/routes.rb` is not edited. The selections are query parameters on `#index`, and
round-trip through `#create` / `#destroy` as ordinary request parameters.

## Parameter contract (`GET /locker_wishes`)

| Parameter | Value | Meaning |
|---|---|---|
| `looking_for` | Any string | Show only wishes whose own floor equals it exactly |
| `looking_for` | absent, `""`, or whitespace | All floors — the axis is not filtering |
| `current_floor` | Any string | Show only wishes whose owner's saved floor equals it exactly |
| `current_floor` | absent, `""`, or whitespace | All floors — the axis is not filtering |

Both may be present at once; the result is the intersection (FR-011). Neither is validated against a
known set: a value matching nothing yields an empty list, never an error and never a silent fallback
to the unfiltered list (FR-020). Unknown parameters are ignored as they are today.

`locker_wish_params` stays `params.expect(locker_wish: [ :floor ])` — the two filter values are read
separately and never reach the record.

## Access contract

| Caller | Outcome |
|---|---|
| Anonymous | Redirect to `new_user_session_path` (`authenticate_user!`), nothing shown — unchanged (003 FR-013, restated as FR-022) |
| Signed in | The screen, filtered per the parameters above |

The filter adds no authorization surface: it narrows a list every signed-in user can already see in
full, and exposes no row, field or floor that the unfiltered screen does not already show.

## Response contract (`GET /locker_wishes`)

| State | What is rendered inside the list region |
|---|---|
| No active wishes at all | The existing `#locker-wish-list-empty` message, "Nobody is looking for a locker right now." Both filter groups render with only the "All floors" choice (User Story 4, scenario 2) |
| Active wishes, no filter in force | Every active wish, oldest declaration first — byte-for-byte the rows the screen renders today |
| Filter(s) in force, matches found | Only the matching wishes, same row content and same order (FR-013) |
| Filter(s) in force, no match | A no-match message, worded distinctly from the "nobody is looking" one (FR-016), with both filter groups still rendered and the selections still current (FR-015) |

Row content, the "Propose swap" control and every reason it is withheld ("This is you", "You already
have an exchange in progress", "Proposal pending") are unchanged in all states (FR-014).

## Redirect contract (`#create`, `#destroy`)

| Request | Redirects to | Notice |
|---|---|---|
| `POST /locker_wish` succeeds | `locker_wishes_path` **carrying both selections** | "Locker search saved." (unchanged) |
| `POST /locker_wish` rejected | Re-renders `:index`, status `422`, **both selections still in force** | Devise error partial (unchanged) |
| `DELETE /locker_wish` | `locker_wishes_path` **carrying both selections** | "Locker search cancelled." (unchanged) |

This is FR-019. A selection that is blank is omitted from the redirect rather than sent as an empty
parameter, so the unfiltered case redirects to the bare `/locker_wishes` it does today.

## Frame contract

```html
<turbo-frame id="locker-wish-list" data-turbo-action="advance">
```

- Wraps the whole list region: both filter groups, the table (or the empty/no-match message).
- The filter links live **inside** the frame, so they drive it without a `data-turbo-frame` attribute.
- The "Propose swap" `button_to` carries `data-turbo-frame="_top"`. It is the only form inside the
  frame, and its redirect targets a page that *contains* the frame, so without `_top` Turbo renders
  that redirect into the frame: the "Swap proposal sent." toast is swallowed and the frame drops both
  selections from the address (FR-014).
- `#index` renders the complete page; Turbo extracts this frame. A direct visit, a reload or a
  back/forward landing on a filtered URL therefore renders the same screen server-side (FR-018).
- The wish declaration panel (`locker_wishes/_locker_wish_panel`) sits **outside** the frame and is
  never replaced by a filter change (FR-009).
- The screen carries `<meta name="turbo-cache-control" content="no-cache">`. An advancing frame
  navigation snapshots the page for the address being left *after* the frame has been re-drawn, so a
  cached restore would show the new filter under the old address. Opting out makes Back ask the
  server, which renders whatever the address says (FR-018).
- The two forms in the declare panel carry the ids `LockerWishesController::DECLARE_FORM_ID` and
  `CANCEL_FORM_ID`. The hidden fields carrying the selections live **inside** the frame — where a
  filter change refreshes them — and attach to those forms by the HTML `form` attribute. Fields placed
  inside the panel would go stale on the first filter change and FR-019 would fail.

## DOM contract

Stable hooks the tests may assert on. Existing ids are unchanged; new ones follow the screen's
existing `locker-wish-*` naming.

| Selector | Purpose |
|---|---|
| `#locker-wish-list` | The `<turbo-frame>`. The id moves here from the inner card `div`, so existing assertions keep matching |
| `#locker-wish-filters` | The filter bar holding both groups |
| `nav[aria-label]` ×2 | One group per axis. The labels are the list's own column terms — "Looking for floor" and "Their floor" — never "current floor", which is the parameter name only (FR-002, FR-021) |
| `#locker-wish-filter-looking-for` | The "looking for floor" group |
| `#locker-wish-filter-current-floor` | The "current floor" group |
| `a[aria-current="true"]` | The choice in force within a group (FR-015) |
| `#locker-wish-list-empty` | Existing — "nobody is looking" only |
| `#locker-wish-list-no-match` | New — "no wish matches these filters" only (FR-016) |
| `#locker-wish-row-<user_id>` and its `-floor` / `-person` / `-current-floor` / `-current-locker` / `-swap` cells | Existing row hooks, unchanged |

The two empty states are separate ids on purpose: FR-016 requires distinct wording, and a single id
with swapped text would let a regression satisfy the selector while saying the wrong thing.

## Accessibility contract

- Each group is a `<nav>` with its own `aria-label`, so the two axes are distinguishable to assistive
  technology rather than one flat list of links (FR-021).
- The choice in force carries `aria-current="true"` — a state of this screen, not a separate page.
- Every choice is a link: reachable by Tab, activated by Enter, never activated by being focused or
  passed over (FR-008).
- axe-core must report clean on the filtered list and on the no-match state, under the existing
  `assert_axe_clean` exemption list — no new exemption is introduced.

## Performance contract

- Two `SELECT DISTINCT` queries are added per render, one per axis, each returning at most one row per
  distinct floor and independent of wish count.
- No query is added per row.
- A filtered index issues no more queries than an unfiltered one — asserted in
  `test/controllers/locker_wishes_controller_test.rb`, and the evidence Principle IV requires in the
  PR description.
