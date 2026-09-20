# Phase 1 Data Model: Modernized Toast Notifications

This feature has no persisted data — no new model, migration, or database table. It has one transient, in-memory/DOM presentation entity, derived each page load from the existing Rails flash (`notice`/`alert`), plus one small piece of client-side layer state introduced by FR-010.

## Toast Notification (presentation entity, unchanged trigger source)

| Attribute | Type | Derivation / Rule |
|---|---|---|
| `message` | text | The flash value itself (`notice` or `alert`); wording is unchanged by this feature (FR-011). |
| `type` | enum: `success` \| `error` | `notice` → `success`; `alert` → `error`. One-to-one with the existing two flash keys — no new categories (per spec Assumptions). |
| `role` | enum: `status` \| `alert` (ARIA) | `success` → `role="status"`; `error` → `role="alert"`. Unchanged from the current implementation. |
| `icon` | one of two fixed inline SVGs | Derived from `type`: `success` → check glyph, `error` → alert glyph. New attribute added by this feature (FR-002). |
| `accent_color` | token reference | Derived from `type`: `success` → `--color-status-success`, `error` → `--color-status-error`. Unchanged token, reused for both the left edge and the icon. |
| `duration_ms` | integer | `Rails.configuration.x.notification_auto_dismiss_ms`, unchanged (FR-006). |
| `dismissible` | boolean | Always `true`; unchanged (FR-006). |

**Lifecycle**: `queued` → `visible` → (`dismissing` on timeout or manual dismiss) → `removed` (element deleted from the DOM, not merely hidden — unchanged from the current `notification_controller.js#dismiss`). A notification never re-enters `visible` after `removed`.

**Invariants**:
- At most one `message`/`type` pair per flash key per page load — this entity does not introduce multi-message queuing from a single request; FR-010's queue (below) only applies when *the layer* already holds the cap's worth of notifications from independent triggers (e.g. an in-flight Turbo Stream toast plus a fresh page-load flash).
- `message` text is never truncated or rewritten by this feature; only wrapping (existing behavior) applies to overflow.

## Toast Layer (new client-side state, FR-010)

Not a database entity — a small piece of state held by the new `toast_layer_controller.js`, scoped to the `.toast-layer` container element.

| Attribute | Type | Rule |
|---|---|---|
| `visible` | ordered list of Toast Notification, max length 3 | Notifications currently rendered and counting down. Cap value fixed at 3 (see research.md §4). |
| `queued` | ordered list of Toast Notification | Notifications received while `visible` is already at cap; FIFO — oldest queued is promoted first. |

**Transition rule**: when a member of `visible` reaches `removed`, if `queued` is non-empty, dequeue its oldest member and move it into `visible` (which starts its own independent `duration_ms` countdown from that moment, not from when it was queued — a queued notification's countdown must not run out before the user ever saw it).

**Invariants**:
- `visible.length` never exceeds 3.
- A notification's position in `queued` never causes it to be dropped — every triggered notification is eventually shown (consistent with 007's FR-007, "none are silently lost"), only its appearance may be delayed.
