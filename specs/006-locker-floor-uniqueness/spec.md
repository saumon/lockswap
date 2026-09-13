# Feature Specification: Per-Floor Locker Number Uniqueness

**Feature Branch**: `006-locker-floor-uniqueness`

**Created**: 2026-09-13

**Status**: Shipped

**Input**: User description: "Le même numéro de casier peut cohabiter pour deux étages différents : on peut avoir le casier 001 à l'étage 1 et le casier 001 à l'étage 2. C'est le couple numéro de casier - étage qui doit être unique, et non le numéro de casier uniquement. Pour un même étage, on ne peut pas avoir deux fois le même casier."

## Clarifications

### Session 2026-09-13

- Q: When a user's locker number is saved but they have no floor on file yet, how should the new per-floor uniqueness rule treat that floor-less locker number? → A: Require the floor to already be on file (or submitted together in the same action) before a locker number can be saved at all — a locker number can never exist without a floor going forward.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Claim a locker number already used on another floor (Priority: P1)

A logged-in user records a locker number that is already saved by a different user, but that other user is on a different floor. Because lockers are numbered per floor, the same number identifies a different, physical locker on each floor, so this submission must succeed instead of being rejected as a duplicate.

**Why this priority**: This is the core correction being made — today the system blocks a perfectly valid combination (same number, different floor), which is a functional defect that prevents legitimate users from recording their real locker.

**Independent Test**: Can be fully tested by having User A save locker number "001" on floor 1, then having User B save locker number "001" on floor 2, and confirming both submissions succeed and both users' profiles display correctly afterward.

**Acceptance Scenarios**:

1. **Given** User A has locker number "001" saved on floor 1, **When** User B submits locker number "001" together with floor 2, **Then** the submission succeeds and User B's profile shows locker "001" on floor 2.
2. **Given** User A has locker number "001" saved on floor 1, **When** User A's own profile is viewed, **Then** it continues to show locker "001" on floor 1, unaffected by User B's later claim of the same number on floor 2.

---

### User Story 2 - Blocked from claiming a locker already taken on the same floor (Priority: P1)

A logged-in user attempts to record a locker number that is already saved by a different user on that same floor. Since two physical lockers on the same floor cannot share a number, this submission must still be rejected, exactly as locker-number collisions are rejected today.

**Why this priority**: Without this rule, the uniqueness check would be removed entirely instead of correctly re-scoped, allowing two people to claim the same physical locker — a data-integrity regression at least as harmful as the current over-strict behavior.

**Independent Test**: Can be fully tested by having User A save locker number "001" on floor 1, then having User B attempt to submit locker number "001" together with floor 1, and confirming the submission is rejected without revealing User A's identity.

**Acceptance Scenarios**:

1. **Given** User A has locker number "001" saved on floor 1, **When** User B submits locker number "001" together with floor 1, **Then** the submission is rejected, User B is told that locker number is not available on that floor, and User A's identity is not disclosed.
2. **Given** User A has locker number "001" saved on floor 1, **When** User A resubmits their own locker number "001" together with floor 1 (no change), **Then** the submission succeeds, since a user is not blocked by their own existing claim.

---

### User Story 3 - Change floor while keeping the same locker number (Priority: P2)

A logged-in user who already has a locker number saved updates their floor (for example, they moved offices) without changing the locker number itself. The system must re-check availability against the new floor rather than the old one, since the meaningful uniqueness key is the floor-and-locker-number pair, not the locker number alone.

**Why this priority**: This is a secondary consequence of the corrected rule — it matters for data correctness when a user's situation changes, but it is not required to demonstrate the core fix in User Story 1 and User Story 2.

**Independent Test**: Can be fully tested by having a user with locker "001" on floor 1 change their floor to floor 2 while keeping locker number "001", confirming the update succeeds when floor 2's "001" is free, and confirming it is rejected when floor 2's "001" is already held by someone else.

**Acceptance Scenarios**:

