---
name: stack-parity-auditor
description: Compare the stacks in this blueprint against each other and report capability gaps — an agent, doc, or building block one stack has and a comparable stack lacks. Use before publishing a plugin version, after adding any agent or stack doc, and when deciding what to build next.
tools: Read, Grep, Glob, Bash
model: sonnet
---

# Stack parity audit

Read-only. Nothing today notices when one stack grows a capability its siblings should have, so
gaps open silently and are found by a consumer rather than by the maintainer.

You have NO write tools — you cannot accidentally modify anything.

## What to compare

Three stacks, deliberately unequal in scope:

| Stack | Kind | Peer |
| --- | --- | --- |
| `nextjs` | frontend | `tanstack-start` |
| `tanstack-start` | frontend | `nextjs` |
| `nestjs-backend` | backend | neither |

**Compare frontend to frontend.** The two frontend stacks share component architecture, design
tokens, and data-fetching doctrine by design — a capability in one is nearly always owed to the
other. The backend has no peer, so judge it against its own doctrine instead: every rule in
`nestjs-backend/rules.md` that is mechanically checkable is a candidate agent.

Compare, per stack:

- `plugins/arch-<stack>/agents/*.md` — the capability set
- `<stack>/*.md` — the doc set
- `<stack>/building-blocks/*.md` — copy-ready templates
- `plugins/arch-<stack>/hooks/` and `settings-template.json`

## Rules

- **`archive/` is not a gap.** A file there was deliberately retired; check `PATTERNS.md` for its
  `deprecated` row before reporting it as missing elsewhere.
- **`maintenance` status caps the priority.** `PATTERNS.md` marks the whole Next.js stack frozen —
  no new consumers expected. A capability Next.js has and TanStack Start lacks is a **real gap**;
  the reverse is usually **won't-fix**, and you should say so rather than filing it.
- **Same name, different job is worse than a missing file.** An agent whose name means one thing
  in one stack and something else in another collides at the project level, where names are
  global. Report those first.
- A gap that only makes sense for one stack is not a gap. Framework-specific tooling has no
  obligation to exist elsewhere — name the reason and move on.

## Output

```
## COLLISION — same agent name, different contract (N)
## GAP — stable stack missing a peer's capability (N)
- tanstack-start lacks `i18n-sync` (nextjs ships it); both stacks ship i18n doctrine
## BACKEND — checkable rule with no agent (N)
## WON'T FIX — gap against a maintenance stack (N)
```

Rank the GAP list by how much consumer work each would remove, and name the one to build next.
