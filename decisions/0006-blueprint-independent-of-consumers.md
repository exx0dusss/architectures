---
id: 0006
title: Make the blueprint independent of its consumers
date: 2026-08-17
status: Accepted
supersedes: []
superseded_by: []
tags: [distribution, patterns-registry, consumers]
---

# ADR-0006 — Make the blueprint independent of its consumers

## Context

The repo described itself as a mirror of a fleet. Nine docs carried
`source: <project>@<sha>` stamps, `PATTERNS.md` tracked which projects consumed
what, and a weekly workflow cloned those projects to report staleness. That made
the upstream depend on its downstreams — backwards — and it meant the repo could
not be shared without exposing the names, paths and internals of every project
in the fleet. (Project-specific material had already leaked into doctrine; a
consumer's analytics roadmap sat in the stack docs until `19cb1d9`.)

ADR-0005 removed the reason for the mirror. Consumers no longer copy blueprint
docs, so nothing in a consumer can silently drift from here and there is nothing
for a mirror-drift check to check.

## Decision

Every doc is authored here, and nothing here points at a downstream project.

- All `source:` stamps removed.
- `scripts/check-pattern-drift.sh`, `scripts/cron-drift-check.sh` and
  `.github/workflows/pattern-drift.yml` deleted.
- `PATTERNS.md` loses its Source-of-truth / Last-synced / Consumers columns.
- Project attribution removed from doc prose (dated sweeps, call-site counts,
  fleet-specific registry URLs).
- The dependency check moves to the side that has the dependency:
  `arch-sync-check.sh` in `arch-core` compares a consumer's installed plugin
  versions against the marketplace, writes `.claude/blueprint-sync.json`, and
  exits non-zero under `--strict`.
- **Promotion survives as a practice**: promoting a pattern means rewriting it
  in general terms — drop the originating repo's name, paths and dated findings,
  keep the rule and the reason.

## Consequences

- The repo is shareable; zero consumer names remain anywhere in it.
- Nobody upstream can tell which consumers are stale — by design. A consumer
  that wants to know runs `arch-sync-check` on itself.
- Promotion now costs a rewrite. A pattern copied verbatim from a project will
  fail `consumer-leak-auditor`.

## Alternatives rejected

| Alternative | Why rejected |
|-------------|--------------|
| Keep the stamps, scrub only the names | The direction of the dependency is the problem, not the wording. |
| Keep the weekly drift workflow, make consumer repos optional inputs | Still requires cloning downstreams from upstream CI. |
