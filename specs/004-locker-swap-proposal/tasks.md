---

description: "Task list template for feature implementation"
---

# Tasks: Locker Swap Proposals

**Input**: Design documents from `/specs/004-locker-swap-proposal/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/web-routes.md, quickstart.md

**Tests**: Included — the project constitution's Testing Standards principle is NON-NEGOTIABLE
("every new feature ... MUST include automated tests that fail without the change and pass with
it"), and plan.md commits every functional requirement (FR-001..FR-020) to a Minitest model test,
controller test, or system test, so every FR below has a corresponding test task.

**Organization**: Tasks are grouped by user story (from spec.md) to enable independent
implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies). Several test tasks that share one
  test file are still marked `[P]` when each adds an independent `test "..."` block with no shared
  mutable state — see "Parallel Opportunities" below.
- **[Story]**: Which user story this task belongs to (US1–US5)
- Exact file paths are included in every task description

## Path Conventions

Single Ruby on Rails monolith at the repository root (`app/`, `config/`, `db/`, `test/`) — see
plan.md's Project Structure section. No frontend/backend split.

---

## Phase 1: Setup

**Purpose**: Create the new `locker_swap_proposals` table.

- [X] T001 Generate and apply a migration `db/migrate/<timestamp>_create_locker_swap_proposals.rb` that creates a `locker_swap_proposals` table with: `requester_id` (integer, not null, FK → `users`), `recipient_id` (integer, not null, FK → `users`), `status` (integer, not null, default `0` — enum `pending` (0), `accepted` (1, "exchange in progress"), `declined` (2), `withdrawn` (3), `completed` (4)), `decline_comment` (text, nullable — "Set only when `status` is `declined`"), `decided_at` (datetime, nullable — "Set when the proposal leaves `pending`"), `completed_at` (datetime, nullable — "Set only when `status` becomes `completed`"), `requester_acknowledged_at` (datetime, nullable — "Set once the requester's homepage has displayed this proposal's `declined` outcome"), plus standard timestamps. Add three partial unique indexes exactly as data-model.md specifies: `[requester_id, recipient_id] WHERE status = 0` (at most one pending proposal per pair, FR-018), `requester_id WHERE status = 1` (at most one accepted exchange as requester), `recipient_id WHERE status = 1` (at most one accepted exchange as recipient). Run `bin/rails db:migrate` so `db/schema.rb` reflects the new table.

**Checkpoint**: `locker_swap_proposals` table exists with all columns and the three partial unique indexes described in data-model.md.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Model, associations, shared query methods, routes, and controller shell used by every user story below. No user story can be implemented until this phase is done.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 [P] Create `app/models/locker_swap_proposal.rb` with `belongs_to :requester, class_name: "User"`, `belongs_to :recipient, class_name: "User"`, and `enum status: { pending: 0, accepted: 1, declined: 2, withdrawn: 3, completed: 4 }` (data-model.md — Entity table; status enum values). No validations or lifecycle methods yet — each user story below adds its own. Depends on: T001.
- [X] T003 [P] In `app/models/user.rb`, add `has_many :sent_swap_proposals, class_name: "LockerSwapProposal", foreign_key: :requester_id, dependent: :destroy` and `has_many :received_swap_proposals, class_name: "LockerSwapProposal", foreign_key: :recipient_id, dependent: :destroy` (data-model.md — Associations). Depends on: T001.
- [X] T004 In `app/models/locker_swap_proposal.rb`, add two class methods used across multiple stories: `LockerSwapProposal.in_progress_for?(user)` — `accepted.where("requester_id = :id OR recipient_id = :id", id: user.id).exists?` (research.md — "Enforcing 'at most one exchange in progress per user, in either role'"; used by US1's create validation and US2's accept-side re-check) — and `LockerSwapProposal.in_progress_user_ids` — `accepted.pluck(:requester_id, :recipient_id).flatten.uniq` (research.md — "Suspending a wish while an exchange is in progress"; used by US1's Locker Wishes list exclusion). Depends on: T002.
- [X] T005 [P] In `config/routes.rb`, add `resources :locker_swap_proposals, only: [:create, :destroy, :index] do member { patch :accept; patch :decline; patch :confirm } end` (contracts/web-routes.md — the six routes: `POST`, `DELETE /:id`, `GET`, `PATCH /:id/accept`, `PATCH /:id/decline`, `PATCH /:id/confirm`).
- [X] T006 [P] Create `app/controllers/locker_swap_proposals_controller.rb` with only `before_action :authenticate_user!` for now (no actions yet — each user story below adds its own), so FR-016 ("sending, withdrawing, accepting, declining, confirming, and viewing history MUST all be restricted to logged-in, registered users") is true from this controller's very first commit — mirrors 003's `LockerWishesController` shell pattern.
- [X] T007 [P] In `test/fixtures/locker_swap_proposals.yml` (new file), add three fixtures reused across the user-story tests below, chosen so none of them puts `bob` or `carol` into `accepted` status (which would exclude `bob_wish`/`carol_wish` from the Locker Wishes list per T031 and could regress 003's existing wish-list tests): `alice_pending_to_bob` (`requester: alice`, `recipient: bob`, `status: 0` — pending, since `bob` has an active wish via `bob_wish`); `dave_declined_to_carol` (`requester: dave`, `recipient: carol`, `status: 2`, `decline_comment: "Found another swap"`, `decided_at: <%= 1.day.ago %>`, `requester_acknowledged_at: nil` — an unacknowledged decline, for the "recently declined" homepage/history cases); `alice_withdrawn_to_carol` (`requester: alice`, `recipient: carol`, `status: 3`, `decided_at: <%= 2.days.ago %>` — a withdrawn proposal, for the "non-actionable, shown in history" cases). Depends on: T001.

**Checkpoint**: Table, model, associations, shared lookup methods, routes, controller shell, and shared fixtures are ready — user story implementation can now begin.

---

## Phase 3: User Story 1 - Propose a locker swap to someone looking for one (Priority: P1) 🎯 MVP

**Goal**: A logged-in user can send a swap proposal, from the Locker Wishes screen, to another user with an active wish — rejecting self-targets, ineligible recipients, and duplicate/competing proposals — and can withdraw their own pending proposal before it is decided.

**Independent Test**: Log in as a registered user, open `/locker_wishes`, send a proposal to another user with an active wish, and confirm it is recorded as pending and linked to both users; confirm self-targeting, targeting an ineligible recipient, and duplicating an existing pending proposal are all rejected; confirm the sender can withdraw it before the recipient responds.

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T008 [P] [US1] Model test in `test/models/locker_swap_proposal_test.rb`: a `LockerSwapProposal` with `requester: alice`, `recipient: bob` (active wish via `bob_wish`) is valid and saves (Acceptance Scenario 1, FR-001).
- [X] T009 [P] [US1] Model test in `test/models/locker_swap_proposal_test.rb`: a proposal with `recipient_id == requester_id` fails validation (Acceptance Scenario 2, FR-002).
- [X] T010 [P] [US1] Model test in `test/models/locker_swap_proposal_test.rb`: a proposal targeting a recipient with no active `LockerWish` (e.g. `alice`, who has none) fails validation (FR-017, Edge Case — wish cancelled before submission).
- [X] T011 [P] [US1] Model test in `test/models/locker_swap_proposal_test.rb`: a proposal is invalid when either the requester or the target recipient is already `LockerSwapProposal.in_progress_for?` (build an `accepted` proposal for one of them first, then attempt a new one) (Acceptance Scenario 3 & 4, FR-003, FR-004).
- [X] T012 [P] [US1] Model test in `test/models/locker_swap_proposal_test.rb`: inserting two `pending` rows for the same `requester_id`/`recipient_id` pair while bypassing application validation (e.g. `insert_all`) raises `ActiveRecord::RecordNotUnique` — proving the partial unique index from T001, not just the application lookup, is the real guarantee behind FR-018 (data-model.md — Persistence-layer backstop).
- [X] T013 [P] [US1] Model test in `test/models/locker_swap_proposal_test.rb`: `withdraw!` transitions a `pending` proposal (fixture `alice_pending_to_bob`) to `withdrawn` and sets `decided_at`; calling it on the `withdrawn` fixture `alice_withdrawn_to_carol` (already final) is rejected (FR-019, FR-020, FR-010-style "final state" rule).
- [X] T014 [P] [US1] Controller test in `test/controllers/locker_swap_proposals_controller_test.rb` (new file, `ActionDispatch::IntegrationTest`): signed in as `alice`, `POST /locker_swap_proposals` with `recipient_id: carol.id` (via `carol_wish`) creates a `pending` proposal and redirects to `/locker_wishes` (FR-001).
- [X] T015 [P] [US1] Controller test in `test/controllers/locker_swap_proposals_controller_test.rb`: signed in as `alice`, `POST /locker_swap_proposals` with `recipient_id: alice.id` is rejected, no proposal is created, and an error naming the self-target rule is shown (Acceptance Scenario 2, FR-002).
- [X] T016 [P] [US1] Controller test in `test/controllers/locker_swap_proposals_controller_test.rb`: `POST /locker_swap_proposals` targeting `dave` (no active wish) is rejected with an error naming the ineligibility (FR-017).
- [X] T017 [P] [US1] Controller test in `test/controllers/locker_swap_proposals_controller_test.rb`: `POST /locker_swap_proposals` targeting a recipient already `in_progress_for?` is rejected (Acceptance Scenario 3, FR-003); a request from a requester already `in_progress_for?` targeting anyone else is rejected (Acceptance Scenario 4, FR-004).
- [X] T018 [P] [US1] Controller test in `test/controllers/locker_swap_proposals_controller_test.rb`: with `alice_pending_to_bob` present, `alice` submitting a second `POST` targeting `bob` is rejected as a duplicate (FR-018); force the `create` action's save to raise `ActiveRecord::RecordNotUnique` (temporarily redefine `LockerSwapProposal#save`, restoring it afterward — no mocking gem present, mirroring 003's controller-test pattern) and assert the same friendly rejection rather than a 500.
- [X] T019 [P] [US1] Controller test in `test/controllers/locker_swap_proposals_controller_test.rb`: signed in as `alice`, `DELETE /locker_swap_proposals/:id` on `alice_pending_to_bob` marks it `withdrawn` and redirects to `/` (FR-019); the same request signed in as `bob` (not the requester), or targeting `alice_withdrawn_to_carol` (already final), 404s (FR-020, scoping).
- [X] T020 [P] [US1] System test in `test/system/locker_swap_proposal_test.rb` (new file): logging in as `alice` and visiting `/locker_wishes`, `bob`'s active-wish row shows a "Propose swap" control; clicking it redirects back with a pending proposal now recorded from `alice` to `bob` (Acceptance Scenario 1).
- [X] T021 [P] [US1] System test in `test/system/locker_swap_proposal_test.rb`: as `alice`, `alice`'s own row on `/locker_wishes` (if she has declared a wish) offers no "Propose swap" control to herself (Acceptance Scenario 2, FR-002).
- [X] T022 [P] [US1] System test in `test/system/locker_swap_proposal_test.rb`: with `bob` already party to an `accepted` proposal (set up directly in the test), `/locker_wishes` shows an explanatory ineligibility note instead of a "Propose swap" control on any row for `bob` (Acceptance Scenario 3).
- [X] T023 [P] [US1] System test in `test/system/locker_swap_proposal_test.rb`: with the viewer themselves party to an `accepted` proposal, every "Propose swap" control on `/locker_wishes` is replaced with an explanatory note instead of being silently omitted (Acceptance Scenario 4, FR-004).
- [X] T024 [P] [US1] System test in `test/system/locker_swap_proposal_test.rb`: `alice` (no floor/locker, no wish of her own) successfully proposes to `carol` — the requester needs neither a locker nor a declared wish of their own (Acceptance Scenario 5).
- [X] T025 [P] [US1] System test in `test/system/locker_swap_proposal_test.rb`: `alice` sends a proposal to `dave` (after `dave` declares a wish via the existing 003 flow), then, before `dave` responds, withdraws it from the homepage; `dave`'s homepage no longer shows it as actionable afterward (Acceptance Scenario 6, FR-019, FR-020).
- [X] T026 [P] [US1] Controller test in `test/controllers/locker_swap_proposals_controller_test.rb`: with `dave_declined_to_carol` present (a resolved, `declined` proposal from `dave` to `carol`), signed in as `dave`, a new `POST /locker_swap_proposals` targeting `carol` succeeds and creates a fresh `pending` proposal — a prior decline between the same pair creates no lasting restriction, as long as the recipient still has an active wish, still has no exchange in progress, and the requester is not proposing to themselves (spec.md Edge Cases: "a requester sends a new proposal to a recipient who previously declined ... MUST be allowed"; FR-018 only blocks a second *pending* row between the pair, not one after the earlier row is resolved).

