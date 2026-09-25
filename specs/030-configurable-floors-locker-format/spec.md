# Feature Specification: Configurable Floors and Locker Number Format

**Feature Branch**: `030-configurable-floors-locker-format`

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description: "Un utilisateur avec le rôle \"Super administrateur\" peut configurer dans l'écran \"danger_zone\" les étages disponibles sur l'ensemble du site. Exemple : \"0, 1, 2, 3\" signifie que seuls les étages 0, 1, 2 et 3 seront sélectionables par les utilisateurs dans les différents écrans. Les différents champs \"floor\" devront donc être une liste sélectionnable, où les valeurs proposées sont celles définies par le \"Super administrateur\". Idem, le format du numéro de casier peut être configuré dans l'écran \"danger_zone\" par un \"Super administrateur\" : on peut définir le format de saisie autorisée (exemple : nombre sur 3 chiffres). Pour celà, le \"Super administrateur\" doit saisir une expression régulière (exemple : \d{3} signifie que le numéro de casier doit être obligatoirement un numéro de 3 chiffres ; \d{1,3} : un numéro de 1 à 3 chiffres). L'écran de paramétrage devra montrer des exemples de regex et résultats attendus. Une fois le format du numéro de casier saisi, tout les champs de saisies du site devront respecter celui-ci."

## Clarifications

### Session 2026-09-25

- Q: When the super admin removes a floor still used by accounts or locker wishes, what happens? → A:
  Keep the data as it is until its owner next edits it (FR-011).
- Q: When a locker number format is saved that some existing numbers do not match, what happens? → A:
  Keep the existing numbers until next edited; the edit must conform (FR-017).
- Q: What do ordinary users see as the expected locker number format in hints and error messages? → A:
  An optional plain-language description written by the super admin alongside the pattern; the raw
  pattern is shown only when no description was written (FR-009, FR-013, FR-016).
- Q: Before the super admin has saved any floor list (including the day this ships), how do floor fields
  behave? → A: They stay free text, exactly as today, until the first list is saved — no list is
  pre-filled from existing data or defaults (FR-006).
- Q: In what order do floor lists offer their floors? → A: The order the super admin typed, in the
  floor entry lists only; the existing floor filters keep their current automatic sort (FR-002, FR-004,
  FR-008).
- Q: Should saving a floor list or format report how many existing accounts/wishes no longer conform? →
  A: No — the save is confirmed without any information about existing data (FR-011, FR-017).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The super admin defines the site's floors (Priority: P1)

On the danger zone screen, the super admin enters the list of floors that exist in the building — for
example "0, 1, 2, 3" — and saves it. From then on, that list is the only set of floors anyone on the site
can pick from.

**Why this priority**: Floors are free text today, so "1", "01" and "1st" are three different floors and
never match each other. A closed list is the foundation of everything else in this feature: without it
there is nothing for the floor fields to offer.

**Independent Test**: As the super admin, save "0, 1, 2, 3" on the danger zone screen, reload the screen,
and confirm the list shown is exactly 0, 1, 2, 3.

**Acceptance Scenarios**:

1. **Given** the super admin is on the danger zone screen, **When** they enter "0, 1, 2, 3" and save,
   **Then** the saved floor list is 0, 1, 2, 3 and the screen confirms it.
2. **Given** a floor list is saved, **When** the super admin enters a different list and saves, **Then**
   the new list replaces the old one site-wide.
3. **Given** the super admin enters a list with stray spaces, empty entries, or a duplicate (e.g.
   " 1, ,2, 2 "), **When** they save, **Then** the saved list is 1, 2 — spaces trimmed, empty entries
   dropped, duplicates kept once.
4. **Given** the super admin submits an empty list (no floor at all), **When** they save, **Then** the
   save is refused with a message saying at least one floor is required.
5. **Given** a standard admin or non-admin, **When** they try to view or change the floor list by any
   means, **Then** they are refused, exactly as for the rest of the danger zone (029).

---

### User Story 2 - Every floor field becomes a choice from that list (Priority: P1)

Wherever someone enters a floor — their own locker profile (first entry and later edits), declaring or
changing the floor they are looking for, and an administrator editing another account's locker — the
field is a selectable list offering exactly the floors the super admin configured, in the configured
order, instead of a free-text box.

**Why this priority**: This is the user-visible payoff of Story 1. It is P1 alongside it because a
configured list that the forms ignore delivers nothing.

**Independent Test**: With the floor list set to 0, 1, 2, 3, open each floor field on the site and confirm
it offers exactly those four values; then submit a value outside the list directly (bypassing the form)
and confirm it is refused.

**Acceptance Scenarios**:

