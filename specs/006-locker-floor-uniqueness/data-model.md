# Phase 1 Data Model: Per-Floor Locker Number Uniqueness

## Entity: User Locker Profile (extends `User` — same entity as 002, rule updated)

No column changes. `floor` and `locker_number` (both nullable strings on the existing `users`
table, introduced in 002) are unchanged in type and meaning. Only the **uniqueness rule** that
relates them changes.

| Field | Type | Notes |
| - | - | - |
| `floor` | string, nullable | Unchanged from 002: free-form, required (non-blank) on the `:locker_profile_update` save path (FR-007). Now also the scope for `locker_number` uniqueness. |
| `locker_number` | string, nullable | Unchanged type/meaning from 002. **Updated**: unique per `floor`, not across all users — the same number may be held by different users when their floors differ (FR-001, FR-002). |

### Validation rules (updated from 002)

All validations remain on the `:locker_profile_update` context only (unchanged from 002 — this
context is exclusive to `LockerProfilesController#update` and never blocks unrelated `User` saves):

- `floor`: unchanged — required (`presence: true`). Because this presence check runs on every save
  in this context regardless of whether `locker_number` is present, a `locker_number` can never be
  persisted through this path without a `floor` also being present in the same save — this is what
  satisfies FR-007/FR-008 without any new validation being added.
- `locker_number`: **updated** — optional; when present, unique **per `floor`**
  (`uniqueness: { scope: :floor, message: ... }, allow_nil: true`) instead of unique across all
  `User` records. The existing blank-to-`nil` normalization (`normalizes :locker_number`) is
  unchanged.
- `LOCKER_NUMBER_TAKEN_MESSAGE`: re-worded to state the locker number is unavailable *on that
  floor*, so the message stays accurate without disclosing who holds it (FR-003).

### Persistence-layer backstop (updated from 002)

- The unique DB index moves from `users.locker_number` alone to the composite
  `[users.floor, users.locker_number]` (multiple `NULL`s in either column remain allowed under
  SQLite's standard NULL-distinct semantics for unique indexes — see research.md). This remains the
  race-safe guarantee under concurrent submissions (FR-003, SC-003), exactly as the single-column
  index was in 002; `LockerProfilesController` needs no change to its existing
  `rescue ActiveRecord::RecordNotUnique` handling, since it already reacts generically to any
  uniqueness violation on the record.

### State transitions (delta from 002 — only the collision condition changes)

```text
[floor: "1", locker_number: nil]
  --(submit locker_number "001", no one holds ("1","001"))-->        [floor: "1", locker_number: "001"]
  --(submit locker_number "001", already held by another user on floor "1")--> rejected, no state change (US2)
  --(submit locker_number "001", already held by another user on floor "2")--> succeeds — different floor, no collision (US1)

[floor: "1", locker_number: "001"]
  --(change floor to "2", no one holds ("2","001"))-->                [floor: "2", locker_number: "001"] (US3 scenario 1)
  --(change floor to "2", already held by another user on floor "2")--> rejected, no state change (US3 scenario 2)
  --(after moving away from ("1","001"))-->                          ("1","001") becomes claimable by any other user (US3 scenario 3, Edge Case)
```

- Resubmitting a user's own current `(floor, locker_number)` pair unchanged is a no-op success, not
  a self-collision (FR-004) — unchanged in shape from how 002 already allowed a user to resubmit
  their own value, just now checked against the pair instead of the single column.

## Relationships

None beyond the single `User` record these two fields live on — unchanged from 002. This feature
touches no other entity's schema. It does, however, touch the *reasoning* (not the schema or
behavior) of one already-existing cross-entity interaction:

- **`LockerSwapProposal#swap_lockers`** (004/005) reads and writes `floor`/`locker_number` on both
  `requester` and `recipient` outside the `:locker_profile_update` context (via `update!`), so
  neither the floor-presence rule nor the (now per-floor) uniqueness validation runs mid-swap. The
  DB-level composite unique index still applies unconditionally during the swap, which is exactly
  why the existing vacate-the-requester-first sequencing remains required — see research.md,
  "Effect on 004/005's swap execution."
