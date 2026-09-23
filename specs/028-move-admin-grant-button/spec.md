# Feature Specification: Admin Rights Controls on the User Detail Screen

**Feature Branch**: `028-move-admin-grant-button`

**Created**: 2026-09-23

**Status**: Draft

**Input**: User description: "Le bouton \"Accorder les droits admin\" doit être placé dans l'écran \"admin/users/x\" et non directement dans la liste des utilisateurs (écran \"admin/users\"), afin d'alléger l'affichage de la liste des users. Cette action doit rester faisable que par les admins. De plus, depuis l'écran \"admin/users/x\", un admin doit pouvoir révoquer les droits d'amin (sauf sur lui-même)."

## Clarifications

### Session 2026-09-23

- Q: When an administrator's rights are revoked, should the account keep a visible record of who
  revoked them and when, the same way it currently records who granted them? → A: No revoke record is
  kept — reverting to a standard account clears all visible history of the prior grant.
- Q: Now that neither a grant nor a revoke control appears on any row, should the Users list's
  "Actions" column be removed entirely, or kept as an empty column? → A: Remove the Actions column
  entirely — the list has one fewer column than today.
- Q: Should revoking admin rights use the same plain confirmation dialog as granting (name the
  account, no password), or require a stronger step such as re-entering a password? → A: Same plain
  confirmation as grant — no password, dialog names the account.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Grant admin rights from the account detail screen (Priority: P1)

Signed in as an administrator, the person opens an individual account's detail screen (reached from
the Users list). If that account is not yet an administrator, a control to grant it administrator
rights is available there, guarded by the same confirmation the Users list used to offer. The Users
list itself no longer carries this control — it only shows facts about each account.

**Why this priority**: This is the relocation the request asks for. Without it, granting rights is
either still cluttering the list or not possible at all; the capability itself must keep working, just
from its new home.

**Independent Test**: With an administrator account and a standard account registered, open that
account's detail screen, activate the grant control, validate the confirmation, and observe the
account is now marked as an administrator — both on its detail screen and back on the Users list.

**Acceptance Scenarios**:

1. **Given** an administrator is viewing the Users list, **When** they look at any row, **Then** no
   control to grant or revoke administrator rights is present on that row, and the list has no
   "Actions" column at all.
2. **Given** an administrator opens the detail screen of an account that is not an administrator,
   **When** the screen renders, **Then** a control to grant that account administrator rights is
   available on it.
3. **Given** the administrator activates that control, **When** the site responds, **Then** a
   confirmation message is presented that identifies the account and states it will gain
   administrator rights, and no change has been made yet.
4. **Given** the confirmation is validated, **When** the grant completes, **Then** the account's
   detail screen shows it as an administrator, and so does its row back on the Users list.
5. **Given** an account is already an administrator, **When** an administrator opens its detail
   screen, **Then** the grant control is not offered on it.

---

### User Story 2 - Revoke admin rights from the account detail screen (Priority: P1)

Signed in as an administrator, the person opens the detail screen of an account that currently holds
administrator rights, other than their own account. A control to revoke those rights is available
there, guarded by a confirmation naming the account. Once confirmed, the account is no longer an
administrator.

**Why this priority**: This is new capability the current system does not offer at all — until now,
the only way to stop being an administrator was to cancel the account entirely. It is as central to
this feature as the relocation in User Story 1.

**Independent Test**: With two administrator accounts (A and B), sign in as A, open B's detail
screen, activate the revoke control, validate the confirmation, and observe that B's detail screen
and its row on the Users list now show it as a standard account.

**Acceptance Scenarios**:

1. **Given** an administrator opens the detail screen of a different account that is an
   administrator, **When** the screen renders, **Then** a control to revoke that account's
   administrator rights is available on it.
2. **Given** the administrator activates that control, **When** the site responds, **Then** a
   confirmation message is presented that identifies the account and states it will lose
   administrator rights, and no change has been made yet.
3. **Given** the confirmation message is presented, **When** the administrator declines or dismisses
   it, **Then** the account's rights are unchanged.
4. **Given** the confirmation is validated, **When** the revoke completes, **Then** the account's
   detail screen and its row on the Users list both show it as a standard account, with no
   administrator marking.
5. **Given** an account that has just lost administrator rights, **When** that person continues using
   the site (if signed in), **Then** they lose administrator capabilities — the "Admin" navigation
   entry and access to admin screens — from their next request onward, without being signed out.
6. **Given** an account is a standard account (not an administrator), **When** an administrator opens
   its detail screen, **Then** no revoke control is offered on it.

---

### User Story 3 - An administrator cannot revoke their own rights (Priority: P1)

Signed in as an administrator, the person opens their own account's detail screen. No control to
revoke administrator rights is offered there, whether or not they are the only administrator on the
site. Requesting the revoke action directly against their own account, rather than through the
interface, is refused the same way.

**Why this priority**: This is the one safeguard the request calls out explicitly. Without it, an
administrator could strip their own access — and, if they were the only administrator, leave the site
with none — which the rest of the system already treats as a state to prevent.

**Independent Test**: Signed in as an administrator, open your own account's detail screen and
confirm no revoke control is present; separately, request the revoke action directly by its address
against your own account and confirm it is refused with your rights unchanged.

**Acceptance Scenarios**:

1. **Given** an administrator opens their own account's detail screen, **When** the screen renders,
   **Then** no control to revoke administrator rights is offered, even though the account is an
   administrator.
2. **Given** an administrator requests the revoke action directly, naming their own account, **When**
   the request is handled, **Then** it is refused and their administrator rights are unchanged.
