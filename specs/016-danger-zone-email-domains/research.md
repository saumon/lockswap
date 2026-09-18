# Phase 0 Research: Danger Zone – Allowed Email Domains

**Feature**: [spec.md](./spec.md) | **Branch**: `016-danger-zone-email-domains` | **Date**: 2026-09-18

Four questions stood between the clarified spec and a design.

## R1 — How the allowed domains are stored

**Decision**: A new table, `allowed_email_domains`, one row per domain — not a single delimited text
column on some settings row.

**Rationale**: The spec's own Key Entities section already names "Allowed Email Domain" as a thing in
its own right, not a formatting detail of a larger blob. A row per domain lets the database do the
work FR-003 and the Edge Cases already ask for in prose — reject a malformed entry, prevent a
functional duplicate — through an ordinary `validates format:` and a unique index, rather than
hand-rolled parsing/splitting/rejoining code run on every save. Removing one domain (FR-003) is then a
single `DELETE`, not a rewrite of an entire text field.

**Alternatives considered**:

- *A single text column, comma- or newline-separated, on a singleton settings row.* Rejected: every
  add or remove would need to parse the whole field, re-validate every entry, and rejoin it, duplicating
  what a table + index already give for free — and there is nothing else this "settings row" would hold,
  so it would exist only to carry one field.
- *A generic `key/value` `Setting` table holding a JSON array under one key.* Rejected as a layer with
  no other user in this codebase; it would solve a problem ("we might need more settings later") the
  spec does not ask this feature to solve.

## R2 — Where the registration gate runs

**Decision**: A `User` model validation, `validate :email_domain_allowed, on: :create`, added beside
the model's other invariants — not a check added to `RegistrationsController`.

**Rationale**: Every existing cross-cutting rule on this model already lives on `User` itself
(`locker_details_held_by_active_swap`, the last-administrator destroy guard), and Devise's
`registerable` module reaches this the same way any other save does: `RegistrationsController#create`
ultimately calls `resource.save`, so a `User` validation is already on that path with nothing extra to
wire up. Scoping it `on: :create` is what makes FR-010 (existing accounts and other flows untouched)
true by construction rather than by a separate guard someone has to remember to add to every future
`update`.

The refusal is added to `:base`, not `:email`. Devise's `error_messages` partial renders
`resource.errors.full_messages`, which prefixes an attribute-scoped message with the humanized
attribute name (see `LOCKER_NUMBER_TAKEN_MESSAGE`, rendered as "Locker number ..."). The spec requires
the exact sentence "Your email address domain is not allowed" with nothing prepended, which only a
`:base` error produces — the same reason `LAST_ADMINISTRATOR_MESSAGE` is added to `:base` rather than
to an attribute.

**Alternatives considered**:

- *Override `RegistrationsController#create` and check the domain before calling `super`.* Rejected:
  the rule is a fact about what makes a `User` record valid, not about one controller action, and it
  would sit apart from every other invariant this model already enforces on itself.

## R3 — How the screen and the resource it manages are split

**Decision**: `Admin::DangerZoneController#show` (read-only — lists domains, renders the add form) and
a separate `Admin::AllowedEmailDomainsController` with `#create`/`#destroy`, each redirecting back to
`admin_danger_zone_path`. Both guarded by the existing `authenticate_user!` / `require_admin!` pair.

**Rationale**: `Admin::UsersController` carries both the read (`index`) and the write (`grant_admin`)
because the write acts on a row already on that same list — a `User`. Here the thing being mutated,
`AllowedEmailDomain`, is its own resource with its own identity and its own validations, so it gets its
own controller, the same way the site already keeps `locker_wishes` (the list) and `locker_wish` (the
single resource a person acts on) apart. "Danger Zone" stays a screen name, not a resource name —
useful if a second dangerous setting is ever added to it, since that would be one more link on the same
screen rather than a new action bolted onto a controller already named for one setting.

**Alternatives considered**:

- *One controller, `Admin::DangerZoneController`, with `show`/`create`/`destroy`.* Considered and
  rejected: it works for exactly one setting, but blurs the screen/resource line the moment there is a
  second one, and a `resource :danger_zone, only: :show` gaining sibling `create`/`destroy` routes for
  an unrelated model reads as accidental REST rather than intended.

## R4 — Domain matching semantics

**Decision** (confirmed in the Clarifications session): exact match on the domain portion of the
email address, case-insensitive, with no automatic inclusion of subdomains. Implemented by normalizing
both sides before comparison — `AllowedEmailDomain#domain` via `normalizes :domain, with: -> (v) {
v.to_s.strip.downcase }` (the same `normalizes` pattern `User#locker_number` already uses), and the
submitted email's domain portion via `.downcase` — then an exact `Array#include?` check, not a suffix
or regex match.

**Rationale**: A suffix match (`ends_with?(".#{allowed}")` or similar) would silently accept
`evilcompany.com` for an allowed domain `company.com` unless carefully anchored, and would need its own
test suite to prove it never accepts a look-alike domain. Exact match after normalization needs none of
that: the set of allowed strings and the submitted string either match exactly or they do not.

**Alternatives considered**: matching subdomains automatically — rejected by the Clarifications answer;
an administrator who wants a subdomain admitted adds it as its own row.

## R5 — No fixture file for `allowed_email_domains`

**Decision**: Add no `test/fixtures/allowed_email_domains.yml` at all. Any test that needs a
configured domain creates it explicitly inside that test (`AllowedEmailDomain.create!(domain: ...)`)
and relies on Rails' transactional test rollback to remove it afterward.

**Rationale**: `test/test_helper.rb` declares `fixtures :all`, which loads every YAML file under
`test/fixtures/` for **every** test in the suite, unconditionally. A fixture file with even one row
in it would restrict registration to that domain for every existing signup/registration test in the
whole application — most of which register accounts at `@example.com` addresses picked with no
awareness that this feature exists — turning one feature's fixtures into a global, easy-to-miss
regression. Leaving the table empty by fixture load keeps today's "no restriction" behavior the
default for the entire suite, matching production's default, and each test that specifically exercises
a configured allow-list states its own domains inline, right next to the assertion that depends on
them.

**Alternatives considered**: a fixture using the same domains the existing user fixtures already sign
up under (e.g. `example.com`). Rejected: it would still silently gate every future test that registers
an account on a different domain, for a saving of one line (`AllowedEmailDomain.create!(...)`) per
test that actually needs it.
