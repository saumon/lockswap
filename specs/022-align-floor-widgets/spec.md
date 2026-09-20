# Feature Specification: Compact floor/locker label alignment

**Feature Branch**: `022-align-floor-widgets`

**Created**: 2026-09-20

**Status**: Draft

**Input**: User description: "afin d'optimiser et compacter l'affichage, applique ces modifications : dans la section 'Your locker search', aligne le numéro d'étage avec le wording 'Looking for a locker on floor' ; dans la section 'Your Locker', en vue mobile, aligne l'étage et le numéro d'étage avec les wordings ; sur la page d'accueil, en mode connecté, la carte 'Your Locker' ne doit pas être sous forme de carte"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Read the searched floor at a glance (Priority: P1)

A signed-in user with an active locker wish looks at the "Your locker search" section to confirm which floor they are looking for. Today the floor number sits on its own line under the sentence "Looking for a locker on floor", so the eye has to travel down before the answer is visible. The number should sit on the same line as the sentence, so the whole statement reads as one continuous line: "Looking for a locker on floor <number>".

**Why this priority**: This is the most frequently seen piece of information on both the homepage and the dedicated locker-wishes page, and the fix is the simplest, highest-visibility win toward a more compact page.

**Independent Test**: Open the homepage (or the locker wishes page) as a user with a saved locker wish, and confirm the floor number appears inline with the sentence rather than stacked beneath it, at any screen width.

**Acceptance Scenarios**:

1. **Given** a signed-in user with a persisted locker wish, **When** they view the "Your locker search" section on the homepage, **Then** the floor number appears on the same line as "Looking for a locker on floor", immediately after the sentence.
2. **Given** the same section on the dedicated locker wishes page, **When** the user views it, **Then** the floor number likewise appears inline with the sentence, matching the homepage presentation.
3. **Given** the section viewed on a narrow (mobile) screen, **When** the sentence and number are long enough to wrap, **Then** the number still reads as part of the same statement rather than as an orphaned line.

---

### User Story 2 - Compact locker details on mobile (Priority: P2)

A signed-in user opens the homepage on a phone and looks at "Your locker" to check their floor and locker number. Today each value ("Floor", locker number) stacks its label above its value, so the two fields take four lines total. The label and its value should sit on the same line for each field, so the block reads as two compact lines instead of four.

**Why this priority**: This is the second-most-seen block on the homepage; compacting it on mobile directly serves the goal of a denser, less scroll-heavy page on small screens, where vertical space is scarcest.

**Independent Test**: View the "Your locker" section on a mobile-width screen as a user with a saved floor, and confirm "Floor" and its number share one line, and "Locker number" and its value share one line.

**Acceptance Scenarios**:

1. **Given** a signed-in user with a saved floor and locker number, **When** they view "Your locker" on a mobile-width screen, **Then** the floor label and the floor number appear on the same line.
2. **Given** the same user, **When** they view the locker number field on a mobile-width screen, **Then** the "Locker number" label and its value (or the "No locker assigned" placeholder, if none is set) appear on the same line.
3. **Given** the same section viewed on a desktop-width screen, **When** the user compares it to before this change, **Then** the existing side-by-side presentation of the two fields is unaffected.

---

### User Story 3 - A lighter-weight "Your locker" block on the homepage (Priority: P3)

A signed-in user with a saved floor lands on the homepage. Today "Your locker" is boxed in the same bordered card treatment as every other section, which adds visual weight and makes the page read as a longer stack of boxes than it needs to. On the homepage specifically, this block should sit directly on the page background as plain content — no border, no panel, no side accent — while keeping its heading and information intact, so the page feels shorter and less boxy at a glance.

**Why this priority**: This is a page-level visual simplification; it depends on nothing else in this feature and is the most cosmetic of the three changes, so it is safe to land last without blocking the more information-dense fixes above.

**Independent Test**: Sign in as a user with a saved floor, open the homepage, and confirm "Your locker" no longer has a card border/background while every other homepage section (e.g. "Your locker search") still does.

