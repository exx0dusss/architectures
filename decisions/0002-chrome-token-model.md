---
id: 0002
title: Give chrome its own always-consistent token group
date: 2026-08-07
status: Accepted
supersedes: [0001]
superseded_by: []
tags: [tokens, ui, tanstack-start]
---

# ADR-0002 — Give chrome its own always-consistent token group

## Context

ADR-0001 modelled chrome as a light surface inverted. That premise died: chrome
moved off dark surfaces entirely (glass redesign plus a token flatten), so
components were inverting against a surface that was no longer dark. The
`dark-surface-auditor` agent was auditing for a condition that no longer
existed, and "dark" tokens started leaking into chrome because the two concepts
had never been separated.

## Decision

Chrome gets a dedicated `--chrome-*` token group that reads the same in every
theme. Chrome components consume `--chrome-*` and never reach for light/dark
surface tokens.

- `tanstack-start/patterns.md` is rewritten around the chrome-token model.
- The inverse-token table survives, scoped to genuinely dark immersive surfaces
  only — not chrome.
- `color-token-auditor` gains a rule flagging dark tokens used inside chrome.
- `dark-surface-auditor` is deleted; its premise is gone.

## Consequences

- Chrome stops participating in theme inversion, so a theme change cannot break
  chrome contrast.
- Two surface vocabularies now exist (`--chrome-*` and the themed surface set).
  Picking the wrong one is a new class of mistake, which is why the auditor rule
  replaced the auditor agent rather than disappearing with it.
- Consumers still on inverted chrome must migrate; there is no compatibility
  shim.

## Alternatives rejected

| Alternative | Why rejected |
|-------------|--------------|
| Keep inverse tokens, retune them for the glass chrome | Preserves the wrong model — chrome's constancy is not an inversion of anything. |
| Let chrome use the standard surface tokens directly | Chrome must stay identical across themes; standard tokens are theme-reactive by definition. |
