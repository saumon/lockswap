# Feature Specification: Users Screen — Locker Details and Filters

**Feature Branch**: `020-admin-users-filters`

**Created**: 2026-09-19

**Status**: Shipped

**Input**: User description: "dans l'écran users accessible des admins uniquement, on doit pouvoir voir le locker et le floor actuel de chaque user, ainsi que son souhait de recherche de casier. L'écran doit proposer des filtres de recherche pour : le locker actuel, le floor actuel, le rôle, ainsi que l'email."

## Clarifications

### Session 2026-09-19

- Q: Should the current-locker filter match locker numbers exactly, or match any locker number that contains the typed text? → A: Exact match — the filter shows only the account holding that precise locker number.
- Q: When an administrator grants administrator rights to an account from a filtered Users list, should the active filters still be applied afterward, or does the list reset to unfiltered? → A: Filters stay applied — the list is shown filtered the same way after the grant completes.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See each account's locker, floor and wish at a glance (Priority: P1)

An administrator opens Admin → Users, the screen they already use to see every registered account. In
addition to what it already shows (email, role), each row now also shows that account's current
floor, current locker number (or that none is assigned), and whether they have an active locker
search wish — and if so, which floor they are looking for.

**Why this priority**: This is the core value being asked for. Today the administrator has to leave
the Users screen and cross-reference the locker wishes screen to know who holds what and who wants
what; putting it on one row removes that back-and-forth and is useful even before any filter exists.

**Independent Test**: With several accounts registered — some with a locker, some without, some with
an active wish, some without — open Admin → Users and confirm every row shows its account's current
floor, current locker (or "no locker assigned"), and active wish (or that there is none), matching
what those same accounts show on the homepage and the locker wishes screen.

**Acceptance Scenarios**:

1. **Given** an account has a floor and locker number saved, **When** the administrator views its row
   in the Users list, **Then** both the floor and the locker number are shown on that row.
2. **Given** an account has a floor saved but no locker number, **When** the administrator views its
   row, **Then** the floor is shown and the locker is clearly shown as "no locker assigned", not as
   missing or broken data.
3. **Given** an account has never saved a floor, **When** the administrator views its row, **Then**
   the floor is clearly shown as not set, distinct from "no locker assigned".
4. **Given** an account has an active locker search wish, **When** the administrator views its row,
   **Then** the row shows that the account is looking for a locker and on which floor.
5. **Given** an account has no active locker search wish, **When** the administrator views its row,
   **Then** the row clearly shows it has none, rather than leaving the space blank or ambiguous.
6. **Given** the administrator is viewing the Users list, **When** they compare a row's floor, locker
   and wish to that same account's own homepage and entry in the locker wishes screen, **Then** the
   values match.

---

### User Story 2 - Narrow the list to a specific locker, floor, role or email (Priority: P1)

Faced with a long Users list, the administrator wants to jump straight to the account(s) they care
about — for example everyone on a given floor, everyone holding a specific locker, every
administrator, or one person by email — without reading through every row. The screen offers four
independent filters: current locker, current floor, role, and email. Setting any of them narrows the
list to the accounts that match; setting several at once narrows it to accounts matching all of them
together.

**Why this priority**: Filtering is the second half of what was asked for and is what keeps the
enriched list in User Story 1 usable as the number of registered accounts grows. It depends on User
Story 1 existing (there is nothing to filter by otherwise) but is itself the headline capability.

**Independent Test**: With accounts spanning several floors, several lockers, both roles, and
distinct emails, apply each filter one at a time and confirm the list narrows to exactly the matching
accounts; then combine two or more filters and confirm only accounts matching all of them remain.

**Acceptance Scenarios**:

1. **Given** accounts on several current floors, **When** the administrator sets the current-floor
   filter to one floor, **Then** the list shows only accounts whose current floor matches, and no
   other row.
2. **Given** accounts holding several different current lockers, **When** the administrator sets the
   current-locker filter to one locker, **Then** the list shows only the account holding that locker.
3. **Given** both administrator and standard accounts exist, **When** the administrator sets the role
   filter to "Admin", **Then** the list shows only administrator accounts, and setting it to
   "Standard" shows only non-administrator accounts.
4. **Given** several accounts with distinct emails, **When** the administrator enters an email (or
   part of one) in the email filter, **Then** the list shows only accounts whose email matches that
   text.
