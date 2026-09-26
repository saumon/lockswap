# Feature Specification: Locker Zone Visibility Across Screens

**Feature Branch**: `032-locker-zone-visibility`

**Created**: 2026-09-26

**Status**: Draft

**Input**: User description: "La zone du casier doit être visible dans les différents écrans (si le casier est rattaché à une zone)."

## Clarifications

### Session 2026-09-26

- Q: For a locker mentioned in past swap-proposal history, should the zone shown always be whichever zone currently claims that floor + locker number, or should history avoid implying something that wasn't necessarily true when the swap actually happened? → A: Show the zone currently assigned to that floor + locker pair on every history entry, live, even if it's changed since the proposal happened — no schema change, no snapshot. This confirms Story 4, FR-004, FR-009, and the matching Assumptions bullet as final, not provisional.

### Session 2026-09-26 (post-implementation follow-up)

- Q: In the two tables where a locker number already has its own dedicated cell per row (the account directory, the locker search list), should the zone share that cell (as it does everywhere else) or get a column of its own? → A: A dedicated "Zone" column on those two tables specifically, showing an explicit "No zone" placeholder when undeclared — the same voice as its neighboring columns' "Not set"/"No locker assigned" (FR-002a, FR-003a). The swap-history table keeps the zone inline: each row already combines two people's floor + locker into one prose cell, so a single "Zone" column cannot cleanly represent two different zones — left unchanged, as confirmed by the user when asked.

### Session 2026-09-26 (second post-implementation follow-up)

- Q (user-directed, not asked): on the homepage's own locker card, the zone must match Floor and Locker number's own presentation exactly — the same row at desktop, a bold label with no colon at every width. → A: The homepage's locker card gains a third term/value field in its existing grid (same markup as Floor and Locker number), rather than the shared/_zone_label partial's inline "Zone: X" sentence used everywhere else. FR-008's "clearly distinguishable" is satisfied structurally here (a separate labelled field) instead of typographically (prose vs. mono), since the user asked for uniform styling specifically on this screen. The other four screens that still use the inline sentence (swap proposal received, exchange in progress, admin detail page, swap history) are unaffected.

### Session 2026-09-26 (third post-implementation follow-up — User Story 4 withdrawn)

- Q (user-directed, not asked): remove the zone information from the "Locker details" column on the swap-history screens (self-service and admin). → A: Done. User Story 4, FR-004, and FR-009 are withdrawn — the "Locker details" column reports only `floor_and_locker_summary`, exactly as it did before this feature existed, on both the self-service history screen and the admin account detail page's history table. Stories 1–3 (own locker, swap-decision screens, admin directory/detail) and FR-001–FR-003a, FR-005–FR-008 are unaffected; the underlying `LockerMapEntry.zone_names_for`/`.zone_name_for` lookup and `LockerSwapProposal#locker_sides` (still used internally by `floor_and_locker_summary`) are unaffected too, since Stories 1–3 still depend on the former.

### Session 2026-09-26 (fourth post-implementation follow-up — received-proposal wording)

- Q (user-directed, confirmed when asked): on the homepage's received-proposal card, should the zone move onto the same line as floor/locker (with the sent date on its own line below, in a new day/month/year format), or is that just an illustrative example and the existing date format should stay? → A: Change the date format too. The card now reads "Floor %{floor} · Locker %{locker} · Zone %{zone}" on one line (zone omitted when undeclared, as FR-005 already required) and "Sent %{sent_at}" on its own line below, where `%{sent_at}` uses a new fixed format ("26/09/2026 à 17:28") reserved for this one field. This is a deliberate, narrow exception to 025/FR-012's "dates keep one format regardless of language" rule — the new format is itself still pinned identically in both `en.yml` and `fr.yml` (not translated per language), consistent with FR-012's own reasoning applied to a second fixed string rather than extending the first one's reach. No other screen's date display is affected.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A user sees their own locker's zone (Priority: P1)

A user viewing their own saved floor and locker number, on the screen where they normally check it, also sees the name of the zone that locker belongs to — when an administrator has declared that floor + locker number pair in a zone.

**Why this priority**: This is the simplest, most direct case, and proves the underlying lookup (floor + locker number → zone) works correctly before extending the same display to every other screen.

**Independent Test**: Can be fully tested by having an admin declare a zone containing a user's saved locker, then having that user view their own locker details and confirming the zone name appears alongside the floor and locker number.

