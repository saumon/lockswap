# Feature Specification: Modernized Toast Notifications

**Feature Branch**: `023-toast-redesign`

**Created**: 2026-09-20

**Status**: Draft

**Input**: User description: "améliore tous les messages de toast de l'app. Inspire toi de ce qui se fait de plus moderne et de mieux (taille, couleur, placement)"

## Clarifications

### Session 2026-09-20

- Q: Où les notifications toast doivent-elles apparaître à l'écran ? → A: Bas-droite, en position fixe — remplace la position haut-droite actuelle ancrée sous le header.
- Q: Le redesign doit-il introduire des icônes de type (succès/erreur), ou rester sur couleur + texte seul ? → A: Introduire une icône de type par notification (en plus de la couleur et du texte), en cohérence avec les toasts modernes actuels.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A notification looks and feels current (Priority: P1)

A user completes an action that produces a confirmation or an error (signing in, saving locker details, sending a swap proposal, etc.). Today the popup that appears is a plain white box with a thin colored line down one edge — functional, but visually dated next to the rest of the redesigned app. The user should see a notification that feels like it belongs to a well-designed, contemporary product: right-sized (not a tiny strip, not an oversized block), with generous but not wasteful spacing, and a shape and finish consistent with the app's own visual language.

**Why this priority**: This is the entire point of the request — the notification is the most frequently seen transient UI element in the app, and it currently looks the most out of step with the rest of the redesigned interface.

**Independent Test**: Trigger any confirmation (e.g. sign in) and any error (e.g. an invalid form submit) and visually compare the resulting notification against the rest of the app's redesigned components (cards, buttons); it should read as part of the same design, not a leftover from an earlier version.

**Acceptance Scenarios**:

1. **Given** a user triggers a success action, **When** the notification appears, **Then** its size, spacing, and finish are visually consistent with the rest of the redesigned interface rather than the previous plain-box treatment.
2. **Given** a user triggers an error action, **When** the notification appears, **Then** it is immediately distinguishable from a success notification through color and iconography, not color alone.

---

### User Story 2 - A notification never gets in the way (Priority: P2)

A user is reading or interacting with the page when a notification appears (their own action, or a background update). The notification must appear in a location that is predictable, never covers navigation or the control the user is about to use, and stays out of the way whether the user is on a phone or a desktop screen.

**Why this priority**: Placement is one of the three dimensions the request explicitly calls out, and a poorly placed notification actively interferes with the task the user is doing, which is worse than a merely dated one.

**Independent Test**: Trigger a notification on a wide screen and on a narrow (phone-width) screen; confirm in both cases it does not overlap the navigation, does not require scrolling to dismiss, and does not block the control the user just used.

**Acceptance Scenarios**:

1. **Given** a user on a desktop-width screen, **When** a notification appears, **Then** it appears fixed to the bottom-right corner of the screen, never overlapping the navigation bar or the primary content the user is reading.
2. **Given** a user on a phone-width screen, **When** a notification appears, **Then** it remains fully visible, fully readable, and does not require horizontal scrolling or cover interactive controls.

---

### User Story 3 - Several notifications stay legible together (Priority: P3)

A sequence of actions (for example a redirect chain, or two quick form submissions) produces more than one notification. The user should be able to read each one without them overlapping, crowding illegibly, or making the screen feel cluttered — a common failure point in older toast implementations.

**Why this priority**: Less frequent than a single notification, but the current implementation already stacks notifications, so this is about making that stack feel orderly and modern rather than introducing new behavior.

**Independent Test**: Trigger two or more notifications in quick succession (e.g. a redirect chain) and confirm each is fully legible, clearly separated, and the newest is easy to tell apart from older ones.

**Acceptance Scenarios**:

1. **Given** two notifications are triggered for the same page load, **When** both appear, **Then** they are visually stacked with clear separation and neither obscures the other.
2. **Given** three or more notifications are visible at once, **When** the user scans them, **Then** each remains fully readable without clipping or overlap.

---

### Edge Cases

