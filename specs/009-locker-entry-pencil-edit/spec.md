# Feature Specification: Streamlined Locker Entry & Pencil-Icon Edit

**Feature Branch**: `009-locker-entry-pencil-edit`

**Created**: 2026-09-15

**Status**: Shipped

**Input**: User description: "Lorsqu'un utilisateur se connecte pour la 1ère fois, sur l'écran \"Add your locker details\", il peut soit saisir son casier (étage + numéro de casier), soit cliquer sur \"I don't have a locker 😔\". Après avoir saisit l'une ou l'autre des possiblités, l'utilisateur peut modifier cette information en cliquant sur une icône en forme de crayon, et non un menu dépliant \"Edit locker details\" afin d'alléger l'UI."

## Clarifications

### Session 2026-09-15

- Q: On the first-time "Add your locker details" screen, should entering a locker and declaring "I don't have a locker 😔" be two mutually exclusive views, or should both fields always stay visible with the button as an extra shortcut? → A: Toggle between two mutually exclusive views — choosing a path shows only the relevant field(s).
- Q: When editing already-saved locker details via the pencil icon, should the "I don't have a locker 😔" shortcut also be available there, or does the edit form just show the plain floor and locker-number fields? → A: Plain two-field form only — clearing the locker-number field manually achieves the same result, consistent with today's existing edit behavior.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Choose "I have a locker" or "I don't have a locker" on first entry (Priority: P1)

A user who logs in for the first time and has not yet saved any locker details sees the "Add your locker details" screen and can either enter their locker (floor and locker number together) or declare upfront, with a single action, that they don't have a locker — without being shown a locker-number field that doesn't apply to them.

**Why this priority**: This is the core UX simplification requested — it removes the ambiguity of an "optional" field for the large share of users who have no locker at all, and is the very first thing a new user sees.

**Independent Test**: Can be fully tested by logging in as a brand-new user, confirming the "Add your locker details" screen offers both a locker-entry option and an "I don't have a locker 😔" option, exercising each path, and confirming both result in a saved profile appropriate to the choice made.

**Acceptance Scenarios**:

1. **Given** a first-time logged-in user on the "Add your locker details" screen, **When** they choose to enter their locker, **Then** they are able to provide their floor and their locker number.
2. **Given** a first-time logged-in user on the "Add your locker details" screen, **When** they click "I don't have a locker 😔", **Then** they are asked only for their floor (no locker-number field is presented or required), consistent with the floor remaining mandatory in all cases.
3. **Given** a first-time logged-in user has started entering a floor value, **When** they then click "I don't have a locker 😔" instead of also entering a locker number, **Then** their floor entry is preserved and the submission succeeds with no locker number recorded.
4. **Given** a first-time logged-in user completes either path with a valid floor, **When** they submit, **Then** the homepage subsequently shows their saved details instead of the "Add your locker details" screen.

---

### User Story 2 - Edit saved locker details via a pencil icon (Priority: P1)

A logged-in user who has already saved their locker details (via either path in User Story 1) can change their floor and/or locker number later by clicking a pencil icon, instead of having to open a labeled "Edit locker details" dropdown menu, so the homepage stays visually lighter when the user isn't actively editing.

**Why this priority**: Without this change the second half of the requested behavior — decluttering the always-visible "Edit locker details" menu label — is not delivered; it's equally central to the request as User Story 1.

**Independent Test**: Can be fully tested by logging in as a user with existing locker details, confirming no "Edit locker details" text menu is shown, clicking the pencil icon, confirming the same floor/locker-number fields appear pre-filled with the current values, changing a value, and confirming the update is saved.

**Acceptance Scenarios**:

1. **Given** a logged-in user has saved locker details, **When** they view the homepage, **Then** they see a pencil icon (not a text menu labeled "Edit locker details") as the way to edit their details.
2. **Given** a logged-in user clicks the pencil icon, **Then** the floor and locker-number fields appear, pre-filled with their currently saved values, ready to edit.
3. **Given** a logged-in user has opened the edit fields via the pencil icon, **When** they update the floor and/or locker number and submit, **Then** the homepage reflects the updated value(s), matching the existing update behavior for locker details.
4. **Given** a logged-in user who relies on a screen reader, **When** they reach the pencil icon, **Then** its purpose ("Edit locker details") is announced even though no visible text label is shown.

