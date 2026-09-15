# Feature Specification: Responsive Site Layout and Signed-In Menu

**Feature Branch**: `012-responsive-layout-menu`

**Created**: 2026-09-15

**Status**: Shipped

**Input**: User description: "Le site doit être responsif et s'afficher aussi bien sur mobile que sur desktop. Le menu en mode connecté doit être adapté et optimisé pour du mobile et desktop."

## Clarifications

### Session 2026-09-15

- Q: Which pattern should the signed-in menu use on phone-width screens — a collapsed toggle panel, a compact always-visible row, or a fixed bottom navigation bar? → A: Collapsed toggle panel ("hamburger"). The bar shows the brand plus a toggle; opening it reveals the destinations, the signed-in identity, and the sign-out control.
- Q: On a phone, should the two data tables (locker wishes, proposal history) keep scrolling sideways inside their container, or be restructured? → A: Restack as cards. Below the breakpoint each row renders as a labelled card block with every column present; at and above the breakpoint the normal table returns.
- Q: Does the 44×44px touch-target rule apply to every interactive element, and what happens to the existing 36px small buttons and pencil? → A: 44×44 for standalone controls below the breakpoint only; the existing 2.25rem/36px controls grow on narrow screens while desktop keeps its current density. Links inline in flowing text are exempt, per WCAG 2.2 SC 2.5.8.
- Q: How is responsive behavior verified for acceptance — automated tests at set viewport widths, or manual review? → A: Automated system tests at two fixed widths, a phone width (390×844) and the existing desktop width (1400×1400), asserting no horizontal overflow, menu panel behavior, the table/card swap, and touch-target sizes, with the existing accessibility audit re-run at phone width. The user-study criterion is dropped.
- Q: Where should the single responsive breakpoint sit — 40rem/640px or 48rem/768px? → A: 48rem (768px). Tablet portrait therefore receives the narrow treatment, and the one existing 40rem rule (the two-column detail grid) moves to 48rem so the site keeps a single breakpoint.
- Q: Must the mobile menu open and close with JavaScript disabled? → A: Yes. Opening, closing, keyboard operation and state announcement are baseline behavior requiring no script, reusing the site's established native disclosure pattern. Dismissal by Escape, by activating outside the panel, and closing on navigation are enhancements that apply when script is available.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The signed-in menu works on a phone (Priority: P1)

A signed-in user opens LockSwap on their phone. The top bar sits on a single row: the brand, and one toggle control. Tapping the toggle opens a panel with everything the menu offers — the locker wishes screen, the proposal history, who they are signed in as, and the way to sign out. Nothing is cut off, squeezed into an unreadable size, or stacked into a tangle that pushes page content off the screen, and every control is big enough to tap accurately with a thumb.

**Why this priority**: The menu is on every signed-in page. If it breaks on a phone, the user cannot navigate at all, which makes every other screen unreachable regardless of how well it renders. This is the single highest-value slice and the explicit second half of the request.

**Independent Test**: Can be fully tested by signing in on a narrow (phone-width) viewport, confirming the top bar renders cleanly without overflow or overlap, and confirming that from that bar alone the user can reach the locker wishes screen, reach the proposal history, see their identity, and sign out.

**Acceptance Scenarios**:

1. **Given** a signed-in user on a phone-width screen, **When** any page loads, **Then** the top bar fits within the screen width with no horizontal scrolling and no element overlapping or clipping another.
2. **Given** a signed-in user on a phone-width screen, **When** they tap the menu toggle, **Then** a panel opens containing the locker wishes destination, the proposal history destination, their identity, and the sign-out control.
3. **Given** the menu panel is open on a phone-width screen, **When** the user taps the toggle again, **Then** the panel closes and focus returns to the toggle.
3a. **Given** the menu panel is open and script is available, **When** the user presses Escape or activates anything outside the panel, **Then** the panel closes and focus returns to the toggle.
3b. **Given** script is unavailable, **When** a signed-in user on a phone-width screen activates the toggle, **Then** the panel still opens, exposes every destination, the identity and the sign-out control, and closes again on a second activation.
4. **Given** a signed-in user on a phone-width screen, **When** they tap any menu control, **Then** the control responds on the first tap and its touch area measures at least 44×44 CSS pixels.
5. **Given** the menu panel is open, **When** the user follows one of its destination links, **Then** the panel is closed on the page that loads.
6. **Given** a signed-in user on a desktop-width screen, **When** any page loads, **Then** the menu presents its destinations, identity, and sign-out directly in the bar, with no toggle and no extra click needed to reveal them.

