# Contract: Flash → Popup Notification Rendering

This is not a network API — it's the internal contract between (a) controllers/Devise, which set Rails flash values, and (b) the shared layout partial + Stimulus controller that render them as popup notifications. Documenting it as a contract ensures new controller code and the rendering component stay decoupled and don't need to change together.

## Producer side (unchanged by this feature)

Any controller action may set:

```ruby
redirect_to some_path, notice: "Human-readable success message."
# or
redirect_to some_path, alert: "Human-readable error message."
```

- **Contract**: Producers set `notice:`/`alert:` exactly as they do today (FR-009 — wording and trigger points unchanged). Producers MUST NOT be modified by this feature beyond what already exists in `app/controllers/*` and Devise's built-in controllers/locale strings.
- Both keys MAY be present simultaneously (e.g. a Devise step followed by a custom redirect); the rendering side MUST handle zero, one, or both being present.

## Consumer side (this feature's scope)

`app/views/layouts/_flash.html.erb`, rendered once per page load from `app/views/layouts/application.html.erb`, reads `notice` / `alert` and for each present value renders one notification element with:

| Attribute | Value | Purpose |
|---|---|---|
| `role` | `"status"` for notice, `"alert"` for alert | Preserves existing accessible semantics and existing test selectors (`[role=alert]`). |
| `data-controller` | `"notification"` | Binds the Stimulus controller (Decision 1, research.md). |
| `data-notification-duration-value` | `"3000"` | Auto-dismiss delay in ms (FR-003); constant across all messages. |
| Visible text | The flash string, unmodified | FR-009 — no truncation, must wrap for long text (Edge Cases). |
| Manual dismiss control | A button/element the Stimulus controller listens on | FR-004. |

**Behavioral contract the Stimulus controller MUST implement** (see data-model.md for the full state machine):

1. On connect: start a 3000ms countdown.
2. On `mouseenter`/`focusin`: pause the countdown (preserve remaining time).
3. On `mouseleave`/`focusout`: resume the countdown from the preserved remaining time.
4. On countdown reaching 0, OR manual dismiss control activated: remove the element from the DOM entirely (not `hidden`/`display:none`).
5. Multiple notification elements present at once operate independently (FR-007) — no shared/global timer.

**Non-goals / explicitly out of contract**:
- No JSON/HTTP API is introduced — this is server-rendered HTML only.
- No no-JS fallback path (spec Clarifications) — the consumer side may assume JavaScript executes.
- No persistence or notification history — dismissed means removed, permanently, for that page load.
