# Decision log

Every architectural decision this blueprint has made, newest first. One file per
decision in [`decisions/`](./decisions/), one row here.

`PATTERNS.md` says what a rule **is**. This log says why it changed, and what was
rejected on the way. A doc without its decision is a rule nobody can safely undo.

## Index

| ID | Date | Decision | Status | Links |
|----|------|----------|--------|-------|
| [0014](./decisions/0014-load-conventions-by-task.md) | 2026-09-12 | Load conventions by task and owning workspace | Accepted | supersedes 0004 |
| [0013](./decisions/0013-expand-beyond-architecture.md) | 2026-09-04 | Expand marketplace from architecture blueprints to engineering playbook collections | Accepted | `product-design/`, `plugins/product-design/` |
| [0012](./decisions/0012-admit-agents-on-generality.md) | 2026-08-20 | Admit an agent or skill on generality, not on a second consumer | Accepted | `plugins/arch-core/skills/promote-pattern/SKILL.md` |
| [0011](./decisions/0011-scope-decision-approval.md) | 2026-08-19 | Scope who approves a decision by cost, cross-team impact and security | Accepted | — |
| [0010](./decisions/0010-prefer-existing-tooling-for-guards.md) | 2026-08-19 | Prefer an existing tool over a bespoke guard, and make every guard state its reason | Accepted | `contributing/comments.md`, `scripts/check-decisions.sh` |
| [0009](./decisions/0009-adr-compliance-section.md) | 2026-08-19 | Record how every decision is governed, not only what was decided | Accepted | `decisions/0000-template.md` |
| [0008](./decisions/0008-contribution-doctrine.md) | 2026-08-19 | Own the contribution conventions — pull requests, commits and comments | Accepted | `contributing/*` |
| [0007](./decisions/0007-rbac-names-follow-the-implementation.md) | 2026-08-18 | Name the RBAC decorator and guard after the working implementation | Accepted | |
| [0006](./decisions/0006-blueprint-independent-of-consumers.md) | 2026-08-17 | Make the blueprint independent of its consumers | Accepted | |
| [0005](./decisions/0005-ship-doctrine-as-plugins.md) | 2026-08-17 | Distribute doctrine as Claude Code plugins instead of copied files | Accepted | |
| [0004](./decisions/0004-converged-agentic-doc-structure.md) | 2026-08-07 | Prescribe one instruction layout for consumer repos | Superseded | superseded by 0014 |
| [0003](./decisions/0003-nextjs-maintenance-mode.md) | 2026-08-07 | Freeze the Next.js stack at maintenance; new doctrine lands in TanStack Start | Accepted | |
| [0002](./decisions/0002-chrome-token-model.md) | 2026-08-07 | Give chrome its own always-consistent token group | Accepted | supersedes 0001 |
| [0001](./decisions/0001-dark-chrome-surface-guidance.md) | 2026-04-07 | Document dark chrome as an inverse-token surface pattern | Superseded | superseded by 0002 |

ADRs 0001–0006 were reconstructed from git history after the fact; each names the
commit it was reconstructed from. Where the alternatives considered at the time
were not written down, the ADR says so rather than inventing them.

## When to write one

An ADR is **required** when:

- **Doctrine reverses.** A rule now says the opposite of what it said. The new
  ADR supersedes the old one; the old one is never edited except to record that.
- **A stack or pattern changes status** — `stable` → `maintenance` → `deprecated`,
  or a pattern is promoted into the registry.
- **Stack parity is deliberately broken.** One stack gets a capability its peer is
  owed, and that gap is accepted rather than scheduled.
- **A promotion rejects a real alternative.** Two projects solved the same problem
  differently and one won. Record the loser and why.
- **Distribution or structure changes** — how doctrine reaches a consumer, or how
  a consumer's instruction files are laid out.

A plain commit is enough for: new patterns that contradict nothing, wording fixes,
expanding a doc, adding a scaffolding agent, regenerating `reference/`.

## How to write one

1. Copy [`decisions/0000-template.md`](./decisions/0000-template.md) to
   `decisions/NNNN-<slug>.md`, next free ID.
2. Fill the frontmatter. `status: Proposed` while it is being decided,
   `Accepted` once it is.
3. Add a row to the index above.
4. If it reverses an earlier decision: set `supersedes: [NNNN]` on the new ADR,
   and on the old one set `status: Superseded` and `superseded_by: [NNNN]`.
   Both sides, or `scripts/check-decisions.sh` fails.
5. Link the ADR from the `Decisions` column of the affected `PATTERNS.md` rows.

**An accepted ADR is immutable.** Its Context and Decision describe a moment.
Correcting a decision means writing the next one, not rewriting the last one. The
only edit an accepted ADR ever takes is `status` / `superseded_by`.

## Statuses

| Status | Meaning |
|--------|---------|
| `Proposed` | Under discussion. Stale after 30 days — decide it or drop it. |
| `Accepted` | In force. Immutable except for supersession. |
| `Superseded` | Reversed by a later ADR. Kept, because the reversal needs it to be legible. |

Guarded by `scripts/check-decisions.sh` (`--strict` in CI): ID/filename agreement,
index and files in step, bidirectional supersede chains, live ADR-ID references,
and stale `Proposed`.