1. **Given** the floor list is 0, 1, 2, 3, **When** a user opens their locker profile form, **Then** the
   floor field is a list offering 0, 1, 2, 3 and nothing else.
2. **Given** the floor list is 0, 1, 2, 3, **When** a user declares the floor they are looking for,
   **Then** the floor field offers exactly 0, 1, 2, 3.
3. **Given** the floor list is 0, 1, 2, 3, **When** an administrator edits another account's locker
   profile, **Then** the floor field offers exactly 0, 1, 2, 3.
4. **Given** the floor list is 0, 1, 2, 3, **When** a floor of "7" is submitted to any of these forms by
   any means, **Then** it is refused with a message saying the floor is not one of the site's floors.
5. **Given** the list is navigated with the keyboard only, **When** a user reaches the floor field,
   **Then** they can open it, move between floors and choose one without a pointer, and the field has a
   visible label announced by assistive technology.

---

### User Story 3 - The super admin sets the locker number format, guided by examples (Priority: P2)

On the danger zone screen, the super admin enters the pattern a locker number must follow, written as a
regular expression — for example `\d{3}` for "exactly three digits" or `\d{1,3}` for "one to three
digits". Next to the field, the screen shows a table of example patterns with sample inputs and whether
each sample is accepted or refused, so the super admin does not need to know regular expressions in
advance to pick a sensible one.

**Why this priority**: It is independent of the floor list and valuable on its own, but less critical:
today's free locker number already works, whereas free-text floors actively break matching.

**Independent Test**: As the super admin, save `\d{3}`; reload and confirm the saved pattern is shown.
Confirm the examples table is visible and that each example's stated result is true for the saved rules.

**Acceptance Scenarios**:

1. **Given** the super admin is on the danger zone screen, **When** they look at the locker number format
   section, **Then** they see the current pattern (or that none is set) and a table of examples, each
   listing a pattern, what it means in plain words, and sample values marked accepted or refused (for
   instance `\d{3}`: "042" accepted, "42" refused, "1234" refused; `\d{1,3}`: "7" accepted, "042"
   accepted, "1234" refused).
2. **Given** the super admin enters `\d{3}` and saves, **When** the screen reloads, **Then** `\d{3}` is
   the saved format and is in force site-wide.
3. **Given** the super admin enters something that is not a valid regular expression (e.g. `[0-9` or `(\d`),
   **When** they save, **Then** the save is refused with a message saying the pattern is not valid, and
   the previously saved format stays in force.
4. **Given** a format is saved, **When** the super admin clears the field and saves, **Then** no format is
   in force and any locker number is accepted again, as today.

---

### User Story 4 - Every locker number entry respects the format (Priority: P2)

Once a format is saved, every place where a locker number is entered — a user's own locker profile and
an administrator's edit of another account — refuses a number that does not match it, and says what the
expected format is. The field's hint describes the format so people get it right the first time.

**Why this priority**: The enforcement half of Story 3; together they form one deliverable slice.

**Independent Test**: With the format `\d{3}` saved, enter "42" in the locker profile form and confirm it
is refused; enter "042" and confirm it is saved. Repeat in the administrator's editor.

**Acceptance Scenarios**:

1. **Given** the format is `\d{3}`, **When** a user saves "042" as their locker number, **Then** it is
   saved.
2. **Given** the format is `\d{3}` described as "3 chiffres, ex. 042", **When** a user saves "42" or "0421"
   or "A42", **Then** it is refused with a message stating the number must match "3 chiffres, ex. 042".
   Without a description, the message names `\d{3}` instead.
3. **Given** the format is `\d{3}`, **When** an administrator saves "42" on another account, **Then** it
   is refused with the same message.
4. **Given** a format is saved, **When** a user leaves the locker number empty (they have no locker),
   **Then** that is still accepted — the format applies to a number that is entered, not to its absence.
5. **Given** the format is `\d{1,3}`, **When** the value " 42 " is entered, **Then** it is judged as "42"
   (surrounding spaces ignored) and accepted.

---

### Edge Cases

- **A floor is removed from the list while accounts or wishes use it**: the data is kept as it is,
  still shown and still matched, until its owner next edits it; if that edit changes the floor, a listed
  floor must be chosen (FR-011, FR-007).
- **A format is saved that existing locker numbers do not match**: they are kept as they are until
  next edited; the edit that changes them must conform (FR-017).
- **The site before any floor list has been configured** (including the moment this feature ships on the
  running site): see FR-006.
- **The pattern matches only part of a value** (e.g. `\d{3}` against "12345"): the whole value must match,
  never a substring — "12345" is refused by `\d{3}`.
- **The super admin types anchors themselves** (`^\d{3}$`): accepted and behaves identically to `\d{3}`.
- **A pattern that accepts nothing useful or everything** (e.g. `.*`): accepted as saved; it is the super
  admin's decision, and the examples table exists to make the consequence visible beforehand.