---

### User Story 2 - Every signed-in screen is readable and usable on a phone (Priority: P2)

A signed-in user browses the homepage, the locker wishes screen, and the proposal history on their phone. Text wraps rather than running off the edge, cards and forms use the full width available instead of sitting in a narrow column, lists of swap proposals stay legible, and the two data lists present each record as a stacked card — every field labelled, the row's action right there — instead of a wide table the user has to swipe across. Buttons stack sensibly instead of colliding.

**Why this priority**: Once the menu works, these are the screens the user actually spends time on. They deliver value independently of the menu work — a user arriving via a direct link still benefits — but a broken menu would block reaching most of them, which is why this is P2.

**Independent Test**: Can be fully tested by visiting each signed-in screen at phone width and confirming that the page never scrolls horizontally, that the two list screens render as labelled stacked cards with their actions visible, that all text and controls are legible and reachable, and that forms can be completed end to end.

**Acceptance Scenarios**:

1. **Given** a signed-in user on a phone-width screen, **When** they open the homepage, **Then** the locker profile, the locker wish block, and each swap proposal section render in a single readable column with no horizontal page scrolling.
2. **Given** a signed-in user on a phone-width screen, **When** they open the locker wishes screen or the proposal history, **Then** each record renders as a stacked card with every field visibly labelled, and no sideways scrolling or swiping is needed to read a record or reach its action.
2a. **Given** a signed-in user on a phone-width screen viewing the locker wishes list, **When** a row offers the "Propose swap" control, **Then** that control is visible within the card without any horizontal scrolling.
2b. **Given** the same user widens the viewport past the breakpoint, **When** the layout reflows, **Then** the stacked cards become the column table, with the same records in the same order and no data lost in either direction.
3. **Given** a signed-in user on a phone-width screen, **When** they open a form (locker profile, locker wish), **Then** every field and button is reachable, correctly labelled, and wide enough to use, and the form can be submitted successfully.
4. **Given** a signed-in user on a phone-width screen, **When** a group of buttons appears side by side on desktop, **Then** those buttons stack or wrap on the narrow screen without overlapping or being cut off.
5. **Given** a signed-in user rotates their phone between portrait and landscape, **When** the layout reflows, **Then** content stays readable and no control becomes unreachable.

---

### User Story 3 - The sign-in and sign-up screens work on a phone (Priority: P3)

A visitor who is not signed in opens the sign-in or sign-up screen on their phone. The brand lock-up, the form fields, the submit button, and the links between sign-in, sign-up, and password recovery all fit the screen and are comfortable to use with one hand.

**Why this priority**: These screens are already a narrow, centred single column, so they are the least likely to be broken today — but they are the first thing a new mobile visitor sees, so they must be verified rather than assumed. Independently valuable and independently testable.

**Independent Test**: Can be fully tested by opening the sign-in and sign-up screens at phone width, signed out, and confirming the brand, the fields, the submit control, and the auth links all fit and function.

**Acceptance Scenarios**:

1. **Given** a signed-out visitor on a phone-width screen, **When** they open the sign-in screen, **Then** the brand lock-up, all fields, the submit button, and the auth links fit within the screen width with no horizontal scrolling.
2. **Given** a signed-out visitor on a phone-width screen, **When** they complete and submit the sign-in or sign-up form, **Then** the flow succeeds and any resulting error or status message is fully visible and readable.

---

### Edge Cases

