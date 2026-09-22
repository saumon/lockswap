# Phase 0 Research: Admin User Detail View

**Feature**: [../spec.md](../spec.md) | **Branch**: `027-admin-user-detail-view`

No item in the spec's Technical Context was left as `NEEDS CLARIFICATION` — every unknown was either
resolved during `/speckit-clarify` or has a reasonable default already established by an existing
feature in this codebase. This document records the design decisions those defaults imply, so Phase 1
has a fixed shape to build `data-model.md` and `contracts/` against.

## R1: Access control for the new destinations

**Decision**: Every new controller (`Admin::UsersController#show`,
`Admin::UserLockerProfilesController`, `Admin::UserLockerWishesController`) gets the identical
`before_action :authenticate_user!` then `before_action :require_admin!` pair
`Admin::UsersController` already carries for `#index`/`#grant_admin`.

**Rationale**: `require_admin!` (`ApplicationController`) is already written as the site's one rule for
every admin-only destination (013 FR-004/FR-008), not scoped to one controller. Reusing it rather than
writing a parallel check is what FR-002 ("refusing the request the same way other admin-only
destinations are refused") literally asks for.

**Alternatives considered**: A single shared before_action module — rejected as unnecessary
indirection; three `before_action` pairs is not duplicated logic in the sense Principle I means (it is
the same one-line guard every other admin controller in this codebase already repeats), and Rails
controller concerns exist for exactly this if it ever grows past "paste two lines."

## R2: No new client-side pattern

**Decision**: The pencil-icon edit disclosure reuses `<details>`/`<summary>` exactly as
`home/_locker_profile.html.erb` (009) already does; the cancel-search confirmation reuses the
`data: { confirm:, turbo_confirm: }` pattern the "Grant admin rights" `button_to` on this same screen
already uses (015). No new Stimulus controller, no new CSS component.

**Rationale**: Constitution III requires justifying any *new* pattern in the PR; the stronger and
cheaper move is to need no justification because nothing new is introduced. Both existing patterns
already solve exactly the interaction this feature needs (an inline editable disclosure; a
confirm-before-destructive-action control), on the same screen family.

**Alternatives considered**: A modal dialog for the edit form or the confirmation — rejected, no
modal pattern exists anywhere in this codebase's stylesheet (CLAUDE.md's own "what this design is
not" list plus the absence of any `<dialog>`/modal CSS component), so introducing one here would be
exactly the "invent a new pattern where an established one already solves the problem" Principle III
flags.

## R3: Provenance columns for the two new admin-on-behalf-of writes

**Decision**: Two independent nullable pairs on `users`: `locker_edited_by_id`/`locker_edited_at` and
`search_cancelled_by_id`/`search_cancelled_at`. Each `_by` is a `belongs_to ... optional: true` foreign
key to `users`, `nullify` (not `dependent: :destroy`) on the referenced account's deletion — the exact
shape `admin_granted_by_id`/`admin_granted_at` (015, migration
`20260918113055_add_admin_grant_provenance_to_users.rb`) already established.

**Rationale**: The Clarifications session settled that both actions must be attributed. Three separate
facts — who granted admin rights and when, who last edited floor/locker on the account's behalf and
when, who last cancelled the account's search on its behalf and when — are three independent pairs
rather than one generalized "last admin action" log, because each is scoped to its own kind of action
and each is read from its own place on the detail screen. `nullify` (not cascade) mirrors 015 FR-019's
reasoning exactly: the fact that an admin once acted must outlive that admin's own account being later
cancelled.

**Alternatives considered**: A single polymorphic "admin action log" table — rejected as scope beyond
what either the spec or the Clarifications session asked for (no requirement asks for a full audit
log of every admin action, only that these two specific facts be recorded and shown on the detail
screen); revisit only if a future feature asks for a general audit trail, at which point these two
pairs could migrate into it.

**Left to the implementer**: whether self-service edits (the account holder editing their own
floor/locker or cancelling their own search) should clear these two pairs. No requirement asks for
this, and leaving them untouched by self-service actions is the simpler default (mirrors
`admin_granted_by`/`admin_granted_at`, which nothing but a grant itself ever touches) — the provenance
line reads "an administrator last touched this on `<date>`," which remains true even if the account
holder has since made their own changes, and is not claimed to describe the *current* values.

## R4: Proposal-history table is shared, not duplicated

**Decision**: Extract the six-column table body in `locker_swap_proposals/index.html.erb` (direction,
person, sent, status, comment, locker details) into a partial, parameterized by the collection of
proposals and the viewer whose perspective "sent"/"received" is judged from. Both
`locker_swap_proposals/index.html.erb` (self-service) and the new `admin/users/show.html.erb` render
it.

**Rationale**: FR-006 asks the detail screen's history to look exactly like the existing self-service
one; duplicating ~70 lines of ERB to get that is precisely the "duplicated logic... MUST be refactored
rather than repeated" case Principle I names, and two independently-maintained copies is exactly the
kind of drift risk the constitution's Code Quality principle exists to prevent.

**Alternatives considered**: Leaving the self-service view untouched and writing a second, separate
table for the admin screen — rejected for the duplication reason above. A view helper returning HTML
strings instead of a partial — rejected as a worse fit for a six-column, role-conditional table than
ERB's own partial mechanism.

## R5: Query shape for "this account's proposals, in either role"

**Decision**: Two bounded queries unioned in Ruby —
`(user.sent_swap_proposals.includes(:recipient).to_a + user.received_swap_proposals.includes(:requester).to_a).sort_by(&:created_at).reverse`
— exactly the expression `LockerSwapProposalsController#index` already uses for `current_user`,
applied to the viewed account instead.

**Rationale**: `LockerSwapProposal`'s own model comments record a real, previously-hit failure mode:
SQLite 3.53's query planner faults ("internal query planner error") when it tries to `OR`-optimize a
scan of this table against its partial unique indexes (see `User#in_progress_for?`'s comment). The
self-service history action already avoids a single `OR` query for the same reason (merging two
`ActiveRecord::Relation`s in Ruby instead); reusing that exact expression rather than writing a new
`.where(requester_id: ...).or(.where(recipient_id: ...))` avoids reintroducing a bug this codebase has
already found and fixed once.

**Alternatives considered**: A single `OR` query — rejected for the reason above. A `UNION` SQL
query — rejected as unnecessary complexity for a per-account result set this small (bounded by one
account's own proposal count, not the site's).

## R6: "Party to an active proposal" for FR-005

**Decision**: The same two-query-then-union shape as R5, filtered to `pending`/`accepted` before the
union (`user.sent_swap_proposals.pending.or(...)` avoided for the same planner-fault reason — composed
instead as `.sent_swap_proposals.where(status: [:pending, :accepted])` unioned with the recipient-side
equivalent). Zero, one, or more than one such proposal is possible (nothing in the model prevents an
account from being the requester on several simultaneous pending proposals), so the detail screen
shows all of them, not a single "the" active proposal.

**Rationale**: `LockerSwapProposal`'s own creation validations (`no_pending_proposal_already_stands`,
`neither_party_is_already_in_an_exchange`) block a second *accepted* exchange and a second pending
proposal *between the same two parties*, but do not block a requester from having several distinct
pending proposals open with different recipients at once. FR-005 only asks that the screen show
whether the account is party to at least one such proposal (and what it is), not that there can only
ever be one — assuming a singular case would misrepresent a state the data model already allows.

**Alternatives considered**: Assuming at most one active proposal and rendering a single summary line
— rejected as inaccurate to what the existing validations actually permit.

## R7: Row-link element on the Users list (FR-001)

**Decision**: A plain `link_to` around the email cell's text (reusing the existing
`#admin-user-row-<%= user.id %>-...` id convention for a new `-detail-link` id), pointing at
`admin_user_path(user)`. Not a click handler on the `<tr>`.

