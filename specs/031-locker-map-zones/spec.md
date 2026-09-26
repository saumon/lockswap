# Feature Specification: Locker Map (Zones per Floor)

**Feature Branch**: `031-locker-map-zones`

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description: "Un nouvel écran dédié à la cartographie complète des casiers doit être accessible et modifiable par les utilisateurs administrateurs uniquement. Cet écran permet de déclarer, par étage, la liste des zones existantes, et pour chaque zone la liste complète des casiers présents dans la zone (une zone est donc un groupe de casiers, localisée à un étage). Une zone doit être identitée par un nom qui doit être saisissable (et modifiable) dans cet écran. Dans tous les écrans existants, le champ de saisie du numéro de casier doit rester libre, mais la modification doit être interdite si le numéro de casiers est inconnu (donc non référencé dans l'écran de cartographie des casiers). L'unicité du casier doit rester sur “étage” + “numéro de casier” (le nom de zone est purement déclaratif c'est une étiquette rattachée au casier)."

## Clarifications

### Session 2026-09-25

- Q: Must a zone's name be unique among the zones on the same floor, or can two zones on one floor share a name? → A: Unique per floor — saving a zone with a name already used by another zone on the same floor is rejected.
- Q: When an admin deletes a zone that still contains locker numbers, does the system delete the zone along with its locker numbers in one step, or must the admin remove every locker number first? → A: Cascading delete — deleting a non-empty zone removes it and all its locker numbers in one action.
- Q: Once a zone is created on a floor, can an admin later change which floor it belongs to, or is a zone's floor fixed for its lifetime? → A: Fixed at creation — to relocate a zone, the admin deletes it and creates a new one on the right floor.

### Session 2026-09-26 (found during implementation)

- Q: How should the known-locker check (FR-010) behave while the Locker Map has never had a single locker declared in it, site-wide? A strict reading rejected every floor/locker save on a fresh site — including every pre-existing test and, in production, every user until an admin fully pre-populated the map — a much larger blast radius than anticipated during planning. → A: Permissive when empty (FR-013a) — mirrors the site's existing convention for `SiteFloorList`/`LockerNumberFormat`, both of which accept anything until first configured. Enforcement switches on, site-wide, the moment an admin declares the first locker.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Admin declares the locker map (Priority: P1)

An administrator opens a new, dedicated screen and, floor by floor, declares the zones that exist in the building and, for each zone, the complete list of locker numbers physically located in it. This screen is the site's single source of truth for "which locker numbers actually exist and where."

**Why this priority**: Nothing else in this feature works until a reference list of known lockers exists. Without it, there is nothing to validate a locker number against.

**Independent Test**: Can be fully tested by having an admin sign in, open the Locker Map screen, create a zone on a floor, add locker numbers to it, and confirm the zone and its lockers are saved and shown back correctly.

**Acceptance Scenarios**:

1. **Given** an admin is on the Locker Map screen, **When** they create a zone named "Aile Nord" on floor "2" and add locker numbers "201", "202", "203" to it, **Then** the map shows "Aile Nord" on floor "2" containing those three locker numbers.
2. **Given** a zone already exists with a name, **When** the admin edits and saves a new name for it, **Then** the zone is shown under its new name everywhere it appears, and its lockers are unchanged.
3. **Given** a locker number "203" is already declared in zone "Aile Nord" on floor "2", **When** the admin tries to declare "203" on floor "2" in a different zone, **Then** the attempt is rejected and the admin is told which zone already claims that locker.
4. **Given** a standard (non-admin) user is signed in, **When** they try to open the Locker Map screen, **Then** they are denied access.

---

### User Story 2 - Existing screens reject unknown locker numbers (Priority: P2)

A user enters or changes a locker number on their own locker profile, or an admin does the same on a user's behalf from the admin locker profile editor. The field itself stays a free-text box, exactly as before, but the save is only accepted if the floor + locker number pair the person typed is one an admin has declared in the Locker Map.

**Why this priority**: This is the enforcement half of the feature — it is what makes the map in User Story 1 matter, but it depends on that map existing first.

**Independent Test**: Can be fully tested by, with a known locker map in place, attempting to save a locker number that is not in the map (expect rejection with an explanatory message) and one that is in the map (expect success), on each of the two affected screens.