3. **Given** an administrator is the only administrator on the site, **When** they view their own
   detail screen, **Then** the same absence of a revoke control applies — there is no special case
   that would let them remove the site's last administrator.

---

### Edge Cases

- What happens if a standard (non-administrator) account requests the grant or revoke action directly
  by its address, rather than through the interface? The request is refused the same way other
  admin-only actions already are, and no account's rights change.
- What happens if the target account is deleted between opening its detail screen and validating a
  grant or revoke confirmation? The action does not take effect, the administrator is told plainly
  that the account no longer exists, and no other account is affected.
- What happens if two administrators grant or revoke rights on the same account at effectively the
  same moment? The account ends up in one consistent state (administrator or not); neither
  administrator is shown a failure, and no duplicate or conflicting state is created.
- What happens if an administrator revokes another administrator's rights while that other
  administrator has the Users list or their own detail screen open? Their view becomes stale until
  refreshed; their next request is treated according to their now-standard status.
- Can revoking rights ever leave the site with zero administrators? No — an administrator can never
  revoke their own rights (User Story 3), so whoever performs a revoke necessarily remains an
  administrator afterwards, and at least one administrator always remains.
- What happens if an account that was granted rights, had them revoked, and is later granted rights
  again? It becomes an administrator again, exactly as any other grant would record it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Users list MUST NOT offer any control to grant or revoke administrator rights on
  any row, and MUST NOT retain an "Actions" column (or equivalent) for that purpose — the column is
  removed from the list, not left empty.
- **FR-002**: The account detail screen MUST offer a control to grant administrator rights when the
  viewed account is not currently an administrator.
- **FR-003**: The account detail screen MUST NOT offer a grant control when the viewed account is
  already an administrator.
- **FR-004**: Activating the grant control MUST present a confirmation identifying the account before
  any change is made, and MUST make no change until that confirmation is validated, matching the
  confirmation behavior the Users list previously provided.
- **FR-005**: The account detail screen MUST offer a control to revoke administrator rights when the
  viewed account currently holds them, except when the viewed account is the signed-in administrator's
  own account.
- **FR-006**: The account detail screen MUST NOT offer a revoke control when the viewed account is not
  currently an administrator, or when the viewed account is the signed-in administrator's own account.
- **FR-007**: Activating the revoke control MUST present a confirmation identifying the account before
  any change is made, and MUST make no change until that confirmation is validated. This confirmation
  MUST NOT require re-entering a password or any other credential, matching the grant confirmation's
  own no-password behavior.
- **FR-008**: Declining or dismissing the revoke confirmation MUST leave the account's rights
  unchanged.
- **FR-009**: Validating the revoke confirmation MUST remove administrator rights from the identified
  account.
- **FR-010**: The system MUST refuse the grant action, and MUST refuse the revoke action, when
  requested by an account that is not an administrator, including when requested directly rather than
  through the interface, and MUST change no account's rights in that case.
- **FR-011**: The system MUST refuse a revoke action requested against the signed-in administrator's
  own account, including when requested directly rather than through the interface, and MUST leave
  their rights unchanged.
- **FR-012**: The system MUST confirm to the administrator that a grant or a revoke took effect, using
  the same status-message pattern the site already uses for other successful actions.
- **FR-013**: The system MUST tell the administrator plainly when a grant or revoke cannot be
  completed (for example because the account no longer exists), without changing any account's
  rights.
- **FR-014**: Revoking rights from an account that is not currently an administrator MUST leave it a
  standard account and MUST NOT be reported to the administrator as a failure.
- **FR-015**: Granting rights to an account that is already an administrator MUST leave it an
  administrator and MUST NOT be reported to the administrator as a failure.
- **FR-016**: Removing administrator rights from an account MUST leave every other account's rights
  unaffected.
- **FR-017**: The Users list and the account detail screen MUST always agree on whether a given
  account is currently an administrator.
- **FR-018**: Revoking rights MUST NOT create or retain any record of who performed the revoke or
  when. Once an account is reverted to standard, neither screen MUST show any trace of its prior
  administrator status or of who last granted it — that record is cleared, not merely hidden, and a
  later grant starts a fresh record.

### Key Entities

- **User account**: Represents a registered person, with a role (standard or administrator). This
  feature adds the ability for the administrator flag to be cleared (revoked) as well as set
  (granted). The existing record of who most recently granted an account rights, and when, is shown
  only while the account remains an administrator; a revoke clears that record rather than
  preserving it (FR-018), so there is no revoke-side history to display.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The Users list shows zero controls for changing administrator rights and carries no
  "Actions" column, across every row listed.
- **SC-002**: An administrator can grant or revoke another account's administrator rights entirely
  from that account's detail screen, in two steps (activate the control, validate the confirmation).
- **SC-003**: 100% of attempts to grant or revoke administrator rights by a non-administrator account,
  made directly rather than through the interface, are refused with no rights changed.
- **SC-004**: 100% of attempts by an administrator to revoke their own rights, whether through the
  interface or directly, are refused, and the site never reaches a state with zero administrators
  through this feature.

## Assumptions

- Revoking rights does not delete or otherwise affect the account itself, its locker, its wishes, or
  its proposal history — it only removes administrator capability, mirroring how granting rights only
  adds it.
- When an account's rights are revoked and later granted again, this is recorded as a new grant (who
  granted it and when), the same as any first-time grant.
- Feature 015's statement that a grant "cannot be undone from within the application" is superseded by
  this feature: it can now be undone, by a revoke, except by the granting or any other administrator
  acting on their own account.
