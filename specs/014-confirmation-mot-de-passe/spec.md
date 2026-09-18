# Feature Specification: Password Confirmation and Visibility Toggle on Signup

**Feature Branch**: `014-confirmation-mot-de-passe`

**Created**: 2026-09-17

**Status**: Shipped

**Input**: User description: "La page d'inscription doit avoir deux champs de saisie pour le mot de passe : mot de passe + vérification du mot de passe. On ne peut pas finaliser l'inscription si le mot de passe et la vérification du mot de passe sont différents. Des yeux doivent permettre de faire apparaître le texte saisi afin de vérifier si la saisie au clavier a bien été faite."

## Clarifications

### Session 2026-09-17

- Q: When should the signup form first display the "passwords don't match" message to the visitor? → A: After the visitor first leaves (blurs) the Confirm password field, then live-updated as either field is edited afterward.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Confirm the password before creating an account (Priority: P1)

A new visitor filling in the signup form must type their chosen password twice: once in a "Password" field and once in a "Confirm password" field. The system only lets them finalize the signup once both entries match exactly.

**Why this priority**: This is the core of the request — it directly prevents users from accidentally creating an account with a typo'd password they can never reproduce, which is the main source of lockout/support friction this feature is meant to remove.

**Independent Test**: Can be fully tested by filling in the signup form with a valid email and two matching passwords and confirming the account is created, versus filling it in with two different passwords and confirming the submission is blocked.

**Acceptance Scenarios**:

1. **Given** a visitor is on the signup page, **When** they enter the same value in the "Password" and "Confirm password" fields along with a valid email, **Then** the signup proceeds normally and the account is created.
2. **Given** a visitor is on the signup page, **When** they enter different values in the "Password" and "Confirm password" fields, **Then** the system prevents the signup from completing and clearly indicates that the two entries do not match.
3. **Given** a visitor has entered mismatched passwords and sees the mismatch message, **When** they correct the "Confirm password" field so it matches the "Password" field, **Then** the mismatch message goes away and the signup can proceed.
4. **Given** a visitor submits the signup form with the "Confirm password" field left empty, **When** they submit, **Then** the system treats this as a mismatch and prevents the signup from completing.
5. **Given** a visitor is actively typing into the "Confirm password" field for the first time and has not yet left the field, **When** their in-progress entry differs from "Password", **Then** no mismatch message is shown yet.
6. **Given** a visitor has left the "Confirm password" field at least once (e.g., by clicking or tabbing away) while its value did not match "Password", **When** they return to either field and continue editing, **Then** the mismatch message updates live (shown or cleared) with each change, without needing to leave the field again.

---

### User Story 2 - Reveal typed password characters to verify correct entry (Priority: P1)

While typing in either the "Password" or "Confirm password" field, a visitor can toggle an "eye" control next to that field to temporarily show the characters they typed in plain text, instead of masked dots/asterisks, so they can visually verify their keyboard input was correct before submitting.

**Why this priority**: This directly addresses the user's stated goal of letting people verify their keystrokes were captured correctly, which reduces mismatched/incorrect password submissions and is called out as essential in the request — it is not a nice-to-have layered on top, it's part of the same core need as User Story 1.

**Independent Test**: Can be fully tested by typing a password into either field, clicking/tapping its eye control, and confirming the field's content becomes readable plain text, then toggling again and confirming it goes back to masked.

**Acceptance Scenarios**:

1. **Given** a visitor has typed a value into the "Password" field, **When** they activate that field's eye control, **Then** the field's content is displayed as plain readable text instead of masked characters.
2. **Given** the "Password" field is currently showing plain text after the eye control was activated, **When** the visitor activates the eye control again, **Then** the field's content returns to being masked.
3. **Given** a visitor has typed a value into the "Confirm password" field, **When** they activate that field's eye control, **Then** only the "Confirm password" field's content is revealed, while the "Password" field's masking state is unaffected.
4. **Given** a visitor reveals a password field's content, **When** they continue typing additional characters, **Then** the newly typed characters remain visible as plain text without needing to reactivate the eye control.