- What happens with a very long message? It must wrap onto multiple lines within the notification's width rather than being clipped, growing the page, or forcing horizontal scroll.
- What happens when a user has "reduce motion" enabled? The notification must still appear and remain fully visible and readable; only the entrance/exit motion is simplified, never removed to the point of the message flashing in and out instantly or not appearing at all.
- What happens when many notifications (5+) queue up in quick succession? They must remain individually readable — this may mean capping the number visible at once and revealing the rest as earlier ones clear, rather than degrading legibility.
- What happens at the boundary between the app's two supported widths (just above/below the 48rem breakpoint)? The notification's placement and size must transition without a jarring jump or a moment where it is unreadable.
- What happens to a notification already on screen when the user resizes the browser or rotates their phone? It must re-settle into the correct position for the new width rather than being left stranded off-screen or over content.
- What happens on a short viewport (e.g. a phone in landscape, or a tall form filling the screen) where a bottom-anchored notification could otherwise land on top of the page's own bottom controls? The notification must never cover an active or about-to-be-used control; per FR-003 this is the same "never overlaps content the user is interacting with" guarantee, just at the screen's short axis instead of its width.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST present success and error notifications with sizing, spacing, and finish visually consistent with the rest of the app's current (redesigned) visual language, replacing the current plain white box treatment.
- **FR-002**: System MUST distinguish a success notification from an error notification through more than one signal at once (color plus an icon plus the message wording) so type is legible at a glance and never depends on color alone.
- **FR-003**: System MUST display notifications fixed to the bottom-right corner of the screen, never overlapping the primary navigation or the content the user is actively reading or interacting with, at every supported screen width.
- **FR-004**: System MUST animate a notification's appearance and departure so it feels responsive and intentional rather than abrupt, consistent with the app's existing motion behavior elsewhere.
- **FR-005**: When more than one notification is visible at the same time, System MUST arrange them in a clearly ordered stack with visible separation between them, with no overlap or clipping.
- **FR-006**: System MUST preserve all existing notification behaviors unchanged by this visual redesign: automatic dismissal after the same delay, the countdown pausing on hover or keyboard focus, a manual dismiss control, and the notification being announced to assistive technology.
- **FR-007**: System MUST continue to show notifications without shifting, resizing, or permanently occupying space within the page's main content layout, whether shown or after being dismissed.
- **FR-008**: The redesign MUST reuse the app's existing color and typography system; it MUST NOT introduce colors or fonts defined solely for notifications.
- **FR-009**: Every notification MUST meet at least a 4.5:1 text-to-background contrast ratio in its new visual treatment.
- **FR-010**: System MUST cap how many notifications are shown at once and reveal any further queued notification only as an earlier one clears, so a burst of triggered messages never renders illegibly crowded.
- **FR-011**: The wording of existing messages MUST remain unchanged; only their visual presentation, sizing, and placement change.

### Key Entities

- **Toast Notification**: A transient message shown after a user action. Attributes: message text, type (success or error), an icon representing that type, appearance timing, and the same fixed auto-dismiss delay already in place. This redesign changes its size, color treatment, iconography, and on-screen position — not its triggers, timing, or wording.
- **Notification Queue**: The ordered backlog of notifications waiting for a slot when the visible cap (FR-010) is already full. Not a separate object the user sees — it governs only *when* a triggered notification actually appears, never whether it appears.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a side-by-side comparison against the previous design, at least 80% of reviewers judge the new notification as more visually consistent with the rest of the app.
- **SC-002**: Users can correctly identify whether a notification is a success or an error within 1 second of it appearing, without reading the full message text.
- **SC-003**: At the narrowest supported screen width, 100% of triggered notifications remain fully visible and legible with no horizontal scrolling and no overlap with navigation or interactive controls.
- **SC-004**: When 3 or more notifications are triggered in quick succession, every one of them is fully readable (no clipping, no full overlap) at some point before it dismisses.
- **SC-005**: The redesign introduces zero new raw color values or fonts outside the app's existing design tokens, confirmed by code review.
- **SC-006**: The time between a notification appearing and it becoming fully legible (finishing its entrance) stays within the app's existing sub-second interaction budget, so the redesign does not make notifications feel slower to read.

## Assumptions

- The two existing notification categories — success and error — remain the only categories in scope; introducing additional categories (e.g. a neutral/informational style) is out of scope for this redesign even though the app's design system already defines tokens for them.
- Bottom-right, fixed placement (resolved in Clarifications) replaces the current top-right, header-anchored position; this removes the notification layer's coupling to the header's published height, which planning should account for as a layout simplification rather than a risk.
- Type icons (resolved in Clarifications) are a new visual pattern for this app — no existing component (badges, cards) uses an icon today, they rely on color plus text alone. Introducing an icon here is scoped narrowly to toast notifications and does not obligate icons anywhere else in the app. FR-008's "no new colors or fonts" constraint does not extend to iconography, which this redesign is explicitly adding.
- All visual values (colors, spacing, radii, type sizes) draw from the app's existing design tokens; no new palette or type scale is introduced.
- Existing trigger points (sign-in, sign-out, sign-up, password/account changes, locker profile, locker wishes, swap proposals) are unchanged; this feature is a visual and placement redesign of the existing mechanism, not a new set of triggers.
- The existing 3-second auto-dismiss, hover/focus pause, manual dismiss, and screen-reader announcement behaviors are retained as-is; only appearance and placement are in scope.
- A reasonable cap on simultaneously visible notifications (FR-010) is a UX safeguard for rare bursts (e.g. redirect chains); the exact number is a planning-level detail, not a user-facing decision point.
