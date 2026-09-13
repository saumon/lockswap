# Feature Specification: Locker Search Wish

**Feature Branch**: `003-locker-search-wish`

**Created**: 2026-09-13

**Status**: Shipped

**Input**: User description: "En tant qu'utilisateur connecté et inscrit, je veux pouvoir déclarer que I'm looking for a locker et à quel étage. On ne peut émettre qu'un seul souhait et on peut émettre un souhait même si on n'a pas de casier affecté. Un utilisateur qui a fait une demande de souhait peut aussi annuler son souhait. Je peux, en tant qu'utilisateur connecté et inscrit, regarder également toutes les personnes qui ont émis un souhait et à quel étage ils cherchent un casier. Pour émettre son souhait, il faut cliquer sur un bouton \"I'm looking for a locker\". Lorsqu'on clique sur ce bouton, le site doit demander à quel étage l'utilisateur cherche un casier."

## Clarifications

### Session 2026-09-13

- Q: When the wish list shows a person who is looking for a locker, what should identify them to other users? → A: Show the user's email address (uses existing data, no schema change).
- Q: Should the wish list also show each person's current floor and locker number (if they have one), alongside the floor they're looking for? → A: Yes — show each person's current floor and locker number (if any) next to the floor they're seeking, so viewers can judge whether a swap is worthwhile.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Declare that I'm looking for a locker on a floor (Priority: P1)

A logged-in, registered user clicks a "I'm looking for a locker" button, is asked which floor they are looking for a locker on, and submits that floor to record their wish — whether or not they currently have a locker assigned to them.

**Why this priority**: This is the core action of the feature — without the ability to declare a wish, there is nothing to display or cancel.

**Independent Test**: Can be fully tested by logging in as a registered user, clicking "I'm looking for a locker", entering a floor, submitting, and confirming the wish is recorded against the user's account — regardless of whether that user has a locker on file.

**Acceptance Scenarios**:

1. **Given** a logged-in, registered user with no active wish, **When** they click "I'm looking for a locker", **Then** the site asks them to specify which floor they are looking for a locker on.
2. **Given** the user has entered a floor and confirms, **When** the submission completes, **Then** a wish is recorded for that user at that floor.
3. **Given** a logged-in user has no locker currently assigned to their account, **When** they declare a wish, **Then** the submission succeeds — having no locker is not a blocker.
4. **Given** a logged-in user already has a locker assigned to their account, **When** they declare a wish for a (different) floor, **Then** the submission succeeds — already having a locker does not prevent wishing for another floor.
5. **Given** a logged-in user attempts to submit the wish without specifying a floor, **When** they submit, **Then** the submission is rejected and the user is told the floor is required.
6. **Given** a logged-in user already has an active wish, **When** they click "I'm looking for a locker" again and submit a new floor, **Then** the system still holds only one wish for that user, now updated to the new floor.

---

### User Story 2 - See who is looking for a locker and where (Priority: P1)

A logged-in, registered user can view a list of everyone who currently has an active wish, along with the floor each of them is looking on and that person's current floor and locker number (if any), so people can find each other and coordinate a locker swap.

**Why this priority**: A recorded wish only creates value once other users can see it — this is what makes User Story 1 useful.

**Independent Test**: Can be fully tested by having one or more users declare wishes, then logging in as any registered user and confirming the list shows each wishing user and their requested floor.

**Acceptance Scenarios**:

1. **Given** at least one user has an active wish, **When** a logged-in, registered user opens the wish list, **Then** they see every user with an active wish along with the floor that user is looking for a locker on, plus that user's current floor and locker number.
2. **Given** no user currently has an active wish, **When** a logged-in, registered user opens the wish list, **Then** the list is shown empty rather than as an error.
3. **Given** the viewing user has their own active wish, **When** they open the list, **Then** their own wish appears in the list alongside everyone else's.
4. **Given** a user with an active wish has no locker currently assigned, **When** their row is shown in the wish list, **Then** it clearly indicates "no locker assigned" for their current locker rather than showing it as missing data or an error.

---

### User Story 3 - Cancel my locker search wish (Priority: P2)

A logged-in, registered user who previously declared a wish can cancel it, since they may find a locker, change their mind, or no longer want to appear in the list.

**Why this priority**: Keeps the wish list accurate over time, but the feature already delivers value through declaring and viewing wishes without it.

**Independent Test**: Can be fully tested by declaring a wish, cancelling it, and confirming it no longer appears in the wish list for any viewer.

**Acceptance Scenarios**:

