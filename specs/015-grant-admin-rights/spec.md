# Feature Specification: Grant Administrator Rights

**Feature Branch**: `015-grant-admin-rights`

**Created**: 2026-09-18

**Status**: Draft

**Input**: User description: "En tant qu'utilisateur administrateur, on doit pouvoir accorder les droits d'admin à un utilisateur standard. Pour cela, il faut cliquer sur un bouton accessible depuis l'écran listant les utilisateurs. Un message de confirmation doit être validé pour finaliser l'opération."

## Clarifications

### Session 2026-09-18

- Q: When an administrator grants rights to a standard account, should both accounts then be
  administrators afterwards, or should the rights transfer to the promoted account? → A: Both remain
  administrators; the number of administrators is not capped.
- Q: Should the system refuse to delete an account when that deletion would leave the site with no
  administrator at all? → A: Yes — refuse it, and tell the person to grant administrator rights to
  another account first.
- Q: Should the system keep a record of who granted administrator rights to whom, and when? → A: Yes
  — recorded on the promoted account itself (which administrator granted them, and the date), shown
  in the Users list. No separate event log.
- Q: Should validating the confirmation require the administrator to re-enter their password, or is
  the confirmation alone enough? → A: The confirmation alone, matching how "Cancel my account" is
  guarded today.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An administrator promotes a standard account (Priority: P1)

Signed in as an administrator, the person opens the Users list they already use to see who is
registered. Next to each account that is not yet an administrator, there is a control to grant that
account administrator rights. Activating it does not change anything on its own: the site first asks
the administrator to confirm, naming the account concerned. Only once that confirmation is validated
does the account become an administrator, and the list reflects it.

**Why this priority**: This is the entire capability being asked for. Without it there is no way to
have a second administrator at all, and the confirmation step is inseparable from it — a one-click
irreversible grant of full access is precisely the thing this story exists to prevent.

**Independent Test**: With an administrator account and at least one standard account registered,
open Admin → Users, activate the grant control on the standard account's row, validate the
confirmation, and observe that the account is now marked as an administrator in the list. This is
verifiable entirely within the Users list, without signing in as the promoted person.

**Acceptance Scenarios**:

1. **Given** an administrator is viewing the Users list with at least one standard account listed,
   **When** they look at that account's row, **Then** a control to grant administrator rights is
   available on it.
2. **Given** the administrator activates that control, **When** the site responds, **Then** a
   confirmation message is presented that identifies the account concerned, states that it will gain
   administrator rights and that this cannot be undone, and no change has been made yet.
3. **Given** the confirmation message is presented, **When** the administrator validates it — with no
   password or other credential asked for — **Then** the account becomes an administrator and the
   Users list shows it carrying the administrator marking.
4. **Given** the account has just been promoted, **When** the administrator looks at the Users list,
   **Then** the grant control is no longer offered on that row, because the account is already an
   administrator.
5. **Given** the promotion succeeded, **When** the administrator returns to the list, **Then** they
   receive a clear confirmation that the grant took effect, in the same style as other status
   messages on the site.
6. **Given** the administrator has just granted rights to another account, **When** they carry on
   using the site, **Then** they are still an administrator themselves, and the Users list shows both
   accounts carrying the administrator marking.
7. **Given** the grant has taken effect, **When** any administrator looks at the promoted account's
   row, **Then** it shows which administrator granted the rights and the date it happened.

---

### User Story 2 - The promoted account gains administrator capability (Priority: P2)

The account that was just granted administrator rights behaves, from that moment on, exactly like
any other administrator: it sees the "Admin" navigation entry, it can open the Users list, and it can
itself grant administrator rights to other standard accounts.

**Why this priority**: The grant is only meaningful if the rights it confers are real and complete.
It is separated from User Story 1 because User Story 1 is demonstrable on its own (the list shows the
new status), while this story is what makes the feature worth shipping.

**Independent Test**: Take an account that an administrator has promoted, sign in as that person, and
confirm the "Admin" entry is present, the Users list opens, and a grant control is offered on the
remaining standard accounts.

**Acceptance Scenarios**:

1. **Given** an account has been granted administrator rights, **When** that person views any
   signed-in page, **Then** the "Admin" navigation entry is present for them.
2. **Given** an account has been granted administrator rights, **When** that person opens the Users
   list, **Then** it opens and shows every registered account, exactly as it does for the original
   administrator.
3. **Given** an account has been granted administrator rights, **When** that person activates the
   grant control on another standard account and validates the confirmation, **Then** that other
   account becomes an administrator too.
4. **Given** an account has been granted administrator rights, **When** the Users list is viewed by
   anyone who can see it, **Then** that account carries the same administrator marking as the
   original administrator — the marking itself does not vary with how the rights were obtained — and
   the list additionally shows that these rights were granted, by whom, and on what date.

---

### User Story 3 - Backing out, and keeping the control out of the wrong hands (Priority: P3)

An administrator who activates the grant control by mistake, or who reconsiders while reading the
confirmation, can decline it and nothing at all happens. Equally, nobody who is not an administrator
can grant administrator rights, whether or not they ever saw the control.

