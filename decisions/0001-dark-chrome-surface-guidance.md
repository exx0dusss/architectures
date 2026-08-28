---
id: 0001
title: Document dark chrome as an inverse-token surface pattern
date: 2026-04-07
status: Superseded
supersedes: []
superseded_by: [0002]
tags: [tokens, ui, tanstack-start]
---

# ADR-0001 — Document dark chrome as an inverse-token surface pattern

> Reconstructed from `e6cefea` (2026-04-07). Recorded here because ADR-0002
> reverses it, and a reversal is only legible next to what it reversed.

## Context

Application chrome — sidebar, top bar, command surfaces — was dark while the
content area was light. The token system had one set of surface tokens tuned
for light content, so chrome had to opt out of them.

## Decision

Treat dark chrome as a surface that inverts the standard token set. Document
the inverse-token table in `tanstack-start/patterns.md`, and ship a
`dark-surface-auditor` agent that flags components rendering inside dark chrome
with non-inverted tokens.

## Consequences

- Every chrome component carries an inversion concern that content components
  do not — the auditor exists because the rule cannot be enforced by the token
  names alone.
- "Is this surface dark?" becomes a question each component must answer, so the
  answer is duplicated across the chrome tree.

## Alternatives rejected

Not recorded — reconstructed from `e6cefea`.
