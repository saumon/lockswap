# Feature Specification: Login Greeting Popup

**Feature Branch**: `036-login-greeting-popup`

**Created**: 2026-10-21

**Status**: Draft

**Input**: User description: "Une popup à la connexion indiquant “coucou”"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Greeting popup after signing in (Priority: P1)

A user signs in with valid credentials. As soon as they land on the page that follows sign-in, a popup appears showing the message "coucou", so they get a friendly acknowledgement that the connection happened.

**Why this priority**: This is the entire feature. Showing the popup on a successful sign-in is the only behavior requested.

**Independent Test**: Sign in with a valid account and confirm a popup reading "coucou" is visible on the page shown right after sign-in.

**Acceptance Scenarios**:

1. **Given** a registered user on the sign-in page, **When** they sign in with valid credentials, **Then** a popup displaying "coucou" appears on the page they land on.
2. **Given** the "coucou" popup is visible, **When** the user does nothing, **Then** it disappears on its own, following the same timing and dismissal behavior as the app's other popup notifications.
3. **Given** the "coucou" popup is visible, **When** the user dismisses it, **Then** it disappears immediately.

---

### User Story 2 - No popup when the user is not freshly signing in (Priority: P2)

The popup is tied to the act of connecting. A user who is already signed in and simply browses, reloads a page or returns to the app with an existing session does not see the popup again.

**Why this priority**: Without this, the popup would become noise on every page view. It refines the main story rather than delivering new value on its own.

**Independent Test**: Sign in, let the popup disappear, then reload the page and navigate elsewhere; confirm "coucou" does not reappear. Also submit a wrong password and confirm no "coucou" popup is shown.

**Acceptance Scenarios**:

1. **Given** a user who has just signed in and seen the popup, **When** they reload the page or navigate to another page, **Then** the "coucou" popup does not appear again.
2. **Given** a user on the sign-in page, **When** they submit invalid credentials, **Then** no "coucou" popup is shown (only the usual error feedback).

---

### Edge Cases

- What happens when the user's sign-in also produces the existing "Signed in successfully." confirmation? Both messages must remain readable and neither may hide the other.
- What happens when sign-in leads to a different landing page (for example, a page the user was trying to reach before being asked to sign in)? The popup still appears on whichever page they land on.
- What happens when the user's interface language is French or English? The text remains "coucou" in both languages.
- What happens when a user signs in from a second browser or device? Each fresh sign-in shows the popup once on that device.
- How is the popup announced to assistive technology? It must be announced the same way as the app's other popup notifications.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a popup containing the text "coucou" to a user immediately after each successful sign-in.
- **FR-002**: The popup MUST appear on the page the user lands on after signing in, whatever that page is.
- **FR-003**: The popup MUST appear exactly once per sign-in and MUST NOT reappear on page reloads or subsequent navigation within the same session.
- **FR-004**: System MUST NOT display the popup when sign-in fails or when the user is not signing in (already-authenticated browsing, sign-up, password reset).
- **FR-005**: The popup MUST disappear automatically and be manually dismissible, consistent with the behavior of the app's existing popup notifications.
- **FR-006**: The popup MUST be visually and behaviorally consistent with the app's existing popup notifications, and MUST coexist with the existing sign-in confirmation message without either hiding the other.
- **FR-007**: The popup text MUST read "coucou" regardless of the interface language.

### Key Entities

None. The feature introduces no new stored data; it reacts to the sign-in event.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of successful sign-ins show the "coucou" popup on the landing page.
- **SC-002**: 0% of failed sign-ins, page reloads or in-session navigations show the popup.
- **SC-003**: The popup is visible within 1 second of the landing page appearing and is readable for the same duration as other popup notifications.
- **SC-004**: The existing sign-in confirmation message remains visible and readable in 100% of successful sign-ins.

## Assumptions

- "Popup" means the app's existing auto-dismissing popup notification (feature 007), not a modal dialog that blocks the page.
- "À la connexion" means a successful sign-in with email and password, not the sign-in page loading.
- The text is the literal word "coucou" in lowercase, with no translation and no personalization with the user's name.
- Sign-up, email confirmation and password reset flows are out of scope.
- The popup is shown to every user, regardless of role.
