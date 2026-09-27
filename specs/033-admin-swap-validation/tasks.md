---

description: "Task list for feature implementation"
---

# Tasks: Administrator Validation of Locker Swap Exchanges

**Input**: Design documents from `/specs/033-admin-swap-validation/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md,
contracts/admin-swap-validation.md, quickstart.md (all present)

**Tests**: Included and REQUIRED. This repository's constitution (`.specify/memory/constitution.md`,
Principle II, NON-NEGOTIABLE) mandates a failing-first automated test for every new feature and bug fix;
nothing in this feature's spec exempts it.

**Organization**: Tasks are grouped by user story (spec.md's US1–US3, all Priority P1) to enable
independent implementation and testing of each story. All three are needed for a complete, non-transitional
rollout (US3 retires the self-confirm control US1/US2 replace — see Implementation Strategy), but each is
independently testable per the rules this file follows.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US3)
- Every task names its exact file path(s)

## Path Conventions

Single Rails monolith at the repository root (`app/`, `config/`, `test/`) — unchanged from every prior
feature.

---

## Phase 1: Setup

No setup tasks are needed. This feature adds no new dependency and no new project scaffolding — it
extends existing controllers, models, views, routes, and locale files with the one migration Phase 2
covers.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The one new column both decisions need to attribute themselves to an administrator
(`admin_decided_by_id`), the model changes both `confirm!` and `decline!` share, and the admin-only
list screen itself (read-only: no decision can be made on it yet) — everything US1 (validate) and US2
(refuse) build on.

**⚠️ CRITICAL**: No user story phase can begin until this phase is complete.

- [X] T001 Create migration `db/migrate/<timestamp>_add_admin_decided_by_to_locker_swap_proposals.rb`:
  ```ruby
  class AddAdminDecidedByToLockerSwapProposals < ActiveRecord::Migration[8.1]
    def change
      add_column :locker_swap_proposals, :admin_decided_by_id, :integer
      add_index :locker_swap_proposals, :admin_decided_by_id
      add_foreign_key :locker_swap_proposals, :users, column: :admin_decided_by_id
    end
  end
  ```
  Run `bin/rails db:migrate` and confirm `db/schema.rb` regenerates with the new column, its index, and
  its foreign key (data-model.md "New column: `admin_decided_by_id`").
- [X] T002 [P] In `app/models/locker_swap_proposal.rb`, add `belongs_to :admin_decided_by, class_name:
  "User", optional: true` immediately after the existing `belongs_to :requester`/`belongs_to :recipient`
  (lines 6-7), with a one-line comment noting it records which administrator validated or refused this
  proposal, when one did (033 FR-014; nil for a decision either party made about their own exchange).
- [X] T003 [P] In `app/models/user.rb`, add `has_many :swap_decisions_made, class_name:
  "LockerSwapProposal", foreign_key: :admin_decided_by_id, dependent: :nullify, inverse_of:
  :admin_decided_by`, placed alongside the existing `locker_edited_by`/`search_cancelled_by`
  associations (around lines 39-47) — same `dependent: :nullify` reasoning already documented there
  (data-model.md; research.md R5).
- [X] T004 In `app/models/locker_swap_proposal.rb`:
  - Widen `decline!`'s guard (currently `return false unless pending?`, around line 68) to `return false
    unless pending? || accepted?` (research.md R4), updating its leading comment to say the guard now
    also covers an administrator refusing an already-accepted exchange (033 FR-005).
  - Add `by: nil` as a keyword argument to both `confirm!` (line 77) and `decline!` (line 67), and add
    `admin_decided_by: by` to each method's `update!` call (data-model.md "Method signature changes").
    Every existing caller (`LockerSwapProposalsController#accept`/`#decline`) is unaffected — neither
    passes `by:`.
  (Depends on T002.)