- **Very narrow screens**: at the minimum supported width (320 CSS pixels), the layout still holds — no horizontal page scrolling, no clipped controls, no overlapping text.
- **Crossing the breakpoint with the panel open**: if the viewport widens past the breakpoint while the phone panel is open, the menu switches cleanly to the desktop bar with no leftover overlay, no trapped focus, and no duplicated controls.
- **Long email addresses**: a signed-in user with a long address sees it truncated or wrapped gracefully — in the bar on desktop, in the panel on a phone. The identity is what gives way, never the brand and never the navigation or sign-out controls.
- **Tablet and in-between widths**: at widths between phone and desktop the menu resolves to exactly one treatment — toggle-and-panel or full bar — with no width at which both are visible, or at which a control appears twice.
- **Reduced motion**: a user with the system "reduce motion" preference enabled sees the panel appear and disappear without animation, consistent with the rest of the site.
- **Keyboard-only and assistive technology**: the toggle and the panel are fully operable by keyboard, the toggle announces its expanded/collapsed state, and focus returns to the toggle when the panel closes — all of it without depending on script.
- **Script unavailable**: with JavaScript disabled or still loading, the menu opens and closes from the toggle alone. Only Escape and outside-activation dismissal are absent; no destination becomes unreachable.
- **Long content in records**: a long email address or locker value inside a stacked card wraps within the card rather than forcing the page sideways; on desktop the table container remains the only thing allowed to scroll sideways.
- **Flash and toast messages**: status and error messages remain fully visible at phone width and do not cover the menu or the primary action on screen.
- **Browser zoom / large text**: at 200% text zoom on a desktop-width screen, content remains readable and no control is lost, consistent with the narrow-screen behavior.

## Requirements *(mandatory)*

### Functional Requirements

#### Responsive shell and screens

- **FR-001**: The site MUST render usably at any viewport width from 320 CSS pixels up to and beyond typical desktop widths, with no horizontal scrolling of the page itself at any width in that range.
- **FR-002**: Every existing screen (sign-in, sign-up, account edit, homepage, locker wishes, proposal history) MUST remain fully functional below the breakpoint — every field reachable, every action performable, every message readable.
- **FR-003**: Content laid out in multiple columns at and above the breakpoint MUST collapse to a single readable column below it.
- **FR-004**: Groups of controls placed side by side at and above the breakpoint MUST wrap or stack below it rather than overflow, overlap, or shrink below a usable size.
- **FR-005**: Below the breakpoint, the locker-wishes list and the proposal-history list MUST abandon the row-and-column table layout and render each record as a self-contained stacked card. At and above the breakpoint they MUST render as the column table they are today.
- **FR-005a**: In the stacked card form, every column present in the desktop table MUST still be shown, and each value MUST carry a visible label naming the column it came from, so no information is lost and no value is left unexplained.
- **FR-005b**: In the stacked card form, a row's action or status (the "Propose swap" control, the "This is you" / "Proposal pending" / "exchange in progress" notices, and the proposal status badge) MUST be visible without any horizontal scrolling or swiping.
- **FR-005c**: The stacked card form MUST preserve the reading and interaction order of the desktop table — records in the same order, and within a record the same field order — so both forms describe the same data the same way.
- **FR-005d**: Both forms MUST be conveyed correctly to assistive technology: each value stays associated with its column label, and the stacked form MUST NOT strip the semantics that let a screen-reader user understand the record as a set of labelled fields.
- **FR-005e**: The empty state ("Nobody is looking for a locker right now", "You have not sent or received any swap proposals yet") MUST render identically in both forms.
- **FR-006**: Text MUST remain legible below the breakpoint without the user needing to zoom — body text MUST NOT render below the site's established base reading size.
- **FR-007**: Below the breakpoint, every standalone interactive control — buttons, submit controls, navigation destinations, the menu toggle, and the locker-profile edit affordance — MUST present a touch target of at least 44×44 CSS pixels.
- **FR-007a**: Links that sit inline within a sentence or a run of flowing text are exempt from FR-007, in line with the recognised target-size exception for inline links. They MUST still be clearly distinguishable and keyboard-focusable.
- **FR-007b**: The existing small controls currently sized at 2.25rem (the compact buttons and the locker-profile pencil) MUST meet FR-007 below the breakpoint. At and above the breakpoint they MUST keep their present size, so desktop density is unchanged.
- **FR-007c**: Where a control's visible shape stays smaller than its required target, the target MAY be enlarged invisibly around it, provided adjacent targets do not overlap.
- **FR-008**: Forms MUST be completable on a phone, including when the on-screen keyboard is open — the field being edited and its submit control MUST remain reachable.

