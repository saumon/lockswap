# Feature Specification: Locker Field Lock & Swap History Comment

**Feature Branch**: `005-swap-lock-history-comment`

**Created**: 2026-09-13

**Status**: Shipped

**Input**: User description: "Lorsqu'on a reçu ou envoyé une proposition, on ne peut pas modifier son étage ni son numéro de casier. Le champ commentaire de l'historique des propositions doit automatiquement être rempli, notamment pour afficher le numéro de casier et l'étage échangé."

## Clarifications

### Session 2026-09-13

- Q: Should the automatically-filled history comment appear only on completed exchanges, or on every proposal status (pending, in progress, declined, withdrawn)? → A: On every status — pending/in-progress/declined/withdrawn entries show what was proposed, completed entries show what was actually exchanged.
- Q: Is the automatic comment the same field as the existing manually-entered decline comment, or a separate field shown alongside it? → A: Two separate fields, shown together — the decline comment stays exactly as it is today, and the system-generated summary is an additional field.
- Q: Once a proposal is resolved (declined, withdrawn, or completed), should its history comment stay frozen at the floor/locker values from when it was decided, or keep reflecting each user's current profile even if they change it later? → A: Freeze/snapshot the floor and locker number values at the moment each proposal is decided (declined/withdrawn) or completed; later profile edits never change past history entries.
- Q: Should the floor/locker edit lock only block changes to a value the user has already saved, or does it also block a user from entering their floor or locker number for the very first time while they have an active proposal? → A: Lock applies only to changing an existing, already-saved floor/locker number; first-time entry (currently unset) is always allowed, even with an active proposal.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Floor and locker number are locked while a swap is active (Priority: P1)

A logged-in user who has sent or received a swap proposal that is still active (pending a decision, or accepted and in progress) can no longer change their floor or their locker number until that proposal is resolved, so the details being negotiated or already agreed to cannot be pulled out from under the other party.

**Why this priority**: Without this lock, a user could quietly change their floor or locker number mid-negotiation or after acceptance, making the proposal (and, once accepted, the exchange itself) refer to values that no longer match reality — this directly protects the integrity of the existing swap workflow.

**Independent Test**: Can be fully tested by having a user send or receive a proposal, attempting to edit their floor or locker number while it is pending or in progress and confirming the edit is rejected, then resolving the proposal (decline, withdraw, or complete) and confirming the edit is allowed again.

**Acceptance Scenarios**:

1. **Given** a logged-in user has sent a proposal that is still pending, **When** they attempt to change their floor or their locker number, **Then** the change is rejected and they are told they cannot edit these fields while they have an active swap proposal.
2. **Given** a logged-in user has received a proposal they have not yet decided on, **When** they attempt to change their floor or their locker number, **Then** the change is rejected for the same reason.
3. **Given** a logged-in user's proposal has been accepted and the exchange is in progress, **When** they attempt to change their floor or their locker number, **Then** the change is rejected until the exchange is confirmed as completed.
4. **Given** a logged-in user has no pending or in-progress proposal (none yet, or all of theirs have been declined, withdrawn, or completed), **When** they change their floor or their locker number, **Then** the change is accepted, exactly as before this feature.
5. **Given** a logged-in user's only active proposal has just been declined or withdrawn, **When** they subsequently attempt to change their floor or locker number, **Then** the change is accepted, since they no longer have any active proposal.
6. **Given** a logged-in user has an active swap proposal but has never saved a locker number (or, unusually, a floor) of their own, **When** they provide that value for the first time, **Then** the submission succeeds, since the lock only blocks changing an already-saved value.

---

### User Story 2 - Proposal history shows what was proposed or exchanged without typing it in (Priority: P2)

A logged-in user reviewing their swap proposal history sees a comment on every proposal — no matter its status — that is automatically filled in by the system rather than left blank or dependent on someone having typed something, stating the floor and locker number involved: what is being proposed for a proposal that is still pending, in progress, declined, or withdrawn, and what was actually exchanged once a proposal is completed.

**Why this priority**: This builds on the existing history screen and decline-comment capability; it makes the record easier to read but the swap workflow itself already functions without it, so it follows User Story 1.

**Independent Test**: Can be fully tested by creating proposals that end up in each status (pending, in progress, declined, withdrawn, completed) and opening the history screen for both users, confirming each status shows an automatically-filled comment with the correct floor/locker wording (proposed vs. exchanged) and no manual entry required.

**Acceptance Scenarios**:

1. **Given** a proposal is pending, in progress, declined, or withdrawn, **When** either party views it in their proposal history, **Then** the entry shows an automatically-filled comment stating the floor and locker number being proposed between the two users.
2. **Given** a proposal has been confirmed as a completed exchange, **When** either user views it in their proposal history, **Then** the automatically-filled comment instead states the floor and locker number actually exchanged between the two users.
3. **Given** a user views any entry in their history, **When** they read the automatically-filled comment, **Then** it is populated without requiring either user to have typed anything.
4. **Given** a declined proposal has both a user-entered decline comment and the automatically-filled system comment, **When** either user views it in history, **Then** both comments are shown together, and neither one overwrites or hides the other.

---

### Edge Cases

