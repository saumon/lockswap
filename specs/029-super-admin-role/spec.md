# Feature Specification: Super Admin Role and Exclusive Danger Zone Access

**Feature Branch**: `029-super-admin-role`

**Created**: 2026-09-23

**Status**: Draft

**Input**: User description: "Ajoute un nouveau rôle \"super admin\". Le premier utilisateur s'inscrivant sur le site a le rôle de \"super admin\". Seul le \"super admin\" a les droits d'accéder à l'écran \"danger_zone\" et y manipuler les actions de l'écran. Un \"super admin\" a également en plus, les mêmes droits qu'un \"admin\" normal. Le rôle \"super admin\" ne peut pas être accordé à un autre utilisateur, il y a donc au total un seul \"super admin\". Un \"admin\" standard ne doit pas voir l'entrée \"Zone de danger\" dans le menu \"Admin\"."

## Clarifications

### Session 2026-09-23

- Q: When this feature ships on the already-running site, should the account that is currently the sole
  bootstrap administrator become the super admin immediately, or should the super admin role only be
  assigned going forward? → A: Retroactively promote the existing bootstrap administrator to super admin
  the moment this ships.
- Q: Should the super admin's own account be permanently undeletable whenever any other account exists
  (even one with no other admin), or should it follow the exact same "last administrator" rule every
  other admin already follows today (deletable as long as at least one other admin would remain)? → A:
  Strict — the super admin's account can never be cancelled while any other account exists, full stop.
  This supersedes the existing "last administrator" protection (the account already holding the super
  admin role is, from the moment any second account registers, a stronger and permanent guarantee that
  the site is never left without an administrator — see FR-010 and FR-014).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The first account becomes the site's super admin automatically (Priority: P1)

The very first person to ever register on the site receives the super admin role the moment their
account is created — no separate step, no one has to grant it. From then on, everyone who registers
afterward is a standard account, never a super admin.

**Why this priority**: Every other behaviour in this feature depends on there being exactly one super
admin account to begin with. Without this, the danger zone restriction and the "only one, ever" rule
have nothing to anchor to.

**Independent Test**: On a site with zero registered accounts, complete registration once — the
resulting account has both standard admin capabilities and super admin access. Register a second
account afterward and confirm it holds neither.

**Acceptance Scenarios**:

1. **Given** no accounts exist yet, **When** someone completes registration, **Then** their account is
   the super admin and also carries every capability a standard admin has.
2. **Given** the super admin account already exists, **When** another person registers, **Then** their
   new account is an ordinary standard account, not a super admin.

---

### User Story 2 - The danger zone is exclusive to the super admin (Priority: P1)

Signed in as a standard admin — one with regular administrator rights but not the super admin role —
the Admin menu no longer lists "Zone de danger", and neither the screen nor any of its actions (the
allowed email domains list, changing the site language) can be reached, whether by following a link or
by addressing the screen directly.

**Why this priority**: This is the actual restriction the feature exists to add — the danger zone
holds settings whose blast radius is the whole site, and confining it to a single, always-known account
is the point of the request.

**Independent Test**: Signed in as a standard admin, confirm the Admin menu has no danger zone entry,
then attempt to open the danger zone screen directly and confirm it is refused, and attempt to submit
one of its actions directly and confirm that is refused too.

**Acceptance Scenarios**:

1. **Given** a standard admin is signed in, **When** they open the Admin menu, **Then** no "Zone de
   danger" entry appears (the Users entry still does).
2. **Given** a standard admin is signed in, **When** they navigate directly to the danger zone screen's
   address, **Then** they are refused access to it.
3. **Given** a standard admin is signed in, **When** they submit one of the danger zone's actions
   directly (for example, changing the site language or the allowed email domains), **Then** the
   action is refused.
4. **Given** a signed-in account with no admin rights at all, **When** they attempt any of the above,
   **Then** they are refused exactly as they already are today for the rest of the Admin section.

---

### User Story 3 - The super admin keeps full control of the danger zone (Priority: P2)

Signed in as the super admin, every danger zone capability that exists today keeps working exactly as
it does now: the screen is reachable from the Admin menu, and every one of its actions can still be
performed.

**Why this priority**: The restriction in User Story 2 must not become a regression for the one account
meant to keep using this screen. This story is what proves the feature narrows access rather than
breaking it.

