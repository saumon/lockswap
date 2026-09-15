# Contract: The single breakpoint

**Feature**: 012-responsive-layout-menu | **Requirements**: FR-018, FR-018a, FR-018b

## The value

```
48rem  =  768px
```

One breakpoint governs the whole site. Below it is the **narrow** treatment; at
and above it is the **wide** treatment.

This coincides with Tailwind v4's default `md` breakpoint, so `md:` utilities
and hand-written media queries agree. The codebase writes component CSS in
`@layer components` rather than using utilities in templates, so the normative
form is the media query.

## Authoring rules

- **Narrow-only rules**: `@media (max-width: 47.999rem) { … }`
- **Wide-only rules**: `@media (min-width: 48rem) { … }`
- Mobile-first defaults are preferred: write the narrow case as the base rule
  and add a `min-width: 48rem` block, so a rule that is forgotten degrades to
  the narrow treatment rather than to a broken wide one.
- **No other width value may appear in a media query anywhere in the
  stylesheet.** This is the testable form of FR-018.

## Migration required

`app/assets/tailwind/application.css` currently contains exactly one width-based
media query:

```css
@media (min-width: 40rem) {
  .detail-grid { grid-template-columns: 1fr 1fr; }
}
```

It moves to `48rem` (FR-018a). After this feature, a grep for `min-width:` /
`max-width:` in the stylesheet must return only `48rem` and `47.999rem`.

## Verification

| Assertion | Where |
|---|---|
| 767px yields the narrow treatment | `responsive_test.rb` |
| 768px yields the wide treatment | `responsive_test.rb` |
| No stylesheet media query uses any other width | a grep-style test or a lint step |
| `.detail-grid` switches at 48rem, not 40rem | `responsive_test.rb` |

## Tested viewports

| Name | Size | Purpose |
|---|---|---|
| minimum | 320 × 568 | overflow floor only (FR-022a) |
| phone | 390 × 844 | full narrow-treatment sweep (FR-022) |
| desktop | 1400 × 1400 | full wide-treatment sweep; the suite's existing size |
