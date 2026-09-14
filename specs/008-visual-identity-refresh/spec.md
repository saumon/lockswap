# Feature Specification: Visual Identity & Modern White-Theme Refresh

**Feature Branch**: `008-visual-identity-refresh`

**Created**: 2026-09-14

**Status**: Shipped

**Input**: User description: "Le site LockSwap doit avoir un style visuel moderne, épuré, dans le thème blanc, avec des animations afin de le rendre sexy et moderne visuellement. Intègre le logo au format svg ainsi que la typo et couleurs du nom \"LockSwap\" en te basant sur l'image ci-jointe."

## Clarifications

### Session 2026-09-14

- Q: The attached logo artwork spells the wordmark "LockerSwap", but the product name used everywhere in the app (page titles, navigation, install manifest) is "LockSwap". Which spelling is the official brand name that the new logo and wordmark must carry? → A: "LockSwap" is the official name. The wordmark is redrawn in the artwork's typeface and colours as "Lock" (navy) + "Swap" (green); the mark and palette are reused unchanged, and the stray "LockerSwap" occurrence in the app is corrected.
- Q: May the refresh rearrange how content is laid out on a page (card grids, a reworked header, a wider canvas), or must it keep every screen's current structure and change only colours, type, spacing, and borders? → A: Restyle plus layout freedom, same content. Templates may be restructured — grids, card groupings, a wider canvas, a reworked header — provided no user-facing information or control is added, removed, or reworded.
- Q: The logo tagline is French ("Trouvez le casier qui vous convient") while every label in the app is English. Should the tagline appear in French, in English, or be omitted from the product? → A: Translate it to English. The product renders an English tagline ("Find the locker that suits you") so it matches the English interface; the original French tagline is retained in the source brand artwork only.
- Q: What counts as adequate automated test evidence for this refresh, given the constitution makes tests non-negotiable? → A: Automated accessibility assertions on every screen — contrast, focus indicators, alternative text, and heading order — plus the existing test suite staying green. Visual appearance itself is reviewed by eye, not snapshot-tested.
- Q: Should the brand typeface be downloaded from a third-party font service at page load, or bundled and served from the LockSwap site itself? → A: Self-host the fonts. The font files are served from the site's own origin, with no third-party request at page load.
- Q: How far should the animation go — only immediate feedback on things the user touches, or also content that animates itself as the user scrolls? → A: Interaction feedback plus page entrance. Hover, focus, active and in-progress states, a brief ease-in of content on page load, and animated proposal status changes. No scroll-triggered reveals and no page-to-page transition animations.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The brand is present and recognisable on every screen (Priority: P1)

A visitor arrives on any page of the site — the sign-in page, the dashboard, the locker wishes page, the proposal history. Today they see a plain text wordmark in a generic system font on a grey page. Instead, they should see the LockSwap logo mark and wordmark rendered crisply at any screen size and any zoom level, in the brand's two-tone treatment (deep navy paired with brand green). On the signed-in screens the brand sits in the page header; the sign-in and sign-up screens instead lead with the full stacked lock-up — mark, wordmark and the English tagline — and carry no header at all, since a header would show the brand twice and hold nothing else for a visitor who is not signed in. The browser tab, the bookmark icon, and the installed-app icon carry the same mark, so the product is recognisable before the page even finishes loading.

**Why this priority**: The logo and wordmark are the single most visible carrier of the brand. Without them, every other visual change still reads as an unbranded generic app. This story alone delivers a recognisable product and can ship on its own.

**Independent Test**: Load any page of the site, at desktop and at phone width, and confirm the logo mark and wordmark render sharply (including at 200% browser zoom), use the brand colours and typeface, link back to the home page, and are announced correctly to a screen reader. Confirm the browser tab icon shows the brand mark.

**Acceptance Scenarios**:

