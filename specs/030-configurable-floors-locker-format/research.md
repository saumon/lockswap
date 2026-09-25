# Research: Configurable Floors and Locker Number Format

**Feature**: 030-configurable-floors-locker-format | **Date**: 2026-09-25

Every "measured" note below was run against the project's own Ruby (3.4.6) in this session.

## R1 — Where the two settings live

**Decision**: Two new singleton models, `SiteFloorList` and `LockerNumberFormat`. Each has one row at
most, is read only through `.current`, and follows `SiteLanguageSetting`'s shape exactly (025): a
`first_or_create!` reader and an `only_one_row_may_exist` guard on `:create`.

**Rationale**: The danger zone renders each section's refusal with
`devise/shared/error_messages, resource: …` just above that section's form. With one model holding both
settings, a refused floor list would print its error above the format form too. Two models give each
section its own `errors` object, which is the pattern the screen already uses (language and domains are
two separate objects). The two settings also change independently and share no validation.

**Alternatives considered**:
- *One `SiteLockerSetting` row with both columns*: fewer files, but the error display has to be filtered
  by attribute, and saving one section re-validates the other.
- *Columns on `site_language_settings`*: mixes unrelated concerns under a name that says "language".
- *Rails credentials or ENV*: not editable from the screen, so it fails FR-001/FR-009.

## R2 — How the floor list is stored and entered

**Decision**: `site_floor_lists.floors` is a `json` column holding an ordered array of strings.
`NULL` means "never configured" (FR-006). The form edits a virtual attribute, `floors_text`: the
comma-separated line. Assigning it cleans the input (split on `,`, strip, drop blanks, `uniq` keeping the
first occurrence, as FR-002 requires) and writes `floors`. Reading it gives `floors.join(", ")`.

Validations:
- presence, once `floors` is being saved (FR-003). An empty result is refused, and once a list exists it
  can never be set back to `NULL`.
- at most 50 floors, each at most 20 characters. These bounds keep the select and the validation bounded
  (Principle IV); both limits are messages in the locale files.

**Rationale**: The typed order is part of the data (clarification Q3), so it needs an ordered container.
`json` on SQLite is stored as text and Rails casts it to and from an `Array`, so no join table is needed
for a list read in one piece and never queried by element. A virtual text attribute keeps the form a
single field, which is what the user's example ("0, 1, 2, 3") describes.

**Alternatives considered**:
- *A `floors` table with a position column*: this suits per-floor identity (renaming, relations), which
  nothing in the spec asks for. It also needs nested forms or a diff on every save.
- *A plain `text` column holding the raw string*: every reader would re-parse it, and the normalisation
  would be implicit.

## R3 — How floors are enforced on save (FR-005, FR-007, FR-011)

**Decision**: One `SiteFloorValidator` (an `ActiveModel::EachValidator` in `app/validators/`), used by
both `User` (`on: :locker_profile_update`, next to the existing presence rule) and `LockerWish`. Rules:
- If the list is not configured, it does nothing: the free-text behaviour stays (FR-006).
- If the value is blank, it does nothing; blanks stay the job of the existing presence validations.
- If the attribute is not changing (`will_save_change_to_attribute?` is false), it does nothing. This is
  what lets a record on a floor that has since been removed be re-saved with that floor unchanged
  (FR-007, FR-011).
- Otherwise the value must be in `SiteFloorList.current.floors`; if not, it adds
  `user.messages.floor_not_offered` / `locker_wish.messages.floor_not_offered`.

This covers every save path — the user's own profile, the admin editor, and the locker wish — including
requests sent without the form, because the check sits in the model, not the view.

