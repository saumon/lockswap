# Phase 1 Data Model: Streamlined Locker Entry & Pencil-Icon Edit

## Persisted data

No schema changes. This feature introduces no new tables, columns, or migrations. It reuses the `User Locker Profile` attributes already defined in `002-locker-floor-profile` and refined in `006-locker-floor-uniqueness`:

| Attribute | Type | Rule | Introduced by |
|---|---|---|---|
| `floor` | string | Required on the `:locker_profile_update` validation context (`validates :floor, presence: true`) | 002 |
| `locker_number` | string, nullable | Optional; normalized to `nil` when blank; unique per `floor` (`uniqueness: { scope: :floor }`, `allow_nil: true`) | 002, 006 |

Both attributes belong to exactly one `User` record and are independent of each other. This feature does not add a "declared no locker" flag or any other new attribute — "no locker" continues to be represented exactly as it is today: `locker_number` is `nil`.

## Transient (view-only) state

This feature's only new "state" is a client-side, non-persisted UI choice on the first-entry screen:

| State | Values | Lifetime | Where it lives |
|---|---|---|---|
| First-entry view | `entering-locker` (default) \| `no-locker` | From page load until the form is submitted; not persisted | DOM only, managed by the `locker_entry_choice_controller` Stimulus controller (a data attribute / hidden/shown element state) |

This state never reaches the server as a distinct value — it only determines which fields are visible/enabled at submit time. The server continues to see the same two params it always has (`user[floor]`, `user[locker_number]`), with `user[locker_number]` empty when the `no-locker` view was active.

## Validation rules (unchanged)

- `floor` presence is enforced server-side on every submission through `PATCH /locker_profile`, regardless of which first-entry view or edit control was used (spec FR-011).
- `locker_number` uniqueness scoped to `floor` is enforced server-side the same way (spec FR-011); a race between two concurrent submissions is still caught via the unique index and translated to the existing `LOCKER_NUMBER_TAKEN_MESSAGE` (see `app/controllers/locker_profiles_controller.rb`).
- The existing "locked while an active swap proposal exists" rule (005) is unaffected: when locked, neither first-entry view nor the pencil-icon edit control is shown at all — the explanatory message takes their place, exactly as today.

## State transitions

```text
[No floor saved yet]
   ├─ default view: "entering-locker" (floor + locker-number fields shown)
   │     ├─ user types floor (+ optional locker number) → submit → [Floor saved, locker-number saved or nil]
   │     └─ user clicks "I don't have a locker 😔" → view: "no-locker" (locker-number field hidden, its value cleared)
   │           ├─ user types floor → submit → [Floor saved, locker_number nil]
   │           └─ user clicks "Actually, I have a locker" → back to "entering-locker" (floor value preserved)
   │
[Floor already saved] (via either path above)
   └─ pencil icon on "Your locker" card → standard two-field edit form (pre-filled) → submit → [updated Floor / locker_number]
         (no "no-locker" shortcut here — clearing the locker-number field achieves the same result, per Clarifications)
```
