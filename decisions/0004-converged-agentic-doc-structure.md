---
id: 0004
title: Prescribe one instruction layout for consumer repos
date: 2026-08-07
status: Accepted
supersedes: []
superseded_by: []
tags: [agentic-docs, conventions, consumers]
---

# ADR-0004 — Prescribe one instruction layout for consumer repos

## Context

Each consumer repo invented its own instruction layout — some put everything in
`CLAUDE.md`, some split by topic, some duplicated doctrine into always-loaded
files. Agents therefore loaded the wrong context at the wrong time, and indexes
that explained instead of routing cost thousands of tokens on every prompt.

## Decision

One canonical layout, documented in the root README and pointed at from each
stack README:

- `CLAUDE.md` contains exactly one line: `@AGENTS.md`. Claude-specific config
  stays in `.claude/`, so the index is tool-agnostic.
- `AGENTS.md` is a pure index: intent skill-mappings header, one `@import` per
  `docs/conventions/*.md`, and a "read X first" trigger table for
  `docs/patterns/*.md`. The index routes; it never explains.
- `docs/conventions/*.md` — one topic per file, always loaded.
- `docs/patterns/*.md` — heavyweight specs loaded before touching that surface.
- `scripts/check-*.ts` — a CI guard for every mechanically-checkable rule. A
  convention without a guard is a suggestion.

## Consequences

- Conventions and patterns become two different things a contributor must
  choose between; the wrong choice costs tokens (a pattern imported always) or
  compliance (a convention nobody loads).
- Fixes the duplication failure directly: the index cannot restate a doc,
  because the index is only links.

## Alternatives rejected

| Alternative | Why rejected |
|-------------|--------------|
| Single `CLAUDE.md` holding everything | Always-loaded cost scales with total doctrine, not with the task. |
| Let each repo choose its own layout | Agents cannot rely on a structure that varies per repo. |