#### Signed-in menu

- **FR-009**: At and above the breakpoint the signed-in menu MUST expose its destinations (locker wishes, proposal history), the signed-in identity, and the sign-out control directly in the top bar, without an extra interaction to reveal them.
- **FR-010**: Below the breakpoint the signed-in menu MUST collapse behind a single toggle control in the top bar. Activating the toggle MUST open a panel containing the same destinations (locker wishes, proposal history), the signed-in identity, and the sign-out control; activating it again, or dismissing the panel, MUST close it.
- **FR-010a**: While the panel is closed, the top bar MUST show the brand lock-up and the toggle control and nothing else, so the bar occupies a single row below the breakpoint.
- **FR-010b**: The panel MUST open and close by activating the toggle, and this MUST work with no script available. Opening and closing MUST be operable from the keyboard and MUST be announced to assistive technology without script.
- **FR-010b-i**: Where script is available, the panel MUST additionally be dismissible by pressing Escape and by activating anything outside the panel.
- **FR-010b-ii**: The absence of script MUST NOT leave the menu in a state a user cannot get out of: with script unavailable, activating the toggle again always closes the panel.
- **FR-010c**: Following a destination link from within the panel MUST leave the panel closed on the page that loads, so the panel is never left open over new content. This MUST hold whether or not script is available.
- **FR-011**: The signed-in menu MUST offer the same capabilities at every width — no destination, identity display, or sign-out control may be available on one size and absent on the other.
- **FR-012**: The brand lock-up MUST remain visible and MUST remain a working link back to the homepage at every width.
- **FR-013**: The signed-in identity (email address) MUST degrade gracefully when it is too long for the available space, truncating or wrapping without displacing or clipping the brand, the navigation destinations, or the sign-out control.
- **FR-014**: The menu MUST be fully operable by keyboard at every width, with a visible focus indicator on every control and a logical focus order.
- **FR-015**: The toggle control MUST announce its state to assistive technology (expanded vs. collapsed) and identify the panel it controls; when the panel is dismissed, focus MUST return to the toggle.
- **FR-016**: Any motion used to open or close the panel MUST be suppressed for users with the system "reduce motion" preference enabled; the panel MUST still open and close, just without animation.
- **FR-017**: The toggle control MUST be recognisable as the way into the site's navigation and MUST carry an accessible name describing that purpose, so a user never has to guess that navigation is available.
- **FR-018**: The layout MUST switch between its narrow and wide treatments at a single breakpoint of 48rem (768px), applied consistently across the whole site, so there is no width at which some regions use one treatment and others use the other. Below 48rem is the narrow treatment; at and above it is the wide treatment.
- **FR-018a**: The one piece of the site that already switches on width at a different value — the two-column detail grid — MUST be moved to the 48rem breakpoint, so that exactly one breakpoint governs the whole site.
- **FR-018b**: A viewport of 768 CSS pixels (tablet portrait) MUST receive the wide treatment, and a viewport of 767 CSS pixels MUST receive the narrow treatment, with no width in between behaving as neither.

#### Consistency and non-regression

- **FR-019**: The responsive work MUST reuse the site's existing visual language — colours, spacing scale, typography, and component styles — and MUST NOT introduce a new visual pattern where an existing one already solves the problem.
- **FR-020**: Desktop appearance and behavior MUST NOT regress: screens that render correctly at desktop width today MUST continue to do so.
- **FR-021**: Existing behavior that already responds to viewport width MUST be preserved or improved, never removed.

#### Verification

- **FR-022**: Responsive behavior MUST be verified by automated tests that run at two fixed viewport widths — a phone width of 390×844 and the established desktop width of 1400×1400 — so that a regression at either size blocks merge rather than waiting to be noticed.
- **FR-022a**: The no-horizontal-overflow check MUST additionally run at the 320-pixel minimum supported width, since that is the width at which overflow is most likely and it is not otherwise sampled.
- **FR-023**: At each width, the automated checks MUST cover every screen in FR-002 and MUST assert: no horizontal overflow of the page, the menu treatment required at that width, the list form (stacked cards or column table) required at that width, and keyboard reachability of every control.
- **FR-024**: The project's existing accessibility audit MUST run at the phone width as well as the desktop width, at the same conformance level, and MUST cover the state with the menu panel open.
- **FR-025**: Touch-target sizes required by FR-007 MUST be measured by an automated check at the phone width, not asserted by inspection.