1. **Given** a user has locker "001" saved on floor 1 and no one holds locker "001" on floor 2, **When** the user updates their floor to floor 2 while keeping locker number "001", **Then** the update succeeds and the user's profile shows locker "001" on floor 2.
2. **Given** a user has locker "001" saved on floor 1 and a different user already holds locker "001" on floor 2, **When** the first user updates their floor to floor 2 while keeping locker number "001", **Then** the update is rejected and the user is told that locker number is not available on that floor.
3. **Given** a user has locker "001" saved on floor 1 and then successfully moves to locker "001" on floor 2, **When** a different user subsequently submits locker number "001" together with floor 1, **Then** that submission succeeds, since floor 1's "001" is no longer held by anyone.

---

### Edge Cases

- What happens when a user submits a locker number without already having a floor on file, and does not supply a floor in that same submission? The submission MUST be rejected and the user MUST be told a floor is required before a locker number can be saved — a locker number can never be stored without an accompanying floor.
- What happens to a user account that, from before this rule change, already has a locker number saved with no floor on file? That existing data MUST be left untouched by this change (no forced backfill), but the next time that user saves or updates their locker number, the system MUST require a floor to be on file or supplied in the same action, per the new rule.
- What happens when a user submits the exact (floor, locker number) pair they already hold? The submission MUST succeed as a no-op, not be rejected as a collision with themselves.
- What happens when a user changes only their locker number and keeps their existing floor? The system MUST check the new locker number for availability against the user's current floor only.
- What happens when a user changes both their floor and their locker number in the same submission? The system MUST check availability of the new (floor, locker number) pair as a single combination, not each value independently.
- What happens to a vacated (floor, locker number) pair after a user moves away from it (changes floor or locker number, or clears their locker)? It MUST immediately become available for any other user to claim.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST treat the combination of locker number and floor as the unique key for locker assignment, superseding any prior rule that treated the locker number alone as globally unique.
- **FR-002**: The system MUST allow the same locker number to be saved by different users at the same time, provided each occurrence is on a different floor.
- **FR-003**: The system MUST reject an attempt to save a locker number on a floor where that exact (floor, locker number) pair is already saved against a different user, and MUST inform the user that the locker number is not available on that floor without disclosing the identity of the current holder.
- **FR-004**: The system MUST NOT reject a user re-submitting a (floor, locker number) pair that is already saved against that same user.
- **FR-005**: When a user changes their floor, their locker number, or both, the system MUST check the availability of the resulting (floor, locker number) pair as a whole before saving the change.
- **FR-006**: Once a (floor, locker number) pair is no longer held by any user (the holder changed floor, changed locker number, or cleared their locker), the system MUST make that pair immediately available for any other user to claim.
- **FR-007**: The system MUST require a floor to already be on file, or to be supplied in the same submission, before a locker number can be saved; a locker number MUST NOT be stored without an associated floor. A submission that supplies a locker number with no floor available (neither on file nor in that submission) MUST be rejected and the user MUST be told a floor is required.
- **FR-008**: A locker number saved before this rule took effect without an associated floor MUST be left as-is; this requirement applies only to new saves and updates of the locker number going forward.

### Key Entities

- **User Locker Profile** *(existing entity, updated rule)*: The `floor` and `locker number` attributes together form the uniqueness key — at most one user account may hold a given (floor, locker number) pair at a time, but the same locker number may be held by different users when their floors differ. This replaces the prior rule under which the locker number alone had to be unique across all accounts.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of submissions pairing a locker number with a floor that is already fully free (no other user holding that exact pair) succeed, including cases where the same locker number is already in use on a different floor.
- **SC-002**: 100% of submissions pairing a locker number with a floor where that exact pair is already held by a different user are rejected, with no other user's identity disclosed.
- **SC-003**: 0% of locker/floor data states allow two different user accounts to simultaneously hold the identical (floor, locker number) pair.

## Assumptions

- This feature corrects the uniqueness scope introduced by the existing locker-and-floor profile capability; it changes the validation rule applied when a floor and/or locker number is saved, and does not introduce any new user-facing fields or screens.
- No pre-existing data conflicts need to be resolved by this change: the prior rule was stricter (locker number unique across all floors), so relaxing it to a per-floor scope cannot create any new collisions among already-saved data.
- "Floor" and "locker number" continue to be handled as free-form values per the existing profile feature; this feature only changes how the two are checked together for uniqueness, not their individual validation.
- This uniqueness rule applies wherever a locker number is saved for a user (initial entry and later updates), consistent with the existing single point of entry for this data.
