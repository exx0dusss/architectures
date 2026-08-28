# Pull requests

This doc governs the body of a pull request — the description a reviewer reads
before the diff. It binds anyone opening one, human or agent.

## The body

A pull request body opens with a line linking the issue it closes, then four
sections, in order: What changed, Why, Verification, Risk.

**`Closes <ISSUE-KEY>`**, or the repo's own closing syntax — whatever the
issue tracker recognises. Example: `Closes PROJ-123`. It goes first, on its
own line, so a reviewer can open the ticket before reading anything else.

**`## What changed`.** One paragraph. It gives a reviewer what they need
before reading a single line of diff — not a restatement of the file list the
diff already shows, but the orientation that makes the diff legible.

**`## Why`.** The reasoning the diff cannot show: what was ruled out, what
surprised the author while building it, what the originating ticket got
wrong. Code answers how; only prose answers why — *why is more important
than how* is the Second Law of Software Architecture, Richards and Ford. A
pull request without a Why section keeps that reasoning in one person's head
until it is lost.

**`## Verification`.** Pasted command output, never a claim. A checked box
means someone clicked it; pasted output means someone ran it. The rule:
**"A check that could not be run is named, with the reason. An honest gap
beats an implied pass."** Silently skipping a check is indistinguishable,
later, from never knowing it existed.

**`## Risk`.** Migrations, data changes, anything irreversible, anything that
needs an operator to do something after merge. Never leave this blank —
write `none` when there is none. A blank Risk section is not evidence of no
risk; it is evidence nobody checked.

## Deleting sections

A section that does not apply to a given pull request is deleted, not left
standing with nothing underneath. An empty heading is worse than no heading:
it reads as something someone forgot to fill in, and a reviewer cannot tell
"nothing to say" from "didn't get to it." Risk is the one section this does
not apply to — it stays and says `none`, because the absence of risk is
exactly what a reviewer needs to be told.

## Attribution

The description is written by the person opening the pull request. No agent
attribution trailer appears in the body, and none appears in any commit the
pull request carries — not a co-authored-by line naming an AI tool, not a
generated-with note, nothing that credits a tool for prose a human is
putting their name behind. This matches the practice of the largest
repositories surveyed to settle this doctrine. The reason: a description is
a claim about work someone is accountable for, and accountability does not
transfer to a tool. `Co-Authored-By` naming a **human** collaborator is
unaffected and stays normal practice, exactly as in
[`commits.md`](./commits.md).

## Stacked pull requests

When one branch targets another instead of the trunk, the base retargets
automatically as each parent merges — re-check the base before merging any
child, because the tool moving it does not announce that it moved. Merge
stacked branches with a merge commit or a rebase merge, never a squash
merge: squashing a parent collapses its commits into one while every child
still holds the original commits underneath, so each child's diff against
the new base shows those changes twice.

## What a guard checks

Two fitness functions exist for this doctrine, named here without pinning a
version because the doctrine outlives whichever release is current: `danger`
checks body structure, a non-blank `## Risk` section, and unchecked boxes
left in the template; `amannn/action-semantic-pull-request` checks the
title, which takes the same Conventional Commits form as a commit subject —
the rule and its fifty-character bound belong to
[`commits.md`](./commits.md). A repository running neither is enforcing this
doc by trust alone. That is a real gap, and it is one this doc records
rather than hides — a template nobody can fail is not evidence the rules are
being followed.
