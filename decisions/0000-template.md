---
id: 0000
title: <Imperative phrase — the decision, not the topic>
date: <YYYY-MM-DD>
status: Proposed
supersedes: []
superseded_by: []
tags: []
---

# ADR-0000 — <Title>

## Context

What forced a decision. The pressure, the constraint, the thing that stopped
working. Written so someone who was not here understands why doing nothing was
not an option. No solution language.

## Decision

What was decided, in the present tense, as a rule someone can follow. Name the
docs, skills, scripts or agents that carry it.

## Consequences

What this costs and what it buys — both. Include the things that got harder,
the migrations it forces, and what a consumer repo has to do about it.

## Compliance

Which fitness function governs this decision — a named `scripts/check-*` guard,
a CI job, or a linter rule. If none exists, write `Manual — no guard exists`
rather than describing an intention. A recorded gap can be counted; a claimed
guard that nobody wrote cannot be told apart from a real one.

## Alternatives rejected

| Alternative | Why rejected |
|-------------|--------------|
| <option> | <reason> |

If the alternatives were never written down, say
`Not recorded — reconstructed from <sha>` rather than inventing them.