**Acceptance Scenarios**:

1. **Given** a user's saved locker is declared in zone "Aile Nord", **When** the user views their own locker details, **Then** "Aile Nord" is shown next to their floor and locker number.
2. **Given** a user's saved locker number is not declared in any zone, **When** the user views their own locker details, **Then** the floor and locker number are shown exactly as before, with no zone name and no error.
3. **Given** a user has no locker assigned at all, **When** they view their locker details, **Then** the existing "no locker assigned" message is shown unchanged, with no zone indication.

---

### User Story 2 - A user sees the zone of a locker they are considering swapping (Priority: P2)

A user browsing the list of people currently offering to swap, reviewing a swap proposal they received, or looking at a swap they are already committed to, sees the zone of the other person's locker wherever that locker's floor and number are already shown — so they can weigh the swap on more than a bare number.

**Why this priority**: This is where the feature delivers the most decision-making value, but it depends on the same lookup Story 1 already establishes.

**Independent Test**: Can be fully tested by declaring a zone for one user's locker, then confirming its name appears on the locker search list, on a swap proposal that user sent to someone else, and on the "exchange in progress" screen once that proposal is accepted.

**Acceptance Scenarios**:

1. **Given** a locker shown on the list of people currently offering to swap is declared in a zone, **When** another user views that list, **Then** the zone name is shown alongside that locker's floor and number on that row.
2. **Given** a user has received a swap proposal from someone whose locker is declared in a zone, **When** the recipient views the proposal, **Then** the zone name is shown alongside the proposer's floor and locker number.
3. **Given** a swap has been accepted and is in progress, **When** either party views the "exchange in progress" screen, **Then** the zone name of the other party's locker is shown alongside their floor and locker number, if declared.
4. **Given** a locker shown in any of these places is not declared in any zone, **When** the screen is viewed, **Then** the floor and locker number are shown exactly as before, with no zone name and no error.

---

### User Story 3 - An administrator sees a locker's zone without leaving the account screen (Priority: P3)

An administrator viewing the account directory list, or a single account's detail page, sees the zone of that account's locker directly, without needing to separately open the Locker Map to look it up.

**Why this priority**: Useful for administrative work, but the site already delivers its core swap-facilitation value (Stories 1 and 2) without this.

**Independent Test**: Can be fully tested by declaring a zone for a user's locker, then confirming an admin sees the zone name both in that user's row on the account directory list and on that user's individual detail page.

**Acceptance Scenarios**:

1. **Given** an account's locker is declared in a zone, **When** an admin views the account directory list, **Then** that account's row shows the zone name alongside its floor and locker number.
2. **Given** an account's locker is declared in a zone, **When** an admin opens that account's detail page, **Then** the zone name is shown alongside its floor and locker number.
3. **Given** an account's locker is not declared in any zone, **When** an admin views either screen, **Then** the floor and locker number are shown exactly as before, with no zone name and no error.

---

### ~~User Story 4 - Zone shown on past swap history~~ (WITHDRAWN 2026-09-26, see Clarifications)

~~A user reviewing their own history of past swap proposals, or an administrator reviewing an account's history, sees the zone associated with each historical proposal's floor and locker number, when one currently applies.~~

**Withdrawn**: shipped, then explicitly reverted by the user. The "Locker details" column on both history screens shows only `floor_and_locker_summary`, with no zone information, exactly as before this feature existed. Kept here, struck through, so the reasoning that once justified it (and the reasoning that later withdrew it) both stay on record.

---

### Edge Cases

