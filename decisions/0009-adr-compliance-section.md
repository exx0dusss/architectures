---
id: 0009
title: Record how every decision is governed, not only what was decided
date: 2026-08-19
status: Accepted
supersedes: []
superseded_by: []
tags: [agentic-docs, decisions, governance, conventions]
---

# ADR-0009 — Record how every decision is governed, not only what was decided

## Context

ADR-0004 established that a convention without a guard is a suggestion, and the
repo half-lives up to it: `check-decisions.sh`, `check-plugin-versions.sh` and
`build-skill-refs.sh --check` each enforce a rule mechanically. But no ADR says
which guard enforces it, because `decisions/0000-template.md` has nowhere to
write one. Governance is therefore recorded by accident — you learn a rule is
enforced by finding the script, not by reading the decision that created it.

The consumers show what that costs. The CRM consumer runs three guards in CI
(`check-type-scale.ts`, `check-mutation-feedback.ts`, `check-loading-patterns.ts`)
and none of them traces back to a recorded decision. The monorepo consumer runs none at
all, and nothing in its docs reveals whether that is deliberate or an omission.
Both are indistinguishable from the outside: an unguarded rule and a rule whose
guard was never written look identical.

Richards and Ford's decision-record structure — Title, Status, Context, Decision,
Consequences, **Compliance**, Notes — carries a section for exactly this.
Compliance states how a decision is measured and governed. Their term for the
mechanism is a *fitness function*: any mechanism that evaluates how well a
solution performs against a desired outcome, with static analysis named as a
first-class example. Every `check-*` script here already is one; the repo simply
lacks the word and the slot.

Their Second Law, *why is more important than how*, is the same argument the
contribution doctrine makes for a mandatory `## Why` in a pull request body
(ADR-0008). The doctrine had the practice and not the principle.

## Decision

`decisions/0000-template.md` gains a `## Compliance` section, placed after
`## Consequences` and before `## Alternatives rejected`. It answers one question:
which fitness function governs this decision. A named script or CI job, or the
literal words `Manual — no guard exists`, which is a permitted and expected
answer.

`check-decisions.sh` grows a check: an ADR numbered 0009 or higher must carry a
non-empty `## Compliance` section. Earlier ADRs are exempt.

The repo adopts *fitness function* as the name for what `scripts/check-*` files
are. `arch-decision`, `arch-init` and `PATTERNS.md` use the term, so a consumer
reading any of them meets the same vocabulary.

`contributing/pull-requests.md` and `contributing/commits.md` cite the Second Law
as the reason a pull request body carries `## Why` and a commit body carries
reasoning the diff cannot.

The rest of the Richards structure is not adopted. `Notes` — authorship and
modification history — is what git already provides.

## Compliance

`scripts/check-decisions.sh --strict`, extended with the section check described
above, run by `.github/workflows/` on every push. The rule that guards are called
fitness functions is prose and has no guard: `Manual — no guard exists`.

## Consequences

- ADRs 0001 to 0008 are Accepted and immutable, so none is retrofitted. ADR-0008
  in particular carries no `## Compliance` despite being the newest, which is why
  the guard starts at 0009 rather than failing the whole log.
- `Manual — no guard exists` is deliberately allowed. A template that forces
  every decision to claim automated governance gets fabricated governance; an
  honest gap that a reader can count is worth more than a fake guard.
- Naming the gap makes it countable. A repo can now be asked how many of its
  decisions are unguarded, which is a question neither consumer could answer
  before.

## Alternatives rejected

| Alternative | Why rejected |
|-------------|--------------|
| Retrofit `Compliance` into ADRs 0001–0008 | Accepted ADRs are immutable here. Editing eight of them to satisfy a new template is the exact rewrite `arch-decision` forbids. |
| Require a real guard, disallow `Manual` | Some decisions genuinely cannot be automated. Forcing a claim produces a fake one, and a fake guard is worse than a recorded gap. |
| Adopt the full Richards template including `Notes` | Authorship and modification history are what git records. A `Notes` section would be a second, staler copy. |
| Fold compliance into `Consequences` | It gets buried in prose and cannot be checked mechanically, which is the failure being fixed. |
| Leave the template alone and document guards in `PATTERNS.md` | That registry indexes docs, not decisions, and would separate a rule from the reason it exists. |
