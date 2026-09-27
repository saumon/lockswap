# Feature Specification: Administrator Validation of Locker Swap Exchanges

**Feature Branch**: `033-admin-swap-validation`

**Created**: 2026-09-27

**Status**: Draft

**Input**: User description: "Les services généraux (les admin ou superadmin) doivent avoir la main pour la
finalisation de l'échange de casiers (ils ont des associations de badge à faire dans leur système). Un
nouvel écran de validation (ou refus) des propositions d'échanges doit donc être créé, et accessible
uniquement des utilisateurs administrateurs (ou super administrateurs). Cet écran permet de lister toutes
les demandes d'échanges en attente de validation, de pouvoir accepter ou refuser les demandes (un
commentaire peut être saisi pour expliquer le refus). Un utilisateur standard ne peut plus confirmer
lui-même l'échange en cours (après acceptation de la proposition), c'est un admin qui valide l'échange via
ce nouvel écran. Du côté utilisateur, lorsqu'une proposition d'échange a été accepté, l'échange est en
attente de validation d'un admin. Il faut changer le libellés "Échange en cours" par "Échange à valider".
Le libellé "Une fois que vous avez réellement échangé vos casiers, confirmez-le ici et les deux jeux de
détails seront échangés" doit être changé en "Votre demande d'échange est en attente de validation.
Rapprochez-vous des services généraux pour l'échange physique des casiers et ainsi finaliser la demande"."

## Clarifications

### Session 2026-09-27

- Q: When this feature ships, what should happen to exchanges that are already accepted and were waiting on
  the user's own self-confirmation (the control this feature removes)? → A: Immediately show them in the new
  admin-validation queue, exactly like any newly-accepted exchange.
- Q: If an administrator is themselves one of the two parties to an accepted exchange, should they be allowed
  to validate or refuse that exchange from the admin screen? → A: Allow it — administrators can validate or
  refuse any listed exchange, including their own.
- Q: Which label should replace "Échange en cours" for an accepted exchange? → A: "En attente de
  validation" (English: "Awaiting validation"), superseding the "Échange à valider" quoted in the Input
  above — requested after implementation.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An administrator finalizes an accepted exchange (Priority: P1)

Once both parties to a locker swap have agreed to it (one proposed, the other accepted), the exchange no
longer completes itself in the system the moment the two people say they physically swapped. Instead, an
administrator or super administrator opens a new, admin-only screen listing every accepted exchange still
waiting on a decision, reviews one, and validates it — at which point the two accounts' floor and locker
details swap in the system exactly as a self-confirmation used to do it, and the exchange is recorded as
completed. This is also the moment the services généraux team does the matching badge-access work in their
own system, which is the entire reason this control needed to move to them.

**Why this priority**: This is the core of the request — without it, nothing changes about who can finalize
an exchange, and the badge-association problem the request exists to solve is not addressed.

**Independent Test**: With a proposal already accepted by its recipient, sign in as an administrator, open
the new validation screen, find that proposal listed, validate it, and confirm both accounts' locker details
have swapped and the proposal now reads as completed.

**Acceptance Scenarios**:

1. **Given** a proposal has been accepted by its recipient but not yet acted on by an administrator, **When**
   an administrator opens the validation screen, **Then** that proposal appears in the list of exchanges
   awaiting validation, showing both parties and their current locker details.
2. **Given** an administrator is viewing a listed exchange, **When** they validate it, **Then** the
   requester's and recipient's floor and locker details are swapped, the proposal is marked completed, and
   it no longer appears in the validation list.
3. **Given** a super administrator (rather than a standard administrator) is signed in, **When** they use the
   validation screen, **Then** they can list and validate exchanges exactly as a standard administrator can —
   this screen is not restricted to the super administrator alone.

---

### User Story 2 - An administrator refuses an exchange that should not proceed (Priority: P1)

Sometimes the physical swap did not happen as described, or the exchange should not be finalized for some
other reason services généraux discovers only when they go to do the badge work. From the same validation
screen, an administrator can refuse a listed exchange instead of validating it, optionally typing a short
comment explaining why. Refusing does not move any locker details — both people keep what they had going
in — and the exchange stops blocking either of them from proposing or accepting a different one.

**Why this priority**: Without a refusal path, a mistaken or no-longer-valid accepted exchange would have no
way to be closed out, permanently occupying both parties' "already in an exchange" status. It ships together
with validation because the screen exists to make exactly this either/or decision.