- What happens if a user has never had a locker number (floor only) and their proposal is proposed, declined, withdrawn, or completed? The automatically-filled comment MUST still describe the floor involved, and MUST clearly indicate no locker number was involved for the side that had none.
- What happens if a user attempts to edit their floor and locker number in the same submission while locked? The entire submission MUST be rejected, since both fields are locked together.
- What happens when a user with an active proposal tries to edit a field unrelated to floor/locker (if any exist elsewhere in their profile)? Out of scope for this feature — only the floor and locker number fields are locked.
- What happens if a user has multiple resolved proposals in their history (e.g., one declined, one later completed)? Each history entry MUST show its own automatically-filled comment independently, based on that entry's own status.
- What happens to the automatically-filled comment if a proposal moves from one status to another (e.g., pending → completed)? It MUST update to reflect the new status (from "proposed" wording to "exchanged" wording) rather than continuing to show stale wording from an earlier status.
- What happens to a resolved proposal's automatically-filled comment if either user later changes their floor or locker number (once unlocked)? The comment MUST stay exactly as it was snapshotted when the proposal was resolved — it MUST NOT change to reflect the user's new, current values.
- What happens if a requester with no locker number (or, unusually, no floor) on file yet has an active proposal? They MUST still be able to save a floor or locker number for the first time, since the lock only blocks changing a value that is already saved, not providing one that is currently missing.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST prevent a logged-in user from changing an already-saved floor value while they have at least one active swap proposal (pending, or accepted and in progress) in which they are either the requester or the recipient. This restriction does not apply to a user who has not yet saved a floor value — they may still provide it for the first time even while an active proposal exists.
- **FR-002**: The system MUST prevent a logged-in user from changing an already-saved locker number under the same condition as FR-001. A user who has not yet saved a locker number may still provide one for the first time even while an active proposal exists.
- **FR-003**: The system MUST tell the user, when a floor or locker number edit is rejected for this reason, that the fields are locked because they have an active swap proposal.
- **FR-004**: The system MUST allow floor and locker number edits again as soon as a user has no remaining active swap proposal (all of theirs are declined, withdrawn, or completed).
- **FR-005**: The system MUST automatically fill in a system-generated comment on every proposal history entry, regardless of status (pending, accepted/in progress, declined, withdrawn, or completed), without requiring manual entry.
- **FR-006**: For a proposal that is pending, in progress, declined, or withdrawn, the automatically-filled comment MUST state the floor and locker number being proposed between the requester and the recipient. For a proposal that is completed, it MUST instead state the floor and locker number actually exchanged.
- **FR-007**: The automatically-filled comment MUST be visible to both the requester and the recipient when they view that entry in their own proposal history.
- **FR-008**: The automatically-filled system comment MUST be a field distinct from the existing manually-entered decline comment (see 004-locker-swap-proposal). Where both exist on the same entry, the system MUST display them together without either one overwriting or hiding the other.
- **FR-009**: While a proposal is pending or in progress (i.e., still unresolved), the automatically-filled comment MUST reflect each party's current floor and locker number; when the proposal transitions to declined, withdrawn, or completed, the system MUST snapshot the floor and locker number values at that moment and freeze the comment to those values from then on, even if either user later changes their profile.

### Key Entities

- **Locker Swap Proposal** *(existing entity, extended)*: Gains a system-generated summary comment, separate from the existing manually-entered decline comment, describing the floor and locker number proposed (for pending or in-progress proposals) or exchanged (for completed ones). While unresolved, the comment tracks each party's current floor and locker number; once the proposal is declined, withdrawn, or completed, the values are snapshotted at that moment and the comment no longer changes even if either user's profile is edited afterward.
- **User Locker Profile** *(existing entity, referenced here)*: Its floor and locker number fields become temporarily non-editable while the owning user is a party (requester or recipient) to any active (pending or in-progress) swap proposal, and become editable again once none remain.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of floor or locker number edit attempts made while the user has an active swap proposal are rejected, with a reason shown to the user.
- **SC-002**: 100% of users regain the ability to edit their floor and locker number immediately once they no longer have any active swap proposal.
- **SC-003**: 100% of proposal history entries, in every status, display a system-generated comment stating the relevant floor and locker number (proposed or exchanged), with zero manual entry required to produce it.
- **SC-004**: A user can tell what floor and locker number were proposed or exchanged for any swap by reading their proposal history alone, without needing to ask the other party or reconstruct it from elsewhere.

## Assumptions

- "Active swap proposal" means a proposal that is pending a decision or has been accepted and is in progress (per the existing 004-locker-swap-proposal statuses); declined, withdrawn, and completed proposals are not considered active and do not lock the profile.
- The lock applies symmetrically to both the requester and the recipient of an active proposal, and to both the floor and the locker number fields together — a user cannot edit either already-saved field while locked, even if only one of the two is directly relevant to the pending exchange.
- The lock only prevents changing a floor or locker number that is already saved; it never blocks a user from providing one of these values for the first time (e.g., a requester with no locker yet can still record one while their proposal is pending).
- Once a user's last active proposal is resolved (declined, withdrawn, or completed), the lock is lifted immediately with no additional waiting period or manual unlock step.
- For a completed exchange, the automatically-filled comment states each user's floor and locker number as they were immediately before the swap (i.e., what each side gave up and received), consistent with how the exchange itself is recorded per 004-locker-swap-proposal's FR-013. While a proposal is still pending or in progress, the comment reflects the floor and locker number currently on file for each side (which, per User Story 1, cannot drift while locked). Once a proposal is declined, withdrawn, or completed, those values are snapshotted at that moment and the comment stays fixed thereafter, regardless of later profile edits.
- This feature builds directly on 004-locker-swap-proposal and does not change who can send, accept, decline, withdraw, or confirm a proposal — it only adds the field lock and the automatic history comment.
