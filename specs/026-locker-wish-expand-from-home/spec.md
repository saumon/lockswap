# Feature Specification: Open the locker search on arrival from the homepage

**Feature Branch**: `026-locker-wish-expand-from-home`

**Created**: 2026-09-21

**Status**: Draft

**Input**: User description: "Depuis l'accueil, lorsqu'on clique sur "Je veux un casier !" ou "Je veux changer de casier !", dans l'écran locker_wishes la zone "Je recherche un casier" doit être dépliée et le focus doit être positionné sur le champ de saisie "Étage". Par contre, si on passe par le menu directement pour aller sur la page locker_wishes, la zone "Je recherche un casier" ne doit pas être dépliée comme c'est le cas actuellement."

## Overview

The homepage invites someone who has not yet said what they are looking for to
do so, with one of two buttons: "I want a locker!" (no locker on file) or "I
want to change lockers!" (a locker on file, nothing declared). Both send the
person to the locker wishes screen — where the form they were promised is
folded away behind a "I am looking for a locker" summary, and they have to ask
for it a second time.

This feature closes that gap: an arrival that came from one of those two
invitations lands with the search zone already open and the cursor in the Floor
field, so the one thing the person set out to do is the one thing in front of
them. An arrival from the menu is not a declared intention to search — it is a
request to see the list — and keeps the zone folded, exactly as it is today.

## Clarifications

### Session 2026-09-21

- Q: When someone arrives from a homepage invitation and then reloads the page or comes back to it with the browser's Back button, should the search zone still be open with the cursor in the Floor field? → A: Opens once, then forgotten — the intention belongs to a single arrival and is spent by it; the address is not changed by it, so a reload or a Back navigation shows the same folded screen the menu gives.
- Q: On a phone, placing the cursor in the Floor field raises the on-screen keyboard, which covers a large part of the screen. Should the cursor still be placed there on a touch device? → A: Yes — one rule at every width. The zone opens and the Floor field takes focus on phone and desktop alike; the keyboard appearing is what the person asked for by pressing the invitation.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Arriving from the homepage invitation (Priority: P1)

Someone with no locker (or with a locker but no declared search) is on the
homepage and presses the invitation to search. They arrive on the locker wishes
screen with the "I am looking for a locker" zone already unfolded, the Floor
field in front of them and the cursor already in it. They type a floor and
submit without touching anything else.

**Why this priority**: This is the whole feature. Everything else in the spec
describes what must *not* change around it.

**Independent Test**: Log in as a user with no locker wish, open the homepage,
press the invitation button, and check on the locker wishes screen that the
search zone is unfolded and the Floor field holds focus. Delivers the complete
value on its own.

**Acceptance Scenarios**:

1. **Given** a signed-in person with no locker on file and no declared search,
   **When** they press "I want a locker!" on the homepage,
   **Then** the locker wishes screen opens with the "I am looking for a locker"
   zone unfolded and keyboard focus in the Floor field.
2. **Given** a signed-in person with a locker on file and no declared search,
   **When** they press "I want to change lockers!" on the homepage,
   **Then** the locker wishes screen opens with the "I am looking for a locker"
   zone unfolded and keyboard focus in the Floor field.
3. **Given** they arrived this way,
   **When** they type a floor and submit without any further navigation,
   **Then** the search is recorded exactly as it would be had they unfolded the
   zone by hand.
4. **Given** they arrived this way,
   **When** they submit a floor the system rejects,
   **Then** the zone is still unfolded and the error is visible, as it is today
   for a rejection after a manual unfold.
5. **Given** they arrived this way and have not submitted anything,
   **When** they reload the page, or leave and return to it with Back,
   **Then** the zone is folded and nothing holds focus — the intention was spent
   by the arrival that used it.

---

### User Story 2 - Arriving from the menu (Priority: P1)

Someone opens the site menu and chooses "Locker searches". They want to see who
is looking for what. The screen opens with the list in front of them and the
"I am looking for a locker" zone folded away, exactly as it is today.

**Why this priority**: Equal to Story 1 and inseparable from it — the feature is
the *difference* between the two entrances. An implementation that opens the
zone for everyone has not delivered this feature, it has removed a distinction.

**Independent Test**: Log in as a user with no locker wish, open the locker
wishes screen from the menu, and check that the search zone is folded and that
nothing on the screen has taken focus away from the top of the page.

**Acceptance Scenarios**:

1. **Given** a signed-in person with no declared search,
   **When** they reach the locker wishes screen from the site menu,
   **Then** the "I am looking for a locker" zone is folded and the Floor field
   does not hold focus.
