# Feature Specification: Danger Zone – Allowed Email Domains

**Feature Branch**: `016-danger-zone-email-domains`

**Created**: 2026-09-18

**Status**: Shipped

**Input**: User description: "Ajoute un nouvel écran \"Danger Zone\" accessible depuis le menu \"Admin\", uniquement par les admin. Dans cet écran on doit pouvoir paramétrer le ou les domaines autorisés pour les adresses emails lors de l'inscription. Si ce champ n'est pas renseigné, alors tous les domaines sont autorisés. Si un utilisateur tente de créer son compte avec une adresse email sur un domaine non autorisé, l'inscription doit être refusée avec un message d'erreur \"Your email address domain is not allowed\"."

## Clarifications

### Session 2026-09-18

- Q: When an administrator allows a domain like "company.com", should addresses on subdomains of it
  (e.g. "user@mail.company.com") also be accepted, or only exact matches to what's typed? → A: Exact
  match only — "company.com" allows only addresses ending exactly in "@company.com"; subdomains must
  be added separately if wanted.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An administrator restricts sign-up to specific email domains (Priority: P1)

Signed in as an administrator, the person opens the new "Danger Zone" screen from the Admin menu.
There they enter one or more email domains (for example "company.com") as the allowed domains for
account registration and save. From that point on, anyone trying to create an account with an email
address on a different domain is refused, while people using an allowed domain can register as
before.

**Why this priority**: This is the entire capability being requested — without it, there is no way to
restrict who can self-register by email domain, which is the stated purpose of the feature.

**Independent Test**: With an administrator account, open Admin → Danger Zone, set the allowed
domains to a single domain, save, then attempt to register a new account with an email on a
different domain and observe the registration is refused with the specified error message; then
register with an email on the allowed domain and observe it succeeds.

**Acceptance Scenarios**:

1. **Given** an administrator is on the Danger Zone screen, **When** they enter one or more allowed
   email domains and save, **Then** the configuration is persisted and reflected the next time the
   screen is opened.
2. **Given** at least one allowed domain is configured, **When** a person attempts to register using
   an email address whose domain is not in the allowed list, **Then** the registration is refused, no
   account is created, and the error message "Your email address domain is not allowed" is shown.
3. **Given** at least one allowed domain is configured, **When** a person attempts to register using
   an email address whose domain matches one of the allowed domains, **Then** the registration
   proceeds exactly as it does today.

---

### User Story 2 - An administrator lifts the restriction (Priority: P2)

An administrator who previously configured allowed domains, or who has never configured any, leaves
the allowed-domains field empty and saves. With no domain configured, registration is open to email
addresses on any domain, matching the product's current behavior before this feature existed.

**Why this priority**: This is the documented default and escape hatch — it must work reliably so
the restriction is never a one-way door, and administrators can immediately restore today's open
behavior.

**Independent Test**: With no allowed domains configured (or after clearing a previous
configuration), attempt to register with an email address on any domain and observe the registration
succeeds as before.

**Acceptance Scenarios**:

1. **Given** the allowed-domains field on the Danger Zone screen is empty, **When** a person registers
   with an email address on any domain, **Then** the registration proceeds exactly as it does today.
2. **Given** an administrator previously configured one or more allowed domains, **When** they remove
   all of them and save, **Then** subsequent registration attempts are no longer restricted by domain.

---

### User Story 3 - Only administrators can reach the Danger Zone (Priority: P3)

A non-administrator user, whether signed out, signed in as a standard user, or attempting to open the
Danger Zone screen directly, cannot see the "Danger Zone" entry in the Admin menu and cannot view or
change the allowed-domains configuration.

**Why this priority**: The feature is explicitly scoped to administrators only; without this
restriction the configuration that gates who can join the product would itself be open to abuse.

**Independent Test**: Signed in as a standard (non-administrator) user, confirm the Admin menu (or
its Danger Zone entry) is not shown, and confirm that navigating directly to the Danger Zone screen's
location does not display or allow changes to the allowed-domains configuration.

**Acceptance Scenarios**:

1. **Given** a standard user is signed in, **When** they look at the navigation, **Then** no "Admin"
   menu entry or "Danger Zone" screen is available to them.
2. **Given** a standard user attempts to reach the Danger Zone screen directly, **When** the system
   responds, **Then** access is refused and the allowed-domains configuration is neither shown nor
   editable.