5. **Given** the administrator sets more than one filter at once, **When** the list is displayed,
   **Then** it shows only accounts matching every filter that is set, and an account matching only
   some of them is not shown.
6. **Given** one or more filters are set, **When** the administrator returns every filter to its
   default ("all"/empty), **Then** the full Users list is shown again, in its normal order.
7. **Given** the administrator arrives on the Users screen for the first time, **When** the screen is
   displayed, **Then** no filter is applied and every registered account is shown, exactly as before
   this feature.

---

### User Story 3 - Recognise that a filter combination matches nobody (Priority: P3)

The administrator sets a combination of filters — for example a floor and a role — for which no
account qualifies. Rather than an apparently broken or blank screen, they are told plainly that no
account matches the current filters, and every filter still shows what they set so they can adjust
one without losing their place.

**Why this priority**: An empty result is a normal, expected outcome once several filters can be
combined, not an error — but without a clear message it looks like one. This only matters once
filtering (User Story 2) exists.

**Independent Test**: Choose a combination of filters that matches no registered account and confirm
a clear "no account matches" message is shown, with every chosen filter value still visible and
adjustable.

**Acceptance Scenarios**:

1. **Given** the administrator's filter selections match no registered account, **When** the list is
   displayed, **Then** a clear message states that no account matches the current filters, distinct
   from the list simply being empty because no accounts exist at all.
2. **Given** that "no match" message is shown, **When** the administrator relaxes or clears one
   filter, **Then** the list updates to show whichever accounts now match the remaining filters.

---

### Edge Cases

- What happens when an account has never saved a floor and the current-floor filter is set to a
  specific floor? That account is excluded from the filtered results, the same way it is excluded
  from the equivalent filter on the locker wishes screen (feature 017).
- What happens when an account has no locker assigned and the current-locker filter is set to a
  specific locker? That account is excluded, since it does not hold that locker.
- What happens when the email filter text matches no account, while the other filters are left at
  "all"? The "no account matches the current filters" message is shown, same as any other
  non-matching combination.
- What happens when a new account registers, or an existing account changes its floor, locker, or
  wish, while the administrator is viewing a filtered Users list? The change is reflected the next
  time the administrator opens or reloads the screen, the same way the unfiltered list already
  behaves today; nothing about this feature makes the list update live.
- What happens to the existing "grant administrator rights" control and "Admin" badge on each row
  (features 013, 015) once locker, floor, wish and filters are added? They are unaffected — the new
  information and filters sit alongside them without changing how promotion works or looks.
- What happens to the active filter selections when the administrator grants rights to an account
  from a filtered list? They remain applied afterward; the promoted row is shown filtered the same
  way as the rest of the list, and disappears from the results only if the promotion itself makes it
  stop matching (for example, a role filter set to "Standard").
- What happens when the email filter text does not exactly match any account, but matches part of one
  (for example, part of an email address)? It is treated as a partial match (see Assumptions), so any
  account whose email contains that text is shown.
- What happens when the current-locker filter text does not exactly match any locker number, but is a
  substring of one (for example, `"1"` typed while locker `"10"` exists)? No account is shown for
  that value — the current-locker filter requires an exact match, unlike the email filter.
- How does the current-floor filter order the floors it offers, and what happens with values that
  read as numbers versus text? It follows the same ordering already established for the locker wishes
  floor filter (feature 017): numeric floor values first in ascending numeric order, then any
  non-numeric floor value in alphabetical order.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Users list MUST show, on every row, the account's current floor exactly as it
  appears on that account's own homepage (feature 002), including a distinct "not set" state when no
  floor has ever been saved.
- **FR-002**: The Users list MUST show, on every row, the account's current locker number exactly as
  it appears on that account's own homepage (feature 002), including a distinct "no locker assigned"
  state when the account has a floor but no locker number.
- **FR-003**: The Users list MUST show, on every row, whether the account has an active locker search
  wish (feature 003) and, when it does, which floor that wish is for; when it does not, the row MUST
  clearly indicate there is no active wish.
- **FR-004**: The Users screen MUST offer four independent filter controls: current locker, current
  floor, role, and email.
- **FR-005**: The current-floor filter MUST offer every distinct floor value currently saved by at
  least one registered account, ordered numeric values first in ascending order and then non-numeric
  values alphabetically, plus a default choice that applies no floor restriction — following the same
  convention as the locker wishes floor filter (feature 017).
