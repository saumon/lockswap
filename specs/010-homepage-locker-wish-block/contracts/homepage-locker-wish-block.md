# UI Contract: Homepage Locker Wish Block

**Feature**: [spec.md](../spec.md) | **Date**: 2026-09-15

This feature exposes no new HTTP endpoint. Its contract is what the homepage renders and
where that rendering leads — the surface tests assert against and the one existing
endpoint it depends on.

## Depended-on endpoint (existing, unchanged)

`GET /locker_wishes` → `LockerWishesController#index`, named route `locker_wishes_path`.
Requires an authenticated user (003 FR-013). This feature adds no parameter to it and
changes none of its behaviour.

## Rendered contract

Rendered on `GET /` (and on the `home/index` re-render that
`LockerProfilesController#update` returns with `422` after a rejected locker edit), for an
authenticated user whose locker details are on file.

### Placement

The block is a direct child of the homepage stack, positioned **after** every swap-proposal
section and **immediately before** the `#locker-profile` card (FR-012). It is absent from
the document entirely — not hidden — when the user has no saved locker details (FR-001a).

### Structure

| Element | Selector | Present in |
|---------|----------|------------|
| Block container | `#home-locker-wish` | All three states |
| Heading | `#home-locker-wish h2.card-title` | All three states — text differs per state, see below |
| Floor sought | `#home-locker-wish-floor` | Declared-wish state only |
| Control | `#home-locker-wish a.btn` | All three states |

### States

| State | Heading | Body | Control text | `href` |
|-------|---------|------|--------------|--------|
| Declared wish | `Your locker search` | Labelled floor value in `#home-locker-wish-floor` | `Review locker wishes! 🥷` | `/locker_wishes` |
| Has a locker, no wish | `Looking for a different locker?` | One line inviting a swap, no wish values | `I want to switch my locker! 👀` | `/locker_wishes` |
| No locker, no wish | `Looking for a locker?` | One line inviting a request, no wish values | `I want a locker! 🙏` | `/locker_wishes` |

The wish state deliberately repeats the heading the wish page's own panel carries
(`app/views/locker_wishes/_locker_wish_panel.html.erb`): the same card title for the same
thing on both screens is continuity, not accidental duplication. The two invitation states
take their own headings because no search exists yet for them to be "your" anything — each
is a question its button answers.

Control labels are exact, emoji included; they are the assertion targets and must not be
reworded without changing the spec.

### Invariants

- Exactly one control is rendered — never zero, never two (SC-002).
- The block contains no `<form>` in any state (FR-009).
- `#home-locker-wish-floor` exists **only** in the declared-wish state; the invitation
  states render no wish values at all (FR-004, FR-005).
- The block never renders another user's wish or email (FR-008).
- The block renders no form and no submit control: it cannot declare, change or cancel a
  wish (FR-009).
- The control is an `<a>` (a navigation, not a mutation), reachable by keyboard with its
  label as its accessible name (FR-010).
- The rendered state is independent of any active swap proposal (FR-013).
- The whole block is absent for a signed-out visitor, because the homepage is (FR-008).

### Accessibility

Audited by `assert_axe_clean` on the homepage as part of the standard suite (008 FR-028),
under WCAG 2.0/2.1 A and AA. No rule skips and no exemption are permitted for this block.
