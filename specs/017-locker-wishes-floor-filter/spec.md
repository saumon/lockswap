# Feature Specification: Filter locker wishes by floor

**Feature Branch**: `[017-locker-wishes-floor-filter]`

**Created**: 2026-09-18

**Status**: Draft

**Input**: User description: "dans l'écran locker_wishes on doit pouvoir filtrer sur l'étage afin de faciliter la recherche d'un casier."

## Clarifications

### Session 2026-09-18

- Q: Each row on the locker wishes screen carries two floors — the floor the person is *looking for*
  ("Looking for floor") and the floor where they already hold a locker ("Their floor"). Which one
  does the filter act on? → A: Both, as two independent filters that can be combined. One narrows the
  list by the floor being looked for, the other by the floor the person currently occupies; each can
  be left on "all floors", and when both are set the list shows only the rows matching both.
- Q: When the viewer saves or cancels their own wish while a floor filter is active, should the
  filter selections still be in force on the screen they land back on? → A: Yes — both selections are
  preserved across saving and cancelling one's own wish. If the viewer's own row no longer matches
  after the change, it simply leaves the filtered list; the filters are not cleared to keep it in
  view.
- Q: In what order should the floors be offered inside each filter control? → A: Floors that read as
  numbers first, in ascending numeric order (so `3` before `10`), then any non-numeric floor value in
  alphabetical order. The same ordering applies to both filters.
- Q: When the viewer picks a floor, should the list update straight away, or only after they activate
  a separate "Apply" control? → A: Straight away, on deliberate selection of a floor — one
  interaction, no "Apply" control. Moving through the available floors without committing to one
  (for example arrowing through them with the keyboard) must not re-filter the list.
- Q: When a filter is applied, should the viewer stay where they are on the page with only the list
  changing, or is reloading the whole screen acceptable? → A: Only the wish list region changes. The
  wish declaration panel, the navigation and the viewer's reading position stay as they are, so the
  viewer can try one floor after another without scrolling back down each time.
- Q: Once one filter is set, should the other filter still offer every floor, or only the floors that
  remain reachable given the first selection? → A: Every floor. Each filter's choices are derived from
  the full set of active wishes and do not change when the other filter is set, so the choices never
  shift under the viewer. A combination matching nobody is reachable and is handled by the existing
  "no wish matches these filters" state.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Narrow the wish list by the floor people are looking for (Priority: P1)

Someone opens the locker wishes screen. Today it shows every active wish in one long list, so
finding the rows that matter means reading the whole thing. They pick a floor in the "looking for"
filter and the list immediately shows only the people searching for that floor — which, when they
pick their own current floor, is exactly the set of people a swap with them could work for.
Everything else about each row — who the person is, their current floor and locker, and whether a
swap can be proposed to them — stays exactly as it is today.

**Why this priority**: This filter acts on the screen's headline column and is the one that answers
"who could I swap with". On its own it already makes the screen measurably faster to use, with no
other part of this feature in place.

**Independent Test**: With several wishes recorded across at least three different looked-for floors,
open the locker wishes screen, choose one floor in the "looking for" filter, and confirm the list
shows every row for that floor and no row for any other — the second filter is not needed for this
to deliver value.

**Acceptance Scenarios**:

1. **Given** active wishes exist for several looked-for floors, **When** the viewer selects one floor
   in the "looking for" filter, **Then** the list shows only the rows whose looked-for floor matches
   that selection, and the number of rows shown equals the number of active wishes for that floor.
2. **Given** a looked-for floor is selected, **When** the viewer looks at a row that is still shown,
   **Then** that row carries the same person, floors, locker and swap information it carried before
   the filter was applied.
3. **Given** a looked-for floor is selected, **When** the viewer is eligible to propose a swap to a
   person on a shown row, **Then** proposing a swap from the filtered list behaves exactly as it does
   from the unfiltered list.
4. **Given** a looked-for floor is selected, **When** the viewer's own wish matches that floor,
   **Then** their own row is shown in the filtered list, marked as theirs the same way it is today.
5. **Given** wishes exist for floors `1`, `3` and `10`, **When** the viewer opens the filter,
   **Then** the choices read "all floors", `1`, `3`, `10` in that order — `10` last, not between
   `1` and `3`.
6. **Given** the viewer is moving through the filter's available floors with the keyboard, **When**
   they pass over floors without committing to one, **Then** the list is not re-filtered; it changes
   only once they select a floor.

---

### User Story 2 - Narrow the wish list by the floor people currently occupy (Priority: P2)