- **FR-006**: The role filter MUST offer a choice between "Admin" and "Standard" accounts, plus a
  default choice that applies no role restriction.
- **FR-007**: The current-locker filter MUST narrow the list to the account whose current locker
  number exactly matches the entered text, and MUST leave the list unrestricted when left empty.
- **FR-008**: The email filter MUST narrow the list to accounts whose email address matches the
  entered text, using a partial (contains) match, and MUST leave the list unrestricted when left
  empty.
- **FR-009**: When more than one filter is set, the system MUST show only accounts matching every
  filter that is set (combined with AND), not accounts matching any one of them.
- **FR-010**: Clearing a filter (returning it to its default/empty value) MUST widen the list to
  include accounts excluded only by that filter, without needing to reload the screen.
- **FR-011**: When no registered account matches the current filter selections, the system MUST show
  a clear message stating that no account matches the current filters, distinct from the message (or
  absence of one) shown when the Users list is empty because no accounts are registered at all.
- **FR-012**: Applying, changing, or clearing a filter MUST NOT alter any account's data, role, locker,
  floor, or wish — filtering is strictly a read-only view over the existing Users list.
- **FR-013**: The existing "Admin" badge and "grant administrator rights" control on each row
  (features 013, 015) MUST continue to behave exactly as they do today, unaffected by the new
  columns and filters.
- **FR-014**: The system MUST continue to refuse a non-administrator's request for the Users screen,
  including with any filter or query parameters attached, the same way it refuses that request today
  (feature 013 FR-008).
- **FR-015**: The Users list's existing row order (registration order, oldest first, per feature 013
  FR-010) MUST be preserved when filters are applied; filtering removes non-matching rows without
  reordering the ones that remain.
- **FR-016**: When an administrator grants administrator rights to an account (feature 015) while one
  or more filters are set, the active filter selections MUST still be applied to the Users list shown
  after the grant completes — the same way feature 017 preserves the viewer's floor filter selections
  across saving their own wish.

### Key Entities

- **User Account** *(existing, features 013/015)*: a registered person, identified by email,
  registration order, and role (Admin or Standard). This feature adds no new field to the account
  itself; it surfaces fields already recorded elsewhere against the same account.
- **Locker Profile** *(existing, feature 002)*: an account's current floor and, optionally, current
  locker number.
- **Locker Search Wish** *(existing, feature 003)*: at most one active wish per account, naming the
  floor that account is currently looking for a locker on.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An administrator can determine any registered account's current floor, current locker,
  and active locker search wish (if any) by reading a single row of the Users screen, with no need to
  visit any other screen.
- **SC-002**: An administrator can narrow a Users list of any size down to a specific locker, floor,
  role, or email — or any combination of these — in a single visit to the screen, without scrolling
  through unrelated accounts.
- **SC-003**: Combining all four filters at once reliably returns exactly the accounts matching every
  chosen criterion, with no account incorrectly included or excluded.
- **SC-004**: When a filter combination matches nobody, the administrator can tell that immediately
  from the screen's message, without mistaking it for an error or for an empty Users list.

## Assumptions

- The email filter uses partial ("contains") text matching, consistent with how a search-style text
  filter is commonly expected to behave. The current-locker filter uses an exact match instead, since
  locker numbers are unique identifiers (feature 002) and an admin typing one already knows the exact
  value they are looking for. The current-floor and role filters use a fixed choice list, since both
  are drawn from a small, enumerable set of existing values (mirroring the floor-filter pattern
  already established in feature 017).
- All four filters combine with AND logic when more than one is set, consistent with the combined-
  filter behavior already established in feature 017's two floor filters.
- Filters take effect as soon as a value is chosen or typed, without a separate "Apply" action,
  mirroring feature 017; the Users list is the only part of the screen affected by a filter change.
- The Users list continues to reflect the state of accounts as of when the screen is loaded — this
  feature introduces no live/real-time update behavior beyond what the screen already has.
- "Current locker" and "current floor" in this feature refer to the same Locker Profile data (feature
  002) already shown to each user on their own homepage, not to any separate admin-only record.
- "Souhait de recherche de casier" refers to the existing Locker Search Wish (feature 003); an account
  can have at most one active wish, so the wish column shows at most one floor per row.
