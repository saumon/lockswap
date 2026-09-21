# Contract: entering the locker wishes screen

The interface this feature exposes is a **UI contract** — two HTTP endpoints and
the markup one of them renders. There is no API, no JSON, no external consumer.
What follows is the whole surface; anything not stated here is unchanged from
today.

---

## 1. `GET /locker_wish/new` — new

**Route** (`config/routes.rb`): `:new` added to the existing
`resource :locker_wish`. Helper: `new_locker_wish_path`. Controller:
`LockerWishesController#new` — a singular `resource :locker_wish` already routes
to the plural controller, so the class's existing
`before_action :authenticate_user!` covers this action with no further wiring.

**Meaning.** "I intend to declare a locker search." It is a navigation, not a
write: it creates nothing. It exists so that an intention can be recorded
without appearing in the address the person ends on.

| | |
|---|---|
| **Authentication** | Required. An anonymous request is redirected to sign-in by the existing `before_action`. |
| **Parameters** | None. Any supplied are ignored. |
| **Side effect** | Sets `flash[:open_wish_form] = true`. Nothing else. No query beyond the session load. |
| **Response** | `302` to `locker_wishes_path` — the bare path, with no query string. |
| **Idempotent** | Yes in the sense that matters: repeating it yields the same screen and stores no record. It does write the session flash, which is why it is not cacheable. |

**The redirect target is part of the contract.** It must be `locker_wishes_path`
with nothing appended. A query string here would put the intention, or anything
else, into the address that the person can copy, bookmark and share — which is
what FR-003 forbids, and what the whole redirect exists to prevent.

### After sign-in

Devise stores the attempted GET location, so an anonymous request to this path
signs the person in and then runs the action, arriving with the form open. The
spec permits this without requiring it (Edge Cases, "Reaching the screen while
signed out"); it falls out of the existing `before_action` rather than being
built.

---

## 2. `GET /locker_wishes` — index

Unchanged in every respect except one instance variable.

**Added.**

```ruby
@open_wish_form = flash[:open_wish_form].present?
```

Read once, in the controller, rather than reaching into `flash` from the view.
It is the raw fact — *this arrival asked for the declare form* — with no
`persisted?` guard folded in; where the fact applies is the view's decision
(research R6).

**Unchanged, and asserted to be unchanged.** The floor filters (017), the
`current_floor` derivation (019), the match tag (018), the wish list, the query
counts, and the `turbo-cache-control: no-cache` meta. FR-011 and SC-006 are about
this paragraph.

---

## 3. Rendered markup contract

### 3.1 The declare disclosure — `_locker_wish_panel.html.erb`, `else` branch

```erb
<details <%= "open" if @open_wish_form || @locker_wish.errors.any? %>>
  <summary class="disclosure-summary"><%= t(".looking_for_a_locker") %></summary>
  <div class="disclosure-body">
    <%= render "locker_wishes/locker_wish_form", autofocus: @open_wish_form %>
  </div>
</details>
```

| Guarantee | Requirement |
|---|---|
| `open` present when the arrival carried the intention | FR-004 |
| `open` present on a rejected submission, as today | FR-010 |
| `open` absent otherwise — menu, typed address, bookmark, reload, Back | FR-006, FR-002 |
| Same summary, same body, same form as a hand-opened disclosure | FR-007 |
| Still operable by pointer and keyboard after arrival | FR-009 — native `<details>`, nothing added to interfere |

The `errors.any?` half is existing behaviour and is preserved verbatim; only the
`@open_wish_form ||` is new.

### 3.2 The persisted branch — unchanged

The nested "Change floor" `<details>` keeps `open` if `@locker_wish.errors.any?`
and nothing else, and its `render` passes `autofocus: false`. FR-008 is enforced
here by structure: the disclosure that FR-004 opens does not exist in this
branch.

### 3.3 The floor field — `_locker_wish_form.html.erb`

Declared with strict locals so the partial states its own interface:

```erb
<%# locals: (autofocus: false) %>
```

and on the field:

```erb
<%= f.text_field :floor, autofocus: autofocus, autocomplete: "off",
      aria: { describedby: "locker_wish_floor_hint" }, class: "field-input" %>
```

| Guarantee | Requirement |
|---|---|
| The attribute is rendered only when the arrival carried the intention | FR-005 |
| Rails omits a boolean attribute entirely when false, so nothing is emitted otherwise | FR-006 |
| The existing `<label>` and `aria-describedby` hint are untouched, so focus is announced with both | SC-004 |
| Behaviour is identical at every viewport width — no media query, no touch branch | FR-015 |

**Load-bearing constraint, restated here because this is where it is violated.**
`open` and `autofocus` must be emitted by the **same server response**.
turbo-rails 2.0.23 picks the autofocusable element with a filter that excludes
anything matching `details:not([open])` (research R3), and native browser
autofocus behaves the same way. Opening the disclosure from script after render
leaves the field permanently unfocused, with no error anywhere.

### 3.4 The two homepage invitations — `home/_locker_wish.html.erb`

```erb
<%= link_to t(".switch_locker"),  new_locker_wish_path, class: "btn btn-primary btn-arrow" %>
<%= link_to t(".want_a_locker"),  new_locker_wish_path, class: "btn btn-primary btn-arrow" %>
```

| Guarantee | Requirement |
|---|---|
| Still `link_to`, not `button_to` — a navigation announced as a link, Back behaves (010's stated reason) | FR-009 |
| Both carry the same intention; neither is distinguished from the other | spec Assumptions |
| The third block state, "See my locker searches! 🥷", keeps `locker_wishes_path` | FR-008 |
| Same text, same classes, same count of controls per state | FR-007, and 010's "exactly one control and no form" |

---

## 4. What must not appear

A short list, because each of these is a plausible-looking change that breaks a
stated requirement:

- **No query parameter or fragment** carrying the intention — FR-003.
- **`:open_wish_form` must not be added to `add_flash_types`.** That helper exists
  to let `redirect_to` take a key as an option; its only effect here would be to
  invite someone to render the key as a message. The flash layer renders `notice`
  and `alert` by name (research R2) and must keep doing so.
- **No JavaScript, no Stimulus controller, no `data-` attribute** for opening the
  disclosure — the `<details>` was chosen precisely to avoid it, and script-driven
  opening breaks focus silently (§3.3).
- **No second form, no second disclosure, no "declare" variant of the panel** —
  FR-007.
- **No new locale key.** If one becomes necessary, both `en.yml` and `fr.yml` get
  it and `test/i18n_completeness_test.rb` enforces the pair — FR-013.
- **No new width in a media query.** This feature introduces no media query at
  all; `test/stylesheet_breakpoint_test.rb` would fail on one anyway.