**Independent Test**: With a proposal accepted and awaiting validation, sign in as an administrator, refuse
it with a comment, and confirm neither party's locker details changed, the proposal now reads as declined
with that comment, and both parties are free to take part in a new exchange.

**Acceptance Scenarios**:

1. **Given** an administrator is viewing a listed exchange, **When** they refuse it without entering a
   comment, **Then** the exchange is recorded as declined, neither party's locker details change, and it no
   longer appears in the validation list.
2. **Given** an administrator is viewing a listed exchange, **When** they refuse it and enter a comment
   explaining why, **Then** the exchange is recorded as declined together with that comment, visible to both
   parties the same way a recipient's own decline comment already is today.
3. **Given** an exchange was just refused by an administrator, **When** either of its two parties is
   considered for a new swap proposal afterward, **Then** neither is treated as still being in an exchange
   because of the refused one.

---

### User Story 3 - Standard users can no longer confirm their own exchange (Priority: P1)

A standard user who is party to an accepted exchange no longer has any control to finalize it themselves.
Where the "Confirm exchange completed" button used to appear (for the recipient) and the "waiting on their
confirmation" message used to appear (for the requester), both parties instead see that the exchange is
"En attente de validation" and read a message telling them their request is awaiting an administrator's validation
and that they should go see services généraux in person to complete the physical locker swap.

**Why this priority**: This is the flip side of Story 1 and 2 — the feature only makes sense if the old
self-service confirmation is retired at the same time the admin-only path replaces it. Shipping the new
screen without also removing the old button would leave two conflicting ways to finalize the same exchange.

**Independent Test**: With a proposal accepted, sign in as the requester and separately as the recipient and
confirm neither sees any control to confirm or finalize the exchange, and both see the "En attente de validation"
label and the new waiting-for-admin message instead of the retired confirm instructions.

**Acceptance Scenarios**:

1. **Given** a user's proposal has been accepted, **When** they view their homepage, **Then** they see the
   status labeled "En attente de validation" rather than "Échange en cours".
2. **Given** a user's proposal has been accepted, **When** they view their homepage, **Then** they see the
   message "Votre demande d'échange est en attente de validation. Rapprochez-vous des services généraux pour
   l'échange physique des casiers et ainsi finaliser la demande" and no button or control offering to confirm
   or finalize the exchange themselves — this applies equally whether they are the requester or the
   recipient, since neither role retains a self-service action once a proposal is accepted.
3. **Given** a user attempts to trigger the exchange's completion directly (for example, by revisiting a
   previously bookmarked confirmation action), **When** that attempt is made, **Then** it is refused, since
   only an administrator can finalize an accepted exchange from this point on.

---

### Edge Cases

- A standard user (not an administrator) attempts to view or use the new validation screen directly: access
  is refused, the same way the rest of the Admin section is already closed to non-administrators.
- Two administrators open the validation screen at the same time and both act on the same listed exchange:
  only the first action (validate or refuse) takes effect; the second is refused rather than applied on top
  of an exchange that has already moved on, since it is no longer awaiting a decision.
- The validation screen is opened when no exchange is currently awaiting a decision: the screen shows that
  the list is empty rather than showing nothing or erroring.
- An administrator refuses an exchange whose two parties, in the meantime, are no longer eligible to have
  been matched at all (for example, one of them no longer has a locker search open): the refusal still
  succeeds, exactly like an ordinary recipient decline does today — refusing never depends on either party
  still wanting the exchange.
- A validated exchange's two parties are shown the completed swap the same way a self-confirmed one already
  is today (in their exchange history) — validation by an administrator is not visually distinguishable in
  its outcome from what self-confirmation used to produce, only in who performed it.
- An exchange that was already accepted before this feature shipped, and so was still waiting on the
  now-removed self-confirmation control: it appears in the admin validation queue exactly like any exchange
  accepted after rollout — there is no separate rollout state, and no such exchange is auto-completed or left
  stuck without a path to a decision.
- An administrator who is themselves the requester or recipient of a listed exchange: they can still validate
  or refuse it like any other administrator — the screen applies no special case based on who is signed in.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a screen, reachable only by signed-in administrators (standard
  administrators and the super administrator alike), that lists every locker swap proposal currently
  accepted and awaiting a validation decision, regardless of when it was accepted (including one accepted
  before this feature existed).
- **FR-002**: The validation screen MUST show, for each listed exchange, both parties involved and their
  current floor and locker details, the same information already shown to the two parties themselves while
  their exchange is pending finalization.
