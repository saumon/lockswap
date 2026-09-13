# Feature Specification: Locker Swap Proposals

**Feature Branch**: `004-locker-swap-proposal`

**Created**: 2026-09-13

**Status**: Shipped

**Input**: User description: "Un utilisateur connecté et inscrit peut faire une proposition d'échange de casier depuis l'écran Locker Wishes à destination d'une personne ayant elle-même exprimé son souhait d'échange visible dans l'écran locker wishes. La personne qui reçoit la proposition d'échange peut accepter ou refuser la proposition. Quand on reçoit une proposition, on doit être notifié sur la page d'accueil du site. Lorsqu'on fait une proposition à quelqu'un, celle-ci doit également apparaître sur la page d'accueil du site. On ne peut pas faire de propositions d'échange à soi-même. En cas d'acceptation de la proposition, l'échange de casier est donc noté comme \"échange en cours\". En cas de refus de la proposition, l'utilisateur qui a fait la demande doit être notifié du refus et la personne qui a refusé peut saisir un commentaire de refus. Plus tard, la personne ayant reçu la proposition peut confirmer que l'échange a bien eu lieu, l'étage et numéro de casier est alors switché entre les deux utilisateurs. On ne peux pas faire de propositions à un utilisateur qui a déjà un échange en cours. Chaque utilisateur peut afficher sur un écran séparé l'historique de des demandes de propositions (ses demandes ou celles qu'il a reçues), avec les dates, les refus et les commentaires de refus."

## Clarifications

### Session 2026-09-13

- Q: Can a requester send more than one pending proposal to the same recipient at the same time? → A: No — only one pending proposal at a time per requester→recipient pair; a new one from the same requester to the same recipient is rejected while an earlier one between them is still pending.
- Q: Can the requester withdraw or cancel a proposal they sent while it is still pending, before the recipient responds? → A: Yes — the requester can withdraw a pending proposal before the recipient decides.
- Q: If an exchange is accepted but the recipient never confirms it happened, is there any way to cancel or unstick that "in progress" exchange? → A: No — an in-progress exchange stays that way indefinitely until the recipient confirms it; no cancellation path is in scope for this feature.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Propose a locker swap to someone looking for one (Priority: P1)

A logged-in, registered user browsing the Locker Wishes screen sends a swap proposal to another user who has an active wish shown on that screen, so the two of them can start negotiating an exchange of lockers.

**Why this priority**: This is the entry point of the whole feature — without the ability to create a proposal, there is nothing to accept, decline, or confirm.

**Independent Test**: Can be fully tested by logging in as a registered user, opening the Locker Wishes screen, choosing another user with an active wish, sending them a proposal, and confirming the proposal is recorded and associated with both users.

**Acceptance Scenarios**:

1. **Given** a logged-in, registered user viewing the Locker Wishes screen, **When** they send a swap proposal to another user shown there with an active wish, **Then** the proposal is recorded as pending, linked to both users.
2. **Given** a logged-in user, **When** they attempt to send a swap proposal targeting themselves, **Then** the submission is rejected and no proposal is created.
3. **Given** a logged-in user, **When** they attempt to send a proposal to a user who already has an exchange in progress, **Then** the submission is rejected and the user is told that person is not currently available for a new swap.
4. **Given** a logged-in user who already has an exchange in progress, **When** they attempt to send a new proposal to anyone, **Then** the submission is rejected, since they cannot commit their locker to a second swap while one is already underway.
5. **Given** a logged-in user, **When** they send a proposal to a user with an active wish, **Then** the submission succeeds whether or not the requester themselves currently has a locker or has declared their own wish.
6. **Given** a logged-in user has a pending proposal they sent, **When** they withdraw it before the recipient responds, **Then** the proposal is marked withdrawn and the recipient can no longer accept or decline it.

---

### User Story 2 - Respond to a received swap proposal (Priority: P1)

A logged-in, registered user who has received a swap proposal reviews it and either accepts or declines it, optionally explaining a decline with a comment, so the requester learns the outcome.

