# Feature Specification: Homepage Locker Wish Block

**Feature Branch**: `010-homepage-locker-wish-block`

**Created**: 2026-09-15

**Status**: Shipped

**Input**: User description: "Un utilisateur connecté doit voir sur la page d'acceuil un bloc montrant son souhait de locker. Le bloc affiche soit le souhait de lock si celui-ci a été exprimé + un bouton \"Review locker wishes! 🥷\", soit un bouton avec le libellé \"I want to switch my locker! 👀\", soit afficher \"I want a locker! 🙏\" si l'utilisateur n'en n'a pas. Le bouton doit redigirer vers la page \"locker_wishes\"."

## Clarifications

### Session 2026-09-15

- Q: When the user has no locker and no wish, should "I want a locker! 🙏" be a clickable button leading to the locker wishes page, or plain text with no action? → A: A button leading to the locker wishes page, exactly like the other two states.
- Q: Should a brand-new user who has not yet filled in the "Add your locker details" card already see the locker wish block? → A: No — the block appears only once locker details are saved (a locker, or the "I don't have a locker" answer).
- Q: Where on the homepage should the block sit? → A: After the swap-proposal sections, immediately above the locker details card.
- Q: In the wish state, should the block show only the floor sought, or also the user's current floor and locker number? → A: Only the floor sought — the locker details card directly below already shows what they have.
- Q: Should the "I want to switch my locker! 👀" state still appear while an active swap proposal freezes the user's locker details? → A: Yes — the block behaves identically regardless of any active proposal; wishes and proposals are independent.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See my declared wish on the homepage (Priority: P1)

A logged-in user who has already declared a locker wish lands on the homepage and immediately sees a block stating the wish they expressed — the floor they are looking for a locker on — together with a "Review locker wishes! 🥷" button that takes them to the locker wishes page, where they can see everyone else's wishes and manage their own.

**Why this priority**: This is the core of the request. A wish that is invisible from the homepage is a wish the user forgets they made; surfacing it is what turns the homepage into the place where the swap conversation starts.

**Independent Test**: Can be fully tested by logging in as a user who has an active wish, opening the homepage, confirming the block shows the floor that user is looking on, and confirming the "Review locker wishes! 🥷" button leads to the locker wishes page.

**Acceptance Scenarios**:

1. **Given** a logged-in user with an active locker wish, **When** they open the homepage, **Then** a locker wish block is shown that states the floor they are looking for a locker on.
2. **Given** a logged-in user with an active locker wish, **When** they look at that block, **Then** it offers a single button labelled "Review locker wishes! 🥷".
3. **Given** a logged-in user with an active locker wish, **When** they activate the "Review locker wishes! 🥷" button, **Then** they arrive on the locker wishes page.
4. **Given** a logged-in user whose wish floor was changed or cancelled on the locker wishes page, **When** they return to the homepage, **Then** the block reflects the current state (updated floor, or the no-wish variant after cancellation) rather than the previous one.

---

### User Story 2 - Be invited to switch when I already have a locker (Priority: P2)

A logged-in user who has a locker of their own but has not declared any wish sees the same homepage block offering a single button labelled "I want to switch my locker! 👀", which takes them to the locker wishes page where the wish can be declared.

**Why this priority**: It is the entry point that converts a locker holder into a swap candidate, but the feature already delivers value through User Story 1 alone.

**Independent Test**: Can be fully tested by logging in as a user who has a locker number on file and no active wish, opening the homepage, and confirming the block shows the "I want to switch my locker! 👀" button and that it leads to the locker wishes page.

**Acceptance Scenarios**:

1. **Given** a logged-in user with a locker on file and no active wish, **When** they open the homepage, **Then** the locker wish block shows a button labelled "I want to switch my locker! 👀" and no wish details.
2. **Given** that user, **When** they activate that button, **Then** they arrive on the locker wishes page.
3. **Given** that user declares a wish on the locker wishes page, **When** they return to the homepage, **Then** the block now shows their declared wish and the "Review locker wishes! 🥷" button instead.

---

### User Story 3 - Be invited to ask for a locker when I have none (Priority: P3)

A logged-in user who has saved their locker details, has no locker of their own, and has not declared any wish sees the same homepage block offering a single button labelled "I want a locker! 🙏", which takes them to the locker wishes page.

**Why this priority**: It serves users who have nothing to swap yet; valuable for onboarding, but the smallest slice of the three and fully independent of the other two.

**Independent Test**: Can be fully tested by logging in as a user who has saved their details with no locker number and has no active wish, opening the homepage, and confirming the block shows the "I want a locker! 🙏" button and that it leads to the locker wishes page.

**Acceptance Scenarios**:

1. **Given** a logged-in user who has saved their locker details with no locker number and has no active wish, **When** they open the homepage, **Then** the locker wish block shows a button labelled "I want a locker! 🙏" and no wish details.
2. **Given** a logged-in user who has never saved any locker details, **When** they open the homepage, **Then** no locker wish block is shown at all, and only the "Add your locker details" card asks for their input.
3. **Given** a user in the state of scenario 1, **When** they activate that button, **Then** they arrive on the locker wishes page.
4. **Given** that user declares a wish on the locker wishes page, **When** they return to the homepage, **Then** the block now shows their declared wish and the "Review locker wishes! 🥷" button instead.

---

### Edge Cases

