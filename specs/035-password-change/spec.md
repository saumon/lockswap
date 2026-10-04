# Feature Specification: Change Password from the Account Page

**Feature Branch**: `035-password-change`

**Created**: 2026-10-04

**Status**: Draft

**Input**: User description: "Feature : Changement de mot de passe. Permettre à un utilisateur authentifié de
changer son propre mot de passe depuis son espace personnel. Le formulaire doit demander le mot de passe
actuel, le nouveau mot de passe et sa confirmation, avec afficher/masquer si cela correspond aux conventions
de l'application. Le mot de passe actuel est vérifié ; le nouveau respecte les règles de l'application ; les
autres sessions sont invalidées, la session courante reste active ; une notification est envoyée. En cas de
succès, l'utilisateur comprend immédiatement que le nouveau mot de passe est actif, que les autres sessions
ont été déconnectées et qu'une notification lui a été envoyée. En cas d'échec, ne pas effacer inutilement les
champs déjà correctement renseignés. Cas particuliers : mot de passe actuel incorrect, nouveau mot de passe
non conforme, confirmation différente, soumissions multiples, session expirée, erreur pendant le changement."

## Context: what exists today

This feature reshapes something that partly exists rather than building from nothing. Recorded here so the
requirements below read as changes, not as greenfield:

- The account page ("Paramètres du compte", 001/034) holds **one** form that changes the email address and
  the password together, asking for the current password last, with the hint "leave blank if you don't want
  to change it". It is not obviously a place to change a password.
- **No link in the site menu leads to the account page.** The menu shows the signed-in email address as
  plain text. The page is reachable only from its address.
- The signup and password-reset screens use a show/hide control on every password field (014); the account
  page does not.
- Password rules: 8 to 128 characters, both entries must match (001 FR-002, 014).
- Since 034 (FR-039), every successful password change already emails the account's address a notification
  saying the password was changed and to contact an administrator if it was not them.
- Sign-in sessions can be persistent for 30 days on a device (001 FR-007).

## Clarifications

### Session 2026-10-04

- Q: After 5 consecutive wrong current passwords on the password-change form, what happens? → A: The form
  alone refuses further attempts for 15 minutes; the user stays signed in and the sign-in lockout is not
  affected (FR-008).
- Q: When a submission is refused, what do the password fields keep? → A: Length and match are checked in the
  browser as the user types, so those mistakes never cost a submission; anything the server refuses comes
  back with all three fields empty, never echoing a typed password (FR-015).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Change my password from my account (Priority: P1)

A signed-in colleague wants a new password. From the site menu they open their account page, where a section
titled for exactly that — "Change password" — asks for three things: their current password, the new one,
and the new one again. They fill it in and submit. The page tells them, in one message, that the new password
is now the one to use, that every other device signed in to their account has been signed out, and that an
email confirming the change has been sent to their address. They stay signed in where they are.

**Why this priority**: It is the feature. Everything else in this spec protects or clarifies this path.

**Independent Test**: Sign in, open the account page from the menu, change the password, then confirm the
success message names all three outcomes, the old password is refused at sign-in, the new one works, and the
user is still signed in on the page they used.

**Acceptance Scenarios**:

1. **Given** a signed-in user on any page, **When** they open the site menu, **Then** an entry leads to
   their account page, and that page shows a section whose heading names password change.
2. **Given** the password-change section, **When** the user reads it, **Then** it contains exactly three
   fields — current password, new password, new password confirmation — each labelled, each with a
   show/hide control, and the new-password field states the password rules.
3. **Given** a correct current password and a new password that meets the rules and matches its
   confirmation, **When** the user submits, **Then** the password is changed and a single confirmation
   message states that (a) the new password is now active, (b) other sessions on the account have been
   signed out, and (c) a notification has been sent to the account's email address.
4. **Given** a password has just been changed, **When** the user continues using the site in the same
   browser, **Then** they remain signed in and are not asked for their password again.
5. **Given** a password has just been changed, **When** anyone signs in with the old password, **Then**
   sign-in is refused with the usual invalid-credentials message; the new password succeeds.

---

### User Story 2 - Other devices are signed out (Priority: P1)

The same colleague was also signed in on a shared computer in the meeting room, and on their phone with
"remember me". After changing their password at their desk, both of those are signed out: the next thing
either does sends it to the sign-in screen.

**Why this priority**: The usual reason to change a password is the suspicion that someone else knows it. If
the other sessions survive, the change protects nothing.

