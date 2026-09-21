# Phase 1 data model: 026 — open the locker search on arrival from the homepage

## There is no schema change

No table, no column, no index, no migration. Stated plainly at the top because
the absence is the design, not an omission: the spec's Key Entities section says
"No new data is stored", and the feature changes how one screen opens rather than
what the product knows.

The two existing records the feature reads are unchanged, and it writes to
neither.

---

## Existing entities, and how this feature touches them

### `LockerWish` — read-only here

The floor a person says they are looking for. One per user (unique index on
`user_id`, 006).

| What this feature does | Where |
|---|---|
| Asks whether the viewer has one, to know which panel branch renders | `LockerWishesController#index` via `own_locker_wish`, already loaded today |
| Nothing else | — |

**FR-012 is structural, not enforced.** `#new` redirects without touching the
record, and `#index` is a read. There is no path by which arriving with the
intention creates, moves or withdraws a wish; the only writer remains `#create`,
reached by submitting the form.

### `User` — read-only here, and untouched

`#new` runs `authenticate_user!` and nothing more. No attribute is read, written
or derived. The two homepage invitations are chosen by
`home/_locker_wish.html.erb` from `current_user.saved_locker_number` and
`current_user.locker_wish`, exactly as they are today; this feature changes only
where those links point.

---

## The one piece of new state: the navigation intention

It is not a record. It is a single boolean that exists for the duration of one
redirect.

| Property | Value |
|---|---|
| **Name** | `flash[:open_wish_form]` |
| **Type** | Boolean (`true`; the key is absent rather than `false` when there is no intention) |
| **Where it lives** | The Rails flash, i.e. the encrypted session cookie |
| **Written by** | `LockerWishesController#new`, immediately before its redirect |
| **Read by** | `LockerWishesController#index`, on the request the redirect lands on |
| **Lifetime** | Exactly one subsequent request. Rails sweeps it after the request that reads it, with no explicit cleanup. |
| **Visible to the person** | No. It is not `:notice` or `:alert`, and `layouts/_flash.html.erb` renders those two by name rather than iterating the hash (research R2), so it puts nothing on screen. |
| **Visible in the address** | No — this is FR-003, and it is the reason the mechanism is a flash and a redirect rather than a query parameter. |
| **Persisted against the account** | Never. |

### Lifecycle

```
homepage                  GET /locker_wish/new          GET /locker_wishes
  │                              │                             │
  │  press an invitation         │  flash[:open_wish_form]=true│  read → @open_wish_form
  ├─────────────────────────────►│  302 → /locker_wishes       ├──► <details open> + autofocus
                                 └────────────────────────────►│
                                                               │  Rails sweeps the flash
                                                               ▼
                           any later request to /locker_wishes  →  no flash  →  folded
```

The last line is FR-002 in full: a reload, a Back or Forward navigation, a
bookmark and a shared link are all "any later request", and all land folded. The
screen's existing `turbo-cache-control: no-cache` (017 FR-018) is what makes the
Back case reach the server at all rather than replaying a snapshot.

### Derived view state

| Name | Derivation | Used by |
|---|---|---|
| `@open_wish_form` | `flash[:open_wish_form].present?` in `#index` | The declare `<details>`'s `open` attribute, and the `autofocus` local passed to the form partial |

Deliberately the *raw* fact — "this arrival asked for the declare form" — with no
`persisted?` guard folded into it. Where that fact applies is the view's
decision, and the view already answers it by branch: the declare disclosure only
renders for a viewer with no wish, so FR-008 needs no second rule (research R6).

### Validation rules

None. There is nothing to validate: the value is a boolean the application wrote
to its own session one request earlier, it is never read from user input, and the
worst case of a forged or stale value is a disclosure that opens when the person
did not ask — no data is read, written or exposed by that.

---

## What is explicitly *not* modelled

- **No per-user "has seen the form" flag.** The intention is per arrival, not per
  person (spec Key Entities, and the "Two arrivals in a row" edge case: pressing
  the invitation again opens it again).
- **No column recording where a wish was declared from.** Nothing in the spec
  asks where a wish came from, and adding it would be data collected for no
  stated reader.
- **No distinction between the two invitations.** Both carry the same intention
  and produce the same screen (spec Assumptions, "Both viewer states reach the
  same zone"). One flag, not two.