- What happens when the Locker Map has never had a single locker declared in it, site-wide? No zone is shown anywhere; every floor and locker number displays exactly as it did before this feature existed.
- What happens when a locker is removed from its zone, or its zone is deleted, after having been shown with a zone name? The zone name stops appearing everywhere that locker is shown, on the very next time each screen is viewed — the user's own saved floor and locker number are unaffected.
- What happens when a zone is renamed? Every screen currently showing that zone's name reflects the new name the next time it is viewed, with no separate step.
- What happens on a screen listing several people at once, where some have a declared zone and others do not? Each row is judged independently; a missing zone on one row is an ordinary state, not an error.
- What happens when the locker number field a user or admin is actively typing into (before saving) doesn't yet match a known, mapped locker? Nothing changes here — this feature only displays the zone for values already saved and shown, not for a value mid-edit.
- What happens when swap history is viewed? Nothing related to zones — User Story 4 was withdrawn (see Clarifications); the "Locker details" column reads exactly as it did before this feature existed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Wherever the system displays an account holder's own saved floor and locker number, the system MUST also display the name of the zone that floor + locker number pair currently belongs to, whenever that pair is declared in the Locker Map.
- **FR-002**: Wherever the system displays another user's floor and locker number for the purpose of evaluating or acting on a swap — the list of people currently offering to swap, a swap proposal received, and a swap already accepted and in progress — the system MUST also display that locker's zone name, under the same condition as FR-001.
- **FR-003**: Wherever the system displays any account's floor and locker number to an administrator — the account directory list and an individual account's detail page — the system MUST also display that locker's zone name, under the same condition as FR-001.
- **FR-002a/FR-003a**: On the two tables where a locker number already has its own dedicated cell per row (the list of people currently offering to swap, and the account directory), the zone MUST be shown in a dedicated column of its own, not folded into the locker number's cell, with an explicit placeholder (in the same voice as that table's other empty-state placeholders) when no zone is declared.
- ~~**FR-004**: Wherever the system displays the floor and locker number recorded against a past swap proposal — in the history shown to the account holder and in the history shown to an administrator — the system MUST also display that locker's zone name, under the same condition as FR-001.~~ **WITHDRAWN 2026-09-26** — swap history displays no zone information; see Clarifications.
- **FR-005**: When a floor + locker number pair is not currently declared in the Locker Map — whether it was never declared, has since been removed from its zone, or the Locker Map has never had anything declared in it site-wide — the zone MUST NOT be displayed, and the floor and locker number MUST continue to display exactly as they do today, without any error or warning treatment.
- **FR-006**: When an account has no locker assigned at all, the existing "no locker assigned" presentation MUST be unaffected; no zone indication is shown in its place.
- **FR-007**: The zone name displayed MUST always reflect the zone's current name and current claim on that floor + locker number pair at the moment the screen is shown — a rename, or a locker being moved out of its zone, MUST be reflected everywhere that locker is shown with no separate step and no stale name left behind.
- **FR-008**: Zone information MUST be presented in a way that is clearly distinguishable from the floor and locker number values themselves, so a reader cannot mistake the zone name for part of the locker's own identity.
- ~~**FR-009**: For a floor + locker number recorded against a past swap proposal, the zone name shown MUST be whichever zone currently claims that pair; the system MUST NOT attempt to reconstruct or imply what zone, if any, applied at the time the proposal was made.~~ **WITHDRAWN 2026-09-26** — moot once FR-004 was withdrawn.

### Key Entities

- **Zone (existing, from the Locker Map feature)**: Unchanged by this feature. Only its name is newly surfaced in more places than before.
- **Locker Map Entry (existing, from the Locker Map feature)**: The floor + locker number → zone declaration this feature reads from, in every place a floor and locker number were already being displayed. This feature introduces no new way of declaring or changing that relationship.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can identify which zone their own locker is in directly from the screen where they already check their locker details, without visiting any other screen.
- **SC-002**: A user weighing a swap can see the zone of the other party's locker in every place that swap is discussed — the search list, a received proposal, and an exchange in progress — without cross-referencing the Locker Map separately.
- **SC-003**: An administrator can see any account's locker zone directly from the account directory list or that account's detail page, without opening the Locker Map.
- **SC-004**: 100% of lockers not declared in the Locker Map display with no zone name and no visual error, matching their appearance before this feature existed.
- **SC-005**: A zone rename or a locker's removal from its zone is reflected on every screen showing that locker the very next time each screen is viewed, with no separate republishing step required.

## Assumptions

- "The different screens" means every existing place the site already displays a specific person's saved floor and locker number to a reader: the account holder's own locker details, the account directory list and an account's detail page (admin), and the locker search list — not the Locker Map screen itself, which already shows zone names as its own organizing structure, and not swap history, which was withdrawn (see Clarifications).
- The locker number entry fields themselves (the account holder's own edit form, and the admin's locker editor for another account) are unchanged by this feature; zone display applies only to values already saved and already shown, not to a value being typed before it is saved.
- This feature adds no new administrative controls and does not change the Locker Map screen; it only adds a read of the existing Zone/Locker Map data to screens that already display a floor and locker number.
- When the Locker Map has never had anything declared in it, site-wide, the absence of any zone display is treated as the normal, pre-feature state, not as missing or broken data.
