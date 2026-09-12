---
id: 0014
title: Load conventions by task and owning workspace
date: 2026-09-12
status: Accepted
supersedes: [0004]
superseded_by: []
tags: [agentic-docs, conventions, routing]
---

# ADR-0014 — Load conventions by task and owning workspace

## Context

Unconditional convention imports scale with accumulated incident history rather than the task.
Mixed-stack repositories also have root packages that do not identify the app being changed.
A directory label cannot establish whether every session needs a rule. Runtime-specific import
and skill discovery semantics make identical files an insufficient guarantee of identical context.

## Decision

Keep a compact AGENTS.md with essential safety, ownership and task-triggered pointers. Preserve
CLAUDE.md as its one-line bridge. Load topic conventions and pattern references when the task
needs them, not merely because they live in conventions/. Resolve the owning workspace before
stack detection. Follow agent-workflows/context-routing.md, bundled with core doctrine.

Keep accepted local decisions and app-specific conventions authoritative over generic examples.
Document actual behavior separately from target doctrine and tracked debt. Portable workflows
check available host capabilities rather than assuming Claude tools, agents or import expansion.

## Consequences

Consumers prune unconditional imports while preserving safety and historical evidence. Index
pointers require meaningful triggers and valid paths. Fewer irrelevant documents are loaded, but
missing or weak routing can hide required rules; validate retrieval on representative tasks.
Existing convention files need not be renamed to change loading policy.

## Compliance

Manual — no guard proves semantic routing quality. scripts/check-decisions.sh governs this
supersede chain; scripts/build-skill-refs.sh --check governs bundled reference equality.
Runtime task evaluations must exercise root and app entrypoints before claiming equivalent
agent behavior.

## Alternatives rejected

| Alternative | Why rejected |
|-------------|--------------|
| Keep every convention auto-imported | Retains unrelated context and cannot distinguish owners in mixed-stack repositories. |
| Delete incident history to shorten files | Loses evidence instead of fixing retrieval. |
| Raise runtime context limits | Increases capacity without resolving contradictory authority or incorrect routing. |
