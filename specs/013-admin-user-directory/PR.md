# 013 — Administrator role and user directory

The first account ever registered becomes the site's administrator, and it alone
gets an **Admin** menu in the signed-in navigation with a **Users** screen behind
it, listing everyone who has registered.

## What changes for users

**Nothing at all, for everybody except one account.** A non-administrator's
navigation is byte-for-byte what it was; the entry is not rendered to them and
the address behind it is refused if they reach it another way.

On an existing deployment the flag is claimed at signup, so a database that
already has accounts ends up with **no administrator** — nobody signed up first
*after* this shipped. That is deliberate rather than an oversight (FR-011 rules
out handing the role to an incumbent), but it means an existing instance needs
the flag set once by hand:

```sh
bin/rails runner 'User.order(:created_at).first.update!(admin: true)'
```

An ordinary `update!` is enough: the callback that claims the flag is
`before_create`, so it has no say over an existing row. The index still does —
run this twice on two different accounts and the second is refused, which is the
intended answer.

## Core Principles

**I. Code Quality** — `bin/rubocop` clean, zero suppressions. The feature adds
one column, one callback, one rescue, one guard method, one controller and one
view; there is no policy object, no role table and no authorization gem, because
there is exactly one role and one check. `require_admin!` sits on
`ApplicationController` rather than on the single controller using it today, so
the next administrator-only destination does not re-derive the site's rule for
what "administrator-only" means.

**II. Testing Standards** — unit and controller tests **105 → 124** (+19);
system tests **176 → 190** (+14). Every one of them fails without this branch.
The coverage that matters most is the part that is easy to get wrong and
impossible to see: the flag is claimed under a partial unique index, and the
race is tested rather than reasoned about — a signup that loses it still gets an
account, just not the flag. Access control is tested at the HTTP layer, not by
looking for the absence of a link, because a hidden link is not a control.
Signup is tested through Devise's own path, including a request that asks for
`admin: true` in its parameters and does not get it.

**III. User Experience Consistency** — reuses the site's existing parts rather
than adding new ones: the `<details>` disclosure (the menu itself, the locker
editor, the wish panel, the decline form), `.data-table` with `data-label` for
the phone/desktop restack, `.badge` for the Admin label, the `.site-nav-link`
styling for the submenu's rows, and the flash `:alert` that 007 already uses for
a refusal. The one new shape is the submenu's caret, which is the same caret
`.disclosure-summary` already draws. The new screen joins the existing per-screen
accessibility audit and the phone/desktop sweep rather than sitting outside them,
and the open Admin menu is audited in both treatments — a state that exists on
one account's pages and would otherwise never be looked at.

**IV. Performance** — no change to any request path anybody else travels. The
directory is a single `User.order(:created_at)` with no per-row query; the Admin
label is read from the column already loaded with the row. The one added cost on
an existing path is a `User.exists?` on signup, which runs once per account ever
created.

*Recorded exception:* the directory is **not paginated**, though the account
count grows without bound in principle. Principle IV asks for pagination,
batching or streaming wherever a result set can; the spec's Assumptions section
defers it deliberately for a single company's employee list on a screen only the
administrator opens, and `plan.md`'s Constitution Check records the deferral.
Flagging it here is the rest of that obligation — Governance allows a gate to be
bypassed only by an explicit written exception recorded in the pull request, and
this is it. The fallback if the count ever matters is plain `limit`/`offset`; no
gem is needed.

## Verification gap in this branch

The system tests **were not executed**. Chrome cannot start in the environment
this branch was written in — `libnspr4.so` is missing for both the browser and
chromedriver, and installing it needs a root password — so the entire system
suite errors at browser startup, including tests this branch never touched. The
190 system tests here are written and committed but unrun; **CI is the first
place they will actually execute.**

What *was* run: the full unit and controller suite (124 tests, green),
`bin/rubocop` (clean), and `bin/brakeman` (0 warnings). To keep the browser gap
from hiding a broken screen, the markup those system tests assert on — the
submenu in both menu containers, its absence for everyone else, the directory's
rows, order and label — was additionally asserted at the rendering layer, where
it runs without a browser. What remains genuinely unverified is the part only a
browser can answer: that the CSS lays the submenu out as intended, that the
`<details>` opens on a click, and the axe audits.

## Reviewer's attention is best spent on

- `app/models/user.rb` — the unconditional `self.admin = !User.exists?`, and the
  `save` override that rescues only this index's conflict and retries exactly
  once.
- `db/migrate/20260917181212_add_admin_to_users.rb` — the partial unique index is
  what actually enforces "one administrator"; the callback is only the fast path.
- The migration note above: this ships an instance with no administrator until
  somebody sets the flag.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01G1qWC3mtmMYDzyM6uUTXHg
