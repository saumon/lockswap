# Feature Specification: Email Confirmation of New Accounts and Password Reset by Email

**Feature Branch**: `034-email-confirmation-password-reset`

**Created**: 2026-09-29

**Status**: Draft

**Input**: User description: "La création d'un compte, le mot de passe oublié (réinitialisation du mot de
passe), doivent êtres validés via un envoi d'email (SMTP). Lorsqu'un utilisateur crée son compte, un email de
confirmation doit-être envoyé. L'email doit contenir le lien d'activation du compte. L'utilisateur ne peut pas
se connecter sans avoir cliqué sur le lien d'activation. Inspire toi des mécaniques du projet
https://github.com/saumon/hitguessr pour la gestion des emails (utilisation de devise mailer, configuration,
etc.)."

## Clarifications

### Session 2026-09-29

- Q: When this feature ships, should existing accounts be treated as already activated, or must their holders
  confirm their email before signing in again? → A: Treat every existing account as activated at release;
  only accounts created afterwards must activate by email.
- Q: If someone who never activated their account completes a password reset from the reset email, should
  that also activate the account? → A: Yes — completing a reset also activates the account, and the user is
  signed in with the new password.
- Q: Should administrators be able to see which accounts are not yet activated, and activate one by hand, from
  the existing admin Users screens? → A: Yes — the admin Users screens show each account's activation status,
  and an administrator can activate an unactivated account by hand (no admin-triggered resend).
- Q: When an account's password changes, should the holder receive an email saying so? → A: Yes — after every
  password change, whether through a reset link or from the account page, telling them to contact an
  administrator if it was not them.
- Q: If an account is in its 15-minute lockout after 5 wrong passwords and its holder completes a password
  reset, should the reset end the lockout immediately? → A: Yes — completing a reset ends the lockout, clears
  the failed-attempt count, and the user is signed in.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Activate a new account from the confirmation email (Priority: P1)

A colleague signs up for LockSwap with their work email address. Instead of landing on the homepage signed
in, as today, they are told that an email has been sent to that address and that they must follow the link
inside it to activate the account. They open the email, follow the activation link, and land on the sign-in
screen with a message saying the account is now active. From then on they sign in normally.

**Why this priority**: This is the core of the request. Without it, anyone can register with any address
they do not own, and the site cannot rely on an account's email address actually reaching its holder.

**Independent Test**: Register with a new address, confirm that exactly one activation email is delivered to
that address, follow its link, then sign in with the chosen password and reach the homepage.

**Acceptance Scenarios**:

1. **Given** a visitor completes the signup form with a valid, allowed email address, **When** the account
   is created, **Then** an activation email is sent to that address and the visitor is shown a message
   telling them to check their inbox — they are not signed in.
2. **Given** a visitor has received the activation email, **When** they follow its link while it is still
   valid, **Then** the account becomes active and they see a message confirming the activation and inviting
   them to sign in.
3. **Given** an account has just been activated, **When** its holder signs in with the correct password,
   **Then** they are signed in and reach the homepage, exactly as any existing account does today.

---

### User Story 2 - Refuse sign-in until the account is activated (Priority: P1)

Someone who registered but never followed the activation link tries to sign in with the right email and
password. They are not let in; they are told the account has not been activated yet and how to get a new
activation email.