**Why this priority**: A proposal only creates value once the recipient can act on it — this closes the loop opened by User Story 1.

**Independent Test**: Can be fully tested by having one user send a proposal to another, then, logged in as the recipient, accepting or declining it, and confirming the resulting status and (for a decline) any comment are visible to the requester.

**Acceptance Scenarios**:

1. **Given** a logged-in user has received a pending proposal, **When** they accept it, **Then** the proposal is marked as an exchange in progress for both users.
2. **Given** a logged-in user has received a pending proposal, **When** they decline it, **Then** the proposal is marked as declined and the requester is notified of the decline.
3. **Given** a logged-in user is declining a proposal, **When** they submit the decline, **Then** they may optionally include a free-form decline comment, which is stored with the decline.
4. **Given** a logged-in user declines a proposal without entering a comment, **When** the decline is recorded, **Then** the requester is still notified of the decline, with no comment shown.
5. **Given** a proposal has already been accepted or declined, **When** anyone attempts to accept or decline it again, **Then** the action is rejected — a decision can only be made once per proposal.

---

### User Story 3 - See my proposals on the homepage (Priority: P1)

A logged-in, registered user sees, on the site's homepage, any swap proposal they have received awaiting a decision, as well as any proposal they have sent that is still pending, so they don't have to go looking for this activity elsewhere.

**Why this priority**: The proposal workflow depends on both parties noticing that something needs their attention; without homepage visibility, proposals could go unseen indefinitely.

**Independent Test**: Can be fully tested by sending a proposal from one user to another and confirming that the sender sees it on their own homepage and the recipient sees it on theirs, without visiting any other screen.

**Acceptance Scenarios**:

1. **Given** a logged-in user has received one or more pending proposals, **When** they visit the homepage, **Then** each pending proposal they received is shown there.
2. **Given** a logged-in user has sent one or more pending proposals, **When** they visit the homepage, **Then** each pending proposal they sent is shown there.
3. **Given** a logged-in user's proposal has just been declined, **When** they visit the homepage, **Then** they see that it was declined.
4. **Given** a logged-in user has no pending or recently-decided proposals in either direction, **When** they visit the homepage, **Then** no proposal-related notification is shown.

---

### User Story 4 - Confirm the exchange actually happened (Priority: P2)

The user who received and accepted a proposal later confirms that the physical locker exchange has actually taken place, at which point the floor and locker number on file for both users are swapped.

**Why this priority**: This is what makes the feature deliver its ultimate value — the actual locker records being updated — but it depends on User Stories 1 and 2 already being in place.

**Independent Test**: Can be fully tested by accepting a proposal, confirming the exchange as the recipient, and verifying that each user's on-file floor and locker number now matches what the other user had before the confirmation.

**Acceptance Scenarios**:

1. **Given** a proposal is marked as an exchange in progress, **When** the user who received the original proposal confirms the exchange took place, **Then** the floor and locker number previously on file for each user are swapped between the two users.
2. **Given** an exchange has been confirmed and completed, **When** either user's profile is viewed afterward, **Then** it reflects the other user's pre-exchange floor and locker number.
3. **Given** an exchange is still marked as in progress, **When** the requester (rather than the recipient) attempts to confirm it, **Then** the confirmation is rejected — only the recipient who accepted the proposal can confirm completion.
4. **Given** an exchange has already been confirmed and completed, **When** anyone attempts to confirm it again, **Then** the action is rejected.

---

### User Story 5 - View my proposal history (Priority: P3)

A logged-in, registered user opens a separate history screen to review every swap proposal they have sent or received, including when each happened, which were declined, and any decline comments.

**Why this priority**: Useful for transparency and record-keeping over time, but the core swap workflow already functions without a dedicated history view.

**Independent Test**: Can be fully tested by generating a mix of sent and received proposals in different states (pending, accepted, declined, completed) and confirming the history screen lists all of them for the user involved, with correct dates, statuses, and decline comments.

**Acceptance Scenarios**:

