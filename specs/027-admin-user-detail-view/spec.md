# Feature Specification: Admin User Detail View

**Feature Branch**: `027-admin-user-detail-view`

**Created**: 2026-09-22

**Status**: Draft

**Input**: User description: "En tant qu'administrateur, depuis l'écran \"admin/users\", on doit pouvoir cliquer sur un utilisateur de la liste. Lorsqu'on clique sur un utilisateur de la liste, on est alors redirigé vers l'écran de visualisation des informations de l'utilisateur cliqué. Cet écran de visualisation des informations utilisateur ne doit être accessible que pour un admin. Sur cet écran de visualisation des informations de l'utilisateur on voit toutes les informations de l'utilisateur, mais aussi sa recherche de casier (s'il a fait une demande de casier ou une demande d'échange de casier), son historique complet de ses propositions. Une icône en forme de crayon doit permettre à l'admin de modifier ces informations : étage actuel, casier affecté. Un bouton permettant d'annuler la recherche de casier de l'utilisateur doit être présent. Ce bouton doit permettre à l'administrateur d'annuler la recherche."

## Clarifications

### Session 2026-09-22

- Q: Should the system record who (which administrator) made a floor/locker edit or cancelled a search on a user's behalf, and when? → A: Record the acting admin and a timestamp for both the floor/locker edit and the search cancellation (new audit fields, surfaced on the detail screen), the same shape of fact already recorded for who granted administrator rights and when.
- Q: Should cancelling a user's locker search from the admin detail screen require a confirmation step, or behave like the existing self-service cancel (single click, no dialog)? → A: Require an explicit confirmation step before the cancellation takes effect, since it acts on another person's account rather than the administrator's own.
- Q: On the Admin → Users list, should the entire row be clickable, or should a distinct link/action within the row open the detail screen? → A: A distinct link/action within the row (e.g. the email, or a "View details" control) is the navigable element, not the row as a whole.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open a registered user's detail screen from the Users list (Priority: P1)

An administrator browsing Admin → Users activates a link within a row — not the row as a whole — and is taken to a dedicated screen showing that one account's full information. Nothing on this screen, or the ability to reach it, is available to a non-administrator, whether they click through the interface or type the address directly.

**Why this priority**: Every other capability in this feature — viewing full details, editing floor/locker, cancelling a search — lives on this screen and has nowhere to exist until it can be reached, and reached only by an administrator.

**Independent Test**: Signed in as the administrator, with at least one other registered account, click that account's row in Admin → Users and confirm the detail screen for that exact account opens. Signed in as a non-administrator, attempt to open the same address directly and confirm the request is refused the same way other admin-only pages are refused.

**Acceptance Scenarios**:

1. **Given** the administrator is viewing Admin → Users with several accounts listed, **When** they activate the detail link on a row, **Then** they are taken to the detail screen for that specific account, not any other.
2. **Given** a non-administrator is signed in, **When** they request the user detail screen's address directly, **Then** the request is refused and no account information is shown.
3. **Given** a signed-out visitor, **When** they request the user detail screen's address directly, **Then** they are redirected to sign in, consistent with how the rest of the site handles unauthenticated access.

---

### User Story 2 - See a user's full profile, locker search and proposal history in one place (Priority: P1)

On the detail screen, the administrator sees everything already visible about that account on the Users list (email, role, current floor, current locker) plus what is not shown there today: whether the account currently has a standing locker-search wish or is party to an active swap proposal, and the complete history of every swap proposal that account has ever sent or received, in any status.

**Why this priority**: This is the core value of the feature — today an administrator must cross-reference the Users list, the locker wishes list, and cannot see proposal history for another account at all. Consolidating it onto one screen is the whole point of making the screen reachable in User Story 1.

**Independent Test**: With an account that has a standing wish, and a second account with a full mix of proposal statuses (pending, accepted, declined, withdrawn, completed) sent and received, open each account's detail screen and confirm every one of those facts is visible without navigating elsewhere.