- [X] T005 [P] In `test/models/locker_swap_proposal_test.rb`, add:
  - `"an accepted proposal can now be declined, not only a pending one"`: build an `accepted`
    `LockerSwapProposal`, call `decline!("no longer valid")`, assert it returns truthy, the proposal is
    `declined?`, `decline_comment` is set, and neither party's floor/locker changed (research.md R4).
  - `"a declined, withdrawn, or completed proposal still cannot be declined again"`: for each of those
    three statuses, assert `decline!` returns `false` and the status is unchanged (regression check on
    the widened guard).
  - `"confirm! records which administrator decided it, when given one"`: build an `accepted` proposal,
    call `confirm!(by: users(:grace))`, assert `admin_decided_by == users(:grace)`.
  - `"confirm! leaves admin_decided_by nil when no administrator is given"`: same setup, call `confirm!`
    with no `by:`, assert `admin_decided_by.nil?` (unchanged behavior for the retired self-confirm path).
  - `"decline! records which administrator decided it, when given one"` / `"decline! leaves
    admin_decided_by nil when no administrator is given"`: same pair, for `decline!` (data-model.md;
    research.md R3).
  (Depends on T004; write these first and confirm they fail against T002/T003 alone, before T004 lands.)
- [X] T006 [P] In `config/routes.rb`, inside the existing `namespace :admin do ... end` block (after
  `resources :zones`), add:
  ```ruby
  # 033 FR-001: the validation queue. :index only for now — :validate/:refuse are
  # added by US1/US2 below.
  resources :swap_validations, only: :index
  ```
  (contracts/admin-swap-validation.md "Routes").
- [X] T007 Create `app/controllers/admin/swap_validations_controller.rb`:
  ```ruby
  # 033 FR-001..FR-010: the queue services généraux works from, and its two
  # decisions. Deliberately separate from LockerSwapProposalsController — that
  # one is the two parties' own self-service actions, this one is an
  # administrator acting on a proposal that is not theirs to decide by default.
  class Admin::SwapValidationsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    # FR-001, FR-002, research.md R7: every accepted proposal, oldest-waiting
    # first, both parties' zones resolved in one batched call (032 research.md
    # R3's pattern) rather than one query per row.
    def index
      @proposals = LockerSwapProposal.accepted.includes(:requester, :recipient).order(decided_at: :asc)
      @zone_names = LockerMapEntry.zone_names_for(@proposals.flat_map(&:locker_sides))
    end
  end
  ```
  (contracts/admin-swap-validation.md; depends on T006.)
- [X] T008 [P] Create `test/controllers/admin/swap_validations_controller_test.rb`:
  - `"a non-admin is refused"`: `sign_in users(:carol)`, `get admin_swap_validations_path`,
    `assert_redirected_to root_path`, `assert_equal ApplicationController::ADMINISTRATORS_ONLY_MESSAGE,
    flash[:alert]`.
  - `"an anonymous visitor is refused"`: `get admin_swap_validations_path`, `assert_redirected_to
    new_user_session_path`.
  - `"an admin sees every accepted proposal, oldest first"`: build two `accepted` proposals with
    different `decided_at` values, `sign_in users(:grace)`, `get admin_swap_validations_path`,
    `assert_response :success`, assert both parties' emails appear, in oldest-first order.
  - `"a pending, declined, withdrawn, or completed proposal is not listed"`: one of each status, confirm
    none of their parties' emails appear on the page.
  (Depends on T007; write first, confirm the access-control cases pass immediately — they exercise
  `require_admin!`, already correct — and the listing case fails until T007 lands.)
- [X] T009 Create `app/views/admin/swap_validations/index.html.erb` with the `.data-table` shell from
  contracts/admin-swap-validation.md (requester/recipient/accepted-at columns, `role="table"`/`role="row"`
  markup mirroring `locker_swap_proposals/_history_table.html.erb`'s shape, `<p class="empty-state">` for
  the empty case) — no actions column yet; US1/US2 add it. (Depends on T007.)