**Acceptance Scenarios**:

1. **Given** the Locker Map has no locker "999" declared on floor "2", **When** a user types floor "2" and locker number "999" into their locker profile and saves, **Then** the save is rejected and the user is told the locker number is not recognized.
2. **Given** the Locker Map has locker "203" declared on floor "2", **When** a user types floor "2" and locker number "203" into their locker profile and saves, **Then** the save succeeds.
3. **Given** an admin is editing another user's locker assignment from the admin locker profile editor, **When** the admin enters an unrecognized floor + locker number pair, **Then** the save is rejected the same way it would be for the user acting alone.
4. **Given** a user's saved floor and locker number are both already known to the map, **When** they change only their floor (leaving the same locker number text in the field) to a floor where that locker number is not declared, **Then** the save is rejected, because the pair — not either value alone — must be recognized.

---

### User Story 3 - Admin keeps the map current (Priority: P3)

As the building changes — a zone is renamed, a locker is removed from service, a new bank of lockers is added — an admin returns to the Locker Map screen to add, remove, or reorganize zones and their lockers.

**Why this priority**: Valuable for long-term upkeep, but the feature already delivers its core value (Stories 1 and 2) without this being exercised on day one.

**Independent Test**: Can be fully tested by removing a locker number from a zone (or deleting a zone outright) and confirming it no longer appears in the map, independent of any other story.

**Acceptance Scenarios**:

1. **Given** a zone contains locker "203", **When** the admin removes "203" from that zone, **Then** "203" no longer appears anywhere in the map for that floor.
2. **Given** a zone has no locker numbers left in it, **When** the admin deletes the zone, **Then** it no longer appears on that floor's list of zones.

---

### Edge Cases

- What happens when an admin tries to save a zone with a blank name? The save is rejected; a zone must have a name.
- What happens when an admin tries to name a zone the same as another zone already on the same floor? The save is rejected (FR-004a); the same name is accepted on a different floor.
- What happens when an admin tries to declare the same locker number twice within the same zone? The second entry is rejected as a duplicate, the same as a duplicate across two different zones on that floor.
- What happens when an admin deletes a zone that still has locker numbers declared in it? The zone and all of its locker numbers are deleted together in one action (FR-006); no separate emptying step is required.
- What happens when an admin deletes a zone, or removes a locker number from it, while a user's saved locker profile currently points at that exact floor + locker number? The user's own saved record is not changed or cleared by this action — but per FR-013, that pair is no longer recognized, so any future attempt to re-save that same locker number (by that user or an admin) is rejected until it is declared again.
- What happens when the same locker number text is typed with different capitalization or surrounding whitespace than how it was declared in the map? It is matched the same normalized way the site already matches locker numbers elsewhere (trimmed; case handling unchanged from today's behavior).
- What happens on a floor that has no zones declared yet? The map shows it as empty, and — per FR-013 — new locker number entries on that floor are rejected until an admin declares at least one zone and locker there.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a dedicated Locker Map screen that only admin users can open; a standard user attempting to access it MUST be denied.
- **FR-002**: The Locker Map screen MUST let an admin view the site organized by floor, and for each floor, the zones declared on it.
- **FR-003**: An admin MUST be able to create a new zone on a floor by giving it a name; the zone's floor is fixed at creation and cannot be changed afterward — relocating a zone means deleting it and creating a new one on the correct floor.
- **FR-004**: An admin MUST be able to edit (rename) an existing zone's name at any time from this screen; the zone's floor is not editable.
- **FR-004a**: A zone's name MUST be unique among the zones declared on the same floor; creating or renaming a zone to a name already used by another zone on that floor MUST be rejected. The same name MAY be reused on a different floor.
- **FR-005**: An admin MUST be able to declare, for any zone, the complete list of locker numbers that belong to it — adding locker numbers to the zone one at a time.
- **FR-006**: An admin MUST be able to remove a locker number from a zone, and to delete a zone entirely. Deleting a zone that still contains locker numbers MUST delete the zone and all of its locker numbers together, in one action, without requiring the admin to remove them individually first.
- **FR-007**: The system MUST enforce that a given floor + locker number pair is declared in at most one zone at a time, site-wide.
- **FR-008**: An attempt to declare a floor + locker number pair that is already claimed by another zone MUST be rejected, and the admin MUST be told which zone already claims it.
- **FR-009**: In both existing screens where a locker number is entered (the user's own locker profile, and the admin's locker profile editor for another user), the locker number field MUST remain free text — never a dropdown or a list limited to known values while typing.
- **FR-010**: Once at least one locker has ever been declared in the Locker Map, site-wide, saving a change to a user's floor and/or locker number on either existing screen MUST be rejected unless the resulting floor + locker number pair is currently declared in the Locker Map, and the rejection MUST tell the person the locker number is not recognized. While the Locker Map has never had anything declared in it at all, every floor + locker number pair MUST be accepted, exactly as it was before this feature existed (FR-013a).
- **FR-011**: A zone's floor MUST be chosen from the same set of floors already offered elsewhere on the site (the site's configured floor list when one exists, or free text when it does not) — a zone can never be declared on a floor the rest of the site does not also recognize.
- **FR-012**: The floor + locker number pair MUST remain the sole identity of a locker, exactly as enforced today; the zone name is a descriptive label attached to a locker and MUST NOT be considered when determining whether two lockers are the same or different.
- **FR-013**: At the moment this feature is released, and for as long afterward as the map remains empty, existing users' already-saved floor + locker number pairs MUST continue to display normally and MUST NOT be cleared or flagged as broken; once at least one locker has been declared anywhere in the map (FR-013a), re-saving a pair that is not itself declared (by that user, or by an admin on their behalf) is treated as a new entry and MUST be rejected under FR-010. Locker numbers already declared in the map before release are unaffected.
- **FR-013a**: The known-locker check in FR-010 MUST be permissive, not restrictive, while the Locker Map has never had a single locker declared in it, site-wide — matching how the site's other optional, admin-configured registries (the floor list, the locker number format) behave before their first use: absence of configuration MUST NOT be read as "nothing is allowed." The check becomes active, everywhere on the site at once, the moment an admin declares the first locker in any zone, on any floor.