---

### Edge Cases

- What happens if a user clicks "I don't have a locker 😔" and then changes their mind before submitting? They MUST be able to switch back to entering a locker number without losing an already-entered floor value.
- What happens if a user tries to submit the "I don't have a locker 😔" path without providing a floor? The submission MUST be rejected and the user MUST be told the floor is required, same as the existing floor-mandatory rule.
- What happens when a user with no locker assigned opens the pencil-icon edit form? It MUST show the floor field populated and the locker-number field empty, the same as today's edit behavior, not the first-time "choose a path" screen.
- What happens if the pencil icon is activated by mistake or repeatedly? Activating it again (or an equivalent close action) MUST collapse the edit fields back without discarding the currently saved values.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: On the "Add your locker details" screen, the system MUST offer a first-time user two mutually exclusive ways to proceed: entering their locker (floor and locker number), or an explicit "I don't have a locker 😔" action.
- **FR-002**: Choosing to enter a locker MUST require the floor and MUST accept the locker number, consistent with the existing floor-mandatory, locker-number-optional rule.
- **FR-003**: Choosing "I don't have a locker 😔" MUST require only the floor and MUST NOT present or require a locker-number field as part of that path.
- **FR-004**: The "I don't have a locker 😔" action MUST be a distinct, intentional user action, not merely the effect of leaving the locker-number field blank while the field is still shown.
- **FR-005**: A user MUST be able to switch between the two paths before their first submission without losing an already-entered floor value.
- **FR-007**: Once a user has saved locker details (via either path), the homepage MUST offer a pencil (icon-only) control as the way to edit those details, replacing the current text-labeled "Edit locker details" dropdown/disclosure menu.
- **FR-008**: Activating the pencil icon MUST reveal the floor and locker-number fields, pre-filled with the user's currently saved values, without navigating away from the homepage.
- **FR-009**: The pencil icon MUST be operable via keyboard and MUST expose an accessible name (e.g., "Edit locker details") for assistive technology, since it carries no visible text label.
- **FR-010**: The pencil-icon edit control MUST show the standard two-field (floor, locker number) edit form — not the first-time "choose a path" screen from FR-001 — regardless of whether the user currently has a locker number saved.
- **FR-011**: All existing floor-mandatory and locker-number-uniqueness rules MUST continue to apply unchanged, regardless of which entry path or edit control is used to submit them.

### Key Entities

- **User Locker Profile**: The existing floor and locker-number attributes (see the locker-floor-profile feature) are unchanged by this feature. This feature only changes how a user is prompted to provide them for the first time and how they later access the edit control — no new attributes are introduced.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of first-time users who declare "I don't have a locker 😔" are never shown or asked to fill in a locker-number field during that flow.
- **SC-002**: 100% of users with saved locker details see an icon-only edit control on the homepage, with no visible "Edit locker details" text menu present.
- **SC-003**: Users can open the edit fields and begin changing their floor or locker number within a single click/tap on the pencil icon, with no intermediate menu to expand first.
- **SC-004**: 100% of assistive-technology users can determine the purpose of the pencil icon control without relying on visible text.
- **SC-005**: The floor-mandatory rule and the locker-number uniqueness guarantee hold for 100% of submissions made through either new entry path, with zero regressions from the existing behavior.

## Assumptions

- Floor remains mandatory in all cases, including when a user declares "I don't have a locker 😔" — that action only removes the relevance of the locker-number field, per the existing floor-mandatory rule established for this product.
- "I don't have a locker 😔" is a single explicit action (e.g., a button), not a checkbox or toggle; choosing it is equivalent to submitting with no locker number.
- The pencil-icon control replaces only the visual/interactive trigger for editing (an icon instead of a text-labeled dropdown/disclosure); the underlying edit form, its fields, validation, and uniqueness rules are unchanged from the existing locker-floor-profile feature.
- The first-time "choose a path" screen (enter locker vs. "I don't have a locker 😔") is shown only before a user has ever saved locker details; subsequent edits via the pencil icon always show the standard floor/locker-number form.
- This feature is only reachable by an authenticated user, building on the existing login and homepage flow.
- The control that switches back from "I don't have a locker 😔" to entering a locker (Edge Cases, FR-005) is labeled "Actually, I have a locker" — the exact wording is an implementation choice, since the source request only specifies the forward action's copy verbatim.
