# Phase 1 Data Model: Responsive Site Layout and Signed-In Menu

**Feature**: 012-responsive-layout-menu
**Date**: 2026-09-15

## Persisted data: none

This feature introduces no entity, no attribute, no relationship and no
migration. It reads nothing new and writes nothing. The spec says so explicitly
under Key Entities, and the plan's Technical Context repeats it.

Concretely, the following stay exactly as they are:

- `User` — no new column, no new validation, no new scope.
- `LockerWish`, `LockerSwapProposal` — untouched.
- Every controller query — untouched. The two list screens render the same
  records in the same order; only their presentation changes with width.

There is therefore no schema diff to review, and Principle IV's rule about
unbounded queries is not engaged: no query is added or altered.

## Presentational state

What the feature *does* introduce is a small amount of view state. It is written
down here because the tests assert against it and the contracts refer to it.

### Viewport treatment

A derived, read-only value. Not stored anywhere; computed by the browser from
the viewport width against the single breakpoint.

| State | Condition | Governs |
|---|---|---|
| `narrow` | viewport < 48rem (768px) | menu is a disclosure; lists are stacked cards; standalone controls ≥ 44px |
| `wide` | viewport ≥ 48rem (768px) | menu is a full bar; lists are column tables; controls keep current sizing |

Invariants (FR-018, FR-018b):

- Exactly one treatment applies at any width. There is no overlap and no gap.
- 767px is `narrow`; 768px is `wide`.
- The treatment is global. No region of the site may be in one treatment while
  another region is in the other.

### Menu disclosure state

Held by the `open` attribute on the `<details>` element — that is, by the
browser, not by the application. Nothing is persisted; the panel starts closed
on every page load.

| State | Reached by | Left by |
|---|---|---|
| `closed` (initial) | page load; second activation of the toggle; Escape*; activation outside the panel*; following a link from the panel | activating the toggle |
| `open` | activating the toggle | as above |

\* script-dependent (FR-010b-i). The other transitions are native and work with
no script (FR-010b).

Invariants:

- In the `wide` treatment the state is not observable: the toggle is hidden and
  the panel is displayed regardless of the attribute (FR-009).
- The state can always be exited without script (FR-010b-ii) — a second
  activation of the toggle always closes the panel.
- Closing returns focus to the toggle (FR-015).

### List record projection

Each record in the two data lists renders from one source into two visual forms.
There is one rendering path; the form is chosen by CSS.

| Field carries | Wide form | Narrow form |
|---|---|---|
| column name | `<th>` in the header row | `data-label`, surfaced as visible text before the value |
| value | `<td>` in the row | `<td>` as a labelled line in the card |
| row action / status | last cell in the row | a line in the card, visible without horizontal scrolling |

Invariants (FR-005a–e):

- Every field present in the wide form is present in the narrow form. Nothing is
  dropped, hidden or summarised.
- Record order and within-record field order are identical in both forms,
  because there is only one order in the markup.
- Both forms carry correct table semantics via explicit ARIA roles.
- The empty state is identical in both forms.