**Independent Test**: Signed in as the super admin, open the danger zone from the Admin menu, change
the site language, and add or remove an allowed email domain — each succeeds as before.

**Acceptance Scenarios**:

1. **Given** the super admin is signed in, **When** they open the Admin menu, **Then** "Zone de danger"
   still appears and opens the screen.
2. **Given** the super admin is on the danger zone screen, **When** they perform any of its actions,
   **Then** the action succeeds exactly as it does today.

---

### User Story 4 - The super admin role cannot be granted, transferred, or taken away (Priority: P2)

Nowhere in the product — not on the Users list, not on an individual account's detail screen, not
anywhere an administrator's rights are managed — is there a way to make a second account into a super
admin, to hand the role to someone else, or to remove it from the account that holds it. Granting or
revoking standard admin rights, which already exists, is unaffected and keeps working on every account
including the super admin's own.

**Why this priority**: This is what keeps "exactly one super admin, ever" true over the site's entire
lifetime, not just at launch. It matters less on day one than Stories 1–3, which is why it is P2, but a
missed case here is a permanent, unrecoverable state change.

**Independent Test**: As the super admin, open another account's detail screen and confirm there is no
control offering to make it a super admin, and confirm there is no control on the super admin's own
account offering to remove the role.

**Acceptance Scenarios**:

1. **Given** the super admin is viewing another account's detail screen, **When** they look for a way
   to grant that account the super admin role, **Then** no such control exists.
2. **Given** the super admin is viewing their own account, **When** they look for a way to give up or
   transfer the super admin role, **Then** no such control exists.
3. **Given** any account other than the super admin's, **When** its standard admin rights are granted or
   revoked through the existing controls, **Then** only its standard admin status changes — the super
   admin role is never affected, and the total count of super admins on the site remains exactly one.

---

### Edge Cases

- Two people complete registration at the same moment on a site that has no accounts yet: exactly one
  of them ends up as the super admin; the other registers as an ordinary standard account, the same way
  today's "first account becomes administrator" race is already resolved.
- The super admin attempts to cancel/delete their own account while any other account exists (even one
  held by another admin): this is refused, because no other account can ever take over the super admin
  role afterward and the site would permanently lose it (FR-010, FR-014).
- The super admin is the only account left on the entire site (every other account has been cancelled or
  removed) and attempts to cancel: this succeeds — the site returns to having no accounts at all, and
  the next person to register becomes the new super admin, the same as the very first registration ever
  did.
- A standard admin who is not the super admin cancels their own account while they are the only other
  admin besides the super admin: this succeeds without restriction, because the super admin's own
  permanence already guarantees the site is never left without an administrator.
- A standard admin's session has the danger zone screen open (e.g. from before this feature shipped, or
  via a saved link) and they try to act on it: the action is refused the same as a fresh direct visit
  would be.
- A super admin also grants themselves nothing extra by using the standard admin grant/revoke controls
  on their own account — those controls never apply to the super admin's own row.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support a "super admin" role, distinct from the existing "admin" role, held
  by at most one account at any time.
- **FR-002**: System MUST assign the super admin role automatically to the account created by the very
  first successful registration on the site, at the moment that account is created, with no manual
  action by anyone.
- **FR-003**: System MUST NOT assign the super admin role to any account other than the very first one
  registered — every account registered afterward starts, and remains, without it unless standard admin
  rights are separately granted to it.
- **FR-004**: System MUST grant the super admin every capability a standard admin has, in addition to
  the super admin's own.
- **FR-005**: System MUST restrict access to the danger zone screen, and every action it offers
  (including managing the allowed email domains and changing the site language), to the super admin
  only.
- **FR-006**: System MUST refuse a standard admin's or non-admin's attempt to view the danger zone
  screen or submit any of its actions, including when the screen or an action is addressed directly
  rather than reached through the Admin menu.
- **FR-007**: The Admin menu MUST NOT present the "Zone de danger" entry to a standard admin, while
  continuing to present it to the super admin.
- **FR-008**: System MUST NOT offer any control, on any screen, that grants the super admin role to an
  account other than the one that received it automatically under FR-002.
- **FR-009**: System MUST NOT offer any control, on any screen, that removes, transfers, or reassigns
  the super admin role away from the account holding it.