1. **Given** a visitor is on the sign-in page, **When** the page loads, **Then** the brand logo mark and wordmark are displayed as the full stacked lock-up in the brand navy and brand green, no header bar is shown, and the browser tab shows the brand icon.
2. **Given** a signed-in user is on any application page, **When** they look at the header, **Then** the same logo mark and wordmark are shown in the same position and act as the link back to the home page.
3. **Given** a visitor views the site at 200% browser zoom or on a high-resolution display, **When** they inspect the logo, **Then** its edges remain sharp with no pixelation or blurring.
4. **Given** a visitor uses a screen reader, **When** focus reaches the header brand link, **Then** it is announced with the brand name rather than as an unlabelled image or as decorative filler.
5. **Given** a visitor views the site at phone width (360px), **When** the header renders, **Then** the brand remains legible and fully visible without overlapping the navigation controls.

---

### User Story 2 - A clean, modern white interface across the whole site (Priority: P1)

A user moves through the existing screens — sign in, sign up, account settings, dashboard with their locker profile, locker wishes, swap proposals sent/received/declined, proposal history. Every one of these screens should read as one coherent, uncluttered product built on a white canvas: generous whitespace, a single consistent type scale, soft rounded cards with light shadows instead of hard grey blocks, and the brand navy and green used purposefully for emphasis and actions rather than decoration. Content may be regrouped and rearranged to achieve this — into cards, into grids, across a wider canvas — but every piece of information and every action the user had before is still there afterwards.

**Why this priority**: This is the substance of "moderne et épuré". It affects every screen a user touches and is what makes the product feel finished. It is independent of the animation work and delivers value with no motion at all.

**Independent Test**: Walk through every existing screen and confirm each uses the shared white-theme visual language — same spacing rhythm, same type scale, same card, button, form-field, and badge treatments, same brand colour usage — with no screen left on the old styling and, however the layout was rearranged, no information lost and no control added or removed.

**Acceptance Scenarios**:

1. **Given** a user navigates between any two screens, **When** they compare them, **Then** headings, body text, buttons, form fields, cards, and status badges use the same visual treatment on both.
2. **Given** a user views any screen, **When** they read it, **Then** the page background is white or near-white and the brand colours are used for emphasis, actions, and status rather than as large background fills.
3. **Given** a user views a form with a validation error, **When** the error is shown, **Then** it uses the shared error treatment and its text remains readable against its background.
4. **Given** a user views any screen at phone width, **When** the layout renders, **Then** the content reflows to a single readable column with no horizontal scrolling and no clipped controls.
5. **Given** a user reads any text or interactive control on any screen, **When** contrast is measured, **Then** it meets the accessibility contrast minimum for its text size.
6. **Given** a user operates the site by keyboard only, **When** they tab through a screen, **Then** every focusable control shows a clearly visible focus indicator.

---

### User Story 3 - Motion that makes the product feel alive (Priority: P2)

A user interacts with the site and the interface responds: content eases into view as a page loads, cards and buttons lift subtly on hover, the swap-proposal actions and status changes animate rather than snapping, and the two-locker logo mark can play its exchange motion as a welcome flourish. The motion is quick and restrained — it makes the product feel responsive and polished, never slow or distracting. A user who has asked their system for reduced motion sees the same interface with the movement removed.

**Why this priority**: Motion is what the user asked for to make the site feel "sexy", but it is a layer on top of a correct, well-laid-out interface. It is worth doing and worth doing last, because it is meaningless — and actively harmful — applied to an inconsistent layout.

**Independent Test**: Exercise the main interactions (load a page, hover a card and a button, focus a field, submit a form, act on a swap proposal) and confirm each has a brief, smooth transition; scroll a long page and confirm nothing animates into view as a result; navigate between pages and confirm no transition animation plays; then enable the operating system's reduced-motion setting and confirm every remaining transition is suppressed while the interface stays fully usable.

**Acceptance Scenarios**:

