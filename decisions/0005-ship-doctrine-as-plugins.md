---
id: 0005
title: Distribute doctrine as Claude Code plugins instead of copied files
date: 2026-08-17
status: Accepted
supersedes: []
superseded_by: []
tags: [distribution, plugins, skills]
---

# ADR-0005 — Distribute doctrine as Claude Code plugins

## Context

`arch-init` copied docs, agents and settings into each consumer repo. Every
sync was then a manual diff-and-merge, and doctrine drifted per project — the
copies were real files someone could edit, with no path back upstream.

## Decision

This repo becomes a Claude Code plugin marketplace. Consumers install rather
than copy, and `claude plugin update` re-syncs every consumer at once.

- `arch-core` ships the `arch-*` skills plus the bundled stack reference. Each
  skill declares triggers, carries the red-flag list from its stack's
  `rules.md`, and routes to the reference for the stack it detects in
  `package.json` — one skill set, all stacks, no duplication.
- `arch-nextjs` / `arch-tanstack-start` / `arch-nestjs-backend` ship per-stack
  agents, hooks and a settings template, each depending on `arch-core`.
- Doctrine loads **lazily**. What stays always-loaded in a consumer is only that
  project's own instantiation — its layout, commands, ports, safety rules.
- `plugins/arch-core/reference/` is generated from the stack docs by
  `scripts/build-skill-refs.sh`; the `Skill refs` workflow fails any PR where
  the two diverged.

## Consequences

- Consumers no longer own an editable copy, so local doctrine patches become
  visible as plugin shadowing rather than invisible as file edits.
- A generated mirror now exists inside the repo, and staleness is a CI concern —
  edit a stack doc, rerun the build script, commit both.
- Archived migration agents had to move outside the agent scan path so they stop
  loading as live agents.

## Alternatives rejected

| Alternative | Why rejected |
|-------------|--------------|
| Keep copying via `arch-init`, add a drift checker | Detects divergence after it happens; the copies are still the problem. |
| Git submodule of this repo per consumer | Pins whole-repo versions and still puts doctrine in the always-loaded path. |