2. **Given** they reach the screen from the menu,
   **When** they press the "I am looking for a locker" summary,
   **Then** the zone unfolds and behaves exactly as it does today.
3. **Given** a signed-in person with no declared search,
   **When** they reach the locker wishes screen by any route other than the two
   homepage invitations — a typed address, a bookmark, a link from elsewhere in
   the product,
   **Then** the zone is folded.

---

### User Story 3 - The person who already declared a search (Priority: P2)

Someone who has already said what floor they are looking for sees a different
homepage block — "See my locker searches!" — and a different panel on arrival:
their declared search, a way to withdraw it, and a separate "Change floor" zone.
That entrance is unchanged by this feature.

**Why this priority**: A guard rather than a capability. It costs nothing to
state and prevents the feature from spreading to an entrance nobody asked about.

**Independent Test**: Log in as a user who has declared a search, press "See my
locker searches!" on the homepage, and check that the "Change floor" zone is
folded and nothing has taken focus.

**Acceptance Scenarios**:

1. **Given** a signed-in person who has declared a search,
   **When** they press "See my locker searches!" on the homepage,
   **Then** the declared search is shown, the "Change floor" zone is folded, and
   no field holds focus.
2. **Given** a person who declared a search in another tab after loading the
   homepage,
   **When** they press an invitation button that is no longer accurate,
   **Then** the locker wishes screen shows their declared search without error,
   and nothing is unfolded or focused that does not exist on that screen.

---

### Edge Cases

- **Reaching the screen while signed out.** The locker wishes screen requires
  sign-in, and that comes first on every route. Nothing about the folded or
  unfolded state may bypass it, and an intention that does not survive the trip
  through sign-in simply yields the ordinary folded screen.
- **Reloading the arrived-from-home screen.** The intention is spent by the
  arrival that used it. A reload shows the screen folded, with nothing focused —
  the same screen the menu gives. The person's own typing in the Floor field is
  subject to whatever the browser normally does on a reload; this feature neither
  preserves nor clears it.
- **Back and Forward.** Returning to the locker wishes address through browser
  history shows the folded screen. The address is not changed by the intention,
  so the address and the screen cannot disagree — which is the property this
  screen already refuses the page cache to protect (017).
- **Two arrivals in a row.** Going back to the homepage and pressing the
  invitation again is a second arrival, so it opens and focuses again. The
  intention is spent per arrival, not once per session.
- **Someone who folds the zone by hand after arriving.** Their action wins for
  as long as they stay on the screen. The feature decides the state the screen
  opens in; it does not keep re-opening a zone the person closed.
- **A person who reached the screen from the menu and unfolded it by hand.**
  Their unfolded zone must not be folded back by anything this feature adds.
- **Someone using a keyboard or a screen reader.** Focus landing in the Floor
  field must be announced with the field's own label and hint, and the field must
  be scrolled clear of the sticky header rather than sitting behind it.
- **Someone who has asked their system for reduced motion.** Arriving focused
  must not require an animation to be perceivable.
- **Someone arriving on a phone.** The on-screen keyboard rises over the wish
  list. That is accepted: the zone and the Floor field are what this arrival is
  for. The field itself must still be visible above the keyboard, not behind it,
  and dismissing the keyboard must leave the zone unfolded.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The two homepage invitations — "I want a locker!" and "I want to
  change lockers!" — MUST carry an intention to search, distinguishable on
  arrival at the locker wishes screen from any other way of reaching it.
- **FR-002**: That intention MUST belong to a single arrival and be spent by
  it. A later visit to the locker wishes screen that does not itself come from
  an invitation MUST show the folded screen, whether it is a reload, a Back or
  Forward navigation, a bookmark, or a shared link.
- **FR-003**: The intention MUST NOT change the locker wishes address. The
  address a person can copy, bookmark or share after arriving from an invitation
  MUST be indistinguishable from the one the menu produces for the same filter
  state, so the address and the screen can never disagree about what is open.
- **FR-004**: When the locker wishes screen is reached carrying that intention
  and the viewer has no declared search, the "I am looking for a locker" zone
  MUST be unfolded on arrival.
- **FR-005**: In that same case, keyboard focus MUST be placed in the Floor
  field, without the viewer pressing anything further.
- **FR-006**: When the locker wishes screen is reached without that intention —
  the site menu, a typed address, a bookmark, any other link — the "I am looking
  for a locker" zone MUST be folded on arrival and no field may take focus. This
  is the behaviour today and it MUST be preserved.
- **FR-007**: The unfolded zone MUST be the same zone, with the same summary,
  the same field, the same hint and the same submit control as the one reached
  by pressing the summary by hand. This feature adds no second form and no
  second treatment of the same form.
