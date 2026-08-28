---
id: 0003
title: Freeze the Next.js stack at maintenance; new doctrine lands in TanStack Start
date: 2026-08-07
status: Accepted
supersedes: []
superseded_by: []
tags: [stack-status, nextjs, tanstack-start]
---

# ADR-0003 — Freeze the Next.js stack at maintenance

## Context

Two frontend stacks were documented in parallel, and every convention change had
to be written twice or the two silently diverged. The Next.js stack's only
consumer had been dormant since 2026-02, so half that cost bought nothing.
Separately, several agents (`baseui-migrator`, `icon-migrator`, `form-migrator`)
drove one-time migrations that had finished everywhere, yet were still being
copied into new projects as live agents.

## Decision

- `nextjs/` moves to **maintenance**: kept accurate for existing code, no new
  consumers expected, no convention syncs. New doctrine lands in
  `tanstack-start/` and is back-ported only when someone needs it.
- Completed-migration agents move to `.claude/agents/archive/` with a
  deprecation header, outside the agent scan path.
- `PATTERNS.md` carries the status per row so the freeze is visible at the doc
  level, not just in a README banner.

## Consequences

- The two stacks will drift, deliberately. Parity is now a claim someone must
  make, which is what `stack-parity-auditor` checks.
- Anyone starting a Next.js project gets doctrine that is correct but not
  current; the maintenance banner is the only warning.

## Alternatives rejected

| Alternative | Why rejected |
|-------------|--------------|
| Delete the Next.js stack | Existing code still follows it; deleting the docs strands it. |
| Keep both stacks fully synced | Doubles the cost of every doctrine change to serve a dormant consumer. |