**Rationale**: A single definition for the two models (Principle I; CLAUDE.md's "one definition" rule).
The "unchanged" condition is the same one `locker_details_held_by_active_swap` already relies on.

**Alternatives considered**:
- *An inclusion validation with a lambda on each model*: this duplicates the "not configured / unchanged"
  conditions in two places.
- *Enforcing in controllers*: this misses any future save path, and the existing validations all live on
  the models.

## R4 — Regular expression semantics and safety (FR-010, FR-014, FR-018)

**Decision**: The pattern is compiled as `Regexp.new("\\A(?:#{source})\\z", timeout: 0.1)`. The value is
stripped before matching. `LockerNumberFormat#matches?(value)` is the only matcher: the validator and the
examples table both call it.

- **Validity**: the model builds the anchored regexp in one private method,
  `anchored_regexp` → `Regexp.new("\\A(?:#{pattern})\\z", timeout: MATCH_TIMEOUT)`. **Both** the
  `pattern_compiles` validation and `matches?` go through it, so a pattern is accepted only if its
  *anchored* form compiles.
  *Measured*: `(?x)\d{3} #` compiles on its own, but its anchored form raises "unmatched parenthesis",
  because the extended-mode comment swallows `)\z`. Validating the raw source would let it through, and
  every locker profile save would then raise (analysis C1). `[0-9`, `(\d`, `*` and `\d{3}(?#` are
  refused either way. `\d{3` is **accepted**: Ruby reads the brace as a literal, so it matches "12{3".
  The spec's invalid-pattern example was changed to `[0-9` / `(\d` for this reason.
  `matches?` also rescues `RegexpError` and returns false, as a safety net for a row written before
  this rule existed.
- **Whole-value match**: `\A(?:…)\z` with a non-capturing group, so a pattern with alternatives such as
  `\d{3}|A\d{2}` still has to match the whole value.
  *Measured*: `\A(?:^\d{3}$)\z` does not match "042\n999". Anchors typed by the super admin are therefore
  harmless (FR-014): `^`/`$` in Ruby are line anchors, and the outer `\A…\z` still requires the whole
  string.
- **Bounded time**: Ruby 3.2+ supports a per-regexp `timeout`. A `Regexp::TimeoutError` is treated as
  "does not match", so the value is refused and the request still completes (FR-018).
  *Measured*: Ruby 3.4's match cache already makes the classic ReDoS `(a+)+b` linear
  (`Regexp.linear_time?` is true). Back-references are not memoised, so the timeout is the guard that
  still matters.
- **Pattern length**: at most 200 characters. The description is at most 100 characters.
- **Case**: sensitive, as written; no flags are exposed.
- **An empty pattern clears the format**: it is normalised to `nil`, and the description is cleared with
  it, as FR-009 requires.

**Rationale**: The site's validation runs in Ruby, so Ruby's dialect is the one the super admin writes.
The spec's examples (`\d{3}`, `\d{1,3}`) mean the same thing in every common dialect.

**Alternatives considered**:
- *Also checking in the browser (HTML `pattern` attribute)*: JavaScript's regex dialect differs from
  Ruby's, so the two could disagree and break SC-004. The existing forms are also deliberately
  `novalidate` ("the server decides what is valid").
- *Global `Regexp.timeout=`*: this would change every regexp in the process, including Rails' and
  Devise's.

## R5 — How locker numbers are enforced on save (FR-013, FR-015, FR-017)

**Decision**: A `LockerNumberFormatValidator` on `User#locker_number`, `on: :locker_profile_update`. It
does nothing when no format is in force, when the value is `nil` (the existing `normalizes` already turns
blank into `nil`, which keeps the "no locker" choice, FR-015), or when the value is not changing. This is
the clarified "existing values kept until next edited" rule (FR-017). The error message interpolates
`LockerNumberFormat.current.display` (the description, or the raw pattern if there is none).

To make FR-014's "surrounding spaces ignored" hold for what gets saved, not only for the check,
`normalizes :locker_number` is extended to strip whitespace as well as turning blank into `nil`.
Uniqueness (006) then compares the stripped values, which is the intent.

**Alternatives considered**:
- *Stripping only inside the matcher*: " 042 " would pass the check and then be saved with its spaces,
  and it would not collide with "042" under uniqueness.

## R6 — Form rendering: one floor field for three forms (FR-004, FR-006, FR-007)

**Decision**: A shared partial, `shared/_floor_field.html.erb` (strict locals: `form:`, `hint_id:`,
`autofocus:`). It renders the existing `text_field` while the list is not configured, and a `select`
once it is:
- options are `SiteFloorList.current.floors` in the typed order (clarification Q3), with
  `include_blank: t("shared.floor_field.prompt")`, so a person with no floor must choose one and the
  existing presence rule still speaks;
- if the record's saved floor is not in the list (FR-007), it is added as the selected option, labelled
  "<floor> (no longer offered)" (`t("shared.floor_field.no_longer_offered")`).

It replaces the floor field in `home/_locker_profile_form`, `locker_wishes/_locker_wish_form` and
`admin/users/_locker_profile_editor`. Each keeps its own label and hint. A `select.field-input` already
exists and is styled (the danger zone's language select), so there is no new CSS component for the field.

**Rationale**: One definition, three uses (CLAUDE.md "one definition per component"). A native `<select>`
is keyboard-operable and labelled through the existing `f.label`, which satisfies SC-007 without a custom
widget. Unlike the floor filters (a `<select>` that submits on change was rejected in 017 FR-008), this
select is inside a form with an explicit submit, so arrowing through its options commits nothing.

**Alternatives considered**:
- *Radio buttons or chips*: they grow with the list, and a floor-heavy building would flood the form.
- *A datalist*: it still accepts free text, which contradicts FR-005.

## R7 — Controllers, routes and the danger zone re-render

**Decision**: Two single-action controllers, following `Admin::AllowedEmailDomainsController`:
`Admin::FloorListController#update` and `Admin::LockerNumberFormatController#update`, each with
`before_action :authenticate_user!, :require_super_admin!` (029, FR-019). Routes go under the existing
`namespace :admin`: `resource :floor_list, only: :update, controller: "floor_list"` and
`resource :locker_number_format, only: :update, controller: "locker_number_format"`. On success each
redirects to `admin_danger_zone_path` with a notice (clarification Q4: no conformance count). On failure
each re-renders `admin/danger_zone/show` with a 422.

The danger zone view will have five objects to load (domains, new domain, language, floor list, format)
and four controllers that re-render it. Loading them is extracted into a `LoadsDangerZone` concern with a
single `load_danger_zone` method that assigns each only if not already set (`||=`), so the controller
whose write was refused keeps its invalid object. This mirrors `LoadsHomepageProposals`. Today's three
copies in `DangerZoneController#show`, `#update` and `AllowedEmailDomainsController` move into it.

**Alternatives considered**:
- *Extending `DangerZoneController#update` with more param keys*: it would branch on which form was
  submitted, and #update is documented as the language setting's own write.

## R8 — The examples table (FR-012, SC-004)

**Decision**: `LockerNumberFormat::EXAMPLES` is a frozen list of `{ pattern:, key:, samples: [...] }`,
with the meaning looked up as `t("admin.danger_zone.show.format_examples.#{key}")`. The accepted/refused
badge is **computed at render time** by calling the same `matches?` against a throwaway
`LockerNumberFormat.new(pattern:)`. A stated result therefore cannot disagree with enforcement (SC-004),
and a unit test asserts the expected outcomes so that a change in the matcher shows up as a failure.
Five examples: `\d{3}`, `\d{1,3}`, `[A-Z]\d{2}`, `\d{2}-\d{2}`, `(A|B)\d{3}`.

Presentation: an existing `.data-table` inside the format card, with patterns and samples in `.data-value`
(mono, CLAUDE.md: "everything measured") and results as `.badge-success` / `.badge-error` carrying the
words "accepted" / "refused". Colour is never the only signal.

## R9 — Performance

`SiteFloorList.current` and `LockerNumberFormat.current` are primary-key lookups on single-row tables. A
form render or a save costs at most one of each. Nothing is cached across requests, so a change applies to
the very next request (FR-020). No swap or lock execution path changes, beyond one extra in-memory
validation on the locker profile save. No unbounded query is introduced, and the list is capped at 50
(Principle IV).

## R10 — Existing tests

Because FR-006 keeps free text until a list is saved, and fixtures create neither row, the existing
system tests that do `fill_in "Floor"` keep passing unchanged. New tests configure a list explicitly and
use `select`. Fixtures gain no rows by default, which keeps "not configured" as the baseline.