**Independent Test**: Sign in to the same account in two separate browsers (one with a persistent session),
change the password in the first, then confirm the second is sent to sign-in on its next request and the
first is not.

**Acceptance Scenarios**:

1. **Given** the account is signed in on another browser, **When** the password is changed from this one,
   **Then** the other browser's next request leads to the sign-in screen with a message asking to sign in.
2. **Given** another browser holds a persistent ("remember me") session, **When** the password is changed,
   **Then** that persistent session no longer signs it in either, even after the browser is restarted.
3. **Given** the password was changed, **When** the browser used to change it makes further requests,
   **Then** it stays signed in, including its own persistent session if it had one.

---

### User Story 3 - Understand and fix a refused change (Priority: P1)

The colleague mistypes. Depending on what went wrong they are told, next to the field concerned, what to do:
the current password is not correct; the new password is too short; the confirmation does not match. Nothing
changes on the account, and they can correct and submit again without starting over.

**Why this priority**: Required explicitly, and a form that refuses without explaining is a form people
abandon — or contact support about.

**Independent Test**: Submit the form once for each failure (wrong current password, too-short new
password, mismatched confirmation) and confirm each gives its own message tied to the right field, the
password is unchanged, and no notification is sent.

**Acceptance Scenarios**:

1. **Given** a wrong current password, **When** the user submits, **Then** the change is refused with a
   message on the current-password field saying it is incorrect, the password is unchanged, no session is
   signed out, and no notification is sent.
2. **Given** a new password that does not meet the rules, **When** the user types it, **Then** a message on
   the new-password field states the rule it breaks before anything is submitted, and what was typed stays
   in place.
3. **Given** a confirmation that differs from the new password, **When** the user types it, **Then** a
   message on the confirmation field says the two do not match before anything is submitted, and what was
   typed stays in place.
6. **Given** the server refuses a submission, **When** the form is shown again, **Then** all three password
   fields are empty and the messages say what to correct.
7. **Given** 5 consecutive wrong current passwords, **When** the user submits again within 15 minutes,
   **Then** the attempt is refused with a message saying how long to wait, without the password being
   checked, and the user is still signed in everywhere else on the site.
4. **Given** several problems at once, **When** the user submits, **Then** every problem is reported at
   once, each on its own field, with a summary at the top of the form listing them.
5. **Given** any refusal, **When** the form is shown again, **Then** focus and the screen-reader
   announcement go to the error summary, so the user knows the submission failed without hunting for it.

---

### User Story 4 - Password change kept apart from email change (Priority: P2)

The account page still lets the colleague change their email address, but in its own section, with its own
current-password check. Changing the password no longer means scrolling past the email field and guessing
which "leave blank" applies to what.

**Why this priority**: Required by "clearly identifiable" and "only the necessary steps". P2 because US1 can
be shipped on a page that still carries the email form, as long as the two are separate forms.

**Independent Test**: On the account page, change the email address without touching any password field,
then change the password without touching the email field; each works on its own and neither form contains
the other's fields.

**Acceptance Scenarios**:

1. **Given** the account page, **When** the user reads it, **Then** email change and password change are
   two separate sections, each with its own submit button, and the password section has no email field.
2. **Given** the user submits the email section, **When** it is saved, **Then** the email-change behaviour
   is exactly as today (034 FR-021/FR-022) and the password is not touched.

---

### Edge Cases

- **Current password incorrect**: refused (US3). The message says only that the current password is
  incorrect — never how close it was, how long the real one is, or anything else about it.
- **Fifth wrong current password in a row**: the form refuses further attempts for 15 minutes (FR-008). The
  user is not signed out and can still sign in elsewhere; the wait applies only to this form. Once it
  elapses, the count starts again from zero.
- **The browser's own checks did not run** (scripting disabled or failed): the server applies every rule
  itself and reports the failures; the fields come back empty, as for any server refusal.
- **New password identical to the current one**: refused, with a message asking for a different password.
  Otherwise the user is told "your password has changed" when nothing did, and every other device is
  signed out for no reason.
- **New password breaks the rules** (fewer than 8 or more than 128 characters): flagged as the user types,
  naming the rule; refused by the server too if submitted anyway.
- **Confirmation empty or different**: refused on the confirmation field; an empty confirmation is never
  treated as "no confirmation required".
- **Any field left empty**: refused, each empty field named. The form never reads an empty new password as
  "keep the current one" — that rule belongs to the old combined form, which this replaces.