The same viewer wants the other direction: not who is looking for their floor, but who currently
holds a locker on the floor they themselves want. They pick a floor in the "current floor" filter and
the list shows only the people whose saved locker is on that floor, whatever they happen to be
looking for.

**Why this priority**: This is the second half of the stated goal — making it easier to find a
locker, as opposed to finding someone who wants yours. It is independently valuable but secondary:
the looked-for filter is the screen's primary axis and ships first.

**Independent Test**: With wishes recorded by people whose saved lockers sit on at least three
different floors, select one floor in the "current floor" filter and confirm only the people on that
floor remain — verifiable with the "looking for" filter left on "all floors" throughout.

**Acceptance Scenarios**:

1. **Given** active wishes exist from people on several current floors, **When** the viewer selects
   one floor in the "current floor" filter, **Then** the list shows only the rows whose person holds
   a locker on that floor, and no other row.
2. **Given** a current floor is selected, **When** a person on the list has never saved a floor,
   **Then** their row is not shown, and the screen does not report an error for it.
3. **Given** a current floor is selected, **When** the viewer returns that filter to "all floors",
   **Then** rows for people with no saved floor are shown again alongside everyone else.

---

### User Story 3 - Combine both filters, and clear them (Priority: P2)

Having used either filter alone, the viewer sets both at once — "looking for floor 3" and "currently
on floor 1" — and sees only the rows matching both, which is the shortlist of people an exact swap
with them would suit. They then return either filter, or both, to "all floors" and the corresponding
rows come back.

**Why this priority**: Combining is what makes two filters worth more than one, and a filter the
viewer cannot get out of without reloading or guessing is a trap. It rides directly on Stories 1 and
2 and is not usable before either exists.

**Independent Test**: Apply both filters, confirm only rows matching both remain, then clear each in
turn and confirm the list widens back out at each step, ending identical to the unfiltered list.

**Acceptance Scenarios**:

1. **Given** both filters are set, **When** the list is displayed, **Then** it shows only the rows
   matching both selections, and a row matching only one of the two is not shown.
2. **Given** both filters are set, **When** the viewer returns one of them to "all floors", **Then**
   the list shows every row matching the filter that is still set, regardless of the other floor.
3. **Given** both filters are set, **When** the viewer returns both to "all floors", **Then** every
   active wish is shown again, in the same order as before any filter was applied.
4. **Given** the viewer arrives on the screen for the first time, **When** the screen is displayed,
   **Then** neither filter is applied and every active wish is shown.
5. **Given** the viewer has scrolled down to the list, **When** they change either filter, **Then**
   only the list region changes; the wish declaration panel above it and their position on the page
   are unchanged, and they do not have to scroll back down.
6. **Given** one filter is set, **When** the viewer opens the other filter, **Then** it offers the
   same floors, in the same order, as it did before the first filter was set.
7. **Given** both filters are set to a combination no wish matches, **When** the list is displayed,
   **Then** the "no wish matches" message is shown and both filters still offer their full set of
   floors, so the viewer can relax either one.

---

### User Story 4 - Recognise that a selection simply matches nobody (Priority: P3)

The viewer makes a selection and nothing matches it. Rather than an apparently broken or blank
screen, they are told plainly that no wish matches the chosen filters, and both filter controls still
show what they picked so they can change one without re-orienting themselves.

**Why this priority**: An empty result is a normal outcome of filtering — and far more likely once
two filters can be combined — not an error. The screen already has an established way of saying
"nobody is looking right now", so this must be distinct from it. It is only reachable once filtering
exists.

**Independent Test**: Select a combination for which no wish exists and confirm a clear "no match"
message is shown, both chosen floors are still visible in their controls, and clearing them restores
the list.

**Acceptance Scenarios**:

1. **Given** no active wish matches the current selections, **When** the list is displayed, **Then** a
   clear message states that no wish matches the chosen filters, distinct in wording from the
   existing "nobody is looking for a locker right now" message shown when the whole list is empty.
2. **Given** no active wish exists at all, **When** the screen is displayed, **Then** the existing
   "nobody is looking" message is shown and neither filter offers any floor to choose from.

---

### Edge Cases

- What happens when a filter is set and the person on a shown row starts an exchange with someone
  else, so their wish leaves the list? The row disappears from the filtered list on the next display,
  the same way it disappears from the unfiltered list today.
- What happens when a selection is in force and every wish matching it is cancelled? The next display
  of the screen shows the "no wish matches these filters" message rather than an error. That floor is
  no longer offered to anyone choosing afresh, but it stays visible as the current selection for the
  viewer who is on it, so they can see what they are filtered on and change it.
