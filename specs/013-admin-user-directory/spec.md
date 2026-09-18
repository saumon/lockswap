# Feature Specification: Admin Role and User Directory

**Feature Branch**: `[013-admin-user-directory]`

**Created**: 2026-09-17

**Status**: Shipped

**Input**: User description: "le tout premier utilisateur qui s'inscrit est considéré comme \"admin\". En tant qu'administrateur, il a accès à un menu \"Admin\" non visible des utilisateurs non admin. Le menu \"Admin\" a un sous menu \"Users\", celui-ci permet à un admin de visualiser tous les utilisateurs inscrits sur le site."

## Clarifications

### Session 2026-09-17

- Q: What should happen if the administrator account deletes itself via the existing "Cancel my account" capability? → A: Administrator status stays fixed to that one account; if it is deleted, the site simply has no administrator afterwards (recovering one is out of scope for this feature).
- Q: In the Users list, how should the administrator's entry be distinguished from the rest? → A: An explicit "Admin" label/badge on that row, rather than relying on it simply being first.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The first account becomes the administrator (Priority: P1)

The very first person to ever create an account on the site is automatically recognised as its
administrator, with no setup step required from anyone. From then on, that account — and only that
account — sees an "Admin" entry in its navigation; every other account's navigation looks exactly as
it does today.

**Why this priority**: Nothing else in this feature has anywhere to live until an administrator
exists and can be told apart from everyone else. It is also the part that must never go wrong: an
account other than the true first one ending up with administrator rights would be a serious access
control failure.

**Independent Test**: On an instance with no accounts yet, register a first account, then a second.
Confirm the first sees the "Admin" entry in its navigation and the second does not — this is
verifiable without anything existing yet under the "Admin" menu.

**Acceptance Scenarios**:

1. **Given** no account has ever been registered, **When** the first person signs up, **Then** their
   account is the administrator and an "Admin" entry appears in their navigation from that point on.
2. **Given** the administrator account already exists, **When** any other person signs up, **Then**
   their navigation shows no "Admin" entry, now or later.
3. **Given** a non-administrator account, **When** that person requests an admin-only page directly
   by its address, **Then** the request is refused the same way an unauthorised request is refused
   elsewhere in the site, and nothing admin-only is shown.

---

### User Story 2 - The administrator reviews every registered account (Priority: P2)

From the "Admin" entry, the administrator opens a "Users" destination and sees every account ever
registered on the site — including their own — so they can tell who has signed up without asking
anyone or reaching into the database by hand.

**Why this priority**: This is the actual value the administrator role exists to deliver in this
feature; User Story 1 only makes it reachable by the right person.

**Independent Test**: Signed in as the administrator, with several accounts registered, open
Admin → Users and confirm every registered account appears, each identifiable by its email address,
with the administrator's own account included.

**Acceptance Scenarios**:

1. **Given** several accounts are registered, **When** the administrator opens Admin → Users,
   **Then** every one of those accounts is listed, identified by email address.
2. **Given** only the administrator's own account exists, **When** they open Admin → Users,
   **Then** the list shows exactly that one account.
3. **Given** the administrator is viewing the Users list, **When** a new account registers,
   **Then** that account appears in the list the next time the administrator opens or reloads it.
4. **Given** the Users list is open, **When** the administrator looks at the administrator's own
   entry, **Then** it carries an explicit "Admin" label that no other row has.

---

### Edge Cases

- What happens if two people submit the sign-up form at effectively the same instant? Exactly one of
  them becomes the administrator — whichever registration the system actually records first — never
  both and never neither.
- What happens if the administrator later cancels their own account (existing "Cancel my account"
  capability)? No other account automatically becomes administrator: the site is left with no
  administrator at all until fixed outside this feature (FR-011).
- What happens if a non-administrator bookmarks or guesses the address of an admin-only page? The
  request is refused, whether or not the "Admin" entry was ever visible to them.
