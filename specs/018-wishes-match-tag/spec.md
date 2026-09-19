# Feature Specification: "It's a match!" tag on locker wishes

**Feature Branch**: `018-wishes-match-tag`

**Created**: 2026-09-18

**Status**: Shipped

**Input**: User description: "dans l'écran locker_wishes, un tag \"It's a match!\" doit être visible sur les wishes remplissant ce critère : pour un wish donné, mon étage actuel correspond à l'étage recherché par la personne, ET mon étage recherché correspond à l'étage actuel de cette même personne."

## Clarifications

### Session 2026-09-19

- Q: Where in each row of the locker wishes table should the "It's a match!" tag appear? → A:
  Alongside the existing status text/button in the "Swap" column (e.g. shown above or next to the
  "Propose swap" button, or next to "Proposal pending"/"This is you") — the same column that already
  carries every other row-level status signal, so no new column is introduced and the tag reads as
  one more member of that existing family.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Spot a reciprocal swap at a glance (Priority: P1)

Someone opens the locker wishes screen looking for a floor to move to. Today every row looks the
same, so telling which of the people listed would actually *want* to swap with them — not just
happen to be on the list — means mentally comparing four floor numbers per row: their own current
and desired floor against each row's current and desired floor. When a row's person is on the floor
the viewer wants, and that same person wants the floor the viewer is currently on, the row is marked
with an "It's a match!" tag, so the one swap that works both ways jumps out without any comparing.

**Why this priority**: This is the entire feature. A reciprocal swap is the only kind of swap
guaranteed to be accepted from both sides, and today nothing on the screen says which rows qualify.

**Independent Test**: With the viewer's own current floor and desired floor recorded, and at least
one other wish whose person's current floor equals the viewer's desired floor and whose desired
floor equals the viewer's current floor, open the locker wishes screen and confirm exactly that row
carries the "It's a match!" tag and no other row does.

**Acceptance Scenarios**:

1. **Given** the viewer's current floor is `3` and their desired floor is `7`, and a row's person
   has current floor `7` and desired floor `3`, **When** the viewer opens the locker wishes screen,
   **Then** that row carries the "It's a match!" tag.
2. **Given** the same viewer, **When** they look at a row whose person has current floor `7` but
   desired floor `5` (not `3`), **Then** that row does not carry the tag — matching one direction
   only is not enough.
3. **Given** the viewer has not declared a wish of their own (no desired floor recorded), **When**
   they open the locker wishes screen, **Then** no row carries the tag, however the floors line up,
   because there is nothing of the viewer's to reciprocate.
4. **Given** the viewer's current floor is not recorded, **When** they open the locker wishes
   screen, **Then** no row carries the tag, for the same reason.
5. **Given** a row whose person's current floor is not recorded ("Not set"), **When** the viewer
   views the list, **Then** that row never carries the tag, since an unset floor cannot match
   anything.
6. **Given** the viewer's own row (their own wish, listed like anyone else's), **When** they view
   the list, **Then** their own row never carries the tag, even if their current and desired floor
   happen to be the same value.
7. **Given** a match exists and the viewer has a floor filter applied (from the existing floor
   filters), **When** the matching row is part of the filtered results, **Then** it still carries
   the tag exactly as it would unfiltered.
8. **Given** more than one row satisfies the criteria, **When** the viewer views the list, **Then**
   every qualifying row carries the tag independently — the feature does not limit this to a single
   match or reorder the list.
9. **Given** a matching row where the viewer can still propose a swap, **When** the viewer views the
   list, **Then** the tag appears in the same column as the "Propose swap" button, alongside it.
10. **Given** a matching row where a swap proposal is already pending between the viewer and that
    person, **When** the viewer views the list, **Then** the tag appears alongside the existing
    "Proposal pending" text in that same column, rather than replacing it.

### Edge Cases

- What happens when the viewer edits or cancels their own wish so it no longer reciprocates with a
  previously-matching row? The tag disappears from that row the next time the list is shown, since
  the criteria are evaluated fresh each time, not stored.
- What happens when a formerly-matching person changes their own current floor (moves locker) or
  their desired floor? The same as above — the tag reflects the current state of both wishes, not a
  historical one.
- What happens when the viewer's current floor and desired floor are the same value, and a row's
  person is the mirror of that (also wanting to swap between those same two floors)? The tag still
  applies to that row as long as it is not the viewer's own row — the criteria only compare floor
  values, not whether the two floors happen to be equal to each other.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST show an "It's a match!" tag on any row of the locker wishes list
  whose person's current floor equals the viewer's own desired floor, AND whose desired floor
  equals the viewer's own current floor.
- **FR-002**: The system MUST NOT show the tag on a row unless both halves of the criteria in
  FR-001 are satisfied — a match in only one direction does not qualify.
- **FR-003**: The system MUST NOT show the tag on any row when the viewer has not declared their own
  wish (no desired floor recorded), regardless of how any row's floors compare.
- **FR-004**: The system MUST NOT show the tag on any row when the viewer's own current floor is not
  recorded.
- **FR-005**: The system MUST NOT show the tag on a row whose person's current floor is not
  recorded.
- **FR-006**: The system MUST NOT show the tag on the viewer's own row.
- **FR-007**: The system MUST evaluate the tag independently for every row that currently appears in
  the list, so more than one row can carry it at the same time.
- **FR-008**: The system MUST continue to show the tag on a qualifying row when the list is narrowed
  by any existing floor filter, as long as that row is still part of the filtered results.
- **FR-009**: The system MUST re-evaluate the tag from the current state of both wishes every time
  the list is displayed, rather than remembering a past match after either person's floors change.
- **FR-010**: The tag MUST appear in the same part of the row that already carries the other status
  indicators for that row (such as "Proposal pending", "This is you", or "You already have an
  exchange in progress" — the "Swap" column), be visually distinguishable from them, and MAY appear
  alongside them rather than replacing them.

### Key Entities

- **Locker Wish**: A person's declared search for a locker — carries the floor they want and
  belongs to one person at a time. Already exists; this feature only reads it, for the viewer and
  for the person on each row.
- **Locker Profile (current floor)**: The floor a person already occupies, separate from any floor
  they are searching for. Already exists; this feature compares it against the desired floor on the
  other side of a potential swap.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A viewer can identify every row that would make a guaranteed two-way swap without
  comparing a single floor number by hand — 100% of rows meeting the reciprocity criteria are
  visibly tagged whenever the screen is shown.
- **SC-002**: No row is ever tagged unless it truly satisfies both directions of the match — a
  false positive never appears, since a wrong tag would send the viewer to propose a swap that the
  other person never actually wanted.
- **SC-003**: The tag appears with no perceptible extra delay compared to loading the list today.

## Assumptions

- The tag is a visual indicator only for this feature; it does not change sort order, filtering
  behavior, or which rows appear on the screen, and it does not by itself send any notification.
- "Current floor" refers to the same value already shown in the list's "Their floor" column and
  compared against in the existing floor filters (017); "desired floor" refers to the same value
  already shown in the "Looking for floor" column.
- A person can only ever have one active wish at a time (existing behavior), so the comparison is
  always one wish against one other wish, never a person against several floors at once.
