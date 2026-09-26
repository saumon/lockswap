---

description: "Task list for Locker Zone Visibility Across Screens"
---

# Tasks: Locker Zone Visibility Across Screens

**Input**: Design documents from `/specs/032-locker-zone-visibility/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/zone-lookup.md, quickstart.md

**Tests**: Included as their own tasks per user story — Constitution II (Testing Standards,
NON-NEGOTIABLE) requires every new feature to ship with automated tests that fail without the
change and pass with it; this mirrors how 031 (the feature this one extends) sequenced its own
tasks (model/validator tests before controller/view changes).

**Organization**: Tasks are grouped by user story (spec.md's US1–US4) so each can be implemented,
tested, and delivered independently. All four stories build on the same Phase 2 lookup, so once
Phase 2 lands, stories may be done in any order — priority order (US1 → US2 → US3 → US4) is
recommended but not required.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Every task names its exact file path

## Path Conventions

Single-project Rails monolith (per plan.md) — `app/`, `test/`, `config/` at the repository root.

---

## Phase 1: Setup

**Purpose**: Confirm the ground this feature builds on before touching it.

- [X] T001 Confirm `Zone`/`LockerMapEntry` (031, `app/models/zone.rb` /
      `app/models/locker_map_entry.rb`) and `LockerSwapProposal#floor_and_locker_summary`
      (`app/models/locker_swap_proposal.rb`) are present and unchanged on this branch; no migration,
      no new gem, and no new route are added by this feature (plan.md → Technical Context).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The one shared lookup every user story's screens read from. No user story's tasks may
start until this phase is complete — every later phase calls these same methods.

**⚠️ CRITICAL**: Complete this phase before any Phase 3+ task.

- [X] T002 Write failing model tests for `LockerMapEntry.zone_names_for(pairs)` and
      `LockerMapEntry.zone_name_for(floor, locker_number)` in
      `test/models/locker_map_entry_test.rb`, covering: a declared pair returns its zone's name; an
      undeclared pair is absent from the Hash / returns `nil`; a blank or `nil` floor/locker_number
      pair is normalized away and never raises; an empty `pairs` array returns `{}` without querying
      (assert via `assert_no_queries` or an equivalent query-count check); a pair whose zone was
      renamed reflects the new name on the very next call; a pair removed from its zone (or whose
      zone was deleted) is absent from the next call's result (data-model.md, contracts/zone-lookup.md).
- [X] T003 Implement `LockerMapEntry.zone_names_for(pairs)` and `LockerMapEntry.zone_name_for(floor,
      locker_number)` in `app/models/locker_map_entry.rb`, making T002 pass: normalize each pair the
      same way `.known?` already does (stripped, blank → `nil`), issue exactly one
      `joins(:zone).where(floor: ..., locker_number: ...)` query keyed back into a Hash by the
      normalized `[floor, locker_number]` pair, and short-circuit to `{}` for an empty/all-blank
      input without querying (research.md R1, contracts/zone-lookup.md).
- [X] T004 [P] Write a failing model test for `LockerSwapProposal#locker_sides` in
      `test/models/locker_swap_proposal_test.rb`, covering: a `pending?` proposal returns the live
      `[requester.floor, requester.locker_number]` / `[recipient.floor, recipient.locker_number]`
      pairs; an `accepted?` proposal does the same; a settled (declined or completed) proposal
      returns the frozen `*_at_resolution` pairs instead, in the same order
      `floor_and_locker_summary` already uses (research.md R3, data-model.md).
- [X] T005 [P] Implement `LockerSwapProposal#locker_sides` in `app/models/locker_swap_proposal.rb`,
      making T004 pass, by extracting/reusing the existing private `sides` computation that
      `floor_and_locker_summary` already builds — `floor_and_locker_summary` itself MUST NOT change
      (research.md R3).

**Checkpoint**: `LockerMapEntry.zone_names_for`/`.zone_name_for` and
`LockerSwapProposal#locker_sides` are implemented and covered by passing tests. Every user story
phase below only adds callers of these methods plus their own view/controller changes.

---

## Phase 3: User Story 1 - A user sees their own locker's zone (Priority: P1) 🎯 MVP

**Goal**: The account holder's own locker card, on the homepage, shows the zone name for their
saved floor + locker number whenever that pair is declared in the Locker Map.