- [X] T010 [P] In `config/locales/en.yml` and `config/locales/fr.yml`, add a new `admin.swap_validations`
  block (alongside the existing `admin.zones`/`admin.locker_map_entries` blocks):
  ```yaml
  # en.yml
  admin:
    swap_validations:
      index:
        title: "Swap exchanges awaiting validation"
        requester_header: "Requester"
        recipient_header: "Recipient"
        accepted_at_header: "Accepted"
        empty: "No exchanges are currently awaiting validation."
  ```
  ```yaml
  # fr.yml
  admin:
    swap_validations:
      index:
        title: "Échanges de casiers en attente de validation"
        requester_header: "Demandeur"
        recipient_header: "Destinataire"
        accepted_at_header: "Accepté le"
        empty: "Aucun échange n'est actuellement en attente de validation."
  ```
- [X] T011 In `app/views/shared/_site_menu_items.html.erb`, add a link to the new screen inside the
  existing `current_user.admin?` submenu, alongside "Users" and "Locker Map" (same tier —
  `require_admin!`, not the super-admin-only "Danger Zone" link below it):
  ```erb
  <%= link_to t(".swap_validations"), admin_swap_validations_path, class: "site-nav-link",
        "aria-current": ("page" if current_page?(admin_swap_validations_path)) %>
  ```
  Add `shared.site_menu_items.swap_validations: "Swap validations"` (en) / `"Validations d'échanges"`
  (fr) to both locale files, alongside the existing `users`/`locker_map` keys in that block.
  (Depends on T007 for the route helper to exist.)

**Checkpoint**: An admin can sign in, find "Swap validations" in the Admin menu, and see every accepted
exchange listed — read-only. Neither user story below can be demonstrated without this.

---

## Phase 3: User Story 1 - An administrator finalizes an accepted exchange (Priority: P1) 🎯

**Goal**: An administrator validates a listed exchange; the two parties' floor and locker details swap,
exactly as the retired self-confirmation used to do it, and the exchange is marked completed.

**Independent Test**: With a proposal already accepted, sign in as an administrator, open
`/admin/swap_validations`, validate the listed proposal, and confirm both accounts' locker details have
swapped and the proposal now reads `completed?` (quickstart.md Scenario 1).

### Tests for User Story 1 ⚠️ Write first; confirm they fail before implementing

- [X] T012 [P] [US1] In `test/controllers/admin/swap_validations_controller_test.rb`, add:
  - `"an admin validates a listed exchange"`: build an `accepted` proposal (e.g. requester `dave`,
    recipient `bob`), `sign_in users(:grace)`, `patch validate_admin_swap_validation_path(proposal)`,
    `assert_redirected_to admin_swap_validations_path`, assert a success flash, `assert_predicate
    proposal.reload, :completed?`, assert both parties' floor/locker swapped, assert `admin_decided_by ==
    users(:grace)`.
  - `"a super admin can validate too"`: same as above signed in as `users(:frank)` — confirms the screen
    is not super-admin-exclusive (spec.md Acceptance Scenario 1.3).
  - `"validating an exchange that was already decided is refused gracefully"`: build an `accepted`
    proposal, decline it directly (`proposal.decline!`) to simulate another admin having just acted,
    then `patch validate_admin_swap_validation_path(proposal)` as a different admin, assert redirect with
    an "already decided" alert, assert the proposal is still `declined?` (not silently completed) —
    research.md R6.
  - `"an administrator can validate their own exchange"`: build an `accepted` proposal where `grace` is
    the requester or recipient, sign in as `grace`, validate it, assert success exactly as any other row
    (research.md R10, clarified).
  - `"a non-admin cannot validate"`: `sign_in users(:carol)`, `patch
    validate_admin_swap_validation_path(...)`, assert redirect/refusal, proposal unchanged.
- [X] T013 [P] [US1] Create `test/system/admin_swap_validation_test.rb` with `"an admin validates an
  exchange from the queue"`: build an accepted proposal, `log_in_as users(:grace)`, visit
  `admin_swap_validations_path`, `within` that proposal's row `click_on` the validate control, assert a
  success message, assert the row is gone, and assert (via a fresh page visit or model reload) that the
  two parties' locker details swapped.

### Implementation for User Story 1

- [X] T014 [US1] In `config/routes.rb`, add the `validate` member route to the `swap_validations`
  resource from T006:
  ```ruby
  resources :swap_validations, only: :index do
    member do
      patch :validate
    end
  end
  ```
