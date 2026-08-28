---
id: 0012
title: Admit an agent or skill on generality, not on a second consumer
date: 2026-08-20
status: Accepted
supersedes: []
superseded_by: []
tags: [patterns-registry, promotion, agents, skills]
---

# ADR-0012 — Admit an agent or skill on generality, not on a second consumer

## Context

`promote-pattern` Phase 1 refuses to promote anything until **a second consumer
is about to need it**. One project using something is a local convention; two
projects about to share it is doctrine.

That test assumes a fleet whose repos converge. This one does not. The consumers
run different stacks — one is TanStack Start plus a NestJS backend, another is
Next.js over a Java service — so two of them are rarely about to need the same
stack-shaped tool in the same month. The gate therefore measures *adoption
timing*, not generality, and tooling that is plainly general fails it for a
reason that has nothing to do with the tool: a reviewer for generated Drizzle
migrations, a writer for the CI guards ADR-0009 and ADR-0010 already require and
that nothing in this repo produces.

The cost is not that the blueprint stays small. It is that a consumer keeps its
own copy of something general, and this repo cannot see it. One consumer was
found running a live copy of an agent this repo had **already archived** as a
completed migration — identical but for the archive banner. Promotion never ran,
so nothing surfaced the duplication, and the archive's own retirement notice
never reached the repo still using it.

## Decision

An agent or skill is admitted when it is **general**, whether or not a second
consumer is waiting.

General means both of:

- Nothing of a consumer survives Phase 2 — no project name, brand, vendor,
  market, locale, path alias, repo-specific spelling of a directory, or dated
  finding. The rule and its reason survive; the originating repo does not.
- It belongs to a stack this repo carries, or holds for every stack it claims.

What stays with the consumer is unchanged, and is decided by the *rule*, not by
how useful it is: anything whose subject is a project's market, vendor, brand or
locale is local, permanently. ADR-0006 already ruled this way on a carrier
integration for one country, and that ruling stands.

Every other phase of `promote-pattern` is untouched. Phase 2 stripping, the
`PATTERNS.md` row, the plugin version bump, the regenerated reference and the
Phase 4 replacement of the consumer's copy with a pointer all still apply. This
ADR narrows exactly one gate and nothing else.

## Consequences

The registry grows faster, and it will carry tools with exactly one known
consumer. That is the accepted cost: a general tool nobody else has adopted yet
is cheaper to keep here than a general tool copied into a repo where no other
project can find it.

Tools that never earn a second consumer are handled by the statuses that already
exist — `deprecated` and `plugins/*/archive/`, which three completed-migration
agents already use. Nothing needs inventing to retire them.

Phase 4 becomes load-bearing rather than tidy. Promotion that leaves the
consumer's copy in place is now the common failure, not the rare one, because
promotion happens earlier in a tool's life — and a stale consumer copy of a
project-level agent silently shadows the plugin's version.

## Compliance

Manual — no guard exists.

`arch-sync-check.sh` reports a consumer agent that shadows a plugin agent of the
same name, which catches Phase 4 only when the names match; a copy left behind
under a different name is invisible to it. Phase 2 leak has an auditor —
`.claude/agents/consumer-leak-auditor.md` — but it is a maintainer agent and no
plugin ships it, so the consumer doing the promoting cannot run the check this
ADR leans on. Both gaps are recorded here rather than described as intentions.

## Alternatives rejected

| Alternative | Why rejected |
|-------------|--------------|
| Keep the second-consumer gate | It measures when a second repo adopts, not whether the thing is general. On a fleet of unlike stacks the two almost never coincide, so general tooling fails the gate for an unrelated reason. |
| Lower the bar to "a consumer could plausibly use it" | Admits everything. ADR-0006 removed consumer-specific material from doctrine at real cost; a plausibility test walks it straight back in. |
| Promote the docs, leave the agents with the consumer | The doc/agent line is not where generality lives. An agent is how a stack rule gets executed, and a rule this repo owns whose executor lives downstream is the same split-ownership ADR-0005 removed. |
| Require a second consumer only for agents, not skills | Same gate, applied to an arbitrary half. Nothing about an agent makes it less general than a skill covering the same rule. |