---

### Edge Cases

- What happens when a visitor pastes a value into the "Confirm password" field instead of typing it? (The system still compares it character-for-character against the "Password" field and blocks submission on any mismatch, including whitespace differences.)
- What happens if a visitor reveals the password, then reloads or navigates away and back to the signup page? (The field starts masked again by default; revealed state is not persisted.)
- What happens when the password and confirmation match but the password itself fails other validation rules (e.g., too short)? (The existing password validation error is shown; matching confirmation does not bypass other password requirements.)
- What happens when a visitor uses a screen reader or keyboard-only navigation? (The eye control must be reachable and operable via keyboard, and its current state — shown or hidden — must be announced or otherwise discoverable, not conveyed by icon alone.)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The signup page MUST present two distinct password input fields: "Password" and "Confirm password".
- **FR-002**: The system MUST compare the "Password" and "Confirm password" field values and MUST prevent the signup from being finalized whenever the two values do not match exactly, including when "Confirm password" is left empty.
- **FR-003**: When the "Password" and "Confirm password" values do not match, the system MUST clearly inform the visitor that the two entries do not match, in a way that is distinguishable from other password validation errors (e.g., password too short).
- **FR-004**: The system MUST NOT display the mismatch message while the visitor is still in their first pass typing into the "Confirm password" field; the mismatch check MUST first run when the visitor leaves (blurs) the "Confirm password" field. After that first check has occurred, the system MUST re-evaluate the match live as the visitor edits either field, so that the mismatch message is shown or cleared immediately as it becomes true or false, without requiring the field to be left again.
- **FR-005**: Each of the "Password" and "Confirm password" fields MUST have its own independent visibility toggle control ("eye") that switches that specific field's displayed content between masked (e.g., dots) and plain readable text.
- **FR-006**: Toggling the visibility control for one password field MUST NOT change the masking state of the other password field.
- **FR-007**: The masked/revealed state of a password field MUST persist across further keystrokes in that field until the visitor toggles it again, and MUST reset to masked by default on a fresh page load.
- **FR-008**: The visibility toggle control MUST be operable via keyboard and MUST expose its current state (shown vs. hidden) in a way accessible to assistive technology, not solely through an icon's visual appearance.
- **FR-009**: The system MUST NOT finalize account creation while any password-matching or password-validity error is currently displayed.

### Key Entities

- **Signup Form Password Fields**: Two related input fields on the signup page — "Password" and "Confirm password" — each holding visitor-entered text, each with its own masked/revealed display state, and together subject to an equality check that gates signup completion.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of signup attempts where the password and confirmation fields differ are blocked from creating an account.
- **SC-002**: 100% of signup attempts where the password and confirmation fields match exactly (and pass existing password rules) proceed to account creation.
- **SC-003**: Visitors can verify their typed password by revealing it in under 1 second (a single interaction with the eye control), without needing to retype it.
- **SC-004**: Visitors correcting a mismatched confirmation field see the mismatch message clear within the same interaction session, without needing to resubmit the form to find out it is now correct.
- **SC-005**: Support inquiries or repeat signup attempts caused by mistyped passwords are reduced, as measured by fewer immediate re-signup attempts with the same email following a blocked mismatch.

## Assumptions

- This feature applies to the existing signup page introduced in the user authentication feature (001-user-authentication); no new signup flow is being created.
- Existing password validation rules (e.g., minimum length) established previously remain unchanged and continue to apply in addition to the new match requirement.
- The visibility toggle affects only how the password is displayed to the visitor in their own browser; it does not change how the password is transmitted, stored, or masked in any server-side logging.
- The visibility toggle defaults to masked/hidden when the signup page is first loaded, for privacy in shared or visible screen situations.
- No changes to the login page are in scope for this feature; it applies specifically to the signup/registration form's password fields.