- [X] T015 [US1] In `app/controllers/admin/swap_validations_controller.rb`, add:
  ```ruby
  # FR-004: validating is exactly what the retired self-confirmation did —
  # confirm! is unchanged except for by:, which records who did it (FR-014).
  def validate
    if accepted_proposal&.confirm!(by: current_user)
      redirect_to admin_swap_validations_path, notice: t(".validated")
    else
      redirect_to admin_swap_validations_path, alert: t(".already_decided")
    end
  end

  private

    # research.md R6: scoped to .accepted so a row that has already moved on
    # is simply not found here, rather than being found and then no-op'd
    # inside the model method.
    def accepted_proposal
      LockerSwapProposal.accepted.find_by(id: params[:id])
    end
  ```
  (Depends on T014.)
- [X] T016 [US1] In `app/views/admin/swap_validations/index.html.erb`, add an actions column with:
  ```erb
  <%= button_to t(".validate_button"), validate_admin_swap_validation_path(proposal), method: :patch,
        class: "btn btn-primary btn-sm", form: { data: { turbo_submits_with: t(".validating") } } %>
  ```
  (Depends on T009, T015.)
- [X] T017 [P] [US1] In `config/locales/en.yml`/`fr.yml`, under the `admin.swap_validations` block from
  T010, add:
  ```yaml
  index:
    actions_header: "Actions"      # / "Actions"
    validate_button: "Validate"    # / "Valider"
    validating: "Validating…"      # / "Validation en cours…"
  validate:
    validated: "Exchange validated — locker details have been swapped."
    already_decided: "That exchange was already decided."
  ```
  French: `"Échange validé — les détails des casiers ont été échangés."` /
  `"Cet échange a déjà été traité."`

**Checkpoint**: User Story 1 is complete and independently testable — an administrator can finalize any
accepted exchange from the queue.

---

## Phase 4: User Story 2 - An administrator refuses an exchange that should not proceed (Priority: P1)

**Goal**: An administrator refuses a listed exchange instead of validating it, optionally with a comment;
neither party's locker details change, and both are freed to take part in a new exchange.

**Independent Test**: With a proposal accepted and awaiting validation, sign in as an administrator,
refuse it with a comment, and confirm neither party's locker details changed, the proposal reads
`declined?` with that comment, and both parties are free to take part in a new exchange (quickstart.md
Scenario 2).

### Tests for User Story 2 ⚠️ Write first; confirm they fail before implementing

- [X] T018 [P] [US2] In `test/controllers/admin/swap_validations_controller_test.rb`, add:
  - `"an admin refuses a listed exchange without a comment"`: build an `accepted` proposal, `sign_in
    users(:grace)`, `patch refuse_admin_swap_validation_path(proposal)` with no `decline_comment`,
    assert redirect + success flash, `assert_predicate proposal.reload, :declined?`, assert neither
    party's floor/locker changed, assert `decline_comment.blank?`.
  - `"an admin refuses a listed exchange with a comment"`: same, with `params: { locker_swap_proposal: {
    decline_comment: "Physical swap did not happen" } }`, assert the comment is saved verbatim.
  - `"a refused exchange no longer counts either party as in progress"`: after refusing, assert
    `LockerSwapProposal.in_progress_for?(requester)` and `.in_progress_for?(recipient)` are both `false`.
  - `"refusing an exchange that was already decided is refused gracefully"`: mirrors T012's validate
    case — validate the proposal first (simulating another admin), then attempt to refuse it, assert an
    "already decided" alert and the proposal is still `completed?`.
  - `"a non-admin cannot refuse"`: mirrors T012's non-admin case for the refuse route.
- [X] T019 [P] [US2] In `test/system/admin_swap_validation_test.rb`, add `"an admin refuses an exchange
  with a comment"`: build an accepted proposal, `log_in_as users(:grace)`, visit
  `admin_swap_validations_path`, open that row's refuse disclosure, fill in a reason, submit, assert a
  success message and the row is gone.

### Implementation for User Story 2

- [X] T020 [US2] In `config/routes.rb`, add `patch :refuse` to the `swap_validations` resource's
  `member do ... end` block, alongside `:validate`.