- What happens when the viewer sets a filter and then changes their own wish to a different floor?
  The selections stay in force across the save. Their own row leaves the filtered list if it no
  longer matches, and the confirmation of the saved wish is shown as it is today.
- What happens when the viewer cancels their own wish while filters are applied? The selections stay
  in force, their row is gone from the list as it is today, and the cancellation confirmation is
  shown. If their wish was the only one matching the selections, the "no wish matches these filters"
  message is shown.
- How does the system handle a floor that does not exist, or a nonsensical floor value, arriving
  directly in the page address for either filter? The screen is shown without error, reporting that
  no wish matches, rather than failing or silently showing everything.
- What happens when the two selections are individually valid but mutually exclusive — nobody on
  floor 1 is looking for floor 3? The "no wish matches these filters" message is shown, with both
  selections still visible so the viewer can relax one.
- What happens to a person who has declared a wish but never saved a floor of their own? Their row is
  shown whenever the "current floor" filter is on "all floors", and is excluded whenever a specific
  current floor is selected. Their row still reads "Not set" as it does today.
- What happens when two floors are recorded with visually similar but different values (for example
  `3` and `03`)? They are treated as two distinct floors and offered as two separate choices; a
  filter on one does not show the other. Both read as the same number, so they sort next to each
  other; their order relative to one another is settled consistently rather than varying between
  displays.
- How does the system behave when the viewer's wish declaration is rejected (for example an empty
  floor) while filters are applied? The error is reported as it is today and the list below it stays
  filtered on the current selections.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The locker wishes screen MUST offer two floor filter controls positioned with the list
  of wishes, separate from the control the viewer uses to declare or change their own wish, so the
  filters and the declaration cannot be mistaken for one another.
- **FR-002**: The two filters MUST be distinguishable by their labels: one narrows the list by the
  floor each person is looking for, the other by the floor where that person currently holds a
  locker. The labels MUST use the same terms the list's own columns already use.
- **FR-003**: Each filter MUST offer an explicit "all floors" choice, and both MUST be in that state
  when the screen is first opened without a filter.
- **FR-004**: The "looking for" filter MUST offer, as choices, exactly the distinct looked-for floors
  present among all active wishes, and no floor for which there is no active wish.
- **FR-005**: The "current floor" filter MUST offer, as choices, exactly the distinct saved floors of
  the people behind all active wishes, and no floor on which none of them holds a locker.
- **FR-006**: Each filter's choices MUST be derived from the full set of active wishes and MUST NOT
  be narrowed by the other filter's current selection; setting one filter MUST NOT add to, remove
  from, or reorder the choices offered by the other.
- **FR-007**: Both filters MUST order their choices the same way: floor values that read as numbers
  first, in ascending numeric order, so that `3` is offered before `10`; then any floor value that
  does not read as a number, in alphabetical order. The "all floors" choice MUST come before all of
  them.
- **FR-008**: Selecting a floor MUST take effect on the list immediately, in that one action. The
  screen MUST NOT require a separate "Apply" or confirm control. Moving through a filter's available
  floors without committing to one — for example arrowing through them with the keyboard — MUST NOT
  re-filter the list.
- **FR-009**: Applying, changing or clearing a filter MUST update the wish list region only. The wish
  declaration panel, the navigation and the viewer's position on the page MUST be left as they are,
  so that trying one floor after another costs no scrolling.
- **FR-010**: When one filter is set and the other is on "all floors", the list MUST show every active
  wish matching the set filter exactly, and no other wish.
- **FR-011**: When both filters are set, the list MUST show only the active wishes matching both
  selections; a wish matching only one of the two MUST NOT be shown.
- **FR-012**: A person who has never saved a floor of their own MUST be shown whenever the "current
  floor" filter is on "all floors", and MUST NOT be shown when a specific current floor is selected.
  This MUST NOT be reported as an error.
- **FR-013**: Filtering MUST NOT change the information shown on a row, the order of rows, or which
  wishes are eligible to appear at all; it only removes rows that do not match.
- **FR-014**: Filtering MUST NOT change who may be sent a swap proposal or what happens when one is
  sent; all existing eligibility rules and their on-row explanations apply unchanged.
- **FR-015**: Both current selections MUST remain visible in their controls while the filtered list is
  displayed, including when the result is empty. A selection that is in force MUST stay visible even
  when no active wish carries that floor any more — because the wishes for it were cancelled, or
  because the value arrived in the page address — so the viewer can always see, and change, what is
  being filtered on.
