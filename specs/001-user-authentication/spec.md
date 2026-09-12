# Feature Specification: User Signup and Login

**Feature Branch**: `001-user-authentication`

**Created**: 2026-09-12

**Status**: Shipped

**Input**: User description: "Je veux créer un site web sur lequel il est possible de créer de s'inscrire en créant son compte et de se connecter à son compte. Une fois connecté, on doit arriver sur la page d'accueil du site."

## Clarifications

### Session 2026-09-12

- Q: What password rule should the system enforce when someone creates an account? → A: Minimum 8 characters, no other composition rules.
- Q: How long should a user stay logged in before needing to log in again? → A: Session persists up to 30 days across browser restarts, or until the user explicitly logs out.
- Q: Should the system do anything special after several failed login attempts in a row? → A: Temporarily block further login attempts on that account for a short cooldown period after 5 consecutive failures.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create an account (Priority: P1)

A new visitor to the site provides basic information (at minimum an email address and a password) to create a personal account.

**Why this priority**: Without the ability to create an account, no one can ever log in — this is the foundation the rest of the feature depends on.

**Independent Test**: Can be fully tested by having a visitor with no existing account fill in the signup form and submit it, then verifying a new account now exists and can be used to log in.

**Acceptance Scenarios**:

1. **Given** a visitor is on the signup page with no existing account, **When** they submit a valid, unused email address and a password of at least 8 characters, **Then** a new account is created and the visitor is informed of success.
2. **Given** a visitor tries to sign up with an email address that already has an account, **When** they submit the signup form, **Then** the system rejects the submission and clearly tells them the email is already in use, without creating a duplicate account.
3. **Given** a visitor submits the signup form with an invalid email format or a password shorter than 8 characters, **When** they submit, **Then** the system rejects the submission and explains what needs to be corrected.

---

### User Story 2 - Log in and reach the homepage (Priority: P1)

A visitor with an existing account enters their credentials to log in, and upon success is taken directly to the site's homepage.

**Why this priority**: This is the other half of the core value proposition — being able to sign up is only useful if the user can subsequently log back in and reach the site's main content.

**Independent Test**: Can be fully tested by using an already-existing account to submit correct credentials on the login page and confirming the homepage is displayed immediately afterward.

**Acceptance Scenarios**:

1. **Given** a visitor with an existing account is on the login page, **When** they submit their correct email and password, **Then** they are logged in and immediately shown the site's homepage.
2. **Given** a visitor is already logged in, **When** they return to the site (e.g., reload the page, close and reopen the browser, or navigate back to it) within 30 days of their last login, **Then** they remain logged in and can reach the homepage without logging in again.
3. **Given** a logged-in user, **When** they choose to log out, **Then** their session ends and they are no longer able to reach the homepage without logging in again.

---

### User Story 3 - Handle incorrect login attempts (Priority: P2)

A visitor attempts to log in with an email/password combination that doesn't match any account, or that doesn't match the stored password. Repeated failures on the same account temporarily block further attempts.

**Why this priority**: Correct handling of failed logins is necessary for a usable and secure product, but the site is still usable end-to-end (via User Stories 1 and 2) without this refinement in place.

**Independent Test**: Can be fully tested by submitting the login form with an unknown email or a wrong password and confirming the visitor is not logged in and sees a clear, generic error message; and by repeating a wrong password 5 times to confirm the account is temporarily blocked from further attempts.

**Acceptance Scenarios**:

1. **Given** a visitor is on the login page, **When** they submit an email that has no matching account, **Then** the system denies login and shows a generic "incorrect email or password" message, without revealing that the email does not exist.
2. **Given** a visitor is on the login page, **When** they submit a correct email with an incorrect password, **Then** the system denies login and shows the same generic "incorrect email or password" message.
3. **Given** a visitor has submitted an incorrect password for the same account 5 times in a row, **When** they attempt to log in again within the next 15 minutes, **Then** the system denies the attempt and informs them to wait before trying again, even if the correct password is provided.

