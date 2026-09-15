# Contract: Data list table ⇄ card forms

**Feature**: 012-responsive-layout-menu | **Requirements**: FR-005, FR-005a–e, FR-020

Applies to the two data lists:

- `app/views/locker_wishes/_locker_wish_list.html.erb` — 5 columns
- `app/views/locker_swap_proposals/index.html.erb` — 6 columns

## Markup contract

One `<table>`, rendered once. Two visual forms selected by CSS.

```html
<table class="data-table" role="table">
  <thead>
    <tr role="row">
      <th scope="col" role="columnheader">Looking for floor</th>
      …
    </tr>
  </thead>
  <tbody>
    <tr role="row" id="locker-wish-row-7">
      <td role="cell" data-label="Looking for floor">3</td>
      <td role="cell" data-label="Person">bob@example.com</td>
      …
    </tr>
  </tbody>
</table>
```

Required of every `<td>`:

- a `data-label` whose value is **exactly** the text of its column's `<th>`
- an explicit `role="cell"`

Required of every `<tr>`: `role="row"`. Of every `<th>`:
`role="columnheader"`. Of the `<table>`: `role="table"`.

The explicit roles exist because flipping `display` to block drops the implicit
table roles; restating them keeps the accessibility tree correct in both forms
(FR-005d). Above the breakpoint they duplicate what the native element already
provides, which is harmless.

## Existing ids are preserved

Both templates already carry ids that tests assert against —
`locker-wish-row-#{user_id}`, `#{row_id}-status`, `#{row_id}-comment`,
`#{row_id}-locker-details`, `#{row_id}-swap`. **None may change.** They must
resolve to the same content in both forms.

## Visual contract

| | Wide (≥ 48rem) | Narrow (< 48rem) |
|---|---|---|
| `thead` | visible header row | visually hidden, still in the accessibility tree |
| `tr` | table row | a card surface: own background, border, radius, spacing |
| `td` | table cell | a labelled line — label from `data-label`, then the value |
| row action | last cell | a line in the card, reachable with no horizontal scrolling |
| `.table-scroll` | keeps `overflow-x: auto` | no horizontal scrolling occurs; the card form never exceeds the width |

The header is hidden with the clip-path technique, not `display: none` — the
`<th>` cells must stay available to anything walking the table.

## Invariants

1. **No data loss** — every column present in the wide form appears in the
   narrow form (FR-005a).
2. **Same order** — record order and within-record field order are identical,
   which is automatic: there is one markup order (FR-005c).
3. **Action always visible** — "Propose swap", "This is you", "Proposal
   pending", "exchange in progress" and the status badge are all reachable
   without a sideways swipe (FR-005b, SC-004a).
4. **Empty states identical** — `#locker-wish-list-empty` and
   `#swap-proposal-history-empty` render the same text in both forms (FR-005e).
5. **Desktop unchanged** — apart from the added attributes, the wide rendering
   is byte-for-byte the current one (FR-020).

## Verification

| Assertion | Where |
|---|---|
| Card form at 390px, table form at 1400px | `responsive_test.rb` |
| Every `td` has a `data-label` matching its `th` | `responsive_test.rb` |
| "Propose swap" is within the viewport at 390px | `responsive_test.rb` |
| axe clean on both list screens at 390px | `accessibility_test.rb` (**the R2 gate**) |
| Existing row-id assertions still pass | existing `locker_wish_test.rb`, `locker_swap_proposal_test.rb` |

If the axe gate fails, adopt the [R2 fallback](../research.md#r2--restacking-the-two-tables-as-cards-without-losing-table-semantics):
a second CSS-exclusive `<ul>`/`<dl>` card rendering.
