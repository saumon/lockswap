# Feature Specification: Looping Logo Fade Animation

**Feature Branch**: `011-logo-fade-loop`

**Created**: 2026-09-15

**Status**: Shipped

**Input**: User description: "Le logo de la page de connexion doit avoir une animation de \"fading\" qui tourne en boucle afin d'attirer l'oeil (actuellement, l'animation ne tourne pas en boucle). L'animation doit également être appliquée sur le logo réduit dans la barre du haut une fois connecté au site."

## Clarifications

### Session 2026-09-15

- Q: Comment l'animation de fondu doit-elle se comporter visuellement une fois en boucle ? → A: Pulsation douce d'opacité — le logo oscille en continu entre pleine opacité et une opacité réduite, sans répéter l'effet de flou/échelle de l'entrée actuelle.
- Q: Une fois connecté, le logo réduit de la barre du haut doit-il boucler indéfiniment sur toutes les pages, ou seulement de façon limitée ? → A: Boucle indéfinie partout — le logo réduit pulse en continu tant qu'il est affiché, sur toutes les pages, sans s'arrêter.
- Q: Should there be a visible on-screen control letting any user pause or stop the continuous pulsing animation, separate from the OS-level "reduce motion" setting? → A: No dedicated pause control — the OS "reduce motion" preference (FR-007) remains the only way to stop the animation.
- Q: How dim should the logo get at the low point of each pulse, before it fades back up to full opacity? → A: Dim to ~60% opacity — a moderate, clearly noticeable pulse.
- Q: How fast should each fade cycle be — how long does one full dim-and-brighten pulse take? → A: ~3s per cycle — a calm, deliberate "breathing" pulse.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Eye-catching logo on the sign-in/sign-up screen (Priority: P1)

A visitor lands on the sign-in or sign-up screen. Instead of the logo fading in once and then sitting static, the logo keeps gently pulsing — fading between full brightness and a slightly dimmed state — for as long as the screen is on display, drawing the visitor's eye to the brand.

**Why this priority**: This is the core of the request — the current one-shot fade is barely noticeable, and the whole point of the change is to make the brand mark catch attention on the screen where a new or returning visitor forms their first impression.

**Independent Test**: Can be fully tested by opening the sign-in screen (or the sign-up screen), waiting a few seconds, and confirming the logo continues to visibly pulse in opacity rather than settling into a static state after its first appearance.

**Acceptance Scenarios**:

1. **Given** a visitor opens the sign-in screen, **When** the entrance animation finishes, **Then** the logo continues to pulse in opacity indefinitely instead of remaining static.
2. **Given** a visitor opens the sign-up screen, **When** they stay on the screen, **Then** the same continuous pulsing behavior is visible on its logo.
3. **Given** the pulsing animation is running, **When** it completes a cycle, **Then** it seamlessly starts the next cycle with no visible jump, flash, or pause.

---

### User Story 2 - Consistent brand animation in the signed-in header (Priority: P2)

A user who is signed in sees the small logo mark in the site's top header. That reduced logo also gently pulses in opacity, continuously, matching the same eye-catching effect used on the sign-in screen, on every page of the site.

**Why this priority**: This extends the same brand treatment to the always-visible, signed-in part of the site, keeping the brand consistently alive wherever it appears. It reuses the same pulsing effect as User Story 1, but does not require User Story 1 to be built first — the pulse itself is shared, reusable groundwork, so the two stories can be delivered in either order or in parallel.

**Independent Test**: Can be fully tested by signing in, opening any page, and confirming the small logo in the top header pulses in opacity the same way as the sign-in screen's logo, and continues to do so while navigating between pages.

**Acceptance Scenarios**:

1. **Given** a signed-in user is on any page of the site, **When** they look at the top header, **Then** the reduced logo mark is continuously pulsing in opacity.
2. **Given** a signed-in user navigates from one page to another, **When** the new page loads, **Then** the header logo's pulsing animation is present and running on the new page as well.