**Independent Test**: With a zone containing a user's saved locker declared on the Locker Map, log
in as that user and confirm the zone name appears on the homepage next to their floor and locker
number; confirm it does NOT appear for an undeclared locker or for no locker at all.

- [X] T006 [P] [US1] Add the "zone" locale key(s) for the new label (e.g.
      `home.locker_profile.zone`) to `config/locales/en.yml` and `config/locales/fr.yml`, next to
      the existing `home.locker_profile.*` keys `floor`/`locker_number`/`no_locker_assigned`
      (Constitution III — every user-facing string in both languages).
- [X] T007 [US1] Write a failing system/controller-level test asserting that a signed-in user whose
      saved floor + locker number is declared in a zone sees that zone's name on the homepage
      locker card, and that a user whose saved locker is not declared (or who has no locker at all)
      sees no zone text and no error — extend `test/system/homepage_locker_wish_test.rb` (or add
      assertions to whichever existing system test already visits the homepage locker card); assert
      the zone name renders in an element distinct from the locker-number value (not concatenated
      into the same text node), to guard FR-008.
- [X] T008 [US1] In `app/views/home/_locker_profile.html.erb`, call
      `LockerMapEntry.zone_name_for(current_user.saved_floor, current_user.saved_locker_number)`
      at the same place the floor/locker `dd` elements already read `current_user.saved_floor` /
      `current_user.saved_locker_number` (mirroring how this partial already resolves values
      through `current_user` rather than an ivar, per its own existing comment about
      `HomeController`/`LockerProfilesController` being two renderers of this same page — research.md
      R2), and render the zone name in a small, visually distinct element (e.g. the existing `.meta`
      treatment, never the swap-axis blue/green) only when a zone name is present (FR-001, FR-005,
      FR-008).
- [X] T009 [US1] Run T007's test and confirm it now passes; run
      `bin/rails tailwindcss:build` if any new class was introduced.

**Checkpoint**: User Story 1 is independently complete, tested, and deliverable.

---

## Phase 4: User Story 2 - A user sees the zone of a locker they are considering swapping (Priority: P2)

**Goal**: The locker search list, a received swap proposal, and the exchange-in-progress card each
show the other party's locker's zone name whenever declared.

**Independent Test**: With a zone containing one user's declared locker, confirm its name appears
on another user's view of the locker search list, on a swap proposal sent between them, and on the
exchange-in-progress card once accepted — and does not appear when the locker is undeclared.

- [X] T010 [P] [US2] Add the locale key(s) for the zone label to `config/locales/en.yml` /
      `config/locales/fr.yml` for the locker-search-list and swap-proposal contexts (reuse T006's
      key if the same wording applies across screens; add a second key only if context requires
      different phrasing) (Constitution III). Done: reused the single `shared.zone_label` key
      added under T006, rendered via the new `shared/_zone_label` partial.
- [X] T011 [US2] Write a failing controller/system test for the locker search list asserting a row
      shows the zone name when the wisher's saved locker is declared, and shows nothing extra when
      it is not declared or when the wisher has no locker at all — extend
      `test/controllers/locker_wishes_controller_test.rb` and/or `test/system/` coverage that
      already visits this list; assert the zone name renders in an element distinct from the
      locker-number value (not concatenated into the same text), to guard FR-008.
- [X] T012 [US2] Write a failing controller/system test for the homepage "swap proposal received"
      card asserting the zone name of the requester's locker is shown when declared, and absent
      when not declared or when the requester has no locker at all — extend the relevant existing
      homepage/proposal test.
- [X] T013 [US2] Write a failing controller/system test for the homepage "exchange in progress"
      card asserting the counterpart's zone name is shown when declared, and absent when not
      declared or when the counterpart has no locker at all — extend the relevant existing
      homepage/proposal test.
- [X] T014 [US2] In `app/controllers/locker_wishes_controller.rb`'s `load_wish_list`, after
      `@locker_wishes` is built, batch-resolve `@locker_zone_names = LockerMapEntry.zone_names_for(
      @locker_wishes.map { |wish| [wish.user.saved_floor, wish.user.saved_locker_number] })` — one
      query for the whole list, never one per row (research.md R1, R2; Constitution IV).
- [X] T015 [US2] In `app/views/locker_wishes/_locker_wish_list.html.erb`, render
      `@locker_zone_names[[wish.user.saved_floor, wish.user.saved_locker_number]]` next to the
      existing `their-locker` cell, as a visually distinct element, only when present (FR-002,
      FR-005, FR-008).
