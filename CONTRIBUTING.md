# Contributing to LockSwap

Thanks for your interest. Setup is in the [README](README.md#quick-start).

## Workflow

1. Branch from `dev`.
2. **Behavioural changes go through Spec Kit** (`/speckit-specify` → `clarify` → `plan` → `tasks` → `analyze` → `implement`); artifacts live in [`specs/`](specs/) and the rules in [`.specify/memory/constitution.md`](.specify/memory/constitution.md). Pure design passes follow the contract in [`CLAUDE.md`](CLAUDE.md).
3. Run `bin/ci` (RuboCop, audits, Brakeman, tests) and `bin/rails test:system` before opening a pull request. CI replays both.
4. Open a pull request against `dev`.

## Rules worth knowing

- Every user-facing string goes through I18n, in both `en.yml` and `fr.yml` — a test fails otherwise.
- No raw hex colour in a template; one media-query breakpoint (48rem).
- Run `bin/rails tailwindcss:build` after any stylesheet change.

See the [development guide](docs/development.md) for details.

## Licensing of contributions

LockSwap is released under the [PolyForm Noncommercial License](LICENSE) and is also available under a separate commercial licence. By submitting a pull request you agree that your contribution may be distributed under both. <!-- TODO: formalise as a CLA or DCO sign-off if outside contributions become regular. -->
