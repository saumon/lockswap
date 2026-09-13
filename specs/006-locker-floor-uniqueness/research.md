# Phase 0 Research: Per-Floor Locker Number Uniqueness

The technology stack, tables, and columns are all fixed by the existing codebase
(001-user-authentication through 005-swap-lock-history-comment) — there is no new dependency,
table, or column to evaluate. The only open question is how to re-scope an *existing* uniqueness
rule correctly, and whether that re-scoping has any knock-on effect on 004/005's swap-execution
code, which was written with the old (global) rule in mind. Both are resolved below; there is no
`NEEDS CLARIFICATION` left in the Technical Context.

## Re-scoping the uniqueness rule

- **Decision**: Replace the single-column unique index `index_users_on_locker_number` with a
  composite unique index on `[:floor, :locker_number]`, and change the model validation from
  `validates :locker_number, uniqueness: { message: ... }, allow_nil: true, on: :locker_profile_update`
  to the same validation with `scope: :floor` added.
- **Rationale**: This is the direct, minimal expression of the spec's own framing — "it's the couple
  locker-number/floor that must be unique, not the locker number alone." Rails' `scope:` option on
  `uniqueness` and a composite DB index are the standard, idiomatic way to express a compound
  uniqueness key in this stack; both 001 and 002 already use this same pattern of
  validation-plus-backing-index for the single-column case, so this is a change in scope, not in
  technique.
- **Alternatives considered**:
  - A single virtual/computed column combining floor and locker number (e.g. `"#{floor}:#{locker_number}"`)
    with a unique index on that column alone — rejected as needless complexity; Rails and SQLite
    both support genuine composite unique indexes natively, so a synthetic concatenated key would
    only add a derived column to keep in sync for no benefit.
  - Enforcing the per-floor rule only in application-level validation, dropping the DB index —
    rejected for the same race-safety reason 002 rejected it: two concurrent submissions can both
    pass the validation's `SELECT` before either write commits. The composite DB index remains the
    actual correctness guarantee (FR-003, SC-003); `LockerProfilesController`'s existing
    `rescue ActiveRecord::RecordNotUnique` backstop needs no change, since it already reacts to
    *any* uniqueness violation on this record without inspecting which columns collided.

## NULL semantics under a composite index

- **Decision**: No special handling is needed for rows where `locker_number` is `nil` (no locker
  assigned). SQLite (like the SQL standard) treats a row where *any* indexed column is `NULL` as
  distinct from every other row for a unique index, composite or single-column. This is exactly the
  same behavior the single-column index already relied on for "many users, all with no locker" in
  002 — the composite version preserves it unchanged, so multiple users can continue to share the
  same floor with no locker number, or have no floor and no locker number, without any collision.
- **Rationale**: Confirmed by re-reading 002's existing rationale for `allow_nil: true` (research.md,
  "Locker number: optional and unique across users") — that reasoning is scope-independent; adding
  `floor` into the index does not change how `NULL` is treated in `locker_number`.
- **Alternatives considered**: A `NOT NULL DEFAULT ''`-style sentinel to avoid relying on SQL NULL
  semantics — rejected; it would resurrect exactly the "empty string collides" bug 002 already
  identified and solved by normalizing blanks to `nil`, for no gain.

## Effect on 004/005's swap execution

- **Decision**: No code change to `LockerSwapProposal#swap_lockers`. The existing vacate-the-requester-
  first, then-write-the-recipient, then-write-the-requester sequence remains both necessary and
  sufficient under the composite index. Only the explanatory comment above it (which currently says
  "locker_number is unique across users") is corrected to describe the per-floor scope, so the
  comment does not contradict the rule it is explaining.
- **Rationale**: The sequencing exists to avoid two rows momentarily holding a colliding key during
  the two-step handoff. That risk is not eliminated by narrowing the key to `(floor, locker_number)`
  — it is unchanged whenever the two parties are swapping onto floors where the incoming pair could
  collide with a value already on the destination row (most concretely: two users on the *same*
  floor swapping locker numbers with each other still momentarily need one side vacated, since both
  rows share the same floor value throughout). The vacate-first order already handles this generally
  because it clears one full side of the pair before the other side ever adopts it, regardless of
  which columns the uniqueness key spans. `swap_lockers` also already uses plain `update!` outside
  the `:locker_profile_update` validation context, so 002/006's presence-of-floor rule does not fire
  mid-swap either — unaffected by this feature.
- **Alternatives considered**: Re-deriving a new swap sequencing proof from scratch — rejected as
  unnecessary; the existing proof generalizes to any uniqueness key scope, since it never depended on
  the key being single-column.

## Existing tests that encode the old (global) rule

- **Decision**: `test/models/user_test.rb`'s current uniqueness test (`user.locker_number =
  users(:bob).locker_number` expected to fail regardless of floor) asserts exactly the behavior this
  feature removes, and must be replaced — not merely supplemented — with tests for both halves of the
  new rule: the same locker number on a *different* floor succeeds, and on the *same* floor it is
  still rejected. The DB-level race test (bypassing model validation to hit the raw unique index) is
  updated the same way, since it is currently written against the single-column index.
- **Rationale**: Leaving the old assertion in place alongside new ones would make the suite
  self-contradictory (one test demanding global uniqueness, others demanding per-floor uniqueness).
  This is a correction, not an addition, consistent with the spec's own framing as fixing a defect.
- **Alternatives considered**: None — keeping a test that asserts the old, now-incorrect behavior is
  not a viable option under Testing Standards (the suite must reflect the current, correct rule).