- **FR-008**: A viewer who already has a declared search MUST see the screen
  unchanged by this feature: their search, the withdraw control, and a folded
  "Change floor" zone, with nothing focused. The homepage block that serves them
  ("See my locker searches!") MUST NOT carry the intention.
- **FR-009**: The viewer MUST remain able to fold and unfold the zone themselves
  after arrival, by pointer and by keyboard, with no state this feature
  introduces overriding that.
- **FR-010**: A rejected submission MUST continue to leave the zone unfolded and
  the error visible, whichever entrance the viewer came through.
- **FR-011**: The address of the locker wishes screen MUST continue to describe
  what the screen shows, including the floor filters already carried there (017,
  019). Nothing this feature adds may change which wishes are listed, which
  filters are in force, or what the filter controls offer.
- **FR-012**: Reaching the screen with the intention MUST NOT create, modify or
  withdraw a locker search. The intention opens a form; only submitting it
  records anything.
- **FR-013**: Every user-facing string this feature introduces, if any, MUST
  exist in both locale files, per the project's i18n rule. The feature is
  expected to introduce none: it changes which existing zone is open, not what
  it says.
- **FR-014**: Placing focus MUST bring the Floor field into view clear of the
  sticky header, and MUST NOT depend on an animation having run.
- **FR-015**: The behaviour MUST be identical at every viewport width. The zone
  unfolds and the Floor field takes focus on a phone exactly as on a desktop;
  there is no narrow-screen exception, and the on-screen keyboard the focus
  raises is an accepted consequence of the invitation the person pressed.

### Key Entities

No new data is stored. The feature concerns how one existing screen opens, and
relies on two things that already exist:

- **Locker wish**: the floor a person says they are looking for. This feature
  reads whether one exists (to know which panel the viewer will see) and never
  writes one.
- **Navigation intention**: whether this arrival came from a homepage
  invitation to search. It describes one arrival, not the person and not the
  address; it is consumed by the arrival that reads it and is never stored
  against the account.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A person who presses a homepage invitation can record the floor
  they are looking for with **zero** interactions between arriving and typing —
  down from two today (open the zone, then place the cursor).
- **SC-002**: 100% of arrivals from the two homepage invitations, for a viewer
  with no declared search, open with the search zone unfolded and the Floor
  field focused — measured at both the wide and the narrow treatment, with the
  same result at each.
- **SC-003**: 100% of arrivals from the site menu, and from every other route,
  open with the search zone folded — measured across both viewer states (locker
  on file or not).
- **SC-004**: A keyboard-only person arriving from a homepage invitation reaches
  the Floor field without pressing Tab, and the field's label and hint are
  announced when focus lands.
- **SC-005**: Reloading, or returning through browser history to, a locker
  wishes screen reached from an invitation gives the folded screen with nothing
  focused — identical to the menu's, and reachable from an address that is
  itself identical to the menu's for the same filter state.
- **SC-006**: The locker wishes screen's existing behaviour is unchanged on
  every other axis: the same wishes are listed, the same filters are offered and
  applied, Back and Forward still reproduce the filters they left, and a
  rejected submission still reports its error in place.

## Assumptions

- **The intention is spent by one arrival** (decided in Clarifications, not
  assumed). It is not written into the address: the locker wishes address stays
  exactly what it is today, so a bookmark, a shared link, a reload and a Back
  navigation all give the ordinary folded screen. What remains for planning is
  which single-arrival mechanism carries it; the spec constrains only that it be
  invisible in the address and consumed on use.
- **Scope is the two named invitations.** "See my locker searches!" — the
  homepage block for someone who has already declared a search — is out of
  scope, and the "Change floor" zone is never opened by this feature. The user's
  description named two buttons; this spec adds no third.
- **The folded default stays the default.** The zone is folded today for every
  arrival, and remains so for every arrival that does not carry the intention.
  This feature narrows an exception into existence; it does not invert a default.
- **No new copy.** The summary, label, hint and submit text are the ones already
  on screen, so no new locale entries are expected. If implementation proves
  otherwise, the i18n gate applies as normal.
- **Both viewer states reach the same zone.** Someone with a locker and someone
  without both see the "I am looking for a locker" zone when they have no
  declared search — the homepage only varies which invitation it shows them —
  so one behaviour covers both buttons.
- **Signed-in only.** The locker wishes screen already requires sign-in; this
  feature inherits that and does not widen it.
- **One behaviour at every width** (decided in Clarifications). No
  media-query-dependent exception is introduced, which also keeps the project's
  single-breakpoint rule out of this feature's way entirely.