- **FR-016**: When a selection is in force and no active wish matches it, the screen MUST say so in
  wording distinct from the message shown when there are no active wishes at all.
- **FR-017**: Each filter MUST be clearable independently, returning it to "all floors" without
  disturbing the other.
- **FR-018**: Both selections MUST be reflected in the page address, so that a filtered view can be
  returned to, shared, or reached with the browser's back and forward controls.
- **FR-019**: Both selections MUST survive the viewer saving or cancelling their own wish: the screen
  they land back on afterwards MUST still be filtered on the selections that were in force. If the
  viewer's own row no longer matches after the change, it simply leaves the filtered list; the
  filters MUST NOT be cleared in order to keep it in view.
- **FR-020**: A floor value arriving in the page address that matches no active wish MUST be handled
  as an empty result, not as an error, and MUST NOT cause the unfiltered list to be shown instead.
- **FR-021**: Both filters MUST be operable by keyboard alone and MUST each carry a label naming what
  they filter, so that they are usable with assistive technology.
- **FR-022**: The filters MUST be available only to signed-in users, on the same terms as the rest of
  the locker wishes screen.
- **FR-023**: The filters MUST remain usable at narrow widths, following the screen's existing
  responsive behaviour rather than introducing sideways scrolling.

### Key Entities *(include if feature involves data)*

- **Locker wish**: an existing record of one person's search for a locker on a particular floor. This
  feature reads wishes and their floors; it does not create, change, or remove any.
- **Person's saved locker details**: the floor and locker number a person has already recorded for
  themselves, already shown on each row. This feature reads the floor to offer and apply the second
  filter; it does not change it.
- **Floor**: a free-text label already recorded on wishes and on people's saved locker details. This
  feature introduces no new list of valid floors and no new floor data — the choices it offers are
  derived from the wishes that exist.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With at least 30 active wishes spread across at least 5 floors, a viewer can isolate the
  wishes for one floor — on either axis — in a single interaction, without typing.
- **SC-002**: A viewer looking for the wishes matching one specific floor finds them in under 10
  seconds from opening the screen, compared with reading the full list today.
- **SC-003**: 100% of rows shown under a given selection match it on every filter that is set, and
  100% of active wishes matching that selection are shown — no row is wrongly hidden or wrongly kept.
- **SC-004**: A viewer can reduce the list to the people an exact two-way swap would suit — looking
  for their floor, and currently on the floor they want — in at most two interactions.
- **SC-005**: Applying, changing, and clearing either filter each update the list within the same
  responsiveness the screen already delivers, with no perceptible delay added for lists of up to 500
  wishes.
- **SC-006**: A viewer part-way down the screen can try five floors in a row without scrolling back to
  the list once: their position on the page is the same after each change as it was before it.
- **SC-007**: A viewer who lands on a filtered view can return to the full list in at most two
  interactions, with no reload or address editing required.
- **SC-008**: The screen remains fully operable by keyboard alone, and every state of the filtered
  list — including the empty result — is announced meaningfully to assistive technology.

## Assumptions

- The filters narrow the existing wish list only; they do not add, reorder, or reveal any wish that
  the screen does not already show. Wishes belonging to people with an exchange in progress stay
  excluded, as they are today.
- The two filters combine by intersection: a row must match every filter that is set. An "either/or"
  combination is out of scope.
- Floors are free text as recorded today; this feature introduces no validated set of floors and no
  normalisation. Two differently-written values are two distinct floors.
- Matching is exact against the recorded floor value. Partial, fuzzy, or case-insensitive matching is
  out of scope.
- Choices are offered as selectable lists derived from all active wishes, rather than free text boxes,
  so a viewer cannot filter on a floor that nobody is on and cannot mistype one.
- Only one floor may be selected per filter at a time. Selecting several floors within one filter is
  out of scope.
- The "current floor" filter offers only real floors. Grouping people with no saved floor under an
  explicit "not set" choice is out of scope; those rows are reached by leaving that filter on "all
  floors".
- The selections live in the page address and nowhere else. They therefore survive moving around
  within the feature — including saving or cancelling one's own wish — but are not stored against the
  account: opening the screen afresh from the navigation shows every wish.
- The viewer's own wish is subject to the filters like anyone else's; it is not pinned into view.
- Sorting remains oldest declaration first, unchanged. Sorting controls are out of scope.
- Filtering is a read-only, per-viewer action; it changes nothing for any other user and records
  nothing.
- The existing swap proposal flow, wish declaration flow, and their messages are unchanged by this
  feature.
