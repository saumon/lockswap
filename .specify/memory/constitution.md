<!--
Sync Impact Report
===================
Version change: [TEMPLATE] → 1.0.0 (initial ratification)
Rationale for MAJOR: First concrete adoption of the constitution — all principle
and governance placeholders are being replaced with substantive, enforceable
rules for the first time.

Modified principles: N/A (initial adoption; no prior named principles existed)
Added principles:
  - I. Code Quality
  - II. Testing Standards (NON-NEGOTIABLE)
  - III. User Experience Consistency
  - IV. Performance Requirements

Added sections:
  - Quality Gates (replaces [SECTION_2_NAME]/[SECTION_2_CONTENT])
  - Development Workflow (replaces [SECTION_3_NAME]/[SECTION_3_CONTENT])
  - Governance (rules populated)

Removed sections: none (template had no prior populated sections)

Templates requiring follow-up review (not modified by this command):
  - .specify/templates/plan-template.md — verify its Constitution Check gate
    references these four principle names.
  - .specify/templates/spec-template.md — no direct constitution references
    expected; verify no drift.
  - .specify/templates/tasks-template.md — verify task categorization still
    reflects Testing Standards (tests before implementation) and Quality Gates.
  - Command docs under .claude/commands or equivalent — verify no stale
    references to placeholder principle names.

Deferred / TODO placeholders:
  - RATIFICATION_DATE set to 2026-09-12 (date of this initial adoption command,
    since no earlier ratification date exists in repo history — repo has only
    a single "first commit"). Update manually if an earlier true adoption date
    should be recorded instead.

Follow-up TODOs: none blocking.
-->

# LockSwap Constitution

## Core Principles

### I. Code Quality

Code MUST be readable, reviewed, and kept simple before it is merged.

- All code MUST pass linting and static analysis with zero unresolved
  warnings; a suppressed warning MUST carry an inline comment explaining why
  it is safe to ignore.
- Functions and modules MUST have a single, clear responsibility. Duplicated
  logic and unjustified complexity MUST be refactored rather than repeated;
  a reviewer MAY request simplification as a blocking change.
- Public interfaces (functions, modules, API endpoints) MUST be documented
  with their purpose, inputs, outputs, and error conditions where these are
  not self-evident from naming.

**Rationale**: Code is read far more often than it is written. Mandatory
review and static analysis catch defects and design drift before they reach
users, and keep the codebase approachable as contributors change over time.

### II. Testing Standards (NON-NEGOTIABLE)

Automated tests are the primary evidence that code works and keeps working.

- Every new feature and every bug fix MUST include automated tests that fail
  without the change and pass with it (unit tests at minimum; integration
  tests for cross-component behavior, especially swap/lock execution paths).
- The full automated test suite MUST run in CI on every pull request; a
  failing suite MUST block merge with no override.
- Tests MUST be deterministic. Flaky tests MUST be fixed or removed, not
  silenced with retries or skips used as a permanent workaround.
- Test coverage for core business logic MUST NOT regress below the level
  established on the `master` branch; a coverage drop MUST be justified in
  the pull request description or the change MUST add the missing tests.

**Rationale**: A financial/swap-adjacent codebase fails silently and
expensively if untested. Tests-first and CI-enforced gating make regressions
visible before they reach production instead of after.

### III. User Experience Consistency

Users MUST experience one coherent product, not a patchwork of components.

- UI terminology, interaction patterns, and visual components MUST be reused
  from existing conventions; introducing a new pattern where an established
  one already solves the problem MUST be justified in the PR description.
- User-facing error and status messages MUST be clear, actionable, and
  consistent in tone and format across the application.
- Any change to a user-facing flow MUST be verified for basic accessibility
  (keyboard operability, sufficient contrast, meaningful labels for
  assistive technology) before merge.
- Breaking changes to user-facing behavior (flows, terminology, shortcuts)
  MUST be called out explicitly in the pull request and, where applicable,
  documented for users.