3. **Given** an administrator is signed in, **When** they open the Admin menu, **Then** a "Danger
   Zone" entry is available and opens the screen described above.

---

### Edge Cases

- What happens when an administrator enters a domain with inconsistent casing (e.g.
  "Example.COM")? Matching against email domains at registration MUST be case-insensitive.
- What happens when an administrator enters the same domain twice, or with surrounding whitespace?
  Duplicates and stray whitespace MUST be normalized so the list has no functional duplicates.
- What happens when an administrator enters a value that is not a syntactically valid domain (e.g.
  "not a domain", an empty entry among others, or an email address instead of a domain)? The system
  MUST reject the invalid entry with a clear error and MUST NOT save an invalid configuration.
- What happens if a registration request is already in flight when an administrator changes the
  configuration? The allowed-domains check MUST be evaluated at the moment the registration is
  submitted, using whatever configuration is current at that time.
- What happens to existing accounts whose email domain would not be allowed under a newly saved
  configuration? Existing accounts MUST be unaffected — the restriction applies only to new account
  registration, not retroactively.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a "Danger Zone" screen, reachable from an "Admin" menu entry.
- **FR-002**: The system MUST restrict both the "Admin" menu entry leading to it and the Danger Zone
  screen itself to users holding administrator rights; non-administrator users (including signed-out
  visitors) MUST NOT see the entry or be able to view or modify its contents.
- **FR-003**: The Danger Zone screen MUST let an administrator view the current list of allowed email
  domains, add domains to it, remove domains from it, and save the result.
- **FR-004**: When the allowed-domains configuration is empty, the system MUST allow account
  registration with an email address on any domain.
- **FR-005**: When the allowed-domains configuration contains one or more domains, the system MUST
  refuse any account registration attempt whose email address domain does not match one of the
  configured domains.
- **FR-006**: When a registration attempt is refused for this reason, the system MUST NOT create an
  account and MUST present the error message "Your email address domain is not allowed".
- **FR-007**: Domain matching between a submitted email address and the allowed-domains configuration
  MUST be case-insensitive and MUST be an exact match on the domain portion of the email address (the
  part after "@"); a subdomain of an allowed domain MUST NOT be accepted unless it is itself listed as
  an allowed domain.
- **FR-008**: The system MUST validate each domain entered by an administrator for basic syntactic
  validity before saving, and MUST reject the save with a clear error if any entry is invalid.
- **FR-009**: The system MUST persist the allowed-domains configuration so it continues to apply to
  registration attempts until an administrator changes it again.
- **FR-010**: The system MUST NOT apply the allowed-domains restriction to existing accounts or to
  flows other than new account registration (e.g., sign-in, password reset).

### Key Entities

- **Allowed Email Domain**: A single domain string (e.g. "company.com") that email addresses are
  checked against during registration.
- **Danger Zone Configuration**: The administrator-managed collection of Allowed Email Domain entries
  that governs registration; an empty collection means no restriction.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An administrator can configure, change, or fully clear the allowed email domains and
  have the new configuration take effect in under 1 minute, with no support intervention needed.
- **SC-002**: 100% of registration attempts using an email domain outside a configured allowed list
  are refused with the exact error message "Your email address domain is not allowed", and no account
  is created for them.
- **SC-003**: 100% of registration attempts using an email domain inside a configured allowed list,
  or made while no restriction is configured, succeed exactly as registration did before this feature.
- **SC-004**: 0% of non-administrator users are able to view or change the allowed-domains
  configuration, verified by attempting access as a standard user and as a signed-out visitor.

## Assumptions

- Administrators enter allowed domains as a simple list (e.g., one per line or comma-separated); the
  exact input widget is a design detail left to planning, not a scope decision. Planning settled this
  as one domain added or removed per action, each persisted immediately — not a multi-domain batch
  save (see `contracts/danger-zone.md` "Add form").
- The restriction applies only to new self-registration; it does not retroactively affect accounts
  that already exist, and does not apply to other flows such as sign-in or password reset.
- No domain-ownership verification (e.g., DNS or email confirmation of the domain itself) is required;
  the check is a string match against the configured list.
- Changes to the allowed-domains configuration take effect immediately for registration attempts
  submitted after the save, with no propagation delay from the user's perspective.