- [X] T021 [US2] In `app/controllers/admin/swap_validations_controller.rb`, add:
  ```ruby
  # FR-005..FR-008: decline! now reachable from accepted?, not only pending?
  # (data-model.md). The comment is optional — decline! already treats a
  # blank one as no comment via .presence.
  def refuse
    if accepted_proposal&.decline!(refuse_params[:decline_comment], by: current_user)
      redirect_to admin_swap_validations_path, notice: t(".refused")
    else
      redirect_to admin_swap_validations_path, alert: t(".already_decided")
    end
  end

  private

    def refuse_params
      params.fetch(:locker_swap_proposal, {}).permit(:decline_comment)
    end
  ```
  placed alongside `accepted_proposal` in the `private` section already opened by T015. (Depends on
  T020.)
- [X] T022 [US2] In `app/views/admin/swap_validations/index.html.erb`, add the refuse control to the same
  actions column as T016, reusing the `<details class="tile-disclosure">` pattern from
  `home/_swap_proposals_received.html.erb`:
  ```erb
  <details class="tile-disclosure">
    <summary class="tile-disclosure-summary"><%= t(".refuse_button") %></summary>
    <%= form_with url: refuse_admin_swap_validation_path(proposal), method: :patch,
                  class: "stack-tight tile-disclosure-body" do |f| %>
      <%= f.label :"locker_swap_proposal[decline_comment]", t(".refuse_comment_label"),
            for: "refuse-comment-#{proposal.id}", class: "field-label" %>
      <%= f.text_area :"locker_swap_proposal[decline_comment]", rows: 2,
            id: "refuse-comment-#{proposal.id}", class: "field-input" %>
      <%= f.submit t(".confirm_refuse"), class: "btn btn-secondary btn-sm",
            data: { turbo_submits_with: t(".refusing") } %>
    <% end %>
  </details>
  ```
  (Depends on T016, T021.)
- [X] T023 [P] [US2] In `config/locales/en.yml`/`fr.yml`, under `admin.swap_validations`, add:
  ```yaml
  index:
    refuse_button: "Refuse"                    # / "Refuser"
    refuse_comment_label: "Reason (optional)"   # / "Motif (facultatif)"
    confirm_refuse: "Confirm refusal"           # / "Confirmer le refus"
    refusing: "Refusing…"                       # / "Refus en cours…"
  refuse:
    refused: "Exchange refused."                                # / "Échange refusé."
    already_decided: "That exchange was already decided."       # / "Cet échange a déjà été traité."
  ```

**Checkpoint**: User Stories 1 and 2 are both complete — the admin queue is fully functional: every
accepted exchange can be validated or refused.

---

## Phase 5: User Story 3 - Standard users can no longer confirm their own exchange (Priority: P1)

**Goal**: The self-confirm control is retired everywhere it appears — the route, the controller action,
the homepage button — and both parties see "En attente de validation" / "Awaiting validation" plus the
new waiting-for-admin message instead.

**Independent Test**: With a proposal accepted, sign in as the requester and separately as the recipient
and confirm neither sees any control to confirm or finalize the exchange, and both see the new label and
message (quickstart.md Scenario 3).

### Tests for User Story 3 ⚠️ Write first; confirm they fail before implementing

- [X] T024 [P] [US3] In `test/controllers/locker_swap_proposals_controller_test.rb`:
  - Delete the four now-obsolete tests that call `confirm_locker_swap_proposal_path` (around lines
    249-314): `"the recipient can confirm an exchange and both lockers move"`, `"the requester cannot
    confirm the exchange"`, `"an exchange that has been confirmed cannot be confirmed again"`, and `"an
    anonymous visitor cannot confirm an exchange"` — the path helper itself no longer exists once T027
    lands, so these cannot compile against the finished feature.
  - Add one replacement test, `"the retired confirm path no longer exists"`: build an `accepted`
    proposal, `sign_in users(:bob)`, `patch "/locker_swap_proposals/#{proposal.id}/confirm"` (the literal
    path, since the route helper is gone), `assert_response :not_found`, `assert_predicate
    proposal.reload, :accepted?` (research.md R8).