**Acceptance Scenarios**:

1. **Given** an account has a floor and locker number saved, **When** the administrator opens its detail screen, **Then** both values are shown, matching what the Users list and that account's own homepage show.
2. **Given** an account has declared a standing locker-search wish, **When** the administrator opens its detail screen, **Then** the screen shows that a search is active and which floor it is for.
3. **Given** an account has no standing wish and is not party to any active swap proposal, **When** the administrator opens its detail screen, **Then** the screen clearly shows there is no locker search in progress, rather than leaving the area blank.
4. **Given** an account has sent or received swap proposals in every status (pending, accepted, declined, withdrawn, completed), **When** the administrator opens its detail screen, **Then** every one of those proposals appears in a history list, each identified by direction (sent or received), the other party, when it was sent, its current status, and its outcome details (decline reason, or the floor/locker terms involved), newest first.
5. **Given** an account has never sent or received a proposal, **When** the administrator opens its detail screen, **Then** the history section clearly states there is none, rather than appearing empty or broken.

---

### User Story 3 - Correct a user's current floor and assigned locker (Priority: P2)

From the detail screen, the administrator clicks a pencil icon next to the account's current floor and locker information and is able to change those two values on the account's behalf — for example to correct a mistake the user made, or to record a locker reassignment handled outside the app.

**Why this priority**: A real but secondary need: getting the account's own details corrected in-app, without the administrator needing database access. It depends on User Story 1 for the screen to exist and does not block viewing the rest of the account's information.

**Independent Test**: Open an account's detail screen, activate the pencil icon, change the floor and/or locker number, submit, and confirm the detail screen (and the Users list) now reflects the new values.

**Acceptance Scenarios**:

1. **Given** the administrator is viewing an account's detail screen, **When** they activate the pencil icon next to the floor/locker information, **Then** an editable form appears pre-filled with that account's current floor and locker number.
2. **Given** the administrator has opened the edit form, **When** they submit a new floor and/or locker number, **Then** the account's record is updated and the detail screen reflects the new values immediately.
3. **Given** the administrator submits a locker number already held by another account on the same floor, **When** they submit, **Then** the change is refused with the same explanation a user would see attempting the same conflicting change, and no data is altered.
4. **Given** the administrator submits the edit form with the floor left blank, **When** they submit, **Then** the change is refused, since a floor is required for every account, the same as it is for a user editing their own details.
5. **Given** the account being edited currently has a pending or accepted swap proposal, **When** the administrator attempts to change its floor or locker number, **Then** the change is refused with an explanation that an outstanding proposal must be resolved first, the same restriction that already applies when the account holder edits their own details.

---

### User Story 4 - Cancel a user's locker search on their behalf (Priority: P2)

From the detail screen, when an account has a standing locker-search wish, the administrator sees a button to cancel that search and, on confirmation, the wish is removed — for example at the user's request made outside the app, or because it is no longer valid.

**Why this priority**: A real but secondary administrative capability, useful in support scenarios, that depends on the screen and the search-status display from User Stories 1 and 2 but adds no new information of its own.

**Independent Test**: Open the detail screen of an account with a standing wish, click the cancel-search button, and confirm the wish is gone from that screen, from the account's own homepage, and from the locker wishes list.

**Acceptance Scenarios**:

1. **Given** an account has a standing locker-search wish, **When** the administrator views its detail screen, **Then** a button to cancel that search is visible.
2. **Given** the administrator clicks the cancel-search button, **When** they confirm the action in the confirmation step that follows, **Then** the account's wish is removed and the detail screen updates to show no search is in progress.
2a. **Given** the administrator clicks the cancel-search button, **When** they decline or dismiss the confirmation step instead of confirming, **Then** the wish is left untouched.
3. **Given** an account has no standing wish (whether it never had one, or is only party to a swap proposal), **When** the administrator views its detail screen, **Then** no cancel-search button is shown.
4. **Given** the administrator cancels a search for an account that is also party to a pending swap proposal as the recipient, **When** the cancellation completes, **Then** the proposal is affected only insofar as the account no longer qualifies as an eligible recipient going forward — the swap proposal itself is left exactly as it was, neither withdrawn nor declined by this action.

