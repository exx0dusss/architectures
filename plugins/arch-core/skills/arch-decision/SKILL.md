---
name: arch-decision
description: Use when an architectural decision is being made, reversed, or asked about — a rule now contradicts an earlier rule, a stack or pattern changes status, stack parity is deliberately broken, a promotion rejects a real alternative, or someone asks "why did we do it this way". Writes an ADR into decisions/ and its row in DECISIONS.md, and never edits an accepted decision.
stacks: [nextjs, tanstack-start, nestjs-backend]
---

# Record an architecture decision

A doc says what the rule **is**. An ADR says why it changed and what was rejected. Without the
second, the next person cannot tell a deliberate constraint from an accident, so they either
cargo-cult it or break it.

## When an ADR is required

- **Doctrine reverses.** The rule now says the opposite of what it said.
- **A status changes** — `stable` → `maintenance` → `deprecated`, or a pattern is promoted.
- **Stack parity is deliberately broken.** One stack gets what its peer is owed, and the gap is
  accepted rather than scheduled.
- **A promotion rejects a real alternative.** Two projects solved it differently; one won.
- **Distribution or structure changes** — how doctrine reaches a consumer, or how a consumer's
  instruction files are laid out.

## When a plain commit is enough

New patterns that contradict nothing. Wording fixes. Expanding a doc. Adding a scaffolding agent.
Regenerating `reference/`. **An ADR for every commit is a log nobody reads.**

## Red flags

| Thought | Reality |
|---------|---------|
| "I'll just update the old ADR" | Accepted ADRs are immutable. Write the next one; set `supersedes` / `superseded_by`. |
| "The reversal is obvious, skip the ADR" | Obvious today is the reason it gets undone in six months. |
| "I don't remember what we rejected" | Write `Not recorded — reconstructed from <sha>`. Never invent alternatives. |
| "I'll write it after the change lands" | Then the Context is written from the outcome, which is how post-hoc justification gets recorded as reasoning. |
| "It's just a doc edit" | Check the trigger list. Status changes and reversals are doc edits too. |
| "Two decisions, one ADR" | One decision per ADR, or nothing can supersede half of it. |

## Steps

1. **Check the trigger list.** No trigger fires → plain commit, stop here.
2. **Copy the template** — `decisions/0000-template.md` → `decisions/NNNN-<slug>.md`, next free ID.
   The title is the decision in imperative form, not the topic.
3. **Write Context before Decision.** Context is the pressure that forced a choice, with no
   solution language in it. If Context could describe a world where doing nothing was fine, it is
   not finished.
4. **Fill Consequences with both sides** — what it costs as well as what it buys, plus what a
   consumer repo has to do about it.
5. **Alternatives rejected.** The reason belongs to each rejected option. Unknown → say so.
6. **Name the fitness function.** `## Compliance` says which mechanism governs the decision —
   a `scripts/check-*` guard, a CI job, or a linter rule. A fitness function is any mechanism
   that evaluates how well a solution performs against a desired outcome; static analysis is
   the common kind here, and a runtime monitor or a tracked metric is equally one. If nothing
   governs it, write `Manual — no guard exists`, which is a countable gap rather than a
   fabricated guard.
7. **Wire the supersede chain, both directions.** New ADR gets `supersedes: [NNNN]`; the old one
   gets `status: Superseded` and `superseded_by: [NNNN]` — and nothing else on it changes.
8. **Add the index row** in `DECISIONS.md`, newest first.
9. **Link it from `PATTERNS.md`** — the `Decisions` column of every row the decision touches.
10. **Verify:**
   ```bash
   sh scripts/check-decisions.sh --strict
   ```

## In a consumer repo

Same shape, same guard, scoped to that project: `decisions/` plus `DECISIONS.md` at the repo root,
referenced from `AGENTS.md` under Related docs — **not** `@import`ed. The log is read when someone
asks why, not loaded on every prompt.

Consumer ADRs record that repo's own decisions. A decision about blueprint doctrine belongs
upstream, in this repo, and reaches the consumer through the plugin — recording it locally
recreates the mirror the blueprint exists to avoid.

## Report

State: the ADR ID and title, which trigger fired, what it supersedes, which `PATTERNS.md` rows now
link it, and the guard's output. If the guard did not run, the decision is not recorded.
