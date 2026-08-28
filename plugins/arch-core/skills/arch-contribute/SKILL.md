---
name: arch-contribute
description: Use when opening a pull request, writing a commit message, or writing or editing comments in source — including comments added incidentally while fixing a bug. Routes to the contribution doctrine and names the fitness functions that guard it.
stacks: [nextjs, tanstack-start, nestjs-backend]
---

# Pull requests, commits, and comments

**Applies only to repos built on the `exx0dusss/architectures` blueprint.** If this repo has no
`docs/architecture/` directory and no `AGENTS.md` naming one of these stacks, this skill does not
apply — stop and ignore it.

A pull request body, a commit message and a comment are the three artefacts a contributor
produces that no compiler checks. Left unstated they get invented per repository.

## Triggers

- Opening or updating a pull request.
- Writing a commit message.
- Writing or editing a comment in source.
- Being asked how to describe a change.

## When this skill does not apply

Reading or reviewing someone else's pull request — that judgement belongs to code review, not
to this skill. A comment living in documentation prose or config, outside source — `comments.md`
governs comments in source, not a `.md` file's own body. A commit nobody composed — a lockfile
bump, a dependency bot's auto-generated message. **This skill governs what a contributor writes,
not what a reviewer or a machine produces.**

## Read the doctrine for the artefact in hand

| Working on | Read |
|---|---|
| A pull request body | `../../reference/contributing/pull-requests.md` |
| A commit message | `../../reference/contributing/commits.md` |
| Comments in source | `../../reference/contributing/comments.md` |

If the repository has its own `docs/conventions/pull-requests.md`, `commits.md` or `comments.md`,
that file wins for the topic it covers. State the reason: a consumer's copy records a deliberate
local deviation, and the blueprint yields to it rather than overriding it silently. This matches
every other `arch-*` skill.

## Red flags

| Thought | Reality |
|---------|---------|
| "The diff explains itself, skip the Why" | The diff shows what changed. Why is what a reader cannot reconstruct. |
| "I ran the checks, I will tick the boxes" | Verification carries pasted output. A tick is a claim, not evidence. |
| "This comment explains what the change fixes" | The reader is at HEAD and has no diff. Describe the code, not the change. |
| "Risk is obviously none, leave it blank" | Blank reads as unconsidered. Write `none`. |
| "I will note the workaround and link the issue later" | A workaround with no link is indistinguishable from a mistake. |

## Steps

1. **Check which artefact is being written** — pull request body, commit message, or comment.
2. **Read the matching doc**, preferring the repository's own copy when one exists.
3. **Apply it** — do not invent a shape the doc doesn't specify.
4. **Before finishing, re-read only the comments in the diff, in isolation.** Delete any that
   fail the deletion test — a comment earns its place only by stating what the reader cannot
   recover from the code.

## Report

State: which doc was applied, whether the repository's own copy took precedence, and which
fitness functions ran (`danger`, `amannn/action-semantic-pull-request`, `@commitlint/cli`,
`no-warning-comments` / `eslint-plugin-jsdoc`, as applicable).