- **A pathological pattern that would take very long to evaluate**: evaluation is bounded; a value whose
  check cannot complete in time is refused rather than hanging the page.
- **Floors that read as numbers and floors that do not** (e.g. "-1", "RDC", "Mezzanine"): all allowed in
  the list; the list is offered in the order the super admin entered it.
- **A floor value containing a comma**: not possible, since comma is the separator; documented in the
  field's hint.
- **The same number on two floors** remains two different lockers (006) — the format does not change
  uniqueness rules.
- **A proposal or history row recorded before the change**: past records keep the floor and locker number
  they were recorded with; nothing historical is rewritten.
- **Two super admin saves in quick succession / a stale danger zone tab**: the last save wins; each save
  replaces the whole list or pattern.
- **Language**: every new label, hint, example description and message exists in French and English and
  follows the site language setting (025).

## Requirements *(mandatory)*

### Functional Requirements

**Floor list**

- **FR-001**: The danger zone screen MUST let the super admin define the site's list of floors, entered as
  comma-separated values (e.g. "0, 1, 2, 3").
- **FR-002**: When saving the floor list, the system MUST trim surrounding spaces from each entry, drop
  empty entries, and keep only the first occurrence of a duplicate; it MUST keep the order in which the
  super admin entered the floors.
- **FR-003**: The system MUST refuse a floor list that is empty after FR-002's clean-up, with a message
  saying at least one floor is required, and keep the previous list in force.
- **FR-004**: Every form on the site where a floor is entered — the user's own locker profile (first entry
  and edits), the locker wish declaration and its "change floor" form, and an administrator's editor for
  another account's locker profile — MUST present the floor as a selectable list offering exactly the
  configured floors, in the configured order.
- **FR-005**: The system MUST refuse any floor value that is not in the configured list, on every save
  path, including values submitted directly rather than through the form.
- **FR-006**: Until a floor list has been saved for the first time, the system MUST behave as it does
  today (floor entered as free text, any value accepted), so the running site is not left with empty
  choice lists on the day this ships. No floor list is pre-filled on delivery — neither from floors
  already on file nor from a default; the danger zone's floor list starts empty until the super admin
  saves one. Once a list has been saved, FR-003 prevents returning to the free-text state.
- **FR-007**: On a form where the current saved floor of the record being edited is no longer in the list,
  the form MUST still show that current value as the selected one (marked as no longer offered) so the
  person sees what is on file, but MUST NOT let it be re-saved as a new choice unless it is unchanged.
- **FR-008**: Floor filters on the locker wish screen and the admin Users screen are not entry fields and
  are unchanged by this feature: they keep offering the floors that actually appear in the data, in their
  existing automatic order (numbers ascending first, then text alphabetically) — not the super admin's
  typed order, which applies to entry lists only.

**Locker number format**

- **FR-009**: The danger zone screen MUST let the super admin define the locker number format as a regular
  expression, or leave it empty to mean "no format — any value accepted". Alongside the pattern, the super
  admin MAY write a short plain-language description of it (e.g. "3 chiffres, ex. 042"), which is what
  users are shown (FR-013, FR-016). A description without a pattern is meaningless and is not kept.
- **FR-010**: The system MUST refuse to save a pattern that is not a valid regular expression, with a
  message saying so, and keep the previous format in force.
- **FR-012**: The danger zone screen MUST show, next to the format field, a table of at least four example
  patterns (including `\d{3}` and `\d{1,3}`), each with a plain-language meaning and at least two sample
  values marked accepted or refused. The results shown MUST be what the system would actually decide for
  those samples.