1. **Given** a logged-in user has sent and/or received proposals in the past, **When** they open the history screen, **Then** they see every proposal they were party to, whether they sent it or received it.
2. **Given** a proposal in the user's history was declined, **When** it is shown in the history screen, **Then** the decline is indicated along with the decline comment, if one was entered.
3. **Given** a proposal in the user's history was accepted and later confirmed, **When** it is shown in the history screen, **Then** its completed status is indicated.
4. **Given** a logged-in user has never sent or received a proposal, **When** they open the history screen, **Then** it is shown empty rather than as an error.

---

### Edge Cases

- What happens when a user tries to propose a swap to someone who no longer has an active wish (e.g., it was cancelled after being shown to the requester)? The submission MUST be rejected, since the target is no longer an eligible recipient.
- What happens to a recipient's other pending, undecided proposals (sent by different requesters) once one of them is accepted? The system MUST automatically decline the recipient's other pending incoming proposals, since the recipient can no longer take on a second swap while one is in progress; each of those other requesters MUST be notified of the automatic decline.
- What happens to a requester's other pending, undecided outgoing proposals (sent to different recipients) once one of them is accepted? The system MUST automatically decline the requester's other pending outgoing proposals for the same reason, notifying the affected recipients.
- What happens if the recipient of a declined proposal still has an active wish afterward? Nothing changes about their wish — it remains active and visible on the Locker Wishes screen, available to receive new proposals.
- What happens if a requester sends a new proposal to a recipient who previously declined one of their proposals? It MUST be allowed, as long as the recipient still has an active wish, still has no exchange in progress, and the requester is not proposing to themselves.
- What happens if a requester tries to send another proposal to a recipient while an earlier proposal from that same requester to that same recipient is still pending? The new submission MUST be rejected until the earlier one between them is decided (accepted, declined, or automatically resolved).
- What happens when a requester withdraws a pending proposal they sent? It MUST become non-actionable for the recipient (no longer acceptable or declinable) and MUST show as withdrawn in both users' history; no further action is required from the recipient.
- What happens when an exchange is accepted but the recipient never confirms it happened? It remains marked as an exchange in progress indefinitely — there is no automatic expiration and no cancellation action for a stuck in-progress exchange.
- What happens to the wish(es) involved once a proposal is accepted? Both the requester's and recipient's active wishes (if any), if related to this exchange, MUST no longer be treated as open invitations while the exchange is in progress or after it is completed, since the underlying need has been resolved or is being resolved.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST allow a logged-in, registered user to send a locker swap proposal, from the Locker Wishes screen, to another user who currently has an active wish shown on that screen.
- **FR-002**: The system MUST reject any attempt by a user to send a swap proposal targeting themselves.
- **FR-003**: The system MUST reject any attempt to send a swap proposal to a user who already has an exchange in progress.
- **FR-004**: The system MUST reject any attempt by a user who already has an exchange in progress to send a new proposal to anyone else.
- **FR-005**: The system MUST allow the recipient of a pending proposal to accept it or decline it.
- **FR-006**: When a proposal is accepted, the system MUST mark the exchange as "in progress" for both the requester and the recipient.
- **FR-007**: When a proposal is declined, the system MUST notify the requester that it was declined.
- **FR-008**: The system MUST allow the recipient, when declining a proposal, to optionally enter a free-form decline comment, and MUST store it with the decline for the requester to see.
- **FR-009**: The system MUST display, on the homepage, every pending proposal a logged-in user has received and every pending proposal they have sent, along with the outcome of any proposal recently decided.
- **FR-010**: The system MUST prevent a proposal from being accepted or declined more than once.
- **FR-011**: When a proposal is accepted, the system MUST automatically decline any other pending proposals involving either the requester or the recipient (as sender or as receiver), and MUST notify the other party of each automatically-declined proposal.
- **FR-012**: The system MUST allow only the recipient who accepted a proposal to confirm that the exchange has actually taken place.
- **FR-013**: When the recipient confirms an exchange has taken place, the system MUST swap the on-file floor and locker number between the requester and the recipient, and MUST mark the exchange as completed.
- **FR-014**: The system MUST prevent an exchange from being confirmed more than once.
- **FR-015**: The system MUST allow a logged-in, registered user to view, on a separate screen, the full history of swap proposals they sent and the full history of swap proposals they received, including the date of each proposal, its current status, and any decline comment.
- **FR-016**: Sending a proposal, withdrawing a proposal, accepting or declining a proposal, confirming a completed exchange, and viewing proposal history MUST all be restricted to logged-in, registered users.
- **FR-017**: The system MUST reject a proposal sent to a user who no longer has an active wish at the time the proposal is created.
- **FR-018**: The system MUST reject a new proposal from a requester to a recipient when a pending proposal from that same requester to that same recipient already exists, until the earlier one is decided.
- **FR-019**: The system MUST allow a requester to withdraw a pending proposal they sent, at any time before the recipient accepts or declines it.
- **FR-020**: Once a proposal is withdrawn, the system MUST prevent the recipient from accepting or declining it, and MUST reflect the withdrawal in both parties' proposal history.