- **Form submitted twice** (double click, Enter pressed twice, slow network): the submit button is
  disabled and says the change is in progress from the first submission; only one change is made, only one
  notification is sent, and the user sees one outcome. A submission made after the first one's answer has
  arrived is judged against the new password like any other attempt and cannot undo or repeat the change.
  **Known exception to FR-017**: if the button could not be disabled (scripting unavailable) and two
  submissions are sent before either is answered, the second one carries the sign-in from before the
  change, which the change has just invalidated. That browser may then be sent to sign-in. The password is
  still changed exactly once and one notification is sent; the user signs in again with the new password.
- **The same form open in two tabs**: the second tab's submission is checked against whatever the current
  password is at that moment; if the first tab already changed it, the second is refused as an incorrect
  current password.
- **Session no longer valid when submitting** (signed out elsewhere, persistent session expired, the
  password already changed from another device): nothing is changed and the user lands on the sign-in
  screen with the usual "please sign in" message. After signing in they are returned to the account page.
- **Unexpected failure while saving**: the password stays as it was — never half-changed — no session is
  signed out, no notification is sent, and the user sees a message saying the change could not be made and
  to try again. Technical details are not shown to the user.
- **Notification cannot be delivered** (mail server down): the password change still stands and the success
  message is unchanged; the delivery failure is recorded for the operator as for every other email (034
  FR-031).
- **A password-reset link was requested before the change**: once the password has been changed here, any
  outstanding reset link for the account no longer works, so a link sent before the change cannot be used to
  override it.
- **Account temporarily locked** (5 failed sign-ins, 001 FR-011): a user already signed in on this device
  can still change their password; doing so does not by itself end the lockout for sign-ins elsewhere
  (only a completed reset does, 034 FR-040).
- **Administrator accounts and the super administrator**: change their own password exactly like everyone
  else. No one, administrator included, can change another account's password through this feature.
- **Site language**: every label, hint, error and success message exists in French and English and follows
  the site language (025); the notification follows the language in force when it is sent (034 FR-024).

## Requirements *(mandatory)*

### Functional Requirements

**Reaching it**

- **FR-001**: The site menu MUST offer every signed-in user an entry leading to their own account page, at
  every screen width.
- **FR-002**: The account page MUST present password change as its own section, with a heading naming it,
  separate from the email-change section, with its own submit button.

**The form**

- **FR-003**: The password-change form MUST ask for exactly three values: the current password, the new
  password, and the confirmation of the new password, each with a visible label.
- **FR-004**: Each of the three fields MUST carry the existing show/hide control used on the signup and
  password-reset screens (014), each field toggled independently, each control named for the field it
  reveals. All three fields start hidden.
- **FR-005**: The new-password field MUST state the password rules (minimum length) before the user
  submits.
- **FR-006**: The fields MUST let the browser and password managers recognise the current password as the
  existing one and the two new entries as a new password to save.

**Rules**

- **FR-007**: A change MUST only be applied to the account of the user currently signed in; the form MUST
  NOT accept any value that designates another account.
- **FR-008**: The current password MUST be verified before any change is made; a wrong current password
  MUST refuse the change. After 5 consecutive wrong current passwords, the password-change form MUST refuse
  further attempts for 15 minutes — without checking the password submitted — with a message saying how long
  to wait. The user stays signed in, every other part of the site keeps working, and the sign-in lockout (001
  FR-011) is not affected. A correct current password resets the count.
- **FR-009**: The new password MUST satisfy the application's password rules (8 to 128 characters, 001
  FR-002) and MUST differ from the current password.
- **FR-010**: The confirmation MUST be provided and MUST be identical to the new password.
- **FR-011**: All checks MUST be made together, and every failure reported in one response.

**Feedback**

- **FR-012**: Each refusal MUST be stated in plain language on the field it concerns, with a summary of all
  problems at the top of the form, announced to assistive technology and receiving focus.
- **FR-013**: The wrong-current-password message MUST say only that the current password is incorrect. No
  message, response, page or log MUST reveal anything about the current password (its length, its
  characters, how close a guess was) or echo any password value back to the user in clear text.
- **FR-014**: On success the user MUST see one confirmation message stating that the new password is now
  active, that the account's other sessions have been signed out, and that a notification has been sent to
  the account's email address.
