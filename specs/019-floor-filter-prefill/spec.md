# Feature Specification: Pre-fill "Their floor" filter from the viewer's wish

**Feature Branch**: `019-floor-filter-prefill`

**Created**: 2026-09-19

**Status**: Shipped

**Input**: User description: "Sur l'écran Locker Wishes, lorsqu'on a exprimé un souhait avec le choix d'un étage (zone "Your locker search"), le filtre "Their Floor" doit être pré-rempli avec ce même numéro d'étage, afin de faciliter la recherche des correspondances dans la section "Everyone looking for a locker". En cas de "Cancel Wish", le filtre doit être repositionné sur "All floors". En cas de changement d'étage souhaité, le filtre "Their Floor" doit être actualisé avec la nouvelle valeur."

## Clarifications

### Session 2026-09-19

- Q: Should the "Their floor" filter be re-synced to the viewer's active wish floor every time they
  open or reload the locker wishes screen, or only at the moment they declare, change, or cancel their
  wish? → A: Re-synced on every fresh screen entry (opening the screen from elsewhere, or reloading
  it) to the viewer's active wish floor — or "All floors" if there is no active wish — overriding
  whatever the filter previously showed. Manual filter clicks made while already on the screen still
  apply normally and are not immediately overridden; they hold until the next fresh screen entry or
  the next declare/change/cancel action.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See likely matches right after declaring a wish (Priority: P1)

Someone opens the locker wishes screen and, in the "Your locker search" panel, declares a wish for a
floor they want. Today the "Everyone looking for a locker" list below stays unfiltered, so seeing who
currently holds that floor means manually opening the "Their floor" filter and picking the same floor
by hand. Instead, the moment the wish is saved, the "Their floor" filter is automatically set to that
same floor, so the list is already narrowed to the people who currently hold it — exactly the people
worth approaching about the locker. The same thing happens whenever they come back to the screen later
while that wish is still active — opening it fresh from the navigation, or simply reloading it — so
they never have to re-apply the filter by hand just because they left and came back.

**Why this priority**: This is the entire point of the request: it removes a manual, easy-to-forget
step immediately after the action that makes it relevant, and delivers the whole benefit on its own.

**Independent Test**: With no wish declared and the "Their floor" filter on "All floors", declare a
wish in "Your locker search" for a specific floor, and confirm the "Their floor" filter now shows that
same floor and the "Everyone looking for a locker" list is narrowed accordingly — without touching the
filter directly. Separately, leave the screen and come back (or reload it) while that wish is still
active, and confirm "Their floor" already shows the wish's floor on arrival, again without touching
the filter.

**Acceptance Scenarios**:

1. **Given** the viewer has no active wish and the "Their floor" filter is on "All floors", **When**
   they declare a wish for floor `5` in "Your locker search", **Then** the "Their floor" filter shows
   `5` and the "Everyone looking for a locker" list shows only rows whose current floor is `5`.
2. **Given** the viewer already has an active wish and later changes the floor they are searching for
   (still in "Your locker search") to a different floor, **When** the change is saved, **Then** the
   "Their floor" filter is updated to the new floor, replacing whatever value it held before —
   including a value the viewer had set manually.
3. **Given** the viewer's wish declaration is rejected (for example, no floor chosen), **When** the
   error is shown, **Then** the "Their floor" filter is left exactly as it was; nothing is pre-filled.
4. **Given** the viewer has an active wish for floor `5` and, while on the screen, manually changes
   "Their floor" to a different floor, **When** they view the list right after, **Then** the list
   reflects their manual choice, not floor `5` — a manual choice made during the visit is not
   immediately overridden.
5. **Given** the same viewer as scenario 4, having manually changed "Their floor" away from their
   wish's floor, **When** they leave the screen and come back later, or reload it, **Then** "Their
   Floor" shows floor `5` again — the manual choice does not survive a fresh screen entry.
6. **Given** the viewer has an active wish for floor `5`, **When** they open the locker wishes screen
   fresh (from the navigation) or reload it, without touching any filter, **Then** "Their floor"
   already shows `5` and the list is already narrowed to it.
7. **Given** a floor is pre-filled into "Their floor" for which no one currently holds a locker,
   **When** the list is displayed, **Then** the existing "no wish matches these filters" message is
   shown, exactly as it would be for the same floor chosen manually.