---

### Edge Cases

- What happens if the administrator opens a user detail screen and that account is deleted (cancelled) by itself in another session before or during the visit? The administrator MUST see a clear "this account no longer exists" outcome rather than a broken or partially-filled screen, and MUST be returned to a working screen (e.g., the Users list) rather than left on a dead page.
- What happens if the administrator submits the cancel-search action for an account whose wish was already cancelled (by the user themselves, moments earlier, in another session)? The action MUST be treated as already accomplished, not as an error, and the screen MUST reflect the current (no-wish) state afterward.
- What happens when the administrator opens the detail screen for their own account? The same information, edit, and cancel-search capabilities apply to the administrator's own account as to any other, since the Users list already permits clicking any row including the administrator's own.
- What happens to the proposal-history section for an account currently in the middle of an accepted (in-progress) exchange? That proposal appears in the history like any other, showing its current in-progress status and the live terms of the exchange, consistent with how that same proposal already reads on the parties' own history screens.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST let an administrator navigate from a link within any row of the Admin → Users list (not the row as a whole) to a dedicated detail screen for that specific account.
- **FR-002**: The system MUST restrict the user detail screen to administrator accounts only, refusing the request the same way other admin-only destinations are refused — whether reached through the Users list or by requesting the address directly.
- **FR-003**: The user detail screen MUST show the account's email address, its role (including the "Admin" label and, where applicable, who granted administrator rights and when — mirroring what the Users list and admin-rights feature already expose), its registration date, its current floor, and its current locker number (or that none is assigned).
- **FR-004**: The user detail screen MUST show whether the account currently has a standing locker-search wish and, if so, which floor it is for.
- **FR-005**: The user detail screen MUST show whether the account is currently party to an active (pending or accepted) swap proposal, in either direction, and MUST show clearly when the account has neither a standing wish nor an active proposal.
- **FR-006**: The user detail screen MUST show the account's complete swap-proposal history — every proposal it has ever sent or received, in every status — ordered newest first, each entry identified by direction (sent/received), counterparty, date, status, and outcome details (decline reason when declined, or the floor/locker terms involved).
- **FR-007**: The user detail screen MUST state clearly when the account's proposal history is empty, rather than showing an empty or ambiguous list.
- **FR-008**: The user detail screen MUST offer an icon-only ("pencil") control that reveals an editable form for the account's current floor and locker number, pre-filled with its current values.
- **FR-009**: Submitting the edit form MUST update the account's floor and/or locker number, applying the same validation rules already enforced when a user edits their own details: a floor is required, a locker number must be unique to its floor, and floor/locker cannot be changed while the account has a pending or accepted swap proposal outstanding.
- **FR-009a**: A successful floor/locker edit made from this screen MUST record which administrator made it and when, and the detail screen MUST show that provenance (who last changed the account's floor/locker on its behalf, and when) whenever it is present.
- **FR-010**: The user detail screen MUST offer a button to cancel the account's standing locker-search wish, visible only when that account currently has one.
- **FR-010a**: Activating the cancel-search button MUST require the administrator to explicitly confirm the action before the wish is removed, distinct from an accidental click.
- **FR-011**: Confirming the cancellation MUST remove the account's standing wish and MUST NOT alter any swap proposal the account is party to.
- **FR-011a**: A cancellation performed from this screen MUST record which administrator performed it and when, retained independently of the wish it cancelled (the wish row itself is deleted).
- **FR-012**: The pencil-icon edit control and the cancel-search button MUST both be operable via keyboard and MUST expose an accessible name for assistive technology, consistent with the existing pencil-icon edit convention.
- **FR-013**: All administrator actions on this screen (viewing, editing floor/locker, cancelling a search) MUST apply to any registered account, including the administrator's own.

**Superseded by feature 015** (`specs/015-grant-admin-rights/`), FR-014: this feature intentionally extends the Admin → Users capability set beyond that requirement's "read-only except for granting rights" boundary, adding the ability to view full account detail, edit an account's floor and locker number, and cancel an account's locker search. Granting/removing administrator rights and deleting an account remain out of scope for this feature and continue to be governed exactly as 013/015 already specify.

### Key Entities

- **User Account**: the detail screen surfaces its existing attributes (email, role, admin-grant provenance, registration date, current floor, current locker number) and lets an administrator update floor and locker number through the same rules already enforced for self-service edits. This feature adds two new facts to the account: who (which administrator) last edited its floor/locker on its behalf and when, and who last cancelled its search on its behalf and when — each recorded independently of any other change, the same shape of provenance already kept for admin-rights grants.
- **Locker Wish**: unchanged; the detail screen reads whether the viewed account has one and lets an administrator cancel it, the same effect as the account holder cancelling it themselves. The cancellation's provenance (which administrator, when) is recorded on the User Account rather than on the wish, since the wish row itself is deleted by the cancellation.
- **Locker Swap Proposal**: unchanged; the detail screen reads the viewed account's full sent-and-received history, and reads whether it currently has one pending or accepted, without introducing any administrator-initiated action on a proposal itself.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An administrator can reach any registered account's full detail screen from the Users list in a single click, for 100% of listed accounts.
- **SC-002**: 0% of non-administrator accounts can view any account's detail screen, whether through the interface or by requesting the address directly.
- **SC-003**: An administrator can determine a given account's current locker-search status and its complete proposal history within a single visit to that account's detail screen, with no need to cross-reference the Users list or locker wishes screen.
- **SC-004**: An administrator can correct a given account's floor or locker number without leaving the detail screen or needing direct database access.
- **SC-005**: An administrator can cancel a given account's locker search in a single action from the detail screen, with the change visible immediately on that screen and reflected everywhere else the search would otherwise appear (the account's own homepage, the locker wishes screen).