1. **Given** a logged-in user has an active wish, **When** they cancel it, **Then** the wish is removed and no longer appears in the wish list.
2. **Given** a logged-in user has no active wish, **Then** there is nothing for them to cancel.
3. **Given** a user has cancelled their wish, **When** they click "I'm looking for a locker" again, **Then** they can declare a new wish as if declaring for the first time.

---

### Edge Cases

- What happens when a user without a locker assigned declares a wish? It is accepted — a locker assignment is not a prerequisite for wishing.
- What happens when a user who already has a locker assigned declares a wish anyway? It is accepted — this is the expected way for someone to signal they want to swap to a different floor.
- What happens when a user who already has an active wish declares another one? No second wish is created; the existing wish's floor is updated to the newly submitted floor.
- What happens if the submitted floor is blank or only whitespace? The system MUST treat it as missing and reject the submission.
- What happens when an anonymous (not logged-in) visitor tries to view the wish list or declare a wish? Both actions MUST be unavailable to them; only logged-in, registered users can declare or view wishes.
- What happens when a wishing user has never saved a floor for themselves (no User Locker Profile floor on file)? Their current-floor display in the wish list MUST show as not set, distinct from "no locker assigned," without treating it as an error.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST allow a logged-in, registered user to declare that they are looking for a locker, together with the floor they are looking on.
- **FR-002**: The system MUST allow a user to declare a wish regardless of whether that user currently has a locker assigned.
- **FR-003**: The system MUST enforce at most one active wish per user account at any time.
- **FR-004**: When a user who already has an active wish declares a new one, the system MUST update the existing wish's floor rather than create a second wish for that user.
- **FR-005**: The site MUST present a "I'm looking for a locker" button as the way to start declaring a wish.
- **FR-006**: Clicking the "I'm looking for a locker" button MUST prompt the user to specify which floor they are looking for a locker on.
- **FR-007**: The system MUST reject a wish submission that is missing or has a blank floor value, and MUST inform the user that the floor is required.
- **FR-008**: The system MUST accept the floor as a free-form value, enforcing only that it is not blank, consistent with how floor is handled elsewhere for a user's own profile.
- **FR-009**: The system MUST allow a logged-in, registered user who has an active wish to cancel it.
- **FR-010**: Once a wish is cancelled, it MUST no longer appear in the wish list shown to any viewer.
- **FR-011**: The system MUST allow any logged-in, registered user to view the list of all users who currently have an active wish, along with the floor each is looking on, the wishing user's email address as their identifier, and that user's current floor and locker number (showing "no locker assigned" when the user has none).
- **FR-012**: The wish list MUST reflect the current set of active wishes — newly declared wishes appear, updated wishes show the new floor, and cancelled wishes are removed.
- **FR-013**: Declaring a wish, cancelling a wish, and viewing the wish list MUST all be restricted to logged-in, registered users.

### Key Entities

- **Locker Wish**: Represents one user's declared desire for a locker on a particular floor. Attributes: the owning user (at most one active wish per user, identified to other viewers by that user's email address), and the target floor (free-form, required, not blank). Exists independently of whether the owning user currently has a locker assigned. Removed entirely when the user cancels it; its floor is overwritten in place when the user declares a new wish while one is already active.
- **User Locker Profile** *(existing entity, referenced here)*: Supplies the current floor and locker number (if any) shown next to each entry in the wish list, so viewers can judge whether a swap is worthwhile. This feature reads this data but does not modify it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A logged-in user can go from clicking "I'm looking for a locker" to having their wish recorded in under 30 seconds.
- **SC-002**: 100% of currently active wishes are visible, with the sought floor, the wishing user's email, and that user's current floor/locker (if any), to any logged-in, registered user viewing the wish list.
- **SC-003**: At no point does any user account have more than one active wish recorded.
- **SC-004**: 100% of cancelled wishes stop appearing in the wish list immediately after cancellation.

## Assumptions

- "Connecté" (logged-in) and "inscrit" (registered) refer to the same existing authenticated-user population already used elsewhere in the site (e.g., the locker/floor profile feature); no separate registration check is introduced.
- Declaring a new wish while one is already active updates that existing wish in place (same record, new floor) rather than requiring the user to cancel first — this keeps "at most one wish per user" satisfied with the least friction, mirroring how the site already lets users update their own floor value at any time.
- The floor value for a wish follows the same free-form, non-blank validation rule already used for a user's own floor elsewhere in the site, for consistency.
- There is no automatic expiration or automatic cancellation of a wish (e.g., when the user is later assigned a locker); a wish stays active until the user explicitly cancels it.
- The wish list shows every active wish at once with no pagination or floor filtering required for this feature.