### Key Entities

*Not applicable — this feature changes presentation and navigation only. It introduces no new data and changes no existing data.*

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero screens produce horizontal page scrolling anywhere in the supported range. This is asserted automatically at the two tested widths and at the 320-pixel minimum, and holds as a requirement at every width in between.
- **SC-002**: A signed-in user on a phone can reach any of the product's main destinations (homepage, locker wishes, proposal history) from any other page in at most two taps.
- **SC-003**: A signed-in user on a phone can sign out in at most two taps from any page.
- **SC-004**: Below the breakpoint, 100% of standalone interactive controls measure at least 44×44 CSS pixels; inline links in flowing text are excluded from this count.
- **SC-004a**: On a phone, a user can read any record in the locker-wishes or proposal-history list, and reach that record's action, using vertical scrolling only — zero horizontal swipes required.
- **SC-005**: Every screen is exercised automatically at both a phone width and a desktop width, and the suite fails if any screen scrolls horizontally, if the menu panel does not open, close, and restore focus as specified, if a list does not present the form required at that width, or if a standalone control falls below the touch-target minimum on the narrow width.
- **SC-005a**: The existing accessibility audit passes at the phone width on every screen, to the same conformance level it is already held to at desktop width, including with the menu panel open.
- **SC-005b**: The primary flows (set a locker profile, post a locker wish, respond to a swap proposal) each complete end to end at the phone width in an automated run, using vertical scrolling only.
- **SC-006**: Every screen passes a keyboard-only walkthrough at both phone and desktop width — every control reachable, every control's focus visible, no keyboard trap.
- **SC-006a**: With script disabled, a signed-in user at phone width can still open the menu and reach every destination and the sign-out control.
- **SC-007**: No screen loses functionality relative to its current desktop behavior; a side-by-side review of every screen at desktop width shows no regression.
- **SC-008**: Page content is readable at 200% text zoom on a desktop-width screen with no loss of content or functionality.

## Assumptions

- **Target range**: the supported viewport range is 320 CSS pixels (small phone, portrait) through common desktop widths. Below 320 pixels is out of scope.
- **Breakpoint**: a single breakpoint at 48rem (768px) separates the narrow and wide treatments everywhere on the site. It was chosen over the existing 40rem rule because the six-column proposal-history table needs the extra width to render as a table at all; below 48rem it becomes stacked cards instead. The existing 40rem detail-grid rule moves to 48rem to keep the count at one.
- **Browsers**: current versions of the major evergreen browsers on iOS, Android, macOS, and Windows. No legacy browser support is in scope.
- **No new screens or data**: this feature adapts the presentation of screens that already exist. It adds no new pages, no new capabilities, and no new stored data.
- **Same information at every size**: the mobile treatment hides nothing permanently — everything available on desktop remains reachable on a phone, possibly behind one extra interaction.
- **Touch-target minimum**: 44×44 CSS pixels, the common iOS/Android accessibility guidance, is the standard for standalone controls below the breakpoint. Inline links in flowing text are exempt, and desktop keeps the existing 2.25rem sizing so the density established in feature 009 is preserved.
- **Existing accessibility posture is the floor**: the site already honours the system "reduce motion" preference; the responsive work maintains that and does not weaken any existing accessibility behavior.
- **No new script dependency for navigation**: core flows on this site work without JavaScript today, and the menu keeps that property. Script enhances dismissal, it does not enable navigation.
- **Native apps out of scope**: this is about the web experience rendering well on mobile browsers, not about a packaged mobile application.
- **Terminology**: the normative requirements speak of *below the breakpoint* and *at and above the breakpoint*, which is the only boundary that governs behavior. The user stories say *phone width* and *desktop width* as plain description, and the verification requirements use *the phone width* and *the desktop width* to mean the two specific tested viewports (390×844 and 1400×1400). None of these introduces a second breakpoint.