**Why this priority**: These are the safety edges of the same flow rather than new value, but a
confirmation that cannot be declined is not a confirmation, and an access-control action reachable by
a non-administrator would undo the whole point of having roles.

**Independent Test**: Activate the grant control and decline the confirmation, then verify the
account is still a standard account. Separately, signed in as a standard account, attempt the grant
action directly by its address and verify it is refused and no account changes.

**Acceptance Scenarios**:

1. **Given** the confirmation message is presented, **When** the administrator declines or dismisses
   it, **Then** no account's rights change and the Users list is exactly as it was.
2. **Given** a standard (non-administrator) account, **When** that person requests the grant action
   directly by its address rather than through the interface, **Then** the request is refused the
   same way other admin-only requests are refused, and no account's rights change.
3. **Given** an account that is already an administrator, **When** any administrator views its row in
   the Users list, **Then** no grant control is offered on that row.
4. **Given** the confirmation was declined, **When** the administrator activates the grant control
   again, **Then** the confirmation is presented afresh and the grant can still be completed.

---

### Edge Cases

- What happens if two administrators grant rights to the same standard account at effectively the
  same moment? The account ends up an administrator exactly once; neither administrator is shown a
  failure, and no duplicate or conflicting state is created.
- What happens if the target account is deleted (via the existing "Cancel my account" capability)
  between the moment the Users list was displayed and the moment the confirmation is validated? The
  grant does not take effect, the administrator is told plainly that the account no longer exists,
  and no other account is affected.
- What happens if an administrator's own rights were somehow removed while they had the Users list
  open, and they then validate a confirmation? The action is refused at the point it is handled,
  because visibility of the control is never what authorises it.
- What happens if the Users list being viewed is stale and shows as standard an account that has
  since been promoted by another administrator? Validating the confirmation leaves the account an
  administrator (the intended end state) and does not report a failure to the administrator.
- What happens if the person being promoted is signed in at that moment? Their new rights apply from
  their next page view onwards; they are not signed out and do not need to sign in again.
- What happens to the recorded origin when the administrator who granted the rights later cancels
  their own account? The record survives: the promoted account still shows that its rights were
  granted and when, and says that the granting account no longer exists (FR-019).
- What happens when the last remaining administrator tries to cancel their own account (existing
  "Cancel my account" capability), while other accounts are still registered? The deletion is refused
  and they are told to grant administrator rights to another account first (FR-016), so those
  accounts are never left unadministered. This supersedes feature 013's FR-011, whose outcome — a
  site with registered accounts and no administrator — is no longer reachable through the application.
- What happens when the administrator is the only account left on the site? Cancelling is allowed:
  there is nobody left to administer, and the next person to register claims the rights exactly as
  the first one did (013 FR-001). This is the one case FR-016 deliberately lets through.
- What happens when two administrators, the only two on the site, cancel their accounts at
  effectively the same moment? One deletion succeeds and the other is refused; the site is never left
  without an administrator by a race between the two checks.
- What happens when the promoted account tries to reach the parts of the site any signed-in account
  already reaches (lockers, wishes, swaps)? Nothing changes — administrator rights are additive and
  remove no existing capability.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Users list MUST offer, on the row of every account that is not an administrator, a
  control to grant that account administrator rights.
- **FR-002**: The system MUST NOT offer that control on the row of an account that is already an
  administrator.
- **FR-003**: Activating the control MUST present a confirmation message before any change is made,
  and MUST make no change until that confirmation is validated.
- **FR-004**: The confirmation message MUST identify the account concerned (by the same email address
  shown in the list), state that the account will gain administrator rights, and state that the grant
  cannot be undone from within the application (FR-014).
- **FR-005**: The confirmation MUST be declinable, and declining it MUST leave every account's rights
  unchanged.
- **FR-006**: Validating the confirmation MUST grant administrator rights to the identified account.
- **FR-007**: Once granted, the account MUST have exactly the same administrator capabilities as any
  other administrator, including seeing the "Admin" navigation entry, opening the Users list, and
  granting administrator rights to other accounts.
- **FR-008**: The Users list MUST mark the promoted account as an administrator in exactly the same
  way as any other administrator, so nothing suggests its rights are lesser or conditional. Recording
  where the rights came from (FR-018) is a separate fact shown beside that marking and MUST NOT
  change it.
- **FR-009**: The system MUST refuse the grant action when it is requested by an account that is not
  an administrator, including when requested directly by address rather than through the interface,
  and MUST change no account's rights in that case.
- **FR-010**: The system MUST confirm to the administrator that the grant took effect, using the same
  status-message pattern the site already uses for other successful actions.
- **FR-011**: The system MUST tell the administrator plainly when a grant cannot be completed (for
  example because the account no longer exists), without changing any account's rights.
- **FR-012**: Granting administrator rights to an account that is already an administrator MUST leave
  it an administrator and MUST NOT be reported to the administrator as a failure.
