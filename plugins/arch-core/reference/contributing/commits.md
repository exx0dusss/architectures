# Commit messages

This doc governs the commit message — the subject line, body and trailers a
contributor writes for each commit. It binds anyone committing, human or
agent.

## Subject

Conventional Commits. Every subject matches:

```
/^(revert: )?(feat|fix|docs|style|refactor|perf|test|build|ci|chore)(\(.+\))?!?: .{1,50}/
```

`.{1,50}` bounds the **description that follows `type(scope): `**, not the
subject line as a whole. A subject can legally run past fifty characters in
total: `fix(cache): retry stale entries after timeout expiry` is
fifty-two characters end to end, but its description — everything after
`fix(cache): ` — is exactly forty, so it matches. Measure the description,
not the line.

Three rules the expression cannot carry, because a regex checks shape, not
meaning:

**Imperative present tense** — "change", never "changed" or "changes". A
subject completes the sentence "This commit will …", and only the imperative
reads correctly there.

**No capital letter after the type**, no trailing period. Both are noise a
reader's eye has to discard on every line of `git log --oneline`; neither
carries information.

**Scope names the area the commit touches, not the ticket it closes.**
`fix(auth): …`, not `fix(PROJ-123): …`. A scope is read as a map of the
codebase across hundreds of commits; a ticket number means nothing without
opening the tracker, and the tracker is already linked from the pull
request.

## Body

A body earns its place only when the reason for the change is not already
visible in the diff — *why is more important than how* is the Second Law of
Software Architecture, Richards and Ford. Reasoning that runs longer than a
sentence or two belongs in the pull request instead: a pull request body is
read once, at review time, by someone with the diff open next to it; a
commit body is read alone, years later, by someone bisecting a regression
who does not have that context and does not want a design essay — they want
the one fact the diff can't show.

## Trailers

No agent attribution trailer — no `Co-Authored-By` naming an AI tool, no
`Generated with`, no session or tool-run identifier, regardless of how the
commit was produced. `Co-Authored-By` naming a **human** collaborator is
unaffected and stays normal practice. The reason for the ban is not the
tool: a trailer is a claim about who is accountable for the work, and
accountability does not transfer to a tool any more than a pull request
description does.

## What a guard checks

`@commitlint/cli` with `@commitlint/config-conventional`, run in CI,
enforces the subject expression above — named here without pinning a
version, because the doctrine outlives whichever release is current. It
cannot check imperative mood: "fixed the leak" and "fix the leak" are both
syntactically valid conventional-commit descriptions, and only a reader
knows which tense was meant. It cannot check whether a body was warranted,
either — that a diff already shows the reason, or doesn't, is a judgment
about the code, not the message. Both stay human judgement; a guard that
flags neither is not a gap in the guard, it is the boundary of what a
message can mechanically prove.