1. **Given** a user loads any page, **When** the content appears, **Then** it eases in briefly rather than appearing abruptly, and the page is interactive without waiting for the motion to finish.
2. **Given** a user hovers or keyboard-focuses an interactive card or button, **When** the pointer or focus arrives, **Then** the element responds with a brief visible transition, and reverts just as smoothly when it leaves.
3. **Given** a user submits a form or triggers an action that takes a moment, **When** the action is in flight, **Then** the control communicates that it is working rather than appearing frozen.
4. **Given** a user has enabled a reduced-motion preference in their operating system, **When** they use any screen, **Then** no non-essential movement plays, and all information and controls remain available and usable.
5. **Given** a user watches any single transition, **When** it plays, **Then** it completes quickly enough not to delay the user's next action.
6. **Given** a user is on a low-powered device, **When** they scroll or interact with an animated screen, **Then** scrolling and interaction remain smooth with no visible stutter.
7. **Given** a user scrolls down a long screen, **When** further content comes into view, **Then** that content is already fully visible and does not fade, slide, or otherwise animate in.
8. **Given** a user navigates from one screen to another, **When** the new screen appears, **Then** no page-to-page transition animation plays.

---

### Edge Cases

- What happens when the logo asset fails to load? The header must still present a readable, correctly-coloured text wordmark that links to the home page, rather than an empty or broken element.
- What happens in a browser or email client that does not render the vector logo (for example, an email template)? A raster fallback of the mark must be available for those contexts.
- How does the header behave when a signed-in user's email address is long? The brand and the navigation controls must remain visible and unclipped; the email is the element that truncates or hides.
- How does the site look while web fonts are still downloading? Text must remain readable in a fallback typeface during loading, with no invisible-text gap, and no jarring layout jump when the brand typeface arrives.
- What happens when a user prints a page or views it in a forced-colours / high-contrast mode? Content must remain legible; decorative colour fills and shadows must not obscure text.
- How does the interface behave for a user who has both reduced-motion enabled and is using a screen reader? Content must be reachable in a sensible reading order with no motion and no content hidden behind a transition that never plays.
- What happens on the toast notifications delivered by feature 007? Their appearance must be brought into the new visual language without breaking their existing auto-dismiss and hover-pause behaviour.

## Requirements *(mandatory)*

### Functional Requirements

#### Brand assets

- **FR-001**: The site MUST present the two-locker exchange mark — a blue locker and a green locker with two curved exchange arrows — rendered sharply at every size it is used.
- **FR-001a**: The site header and the icons MUST use a vector form of the mark, since it is drawn small, has to stay crisp at 16px, and is animated on the full-brand screens.
- **FR-001b**: The sign-in and sign-up screens MUST use the supplied raster artwork rather than any reproduction of it. It MAY be downscaled for delivery, but MUST NOT be otherwise altered, MUST remain at least twice the largest size it is drawn at so it stays sharp on a high-resolution display, and the unmodified master MUST be kept in the repository.
- **FR-002**: The wordmark MUST read "LockSwap" and MUST be rendered in the brand's two-tone split — "Lock" in brand navy and "Swap" in brand green — in the typeface and colours of the attached artwork.
- **FR-003**: The brand MUST be available in at least three arrangements: mark with wordmark side by side (site header), mark alone (favicon, app icon, compact contexts), and the full stacked lockup with the tagline (sign-in / sign-up pages and any full-brand context).
- **FR-003a**: The tagline rendered in the product MUST be in English — "Find the locker that suits you" — so that it matches the language of the surrounding interface. The original French tagline "Trouvez le casier qui vous convient" is retained in the source brand artwork only and MUST NOT appear on any page.
- **FR-004**: The site MUST use the brand palette derived from the attached artwork, defined as named design tokens rather than ad-hoc values: brand navy `#0E2A47` (primary ink and first wordmark segment), brand green `#0AB486` (second wordmark segment, exchange arrow, primary accent), brand blue `#0A77F1` (secondary accent, exchange arrow), locker blue face `#2588F3` with depth `#014DA7`, locker green face `#41D5A5` with depth `#05776E`, and a white / near-white page canvas.
- **FR-005**: The site MUST use a geometric, rounded sans-serif typeface family for the brand and interface — heavy weight for the wordmark and headings, light-to-regular weight for the tagline and body text — matching the character of the attached artwork.
- **FR-005a**: Typeface files MUST be served from the site's own origin. The site MUST NOT request fonts, stylesheets, or any other brand asset from a third-party service at page load, so that no visitor data is disclosed to a third party and the site renders correctly with no external origin reachable.
- **FR-005b**: Only the typeface weights and character ranges actually used MUST be shipped, so that the added asset weight stays small enough to satisfy SC-008.
- **FR-006**: The browser tab icon, bookmark icon, and installed-application icon MUST all use the brand mark rather than the current placeholder icon.
- **FR-007**: Wherever the site header is rendered, the brand element in it MUST remain the link to the home page and MUST expose the brand name to assistive technology.
- **FR-006a**: The sign-in and sign-up screens MUST NOT render the site header. They MUST present the stacked lock-up instead, at a size that makes it the first thing on the page.
- **FR-007a**: All brand-carried text rendered in the product (wordmark, tagline, alternative text) MUST be in the same language as the surrounding interface, currently English.
- **FR-008**: The product name MUST be spelled "LockSwap" in every user-visible place — logo, wordmark, page titles, header, navigation, and installed-app manifest — leaving zero occurrences of the alternate spelling "LockerSwap" in user-visible output. (The `LockerSwapProposal` model class and its references are a different word — "locker swap proposal" — and are correct as they stand.)