---

### Edge Cases

- A visitor or user with a system-level "reduce motion" preference enabled sees the logo at a stable, fully opaque resting state with no pulsing animation, consistent with how the rest of the site already respects that preference.
- The pulsing animation must not affect layout (no shifting of surrounding elements) and must not make the logo fully disappear at any point in the cycle — it stays legible and clickable throughout.
- The header logo remains a fully functional link back to the homepage at every point in the pulse cycle; the animation must not interfere with clicking, tapping, or keyboard-focusing it.
- On the sign-in/sign-up screens, the existing one-time entrance effect (blur and scale settling into place) still plays first; the continuous opacity pulse begins only once that entrance has finished, so the two effects do not visually overlap or compound.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The logo mark on the sign-in screen MUST continuously loop a fading (opacity pulse) animation for as long as the screen remains displayed, rather than animating once and stopping.
- **FR-002**: The logo mark on the sign-up screen MUST have the same continuously looping fading animation as the sign-in screen.
- **FR-003**: The reduced logo mark shown in the site's top header MUST continuously loop the same fading animation, on every page, whenever a user is signed in.
- **FR-004**: The looping fade animation MUST oscillate the logo's opacity between full opacity (100%) and approximately 60% opacity at the low point of the pulse, rather than repeating the existing one-time blur/scale entrance effect.
- **FR-005**: The looping fade animation MUST run indefinitely (no fixed number of cycles or timeout) as long as the logo is visible on screen, with each full dim-and-brighten cycle taking approximately 3 seconds.
- **FR-006**: The existing one-time entrance effect on the sign-in/sign-up screens MUST still play once when the screen first appears; the continuous fading loop MUST take over only after that entrance effect completes.
- **FR-007**: The looping fade animation MUST be suppressed (logo shown static, at full opacity) for users whose system indicates a preference for reduced motion, consistent with existing motion handling elsewhere on the site. This reduced-motion preference is the only mechanism to stop the animation; no dedicated on-screen pause/stop control is provided.
- **FR-008**: The looping fade animation MUST NOT alter the logo's size, position, or the surrounding layout at any point in its cycle.
- **FR-009**: The header logo MUST remain a fully clickable/tappable/focusable link to the homepage while the fading animation is running.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the sign-in and sign-up screens, the logo's opacity is measurably cycling between 100% and ~60% on a ~3-second cadence at any point sampled at least 10 seconds after the screen loads, rather than appearing static.
- **SC-002**: On every page of the signed-in site, the header logo's opacity is measurably cycling the same way at any point sampled during a normal browsing session.
- **SC-003**: Users with reduced-motion preferences enabled see a fully static logo in both locations, with zero animated opacity change.
- **SC-004**: The looping animation introduces no layout shift and no loss of clickability of the header logo, verified across the site's supported pages.

## Assumptions

- The definition of "fading" loop is a continuous opacity pulse (e.g., full opacity dimming to a reduced-but-visible opacity and back), not a repeat of the current blur+scale entrance effect — confirmed via clarification.
- The header logo should loop indefinitely on every page while signed in, matching the literal request, rather than only for a limited time after each page load — confirmed via clarification.
- The dimmed end of the pulse (~60% opacity) stays well above fully transparent, so the logo never disappears or becomes illegible at any point in the cycle.
- The pace of the pulse (~3 seconds per cycle) is slow and gentle enough to read as a calm "breathing" effect meant to draw attention, not a fast blink or flash that could be distracting or trigger photosensitivity concerns.
- The existing reduced-motion handling pattern already present in the codebase (disabling non-essential animation for users who request it) extends to this new looping animation without needing a separate opt-out mechanism.
- This change affects only the visual/motion treatment of the existing logo marks; no change to the logo's artwork, the sign-in/sign-up page content, or the header's other elements is in scope.