- [X] T025 [P] [US3] In `test/system/locker_swap_proposal_test.rb`:
  - Rewrite `"the recipient can confirm the exchange and both lockers change hands"` (line 255) into
    `"the recipient sees no confirmation control, only the pending-admin message"`: build the same
    accepted proposal, `log_in_as users(:bob)`, within `#swap-exchange-in-progress` assert `assert_text
    "En attente de validation"` (or the `I18n.t` equivalent), `assert_text` the new pending-admin-validation
    message, and `assert_no_button`/`assert_no_selector` for any confirm control.
  - Rewrite `"the requester sees the exchange but is offered no confirmation"` (line 271) to also assert
    the same label and message (not just the absence of the old button) — both parties now see
    identical copy (spec.md FR-013).
- [X] T026 [P] [US3] In `test/system/locker_swap_proposal_test.rb`, add `"the proposal history shows an
  accepted exchange as awaiting validation, not in progress"`: build an accepted proposal, visit the
  viewer's `locker_swap_proposals_path`, assert the row's status badge reads the new copy — there is no
  existing test of this badge's text for an `accepted?` row today, so this is new coverage, not a rewrite
  (research.md R12).

### Implementation for User Story 3

- [X] T027 [US3] In `config/routes.rb`, remove `patch :confirm` from the `locker_swap_proposals` member
  block (leaving `:accept` and `:decline`).
- [X] T028 [US3] In `app/controllers/locker_swap_proposals_controller.rb`, delete the `#confirm` action
  entirely (research.md R8 — a guarded-but-unreachable action would be dead code under Constitution I).
- [X] T029 [US3] In `app/views/home/_swap_exchange_in_progress.html.erb`, remove the `viewer_is_recipient`
  local and its `if`/`else` branch (the confirm button and the two different messages); replace with one
  unconditional paragraph:
  ```erb
  <p class="card-lead"><%= t(".pending_admin_validation") %></p>
  ```