- **FR-013**: Every form where a locker number is entered (the user's own locker profile and an
  administrator's editor for another account) MUST refuse a non-empty value that does not match the
  format in force, with a message naming the expected format — the super admin's description when one
  was written, otherwise the raw pattern — on every save path including direct submissions.
- **FR-014**: A pattern MUST match the whole value, never a part of it; surrounding spaces in the entered
  value MUST be ignored before checking. Anchors typed by the super admin MUST not change the result.
- **FR-015**: An empty locker number MUST remain accepted whatever the format ("I don't have a locker",
  009).
- **FR-016**: When a format is in force, the locker number field's hint MUST state it — the super admin's
  description when one was written, otherwise the raw pattern — so that people can enter a conforming
  value on the first attempt.
- **FR-018**: Checking a value against the pattern MUST complete within a bounded time; if it cannot, the
  value MUST be refused and the page MUST still respond.

**Existing data and access**

- **FR-011**: When a floor is removed from the list, accounts and locker wishes already on that floor
  MUST be kept as they are — still displayed, still filterable and still counted for reciprocal matches —
  until their owner (or an administrator) next edits them. An edit that **changes** the floor MUST choose
  one from the current list; an edit that leaves the floor unchanged (e.g. only the locker number is
  edited) is not refused because of it (FR-007). Removing a floor MUST NOT be blocked by, nor clear, existing data. The save confirmation
  MUST NOT report how many accounts or wishes are on a removed floor.
- **FR-017**: When a format is saved, existing locker numbers that do not match it MUST be kept as they
  are, still displayed and usable in swaps, until next edited; saving a format MUST NOT be blocked by, nor
  clear, existing numbers, and its confirmation MUST NOT report how many existing numbers do not match. An edit that changes the number MUST produce a conforming one; a save that
  leaves the number unchanged (e.g. only the floor is edited) is not refused because of it — mirroring
  FR-007 for floors.
- **FR-019**: Both settings MUST be viewable and changeable by the super admin only, under exactly the
  same access rule as the rest of the danger zone (029 FR-005/FR-006).
- **FR-020**: Both settings MUST apply site-wide and immediately after saving, to every user and every
  form, without anyone needing to sign in again.
- **FR-021**: Past swap proposals and their history MUST keep the floor and locker number recorded at the
  time; changing either setting MUST NOT rewrite them.
- **FR-022**: Every new user-facing text (labels, hints, examples' meanings, messages) MUST be available
  in French and English. Floor labels and the format
  description are super-admin data, not interface text, and are shown as entered (see Assumptions).

### Key Entities

- **Site floor list**: one site-wide, ordered list of floor labels (short text, e.g. "0", "RDC"), set by
  the super admin. The sole source of choices for every floor entry field once it has been saved.
- **Locker number format**: one site-wide, optional pattern that every entered locker number must match
  in full, with an optional plain-language description shown to users in its place. Absent means "any
  value". Set by the super admin.
- **Format example**: a fixed, illustrative pattern with a plain-language meaning and sample values with
  their accepted/refused result, shown on the danger zone screen. Not editable.
- Existing **account locker profile** (floor, locker number) and **locker wish** (floor): unchanged in
  shape; newly constrained by the two settings above on save.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Once a floor list is saved, 100% of floor entry fields on the site offer exactly the
  configured floors, and 0 saves anywhere *change* a floor to a value outside the list. A floor already
  on file is kept until it is next changed (FR-007, FR-011).
- **SC-002**: Once a format is saved, 0 saves anywhere *change* a locker number to a non-empty value
  that does not match it. A number already on file is kept until it is next changed (FR-017).
- **SC-003**: The super admin can configure both settings from the danger zone screen in under 2 minutes,
  without outside documentation, using the examples on the screen.
- **SC-004**: Every example result displayed on the danger zone screen agrees with what the site actually
  accepts or refuses for that sample (100% agreement).
- **SC-005**: Every floor chosen after the list is saved is one of the listed values, spelled
  identically, so two people choosing the same floor are never missed as a reciprocal match because of
  spelling ("1" vs "01" vs "1st"). Floors recorded before the list existed converge as their owners next
  edit them.
- **SC-006**: A standard admin or non-admin succeeds in viewing or changing either setting 0% of the time,
  however the request is made.
- **SC-007**: Every floor list field and locker number field is fully operable by keyboard alone and has
  an accessible label.

## Assumptions

- "Super administrateur" is the single super admin role introduced by 029; the danger zone is already
  restricted to it, and these two settings live there as two more sections alongside the site language and
  the allowed email domains.
- Floors are entered as one comma-separated line, as in the user's example, rather than added one by one;
  the order typed is the order offered. The offered order is the super admin's, not a computed sort.
- A floor label is short free text (numbers, "-1", "RDC", …); comma is reserved as the separator.
- The locker number pattern is matched against the whole value (the user's examples `\d{3}` / `\d{1,3}`
  only make sense that way), and case-sensitively as written.
- The examples table is fixed reference material showing representative patterns and their results; a live
  "try a value" tester is not required by this feature.
- Search and filter fields (e.g. the admin Users screen's locker number search) are not entry fields: they
  look up existing data and are not constrained by the format, so old non-conforming values stay findable.
- Until the super admin saves a floor list, floors remain free text (FR-006); until a format is saved, any
  locker number is accepted — i.e. the site behaves exactly as today.
- Locker uniqueness per floor (006) and the "no locker" choice (009) are unchanged.
- Floor labels and the locker number format's description are **site data** typed by the super admin, in
  the same category as the allowed email domains. They are shown exactly as entered, in one language,
  whatever the site language. FR-022 (and Constitution III's I18n rule) applies to the interface text
  around them: labels, hints, the "(no longer offered)" suffix, messages and the examples' meanings.
