---
id: 0011
title: Scope who approves a decision by cost, cross-team impact and security
date: 2026-08-19
status: Accepted
supersedes: []
superseded_by: []
tags: [governance, decisions, consumers]
---

# ADR-0011 — Scope who approves a decision by cost, cross-team impact and security

## Context

ADR-0008 specified a written handoff for the enforcement the monorepo consumer cannot
apply itself: the monorepo root belongs to a separate devops team, so the
frontend can stage a workflow but not merge one. That handoff was justified
ad hoc — the root is shared, therefore ask. Nothing said which decisions need
asking and which do not, so the boundary is redrawn by argument every time it
is met. The monorepo consumer's own `workflow.md` shows the cost: a `merge-policy`
workflow was written into the frontend package's nested `.github/`, where GitHub never
reads it, because putting it where it would run was a conversation nobody had.

Richards and Ford scope decision approval by cost, cross-team impact and
security: those criteria decide whether an architect decides alone or escalates.
The criteria are what this repo was missing, not the conclusion.

## Decision

A decision is owned by the team whose files it changes. It escalates to a shared
owner when any of three criteria holds:

- **Cross-team impact** — it changes a file another team also owns. In a
  monorepo the repository root is the common case: workflows, `CODEOWNERS`,
  branch protection, root compose files.
- **Cost** — it changes what the organisation pays or is billed for, including
  CI minutes and anything that runs per push.
- **Security** — it changes permissions, secrets, signing, or what a workflow is
  trusted to do with a token.

A handoff document names which criterion triggered it. "The root is shared" is
not a reason; "cross-team impact: the root `.github/workflows` is owned by
devops" is.

A decision meeting none of the three is made and recorded by the owning team,
not escalated. Escalating everything is how the `merge-policy` workflow ended up
in a directory that does not run.

## Compliance

`CODEOWNERS` at the repository root is the fitness function for the cross-team
criterion: it makes ownership machine-readable and forces review from the owning
team. Neither consumer has one — the monorepo consumer lists it as a deferred repo-level
item, and adding it is itself a cross-team decision under this ADR.

Cost and security have no automated check: `Manual — no guard exists`.

## Consequences

- The monorepo-consumer handoff gains a stated reason per item, and the items that
  meet none of the criteria stop being handed off at all.
- `CODEOWNERS` becomes the first thing worth asking devops for, ahead of the
  workflows, because it is what makes every later boundary question answerable
  without a conversation.
- Two of the three criteria are unguarded, and this ADR says so rather than
  implying the framework is enforced.
- The criteria are borrowed from a book about architecture decisions and applied
  to repository ownership, which is a narrower thing. Anything larger — team
  topology, who is allowed to introduce a dependency — is out of scope here.

## Alternatives rejected

| Alternative | Why rejected |
|-------------|--------------|
| Keep deciding the boundary case by case | Already produced a workflow in a directory GitHub does not read. |
| Escalate anything touching a shared file | The root holds compose files both halves edit routinely; this would escalate ordinary work. |
| Adopt the full approval framework from the book | It scopes architect authority in an organisation. Only the three criteria transfer to a repository. |
| Let `CODEOWNERS` alone express it | It encodes who reviews, never why a decision escalated. The criteria have to be written down separately. |
