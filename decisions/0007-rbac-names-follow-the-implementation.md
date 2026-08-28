---
id: 0007
title: Name the RBAC decorator and guard after the working implementation
date: 2026-08-18
status: Accepted
supersedes: []
superseded_by: []
tags: [nestjs, auth, naming]
---

# ADR-0007 — Name the RBAC decorator and guard after the working implementation

## Context

The NestJS doctrine specified `@CheckPermission({ action, subject })`, enforced by a
`CaslGuard` reading its metadata, declared in `rbac/check-permission.decorator.ts`. Four
documents carried those names: `nestjs-backend/auth-rbac.md`, `structure.md`, `rules.md`, and
the `arch-auth` skill.

No implementation ever used them. The one production backend built on this doctrine calls the
decorator `@RequirePermission` — 839 call sites — reads it with a `PermissionGuard`, and keeps
both in an `access-control` module. `@CheckPermission` appears in zero source files anywhere.

The names were not merely cosmetic. `arch-review` and `module-scaffold`, promoted from that
same backend, inherited the doctrine spelling and audited for a decorator that does not exist —
so a fully guarded API would have been reported as unguarded, on the exact rule where a false
negative is most expensive.

## Decision

The blueprint's RBAC names follow the working implementation: **`@RequirePermission`**, read by
**`PermissionGuard`**, declared in `require-permission.decorator.ts`.

Doctrine names an API only where a name is load-bearing — a framework export, a shared helper,
a file a scaffold must produce. For those, the name in the docs is the name that runs somewhere.
A name that exists only in prose is a specification of nothing.

Agents go further and **resolve the name from the codebase before auditing**, the way
`module-boundary-audit` already resolves the path alias from `tsconfig.json`. Doctrine states the
reference design; the agent trusts the repo. A rename in a consumer must not turn an audit into a
false negative.

## Consequences

- The rule that every non-public route carries a permission guard is unchanged. Only its spelling
  moved. No consumer has to rename anything: the implementation was always the source.
- `nestjs-backend/` docs, the `arch-auth` skill, and the two NestJS agents change together, so the
  bundled `reference/` regenerates and both plugins version.
- Anyone who built against the old prose — nobody known — reads a name that no longer matches.
  This ADR is the pointer.
- The general lesson is cheap to state and easy to forget: doctrine promoted out of a codebase
  must be checked back against that codebase. Promotion strips a consumer's market, vendors and
  paths; it must not strip its accuracy. `consumer-leak-auditor` catches leaks in one direction,
  and did not catch this one, which travelled the other way.

## Alternatives rejected

| Alternative | Why rejected |
|-------------|--------------|
| Rename the implementation to `@CheckPermission` | 839 call sites and a guard rewrite to make prose true. The prose is the cheap side of that trade. |
| Leave the names disagreeing, fix only the agents | The agents would be right and the docs wrong; the next promotion reintroduces the error from the docs. |
| Drop concrete names from doctrine entirely | A scaffolding agent must emit *something*. Refusing to name it moves the decision to whoever is least equipped to make it. |
