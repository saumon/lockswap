# Phase 0 Research: Users Screen — Locker Details and Filters

**Feature**: [spec.md](./spec.md) | **Branch**: `020-admin-users-filters` | **Date**: 2026-09-19

No `NEEDS CLARIFICATION` markers survived `/speckit-specify` and `/speckit-clarify` (both
clarifications — exact-match locker filtering, and filters surviving the grant-rights redirect — are
already encoded as FR-007 and FR-016). This document resolves the remaining *technical* unknowns: how
the screen updates in place, what each of the four filter controls is made of, where filtering
happens, and how the selections survive the one write this screen already has.

---

## R1 — Updating the list in place, reusing 017's frame

**Decision**: Wrap the users table in `<turbo-frame id="admin-user-directory-list"
data-turbo-action="advance" data-controller="frame-history">`, exactly the shape feature 017
introduced for the locker wishes list. Add `<meta name="turbo-cache-control" content="no-cache">` to
`admin/users/index.html.erb`. Reuse `app/javascript/controllers/frame_history_controller.js`
unchanged — it operates on `this.element`, so it needs no admin-specific variant.

**Rationale**: The requirements are the same shape 017 solved: only the list region may change
(FR-013 keeps the surrounding page, notably the "Admin" badge and grant control, untouched), and the
address must reflect the filters so they can be shared, bookmarked, and reached with back/forward
(implied by FR-010's "without needing to reload the screen" plus the general expectation that a
filtered admin view is a URL a colleague can be sent). 017 already found and fixed the two failure
modes a naive frame-advance hits — the snapshot cache disagreeing with the address on Back, and
Turbo's restoration visit not reliably re-rendering the frame — so reusing its exact fix avoids
rediscovering both.

**Alternatives considered**:

- *Full-page navigation on every filter change*. Simplest, but returns the screen to the top and
  contradicts FR-010's "without needing to reload the screen."
- *A second, admin-specific Stimulus controller duplicating `frame_history_controller.js`*. Rejected —
  the existing controller reads only `this.element` and `window.location`, so it is already generic
  over any frame; a copy would be the exact duplication Constitution I forbids.

**Note for the PR**: this is the second Turbo Frame in the codebase, reusing the first one's
supporting JavaScript rather than introducing a third pattern.

---

## R2 — Two shapes of filter control: links for closed choices, debounced text for open ones

**Decision**: Current-floor and role are rendered as link groups (017's pattern: "All" plus one link
per choice, `aria-current` on the one in force, no `<select>`). Current-locker and email are rendered
as `<input type="text">` fields inside a `GET` form, with a new Stimulus controller,
`auto_submit_controller.js`, that debounces the `input` event (≈400ms) and calls
`form.requestSubmit()`.

**Rationale**: 017's R2 already settled why a closed, small choice set is links and not a
`<select>` — an auto-submitting `<select>` fires on arrow-key navigation on several platforms, which
is the WCAG 2.1 SC 3.2.2 (On Input) failure the spec's own floor-filter precedent rules out. Role has
exactly two values plus "all," so the same reasoning and the same interaction pattern apply directly
— reusing it is what Constitution III asks for ("UI terminology, interaction patterns... MUST be
reused"). Locker number and email have no small enumerable choice set (FR-007, FR-008), so a link
group cannot represent them at all; a text input is the only sensible control. The Assumptions
section's "takes effect as soon as a value is chosen or typed, without a separate Apply action"
still has to hold for these two, and a text input's natural analogue of "committing" is not focus (a
`<select>`'s problem) but every keystroke — so a plain, un-debounced `input`-driven submit would
issue one request per character. The debounce is the minimum change needed to keep "no Apply
control" true without that cost.

**Alternatives considered**:

- *Submit on blur / Enter only*. Avoids per-keystroke requests with no new JavaScript, but silently
  drops the "as soon as... typed" behavior the other two filters have — pressing Tab away from the
  field would be the only way to see a result, which is not how the rest of the screen behaves and
  would read as broken to anyone used to the link filters' immediacy.
- *An explicit "Apply" button on the two text filters only*. Consistent with neither this feature's
  Assumptions nor 017's precedent, and would make the screen's four filters behave two different
  ways for no reason a viewer could infer.
- *Debounce with a longer/shorter interval, or fire on `change` instead of `input`*. `change` only
  fires on blur for a text field, which collapses back to the "blur only" alternative above. ~400ms
  on `input` is the codebase's first debounce, chosen as a conventional value (long enough that normal
  typing does not fire a request per keystroke, short enough that the delay is not perceptible as
  lag) — not empirically tuned, since there is no existing precedent to match.

