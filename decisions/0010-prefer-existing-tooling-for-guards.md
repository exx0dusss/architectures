---
id: 0010
title: Prefer an existing tool over a bespoke guard, and make every guard state its reason
date: 2026-08-19
status: Accepted
supersedes: []
superseded_by: []
tags: [governance, tooling, conventions, consumers]
---

# ADR-0010 — Prefer an existing tool over a bespoke guard, and make every guard state its reason

## Context

ADR-0008 decided that consumers author their own `scripts/check-comments.ts`,
following `arch-init`, which tells a consumer to write `scripts/check-*.ts` for
every mechanically-checkable rule. That instruction was written before anyone
checked what already exists.

Most of the rules do have tools. ESLint's core `no-warning-comments` matches
whole words, case-insensitively, accepts multi-word terms, and takes
`location: "anywhere"` — which is the banned-phrase rule and the no-TODO rule
together, with no dependency added and no new CI, because the monorepo consumer already
runs ESLint inside `bun run verify`. `eslint-plugin-jsdoc` covers the contract
shape of a `/** */` block. `danger` covers pull request body rules that the
staged `pr-checklist.yaml` would otherwise parse by hand, and covers more of
them: a `Risk` section that must not be blank, an issue key that must carry a
number. A bespoke script would reimplement all of this and own the bugs.

The pressure the other way is Richards' own caution: ensure developers
understand the purpose before enforcement. A bespoke script controls its failure
message and can name the doctrine it enforces; a third-party rule prints its own
words and usually cannot be told to say more.

Not everything has a tool. No verifiable rule was found for emoji in source.

## Decision

A rule gets an existing tool when one covers it. A bespoke fitness function is
written only when none does.

| Rule | Fitness function |
|------|------------------|
| Banned comment phrases, no TODO comments | ESLint `no-warning-comments` |
| JSDoc contract shape | `eslint-plugin-jsdoc` |
| Pull request body sections, checkboxes, non-blank Risk | `danger` |
| Pull request title | `amannn/action-semantic-pull-request` |
| Commit subject format | `@commitlint/cli` |
| Emoji in source | bespoke — no tool found |
| Decision log integrity | `scripts/check-decisions.sh` — kept |

`check-decisions.sh` stays. `log4brains` is the nearest published alternative,
last released in December 2024, and it is an authoring and publishing toolchain
rather than a linter — it checks neither supersede-chain bidirectionality nor
whether an `ADR-NNNN` reference resolves, which are the two things the script
exists for.

Every fitness function states why it failed. Where the tool's message cannot be
customised, the reason is carried by the rule's configuration comment and by the
CI job name, both of which name the doc or ADR that owns the rule. A guard whose
output a contributor cannot trace back to a written rule is not finished.

This narrows the mechanism ADR-0008 chose. It does not reverse the decision that
consumers own their guards, or that the doctrine states what must be caught.

## Compliance

ESLint rules run inside `bun run verify` and in CI. `danger`, `commitlint` and
the title check run as CI jobs. `scripts/check-decisions.sh --strict` guards the
decision log.

The rule that every guard states its reason is prose about configuration, and
carries no automated check of its own: `Manual — no guard exists`.

## Consequences

- Less code to own. The comment rules become configuration in a linter the repo
  already runs, so the monorepo consumer gains them without a new CI job.
- Message control is lost wherever a third-party rule is used. That is the price
  of not owning the code, and the configuration comment is the mitigation rather
  than a fix.
- The set of tools is now a thing that ages. A rule that gains a better tool, or
  loses its tool to abandonment, is a doctrine change and needs its own decision.
- The monorepo consumer still has no fitness function for its layer doctrine, and neither
  does any other consumer. This decision does not address that gap; it only
  stops new bespoke code being written where a tool already exists.

## Alternatives rejected

| Alternative | Why rejected |
|-------------|--------------|
| Author every guard by hand, as ADR-0008 said | Reimplements `no-warning-comments`, `jsdoc` and `danger`, and owns their bugs, to gain a failure message. |
| Use tools only, drop the rules nothing covers | The emoji rule would be silently unenforced, which is the invisible gap ADR-0009 was written to stop. |
| Replace `check-decisions.sh` with `log4brains` | Stale since 2024-12, and it publishes ADRs rather than checking them. Neither supersede chains nor reference resolution is covered. |
| Wrap each third-party rule in a script to control the message | A wrapper per rule is bespoke code again, bought for wording alone. |