- **FR-013**: The system MUST allow any number of administrators to exist at the same time, with no
  cap on how many accounts hold the rights, superseding the single-administrator constraint of
  feature 013. Granting rights MUST NOT remove or alter the granting administrator's own rights.
- **FR-014**: This feature MUST NOT provide any way to remove administrator rights from an account,
  nor to edit or delete an account from the Users list; granting is the only new capability.
- **FR-015**: The grant control and its confirmation MUST be operable by keyboard and carry labels
  that convey, to assistive technology, which account they act on — the control MUST NOT rely on row
  position alone to say what it does.
- **FR-016**: The system MUST refuse to delete an account when that deletion would leave other
  registered accounts with no administrator, and MUST tell the person that they need to grant
  administrator rights to another account first. This holds even when two administrators attempt to
  cancel their accounts at the same moment: at least one of the two deletions MUST be refused.
  Deleting the last remaining account on the site is not refused: nothing is left to administer, and
  the next registration claims the rights again as it did on the first day (013 FR-001).
- **FR-017**: When administrator rights are granted, the system MUST record on the promoted account
  which administrator granted them and the date on which it happened.
- **FR-018**: The Users list MUST show that recorded origin for every account that was granted its
  rights, so an administrator can tell which accounts claimed the rights at first registration and
  which were granted them, and by whom.
- **FR-019**: The recorded origin MUST survive the deletion of the granting account: the fact that
  the rights were granted, and when, MUST still be shown, stating that the granting account no longer
  exists rather than showing nothing.
- **FR-020**: Validating the confirmation MUST NOT require the administrator to re-enter their
  password or any other credential; the confirmation is the only step between activating the control
  and the grant taking effect.

### Key Entities

- **User Account**: a registered person on the site, identified by email address and registration
  order. Whether it is an administrator is now a fact that can be set in two ways — claimed
  automatically by the very first registration (feature 013), or granted afterwards by an existing
  administrator (this feature) — and, once true, is not changed back by anything in this feature.
  An account whose rights were granted also carries the origin of those rights: which administrator
  granted them and on what date. Because rights are granted at most once and never removed, that
  origin is a single fact on the account rather than a history of events.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An administrator can grant administrator rights to a standard account in no more than
  two deliberate actions from the Users list — activating the control and validating the confirmation
  — without leaving the list or consulting documentation.
- **SC-002**: 0% of grants take effect without an explicit confirmation being validated first.
- **SC-003**: 100% of declined confirmations leave every account's rights exactly as they were.
- **SC-004**: 100% of promoted accounts have full administrator capability — navigation entry, Users
  list, and the ability to promote others — from their next page view onwards, with no sign-out or
  manual step.
- **SC-005**: 0% of non-administrator accounts can grant administrator rights, whether through the
  interface or by requesting the action directly.
- **SC-006**: An administrator can tell from the Users list alone, in a single visit, which accounts
  are administrators and which can still be promoted.
- **SC-007**: 0% of sites with registered accounts can reach a state where no account is able to
  administer them, so recovering administrator access never requires reaching into the database by
  hand. A site whose every account has been cancelled is not such a state, since the next
  registration claims the rights again.
- **SC-008**: For 100% of administrator accounts, an administrator can tell from the Users list alone
  whether the rights were claimed at first registration or granted afterwards, and by whom.

## Assumptions

- **Any number of administrators may now exist** (settled in Clarifications, Session 2026-09-18).
  Feature 013 assumed exactly one administrator and stated (FR-009) that the Users list was
  read-only. This feature supersedes both points: the list gains one write action, and administrators
  coexist without limit. Feature 013's own spec.md still carries the superseded wording.
- **Granting only.** The request describes granting rights, so removing them (demotion) is out of
  scope, as is any other editing or deletion of accounts from the Users list. A grant is therefore
  permanent as far as this feature is concerned, and cancelling the account is the only way an
  account stops being an administrator — which is why FR-016 guards the last one.
- **The first administrator keeps its origin.** How the original administrator obtained its rights
  (first registration) is unchanged; this feature adds a second route in, not a replacement.
- **Existing patterns are reused.** The confirmation follows the site's established confirm-before-
  acting pattern (as already used by "Cancel my account"), and the success and failure messages follow
  the existing status-message pattern, rather than introducing new interaction styles. Re-entering a
  password was considered and rejected (Clarifications, Session 2026-09-18): the closest existing
  precedent for an irreversible action is guarded by a confirmation alone.
- **No notification is sent to the promoted person.** They discover their new rights by seeing the
  "Admin" entry; telling them out of band is left to the administrator and is out of scope here.
  Sending one would need mail delivery the application does not have: there is no mailer beyond the
  default, and production SMTP is unconfigured.
- **The origin of granted rights is recorded, but no event log is** (settled in Clarifications,
  Session 2026-09-18). The promoted account carries who granted its rights and when, and the Users
  list shows it. Nothing records declined confirmations, repeated grants, or any other event, so the
  Users list still shows current state — with the addition of where that state came from.
- **The Users list from feature 013 is the only entry point.** No new screen is introduced, and the
  grant capability appears nowhere else in the site.