#### Visual system

- **FR-009**: The site MUST define a single shared visual system — colour tokens, type scale, spacing rhythm, corner radii, shadow levels, and border treatments — applied consistently to every screen.
- **FR-010**: Every existing screen (sign in, sign up, account settings, home dashboard, locker profile and its form, locker wishes list and form, swap proposals sent / received / declined / in progress, proposal history) MUST be restyled with this shared system; no screen may be left on the previous styling.
- **FR-011**: All recurring interface elements — buttons (primary, secondary, destructive), form fields, labels, help text, validation errors, cards, panels, status badges, empty states, and toast notifications — MUST have one defined treatment each, reused everywhere they appear.
- **FR-012**: The page canvas MUST be white or near-white, with separation between regions achieved through whitespace, soft shadows, and light borders rather than heavy grey background blocks.
- **FR-013**: Brand navy and brand green MUST carry meaning — navy for primary text and structure, green for primary actions and positive/confirmed status — rather than being applied decoratively.
- **FR-014**: Every screen MUST remain usable and readable from 360px viewport width upward, with no horizontal scrolling of the page body.
- **FR-015**: The refresh MUST NOT remove or reword any user-facing information, control, or flow, MUST NOT add any new control or flow, and MUST NOT change any business behaviour; every piece of information and every action available on a screen before the refresh MUST still be available after it. The brand tagline introduced by FR-003a is the single permitted addition of user-facing text, and it carries no control or behaviour.
- **FR-015a**: Within the FR-015 constraint, screens MAY be restructured — regrouping content into cards or grids, widening the page canvas, and reworking the header layout are all permitted — so long as the set of information and controls on each screen is unchanged.
- **FR-015b**: Where a screen is restructured, the reading and keyboard tab order MUST remain logical and MUST follow the visual order of the new layout.

#### Motion

