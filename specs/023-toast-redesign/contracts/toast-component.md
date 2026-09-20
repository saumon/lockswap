# Contract: Toast Notification Component

This is the internal UI contract other code already depends on and must keep working: `test/system/notification_test.rb`, every controller/view that triggers a flash (sign-in, sign-up, locker profile, swap proposals, etc.), and this feature's own new tests. It documents selectors and attributes, not visual values (those are implementation detail resolved in Phase 2 tasks).

## DOM structure (per notification)

```html
<div class="toast-layer" data-controller="toast-layer">        <!-- container: fixed, bottom-right, cap-aware -->
  <div class="toast toast-success"                              <!-- or toast-error -->
       role="status"                                             <!-- or role="alert" for error -->
       data-controller="notification"
       data-notification-duration-value="<ms>"
       data-action="mouseenter->notification#pause
                    mouseleave->notification#resume
                    focusin->notification#pause
                    focusout->notification#resume">
    <svg class="toast-icon" aria-hidden="true">...</svg>         <!-- NEW: decorative type icon -->
    <span class="min-w-0 flex-1 break-words"><!-- message text --></span>
    <button type="button"
            aria-label="Dismiss notification"
            data-action="notification#dismiss"
            class="toast-dismiss">&times;</button>
  </div>
</div>
```

## Selectors and attributes that MUST remain stable

These are asserted directly by existing and planned tests; changing them is a breaking change to this contract.

| Selector / attribute | Meaning | Consumer |
|---|---|---|
| `[role=status]` | A success/informational notification is present | `notification_test.rb` (existing) |
| `[role=alert]` | An error notification is present | `notification_test.rb` (existing) |
| `.toast-success`, `.toast-error` | Type-specific styling hook | CSS, tests |
| `button[aria-label='Dismiss notification']` | The manual-dismiss control | `notification_test.rb` (existing) |
| `data-controller="notification"` + `data-notification-duration-value` | Per-toast countdown wiring | `notification_controller.js` (unchanged) |
| computed `border-left-color` on `.toast-success` / `.toast-error` | Visually distinguishes type without reading text | `notification_test.rb` (existing) — value stays `--color-status-success` / `--color-status-error` (research.md §3) |
| `main` element's bounding rect | Must be identical whether or not a notification is showing | `notification_test.rb` (existing) |

## New in this feature

| Selector / attribute | Meaning | Consumer |
|---|---|---|
| `.toast-icon` (`svg[aria-hidden=true]`) | Decorative type glyph, never the sole signal | New tests (icon present per type) |
| `data-controller="toast-layer"` on `.toast-layer` | Mediates the visible-count cap and reveal queue | New tests (FR-010: 4th+ notification queued, shown once a slot frees) |
| `.toast-layer` positioning | `position: fixed`, bottom-right of viewport, no longer coupled to `--size-bar` | New tests (placement), replaces the current `position: sticky` + header-offset approach |
| `.toast` entrance/exit transition | Fade + small rise, `transform`/`opacity` only, reversed on exit; `notification_controller.js#dismiss` waits for it before removing the element | New tests (FR-004/SC-006 timing); `toast_layer_controller.js` (below) |
| A dispatched event on toast removal (name TBD at implementation, e.g. `notification:dismissed`) | Tells `toast_layer_controller.js` a visible slot just freed, so it can promote the oldest `queued` toast | `toast_layer_controller.js`'s cap/queue logic (FR-010) — internal to this feature, not asserted by other views |

## Explicitly NOT part of this contract

- Exact pixel values (padding, radius, shadow, icon glyph paths) — implementation detail for Phase 2 tasks, not asserted by tests beyond "an icon element exists" and "the accent color is the correct status token."
- The specific queue cap number (3) is a behavioral contract (data-model.md) but not a DOM contract — tests assert "a 4th notification is not visible until a slot frees," not the literal number.