**Why this priority**: Explicitly required ("l'utilisateur ne peut pas se connecter sans avoir cliqué sur le
lien d'activation"). Activation without this gate would be decorative.

**Independent Test**: Create an account, do not follow the link, attempt to sign in with correct
credentials, and confirm the attempt is refused with a message pointing to activation.

**Acceptance Scenarios**:

1. **Given** an account that has not been activated, **When** its holder signs in with correct credentials,
   **Then** sign-in is refused and a message states that the account must first be activated from the email
   that was sent, with a way to request a new one.
2. **Given** an account that has not been activated, **When** someone signs in with a wrong password,
   **Then** the response is the existing generic invalid-credentials message — activation status is not
   revealed to someone who does not know the password.
3. **Given** an account that has not been activated, **When** sign-in is refused, **Then** no activation
   email is sent automatically as a side effect of that attempt.

---

### User Story 3 - Reset a forgotten password by email (Priority: P1)

A user has forgotten their password. From the sign-in screen they follow a "Forgot your password?" link,
enter their email address, and are told that if an account exists for that address, an email with
instructions has been sent. The email contains a link to a screen where they choose a new password (entered
twice, as at signup). Once saved, they are signed in with the new password and the old one no longer works.

**Why this priority**: Explicitly required, and LockSwap has no password recovery at all today — a user who
forgets their password currently has no way back into their account without an administrator deleting it.

**Independent Test**: From the sign-in screen, request a reset for an existing active account, follow the
link in the email, set a new password, and confirm that the new password works and the old one is refused.

**Acceptance Scenarios**:

1. **Given** the sign-in screen, **When** a visitor looks for help with a forgotten password, **Then** a
   clearly labelled link leads to a screen asking for their email address.
2. **Given** an address belonging to an existing account, **When** a reset is requested, **Then** an email
   containing a password-reset link is sent to that address, and the screen shows a generic message.
3. **Given** an address belonging to no account, **When** a reset is requested, **Then** no email is sent
   and the screen shows exactly the same generic message as in scenario 2.
4. **Given** a valid reset link, **When** the user enters a new password and its confirmation that match and
   meet the existing password rules, **Then** the password is changed, the user is signed in, and the
   previous password no longer works.
5. **Given** a valid reset link, **When** the new password and its confirmation differ or the password is
   too short, **Then** the change is refused with the same messages the signup form uses, and the link
   remains usable.
6. **Given** a password has just been changed through a reset link, **When** the same link is followed
   again, **Then** it is refused as already used.
7. **Given** a password has just been changed — through a reset link or from the account page — **When**
   the change is saved, **Then** the account's address receives an email saying the password was changed
   and to contact an administrator if they did not do it.

---

### User Story 4 - Request a new activation email (Priority: P2)

A person who registered but lost, never received, or let expire the activation email asks for a new one from
a link on the sign-in screen (and from the refused sign-in message), by entering their email address. A new
activation email arrives, and only that newest link works.

**Why this priority**: Without it, a lost or expired email leaves an account permanently unusable and its
address permanently taken — the person could not even register again. It is second only because the main
path (US1) works without it for most people.

**Independent Test**: With an unactivated account, request a new activation email, confirm the earlier link
is now refused and the new one activates the account.

**Acceptance Scenarios**:

1. **Given** an unactivated account, **When** its holder requests a new activation email, **Then** a new
   email with a fresh activation link is sent and a generic confirmation message is shown.
2. **Given** a new activation email has been sent, **When** the link from an earlier email is followed,
   **Then** activation is refused, and the newest link still works.
3. **Given** an address that belongs to no account, or to an account that is already active, **When** a new
   activation email is requested, **Then** no email is sent and the screen shows exactly the same generic
   message as in scenario 1.

---

### User Story 5 - Operators configure outgoing email per environment (Priority: P2)

The person deploying LockSwap supplies the outgoing mail server, its credentials, the sender address and the
public address of the site through the deployment's own settings, without changing the application. In
development, with no mail server configured, the application still runs and the emails it would send can be
inspected locally.

**Why this priority**: Every other story depends on emails actually leaving the server, with links that
point at the real site. It is P2 only because it is operator-facing rather than user-facing.

**Independent Test**: Deploy with mail-server settings supplied as environment settings, register an
account, and confirm the email arrives from the configured sender with a link pointing to the configured
public address.

**Acceptance Scenarios**:

1. **Given** mail-server settings are supplied for a deployment, **When** an email is sent, **Then** it
   goes out through that server, from the configured sender address, with links built on the configured
   public address of the site.
2. **Given** a development environment with no mail server configured, **When** an email would be sent,
   **Then** the application does not fail and the email can be inspected locally.
3. **Given** a production deployment whose mail server rejects or cannot be reached, **When** an email is
   sent, **Then** the failure is recorded where the operator can see it — it is not silently dropped.

---

### User Story 6 - Confirm a changed email address (Priority: P3)

A signed-in user changes their email address from their account page. The change does not take effect until
they follow an activation link sent to the new address; until then their account keeps the old address and
the account page says which address is waiting for confirmation.

**Why this priority**: Without it, the guarantee from US1 ("the address on file reaches its holder") could be
bypassed by registering with a real address and then switching to one never verified. It is P3 because it
closes a loophole rather than delivering the requested flow.

**Independent Test**: Change the email on the account page, confirm the old address still signs in, follow
the link sent to the new address, then confirm only the new address signs in.

**Acceptance Scenarios**:

1. **Given** a signed-in user, **When** they save a new email address, **Then** an activation email is sent
   to the new address, the account keeps its current address, and the account page names the address
   awaiting confirmation.
2. **Given** a pending email change, **When** the link sent to the new address is followed, **Then** the new
   address replaces the old one, and the user signs in with it from then on.

---

### User Story 7 - An administrator activates an account by hand (Priority: P3)

A colleague tells facilities they registered but never got the activation email — the mail server was
down, or their inbox filtered it. An administrator opens Admin → Users, sees that the account is marked as
not activated, opens its detail screen and activates it. The colleague can now sign in with the password
they chose.

**Why this priority**: The self-service resend (US4) covers most cases; this is the support path for when
email itself is the problem. P3 because it is only needed when delivery fails.

**Independent Test**: Create an account without activating it, confirm the admin Users list and detail
screen show it as not activated, activate it from the detail screen, and confirm its holder can then sign in.

**Acceptance Scenarios**:

1. **Given** an administrator on Admin → Users, **When** the list includes an account that is not
   activated, **Then** that row states in words that the account is not activated; activated accounts carry
   no extra marking.
2. **Given** an administrator on the detail screen of an unactivated account, **When** they activate it,
   **Then** the account becomes active, the screen confirms it, and shows which administrator activated it
   and when.
3. **Given** the detail screen of an account that is already activated, **When** an administrator views
   it, **Then** no activation control is offered, and the screen shows when (and, if by hand, by whom) it
   was activated.
4. **Given** a standard user, **When** they try to reach the manual activation by any route, **Then** they
   are refused like any other admin-only action.

---

### Edge Cases

- **Expired activation link**: refused with a clear message, and the page offers to send a new activation
  email. The account stays unactivated.
- **Activation link followed twice**: the second visit does not error out or re-activate; it says the
  account is already active and points to sign-in.
- **Malformed or unknown activation or reset link**: refused with a clear message; nothing about any account
  is revealed.
- **Expired reset link**: refused with a clear message, and the page offers to request a new one. The
  password is unchanged.
- **Several reset requests in a row**: only the most recently issued reset link works; earlier ones are
  refused.
- **Repeated resend / reset requests for the same address**: at most one email of each kind is sent to a
  given address every 5 minutes. A request within that window shows the same generic message and sends
  nothing, so the limit is not itself a way to learn whether an account exists.
- **Password reset requested for an unactivated account**: the reset email is sent; completing the reset
  both changes the password and activates the account (following the reset link proves ownership of the
  address as much as the activation link does), and the user is signed in. Any outstanding activation link
  for that account stops working, since there is nothing left to activate.
- **Account temporarily locked after 5 failed sign-ins (001 FR-011)**: completing a password reset ends the
  lockout at once and clears the failed-attempt count, and the user is signed in. Merely *requesting* a
  reset changes nothing — the lockout still runs until the reset is completed or the 15 minutes elapse.
- **Email cannot be delivered at signup** (mail server down): the account is still created and the visitor
  still sees the "check your inbox" message; they can request a new activation email once delivery works.
  The failure is recorded for the operator (US5).
- **Signup with an address from a domain not on the allow-list (016)**: refused exactly as today, and no
  email is sent.
- **The very first account on an empty site** (which becomes the super administrator, 013/029): must be
  activated like any other account before it can sign in.
- **Accounts that already exist when this feature ships**: treated as already activated — nobody currently
  able to sign in is locked out by the release.
- **An administrator activates an account by hand while its holder follows the activation link at the same
  moment**: whichever lands second finds the account already active and reports that, not an error; the
  account is activated once.
- **An administrator activates an account with a pending email change (US6)**: manual activation only
  activates the account's current address; the pending new address still needs its own link.
- **Unactivated account cancelled or never activated**: out of scope for automatic clean-up (see
  Assumptions).
- **Site language changes between sending and reading an email**: the email is written in the site language
  in force when it was sent; the pages its links open follow the language in force when they are opened.

## Requirements *(mandatory)*

### Functional Requirements

**Account activation**

- **FR-001**: The system MUST send an activation email to the address given at signup every time an account
  is successfully created.
- **FR-002**: The activation email MUST contain a link unique to that account which activates it when
  followed.
- **FR-003**: After signing up, the visitor MUST NOT be signed in; they MUST be shown a message telling them
  an activation email has been sent and must be followed before they can sign in.
- **FR-004**: The system MUST record, for every account, whether it has been activated and when.
- **FR-005**: The system MUST refuse sign-in for an unactivated account even when the email and password are
  correct, with a message that the account must first be activated and a way to request a new activation
  email.
- **FR-006**: The "not activated" message MUST only be shown when the password was correct; a wrong password
  MUST produce the existing generic invalid-credentials message regardless of activation status.
- **FR-007**: An activation link MUST be valid for 24 hours from the moment it was issued; after that, it
  MUST be refused.
- **FR-008**: The system MUST show a specific, actionable message for an activation link that is expired,
  already used, or unrecognised — each offering the relevant next step (request a new email, or sign in).
- **FR-009**: A refused sign-in attempt MUST NOT send an activation email by itself.
- **FR-010**: Every account that exists when this feature is released — administrators and standard accounts
  alike — MUST be treated as activated, with no email sent and no action required of its holder. Only
  accounts created after the release go through email activation.

**Resending the activation email**

- **FR-011**: Visitors MUST be able to request a new activation email by entering an email address, from a
  link on the sign-in screen and from the refused-sign-in message.
- **FR-012**: Issuing a new activation email MUST invalidate every activation link previously issued for
  that account; only the newest unexpired link activates it.
- **FR-013**: The response to a resend request MUST be the same generic message whether the address belongs
  to an unactivated account, an active account, or no account at all.

**Password reset**

- **FR-014**: The sign-in screen MUST offer a "forgot your password" link leading to a screen where a visitor
  enters their email address.
- **FR-015**: When a reset is requested for an address belonging to an account, the system MUST send that
  address an email containing a password-reset link.
- **FR-016**: The response to a reset request MUST be the same generic message whether or not the address
  belongs to an account.
- **FR-017**: The reset link MUST open a screen where the user enters a new password twice; the same rules as
  signup apply (minimum length, both entries must match — 001 FR-002, 014).
- **FR-018**: A reset link MUST be valid for 6 hours from issue, MUST work only once, and MUST be invalidated
  when a newer reset link is issued for the same account.
- **FR-019**: After a successful reset, the old password MUST no longer work and the user MUST be signed in
  with the new password. If the account was not yet activated, completing the reset MUST also activate it
  (recording when, as for FR-004).
- **FR-020**: The system MUST show a specific, actionable message for a reset link that is expired, already
  used, or unrecognised, offering to request a new one.
- **FR-039**: After every successful password change — through a reset link or from the account page — the
  system MUST send the account's address a notification that its password was changed, with the time of the
  change and an instruction to contact an administrator if the holder did not make it. The notification MUST
  NOT contain any link that changes the account, nor the password itself. It is not subject to the
  rate limit of FR-023.
- **FR-040**: Completing a password reset MUST end any temporary sign-in lockout on the account (001 FR-011)
  and clear its count of failed attempts, so the user is signed in as FR-019 requires. Requesting a reset
  without completing it MUST NOT affect the lockout.

**Email address change**

- **FR-021**: A change of email address from the account page MUST NOT take effect until the holder follows
  an activation link sent to the new address; until then the old address remains the account's address.
- **FR-022**: While an email change is pending, the account page MUST state which address is awaiting
  confirmation.

**Administrator activation**

- **FR-034**: The admin Users list and the admin user detail screen (020, 027) MUST state, in words, when an
  account is not activated.
- **FR-035**: The admin user detail screen of an unactivated account MUST offer an administrator a control
  to activate it by hand; the control MUST NOT appear for an account that is already activated.
- **FR-036**: A manual activation MUST record which administrator performed it and when, and the detail
  screen MUST show that provenance — the same pattern as 027 FR-009a. If that administrator's account is
  later deleted, the activation stands and the reference is cleared.
- **FR-037**: Manual activation MUST be restricted to administrators (including the super administrator),
  refused for anyone else the same way other admin-only actions are refused.
- **FR-038**: Manual activation MUST NOT send any email, and MUST invalidate any outstanding activation link
  for that account.

**Rate limiting**

- **FR-023**: The system MUST send at most one activation email and at most one reset email to a given
  address in any 5-minute window. A request within the window MUST show the same generic message as any
  other request and send nothing.

**Email content and delivery**

- **FR-024**: Every email MUST be written in the site language (French or English, 025) in force at the time
  it is sent, with each text present in both languages.
- **FR-025**: Every email MUST identify LockSwap as the sender, state plainly why it was sent, and say what
  to do if the recipient did not ask for it. Every email carrying a link (activation, email-change
  confirmation, reset) MUST also say what the link does, give it both as a button and as a plain address
  that can be copied, and state how long it remains valid.
- **FR-026**: Every email MUST be sent in both a formatted and a plain-text version.
- **FR-027**: Links in emails MUST point to the public address of the site configured for the deployment.
- **FR-028**: Sending an email MUST NOT make the signup, resend or reset screen wait on, or fail because of,
  the mail server; the visitor sees the same outcome whether delivery succeeds immediately, later, or not
  at all.
- **FR-029**: The outgoing mail server (address, port, credentials, authentication and encryption options),
  the sender address and the site's public address MUST be configurable per deployment without changing
  the application, each settable either by environment variable or by the application's encrypted
  credentials, the environment variable taking precedence.
- **FR-030**: In development, when no mail server is configured, the application MUST keep working and the
  emails it sends MUST be viewable locally.
- **FR-031**: In production, a delivery failure MUST be recorded where the operator can see it, not dropped
  silently.
- **FR-032**: The system MUST record the sending of each activation and reset email and each successful
  activation and reset, for support purposes, without recording passwords or link tokens.

**Screens**

- **FR-033**: Every new screen (request a reset, choose a new password, request a new activation email,
  activation outcome) MUST follow the existing LockSwap design contract and sign-in/signup screen patterns,
  and meet the same accessibility bar (keyboard operable, labelled fields, messages announced to assistive
  technology).

### Key Entities

- **User account** *(existing)*: gains an activation state — activated or not, and when — and, when it was
  activated by hand, which administrator did it; plus, while an email change is pending, the new address
  awaiting confirmation.
- **Activation link**: a single-purpose, time-limited reference tied to one account (and, for an email
  change, to the new address). Only the most recently issued one for an account is valid; it expires 24
  hours after issue.
- **Password-reset link**: a single-use, time-limited reference tied to one account. Only the most recently
  issued one is valid; it expires 6 hours after issue.
- **Transactional email**: a message sent to one address, of one kind (activation, email-change
  confirmation, password reset, password-changed notification), in the site language at the time of
  sending.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of successful signups trigger exactly one activation email to the address given.
- **SC-002**: With a working mail server, the activation or reset email reaches the recipient's server within
  1 minute of the request in at least 95% of cases.
- **SC-003**: A new user can go from submitting the signup form to being signed in, via the activation email,
  in under 3 minutes.
- **SC-004**: 100% of sign-in attempts with correct credentials on an unactivated account are refused with a
  message pointing to activation; 0% succeed.
- **SC-005**: A user who has forgotten their password can set a new one and be signed in in under 3 minutes,
  without contacting an administrator.
- **SC-006**: For an address with no account, the resend and reset screens are indistinguishable in wording
  from those for an existing account in 100% of cases.
- **SC-007**: 100% of accounts that could sign in before the release can still sign in after it, without any
  action on their part.
- **SC-008**: 100% of email texts and new screen texts are available in both French and English.
- **SC-009**: An administrator can find an unactivated account and activate it by hand in under 1 minute,
  after which its holder can sign in without receiving any email.

## Assumptions

- **Approach carried over from hitguessr** (requested by the user): the mechanics of that project's
  001-account-email-verification feature are the model — 24-hour activation links, only the newest link
  valid, generic anti-enumeration responses, one resend per 5 minutes per address, mail settings read from
  environment variables with the encrypted credentials as fallback, and SMTP only switched on when its
  required settings are present. The same shape is applied to password reset.
- **Reset link validity of 6 hours** matches the value already present in LockSwap's authentication
  configuration.
- **Existing accounts are grandfathered** as activated (FR-010) rather than forced to confirm: every one of
  them was usable yesterday, and locking them out on release would be a breaking change with no benefit.
- **Signup still reveals a taken address** ("email has already been taken"), as it does today; making signup
  itself enumeration-proof is out of scope. The generic responses apply to the resend and reset screens.
- **The temporary lockout after 5 failed sign-ins is otherwise unchanged** (001 FR-011): same threshold, same
  15 minutes; the only new way out of it is completing a reset (FR-040).
- **Administrator tooling is limited to seeing activation status and activating by hand** (US7); an
  administrator cannot trigger an email for someone else, and no filter by activation status is added to the
  Users list. The first account on an empty site activates by email like anyone else — there is no
  administrator yet to do it by hand.
- **No automatic clean-up** of accounts that are never activated; they remain until deleted, and their
  holder can always request a new activation email.
- **The allow-list of email domains (016)** is checked at signup exactly as today, before any email is sent.
- **Email visual design** reuses LockSwap's identity (logo, palette, typography intent) within the limits of
  what email clients render; it is not required to reproduce the web design contract exactly.
- **Delivery is handed to the existing background job system** so that screens never wait on the mail
  server (FR-028).
- A mail-server account for production (host, port, username, password, sender) will be provided by the
  operator; choosing and provisioning it is outside this feature.
