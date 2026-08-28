# Code comments

This doc governs comments left in source — module overviews, item docs and
inline notes. It binds anyone writing one, human or agent.

## The reader

The reader is a contributor reading the code at HEAD, months later, with no
access to the conversation that produced it, the pull request, the issue, or
the diff. They have the file in front of them and nothing else.

Two rules follow from that, not as separate preferences but as direct
consequences of who is reading:

**Never narrate change history.** "Previously" and "now" describe a diff the
reader does not have open. At HEAD, only one version of the code has ever
existed as far as they can tell.

**Never address the reviewer.** A comment that argues a line is correct is
talking to someone who is no longer there. The reader needs the code
justified, not defended.

## Three kinds, three jobs

| Kind | Syntax | Job | Carries |
|---|---|---|---|
| Module overview | `/** */` at the top of the file | Explanation | Why the module exists, the concepts it defines, design rationale |
| Item docs | `/** */` above a declaration | Reference | The contract: behaviour, parameters, return, thrown errors, invariants |
| Inline | `//` inside a body | Rationale | Only what the code cannot say: constraints, workarounds, non-obvious coupling |

The jobs do not mix. An item doc that explains an implementation detail has
put explanation where reference belongs, and a reader trusting the contract
now has to read the body to find out which parts of the doc are real. A
contract scattered across inline comments below the declaration is no
contract at all — nothing above the function tells a caller what it can
rely on without reading the whole thing first.

## The deletion test

Before writing a comment, ask whether it states something the reader cannot
recover from the code. If the names, types or structure already carry it,
do not write it. If a name fails to carry it, fix the name instead of
compensating with a comment beside it.

**There is no line limit.** A comment is not measured in lines; it is
measured against the deletion test. A long comment that states something
the code genuinely cannot — a race condition, a constraint imposed by a
system outside this file, the reason an obvious-looking alternative doesn't
work — passes the test and stays exactly as long as it needs to be. A
one-line comment that restates what the code already says fails the test
and goes, regardless of how short it is. Length is a symptom, not the
disease: cutting a comment down to a shorter version of the same restated
fact does not make it pass.

## Banned

**Narrating the next line.** `// increment the counter` above `counter++`
tells the reader nothing the line itself doesn't. If the comment and the
code always say the same thing, the comment is the one that can go stale.

**Change-history narration** — `now`, `previously`, `no longer`, `the new
approach`. Meaningless at HEAD, where only one approach exists. This is the
first consequence of who the reader is, restated as a banned pattern rather
than left as an abstract rule.

**Reviewer-addressed justification** — `this correctly handles…`. That
argument belongs in the pull request, in the Why section (see
[`pull-requests.md`](./pull-requests.md)); the comment must justify the
code permanently, to a reader who was never in the review.

**Restated declarations** — a `/** */` block that rewords the function name
says nothing a reader couldn't get from the signature. `/** Gets the user
by id. */` above `getUserById(id: string)` carries zero information the
name didn't already carry.

**Vague hedging** — `some cases`, `various reasons`, `handles edge cases`,
`etc.` Name the cases or drop the sentence. A comment that gestures at
detail without giving it is worse than no comment: it promises an
explanation and then withholds it.

**Emoji.** They carry no information a linter or a reader can act on, and
this doc bans them in its own prose too, on the same reasoning.

**Ad-hoc section banners.** A `// ============ SECTION ============` block
is a signal the file wants to be split, not decorated. If a file is long
enough to want one, split the file.

## Workarounds

A comment explaining a workaround, a hack, or a dependency's surprising
behaviour must link the issue or pull request that motivates it. State the
reason verbatim: **a workaround with no link is indistinguishable from a
mistake.** Without the link, a later reader has no way to tell "this is
deliberate, here's why" from "nobody got around to fixing this," and the
safest-looking move — removing the workaround — becomes a regression.

## Editing existing comments

When a change makes a comment false, fix it in the same diff. A stale
comment is worse than a missing one, because it is read as current.

Do not replace specific prose with generic text — extend or correct the
comment so it keeps carrying what it carried before, plus whatever the
change added. Do not rewrite comments your change did not touch; a diff
that "cleans up" unrelated comments buries the actual change and makes the
pull request harder to review.

## What a guard checks

Per ADR-0010: ESLint core `no-warning-comments` covers the banned terms and
TODO, matching whole words, case-insensitively, accepting multi-word terms,
with `location: "anywhere"`. `eslint-plugin-jsdoc` covers contract shape. A
consumer copies this configuration:

```js
"no-warning-comments": [
  "error",
  {
    // contributing/comments.md — banned patterns. Change-history narration and
    // reviewer-addressed justification are meaningless to a reader at HEAD.
    terms: ["todo", "fixme", "previously", "no longer", "this correctly"],
    location: "anywhere",
  },
],
```

No existing tool covers everything in this doc. No tool was found for emoji
in source, so a bespoke fitness function enforces that rule — ADR-0010
rejected dropping the rules nothing covers, because the emoji rule would
then be silently unenforced. And the deletion test itself is a judgement no
linter makes: whether a comment states something the code cannot recover is
a question about what the code communicates, not a pattern a rule can match
against.