**Rationale**: Inconsistency compounds cognitive load and erodes trust,
especially in a product handling asset locks/swaps where user confidence in
predictable behavior is part of the safety model.

### IV. Performance Requirements

Performance is a designed-for property, not an afterthought.

- Changes touching performance-sensitive paths (swap execution, lock
  operations, or any code in a hot request/transaction path) MUST include a
  before/after measurement (benchmark, profile, or load test) in the pull
  request when the change could plausibly affect latency or throughput.
- A change MUST NOT increase p95 latency or resource consumption on a
  measured critical path without explicit justification recorded in the PR;
  unexplained regressions MUST be fixed before merge.
- Critical user-facing and on-chain-adjacent paths MUST NOT contain
  unbounded loops or unbounded queries; pagination, batching, or streaming
  is required wherever result sets can grow without bound.
- Resource-intensive operations (network calls, on-chain reads/writes, large
  computations) MUST be identified and, where possible, made asynchronous or
  cached rather than blocking the user-facing critical path.

**Rationale**: Swap/lock operations are latency- and cost-sensitive by
nature; unmeasured performance changes risk both poor user experience and
increased on-chain/transaction cost.

## Quality Gates

The following gates enforce the Core Principles at the point of merge and
MUST be automated wherever tooling allows, rather than relying on manual
diligence alone:

- **Lint/static-analysis gate**: blocks merge on any unresolved warning or
  error (Code Quality).
- **Test gate**: blocks merge on any failing or newly-skipped test, and on a
  coverage regression for core business logic (Testing Standards).
- **Review gate**: blocks merge until at least one independent approval is
  recorded (Code Quality).
- **Accessibility/consistency check**: required in the PR description for
  any user-facing change, describing which existing patterns were reused or
  why a new one was necessary (User Experience Consistency).
- **Performance evidence**: required in the PR description for any change to
  a performance-sensitive path, per Principle IV (Performance Requirements).

A gate MAY only be bypassed with an explicit, written exception approved by
a maintainer and recorded in the pull request; silent bypasses are a
constitution violation.

## Development Workflow

- Work MUST proceed through pull requests against `master`; direct pushes to
  `master` are prohibited except for the repository owner correcting a
  broken build.
- Every pull request MUST state which Core Principles are relevant and how
  the change satisfies them (this MAY be brief for principles that are
  clearly not implicated).
- Reviewers MUST check pull requests against the Quality Gates above before
  approving, and MUST request changes if a gate's evidence is missing rather
  than assuming compliance.
- Specs, plans, and tasks produced by the Spec Kit workflow MUST reflect
  these principles; a plan step that conflicts with a Core Principle MUST
  either be revised or carry a documented, approved exception.

## Governance

This constitution supersedes any conflicting informal practice. All pull
requests and reviews MUST verify compliance with the Core Principles and
Quality Gates defined above; unresolved non-compliance MUST block merge.

**Amendment procedure**: Amendments are made by editing this file via the
`/speckit-constitution` workflow (or an equivalent explicit, reviewed
change). A proposed amendment MUST state the reason for the change and its
version-bump classification before being merged.

**Versioning policy**: This constitution follows semantic versioning:

- **MAJOR** — backward-incompatible governance changes, or a principle is
  removed or redefined in a way that changes prior obligations.
- **MINOR** — a new principle or section is added, or existing guidance is
  materially expanded.
- **PATCH** — clarifications, wording, typo fixes, or other non-semantic
  refinements.

**Compliance review**: Any contributor may flag a merged change as
non-compliant; the flag MUST be resolved by either bringing the change into
compliance or amending the constitution with a documented rationale. There
is no grandfathering of non-compliant code beyond the pull request in which
the non-compliance is identified.

**Version**: 1.0.0 | **Ratified**: 2026-09-12 | **Last Amended**: 2026-09-12