### Implementation for User Story 1

- [X] T027 [US1] In `app/models/locker_swap_proposal.rb`, add validations: `requester`/`recipient` required; `recipient_id != requester_id` — "The system MUST reject any attempt by a user to send a swap proposal targeting themselves" (FR-002); a custom validation that `recipient.locker_wish.present?` — FR-017; a custom validation that neither `requester` nor `recipient` is `LockerSwapProposal.in_progress_for?` — FR-003, FR-004; a custom validation that no existing `pending` proposal already exists for this exact `requester_id`/`recipient_id` pair — FR-018 (application-level half of the guarantee; T001's index is the concurrency backstop). Depends on: T004.
- [X] T028 [US1] In `app/models/locker_swap_proposal.rb`, add `withdraw!`: only valid while `pending` (raise/return false otherwise, matching the "final states reject any action" rule — FR-020), sets `status: :withdrawn, decided_at: Time.current`. Depends on: T027.
- [X] T029 [US1] In `app/controllers/locker_swap_proposals_controller.rb`, add the `create` action: build via `current_user.sent_swap_proposals.build(recipient_id: params.expect(locker_swap_proposal: [:recipient_id])[:recipient_id])`; on success redirect to `locker_wishes_path` with a confirmation flash; on validation failure redirect back to `locker_wishes_path` with the specific error message per contracts/web-routes.md's Error message contract (self-target, no active wish, in-progress, duplicate-pending); `rescue ActiveRecord::RecordNotUnique` and redirect with the duplicate-pending message (FR-001, FR-002, FR-003, FR-004, FR-017, FR-018; verified by T014–T018). Depends on: T027, T006.
- [X] T030 [US1] In `app/controllers/locker_swap_proposals_controller.rb`, add the `destroy` action: `current_user.sent_swap_proposals.pending.find(params[:id]).withdraw!`, then redirect to `root_path` with a confirmation flash (FR-019); the scoped `find` naturally 404s for someone else's proposal or one no longer `pending` (FR-020; verified by T019). Depends on: T028.
- [X] T031 [US1] In `app/controllers/locker_wishes_controller.rb`, change `all_locker_wishes` to `LockerWish.where.not(user_id: LockerSwapProposal.in_progress_user_ids).includes(:user).order(created_at: :asc)` — "no longer treated as an open invitation while the exchange is in progress" (Edge Cases; research.md — Suspending a wish while an exchange is in progress). Depends on: T004.
- [X] T032 [US1] In `app/controllers/locker_wishes_controller.rb`, extend `index` to also set `@viewer_in_progress = LockerSwapProposal.in_progress_for?(current_user)` and `@pending_recipient_ids = current_user.sent_swap_proposals.pending.pluck(:recipient_id)`, for the view's per-row eligibility logic added in T033. Depends on: T004.
- [X] T033 [US1] In `app/views/locker_wishes/_locker_wish_list.html.erb`, add, per row whose `wish.user` is not `current_user`: if `@viewer_in_progress`, an explanatory note that the viewer cannot start a new swap while one is underway (FR-004); else if `wish.user_id` is in `@pending_recipient_ids`, a note that a proposal to this person is already pending (FR-018); else a `button_to locker_swap_proposals_path(locker_swap_proposal: { recipient_id: wish.user_id })` labelled "Propose swap" (FR-001; research.md — Where the new UI lives). Depends on: T029, T032.
- [X] T034 [US1] In `app/controllers/home_controller.rb`, extend `index` to set `@sent_pending_proposals = current_user.sent_swap_proposals.pending.includes(:recipient)` (contracts/web-routes.md — Display contract, "Pending proposals sent"). Depends on: T003.
- [X] T035 [US1] In `app/views/home/index.html.erb`, add a "Pending proposals sent" section, shown when `@sent_pending_proposals.any?`, listing each proposal's recipient identifier with a `button_to locker_swap_proposal_path(proposal), method: :delete` labelled "Withdraw" (FR-019; contracts/web-routes.md — Display contract). Depends on: T030, T034.

**Checkpoint**: User Story 1 is fully functional and independently testable — a user can propose a swap from the Locker Wishes screen and withdraw it before a decision is made.

---

## Phase 4: User Story 2 - Respond to a received swap proposal (Priority: P1)

**Goal**: The recipient of a pending proposal can accept it (marking an exchange in progress for both users and auto-declining any other pending proposals either party is involved in) or decline it (optionally with a free-form comment), closing the loop opened by User Story 1.

**Independent Test**: Send a proposal from one user to another, then, logged in as the recipient, accept or decline it, and confirm the resulting status and (for a decline) any comment.

### Tests for User Story 2

- [X] T036 [P] [US2] Model test in `test/models/locker_swap_proposal_test.rb`: `accept!` on `alice_pending_to_bob` sets `status: :accepted` and `decided_at` (Acceptance Scenario 1, FR-006).
- [X] T037 [P] [US2] Model test in `test/models/locker_swap_proposal_test.rb`: `accept!` re-checks `in_progress_for?` for both parties inside its transaction and is rejected if either became in-progress via another proposal in the meantime (research.md — accept-side race backstop, FR-003/FR-004).
- [X] T038 [P] [US2] Model test in `test/models/locker_swap_proposal_test.rb`: `accept!` auto-declines every other `pending` proposal where `requester_id` or `recipient_id` matches either party of the proposal being accepted, setting `status: :declined, decided_at: Time.current, decline_comment: <system message>, requester_acknowledged_at: nil` on each (FR-011, Edge Cases).
- [X] T039 [P] [US2] Model test in `test/models/locker_swap_proposal_test.rb`: `decline!(comment)` on `alice_pending_to_bob` sets `status: :declined`, `decided_at`, and stores `comment` verbatim in `decline_comment` when given, or leaves `decline_comment` blank when omitted (Acceptance Scenario 2, 3 & 4, FR-007, FR-008).
- [X] T040 [P] [US2] Model test in `test/models/locker_swap_proposal_test.rb`: calling `accept!` or `decline!` on the `declined` fixture `dave_declined_to_carol` (already decided) is rejected — a decision can only be made once (Acceptance Scenario 5, FR-010).
- [X] T041 [P] [US2] Controller test in `test/controllers/locker_swap_proposals_controller_test.rb`: signed in as `bob`, `PATCH /locker_swap_proposals/:id/accept` on `alice_pending_to_bob` marks it `accepted` and redirects to `/` (FR-005, FR-006).
- [X] T042 [P] [US2] Controller test in `test/controllers/locker_swap_proposals_controller_test.rb`: `PATCH .../accept` on `alice_pending_to_bob` signed in as `alice` (the requester, not the recipient) or as an unrelated user 404s (scoping).
- [X] T043 [P] [US2] Controller test in `test/controllers/locker_swap_proposals_controller_test.rb`: signed in as `bob`, `PATCH .../decline` on `alice_pending_to_bob` with `locker_swap_proposal[decline_comment]` present stores it; the same request with the param omitted declines with no comment stored (FR-007, FR-008).
- [X] T044 [P] [US2] Controller test in `test/controllers/locker_swap_proposals_controller_test.rb`: `PATCH .../accept` or `PATCH .../decline` on the `declined` fixture `dave_declined_to_carol` 404s (FR-010).
- [X] T045 [P] [US2] Controller test in `test/controllers/locker_swap_proposals_controller_test.rb`: with two separate pending proposals both involving `bob` (e.g. `alice_pending_to_bob` plus a second one created in the test), `PATCH .../accept` on one leaves the other `declined` afterward (FR-011).
- [X] T046 [P] [US2] System test in `test/system/locker_swap_proposal_test.rb`: `alice` sends a proposal to `bob`; logging in as `bob` and visiting `/`, the pending proposal appears with Accept and Decline controls; clicking Accept marks the exchange in progress for both (Acceptance Scenario 1; quickstart scenario 2).
- [X] T047 [P] [US2] System test in `test/system/locker_swap_proposal_test.rb`: as `bob`, declining the same proposal via the Decline `<details>` disclosure with a comment entered results in `alice` seeing the decline and the comment on her next homepage visit (Acceptance Scenario 2 & 3).
- [X] T048 [P] [US2] System test in `test/system/locker_swap_proposal_test.rb`: declining without entering a comment still notifies `alice`, with no comment shown (Acceptance Scenario 4).
- [X] T049 [P] [US2] System test in `test/system/locker_swap_proposal_test.rb`: attempting to accept or decline the same proposal a second time (after it is already decided) is rejected (Acceptance Scenario 5).

### Implementation for User Story 2

- [X] T050 [US2] In `app/models/locker_swap_proposal.rb`, add `accept!`: only valid while `pending` (raise/return false otherwise, matching the "final states reject any action" rule — FR-010, mirroring `decline!`'s and `confirm!`'s own state guard); within a transaction, re-check `LockerSwapProposal.in_progress_for?(requester)` and `in_progress_for?(recipient)` are both false and raise/return false otherwise (closing the accept-side race — research.md); set `status: :accepted, decided_at: Time.current` on self; then find every other `pending` proposal where `requester_id` or `recipient_id` equals this proposal's `requester_id` or `recipient_id`, and update each to `status: :declined, decided_at: Time.current, decline_comment: <system message noting the automatic decline>, requester_acknowledged_at: nil` (FR-006, FR-011). Depends on: T027.
- [X] T051 [US2] In `app/models/locker_swap_proposal.rb`, add `decline!(comment = nil)`: only valid while `pending`; sets `status: :declined, decided_at: Time.current, decline_comment: comment` (FR-007, FR-008, FR-010). Depends on: T027.
- [X] T052 [US2] In `app/controllers/locker_swap_proposals_controller.rb`, add the `accept` action: `current_user.received_swap_proposals.pending.find(params[:id]).accept!`, redirect to `root_path` with a confirmation flash; a re-check failure inside `accept!` redirects back with an error (FR-005, FR-006; the scoped `find` 404s per FR-005's role/state requirement — verified by T042, T044). Depends on: T050.
- [X] T053 [US2] In `app/controllers/locker_swap_proposals_controller.rb`, add the `decline` action: `current_user.received_swap_proposals.pending.find(params[:id]).decline!(params.dig(:locker_swap_proposal, :decline_comment))`, redirect to `root_path` with a confirmation flash (FR-005, FR-007, FR-008; verified by T043, T044). Depends on: T051.
- [X] T054 [US2] In `app/controllers/home_controller.rb`, extend `index` to set `@received_pending_proposals = current_user.received_swap_proposals.pending.includes(:requester)` (contracts/web-routes.md — Display contract, "Pending proposals received"). Depends on: T003.
- [X] T055 [US2] In `app/views/home/index.html.erb`, add a "Pending proposals received" section, shown when `@received_pending_proposals.any?`, listing each proposal's requester identifier with an Accept `button_to locker_swap_proposal_accept_path(proposal), method: :patch` and a Decline `<details>` disclosure (mirroring 002/003's no-JavaScript pattern) containing an optional `decline_comment` text field and its own submit (FR-005–FR-008; contracts/web-routes.md — Display contract). Depends on: T052, T053, T054.

**Checkpoint**: User Stories 1 and 2 work together end-to-end — a proposal can be sent, then accepted or declined, with the outcome correctly gated against re-decision.

---

## Phase 5: User Story 3 - See my proposals on the homepage (Priority: P1)

**Goal**: The homepage shows a logged-in user every pending proposal they received, every pending proposal they sent, and the outcome of any of their sent proposals recently declined, so activity is never missed; a user with none of this sees no proposal-related section.

**Independent Test**: Send a proposal from one user to another and confirm the sender sees it on their own homepage and the recipient sees it on theirs, without visiting any other screen.

### Tests for User Story 3

- [X] T056 [P] [US3] System test in `test/system/locker_swap_proposal_test.rb`: after `bob` declines `alice`'s proposal with a comment, `alice`'s next homepage visit shows the decline and comment under a "recently declined" notice (Acceptance Scenario 3, FR-007, FR-009).
- [X] T057 [P] [US3] System test in `test/system/locker_swap_proposal_test.rb`: reloading `alice`'s homepage a second time after T056 no longer shows the same declined notice — it was acknowledged on first display (contracts/web-routes.md — Display contract: "marked acknowledged immediately after this render, so it does not reappear").
- [X] T058 [P] [US3] System test in `test/system/locker_swap_proposal_test.rb`: a user with no pending or recently-decided proposals in either direction (e.g. a freshly created account) sees no proposal-related section on `/` (Acceptance Scenario 4).
- [X] T059 [P] [US3] System test in `test/system/locker_swap_proposal_test.rb`: with one pending received proposal and one pending sent proposal simultaneously, both the "Pending proposals received" and "Pending proposals sent" sections render together on the same homepage load (Acceptance Scenario 1 & 2).

### Implementation for User Story 3

- [X] T060 [US3] In `app/controllers/home_controller.rb`, extend `index` to set `@recently_declined_sent = current_user.sent_swap_proposals.declined.where(requester_acknowledged_at: nil).includes(:recipient)`, then, after building the list for this render, update those same rows' `requester_acknowledged_at` to `Time.current` (contracts/web-routes.md — Display contract, "Recently declined (sent)"; FR-007, FR-009). Depends on: T051, T034, T054.
- [X] T061 [US3] In `app/views/home/index.html.erb`, add a "Recently declined" section, shown when `@recently_declined_sent.any?`, listing each proposal's recipient identifier and `decline_comment` if present (FR-007, FR-009). Depends on: T060.
- [X] T062 [US3] Review `app/views/home/index.html.erb` and confirm each of the three proposal sections ("Pending proposals received", "Pending proposals sent", "Recently declined") is wrapped in its own `.any?` guard so that a user with none of the three sees no proposal-related content at all (Acceptance Scenario 4). Depends on: T055, T035, T061.

**Checkpoint**: All three P1 user stories work together — proposing, responding, and homepage visibility form one complete loop.

---

## Phase 6: User Story 4 - Confirm the exchange actually happened (Priority: P2)

**Goal**: The recipient who accepted a proposal can later confirm the physical exchange took place, at which point the floor and locker number on file for both users are swapped and both their wishes (if any) are cleared.

**Independent Test**: Accept a proposal, confirm the exchange as the recipient, and verify each user's on-file floor and locker number now matches what the other user had before the confirmation.

### Tests for User Story 4

- [X] T063 [P] [US4] Model test in `test/models/locker_swap_proposal_test.rb`: `confirm!` on an `accepted` proposal between two users with distinct floor/locker values swaps `floor`/`locker_number` between `requester` and `recipient`, and sets `status: :completed, completed_at` (Acceptance Scenario 1 & 2, FR-013).
- [X] T064 [P] [US4] Model test in `test/models/locker_swap_proposal_test.rb`: `confirm!` destroys each party's `LockerWish` if present (research.md — "Effect on Locker Wish"; Edge Cases — wishes involved in a completed exchange are resolved).
- [X] T065 [P] [US4] Model test in `test/models/locker_swap_proposal_test.rb`: `confirm!` still succeeds when one party (e.g. `alice`) has `floor`/`locker_number` both `nil` — that party ends up with the other's values, and the other ends up with `nil` (research.md — "`floor`/`locker_number` already tolerate `nil`").
- [X] T066 [P] [US4] Model test in `test/models/locker_swap_proposal_test.rb`: `confirm!` is only valid while `status` is `accepted`; calling it on `pending`, `declined`, `withdrawn`, or an already-`completed` proposal is rejected (Acceptance Scenario 4, FR-014).
- [X] T067 [P] [US4] Controller test in `test/controllers/locker_swap_proposals_controller_test.rb`: signed in as the recipient of an `accepted` proposal (built in the test), `PATCH /locker_swap_proposals/:id/confirm` swaps floor/locker and redirects to `/` (Acceptance Scenario 1, FR-012, FR-013).
- [X] T068 [P] [US4] Controller test in `test/controllers/locker_swap_proposals_controller_test.rb`: `PATCH .../confirm` on the same proposal signed in as the requester (not the recipient) 404s (Acceptance Scenario 3, FR-012).
- [X] T069 [P] [US4] Controller test in `test/controllers/locker_swap_proposals_controller_test.rb`: `PATCH .../confirm` on an already-`completed` proposal 404s (Acceptance Scenario 4, FR-014).
- [X] T070 [P] [US4] System test in `test/system/locker_swap_proposal_test.rb`: full flow — `alice` proposes to `bob`, `bob` accepts, `bob` confirms; afterward each user's homepage/profile reflects the other's pre-exchange floor and locker number (Acceptance Scenario 1 & 2; quickstart scenario 4).
- [X] T071 [P] [US4] System test in `test/system/locker_swap_proposal_test.rb`: while an exchange is `accepted`, the "Confirm exchange completed" control appears on the homepage only for the recipient, not for the requester (contracts/web-routes.md — Display contract).

### Implementation for User Story 4

- [X] T072 [US4] In `app/models/locker_swap_proposal.rb`, add `confirm!`: only valid while `accepted` (FR-014); within a transaction, read both users' current `floor`/`locker_number`, `update!` each user with the other's pre-read values (a plain `update!`, not `update_columns` — the `on: :locker_profile_update`-scoped validations do not fire, per research.md), set `status: :completed, completed_at: Time.current` on self, then `destroy` each party's `locker_wish` if present (FR-013; research.md — "Confirming completion"). Depends on: T027.
- [X] T073 [US4] In `app/controllers/locker_swap_proposals_controller.rb`, add the `confirm` action: `current_user.received_swap_proposals.accepted.find(params[:id]).confirm!`, redirect to `root_path` with a confirmation flash; the scoped `find` (only the recipient's own `accepted` proposals) 404s for the requester or for a non-`accepted` proposal (FR-012; verified by T068, T069). Depends on: T072.
- [X] T074 [US4] In `app/controllers/home_controller.rb`, extend `index` to set `@exchange_in_progress = LockerSwapProposal.accepted.where("requester_id = :id OR recipient_id = :id", id: current_user.id).includes(:requester, :recipient).first` (contracts/web-routes.md — Display contract, "Exchange in progress"). Depends on: T050.
- [X] T075 [US4] In `app/views/home/index.html.erb`, add an "Exchange in progress" section, shown when `@exchange_in_progress.present?`, showing the other party's identifier and status, with a "Confirm exchange completed" `button_to locker_swap_proposal_confirm_path(@exchange_in_progress), method: :patch` shown only when `@exchange_in_progress.recipient_id == current_user.id` (FR-012, FR-013; contracts/web-routes.md — Display contract). Depends on: T073, T074.
- [X] T076 [US4] Per Constitution Principle IV, since `confirm!` is the constitution-designated swap/lock execution path: capture and record a before/after performance measurement (e.g. query count or timing for the transaction) in the pull request description, even though the operation is a small, bounded transaction (research.md — "Performance note"). Depends on: T072.

**Checkpoint**: All P1/P2 user stories are functional — the full propose → respond → confirm lifecycle updates real locker records.

---

## Phase 7: User Story 5 - View my proposal history (Priority: P3)

**Goal**: A logged-in user can open a separate, read-only screen listing every proposal they sent or received, with dates, statuses, and decline comments.

**Independent Test**: Generate a mix of sent and received proposals in different states (pending, accepted, declined, completed) and confirm the history screen lists all of them for the user involved, with correct dates, statuses, and decline comments.

### Tests for User Story 5

- [X] T077 [P] [US5] System test in `test/system/locker_swap_proposal_test.rb`: as `alice` (party to `alice_pending_to_bob` and `alice_withdrawn_to_carol`), visiting `/locker_swap_proposals` lists both, each labelled "Sent", with its date and status (Acceptance Scenario 1).
- [X] T078 [P] [US5] System test in `test/system/locker_swap_proposal_test.rb`: as `carol` (recipient in both `dave_declined_to_carol` and `alice_withdrawn_to_carol`), the declined row shows the decline and its `decline_comment` (Acceptance Scenario 2).
- [X] T079 [P] [US5] System test in `test/system/locker_swap_proposal_test.rb`: after completing the T070 accept→confirm flow, the resulting proposal shows a "completed" status in both `alice`'s and `bob`'s history (Acceptance Scenario 3).
- [X] T080 [P] [US5] System test in `test/system/locker_swap_proposal_test.rb`: a user who has never sent or received a proposal sees `/locker_swap_proposals` render empty, not as an error (Acceptance Scenario 4).
- [X] T081 [P] [US5] System test in `test/system/locker_swap_proposal_test.rb`: `/locker_swap_proposals` shows no Accept/Decline/Withdraw/Confirm controls on any row — it is read-only (contracts/web-routes.md — Display contract: "the homepage is the action surface; this page is the audit/review surface").
- [X] T082 [P] [US5] Controller test in `test/controllers/locker_swap_proposals_controller_test.rb`: `GET /locker_swap_proposals` as an unauthenticated visitor redirects to `/users/sign_in` (FR-016).

### Implementation for User Story 5

- [X] T083 [US5] In `app/controllers/locker_swap_proposals_controller.rb`, add the `index` action: `@proposals = LockerSwapProposal.where("requester_id = :id OR recipient_id = :id", id: current_user.id).includes(:requester, :recipient).order(created_at: :desc)` (FR-015). Depends on: T006.
- [X] T084 [US5] Create `app/views/locker_swap_proposals/index.html.erb`: a read-only table over `@proposals` with columns Direction ("Sent" when `proposal.requester_id == current_user.id`, else "Received"), Counterparty (the other party's email), Date (`proposal.created_at`), Status, and Decline comment (shown when `status == "declined"` and `decline_comment` present); an empty-state message when `@proposals.none?` (FR-015; contracts/web-routes.md — Display contract). Depends on: T083.
- [X] T085 [US5] In `app/views/layouts/application.html.erb`, add a "Proposal history" nav link to `locker_swap_proposals_path`, shown only when `user_signed_in?` (mirrors 003's own nav-link addition for `/locker_wishes`). Depends on: T083.

**Checkpoint**: All five user stories are independently functional — the complete propose/respond/notify/confirm/history feature works end-to-end.

---

## Phase 8: Access Control Coverage (FR-016)

**Why**: FR-016 requires every proposal action and the history page to be unreachable by an unauthenticated visitor. No prior task verifies this across all six routes together — it needs all of them to exist, so it runs after Phase 7.

- [X] T086 [P] System test extending `test/system/access_control_test.rb` (matching its existing style): an unauthenticated visitor who attempts `POST /locker_swap_proposals`, `DELETE /locker_swap_proposals/:id`, `PATCH /locker_swap_proposals/:id/accept`, `PATCH /locker_swap_proposals/:id/decline`, `PATCH /locker_swap_proposals/:id/confirm`, or `GET /locker_swap_proposals` is redirected to the login page for each (FR-016). Depends on: T029, T030, T052, T053, T073, T083 (all six routes must exist).

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Quality gates from the project constitution that span all five stories above.

- [X] T087 [P] Run `bin/rubocop` and fix any offenses in the files touched by this feature (`app/models/locker_swap_proposal.rb`, `app/models/user.rb`, `app/controllers/locker_swap_proposals_controller.rb`, `app/controllers/locker_wishes_controller.rb`, `app/controllers/home_controller.rb`, `app/views/locker_swap_proposals/*`, `app/views/locker_wishes/_locker_wish_list.html.erb`, `app/views/home/index.html.erb`, `app/views/layouts/application.html.erb`, `config/routes.rb`, the new migration) — zero-warning gate per Constitution Principle I.
- [X] T088 [P] Review the Decline `<details>` disclosure, the Accept/Withdraw/Confirm buttons, the "Propose swap" controls, and the history table for accessible labels and keyboard operability, per Constitution Principle III.
- [X] T089 Walk through all 7 scenarios in `quickstart.md` manually against a running `bin/rails server` instance and confirm each matches its expected outcome; while running scenario 1 (Propose a swap), time the flow from opening `/locker_wishes` to the proposal being recorded and confirm it completes in under 30 seconds (SC-001).
- [X] T090 Run `bin/rails test` and `bin/rails test:system` and confirm the full suite passes, including all pre-existing 001/002/003 tests (no regressions) alongside all new tests from T008–T026, T036–T049, T056–T059, T063–T071, T077–T082, T086.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 (T002 and T003 need the migrated table). Blocks all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational. No dependency on other stories.
- **User Story 2 (Phase 4)**: Depends on Foundational and on User Story 1's model validations (T027) and home-page scaffolding (T034/T035), since `accept!`/`decline!` build on the same model file and the same homepage view.
- **User Story 3 (Phase 5)**: Depends on Foundational, User Story 1 (T034/T035), and User Story 2 (T051/T054) — it extends the same `HomeController#index` and `home/index.html.erb`.
- **User Story 4 (Phase 6)**: Depends on Foundational and User Story 2 (T050, since `confirm!` only applies to an `accepted` proposal produced by `accept!`).
- **User Story 5 (Phase 7)**: Depends on Foundational only — the history page reads the same associations every earlier story writes to, but adds no new model behavior, so it can in principle be built any time after Phase 2 (placed last here to match its P3 priority).
- **Access Control Coverage (T086)**: Depends on User Stories 1, 2, 4, and 5 (all six routes must exist).
- **Polish (Phase 9)**: Depends on all five user stories and T086 being complete.

### Within Each User Story

- Tests are written before the implementation tasks they cover, and MUST fail until the corresponding implementation task lands.
- Model validations/methods before controller actions; controller actions before views that submit to them.
- `HomeController#index` and `home/index.html.erb` are extended incrementally by US1, US2, US3, and US4 in that order — each adds one section without disturbing the others (guarded independently per T062).

### Parallel Opportunities

- T002, T003, T005, T006, T007 (Phase 2) can start in parallel — five different files (T004 depends on T002 completing first).
- All test tasks within a given story's Tests subsection are marked `[P]` and can be drafted in parallel — most share one test file but describe independent `test "..."` blocks with no shared mutable state.
- T087 and T088 (Polish) can run in parallel.

---

## Parallel Example: User Story 1

```bash
# Once Foundational (Phase 2) is done, these tests can be drafted together (all touch
# test/models/locker_swap_proposal_test.rb or test/controllers/locker_swap_proposals_controller_test.rb
# as independent test blocks):
Task: "Model test: a valid proposal from alice to bob saves"
Task: "Model test: recipient_id == requester_id fails validation"
Task: "Model test: recipient with no active wish fails validation"
Task: "Model test: requester or recipient already in progress fails validation"
Task: "Model test: duplicate pending pair hits the DB unique index"
Task: "Model test: withdraw! transitions pending to withdrawn"

# And the controller/system tests together (independent files/blocks):
Task: "Controller test: POST creates a pending proposal"
Task: "Controller test: self-target POST is rejected"
Task: "System test: Propose swap control appears and works on /locker_wishes"
Task: "System test: withdrawing a pending sent proposal"
```

---

## Implementation Strategy

### MVP First (User Stories 1–3 Only)

1. Complete Phase 1: Setup (migration).
2. Complete Phase 2: Foundational (model, associations, shared lookups, routes, controller shell, fixtures).
3. Complete Phase 3: User Story 1 — propose and withdraw.
4. Complete Phase 4: User Story 2 — accept and decline.
5. Complete Phase 5: User Story 3 — homepage visibility.
6. **STOP and VALIDATE**: All three P1 stories together form the complete propose/respond/notice loop — the MVP.

### Incremental Delivery

1. Setup + Foundational → table and shared rules ready.
2. Add User Story 1 → validate independently → users can propose and withdraw.
3. Add User Story 2 → validate independently → recipients can act on proposals.
4. Add User Story 3 → validate independently → both parties see activity on the homepage without hunting (full P1 MVP).
5. Add User Story 4 → validate independently → confirmed exchanges actually swap locker records.
6. Add User Story 5 → validate independently → the audit/history screen is available.
7. Access Control Coverage → confirm every route is auth-gated.
8. Polish → lint, accessibility, full suite, manual quickstart pass.

### Parallel Team Strategy

With multiple developers, after Setup + Foundational:

- Developer A: User Story 1, then User Story 5 (independent of the accept/decline/confirm chain).
- Developer B: User Story 2, then User Story 4 (the accept→confirm chain).
- Developer C: User Story 3, picked up once A and B's homepage sections (T034/T035, T054/T055) land, since it extends the same view.
