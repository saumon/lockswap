# Phase 1 Data Model: Auto-Dismissing Popup Notifications

This feature has no persisted data — no new database table, model, or migration. The only "entity" is a client-side, ephemeral concept that exists purely in the rendered page and browser state for the duration of one page load.

## Popup Notification (client-side, non-persisted)

Represents one message currently shown to the user, sourced from the Rails `flash` hash already set by controllers/Devise.

| Field | Type | Source | Notes |
|---|---|---|---|
| `text` | string | `flash[:notice]` or `flash[:alert]` | Wording unchanged from today (FR-009); rendered as-is, no truncation (must wrap per Edge Cases). |
| `type` | enum: `success` \| `error` | Derived from which flash key it came from (`notice` → `success`, `alert` → `error`) | Drives styling (emerald vs rose, unchanged from today) and ARIA role (`status` vs `alert`). |
| `duration_ms` | integer, `3000` as shipped | Fixed by spec (FR-003); held in `config.x.notification_auto_dismiss_ms` | Not configurable per-message; uniform across success and error. Environment-level only: the test environment shortens it so the suite need not wait out real seconds, and a test pins the shipped value at 3000. |
| `remaining_ms` | integer, runtime-only | Computed by the Stimulus controller | Decrements while visible; frozen while paused (hover/focus); drives the resume timeout. |
| `state` | enum: `visible` \| `paused` \| `dismissed` | Runtime-only, owned by the Stimulus controller | `dismissed` triggers DOM removal (Decision 3 in research.md), not merely hiding. |

### Lifecycle / state transitions

```
(page loads with flash present)
        │
        ▼
   ┌─────────┐   mouseenter / focusin    ┌────────┐
   │ visible │ ───────────────────────▶ │ paused │
   └─────────┘ ◀─────────────────────── └────────┘
        │           mouseleave / focusout
        │ timer reaches 0  OR  manual dismiss click
        ▼
   ┌───────────┐
   │ dismissed │  → element removed from DOM
   └───────────┘
```

- Entry: one `visible` instance is created per non-empty `flash[:notice]` and per non-empty `flash[:alert]` present on the rendered page (at most two per page load in current usage; the stack supports any number per FR-007).
- `visible` → `paused`: on hover or keyboard focus; remaining time is preserved, not reset.
- `paused` → `visible`: on mouse-leave or blur; countdown resumes from the preserved remaining time.
- `visible` → `dismissed`: when `remaining_ms` reaches 0, or the user clicks the manual dismiss control (from either `visible` or `paused`).
- `dismissed` is terminal — the element is removed from the DOM; there is no history/log (per spec Assumptions).

### Relationships

None — each Popup Notification is independent; multiple instances only share the same fixed-position stacking container in the DOM.

### Validation rules

- A notification is only rendered when its source flash value is present (non-blank) — this is unchanged from the current `_flash.html.erb` behavior (`if notice.present?` / `if alert.present?`).
- `type` is fully determined by source key; there is no user- or controller-supplied override.