### Key Entities

- **Zone**: A named group of lockers, located on exactly one floor. Attributes: name (admin-entered, editable, unique among zones on the same floor), the floor it belongs to (set once at creation, never editable afterward).
- **Locker Map Entry**: The declaration that a specific floor + locker number pair exists and belongs to a specific zone. This is the site's authoritative registry of which locker numbers exist; it is what every existing locker-number field is validated against. The floor + locker number pair is unique across the whole map; the zone is a label attached to that pair, not part of its identity.
- **Locker (existing entity)**: A user's own floor + locker number assignment, already unique on floor + locker number today. Unaffected in shape by this feature — only the validation applied when it is entered or changed is new.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An admin can determine, for any floor, exactly which zones and locker numbers are currently declared, without needing to ask anyone else or inspect data outside this screen.
- **SC-002**: 100% of attempts to save a floor + locker number pair that is not declared in the Locker Map are rejected, across every screen that accepts a locker number, with a message explaining the number is not recognized.
- **SC-003**: A locker number an admin adds to the map becomes acceptable on every existing screen immediately, with no delay or separate release step.
- **SC-004**: It is never possible for two zones to simultaneously claim the same floor + locker number — verified by confirming every such attempt is rejected.
- **SC-005**: Users entering a locker number they already know continue to do so by typing it into a plain text field, with no change to that interaction from before this feature existed.

## Assumptions

- "Administrator users" refers to the site's existing regular admin role (the same role gated on today throughout the admin section), not the narrower super-admin-only role reserved for the Danger Zone — the request's wording names admins generally, and this screen is ordinary content administration rather than a site-wide danger-zone setting.
- A zone's floor is drawn from the same floor source the rest of the site already uses (the configured floor list once the super admin has set one, or free text while none is configured), so this feature introduces no second notion of "floor."
- Locker numbers declared in the Locker Map remain subject to the site's existing locker-number format rule (when a super admin has configured one) — the map does not relax or duplicate that check.
- Zone names must be non-blank; no additional format is imposed on them beyond that.
- Lockers are added to and removed from a zone one number at a time from this screen; bulk/range entry (e.g., "201-220") is out of scope for this feature.
- This feature does not change how a locker's uniqueness is enforced (floor + locker number, already the case today) — it adds a second, independent check: that the pair is also a *known* one.
