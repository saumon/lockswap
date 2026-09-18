# 016 — Danger Zone: allowed email domains

A new administrator-only screen, **Admin → Danger Zone**, where an administrator
lists the email domains that may create an account. With the list empty — which is
how every existing deployment starts — registration is open to any domain, exactly
as it is today. With one or more domains listed, a signup from anywhere else is
refused with "Your email address domain is not allowed".

## What changes for users

For anyone who is not an administrator, nothing: the screen is not in their
navigation and the addresses behind it are refused.

For an administrator, one new entry in the Admin submenu beside "Users". On the
screen: the current list, a field to add a domain, and a Remove control per row.

**Nothing changes on an existing deployment until somebody adds a domain.** The
migration only adds an empty table, and an empty table is the absence of a
restriction rather than a restriction of zero domains — so this feature is inert
until it is deliberately switched on, and removing the last domain switches it off
again.

Two behaviours worth stating plainly, because both were decisions rather than
defaults:

- **Existing accounts are never re-judged.** Configuring a domain does not lock out
  the people already registered — they sign in, reset passwords and edit their
  details exactly as before (FR-010).
- **Subdomains are not included.** `company.com` admits `company.com` and nothing
  else; `mail.company.com` must be listed in its own right. Settled in the
  clarification session, and the reason the check is an exact comparison rather
  than a suffix test — a suffix test admits `evilcompany.com` unless very
  carefully anchored.

## Core Principles

**I. Code Quality.** The screen and the resource it manages are separate:
`Admin::DangerZoneController#show` reads, `Admin::AllowedEmailDomainsController`
writes (`#create`, `#destroy`). "Danger Zone" is the name of a screen, not of a
setting, so a second dangerous setting later is one more section rather than a
controller named after the wrong thing. There is no `#update` — changing a domain
is remove-then-add, which leaves no half-edited state to validate. The signup gate
is one named `User` validation beside the model's other invariants, not a special
case bolted onto `RegistrationsController`. RuboCop: 80 files, no offenses.
Brakeman: 0 warnings.

**II. Testing Standards.** 155 runs / 587 assertions before, **204 runs / 768
assertions** after for `bin/rails test`; 214 / 1004 before, **230 runs / 1088
assertions** after for `bin/rails test:system`. 65 new tests, each written before
the code it constrains — the model tests were watched failing on a missing
constant, and the two controller tests on a missing controller, before either
existed. The split is deliberate: the refusals and the already-removed-domain case
are controller tests because no browser can reach them; the confirmation text, the
accessible names and the empty state are system tests because no request test can
see them.

**III. User Experience Consistency.** No new UI pattern. The screen reuses the
card/table/`data-label` markup from Admin → Users (so it restacks into labelled
cards below the breakpoint like every other table), the `field`/`field-label`/
`field-input` form vocabulary from the locker-profile form, and the existing
`devise/shared/error_messages` component for a refused entry. The Remove control
is the same `button_to` + `data-turbo-confirm`/`data-confirm` construction as
"Grant admin rights", because it is the same class of act: one click, immediate
effect on who may join the site. Both the accessibility and responsive sweeps
gained coverage — the screen is audited in three states (empty, populated, showing
a refused entry), and each Remove control's accessible name is asserted to name
its domain rather than rely on row position, which axe cannot check.

**IV. Performance Requirements.** No swap or lock path is touched. The signup
check is a single `AllowedEmailDomain.pluck(:domain)` followed by an in-memory
comparison — one query, against a table whose size an administrator sets and which
does not grow with the number of people registering. It is deliberately not an
`exists?` per candidate domain, and deliberately not a `LIKE`. The Danger Zone
listing is one ordered query with no per-row association read.

## Decisions a reviewer should check rather than assume

**No fixture file for the new table, on purpose.** `test/test_helper.rb` declares
`fixtures :all`, which loads every YAML file under `test/fixtures/` for every test
in the suite. A fixture here with even one row would have restricted registration
**site-wide in the test suite** — including in the several dozen existing tests
that sign accounts up at `@example.com` without any knowledge of this feature. The
table is therefore left empty by fixture load, which also matches production's
default, and the tests that need a configured domain create it inline. Reasoning
at `research.md` R5. This is the single most likely thing for a later change to get
wrong.

**The error is added to `:base`, not `:email`.** The spec fixes the sentence
exactly. `full_messages` prefixes an attribute-scoped message with the humanized
attribute name, which would render it as "Email Your email address domain is not
allowed" — so `:base` is what produces the required text, the same reason
`LAST_ADMINISTRATOR_MESSAGE` is on `:base`.

**`validate :email_domain_allowed, on: :create`.** The `on: :create` scope is what
makes FR-010 true by construction rather than by a second guard somebody has to
remember to add to every future `update`. A blanket validation would lock out
every existing account the moment a domain was configured. Pinned by tests that
save and re-password an existing account on a now-disallowed domain.

**`resource :danger_zone, only: :show, controller: "danger_zone"`.** A singular
`resource` otherwise routes to a pluralized `DangerZonesController`, and there is
only ever one danger zone. Found by a failing test, not by inspection.

## Deviations from the plan, recorded

- The format-validation message is `"must look like company.com"`, where
  `data-model.md` proposed `"must be a domain, like company.com"`. `full_messages`
  renders the latter as "Domain must be a domain, like company.com", which reads
  badly for a message a person is meant to act on (Principle III).
- `spec.md` and `data-model.md` each gained one clarifying line during
  `/speckit-analyze`: the Assumptions bullet now states that domains are added and
  removed one at a time rather than batch-saved, and `data-model.md` names the
  table as the spec's "Danger Zone Configuration" entity. Both were documentation
  gaps, not behaviour changes.

## Verification

Both suites pass in full on this branch: **204 runs / 768 assertions** for
`bin/rails test`, **230 runs / 1088 assertions** for `bin/rails test:system`.
RuboCop and Brakeman are clean.

One **pre-existing flake**, unrelated to this branch and worth not mis-attributing:
`AdminUsersTest#test_a_granted_administrator_reaches_the_screen_and_can_grant_rights_onwards`
and `NavigationTest#test_a_granted_administrator's_navigation_carries_the_same_Admin_menu`
both fail intermittently — reliably when run in isolation on this machine, usually
passing in a full-suite run. Both were verified failing **3 out of 3 times at
`HEAD` in a clean worktree**, with none of this branch's code present, so the extra
link in the Admin submenu is not the cause. They involve the granted-administrator
fixture and the desktop submenu click.

`bin/ci` does **not** run system tests (`config/ci.rb:16` is commented out), so a
green `bin/ci` is not by itself evidence for this branch;
`.github/workflows/ci.yml:122` does run them.

## Reviewer's attention is best spent on

**`app/models/user.rb`, `#email_domain_allowed`.** Three things are load-bearing in
five lines: the empty-list early return (FR-004 — the absence of a restriction, not
a restriction of nothing), the exact `include?` rather than any suffix match
(FR-007 and the subdomain clarification), and `on: :create` on the validation
declaration (FR-010). Each is covered by a test, but each is also the kind of line
a later edit could "simplify" without any visible symptom until somebody cannot
register.

**`app/controllers/admin/allowed_email_domains_controller.rb`, `#create`'s failure
branch.** It reloads `@allowed_email_domains` before re-rendering the Danger Zone
view, because that action never ran `#show`. Without it, a rejected addition comes
back with the existing configuration missing from the page — which reads as the
failed entry having wiped the list. Covered by a test that asserts the existing
domain is still on screen after a refusal.
