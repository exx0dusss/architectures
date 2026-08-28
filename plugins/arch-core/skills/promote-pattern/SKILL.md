---
name: promote-pattern
description: Use when a pattern has proven itself in a project and a second project is about to copy it, or when someone asks to promote, upstream, or generalize a convention into the exx0dusss/architectures blueprint. Walks the promotion from consumer code to a stack doc, a PATTERNS.md row, and a regenerated bundled reference.
stacks: [nextjs, tanstack-start, nestjs-backend]
disable-model-invocation: true
---

# Promote a pattern to the blueprint

**Never promote automatically.** A pattern earns its row by proving itself in a project. This
skill runs when a human asks for it — that is why the model cannot invoke it.

The rule it enforces: a pattern earns its row by being **general** — the rule and its reason
survive, the project it came from does not. ADR-0012 replaced the older gate, which held a
pattern back until a second project was about to copy it; on a fleet of unlike stacks that
measured when two repos happened to converge rather than whether the thing was general.

## Phase 1 — earn the row

Refuse to promote on enthusiasm. Confirm, out loud, with evidence:

- It is **in production** in at least one repo, not a plan or a spike.
- It is **general** — nothing of the originating project needs to survive Phase 2, and it belongs
  to a stack this repo carries or holds for every stack it claims. If the subject of the rule is
  a project's market, vendor, brand or locale, stop: that is local permanently, not local for
  now. ADR-0006 ruled that way on a carrier integration and it still stands.
- It is not already covered. Grep `PATTERNS.md` and the stack docs first; an existing row that
  needs sharpening is an **edit**, not a new pattern. **Check `plugins/*/archive/` too** — a
  consumer has already been found running a live copy of an agent archived here, and a promotion
  that misses the archive re-admits retired tooling under a new row.

A second consumer is **not** required. It was until ADR-0012; a plan or a doc that still asks for
one is stale.

## Phase 2 — strip the consumer out

This is the whole job, and it is where promotion usually fails. Rewrite the rule in general
terms:

- Drop the project's name, its brand, its vendors, its currency and locale.
- Drop its file paths and path aliases. State the shape (`{module}/domain/`), not one repo's
  spelling of it.
- Drop dated findings — "library X was broken in March" is a changelog entry, not doctrine.
- Turn magic numbers into either a named constant or an example clearly labelled as one.
- **Keep the rule and keep the reason.** A rule whose reason was edited out gets cargo-culted and
  then broken the first time it is inconvenient.

The blueprint must not end up pointing back at the project it came from.

## Phase 3 — land it

1. **Write it into the owning stack doc** — the doc that already covers the topic. A new file is
   the last resort, not the first; a pattern that does not fit an existing doc usually means the
   scope is wrong.
2. **If it is stack-agnostic**, it belongs in the doctrine skills instead, and it must hold for
   every stack in `stacks:` — check all three before claiming that.
3. **Add its `PATTERNS.md` row** — file path and status. New patterns start `stable`; nothing
   ships without a row, because a doc with no owner is how drift starts.
4. **Record the decision if the promotion rejected a real alternative** — two projects solved this
   differently and one won, or the promotion reverses existing doctrine. Then run `arch-decision`,
   and link the ADR from the new row's `Decisions` column. A promotion that merely fills a gap
   needs no ADR.
5. **Regenerate the bundled reference:**
   ```bash
   sh scripts/build-skill-refs.sh
   ```
   Skills read doctrine from `plugins/arch-core/reference/`, which is generated. Skip this and
   consumers receive doctrine that lags the repo. CI fails on it (`skill-refs.yml`).
6. **Version the plugin.** A consumer's `arch-sync-check.sh` compares version strings — doctrine
   that changes without a version bump reaches nobody's `BEHIND` report. Bump the plugin the
   change lands in, and the marketplace manifest with it.

## Phase 4 — reference it from both sides

Replace the consumer's local copy with a pointer to the blueprint, in **both** repos. A promotion
that leaves the original in place has created a mirror to drift — the exact failure the blueprint
exists to prevent.

Then re-read what you wrote against Phase 2, line by line — Phase 2 is easy to do 90% of, and the
last 10% is what ADR-0006 was written about. Working **in this repo** there is a
`consumer-leak-auditor` agent in `.claude/agents/` that does it for you; no plugin ships it, so a
consumer promoting from its own repo does this by reading.

## Report

State: what was promoted, which doc and row it landed in, what was stripped, any ADR recorded,
which plugin version carries it, and which consumer copies were replaced with pointers. If any of those is missing,
the promotion is not done.