- **FR-003**: System MUST refuse access to the validation screen, and to the validate/refuse actions it
  offers, for any signed-in user without administrator rights, and for anonymous visitors. An administrator
  who is themselves the requester or recipient of a listed exchange MAY still validate or refuse it — no
  additional restriction applies based on who the signed-in administrator is.
- **FR-004**: An administrator MUST be able to validate a listed exchange. Doing so MUST swap the two
  parties' floor and locker details and mark the proposal completed — the same outcome the retired
  self-confirmation used to produce.
- **FR-005**: An administrator MUST be able to refuse a listed exchange instead of validating it. Doing so
  MUST NOT change either party's floor or locker details, and MUST mark the proposal declined.
- **FR-006**: When refusing an exchange, the administrator MAY enter a free-text comment explaining the
  refusal; the comment is optional, and its absence MUST NOT block the refusal.
- **FR-007**: A refusal comment entered by an administrator MUST be shown to both parties of the refused
  exchange, the same way a comment on a recipient's own decline is shown today.
- **FR-008**: An exchange refused by an administrator MUST NOT continue to count either party as "already in
  an exchange" afterward — both remain free to send, receive, and accept a new swap proposal.
- **FR-009**: Once a listed exchange has been validated or refused, it MUST no longer appear among the
  exchanges awaiting validation.
- **FR-010**: If an administrator acts (validate or refuse) on an exchange that has already been decided by
  that time (by another administrator, or otherwise no longer awaiting a decision), the system MUST reject
  that action rather than apply it a second time.
- **FR-011**: System MUST remove the standard user's own ability to confirm or finalize an accepted exchange;
  neither the requester nor the recipient retains any control that completes the exchange once it has been
  accepted.
- **FR-012**: A standard user whose proposal is accepted MUST see the exchange's status labeled "Échange à
  valider" instead of the retired "Échange en cours" label, in every place that status is shown.
- **FR-013**: A standard user whose proposal is accepted MUST see the message "Votre demande d'échange est en
  attente de validation. Rapprochez-vous des services généraux pour l'échange physique des casiers et ainsi
  finaliser la demande" replacing the retired confirmation instructions, shown identically to the requester
  and the recipient.
- **FR-014**: System MUST record which administrator validated or refused each exchange, and when, so the
  decision has the same kind of accountable record other administrative actions on the site already carry.

### Key Entities

- **Locker swap proposal**: the existing exchange-request record between two users. This feature adds a new
  decision step, taken by an administrator rather than by the exchange's own recipient, between a proposal
  being accepted and it being completed or, newly, refused after acceptance. Its optional decline comment is
  reused to carry an administrator's refusal explanation.
- **Administrator** (standard or super administrator): the only actor able to reach the new validation
  screen and decide the outcome of an accepted exchange. The two administrator levels are treated
  identically for this feature — neither is exclusive to it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of locker exchanges completed after this feature ships are finalized through an
  administrator's validation — none complete through any remaining standard-user action.
- **SC-002**: Every exchange awaiting validation is visible to an administrator from a single screen, with
  both parties' identity and locker details readable without leaving that screen.
- **SC-003**: 100% of attempts by a non-administrator to view or act on the validation screen are refused.
- **SC-004**: No exchange is ever validated or refused more than once, even when two administrators act on
  the same listed exchange at nearly the same time.
- **SC-005**: A standard user with an accepted proposal always sees the "En attente de validation" label and the
  new waiting-for-admin message, and never sees a control to confirm or finalize the exchange themselves.

## Assumptions

- "Admin or super admin" means both administrator levels already established on this site (029's super
  admin role); this feature does not add a new, narrower permission level, and does not restrict the
  validation screen to the super administrator the way the existing danger zone is restricted.
- The validation screen lists every accepted exchange site-wide, with no filtering by floor or other
  criteria, consistent with how the existing admin Users screen shows the whole population by default.
- Refusing an accepted exchange reuses the same "declined" outcome and optional comment field an ordinary
  recipient decline already produces; no new proposal state is introduced, only a new actor (an
  administrator) and a new starting point (an already-accepted proposal rather than only a pending one) able
  to reach it.
- Since neither the requester nor the recipient retains any action once a proposal is accepted, both now see
  the identical waiting-for-admin message; the previous distinction between "confirm it yourself" (recipient)
  and "waiting for their confirmation" (requester) no longer applies.
- No additional notification channel (e-mail, etc.) is introduced by this feature; the decision is
  surfaced the same way existing decisions already are, through the affected users' homepage the next time
  they view it.
- English-language copy for the two changed labels follows the same change as the French copy quoted in this
  spec, keeping both locales consistent, even though the feature request only quoted the French text.