**Justification for the PR (Principle III)**: this is the one genuinely new interaction pattern the
feature introduces. It exists because 017's link-based answer to "no Apply control" has no analogue
for free text, not because a simpler, already-established pattern was skipped.

---

## R3 — Where filtering happens, and where each choice list comes from

**Decision**: Filter in SQL via four named scopes on `User` (`with_role`, `on_floor`,
`with_locker_number`, `email_containing`), composed unconditionally in
`Admin::UsersController#index`. The current-floor filter's choices come from a new `User.saved_floors`
class method (`SELECT DISTINCT floor ...`, mirroring `LockerWish.owner_floors`'s shape). The role
filter's choices are the fixed pair `["Admin", "Standard"]` — never queried, per FR-006.

**Rationale**: Mirrors 017's R3 directly: SQL filtering means a filtered view reads fewer rows than
today's unfiltered one, and the choice list for a dynamic axis (floor) has to come from an unfiltered
query so setting one filter never changes what another offers (consistent with 017's own floor filters,
and with this feature's FR-015 preserving row order rather than any filter narrowing what the others
show). Role does not need a query for its choices at all — FR-006 fixes the pair regardless of whether
any account currently holds either role — so `RoleFilter` is handed a constant array rather than
issuing a query, which is one query fewer than the equivalent `FloorFilter` usage would cost.

**Query budget**: one `DISTINCT` query added (current-floor choices), bounded by distinct-floor count.
Composing four scopes with `.where` clauses is a single query regardless of how many are active — the
same reasoning as 017's R3. The controller test asserts the filtered index issues no more queries than
the unfiltered one.

**Alternatives considered**:

- *Load every user and filter in Ruby*. Rejected for the same reason as 017's equivalent alternative —
  it makes the (already unbounded, and out of scope to fix here) user list load unconditional, moving
  Principle IV in the wrong direction.
- *Derive the current-floor choices from the currently-filtered relation*. Would make the floor
  filter's own choices shrink once a locker or role filter narrows the list, contradicting the pattern
  017 already established (each axis's choices reflect the whole set, not what other filters left).

---

## R4 — Exact match vs. partial match, and escaping user input safely

**Decision**: `with_locker_number` matches with `where(locker_number: value)` (exact, case-sensitive —
locker numbers are opaque identifiers, not free text). `email_containing` matches with
`where("email LIKE ? ESCAPE '\\'", "%#{value.gsub(/[\\%_]/) { "\\#{it}" }}%")` — a literal `%` or `_`
typed into the email filter is escaped so it filters on that literal character rather than acting as a
SQL wildcard.

**Rationale**: FR-007 (from Clarification session) settles current-locker as exact match. The `email`
column already carries `collation: "NOCASE"` (per `db/schema.rb`), so `LIKE` on it is case-insensitive
for free, consistent with how email lookups already behave everywhere else in the app (sign-in,
uniqueness). The escaping is a correctness requirement independent of the spec: `LIKE`'s `%` and `_`
are metacharacters, and an administrator searching for an email containing a literal `_` (a common
character in email local-parts) must not have it silently treated as a single-character wildcard.
Rails' `sanitize_sql_like` exists for exactly this and is used instead of a hand-rolled `gsub` in the
implementation; it is spelled out here because the *requirement* — that user-typed search text is
escaped before reaching `LIKE` — is a decision worth recording even though the one-line
implementation is not.

**Alternatives considered**:

- *Case-insensitive/partial match for the locker filter too*, matching the email filter's shape.
  Rejected by the clarification session (FR-007) precisely because locker numbers are unique
  identifiers, not search text.
- *`ILIKE` or a database-level `LOWER()` comparison for email*. Unnecessary — the column's own
  `NOCASE` collation already makes both `=` and `LIKE` case-insensitive on SQLite, so an extra
  `LOWER()` wrapping would be redundant work with no behavior change.

---

## R5 — Carrying the filter selections through the "grant administrator rights" redirect (FR-016)

**Decision**: The per-row "Grant admin rights" `button_to` form (already inside the new turbo-frame,
unlike 017's declare panel which was deliberately kept outside its frame) gains hidden fields for the
four filter values whenever they are set, and
`Admin::UsersController#grant_admin` redirects to `admin_users_path(filter_selections)` instead of
the bare `admin_users_path`. The `button_to`'s form also gains
`data: { turbo_frame: "_top" }`, matching 017's swap-propose precedent, so the flash notice — which
lives outside the frame, in the layout — is still rendered after the redirect.

**Rationale**: FR-016. The grant action is a full request/redirect round trip, so the filtered address
the administrator was looking at is not preserved unless it travels with the request and is put back
on the redirect — the same problem 017's R5 solved for its declare/cancel writes. This feature's
version is simpler than 017's: the grant control's form is already *inside* the new frame (it is a
column in the same table being filtered), so the hidden fields can sit directly in that form and stay
current on every filter change automatically, without 017's cross-frame `form="..."` attachment
trick, which existed only because 017's declare panel had to stay outside the frame for a different
reason (FR-009 there).

**Alternatives considered**:

- *Store the filter selections in the session*. Rejected for the same reason as 017's R5 — it would
  make the filters sticky in ways the spec does not ask for (a fresh visit to the screen must start
  unfiltered, per Acceptance Scenario 7).
- *`redirect_back fallback_location:`*. Depends on the `Referer` header, which is not a MUST-level
  guarantee (some proxies and privacy settings strip it) — FR-016 is stated as a MUST.

---

## R6 — Test strategy

**Decision**: Split the evidence across the levels this repo already uses for this exact kind of
feature, following 017's precedent (`test/controllers/locker_wishes_controller_test.rb`,
`test/system/locker_wish_filter_test.rb`).

| Level | What it covers |
|---|---|
| `test/models/role_filter_test.rb` (new) | The fixed choice pair, `current?`/`filtering?`. Pure Ruby, no database. |
| `test/models/user_test.rb` | The four new scopes: exact locker match, role match, partial/escaped email match (including the literal `%`/`_` case from R4), and `saved_floors`. |
| `test/controllers/admin/users_controller_test.rb` | Each filter narrowing the list; AND-combination across all four; the no-match message; FR-016 — filters surviving the grant redirect; FR-014 — a non-administrator refused with filter params attached; the Principle IV query-count comparison (filtered vs. unfiltered). |
| `test/system/admin_users_filter_test.rb` (new) | User Stories 1–3 in the browser: the new columns rendering correctly for each locker/floor/wish state; the frame updating in place; the two link filters' keyboard rule (arrowing does not re-filter); the two text filters' debounced auto-submit; the no-match state; filters still applied immediately after granting rights. |
| `test/system/accessibility_test.rb` | axe-core clean on a filtered list, the no-match state, and the new text-filter inputs (labels, `aria-label`). |
| `test/system/responsive_test.rb` | The four-filter bar wraps at narrow width with no sideways scroll, against the site's single 48rem breakpoint. |
| `test/system/admin_users_test.rb` (existing) | Every assertion keeps passing except one, which is deliberately narrowed rather than left unchanged: "the screen offers no control but the grant" asserted `assert_no_field`, which the two new text filters (current locker, email) necessarily make false. That one test is updated to assert the only fields on screen are those two filters — everything else in the file, including every other test, is untouched, and remains the evidence that the "Admin" badge and grant-control behavior (FR-013) were not disturbed. |
| `test/system/locker_wish_filter_test.rb` (existing) | Must keep passing **unchanged** — the evidence that reusing `FloorFilter` and `frame_history_controller.js` here did not regress feature 017. |

**Fixtures**: `users.yml` gains enough rows/floors/lockers to make each filter observable
independently and in combination — at least one account per role, at least one account with no floor
and one with no locker (existing edge-case coverage), and an email containing a literal `_` or `%` for
R4. Existing fixtures are added to, not renumbered.

**Failing-first**: every item above fails before the change and passes after it, per Principle II.