- **FR-016**: Page and content entrances MUST use a brief easing-in transition that plays once on page load, and the page MUST be interactive immediately rather than gated on the transition finishing.
- **FR-016a**: Motion MUST be limited to: interaction feedback (hover, focus, active, in-progress), the one-off page entrance of FR-016, animated swap-proposal status changes, and the logo flourish of FR-022. The site MUST NOT use scroll-triggered reveals — no content may animate into view as a consequence of scrolling — and MUST NOT animate transitions between pages as the user navigates.
- **FR-016b**: All content MUST be present and readable whether or not any entrance transition has played or completed; no information may depend on an animation running.
- **FR-017**: Interactive elements (buttons, links, cards, form fields) MUST respond to hover and to keyboard focus with a brief visible transition, and MUST revert smoothly.
- **FR-018**: Actions that take time (form submission, proposal accept/decline) MUST show an in-progress state on the triggering control.
- **FR-019**: Individual transitions MUST complete quickly enough not to delay a user's next action, and MUST never block input while they play. As a concrete bound: interaction feedback MUST settle within 200ms, and the page entrance transition MUST complete within 400ms of content becoming available.
- **FR-020**: The system MUST honour the user's operating-system reduced-motion preference by suppressing all non-essential movement while keeping every piece of information and every control available and usable.
- **FR-021**: Motion MUST NOT cause visible stutter during scrolling or interaction on a mid-range device.
- **FR-022**: The logo MUST fade in as a one-off flourish in full-brand contexts (sign-in / sign-up), emerging from a blur, staged so the mark, the wordmark and the tagline arrive a beat apart. The entrance MUST last long enough and ease gently enough to be seen as a fade rather than a snap — at least 800ms on a curve that progresses across its whole length. It MUST NOT loop, MUST settle fully opaque and fully sharp, and MUST NOT be declared at all under reduced-motion — so that a visitor who has asked for less motion is shown the brand outright rather than a flattened animation that could leave it invisible.
- **FR-022a**: The site header's mark MUST NOT animate on load. A logo that replays on every navigation is a distraction rather than a flourish.

#### Accessibility & robustness

- **FR-023**: All text and meaningful interface elements MUST meet the accessibility contrast minimum for their size against their background.
- **FR-024**: Every focusable control MUST display a clearly visible focus indicator that is not conveyed by colour alone.
- **FR-025**: Status and meaning MUST NOT be conveyed by colour alone; a text label or icon MUST accompany colour-coded status.
- **FR-026**: Text MUST remain visible in a fallback typeface while the brand typeface loads, with no period of invisible text.
- **FR-027**: If the vector logo cannot be rendered, the header MUST fall back to a styled text wordmark that still links to the home page.
- **FR-028**: Every screen MUST be covered by an automated accessibility check asserting, at minimum: text and meaningful non-text contrast against its background, a visible focus indicator on every focusable control, meaningful alternative text or accessible name on every image and icon-only control, and a heading order with no skipped levels.
- **FR-029**: The refresh MUST leave the existing automated test suite passing without weakening, skipping, or deleting any existing assertion; a test that breaks because a template was restructured MUST be updated to assert the same behaviour, never removed.
- **FR-030**: The accessibility checks in FR-028 MUST run as part of the standard automated test suite so that a failure blocks merge, rather than existing as a manual or on-demand step.

### Key Entities

- **Brand asset**: A reusable visual representation of the product — the mark, the horizontal lockup, the stacked lockup with tagline, and the icon — each with a defined minimum size, clear-space allowance, and permitted colour treatment.
- **Design token**: A named, single-source value for a colour, type size, weight, spacing step, corner radius, shadow level, or motion duration, referenced by every screen instead of being re-specified locally.
- **Interface component**: A recurring visual element (button, form field, card, badge, panel, empty state, toast) with one agreed appearance and one agreed set of interaction states (rest, hover, focus, active, disabled, in-progress, error).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of existing screens render in the new visual system, with zero screens remaining on the previous styling.
- **SC-002**: The brand mark and wordmark appear on 100% of screens — in the header on the signed-in screens, as the stacked lock-up on sign-in and sign-up — and remain sharp at 200% browser zoom and on high-resolution displays.
- **SC-003**: The product name is spelled "LockSwap" in 100% of user-visible places (logo, header, page titles, install manifest), with zero occurrences of the brand spelled "LockerSwap" in rendered output. Source identifiers containing `LockerSwapProposal` are out of scope — that is the model name, not the brand.
- **SC-004**: 100% of screens have automated accessibility coverage in the standard test suite, and the suite reports zero violations across contrast, focus visibility, accessible naming, and heading order — including zero contrast failures on text and interactive elements at their size.
- **SC-004b**: The existing automated test suite passes with zero failures and zero newly skipped tests after the refresh.
- **SC-005**: 100% of focusable controls show a visible focus indicator when reached by keyboard.
- **SC-006**: With the reduced-motion preference enabled, zero non-essential animations play, and 100% of information and controls remain reachable and usable.
- **SC-006a**: Zero content on any screen animates as a result of scrolling, and zero page-to-page navigations play a transition animation.
- **SC-006b**: Every interaction feedback transition settles within 200ms and every page entrance completes within 400ms.
- **SC-007**: Every screen is usable with no horizontal page scrolling from 360px viewport width upward.
- **SC-008**: Perceived load speed does not regress: the point at which a user first sees meaningful content is no later than before the refresh on a standard connection.
- **SC-008a**: Zero requests to third-party origins are made while loading any page, verified by inspecting the network activity of a page load.
- **SC-009**: Scrolling and interaction on animated screens stay visually smooth on a mid-range device, with no user-perceptible stutter.
- **SC-010**: Text is readable throughout page load, with zero occurrences of invisible text while the brand typeface loads.
- **SC-011**: No user-facing control or flow is added, removed, or reworded, and no existing information is lost — a before/after comparison of each screen shows identical available actions and identical information, even where the arrangement has changed. The only permitted new text is the brand tagline on the sign-in and sign-up pages.
- **SC-012**: In an informal review, a majority of reviewers describe the refreshed site as modern and uncluttered compared with the previous version.