- [X] T016 [P] [US2] In `app/views/home/_swap_proposals_received.html.erb`, call
      `LockerMapEntry.zone_name_for(proposal.requester.saved_floor, proposal.requester.saved_locker_number)`
      — the same "value on file" readers the adjacent `proposal_details` line already uses, not the
      raw `.floor`/`.locker_number` attributes — next to that line, and render it distinctly when
      present (FR-002, FR-005, FR-008).
- [X] T017 [P] [US2] In `app/views/home/_swap_exchange_in_progress.html.erb`, call
      `LockerMapEntry.zone_name_for(counterpart.saved_floor, counterpart.saved_locker_number)` — the
      same "value on file" readers the adjacent `counterpart_details` line already uses, not the raw
      `.floor`/`.locker_number` attributes — next to that line, and render it distinctly when
      present (FR-002, FR-005, FR-008).
- [X] T018 [US2] Run T011–T013's tests and confirm they now pass.

**Checkpoint**: User Story 2 is independently complete, tested, and deliverable — does not require
US1 to be implemented first (both depend only on Phase 2), though US1 is recommended first as the
simpler proof of the lookup.

---

## Phase 5: User Story 3 - An administrator sees a locker's zone without leaving the account screen (Priority: P3)

**Goal**: The admin account directory list and an individual account's detail page each show that
account's locker's zone name whenever declared.

**Independent Test**: With a zone containing an account's declared locker, confirm an admin sees
the zone name both in that account's row on the directory list and on that account's detail page —
and does not see it when the locker is undeclared.

- [X] T019 [P] [US3] Add the locale key(s) for the zone label/column to `config/locales/en.yml` /
      `config/locales/fr.yml` for the admin directory and detail-page contexts (Constitution III).
      Done: reused the shared `shared.zone_label` key from T006.
- [X] T020 [US3] Write a failing controller/system test asserting the admin account directory list
      (`admin/users/index.html.erb`) shows the zone name for a row whose locker is declared, and
      shows nothing extra for a row whose locker is not declared, or whose account has no locker at
      all — extend `test/controllers/admin/users_controller_test.rb` and/or
      `test/system/admin_users_test.rb`; assert the zone name renders in an element distinct from
      the locker-number value, to guard FR-008.
- [X] T021 [US3] Write a failing controller/system test asserting the admin account detail page
      (`admin/users/show.html.erb`) shows the zone name when the viewed account's locker is
      declared, and shows nothing extra when it is not declared, or when the account has no locker
      at all — extend `test/controllers/admin/users_controller_test.rb` and/or
      `test/system/admin_user_detail_test.rb`.
- [X] T022 [US3] In `app/controllers/admin/users_controller.rb#index`, after `@users` is built,
      batch-resolve `@locker_zone_names = LockerMapEntry.zone_names_for(@users.map { |user|
      [user.saved_floor, user.saved_locker_number] })` — one query for the whole directory list,
      never one per row (research.md R1, R2; Constitution IV, mirroring this action's existing
      `includes(:admin_granted_by, :locker_wish)`).
- [X] T023 [US3] In `app/views/admin/users/index.html.erb`, render
      `@locker_zone_names[[user.saved_floor, user.saved_locker_number]]` next to the existing
      floor/locker cells, as a visually distinct element, only when present (FR-003, FR-005, FR-008).
- [X] T024 [US3] In `app/controllers/admin/users_controller.rb#show`, after `@user` is loaded, set
      `@locker_zone_name = LockerMapEntry.zone_name_for(@user.saved_floor,
      @user.saved_locker_number)` (research.md R2 — single-record screen).
- [X] T025 [US3] In `app/views/admin/users/show.html.erb`, render `@locker_zone_name` next to the
      existing floor/locker `dd` elements, as a visually distinct element, only when present
      (FR-003, FR-005, FR-008).
- [X] T026 [US3] Run T020–T021's tests and confirm they now pass.

**Checkpoint**: User Story 3 is independently complete, tested, and deliverable — does not require
US1/US2 to be implemented first (all depend only on Phase 2).

---

## Phase 6: User Story 4 - Zone shown on past swap history (Priority: P3)

**Goal**: The self-service swap-history screen and the admin account detail page's history table
each show, per side of a past proposal, the zone currently claiming that side's floor + locker
number, whenever declared.