- **FR-010**: System MUST prevent the account holding the super admin role from cancelling or deleting
  its own account whenever any other account exists on the site, since no successor could ever take
  over the role afterward — regardless of how many other admins exist among those other accounts. The
  one exception is the account holding the super admin role being the sole remaining account on the
  site: it may still cancel then, exactly as the very first account on an empty site always could,
  because the site returns to the empty state the role is established from (the next registration
  becomes the new super admin, same as the first).
- **FR-011**: System MUST continue treating the super admin as an admin for every purpose unrelated to
  the danger zone — appearing among administrators, granting or revoking standard admin rights on other
  accounts, and viewing account detail — with no loss of any capability a standard admin already has.
- **FR-012**: Granting or revoking standard admin rights on an account MUST have no effect on the super
  admin role — it can never be acquired, extended, or removed through those controls.
- **FR-013**: On a site where accounts already exist when this feature is delivered, the account already
  holding the site's sole bootstrap-administrator status MUST be promoted to super admin at that moment,
  with no registration event required to trigger it and no manual step taken by anyone.
- **FR-014**: FR-010's protection replaces, rather than adds to, any prior rule that only blocked
  cancelling an admin account when it was the last one keeping the site administered. Because the super
  admin is a permanent admin for as long as any other account exists, the site can never actually reach
  "registered accounts with no administrator" while it has one — an admin account that is not the super
  admin MUST be cancellable at any time, regardless of how many other admins remain, since the super
  admin itself is always still there.

### Key Entities

- **Super admin**: a role held by exactly one account for the entire life of the site once registration
  has happened at least once. Established automatically and permanently by the first registration;
  carries every standard admin capability plus exclusive access to the danger zone screen and its
  actions.
- **Danger zone screen**: the site-wide, sensitive settings screen (allowed email domains, site
  language) whose access narrows from "every admin" to "the super admin only" under this feature.
- **Standard admin** (as this spec uses the term): an account with the existing "admin" rights but not
  the super admin role — called a "granted administrator" in the codebase's own comments and locale
  strings, since its rights were granted after the fact rather than claimed at first registration (015).
  Distinct from the product's own "Standard" role label, which instead marks an account with **no** admin
  rights at all — this spec never uses "standard" on its own to mean that.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a site with no accounts yet, the first completed registration results in an account
  with full danger zone access with zero additional steps taken by anyone.
- **SC-002**: 100% of attempts by a non-super-admin account to view the danger zone screen or submit one
  of its actions are refused, regardless of how the screen or action is addressed.
- **SC-003**: A standard admin's Admin menu never lists a "Zone de danger" entry, across every account
  that is a standard admin.
- **SC-004**: At every point in time when the site has at least one registered account, exactly one of
  them holds the super admin role — never more than one, and never zero while any account exists (the
  one moment the site can be super-admin-less is between the super admin's own account being the last
  one cancelled and the next registration, per FR-010's exception).
- **SC-005**: No sequence of actions available anywhere in the product transfers the super admin role to
  a second account while the original holder's account still exists — the role only ever passes to a
  different account when the site has returned to zero accounts and a new registration establishes it
  again from scratch (FR-010's exception), never by any grant, revoke, or transfer control.

## Assumptions

- The "first user to register" is the site's existing first-account concept (today informally the
  site's sole bootstrap administrator) — this feature gives that existing, always-unique account an
  explicit name and an additional, exclusive capability, rather than introducing a second, separate way
  to detect "who registered first." On the already-running site this account is promoted immediately on
  delivery rather than waiting for a future registration (see Clarifications and FR-013).
- "Manipulate the actions of the danger zone screen" covers every write that screen currently offers:
  changing the site language and adding or removing an allowed email domain. Restricting the screen also
  restricts those actions specifically to the super admin.
- A standard admin loses no capability other than the danger zone: the Users list, account detail,
  filters, and the existing grant/revoke standard-admin controls all keep working for a standard admin
  exactly as they do today.
- The super admin role can be re-established only by a fresh registration on a completely empty site —
  either the very first registration ever, or, in the one case FR-010's exception allows, a registration
  after the super admin's own account was the last one on the site and chose to leave. Outside that
  specific reset, there is no scenario in which a second super admin could be appointed or the role moved
  between two co-existing accounts — the "at most one, ever" requirement holds at every moment the site
  is non-empty, and is never violated by any grant, revoke, or transfer control (FR-008/FR-009).
