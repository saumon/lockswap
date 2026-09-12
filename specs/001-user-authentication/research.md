# Phase 0 Research: User Signup and Login

All Technical Context values were mandated directly by the stakeholder (see plan.md), so there are
no open `NEEDS CLARIFICATION` items to resolve. This document instead records the rationale and
alternatives considered for how each mandated technology is applied to satisfy the feature spec's
functional requirements.

## Framework & language

- **Decision**: Ruby on Rails 8.1.3 on Ruby 3.4.6.
- **Rationale**: Explicitly mandated by the stakeholder for this project.
- **Alternatives considered**: None — version and framework are fixed constraints, not open
  choices.

## Authentication: Devise

- **Decision**: Use the Devise gem on the `User` model with modules `:database_authenticatable`,
  `:registerable`, `:rememberable`, `:lockable`, and `:timeoutable`.
- **Rationale**: Devise is the mandated authentication library and is the de facto Rails standard.
  Its modules map directly onto the spec's functional requirements without custom security code:
  - `:database_authenticatable` → bcrypt password hashing + email/password login (FR-004, FR-006).
  - `:registerable` → self-service signup (FR-001, FR-003 uniqueness validation built in).
  - `:rememberable` → persistent session across browser restarts (FR-007).
  - `:lockable` → automatic lockout after N failed attempts with a timed unlock (FR-011).
  - `:timeoutable` is available for future inactivity-based expiry but is not required by the
    spec's 30-day "or explicit logout" model; included for completeness but not configured with an
    aggressive timeout (see Session configuration below).
- **Alternatives considered**: Rails 8's built-in `has_secure_password` + a hand-rolled sessions
  controller (rejected — would require re-implementing remember-me cookies, lockout counters, and
  timed unlocks that Devise already provides and has battle-tested); Sorcery gem (rejected — smaller
  ecosystem, and Devise was explicitly mandated).

## Password policy (FR-002)

- **Decision**: Set `config.password_length = 8..128` in `config/initializers/devise.rb`.
- **Rationale**: Devise's `:validatable` module already enforces a configurable length range and
  email format; this directly satisfies FR-002's 8-character minimum with no custom validation code.
- **Alternatives considered**: Custom `validates :password, length: { minimum: 8 }` on `User`
  (rejected — duplicates what Devise's own configuration already covers, and could drift out of
  sync with Devise's registration flow).

## Session duration (FR-007)

- **Decision**: Configure Devise's `:rememberable` module with `config.remember_for = 30.days`, and
  issue the remember-me cookie automatically on every successful login (not conditional on a
  "remember me" checkbox), since the spec calls for a blanket 30-day persistent session rather than
  an opt-in feature.
- **Rationale**: Matches Acceptance Scenario 2 of User Story 2 exactly — the session must survive
  browser restarts for up to 30 days without extra user action.
- **Alternatives considered**: Plain Rails session cookie with a 30-day `expire_after` on the
  session store (rejected — a plain session cookie is lost on browser close by default and would
  require additional custom persistence logic that `:rememberable` already provides securely).

## Account lockout (FR-011, SC-006, Edge Case: cooldown reset)

- **Decision**: Configure Devise's `:lockable` module with `config.lock_strategy = :failed_attempts`,
  `config.maximum_attempts = 5`, `config.unlock_strategy = :time`, `config.unlock_in = 15.minutes`.
- **Rationale**: Directly matches the clarified thresholds (5 consecutive failures → 15-minute
  cooldown). Devise automatically resets the failed-attempts counter on a successful login and
  automatically permits login again once `unlock_in` has elapsed, satisfying the edge case without
  extra code.
- **Alternatives considered**: `:email` unlock strategy requiring the user to click a link (rejected
  — spec calls for a time-based cooldown, not a manual unlock action); a custom Rack::Attack-based
  IP throttle (rejected — spec's requirement is per-account, not per-IP; Rack::Attack could be added
  later as a complementary defense but is out of scope for this feature).

## Storage: SQLite via Active Record

- **Decision**: Use Rails 8's default SQLite3 adapter for the `users` table.
- **Rationale**: Explicitly mandated. Rails 8 treats SQLite as production-viable for single-server
  monoliths (its own Solid Cache/Queue/Cable defaults already run on SQLite), which fits a small
  monolithic deployment via Kamal with a persistent volume for the database file.
- **Alternatives considered**: PostgreSQL (rejected — not requested, and adds infrastructure not
  needed at this project's current scale).

## Styling: Tailwind CSS v4.3

- **Decision**: Integrate Tailwind via the `tailwindcss-rails` gem, which packages Tailwind v4's
  Rust-based CLI as a Ruby gem, rather than `cssbundling-rails` with a Node-based toolchain.
- **Rationale**: Avoids adding a Node.js/npm runtime dependency to the Docker image purely for CSS
  compilation, keeping the deployment footprint minimal and consistent with a monolithic Ruby app
  deployed via Kamal.
- **Alternatives considered**: `cssbundling-rails` + Node-installed Tailwind CLI (rejected — extra
  Node runtime in the Docker image with no functional benefit at this project's scale); plain CDN
  Tailwind (rejected — not suitable for production, no build-time purging/optimization).

## Testing strategy

- **Decision**: Minitest with fixtures for model-level tests (`test/models/user_test.rb`) and Rails
  system tests (Capybara, headless-Chrome driver, both bundled by default in a Rails 8 app) for the
  end-to-end acceptance scenarios (signup, login → homepage redirect, wrong-password error, 5-failed
  -attempt lockout, unauthenticated homepage redirect).
- **Rationale**: Satisfies the constitution's Testing Standards principle (automated tests for every
  functional requirement, CI-gated) using only what a default Rails 8 app already includes — no new
  test dependency needs to be introduced.
- **Alternatives considered**: RSpec + Capybara (rejected — not requested by the stakeholder, and
  Minitest is the Rails-generated default, sufficient for this feature's scope).

## App server & deployment: Puma, Docker, Kamal

- **Decision**: Use Puma (Rails 8 default) as the app server, package the app in Docker, and deploy
  with Kamal, with a persistent volume mounted for the SQLite database file across deploys.
- **Rationale**: Explicitly mandated; Kamal is Rails 8's first-party deployment tool for exactly this
  "monolithic Rails app in a container" shape.
- **Alternatives considered**: None — mandated by the stakeholder.

## Lint / static analysis (Constitution Code Quality gate)

- **Decision**: Use RuboCop with the `rubocop-rails-omakase` configuration that Rails 8 generates by
  default, run as a required, zero-warning CI gate.
- **Rationale**: Satisfies the constitution's Code Quality principle without introducing a
  lint configuration not already provided by the Rails 8 generator.
- **Alternatives considered**: `standard` gem (rejected — Rails 8's own default already provides a
  RuboCop configuration, so adding a second linter would be redundant).

**Output**: All Technical Context items resolved; no `NEEDS CLARIFICATION` markers remain.