**Independent Test**: After completing a swap for a locker declared in a zone, confirm the zone
name appears next to that history entry on both the self-service history screen and the admin
detail page's history table — and does not appear when the locker is not currently declared.

- [X] T027 [P] [US4] Add the locale key(s) for the zone label to `config/locales/en.yml` /
      `config/locales/fr.yml` for the swap-history context (Constitution III). Done: reused the
      shared `shared.zone_label` key from T006.
- [X] T028 [US4] Write a failing controller/system test asserting the self-service history screen
      (`locker_swap_proposals/index.html.erb` via `LockerSwapProposalsController#index`) shows a
      zone name next to each side of a history row whose floor + locker number is currently
      declared, and shows nothing extra for a side that is not currently declared or whose recorded
      floor/locker is blank — extend `test/controllers/locker_swap_proposals_controller_test.rb`;
      assert each side's zone name renders in an element distinct from `floor_and_locker_summary`'s
      text, to guard FR-008.
- [X] T029 [US4] Write a failing controller/system test asserting the admin account detail page's
      history table (`admin/users/show.html.erb`'s `@proposal_history`) shows the same, per side —
      extend `test/controllers/admin/users_controller_test.rb`.
- [X] T030 [US4] In `app/controllers/locker_swap_proposals_controller.rb#index`, after `@proposals`
      is built, batch-resolve `@locker_zone_names = LockerMapEntry.zone_names_for(@proposals.flat_map(
      &:locker_sides))` — one query for the whole history list, never one per row or per side
      (research.md R1, R3; Constitution IV).
- [X] T031 [US4] In `app/controllers/admin/users_controller.rb#show`, after `@proposal_history` is
      built, batch-resolve `@locker_zone_names = LockerMapEntry.zone_names_for(
      @proposal_history.flat_map(&:locker_sides))` the same way (research.md R1, R3).
- [X] T032 [US4] Update `app/views/locker_swap_proposals/_history_table.html.erb`'s
      `locker-details` cell to render, next to (never inside) the existing
      `proposal.floor_and_locker_summary` text, each side's zone name looked up from the caller-
      supplied `@locker_zone_names` Hash via `proposal.locker_sides`, as a visually distinct
      element, only when present for that side (FR-004, FR-005, FR-008, FR-009). This is the one
      partial shared by both `locker_swap_proposals/index.html.erb` and `admin/users/show.html.erb`
      (per the partial's own existing comment), so this single change serves both callers once
      T030 and T031 each supply `@locker_zone_names`.
- [X] T033 [US4] Run T028–T029's tests and confirm they now pass.

**Checkpoint**: User Story 4 is independently complete, tested, and deliverable — does not require
US1/US2/US3 to be implemented first (all depend only on Phase 2).

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final validation across every story once all four are implemented.

- [X] T034 [P] Run `test/system/accessibility_test.rb` (axe-core) against every screen touched by
      this feature to confirm the new zone label has no accessibility violations (sufficient
      contrast, no orphaned text) (Constitution III).
- [X] T035 [P] Run `bin/rails test test/i18n_completeness_test.rb` (this repo's existing automated
      i18n coverage gate — there is no `i18n-tasks` gem in this project) to confirm every new key
      from T006/T010/T019/T027 exists in both `en.yml` and `fr.yml` with no missing/unused entries
      (Constitution III, Quality Gates).
- [X] T036 Walk through `quickstart.md` end-to-end (own locker, search list, proposal
      received/exchange in progress, admin directory/detail, swap history, plus the empty-map /
      unmapped / rename / removed-from-zone edge cases) and confirm every scenario matches its
      expected outcome.
- [X] T037 Run `bin/rubocop` and Brakeman (or this repo's equivalent CI lint/security commands)
      across every file touched by this feature and resolve any warning (Constitution I, Quality
      Gates).
- [X] T038 [P] (Optional, SC-005) Add one automated view-level regression test — e.g. in
      `test/system/admin_users_test.rb` — that renames a zone (or removes a locker from it) via the
      Locker Map screen and asserts the new name (or its absence) is reflected on the next render of
      at least one already-touched screen, supplementing T002's model-level coverage and T036's
      manual quickstart pass.

---

## Phase 8: Post-Implementation Follow-Up — Dedicated Zone Column (FR-002a/FR-003a)

**Purpose**: A follow-up request from the user, after Phase 1–7 shipped: on the two tables where a
locker number already has its own dedicated cell per row (the locker search list, the account
directory), the zone must be its own column rather than sharing the locker cell. The swap-history
table stays inline (user confirmed when asked, since each of its rows already combines two people's
floor + locker into one prose cell — no single column can represent two different zones cleanly).

- [X] T039 [P] Add the shared `shared.no_zone` locale key ("No zone" / "Aucune zone") to
      `config/locales/en.yml` and `config/locales/fr.yml`, in the same voice as its neighbouring
      placeholders ("Not set", "No locker assigned") — reuses the existing `shared.zone_label` key
      ("Zone") as both tables' new column header.
- [X] T040 In `app/views/locker_wishes/_locker_wish_list.html.erb`, add a "Zone" column
      (`<th>`/`<td id="...-current-zone">`) right after "Their locker", showing the zone name or the
      `shared.no_zone` placeholder; remove the inline `shared/_zone_label` render from the
      `-current-locker` cell.
- [X] T041 In `app/views/admin/users/index.html.erb`, add a "Zone" column
      (`<th>`/`<td id="admin-user-row-#{user.id}-zone">`) right after "Locker", showing the zone name
      or the `shared.no_zone` placeholder; remove the inline `shared/_zone_label` render from the
      `-locker` cell.
- [X] T042 Update the existing zone tests in `test/controllers/locker_wishes_controller_test.rb` and
      `test/controllers/admin/users_controller_test.rb` to assert against the new dedicated
      `-current-zone`/`-zone` cells (plain text, no `.zone-label` class) instead of the removed inline
      render; re-run `test/system/responsive_test.rb` (header/data-label correspondence) and
      `test/system/accessibility_test.rb` to confirm the new column doesn't break either contract.

---

## Phase 9: Post-Implementation Follow-Up — Uniform Homepage Styling

**Purpose**: A second follow-up request: on the homepage's own locker card specifically, the zone
must match Floor and Locker number's own presentation — same row at desktop, bold label with no
colon at every width — rather than the inline "Zone: X" sentence used elsewhere.

- [X] T043 In `app/views/home/_locker_profile.html.erb`, replace the `shared/_zone_label` render with
      a third `dt`/`dd` field in the existing `.detail-grid`, matching Floor and Locker number's exact
      markup (label with no colon, `.detail-value` styling), omitted entirely when no zone is declared
      (FR-005 unchanged).
- [X] T044 In `app/assets/tailwind/application.css`, add an opt-in `.detail-grid--zone` modifier
      (inside the existing 48rem media query, per the one-breakpoint rule) widening this specific grid
      to 3 columns at desktop only when the zone field is present — the base `.detail-grid` (admin
      detail page, and the homepage card when it has no zone) keeps its original 2-column layout, so
      the pre-existing breakpoint regression test (`responsive_test.rb`, using `.detail-grid`'s column
      count as generic evidence of the 768px switch) is undisturbed.
- [X] T045 Update `test/system/locker_profile_test.rb`'s zone tests for the new `#locker-profile-zone`
      field (dropping the old `.zone-label`/"Zone:" assertions) and add coverage for the two new
      requirements: same-row placement at desktop (`assert_same_line` + rect ordering) and same-line
      placement with a bold label on mobile (`assert_same_line` + a computed `font-weight` check).

---

## Phase 10: Post-Implementation Follow-Up — User Story 4 Withdrawn

**Purpose**: A third follow-up request: remove the zone information from the "Locker details" column
on both swap-history screens entirely. User Story 4, FR-004, and FR-009 are withdrawn (struck through
in spec.md, not deleted, so the reasoning that once justified them stays on record).

- [X] T046 In `app/views/locker_swap_proposals/_history_table.html.erb`, remove the per-side
      `shared/_zone_label` render from the `-locker-details` cell — it shows only
      `proposal.floor_and_locker_summary` again, exactly as before this feature existed.
- [X] T047 Remove the now-unused `@locker_zone_names` batch lookup from
      `LockerSwapProposalsController#index` and from both `Admin::UsersController#show` and
      `Admin::UserLockerProfilesController#update`'s `load_proposal_data` (its second renderer) —
      keeping each controller's other zone lookup (`@locker_zone_name`, US1/US3) untouched.
      `LockerSwapProposal#locker_sides` itself is kept, since `floor_and_locker_summary` still calls it
      internally.
- [X] T048 Replace the withdrawn zone assertions in `test/system/locker_swap_proposal_test.rb` and
      `test/controllers/admin/users_controller_test.rb` with a single regression test per screen
      confirming the "Locker details" column shows no zone text even when one is declared for a side's
      floor + locker number — guarding against the withdrawn behavior quietly reappearing.

---

## Phase 11: Post-Implementation Follow-Up — Received-Proposal Wording

**Purpose**: A fourth follow-up request: on the homepage's received-proposal card, the zone moves onto
the same line as floor/locker (no colon), and the sent date moves to its own line below in a new,
deliberately fixed day/month/year format reserved for this one field.

- [X] T049 [P] Add `time.formats.numeric_at: "%d/%m/%Y à %H:%M"` to both `config/locales/en.yml`
      (a new top-level `time:` key — this app's en.yml otherwise relies on Rails' bundled English
      date/time defaults) and `config/locales/fr.yml` (a new key under the existing `time.formats`
      block) — identical in both files, a deliberate second fixed format alongside `:long`
      (025/FR-012's reasoning, applied to a second string rather than extending the first).
- [X] T050 Split `home.swap_proposals_received.proposal_details` into `proposal_details` (floor +
      locker only) and `proposal_details_with_zone` (+ " · Zone %{zone}"), and add a new
      `sent_at: "Sent %{sent_at}"` key, in both `en.yml` and `fr.yml` — mirroring
      `swap_proposals_sent.sent_at`'s existing wording.
- [X] T051 In `app/views/home/_swap_proposals_received.html.erb`, split the single `proposal_details`
      paragraph into two: floor + locker (+ zone, when declared, via `proposal_details_with_zone`) on
      one line, and `sent_at` (using `l(proposal.created_at, format: :numeric_at)`) on its own line
      below — replacing the `shared/_zone_label` render, which is no longer used on this card.
- [X] T052 Update `test/system/locker_swap_proposal_test.rb`'s received-proposal zone tests for the
      new wording and line split, and add a regression test asserting the sent date renders in the new
      `dd/mm/yyyy à hh:mm` format on its own line.

---

## Dependencies & Execution Order

- **Phase 1 (Setup)** → **Phase 2 (Foundational)**: strictly sequential; Phase 2 blocks every user
  story.
- **Phase 2** is a hard prerequisite for Phases 3–6; within Phase 2, T002→T003 and T004→T005 are
  each strictly sequential (test before implementation), but the two pairs (`zone_names_for`/
  `zone_name_for` vs. `locker_sides`) touch different files and may proceed in parallel with each
  other.
- **Phases 3–6 (US1–US4)** are mutually independent once Phase 2 is done — each touches a disjoint
  set of controller/view files and can be implemented, tested, and shipped in any order or in
  parallel by different contributors. Priority order (US1 → US2 → US3 → US4) is recommended for a
  single contributor working sequentially, since US1 is the smallest proof of the shared lookup.
- **Phase 7 (Polish)** runs only after every user story to be shipped in this release is complete.

## Parallel Execution Examples

- Within Phase 2: T002+T003 (LockerMapEntry) and T004+T005 (LockerSwapProposal) are two independent
  file-pairs and may be worked in parallel by two contributors.
- Once Phase 2 is done: an entire user-story phase (e.g., all of Phase 4/US2) may run in parallel
  with another entire phase (e.g., Phase 5/US3), since neither touches a file the other does.
- Within Phase 4/US2: T016 (`_swap_proposals_received.html.erb`) and T017
  (`_swap_exchange_in_progress.html.erb`) are marked `[P]` — different files, no shared dependency
  once T014's controller change and T015's list-view change are in place (T014/T015 themselves
  share `_locker_wish_list.html.erb`'s controller action and are sequential with each other).

## Implementation Strategy

**MVP = Phase 1 + Phase 2 + Phase 3 (US1)**: the account holder's own locker card shows its zone.
This is the smallest deliverable slice that proves the shared lookup end-to-end and delivers
visible value on its own.

**Incremental delivery**: ship US1 first, then add US2 (swap-decision screens — the highest-value
story per spec.md), then US3 (admin screens) and US4 (history) in either order, since all three
depend only on Phase 2 and not on each other or on US1.
