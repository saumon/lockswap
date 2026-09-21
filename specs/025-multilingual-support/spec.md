# Feature Specification: Site Language Setting (French/English)

**Feature Branch**: `025-multilingual-support`

**Created**: 2026-09-21

**Status**: Draft

**Input**: User description: "Le site LockSwap doit être multilangue. Le paramétrage de la langue doit se faire dans l'écran \"Danger Zone\" accessible pas les administrateurs. Le choix de la langue impacte tout le site (les libellés) et s'applique à tous les utilisateurs. Les langues disponibles sont le français et l'anglais. (la langue par défaut est l'anglais lorsqu'on installe l'application)"

## Clarifications

### Session 2026-09-21

- Q: When the site language is French, should dates and numbers shown on screen also switch to French/European formatting conventions, or should they keep a single fixed format regardless of language? → A: Keep one fixed date/number format regardless of language — only text labels are translated.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An administrator sets the site's language (Priority: P1)

Signed in as an administrator, the person opens the "Danger Zone" screen from the Admin menu. There
they find a language setting offering "French" and "English", choose one, and save. From that moment,
every screen's labels, headings, buttons, and messages are shown in the chosen language, for every
person visiting the site — not just the administrator who made the change.

**Why this priority**: This is the entire capability being requested — without it, there is no way to
make the site's interface language configurable at all.

**Independent Test**: With an administrator account, open Admin → Danger Zone, switch the language
setting to French, save, then browse several different screens (as the administrator and as a
standard user) and observe every label is in French; switch back to English and confirm the same
screens return to English.

**Acceptance Scenarios**:

1. **Given** an administrator is on the Danger Zone screen, **When** they select a language and save,
   **Then** the configuration is persisted and reflected the next time the screen is opened.
2. **Given** the site language is set to French, **When** any user (administrator or standard,
   including a signed-out visitor) views any screen, **Then** all interface labels on that screen are
   shown in French.
3. **Given** the site language is set to English, **When** any user views any screen, **Then** all
   interface labels on that screen are shown in English.

---

### User Story 2 - A fresh installation starts in English (Priority: P2)

On a newly installed instance of LockSwap where no administrator has yet configured a language, every
visitor sees the site in English, and the Danger Zone screen shows "English" as the current setting.

**Why this priority**: This is the documented default — it must hold on day one, before any
administrator has touched the setting, so the product has a predictable out-of-the-box behavior.

**Independent Test**: On a freshly installed instance (or with the language setting cleared/reset),
open any screen without signing in or configuring anything, and observe it is in English; open the
Danger Zone screen as an administrator and confirm the language setting shows "English".

**Acceptance Scenarios**:

1. **Given** a freshly installed instance with no language ever configured, **When** any user views
   any screen, **Then** the interface is shown in English.
2. **Given** a freshly installed instance, **When** an administrator opens the Danger Zone screen,
   **Then** the language setting is shown as "English".

---

### User Story 3 - Only administrators can change the language (Priority: P3)

A non-administrator user, whether signed out, signed in as a standard user, or attempting to reach the
Danger Zone screen directly, cannot see or change the site language setting. They experience the site
in whichever language an administrator has configured, with no personal override.

**Why this priority**: The setting is explicitly a single, site-wide, administrator-controlled switch;
without this restriction, any user could change the language experienced by everyone else.

**Independent Test**: Signed in as a standard (non-administrator) user, confirm the Admin menu (or its
Danger Zone entry) is not shown, confirm the language setting is neither visible nor editable to them
anywhere in the product, and confirm the screens they view follow the site-wide setting regardless of
their own account or browser locale.

**Acceptance Scenarios**:

1. **Given** a standard user is signed in, **When** they look at the navigation, **Then** no "Admin"
   menu entry or "Danger Zone" screen is available to them, and no language control is offered
   anywhere else in the product.
2. **Given** a standard user's browser or account is set to a locale different from the configured
   site language, **When** they view any screen, **Then** the screen still follows the site-wide
   language setting, not their personal locale.
3. **Given** an administrator is signed in, **When** they open the Admin menu, **Then** a "Danger
   Zone" entry is available and opens the screen where the language can be viewed and changed.

---

### Edge Cases