- What happens to the Users list as the number of registered accounts grows very large? No account is
  ever silently left off the list; see Assumptions on how this stays true at scale.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST designate the account from the very first successful registration on
  the site as the sole administrator.
- **FR-002**: The system MUST NOT grant administrator status to any account other than that first one,
  regardless of the order in which accounts are later changed, or deleted.
- **FR-003**: The system MUST show an "Admin" entry in the navigation presented to the administrator
  on every signed-in page, exactly as other navigation entries are shown.
- **FR-004**: The system MUST NOT show the "Admin" entry, or anything reachable only through it, to
  any non-administrator account, under any circumstance.
- **FR-005**: The "Admin" entry MUST lead to a "Users" destination.
- **FR-006**: The "Users" destination MUST list every account ever registered on the site, including
  the administrator's own account.
- **FR-007**: Each entry in the Users list MUST be identified by the account's email address.
- **FR-008**: The system MUST refuse a non-administrator's request for the Users destination, or any
  other admin-only destination, even when requested directly by address rather than through the
  navigation.
- **FR-009**: This feature MUST NOT let the administrator change any account's role, or otherwise
  edit or remove an account, from the Users list — the list is read-only; administrator status is
  assigned automatically at signup and by nothing else.
  **Superseded by feature 015** (`specs/015-grant-admin-rights/`): the Users list gained one write —
  granting administrator rights — and administrators may now coexist without limit. Everything else
  this requirement forbids on that screen still holds (015 FR-014).
- **FR-010**: The Users list MUST present accounts in the order they registered, oldest first, so the
  administrator's own entry is the first one shown.
- **FR-011**: If the administrator's account is later deleted (via the existing "Cancel my account"
  capability), the system MUST NOT reassign administrator status to any other account; the site is
  left with no administrator until that is addressed outside this feature.
  **Superseded by feature 015** (`specs/015-grant-admin-rights/`): the outcome this describes — a site
  with registered accounts and no administrator — is no longer reachable, because 015 FR-016 refuses
  the deletion that would produce it. The half that still holds is that nobody is promoted
  automatically to fill a vacancy; rights are only ever granted deliberately.
- **FR-012**: The Users list MUST carry an explicit "Admin" label on the administrator's row, so that
  row is identifiable at a glance and not only by its position in the list.

### Key Entities

- **User Account**: a registered person on the site, identified by email address and registration
  order. Carries one additional fact for this feature — whether it is the administrator — which is
  true for exactly one account at a time (the first ever registered) and never changes by hand.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of freshly-deployed instances grant administrator rights to the first registered
  account automatically, with no manual configuration step by anyone.
- **SC-002**: 0% of non-administrator accounts can reach admin-only navigation or pages, whether
  through the interface or by requesting the address directly.
- **SC-003**: The administrator can see every registered account, and identify each by email, within
  a single visit to the Users destination — no account is missing regardless of how many have signed
  up.
- **SC-004**: The administrator can answer "who is registered on this site, and who was first?"
  without contacting anyone else or inspecting the database directly.

## Assumptions

- There is exactly one administrator account at any time; this feature introduces no way to promote a
  second account or otherwise have more than one.
  **Superseded by feature 015**, which introduces exactly that (015 FR-013).
- The Users list shows each account's email address and registration order/date. It does not repeat
  floor, locker, or wish details already shown on the existing Locker wishes and homepage screens,
  since this feature is about who is registered, not what they hold or want.
- Hiding the "Admin" entry from non-administrators is a display convenience, not the access control
  itself: admin-only destinations are also refused at the point the request is handled, consistent
  with how the rest of the site already keeps signed-in-only content from unauthorised requests.
- No specific display limit is assumed necessary at the site's current scale; if the number of
  registered accounts ever grows large enough for that to matter, the Users list can be batched or
  paginated later without changing what this feature promises (every account listed, none missing).