---

### Edge Cases

- What happens when a visitor who is already logged in navigates directly to the signup or login page? (They should be redirected to the homepage rather than shown the form again.)
- What happens when someone who is not logged in tries to navigate directly to the homepage URL? (They should be redirected to the login page instead of seeing homepage content.)
- What happens when the signup or login form is submitted with empty fields? (The system should reject the submission and indicate which fields are required.)
- What happens if a user's session expires while they are on the homepage? (Their next action requiring authentication should redirect them to the login page.)
- What happens when the 15-minute login cooldown ends after 5 consecutive failed attempts? (The account should accept login attempts normally again, with the failure count reset.)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow a new visitor to create an account by providing an email address and a password.
- **FR-002**: System MUST validate that the submitted email address is in a valid format and that the password is at least 8 characters long before creating the account.
- **FR-003**: System MUST prevent creation of more than one account per email address and MUST inform the visitor when the email address they submitted is already registered.
- **FR-004**: System MUST allow a visitor with an existing account to log in using their email address and password.
- **FR-005**: System MUST redirect a user to the site's homepage immediately upon successful login.
- **FR-006**: System MUST deny login and show a clear, generic error message when the submitted email/password combination does not match a valid account, without indicating whether the email or the password was the incorrect part.
- **FR-007**: System MUST keep a user logged in across page navigation, reloads, and browser restarts for up to 30 days, until they explicitly log out or the 30-day session expires.
- **FR-008**: System MUST prevent access to the homepage for visitors who are not logged in, redirecting them to the login page instead.
- **FR-009**: System MUST allow a logged-in user to log out, which ends their session and requires them to log in again to reach the homepage.
- **FR-010**: System MUST redirect an already-logged-in user away from the signup and login pages to the homepage.
- **FR-011**: System MUST temporarily block further login attempts on an account for 15 minutes after 5 consecutive failed attempts on that account, and MUST inform the visitor that they need to wait before trying again.

### Key Entities

- **Account**: Represents a registered user of the site. Key attributes: unique email address, password (stored securely, minimum 8 characters), account creation date, count of consecutive failed login attempts, cooldown-until timestamp (15 minutes from the 5th consecutive failure, when applicable).
- **Session**: Represents an active logged-in state tied to one account. Key attributes: which account it belongs to, when it started, when it expires (up to 30 days after login) or ends (e.g., via logout).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new visitor can complete account creation in under 2 minutes.
- **SC-002**: A returning user can log in and see the homepage within 10 seconds of submitting correct credentials.
- **SC-003**: 100% of attempts to reach the homepage without being logged in are redirected to the login page instead of showing homepage content.
- **SC-004**: 100% of successful logins with correct credentials result in the homepage being displayed, with no failed redirects.
- **SC-005**: Users submitting an invalid signup (duplicate email, bad format, weak password) receive a specific, actionable message in under 2 seconds, with zero accounts created as a result of the invalid attempt.
- **SC-006**: 100% of accounts with 5 consecutive failed login attempts are blocked from further login attempts for the following 15 minutes, even when the correct password is subsequently provided.

## Assumptions

- Authentication is based on email address and password only; social login, SSO, and OAuth providers are out of scope for this feature.
- No email verification step is required before a newly created account can be used to log in; this may be added as a separate future feature.
- A "forgot password" / password-reset flow is out of scope for this feature and will be specified separately if needed.
- The homepage is a single authenticated landing page shown identically to all logged-in users; per-user personalization of the homepage is out of scope for this feature.
- Users access the site with a standard modern web browser capable of maintaining a session (e.g., via cookies).
- The login cooldown period after 5 consecutive failed attempts is set to 15 minutes; this specific duration was not asked about directly but follows common brute-force mitigation practice and can be adjusted later without changing the feature's behavior model.
