# Phase 1 Data Model: Locker Field Lock & Swap History Comment

This feature adds no new table. It extends two existing entities from 002-locker-floor-profile and
004-locker-swap-proposal. See [research.md](./research.md) for why each decision below is shaped the
way it is.

## Entity: Locker Swap Proposal (existing `locker_swap_proposals` table, extended)

### New fields

| Field | Type | Notes |
| - | - | - |
| `requester_floor_at_resolution` | string, nullable | The requester's `floor` at the moment this proposal left `pending`/`accepted`. `nil` while the proposal is still `pending` or `accepted`. |
| `requester_locker_number_at_resolution` | string, nullable | The requester's `locker_number` at that same moment; `nil` if they had none, or if still unresolved. |
| `recipient_floor_at_resolution` | string, nullable | The recipient's `floor` at that same moment. |
| `recipient_locker_number_at_resolution` | string, nullable | The recipient's `locker_number` at that same moment; `nil` if they had none, or if still unresolved. |

All four are populated together, exactly once, by whichever transition first moves the proposal out
of `pending`/`accepted` (`withdraw!`, `decline!`, the bulk `decline_competing_proposals` auto-decline,
or `confirm!`) — never recomputed afterward (FR-009, and the "no drift after resolution"
clarification). For `confirm!` specifically, the snapshot is taken from `requester`/`recipient`
*before* the existing `swap_lockers` call mutates them, so the values recorded are each side's
pre-swap floor/locker number, matching 004 FR-013's own "what each side gave up and received."

### New derived behavior: `#floor_and_locker_summary`

Not a stored field — computed from the columns above (when resolved) or from `requester`/`recipient`
directly (when not), per status:

| Status | Source | Wording |
| - | - | - |
| `pending`, `accepted` | `requester.floor` / `requester.locker_number` / `recipient.floor` / `recipient.locker_number` (live) | States what is being *proposed* (FR-006). Cannot drift while unresolved — these are exactly the fields FR-001/FR-002 lock. |
| `declined`, `withdrawn` | The four `..._at_resolution` columns | States what was being *proposed* at the time (FR-006) — no exchange took place, but the comment still auto-fills rather than staying blank (spec, User Story 2). |
| `completed` | The four `..._at_resolution` columns | States what was actually *exchanged* (FR-006) — each side's pre-swap values, per 004 FR-013. |

A side with no locker number (either live or snapshotted) is rendered distinctly from a side with
one, reusing the existing "no locker assigned" phrasing already established in
`home/_locker_profile.html.erb` (002) rather than introducing new copy for the same state (Edge
Cases: "no locker number" case).

### New class method: `.active_for?(user)`

`pending.exists?(requester_id: user.id) || pending.exists?(recipient_id: user.id) ||
in_progress_for?(user)` — true when `user` is a party, in either role, to a `pending` or `accepted`
proposal. Used by the new `User` validation (below) and by the home view to decide whether to show
the locked notice in place of the "Edit locker details" disclosure. Distinct from the existing
`in_progress_for?` (accepted only), which 004's proposal-creation eligibility checks continue to use
unchanged.

### Updated state transitions

```text
[pending]
  --(recipient accepts)-->                       [accepted]    (unchanged from 004; no snapshot yet)
  --(recipient declines)-->                       [declined]    (snapshot captured — FR-009)
  --(requester withdraws)-->                      [withdrawn]   (snapshot captured — FR-009)
  --(another of either party's proposals accepted first)--> [declined]  (auto-decline; snapshot captured via correlated subquery — FR-009)

[accepted]
  --(recipient confirms)-->                       [completed]   (pre-swap snapshot captured, then swap_lockers runs — FR-009)
  --(never confirmed)-->                          stays [accepted] indefinitely (unchanged from 004)

[declined] / [withdrawn] / [completed]
  --(any action, including a later profile edit by either party)--> snapshot columns unchanged; #floor_and_locker_summary keeps returning the same text (FR-009, "no drift" clarification)
```

## Entity: User Locker Profile (existing `users.floor` / `users.locker_number`, 002)

No new column. One new validation, scoped to the existing `:locker_profile_update` context 002
already established:

| Rule | Scope | Notes |
| - | - | - |
| Cannot change an already-saved `floor` while `LockerSwapProposal.active_for?(self)` | `on: :locker_profile_update` | FR-001. Checked via `floor_changed? && floor_was.present?`, so a currently-unset `floor` may still be set for the first time even while locked. |
| Cannot change an already-saved `locker_number` while `LockerSwapProposal.active_for?(self)` | `on: :locker_profile_update` | FR-002. Same "already-saved vs. first-time" distinction, via `locker_number_changed? && locker_number_was.present?`. |

Both rules fire together (a single validation method, per research.md), each adding its own error to
the relevant attribute, so a rejected submission that touched both fields reports both (Edge Cases:
"both fields locked together"). Reuses the existing `devise/shared/error_messages` rendering already
wired into `home/_locker_profile_form.html.erb` — no new error-display mechanism.

## Relationships

- No new foreign key or association. The four new `locker_swap_proposals` columns are plain
  denormalized copies of values that, at the moment they are written, live on `users.floor` /
  `users.locker_number` for the relevant `requester_id`/`recipient_id` — captured precisely so they
  no longer need to stay in sync with those columns afterward.
- `LockerSwapProposal.active_for?` reads the same `requester_id`/`recipient_id` columns and partial
  indexes 004 already created; no new index is required (the existing `pending` partial unique index
  on `[requester_id, recipient_id]` and the plain non-unique indexes on `requester_id`/`recipient_id`
  already make both `pending.exists?` lookups indexed).