### Key Entities

- **Locker Swap Proposal**: Represents one user's request (the requester) to swap lockers with another user (the recipient) who has an active wish. Attributes: requester, recipient, status (pending, accepted/in progress, declined, withdrawn, completed), date created, date decided, optional decline comment (present only when declined), date completed (present only when completed). A proposal moves through at most one full lifecycle from pending to a final state (declined, withdrawn, or accepted then later completed).
- **Locker Wish** *(existing entity, referenced here)*: Identifies which users are eligible recipients of a proposal (must have an active wish). Referenced but not owned by this feature; entering an exchange in progress does not delete the underlying wish record but suspends it from being treated as an open invitation.
- **User Locker Profile** *(existing entity, referenced here)*: Holds each user's current floor and locker number. This feature reads it to know what to swap, and updates it — swapping the two users' values — when an exchange is confirmed as completed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A logged-in user can send a swap proposal to an eligible person shown on the Locker Wishes screen in under 30 seconds.
- **SC-002**: 100% of self-targeted proposal attempts are rejected without creating a proposal.
- **SC-003**: 100% of newly received and newly sent pending proposals appear on the relevant user's homepage the next time they load it.
- **SC-004**: 100% of proposal declines result in the requester being notified, with any decline comment visible to them.
- **SC-005**: At no point does any user have more than one exchange in progress at the same time.
- **SC-006**: 100% of confirmed exchanges result in each user's floor and locker number correctly reflecting the other user's pre-exchange values.
- **SC-007**: A user can find the complete history (sent and received, with dates, declines, and decline comments) of their swap proposals in one place, without needing to reconstruct it from other screens.

## Assumptions

- "Connecté" (logged-in) and "inscrit" (registered) refer to the same existing authenticated-user population already used elsewhere in the site (e.g., the locker/floor profile and locker wishes features); no separate registration check is introduced.
- The requester does not need to have declared their own active wish in order to send a swap proposal — only the recipient is required to have one, per the feature description; the requester may or may not currently have a locker of their own.
- The restriction against proposing to a user with an exchange in progress applies symmetrically: such a user can also not initiate a new proposal to anyone else, since their own locker is already committed to the swap that is underway.
- When an exchange is accepted, any other pending proposals involving either party (sent or received) are automatically declined by the system, since neither party can pursue a competing swap while committed to this one; affected counterparts are notified the same way as for a manual decline.
- Declining a proposal creates no lasting restriction between the two users — the same requester may send a new proposal to the same recipient again later, as long as normal eligibility rules are still met.
- Only the recipient who accepted the original proposal can confirm that the exchange took place; there is no separate action for the requester to confirm or dispute completion. An in-progress exchange that is never confirmed stays in progress indefinitely — there is no automatic expiration and no manual cancellation path for a stuck in-progress exchange in this feature.
- The decline comment is optional and free-form, consistent with how the floor field is already handled elsewhere in the app (no predefined list, just an optional text value).
- The homepage notification described here is a summary/indicator sufficient to identify each relevant proposal and its status; the full detail of accepting, declining, or confirming an exchange is handled from the appropriate proposal screen.