- [X] T030 [P] [US3] In `config/locales/en.yml` and `config/locales/fr.yml`:
  - In `home.swap_exchange_in_progress` (en.yml lines 297-307 / fr.yml lines 343-353): change `title`
    from `"Exchange in progress"`/`"Échange en cours"` to `"Awaiting validation"`/`"Échange à
    valider"`; remove `confirm_instructions`, `confirm_button`, `confirming`, and
    `waiting_for_their_confirmation`; add `pending_admin_validation: "Your exchange request is awaiting
    validation. Please see the facilities team in person to complete the physical locker swap and
    finalize the request."` (en) / `"Votre demande d'échange est en attente de validation.
    Rapprochez-vous des services généraux pour l'échange physique des casiers et ainsi finaliser la
    demande."` (fr, the spec's own quoted text verbatim).
  - In `locker_swap_proposals.index` (en.yml line 375 / fr.yml line 421), change `exchange_in_progress`
    from `"Exchange in progress"`/`"Échange en cours"` to `"Awaiting validation"`/`"Échange à
    valider"` (research.md R12 — the same fact, shown on the proposal-history table).
  - Remove `locker_swap_proposals.confirm` and its `confirmed` key entirely (en.yml lines 362-363 /
    fr.yml lines 408-409) — no action is left to reach it from.
  - **Do not** touch `locker_swap_proposal.messages.requester_already_in_exchange` /
    `recipient_already_in_exchange` (en.yml lines 348-349 / fr.yml equivalents) even though their English
    text also contains "in progress" — those describe a *different* fact (a proposal-creation-time
    refusal, "this person already has an exchange in progress"), not the retired status label, and are
    out of this feature's scope.

**Checkpoint**: All three user stories are complete. The self-confirm control is fully retired; the
admin queue is the only way an accepted exchange is finalized or refused; every occurrence of the old
"in progress" label a standard user could see now reads "awaiting validation."

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verification that spans every user story above.

- [X] T031 Run `bin/rails test` and `bin/rails test:system` (full Minitest suite, including
  `test/i18n_completeness_test.rb`, which automatically fails if T010/T017/T023/T030 leave `en.yml` and
  `fr.yml` out of lockstep) and confirm zero failures.
- [X] T032 Run `bin/rails tailwindcss:build` (the new admin screen and the simplified homepage card are
  new/changed markup) and `bin/rubocop` on every changed file, confirming zero unresolved warnings
  (Constitution I).
- [X] T033 Work through `quickstart.md` Scenarios 1-6 by hand (`bin/rails server` + a browser) and confirm
  each matches what it describes, including the two clarified edge cases (Scenario 4: an already-accepted
  exchange from before this feature appears with no migration step; Scenario 5: an administrator can
  validate/refuse their own exchange) and the admin race condition (Scenario 6).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: None — no tasks.
- **Foundational (Phase 2)**: No dependencies beyond the existing codebase — BLOCKS all user stories.
- **User Stories (Phase 3-5)**: All depend on Foundational (Phase 2) completion.
  - US1 and US2 both extend the same controller/view/route files (`Admin::SwapValidationsController`,
    `admin/swap_validations/index.html.erb`, the `swap_validations` route block) — they can be built in
    either order, but not truly in parallel by two people without coordinating those shared files.
  - US3 touches an entirely different set of files (`LockerSwapProposalsController`,
    `home/_swap_exchange_in_progress.html.erb`) and has no code dependency on US1/US2 — it can be built
    in parallel with them by a different person, though see Implementation Strategy for why it should not
    ship *before* them.
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### Within Each User Story

- Tests are written first and confirmed to fail before the implementation tasks that follow them.
- Route → controller action → view → locale keys, in that order (each depends on the one before it).

### Parallel Opportunities

- T002 and T003 (different model files) can run in parallel once T001's migration is applied.
- T005 (model tests), T008 (controller tests), T010 (locale) can each proceed in parallel with each
  other once their respective prerequisite (T004, T007, —) lands.
- T012/T013 (US1 tests) and T018/T019 (US2 tests) can be written in parallel by different people, since
  they land in different describe-blocks of the same or sibling files; the *implementation* tasks
  (T014-T017 vs. T020-T023) touch the same controller/view/route files sequentially, so are not truly
  parallel unless coordinated.
- T024, T025, and T026 (all US3 tests, three different assertions but two of them in the same file) can
  be drafted in parallel and merged.

---

## Parallel Example: Foundational Phase

```bash
# After T001 (migration) is applied:
Task: "Add belongs_to :admin_decided_by in app/models/locker_swap_proposal.rb"
Task: "Add has_many :swap_decisions_made in app/models/user.rb"
```

## Parallel Example: User Story 1

```bash
# Tests, before any implementation:
Task: "Add validate/race/self-validation/non-admin tests in test/controllers/admin/swap_validations_controller_test.rb"
Task: "Add the validate system test in test/system/admin_swap_validation_test.rb"
```

---

## Implementation Strategy

### Recommended order (not a strict MVP cut — all three stories are P1)

Unlike a feature with a clear P1/P2/P3 split, shipping US1+US2 (the admin queue) without US3 (retiring
self-confirm) would leave two competing ways to complete the same accepted exchange — the very
contradiction this feature exists to remove (spec.md User Story 3's rationale). The three stories are
still independently testable, as required, but the recommended delivery order is:

1. Complete Phase 1 (none) + Phase 2: Foundational — the read-only queue exists and is reachable.
2. Add User Story 1 (validate) → test independently.
3. Add User Story 2 (refuse) → test independently → the queue is now fully functional end-to-end.
4. Add User Story 3 (retire self-confirm, relabel) → test independently → **ship all three together**,
   since shipping 2-3 without 4 leaves the contradictory transitional state above.
5. Phase 6: Polish — full-suite regression run and manual quickstart walkthrough.

### Parallel Team Strategy

With two developers: one takes US1+US2 (they share files, so sequencing between them matters more than
parallelizing them); the other takes US3 in parallel, since it touches an entirely disjoint set of files.
Both merge behind Foundational, and the combined branch ships together per the ordering note above.
