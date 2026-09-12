# Feature Specification: Locker and Floor Profile

**Feature Branch**: `002-locker-floor-profile`

**Created**: 2026-09-12

**Status**: Shipped

**Input**: User description: "Une fois logué, mon numéro de casier et mon étage doivent être affichés. Si c'est pas déjà rempli, la homepage doit me proposer de les saisir, sépare l'étage du numéro de casier. Il est tout à fait possible de ne pas avoir de cabsier attribué dans tous les cas, je dois remplir mon étage."

## Clarifications

### Session 2026-09-12

- Q: Should two different users be able to self-report the same locker number at the same time, or must each locker number be claimed by only one user? → A: Enforce uniqueness — each locker number can be saved by at most one user at a time; a second user trying to claim it is rejected.
- Q: Should the floor value be restricted to a predefined list of valid floors for the building, or can a user type any free-form value? → A: Free-form value — no predefined list to validate against, only "must not be blank" is enforced.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See my locker and floor on the homepage (Priority: P1)

A logged-in user with a floor (and, where applicable, a locker number) already on file visits the homepage and immediately sees that information displayed, without having to look it up elsewhere.

**Why this priority**: This is the core value of the feature — surfacing information the user already provided so they don't have to remember or re-enter it every visit.

**Independent Test**: Can be fully tested by logging in as a user who already has a floor saved (with or without a locker number) and confirming the homepage displays the floor, and the locker number when present, without any additional action.

**Acceptance Scenarios**:

1. **Given** a logged-in user has both a floor and a locker number saved, **When** they land on the homepage, **Then** both values are displayed.
2. **Given** a logged-in user has a floor saved but no locker number (none assigned), **When** they land on the homepage, **Then** their floor is displayed and the homepage clearly indicates they have no locker assigned, without treating this as an error.

---

### User Story 2 - Fill in my floor and locker number from the homepage (Priority: P1)

A logged-in user who has not yet recorded their floor is offered, directly on the homepage, a way to enter their floor and, separately, their locker number, so the information required by the rest of the site is captured as early as possible.

**Why this priority**: Without a way to capture this information, User Story 1 can never be satisfied — this is the entry point that populates the data being displayed.

**Independent Test**: Can be fully tested by logging in as a user with no floor on file, confirming the homepage prompts for it with the floor and locker number as two distinct fields, submitting a floor value (with or without a locker number), and confirming the homepage subsequently displays the saved value(s) instead of the prompt.

**Acceptance Scenarios**:

1. **Given** a logged-in user has not yet saved a floor, **When** they land on the homepage, **Then** the homepage presents a way to enter a floor and a way to enter a locker number as two separate, independent inputs (not a single combined field).
2. **Given** a logged-in user is filling in this information, **When** they submit a floor value without providing a locker number, **Then** the submission succeeds and the floor is saved with no locker number recorded.
3. **Given** a logged-in user is filling in this information, **When** they attempt to submit without providing a floor value, **Then** the submission is rejected and the user is told the floor is required.
4. **Given** a logged-in user submits a locker number that is already saved against a different user's account, **When** they submit, **Then** the submission is rejected, the user is told that locker number is not available, and no other user's identity is disclosed.

---

### User Story 3 - Update my floor or locker number later (Priority: P2)

A logged-in user who already has a floor and/or locker number on file can go back and change either value independently, since a locker assignment or a user's floor can change over time.

**Why this priority**: Improves accuracy over time but isn't required for the initial capture-and-display value delivered by User Story 1 and User Story 2.

**Independent Test**: Can be fully tested by logging in as a user with an existing floor and locker number, changing one of the two values, and confirming the homepage reflects the update while the other value is left untouched.

**Acceptance Scenarios**:

1. **Given** a logged-in user already has a floor saved, **When** they update their floor to a new value, **Then** the homepage subsequently displays the new floor.
2. **Given** a logged-in user already has a locker number saved, **When** they clear it (e.g., their locker was reassigned away from them), **Then** the homepage subsequently shows them as having no locker assigned, and their floor remains unchanged.

---

### Edge Cases

- What happens when a user has a locker number on file but no floor (e.g., pre-existing data)? The floor is still mandatory, so the homepage MUST still prompt for the floor even though the locker number is already known.
- How does the homepage distinguish "no locker assigned" from "not yet asked"? Once a user has provided a floor at least once, an empty locker number MUST always be presented as "no locker assigned," never as an outstanding prompt to fill it in as if it were required.
- What happens if a user submits a floor value that is blank or only whitespace? The system MUST treat it as missing and reject the submission, per User Story 2's mandatory-floor rule.
- What happens when a user tries to save a locker number that is already saved against a different user's account? The submission MUST be rejected and the user MUST be told that locker number is unavailable, without disclosing which other user holds it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST allow a logged-in user to record their floor.
- **FR-002**: The system MUST allow a logged-in user to record their locker number, independently of the floor, and MUST treat the locker number as optional since a user is not guaranteed to have a locker assigned.
- **FR-003**: The homepage MUST display the logged-in user's floor whenever it has been saved.
- **FR-004**: The homepage MUST display the logged-in user's locker number whenever it has been saved, and MUST clearly indicate "no locker assigned" when it has not, without ever presenting the missing locker number as an error.
- **FR-005**: When a logged-in user has not yet saved a floor, the homepage MUST present a way to enter it.
- **FR-006**: The homepage MUST present the floor input and the locker number input as two separate, independently submittable fields, never combined into a single field or value.
- **FR-007**: The system MUST reject an attempt to save a missing or blank floor value and MUST inform the user that the floor is required.
- **FR-008**: The system MUST NOT require a locker number in order to save a floor value.
- **FR-009**: The system MUST allow a logged-in user to update a previously saved floor and/or locker number at a later time.
- **FR-010**: The saved floor and locker number MUST persist across sessions, tied to the user's account.
- **FR-011**: The system MUST enforce that a given locker number is saved against at most one user account at a time; an attempt to save a locker number already held by a different user MUST be rejected without disclosing the identity of the current holder.
- **FR-012**: The system MUST accept the floor as a free-form value (no predefined list of valid floors to validate against), enforcing only that it is not blank.

### Key Entities

- **User Locker Profile**: Extends the existing user account with two attributes — `floor` (required once the user has completed this step; a free-form, self-reported value with no predefined list to validate against) and `locker number` (optional; identifies the locker currently assigned to the user, absent when no locker is assigned; unique across all user accounts — at most one user may hold a given locker number at a time). Both attributes belong to exactly one user account and are independent of each other.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of logged-in users who already have a floor saved see it on the homepage immediately upon landing, with no extra action required.
- **SC-002**: 100% of logged-in users who have not yet saved a floor are shown a way to enter it on every homepage visit until they do so.
- **SC-003**: A user with no locker assigned can complete the floor entry step and reach a fully "filled in" homepage state in under 30 seconds, without being blocked or confused by the optional locker number field.
- **SC-004**: Users can distinguish, without confusion, between "no locker assigned" and "floor not yet provided" 100% of the time the two states are shown.
- **SC-005**: At no point do two different user accounts hold the same locker number simultaneously.

## Assumptions

- This feature is only reachable by an authenticated user, building on the existing login flow (see the user-authentication feature) that lands the user on the homepage.
- Users self-report both values; no separate administrative assignment workflow is in scope for this feature.
- When a locker number conflict is rejected, the message tells the user only that the locker number is unavailable, without naming or otherwise identifying the other account that holds it.
- Once saved, a user can return at any time to change their floor or locker number (User Story 3); there is no "locked in after first save" restriction.