## Assumptions

- The detail screen is a full page reached by navigation, not a modal or in-list expansion, consistent with "redirigé vers l'écran" in the request and with how the rest of the admin section already works.
- "Toutes les informations de l'utilisateur" is interpreted as everything already tracked about the account elsewhere in the product (email, role and admin-grant provenance, registration date, current floor, current locker number), plus the two new provenance facts this feature adds (FR-009a, FR-011a) — this feature introduces no account attributes beyond that audit trail.
- The proposal-history section mirrors the existing self-service proposal history a user already sees for their own account (direction, counterparty, date, status, outcome details), scoped to the viewed account instead of the signed-in one, rather than introducing a new data shape.
- This feature does not add any capability to grant/revoke administrator rights, edit an account's email, or delete an account — those remain exactly as governed by features 013 and 015.
- "Cancel search" is read narrowly, matching the term used in the request ("recherche de casier", distinct from "propositions" used for the history section): it cancels only the standing locker-search wish, exactly as a user's own "Cancel wish" action does today. It never withdraws a swap proposal on the account's behalf — a proposal already has its own withdraw/decline lifecycle (features 004/005), driven only by its two parties, and this feature does not extend that lifecycle to the administrator. Consequently the button is only ever shown when a standing wish exists.
- Editing floor/locker on an account's behalf reuses the exact same validations already enforced for self-service edits, including the rule that those fields lock while a pending or accepted swap proposal is outstanding (existing `locker_profile_update` rules on the User model). The administrator is not given a bypass for this lock — the proposal must be resolved (accepted-and-confirmed, declined, or withdrawn) before either party's floor/locker can change again, whether the edit is made by the account holder or by an administrator on their behalf.