## Assumptions

- The brand colours, mark, and typographic character are taken from the attached artwork; the exact palette values in FR-004 were sampled directly from that image and are treated as the authoritative brand palette.
- The site's interface language is English and is unchanged by this feature; no localisation or language-switching capability is introduced.
- The English tagline wording "Find the locker that suits you" is a direct rendering of the artwork's French tagline. The exact wording is a copy decision that can be adjusted without affecting any other requirement.
- The artwork's locker mark, exchange arrows, palette, and typographic character are adopted unchanged; only the lettering is reset from "LockerSwap" to "LockSwap", so the split falls between "Lock" and "Swap".
- Scope is a restyle of the screens that exist today. No new page is introduced — in particular, no public marketing or landing page is added, and an unauthenticated visitor continues to land on the sign-in page as they do now.
- No copy, no information, no available action, and no business behaviour changes. Layout and arrangement may change (see FR-015a); what is on each screen may not. Any wording change surfaced along the way is out of scope and should be raised separately.
- The set of screens and the navigation between them is unchanged; restructuring happens within a screen, never by moving content between screens.
- The toast notification behaviour delivered by feature 007 (auto-dismiss, pause on hover/focus) is kept as-is; only the toast's appearance is brought into the new visual system.
- The site continues to be a light/white-theme product only; a dark theme is out of scope for this feature.
- Visual appearance is signed off by human review; pixel-level visual regression snapshotting is deliberately out of scope, as it is brittle against font rendering differences and needs infrastructure this project does not have.
- The automated accessibility checks run against rendered pages in the existing test suite, which already exercises these screens end to end.
- "Accessibility contrast minimum" means the widely-adopted WCAG 2.1 AA thresholds (4.5:1 for normal text, 3:1 for large text and meaningful non-text elements).
- The brand typeface is sourced from an openly-licensed family whose character matches the artwork, since the artwork's exact typeface is not supplied. Its licence must permit self-hosting and redistribution.
- Self-hosting is chosen for privacy (no visitor IP addresses disclosed to a third-party font service, which matters for a French-facing product under GDPR), for resilience, and to avoid an extra origin on the critical render path.
- Target browsers are current versions of the major evergreen browsers on desktop and mobile; no legacy browser support is added by this feature.
- "Mid-range device" for the smoothness criteria means a mid-tier phone of roughly the last four years, not a flagship.
- The 200ms / 400ms motion bounds in FR-019 are a stated default that makes "brief" testable, chosen to stay below the threshold at which a transition starts to feel like waiting. They may be tuned during implementation provided motion still reads as immediate.
- Scroll-triggered reveals are deliberately excluded: the screens are short enough that they add little, and they risk leaving content invisible if a reveal never fires.