**Acceptance Scenarios**:

1. **Given** a signed-in user with a saved floor, **When** they view the homepage, **Then** the "Your locker" block appears as plain content on the page background, without a card border or background panel.
2. **Given** the same homepage, **When** the user views the "Your locker search" section above it, **Then** that section is unchanged and still appears as a bordered card.
3. **Given** a signed-in user who has not yet set a floor, **When** they view the homepage's "Add your locker details" prompt, **Then** that block is unaffected by this change (it is a different section from "Your locker").

---

### Edge Cases

- A user has no active locker wish: the "Your locker search" section shows a call-to-action instead of a floor value, so the inline-alignment change in Story 1 does not apply — no floor number is present to align.
- A user has a saved floor but no locker number assigned: the "No locker assigned" placeholder must still align inline with the "Locker number" label on mobile, the same as a real value would.
- A very long floor or locker number value on a narrow screen: the label and value must stay legible and not overlap or truncate silently when they wrap.
- The homepage locker is currently locked by an active swap proposal: the read-only "locked" notice that follows "Your locker" is a separate block and is unaffected by removing the card treatment from "Your locker" itself.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: In the "Your locker search" section, wherever it appears (homepage and the dedicated locker wishes page), the system MUST display the floor number inline with the sentence "Looking for a locker on floor", on the same line, rather than on a separate line beneath it.
- **FR-002**: In the "Your locker" section, on mobile-width screens, the system MUST display each field's label and its value (Floor and its number; Locker number and its value or placeholder) on the same line, rather than the value appearing on a line below the label.
- **FR-003**: The existing desktop-width presentation of the "Your locker" section's two fields (currently shown side by side) MUST be preserved; this change is scoped to the mobile stacking behavior only.
- **FR-004**: On the homepage, when a signed-in user has a saved floor, the "Your locker" block MUST be displayed as plain page content, without the bordered/background card container used elsewhere on the page.
- **FR-005**: The "Your locker" block's heading and information (floor, locker number, or "No locker assigned" placeholder) MUST remain fully visible and correctly labeled after removing its card container.
- **FR-006**: All other homepage sections that currently use the card treatment (including "Your locker search" and the "Add your locker details" prompt for users without a saved floor) MUST be unaffected by this change and continue to appear as cards.
- **FR-007**: The "Your locker" section on any page other than the homepage (if it exists elsewhere) is out of scope for the card-removal change in FR-004; only the homepage presentation changes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On any screen width, a user can read the floor being searched for without looking below the sentence that introduces it — the number is part of the same line.
- **SC-002**: On a mobile-width screen, the "Your locker" section occupies two visual lines of label-plus-value (one for floor, one for locker number) instead of the current four.
- **SC-003**: The homepage's "Your locker" block no longer contributes a bordered/boxed visual unit to the page, while every other homepage section keeps its existing card appearance, verified by visual comparison before and after the change.
- **SC-004**: 100% of the floor and locker-number information currently shown is still present and correctly labeled after the layout changes — no information is lost or misattributed.

## Assumptions

- "Your locker search" refers to the locker-wish summary shown both on the homepage and on the dedicated locker wishes page; since both are driven by the same underlying markup, the alignment fix in FR-001 applies to both.
- "Your Locker" (as named by the user) refers to the section titled "Your locker" that shows the signed-in user's saved floor and locker number on the homepage.
- "Mobile view" follows the project's existing single responsive breakpoint; below that breakpoint is mobile, at or above it is desktop, consistent with how the rest of the site already defines the split.
- Only the "Your locker" block on the homepage loses its card container. The "Your locker search" card and the "Add your locker details" card (shown to users without a saved floor yet) are different sections and keep their existing card treatment, since the user's request named "Your Locker" specifically.
- Removing the card container from "Your locker" is a visual simplification only; the heading text ("Your locker") continues to identify the block as belonging to the signed-in user, so no replacement visual cue is required beyond the existing wording.