- What happens to users who already have a page open, or an active session, when an administrator
  changes the language? The new language MUST take effect for them on their next screen view (page
  load/navigation) at the latest — they are not required to sign out and back in.
- What happens if an interface label has not been translated into the selected language? The system
  MUST fall back to showing that label's English text rather than a blank space or an internal key.
- What happens to user-entered or user-generated content (e.g., a person's name, an e-mail address, a
  comment left on a swap, a locker or floor number) when the language changes? That content is data,
  not interface labels, and MUST be shown unchanged regardless of the selected language.
- What happens if an administrator saves the Danger Zone screen without changing the language field?
  The previously configured language MUST remain in effect, unchanged.
- What happens to dates and numbers (e.g., a swap's timestamp, an admin's "last active" date) when the
  language changes? They MUST continue to display in one fixed format — only translated text labels
  change, per [Clarifications](#clarifications).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a language setting on the "Danger Zone" screen, reachable from
  the "Admin" menu.
- **FR-002**: The system MUST restrict both the "Admin" menu entry leading to the Danger Zone screen
  and the language setting itself to users holding administrator rights; non-administrator users
  (including signed-out visitors) MUST NOT see or be able to change the setting.
- **FR-003**: The language setting MUST offer exactly two choices: French and English.
- **FR-004**: The system MUST persist the selected language as a single, site-wide setting shared by
  all users — it is not a per-user or per-session preference.
- **FR-005**: On a fresh installation, before any administrator has configured the setting, the site
  MUST behave as if English were selected.
- **FR-006**: When the language setting is French, all site-authored interface text — labels,
  headings, navigation, buttons, form fields, validation and error messages, e-mail notification
  text, and any other wording the product itself displays — MUST be presented in French, for every
  user viewing the site.
- **FR-007**: When the language setting is English, all site-authored interface text described in
  FR-006 MUST be presented in English, for every user viewing the site.
- **FR-008**: A saved change to the language setting MUST apply to every user, including those with an
  already-open session, no later than their next page load or navigation — no sign-out/sign-in or
  other individual action is required.
- **FR-009**: The system MUST NOT translate or alter user-entered or user-generated data (e.g. names,
  e-mail addresses, comments, locker/floor identifiers) when the language changes; only site-authored
  interface text is affected.
- **FR-010**: If an interface label has no translation available in the currently selected language,
  the system MUST display that label's English text as a fallback rather than leaving it blank or
  showing a raw internal identifier.
- **FR-011**: The Danger Zone screen MUST show which language is currently in effect, and MUST reflect
  a saved change the next time the screen is opened.
- **FR-012**: The language setting MUST affect only translated text labels; dates and numbers
  displayed anywhere on the site MUST use a single fixed format regardless of the selected language.

### Key Entities

- **Site Language Setting**: A single, site-wide configuration value holding the interface language
  currently in effect (French or English); read by every screen shown to every user and editable only
  from the Danger Zone screen by an administrator.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An administrator can change the site language and have it take effect for every user in
  under 1 minute, with no support intervention or per-user action needed.
- **SC-002**: 100% of a freshly installed instance's screens are shown in English before any language
  configuration has been made.
- **SC-003**: 100% of site-authored interface text on any screen, for any user, matches the currently
  configured site language (French or English), with no mixed-language screens.
- **SC-004**: 0% of user-entered or user-generated content is altered or mistranslated as a result of
  a language change.

## Assumptions

- "Impacte tout le site (les libellés)" is interpreted as: every piece of site-authored interface
  text (labels, headings, buttons, messages, navigation, and notification e-mails) — not
  user-generated content, which is data and stays as entered.
- The setting applies to every screen of the site, including screens reachable before signing in
  (e.g. the sign-in and registration screens), since the request describes it as covering "tout le
  site" without carving out an exception for pre-authentication screens.
- There is no per-user or per-browser language override in this feature; the request is explicit that
  the choice "s'applique à tous les utilisateurs" as a single, shared setting. Personal language
  preference is out of scope.
- The Danger Zone screen displays and edits the language the same way it does its other settings
  (e.g. the existing allowed-email-domains setting): a simple control the administrator changes and
  saves, with the current value always visible.
- Changing the language does not require restarting the application or any technical intervention
  beyond saving the setting in the Danger Zone screen.