- What happens when a user has an active wish **and** no locker of their own? The declared wish takes precedence: the block shows the wish and the "Review locker wishes! 🥷" button, never one of the two invitation buttons.
- What happens when a user has an active wish **and** a locker of their own? Same as above — the wish state wins over the "switch" invitation.
- What happens when a user has not yet recorded any locker details at all (brand-new account still on the "Add your locker details" screen)? No block is shown at all — not even the "I want a locker! 🙏" state — until they have saved their details.
- What happens when a user has saved a floor but explicitly no locker number (the "I don't have a locker" answer)? Their details count as saved, so the block is shown, and they count as having no locker — "I want a locker! 🙏".
- How does the system handle an anonymous (not logged-in) visitor? The block is never rendered to them; the homepage remains unavailable to visitors who are not logged in.
- What happens when the user has a swap proposal in flight? The wish block is unaffected: it keeps showing whichever of the three states applies — including the "I want to switch my locker! 👀" invitation — even though the locker details card below it is frozen for editing.
- Exactly one of the three states is ever displayed — the block never shows two buttons, and never shows none.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The homepage MUST show a locker wish block to every logged-in user who has saved their locker details, in exactly one of three mutually exclusive states.
- **FR-001a**: The block MUST NOT be shown to a user who has not yet saved any locker details — the first-time "Add your locker details" screen stays a single-task screen. Saving those details, by either path (a locker, or "I don't have a locker"), makes the block appear on the next homepage view.
- **FR-002**: When the user has an active locker wish, the block MUST display that wish — the floor the user is looking for a locker on — as it is currently recorded, and nothing more. It MUST NOT repeat the user's own current floor or locker number, which the locker details card below it already shows.
- **FR-003**: When the user has an active locker wish, the block MUST offer a single control labelled exactly "Review locker wishes! 🥷".
- **FR-004**: When the user has no active locker wish and has a locker of their own on file, the block MUST offer a single control labelled exactly "I want to switch my locker! 👀" and MUST NOT display any wish details.
- **FR-005**: When the user has no active locker wish and has no locker of their own on file, the block MUST offer a single control labelled exactly "I want a locker! 🙏" and MUST NOT display any wish details. This control is a button leading to the locker wishes page, identical in behaviour to the other two states — it is never inert text.
- **FR-006**: Whichever control the block shows, activating it MUST take the user to the locker wishes page.
- **FR-007**: The block MUST reflect the user's current wish and locker state on every homepage view, so that declaring, changing, or cancelling a wish elsewhere is visible on the next homepage visit without further action.
- **FR-008**: The block MUST NOT be shown to visitors who are not logged in, and MUST only ever show the viewing user's own wish — never anyone else's.
- **FR-009**: The block MUST NOT allow declaring, editing, or cancelling a wish directly; those actions remain on the locker wishes page, which the block links to.
- **FR-010**: The block's control MUST be operable by keyboard and carry a label that conveys its purpose to assistive technology, consistent with the existing homepage cards and buttons.
- **FR-011**: A user having no locker on file MUST NOT prevent the block from being shown, and MUST NOT prevent them from reaching the locker wishes page from it.
- **FR-012**: The block MUST appear after the swap-proposal sections and immediately above the user's locker details card, so that proposals awaiting an answer keep precedence while the wish stays above reference information.
- **FR-013**: An active swap proposal MUST NOT change which state the block shows or whether its control is offered. The freeze that an active proposal places on the user's floor and locker number applies to the locker details card only; wishes stay independent of proposals.

### Key Entities

- **Locker wish**: One user's declared search for a locker, holding the floor they are looking on. At most one per user; absent when no wish has been declared or after it was cancelled.
- **User locker profile**: The floor and locker number recorded against a user. Whether a locker number is on file is what distinguishes the "switch my locker" invitation from the "I want a locker" invitation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A logged-in user can tell, from the homepage alone and without scrolling past their own details, whether they currently have a locker wish and what floor it is for — in under 5 seconds.
- **SC-002**: 100% of homepage views by a user with saved locker details show exactly one of the three block states, matching that viewer's actual wish and locker state; 100% of views by a user with no saved details show no block.
- **SC-003**: Reaching the locker wishes page from the homepage takes a single action (one click or one keyboard activation) from any of the three states.
- **SC-004**: After a user declares, changes, or cancels a wish, the homepage block shows the new state on their very next homepage visit, with no stale wish shown in any case.
- **SC-005**: The block's control is reachable and activatable by keyboard alone, and its label is announced by assistive technology in 100% of the three states.

## Assumptions

- All three states present their action as a button-styled control that navigates to the locker wishes page (confirmed in Clarifications), so no state is a dead end.
- "Has a locker" means a locker number is recorded against the user's account. A user with a floor on file but no locker number counts as having no locker, matching how the existing homepage and wish list already describe "no locker assigned".
- An "expressed wish" means an active wish exists for the user; cancelling it returns the user to one of the two invitation states. There is no separate notion of an expired or archived wish.
- Declaring a wish is not an edit to the user's locker details, so it is unaffected by the active-proposal freeze those details are subject to.
- The wish displayed in the block is the floor being sought and only that (confirmed in Clarifications) — the same value the locker wishes page shows for that user. No new wish attributes, counts, or match indicators are introduced by this feature.
- Having saved locker details is the precondition for the block (confirmed in Clarifications); declaring a wish itself still requires no locker, only saved details.
- The block reuses the existing homepage card and button patterns and the existing locker wishes page; no new page, no new data, and no change to how wishes are declared or cancelled.
- The block's position is fixed by FR-012 (after swap proposals, above the locker details card) and is the same in all three states; the swap-proposal sections keep their existing relative order among themselves.
