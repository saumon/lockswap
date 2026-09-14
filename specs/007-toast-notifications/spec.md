# Feature Specification: Auto-Dismissing Popup Notifications

**Feature Branch**: `007-toast-notifications`

**Created**: 2026-09-14

**Status**: Shipped

**Input**: User description: "les messages d'infos du type \"Signed in successfully.\", \"Locker details saved.\", sont statiques et persistants. Il faut les remplacer par mes messages qui pop, mais qui disparaissent au bout de quelques secondes."

## Clarifications

### Session 2026-09-14

- Q: Should the 3-second auto-dismiss timer pause while the user is hovering over or has keyboard focus on a notification, so they get enough time to finish reading it? → A: Pause the 3-second timer on hover/focus, resume (or restart) it once the user moves away.
- Q: Should the popup notification still display if JavaScript is disabled in the browser, or can the system assume JavaScript is always available? → A: JavaScript is always available; no static fallback is required when JavaScript is disabled.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Success message pops and disappears automatically (Priority: P1)

A user completes an action that succeeds (signing in, saving their locker details, sending a swap proposal, etc.). Today, the confirmation message appears as a static block at the top of the page and stays there until the user navigates elsewhere. Instead, the user should see the confirmation appear as a popup notification that goes away on its own after a few seconds, without them having to do anything.

**Why this priority**: This is the core, most frequent case — success confirmations happen on nearly every user action (sign in, sign up, every form save) and are the messages the user explicitly called out as bothersome today.

**Independent Test**: Sign in to the app, or save locker details, and observe that the confirmation message appears as a popup and disappears by itself after a few seconds, without needing a page reload or navigation.

**Acceptance Scenarios**:

1. **Given** a user is on the sign-in page, **When** they sign in with valid credentials, **Then** a "Signed in successfully." popup notification appears and automatically disappears after a few seconds.
2. **Given** a user is on their locker profile page, **When** they save valid locker details, **Then** a "Locker details saved." popup notification appears and automatically disappears after a few seconds.
3. **Given** a popup notification is currently visible, **When** the auto-dismiss delay elapses, **Then** the notification disappears without the user clicking anything and without affecting the surrounding page content.

---

### User Story 2 - Error message pops and disappears automatically (Priority: P2)

A user performs an action that fails or is refused (e.g. an invalid swap proposal, a locker save that's rejected). They should see the error explained as a popup notification, visually distinct from success messages, that also disappears on its own after a few seconds rather than sitting permanently on the page.

**Why this priority**: Error/alert messages use the same static banner mechanism as success messages today, so they need the same fix; slightly lower priority than P1 since they occur less often.

**Independent Test**: Trigger a failing action (e.g. submit an invalid swap proposal) and confirm the error appears as a popup, visually distinguishable from a success popup, and disappears automatically.

**Acceptance Scenarios**:

1. **Given** a user submits an action that fails validation, **When** the page reloads with the error, **Then** an error popup notification appears, styled distinctly from success notifications, and automatically disappears after a few seconds.
2. **Given** an error popup notification is visible, **When** the user takes no action, **Then** it disappears on its own without leaving empty space or a lingering static block on the page.

---

### User Story 3 - Manually dismiss a notification early (Priority: P3)

A user who has already read a popup notification wants to close it immediately instead of waiting for the automatic timeout.

**Why this priority**: A nice-to-have convenience on top of the automatic dismissal; not essential to solving the core "static and persistent" complaint, but a standard expectation for popup notifications.

**Independent Test**: Trigger any popup notification and click its close control; confirm it disappears immediately instead of waiting out the full delay.

**Acceptance Scenarios**:

1. **Given** a popup notification is visible, **When** the user clicks its dismiss control, **Then** the notification disappears immediately.

---

### Edge Cases

- What happens when two actions in quick succession each produce a message (e.g. a redirect chain)? Notifications must stack or queue so each one is readable rather than overwriting or hiding another.
- How does the system handle a very long message? The popup must remain readable (wrap text) rather than being cut off or breaking the page layout.
- What happens if the user navigates to another page while a notification is still visible? The notification for the previous page's action should not persist onto an unrelated page.
- How is the notification announced to assistive technology (screen readers), given it now appears and disappears automatically rather than sitting as static page content?
- What happens when the user hovers over or focuses a notification just before it would auto-dismiss? The countdown must pause so it doesn't disappear mid-read, then resume once the user moves away.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display success/informational messages (e.g. "Signed in successfully.", "Locker details saved.") as popup notifications instead of static inline banners embedded in the page content.
- **FR-002**: System MUST display error/alert messages using the same popup notification mechanism, visually distinguished from success/informational messages (consistent with today's success-vs-error color distinction).
- **FR-003**: System MUST automatically dismiss each popup notification 3 seconds after it appears, with no user interaction required. While the user is hovering over or has keyboard focus on the notification, the countdown MUST pause; it MUST resume once the user moves the pointer or focus away.
- **FR-004**: System MUST allow the user to manually dismiss a popup notification before the automatic timeout elapses.
- **FR-005**: Popup notifications MUST NOT shift, resize, or permanently occupy space within the page's main content layout, whether shown or after being dismissed.
- **FR-006**: System MUST support all existing message trigger points using the new popup mechanism, including sign-in, sign-out, sign-up, password change, account update, email confirmation, account unlock, locker profile save, locker wish save/cancel, and all swap proposal actions (send, withdraw, accept, decline, confirm, and related refusals).
- **FR-007**: When more than one message is triggered for the same page load, the system MUST present them all to the user (e.g. stacked) rather than showing only the last one or silently dropping any.
- **FR-008**: Popup notifications MUST remain perceivable by assistive technology (announced to screen readers) despite appearing and disappearing automatically.
- **FR-009**: The wording of existing messages MUST remain unchanged; only how they are presented and how long they remain visible changes.

### Key Entities

- **Popup Notification**: A transient message shown to the user after an action. Attributes: message text, type (success/informational vs. error), appearance time, and a fixed 3-second auto-dismiss delay. Replaces the current static flash banner as the sole way these messages are shown.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of existing success and error messages (sign-in, sign-out, sign-up, password/account changes, locker profile, locker wishes, swap proposals) are delivered as popup notifications instead of static banners.
- **SC-002**: Every popup notification disappears on its own within 3-4 seconds of appearing, without the user needing to interact with it.
- **SC-003**: After a popup notification disappears, no empty gap, leftover static text, or layout shift remains on the page.
- **SC-004**: Users can distinguish a success notification from an error notification at a glance, without reading the full text, in usability checks.
- **SC-005**: When two messages occur for the same page load, both are visible to the user at some point (none are silently lost).

## Assumptions

- The 3-second auto-dismiss delay applies uniformly to both success and error notifications (user confirmed this duration; no separate longer duration for errors).
- Only the presentation and timing of these messages changes — the message text/wording for each existing trigger point stays the same.
- Exact visual placement (e.g. corner of the screen) and animation style are implementation details left to design/engineering, as long as notifications are clearly visible popups rather than static in-page content.
- No persistent history or log of past notifications is required; once a notification is dismissed (automatically or manually), it is gone.
- This feature covers presentation of existing message types only; it does not introduce new categories of messages or new trigger points beyond those that already exist in the application today.
- The system may assume JavaScript is always available in the user's browser; no static/no-JS fallback rendering of messages is required.