- **FR-015**: The length rule and the match between the two new entries MUST be checked in the browser as
  the user types, and stated next to the field concerned, so these mistakes are caught before submission and
  nothing typed is lost. Whatever the server still refuses (wrong current password, throttle, new password
  equal to the current one, or a browser that did not run the check) MUST come back with all three fields
  empty: no typed password is ever sent back to the page. The server MUST re-check every rule regardless of
  what the browser checked.

**Sessions**

- **FR-016**: After a successful change, every other session on the account — on any device or browser,
  persistent ("remember me") sessions included — MUST be signed out and require the new password to sign
  in again.
- **FR-017**: The session that made the change MUST stay signed in, keeping its persistent session if it had
  one.
- **FR-018**: After a successful change, any outstanding password-reset link for the account MUST stop
  working.
- **FR-019**: If the session is no longer valid when the form is submitted, nothing MUST change and the user
  MUST be sent to sign-in, returning to the account page afterwards.

**Notification**

- **FR-020**: Every successful change MUST send the existing password-changed notification (034 FR-039) to
  the account's email address, exactly once per change. A refused change MUST NOT send it.
- **FR-021**: A failure to deliver the notification MUST NOT undo or block the change, nor alter what the user
  is shown; it MUST be recorded for the operator (034 FR-031).

**Reliability and security**

- **FR-022**: A change MUST be all-or-nothing: either the password is changed, other sessions are signed out
  and the notification is queued, or none of these happen.
- **FR-023**: While a submission is in progress, the submit button MUST be disabled and say so; repeated
  submissions MUST NOT produce more than one change or more than one notification.
- **FR-024**: An unexpected failure MUST leave the password unchanged and show a message telling the user the
  change could not be made and to try again, with no technical details.
- **FR-025**: The system MUST record each successful password change and each refused attempt (account and
  time, and for a refusal which rule failed) for support purposes, without recording any password value.
- **FR-026**: Password values MUST NOT appear in page addresses, logs, or anywhere other than the form
  submission itself.

**Consistency**

- **FR-027**: The section MUST follow the LockSwap design contract and the existing form patterns of the
  signup and reset screens, and meet the same accessibility bar (keyboard operable, labelled fields, errors
  tied to their fields and announced).
- **FR-028**: Every text this feature adds MUST exist in French and English.

### Key Entities

- **User account** *(existing)*: its password changes; the change invalidates every sign-in made with the
  previous password except the one that made it.
- **Sign-in session** *(existing)*: a signed-in browser, possibly persistent for 30 days. After a change,
  only the session that made it remains valid.
- **Password-reset link** *(existing, 034)*: any outstanding one stops working when the password is changed.
- **Password-changed notification** *(existing, 034)*: the email sent to the account's address after every
  change.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A signed-in user can go from any page to a completed password change in 4 actions or fewer
  (open menu, open account page, fill the form, submit) and in under 1 minute.
- **SC-002**: After a change, 100% of the account's other sessions, persistent ones included, are refused on
  their next request; the session that made the change is never signed out by it.
- **SC-003**: 100% of successful changes produce exactly one notification email; 0 refused attempts produce
  one.
- **SC-004**: For each of the failure cases listed under Edge Cases, the user sees a message naming the field
  and what to do, and in a usability check at least 9 users out of 10 correct the problem on their next
  attempt.
- **SC-005**: No response, page or log produced by this feature contains a password value or any detail
  about the current password, verified by inspecting every response of the refused and successful paths.
- **SC-006**: In a usability check, at least 9 users out of 10 who read the success message can say, unaided,
  that their new password is active, that other devices were signed out, and that an email was sent.
- **SC-007**: Guessing the current password through this form is limited to 5 attempts every 15 minutes.

## Assumptions

- The "espace personnel" is the existing account page ("Paramètres du compte"); no new page is created. The
  menu entry that leads to it is part of this feature because none exists today.
- The email-change part of the existing form keeps its current behaviour (034 US6) and keeps asking for the
  current password; only its separation from the password change is in scope.
- The notification is the existing password-changed email from 034; its wording is not redesigned here.
- No password strength meter, breach-list check or complexity rule (digits, symbols) is added: the
  application's password rules are the existing length rule, and this feature applies them, it does not
  change them.
- No "sign out other devices" control independent of a password change, and no list of active sessions, is
  in scope.
- Changing another user's password (by an administrator) is out of scope; an administrator who needs to help
  someone uses the existing reset-by-email flow.
- The success message is shown on the account page the user submitted from.