**Rationale**: Settled directly by the Clarifications session. A plain link needs no JavaScript, is
keyboard-operable by construction, and announces correctly to assistive technology with no extra
`aria-*` work — the properties the clarification's reasoning named as the reason to prefer it over a
whole-row click target.

**Alternatives considered**: A dedicated "View" link in the existing Actions column (currently holding
only the "Grant admin rights" control, or an em dash for the row that already has the rights) — a
reasonable alternative placement, left to the implementer/design pass in Phase 1's `contracts/`
document rather than fixed here, since the Clarifications session settled *that* a distinct link
exists, not *where* in the row it sits.

## R8: i18n

**Decision**: Every new user-facing string is added under `admin.users.show.*` (and small
controller-level keys for the two new actions' flashes, `admin.users.update_locker_profile.*` /
`admin.users.cancel_search.*` or equivalent nested under each new controller's own namespace) in both
`config/locales/en.yml` and `config/locales/fr.yml`, matching the existing key-nesting convention
(`admin.users.index.*`, `admin.users.grant_admin.*`).

**Rationale**: Constitution III's i18n bullet is unconditional or bug-per-string; no research is needed
beyond confirming the existing enforcement (`test/i18n_completeness_test.rb`) already covers any key
added under `admin.*` without a feature-specific change to that test.

**Alternatives considered**: None — this is not a decision point, just confirmation that the existing
mechanism already covers new keys.
