---
id: 0008
title: Own the contribution conventions — pull requests, commits and comments
date: 2026-08-19
status: Accepted
supersedes: []
superseded_by: []
tags: [agentic-docs, conventions, consumers, contributing]
---

# ADR-0008 — Own the contribution conventions — pull requests, commits and comments

## Context

ADR-0004 prescribed the instruction layout a consumer repo must have — `CLAUDE.md`
into `AGENTS.md`, conventions always loaded, patterns loaded on trigger. It said
nothing about the artefacts a contributor actually produces: the pull request
body, the commit message, the comment left in the source. That hole shows up in
both consumers.

The monorepo consumer has no pull request template and no contribution guide, so
sixteen stacked pull requests were opened with sixteen improvised descriptions,
and 131 commits carry agent attribution trailers nobody asked for. Its commit
bodies run twenty to forty lines of prose that belong in a pull request. Comment
blocks on the open branches run six lines where two would do, and narrate the
change rather than the code — `ui/sheet.tsx` carries fifty-two comment lines, and
cites `node_modules` paths that will rot at the next dependency bump.

The CRM consumer solved the same problem independently and better. Its
template demands pasted command output rather than a checked box, and forces a
`Risk` section to say `none` rather than stay blank. Two projects solved the same
problem two ways, which is the promotion trigger this repo already recognises.

A survey of nine reference repositories — `withastro/astro`, `sveltejs/kit`,
`vercel/next.js`, `vitejs/vite`, `TanStack/query`, `shadcn-ui/ui`,
`microsoft/TypeScript`, `honojs/hono`, `t3-oss/create-t3-app` — settles the parts
that were open questions. Templates are short, a median of roughly fifteen lines.
None of the nine gates a merge on pull request checkboxes, although the action to
do it exists; they gate on machine-checkable facts instead — conventional commit
titles, commitlint, formatting applied by CI rather than asserted by the author.
Astro is the only one with a written comment policy, and it caps nothing by
length: a comment earns its place by stating what the reader cannot recover from
the code.

## Decision

This repo owns contribution doctrine, in a new stack-agnostic `contributing/`
directory beside the stack directories:

- `contributing/pull-requests.md` — the body shape. `Verification` carries pasted
  command output, never a bare assertion; a check that could not be run is named
  with its reason. `Risk` states `none` rather than staying blank. Descriptions
  are written by the human opening the pull request; agent attribution trailers
  appear in neither the body nor the commit.
- `contributing/commits.md` — Conventional Commits, subject imperative, lowercase
  and under fifty characters. A body only when the reason is not already visible
  in the diff, and the reasoning that runs long belongs in the pull request.
- `contributing/comments.md` — the reader is a contributor at HEAD months later
  with no access to the conversation, the pull request or the diff. Three kinds
  of comment carry three different jobs. A comment survives only if it states
  something the code cannot; change-history narration, reviewer-addressed
  justification and restated declarations are banned outright, and a workaround
  without a linked issue is indistinguishable from a mistake.

`arch-core` ships an `arch-contribute` skill that routes to those three docs and,
like every other `arch-*` skill, prefers a consumer's own copy when one exists.
`scripts/build-skill-refs.sh` copies the directory into the bundled reference
alongside the stack docs.

Consumers author their own `scripts/check-comments.ts`. The doctrine states what
the guard must catch; it does not ship the script. This follows `arch-init`,
which already tells a consumer to write `scripts/check-*.ts` for every
mechanically-checkable rule, and it keeps the promise in `PATTERNS.md` that
nothing is copied into a consumer repo and therefore nothing can drift.

Consumer decision logs converge on this repo's format — `decisions/NNNN-slug.md`,
one row per decision in `DECISIONS.md`, guarded by `check-decisions.sh`. The
dated filenames in the CRM consumer's `docs/decisions/` are renumbered.

## Consequences

- A convention that only a human enforces is still a suggestion, and ADR-0004
  already said so. Three of these rules are machine-checkable and get a guard;
  the rest are not, and the pull request body is where a human states what no
  machine can confirm. Demanding pasted output rather than a checked box is what
  keeps that statement honest.
- Neither consumer can enforce any of it today. The monorepo consumer cannot add workflows
  because the monorepo root belongs to a separate devops team, and the CRM consumer has
  Actions billing unresolved. Doctrine and guards land now; the gates light up
  per repository when each is unblocked. A staged, inert workflow with a written
  handoff is the honest form for that gap.
- The 131 existing attribution trailers stay. Rewriting them would force a
  force-push through a sixteen-pull-request stack, and history is not worth that.
  The rule binds new commits.
- `contributing/` is the first directory here that no stack owns. The skill-ref
  build script grows a second loop, and `PATTERNS.md` a section that is not
  per-stack.

## Alternatives rejected

| Alternative | Why rejected |
|-------------|--------------|
| Leave it to each consumer | Two consumers had already invented two answers; a third would invent a third. |
| Fold the rules into each stack's `rules.md` | Nothing here is stack-specific, so three copies would drift apart. |
| Cap comments by line count | Length is a symptom. Astro's deletion test removes the comments that deserve removing and keeps a long one that earns it. |
| Gate merges on pull request checkboxes alone | None of the nine surveyed repositories does this. An unchecked-box gate teaches people to check boxes, not to verify. |
| Ship `check-comments.ts` from the plugin | `PATTERNS.md` forbids copying into consumers, and CI cannot resolve `${CLAUDE_PLUGIN_ROOT}`. |
| Adopt `docs/adr/NNNN` from an external example | This repo's `decisions/` plus `DECISIONS.md` plus `check-decisions.sh` is the more developed system and already has a guard. |