8. **Given** the "Looking for floor" filter (the screen's other existing filter) is set to some value,
   **When** the viewer declares or changes their wish, or opens the screen fresh, **Then** the
   "Looking for floor" filter is left untouched; only "Their floor" reacts to this behavior.

---

### User Story 2 - Filter clears itself when the wish is withdrawn (Priority: P2)

Having declared a wish and seen the "Their floor" filter narrow the list for them, the viewer decides
to cancel their wish. Since the floor they were searching for no longer applies, the "Their floor"
filter is put back to "All floors" at the same time, so they are not left looking at a narrowed list
that no longer corresponds to anything they are searching for — and it stays on "All floors" the next
time they open the screen too, since there is no longer an active wish to derive it from.

**Why this priority**: This closes the loop opened by Story 1 — without it, cancelling a wish would
leave a stale, no-longer-meaningful filter in place. It depends on Story 1 existing but is a distinct,
independently verifiable behavior.

**Independent Test**: With a wish declared and its floor pre-filled into "Their floor", cancel the
wish and confirm "Their floor" returns to "All floors" and the full list is shown again.

**Acceptance Scenarios**:

1. **Given** the viewer has an active wish and "Their floor" is set to that wish's floor, **When**
   the viewer cancels the wish via "Cancel Wish", **Then** the "Their floor" filter is reset to
   "All floors" and the "Everyone looking for a locker" list shows every active wish again.
2. **Given** "Their floor" was already on "All floors" (for example, the viewer had manually cleared
   it before cancelling), **When** the viewer cancels their wish, **Then** the filter simply stays on
   "All floors".
3. **Given** the viewer cancels their wish, **When** the "Looking for floor" filter has a value set,
   **Then** it is left untouched — only "Their floor" is reset.
4. **Given** the viewer cancelled their wish, **When** they later open the locker wishes screen fresh
   or reload it, having no active wish, **Then** "Their floor" still shows "All floors" on arrival.

---

### Edge Cases

- What happens if the viewer opens the locker wishes screen fresh (e.g., from the navigation) while
  already having an active wish from an earlier visit? "Their floor" is set to that wish's floor
  immediately on arrival, the same as if the viewer had just declared it.
- What happens if the viewer manually changes "Their floor" to a different floor while they have an
  active wish, and then simply keeps browsing the same screen (for example changing "Looking for
  floor" too, or paging through results) without leaving? Their manual choice for "Their floor" holds;
  it is not overridden again until they leave and come back (or reload), or until they declare,
  change, or cancel their wish.
- What happens if the viewer declares a wish for a floor, and that same floor is already the value the
  "Their floor" filter is set to? The filter is (re)set to that value; the list is unaffected since it
  already matched.
- What happens if the "Their floor" filter cannot offer the pre-filled floor as a choice (nobody
  currently holds a locker there)? The pre-filled selection still shows in the control and the list
  shows the existing "no wish matches these filters" empty state, consistent with how 017 already
  handles a selection that matches nothing.
- What happens if the viewer bookmarks or shares a page address where they had manually set "Their
  Floor" to a value different from their wish's floor, and later reopens that address while the wish
  is still active? Reopening it is a fresh screen entry, so "Their floor" is set to the active wish's
  floor rather than reproducing the bookmarked value; only the "Looking for floor" portion of a shared
  or bookmarked address is guaranteed to reproduce as saved.
- What happens if the viewer uses the browser's back or forward controls to move between filter states
  they created earlier in the same visit? That is treated as revisiting those in-visit selections, not
  as a fresh screen entry, so it does not by itself force "Their floor" back to the wish's floor.
- What happens to the page address (URL) when the filter is pre-filled, updated, or reset by this
  behavior? It changes the same way a manual selection would, so the resulting filtered view can still
  be reloaded, shared, or reached with the browser's back and forward controls — noting that reloading
  it is itself a fresh screen entry, so "Their floor" specifically is re-derived from the active wish
  at that point rather than always reproducing exactly what the address encoded.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: On every fresh screen entry to the locker wishes screen (opening it from elsewhere, or
  reloading it) where the viewer has an active wish with a floor, the system MUST set the "Their
  Floor" filter to that floor.
- **FR-002**: On every fresh screen entry where the viewer has no active wish, the system MUST set the
  "Their floor" filter to "All floors".
- **FR-003**: When the viewer successfully declares a wish in "Your locker search" with a floor, or
  successfully changes the floor of their already-declared wish, the system MUST immediately set or
  update the "Their floor" filter to that same floor value, without requiring a further fresh screen
  entry.
- **FR-004**: When the viewer cancels their wish via "Cancel Wish", the system MUST immediately reset
  the "Their floor" filter to "All floors", without requiring a further fresh screen entry.
- **FR-005**: The value set by FR-001 through FR-004 MUST narrow the "Everyone looking for a locker"
  list exactly as the same value would if the viewer had chosen it manually in the "Their floor"
  filter.
- **FR-006**: If declaring or changing the wish fails (for example, no floor is chosen), the "Their
  Floor" filter MUST NOT be changed by that failed attempt.
- **FR-007**: The "Looking for floor" filter MUST NOT be changed by any of the behavior in this
  feature — fresh screen entry, declaring, changing, or cancelling a wish; only "Their floor" reacts.
- **FR-008**: Within one continuous visit to the screen (between fresh screen entries), the viewer MAY
  manually change "Their floor" via the filter control; that manual choice MUST apply and MUST remain
  in force for the rest of that visit, until superseded by the viewer declaring, changing, or
  cancelling their wish (FR-003/FR-004) or by the next fresh screen entry (FR-001/FR-002).
- **FR-009**: Moving between filter states created earlier in the same visit using the browser's back
  or forward controls MUST reproduce those in-visit selections and MUST NOT, by itself, be treated as
  a fresh screen entry that forces "Their floor" back to the active wish's floor.
- **FR-010**: Every change to the "Their floor" filter covered by this feature MUST be visible
  immediately, without requiring any further action from the viewer beyond the triggering one (fresh
  entry, declare, change, or cancel).
- **FR-011**: The current "Their floor" value MUST be reflected in the page address the same way a
  manual selection already is, so the currently displayed view can be reloaded or shared as seen —
  noting that reloading such an address is itself a fresh screen entry, so "Their floor" is re-derived
  per FR-001/FR-002 at that point rather than the address alone guaranteeing what is shown.
- **FR-012**: The fresh-screen-entry and declare/change/cancel behavior in this feature MUST be driven
  only by the viewer's own wish; it MUST NOT be triggered or affected by any other person's wish
  activity.
- **FR-013**: A floor set into "Their floor" by this behavior that matches no currently active wish
  MUST result in the existing "no wish matches these filters" state, not an error and not the
  unfiltered list.

### Key Entities *(include if feature involves data)*

- **Locker wish**: the viewer's own existing wish record, declared and edited through "Your locker
  search". This feature reads the floor on that wish at the moment it is declared, changed, or
  cancelled; it does not add, remove, or otherwise alter wish data.
- **"Their floor" filter selection**: the existing per-viewer filter (introduced in
  017-locker-wishes-floor-filter) that narrows "Everyone looking for a locker" by the floor each
  listed person currently occupies. This feature is the only new source that sets this selection
  automatically; it remains otherwise identical to its existing behavior.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After declaring a wish for a floor, a viewer sees "Everyone looking for a locker"
  already narrowed to that floor with zero additional interactions, 100% of the time.
- **SC-002**: After cancelling a wish, the "Their floor" filter shows "All floors" and the full list
  is visible again with zero additional interactions.
- **SC-003**: After changing the floor on an existing wish, the "Their floor" filter reflects the new
  floor within the same save action used to change the wish — no separate step is needed.
- **SC-004**: The number of interactions needed to go from declaring a wish to viewing the people who
  currently hold the wanted floor drops from two (declare, then filter) to one (declare only).
- **SC-005**: A viewer with an active wish who returns to the locker wishes screen later — including
  simply reloading it — sees "Their floor" already set to their wish's floor, with zero additional
  interactions, every time, for as long as that wish stays active.

## Assumptions

- "Their floor" refers to the existing current-floor filter delivered in
  017-locker-wishes-floor-filter; "Your locker search" refers to the existing panel where the viewer
  declares, edits, and cancels their own wish.
- "Fresh screen entry" means arriving at the locker wishes screen from outside it (for example, the
  main navigation) or reloading/refreshing it — as distinct from interacting with controls already on
  the screen (filters, declaring, changing, or cancelling a wish) during one continuous visit. Only a
  fresh screen entry re-derives "Their floor" from the active wish; in-visit interaction does not.
- Moving between filter states created earlier in the same visit via the browser's back/forward
  controls is treated as revisiting those in-visit selections, not as a fresh screen entry.
- The "Looking for floor" filter (the other filter from 017) is out of scope for this feature and is
  never changed by it.
- Floor values are compared and set as exact free text, consistent with existing floor handling (017,
  018); no normalization is introduced.
- Because "Their floor" is re-derived from the active wish on every fresh screen entry, a bookmarked
  or shared address that encodes a manually-chosen "Their floor" value will not reproduce that value
  on reopening if the viewer still has an active wish — it will show the wish's floor instead. This
  is treated as expected behavior, not a defect, given the goal of this feature.
