# Contribution Doctrine Implementation Plan — blueprint

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the blueprint stack-agnostic contribution doctrine — pull requests, commits, comments — shipped through `arch-core` so both consumer repos receive it by `claude plugin update` rather than by copying.

**Architecture:** A new top-level `contributing/` directory holds three docs, the first directory here no stack owns. `scripts/build-skill-refs.sh` grows a second loop that copies it into `plugins/arch-core/reference/`, alongside the per-stack copies it already makes. A new `arch-contribute` skill routes to those copies and, like every other `arch-*` skill, prefers a consumer's own version when one exists. The ADR template gains the `## Compliance` section from ADR-0009, and `check-decisions.sh` grows the check that enforces it.

**Tech Stack:** POSIX shell (`sh`, not bash — the existing scripts are `#!/bin/sh` and `#!/usr/bin/env bash` respectively; match whichever file you are editing), Markdown, GitHub Actions, Claude Code plugin manifests.

**Spec:** `decisions/0008-contribution-doctrine.md`, `decisions/0009-adr-compliance-section.md`, `decisions/0010-prefer-existing-tooling-for-guards.md`, `decisions/0011-scope-decision-approval.md`

## Global Constraints

- Branch is `feat/contribution-doctrine`, already created, already carrying the four ADRs. Do not branch again.
- **No agent attribution in any commit.** No `Co-Authored-By: Claude`, no `Claude-Session:`, no "Generated with". This is ADR-0008 and it binds every commit in this plan.
- Conventional Commits. Subject imperative, lowercase after the type, no trailing dot. The 50-character limit applies to the description *after* `type(scope): `, matching the expression in Task 3 where `.{1,50}` governs that portion — not to the whole subject line. Scope is the plugin or area: `docs(core)`, `feat(core)`, `build(core)`.
- **ADRs 0001–0011 are immutable.** No task edits one. If a task seems to need an ADR changed, stop and report instead.
- Every ADR numbered 0009 or higher carries a non-empty `## Compliance`. That is what Task 1 enforces.
- Doctrine is written in general terms: no consumer repo names, no consumer file paths, no dated findings. `PATTERNS.md` states this and ADR-0006 decided it.
- Run `sh scripts/check-decisions.sh --strict`, `sh scripts/check-plugin-versions.sh` and `sh scripts/build-skill-refs.sh --check` before the final commit of any task that touched what they guard.
- `plugins/arch-core/reference/` is generated. Never hand-edit a file under it.

---

### Task 1: `## Compliance` in the ADR template, and the guard that enforces it

**Files:**
- Modify: `decisions/0000-template.md`
- Modify: `scripts/check-decisions.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: the `## Compliance` section contract every later ADR in every repo must satisfy. `check-decisions.sh --strict` gains a fifth `ok` line, `compliance sections present`, which Task 9's verification expects to see.

- [ ] **Step 1: Write the failing case first**

Create a synthetic ADR with no `## Compliance`, so the guard has something to catch:

The fixture id is built from a shell variable and never written as a literal
`ADR-` plus four digits. Check 5 of this same guard greps every `.md` in the
repo — this plan included — for such references and fails on any that do not
resolve to a file. A literal here would break the guard from inside the plan
that tests it.

```bash
cd ~/GitHub/exx0dusss/architectures
FIXTURE_ID=0099
cat > "decisions/${FIXTURE_ID}-guard-fixture.md" <<EOF
---
id: ${FIXTURE_ID}
title: Fixture used to prove the compliance check fails
date: 2026-08-19
status: Accepted
supersedes: []
superseded_by: []
tags: [fixture]
---

# ADR-${FIXTURE_ID} — Fixture used to prove the compliance check fails

## Context

Temporary fixture. Deleted in step 6.

## Decision

None.

## Consequences

None.

## Alternatives rejected

| Alternative | Why rejected |
|-------------|--------------|
| — | — |
EOF
printf '%s\n' "| [${FIXTURE_ID}](./decisions/${FIXTURE_ID}-guard-fixture.md) | 2026-08-19 | Fixture | Accepted | |" >/dev/null
```

Add its index row so the existing "index rows and ADR files are in step" check does not fire first and mask the one being added:

```bash
python3 - <<'PY'
import pathlib
p = pathlib.Path("DECISIONS.md"); s = p.read_text()
row = "| [0099](./decisions/0099-guard-fixture.md) | 2026-08-19 | Fixture | Accepted | |\n"
anchor = "| [0011](./decisions/0011-scope-decision-approval.md)"
assert anchor in s
p.write_text(s.replace(anchor, row + anchor, 1))
PY
```

- [ ] **Step 2: Run the guard and confirm it passes — which is the bug**

Run: `sh scripts/check-decisions.sh --strict`
Expected: `decision log OK`. The fixture has no `## Compliance` and the guard does not care. That is the gap this task closes.

- [ ] **Step 3: Add the check**

`check-decisions.sh` already loops `for f in $ADRS` in the section commented `--- 1. id matches filename; 4. superseded status; 6. stale Proposed ---`. Add a seventh check as its own section after that loop. Insert immediately before the line that reads `section "frontmatter, statuses and staleness checked ($(echo "$ADRS" | wc -l | tr -d ' ') ADRs)"` — if that exact line differs, insert after the loop that computes it and before the next `# ---` banner:

```sh
# --- 7. ADRs from 0009 carry a non-empty Compliance section ---------------
# ADR-0009 added the section; ADRs 0001-0008 predate it and are immutable, so
# the check starts at 0009 rather than failing the whole log.
for f in $ADRS; do
  base=$(basename "$f")
  fid=${base%%-*}
  # Shell compares 0009 and 0010 correctly as zero-padded strings of equal
  # width, but strip the padding anyway so the intent survives ids past 0999.
  num=$(echo "$fid" | sed 's/^0*//')
  [ -n "$num" ] || num=0
  [ "$num" -ge 9 ] || continue

  body=$(awk '/^## Compliance$/{f=1;next} /^## /{f=0} f' "$f" | tr -d '[:space:]')
  [ -n "$body" ] || fail "$base: ## Compliance is missing or empty (ADR-0009)"
done
section "compliance sections present"
```

- [ ] **Step 4: Run the guard and confirm it now fails**

Run: `sh scripts/check-decisions.sh --strict`
Expected: exit status 1, with the line
`FAIL  0099-guard-fixture.md: ## Compliance is missing or empty (ADR-0009)`

Confirm the exit status explicitly:

```bash
sh scripts/check-decisions.sh --strict; echo "exit=$?"
```

Expected: `exit=1`

- [ ] **Step 5: Prove the check accepts a filled section**

Append a Compliance section to the fixture, then re-run:

```bash
python3 - <<'PY'
import pathlib
p = pathlib.Path("decisions/0099-guard-fixture.md"); s = p.read_text()
s = s.replace("## Consequences", "## Compliance\n\n`Manual — no guard exists`.\n\n## Consequences", 1)
p.write_text(s)
PY
sh scripts/check-decisions.sh --strict; echo "exit=$?"
```

Expected: `exit=0`, and the output includes `ok    compliance sections present`.

- [ ] **Step 6: Delete the fixture and confirm the real log is clean**

```bash
rm decisions/0099-guard-fixture.md
python3 - <<'PY'
import pathlib
p = pathlib.Path("DECISIONS.md")
p.write_text("".join(l for l in p.read_text().splitlines(keepends=True) if "0099-guard-fixture" not in l))
PY
sh scripts/check-decisions.sh --strict; echo "exit=$?"
```

Expected: `exit=0`, `decision log OK`, `11 ADRs`, and `ok    compliance sections present` — ADRs 0009, 0010 and 0011 all carry the section already, 0001–0008 are skipped.

- [ ] **Step 7: Add the section to the template**

In `decisions/0000-template.md`, insert between the `## Consequences` block and the `## Alternatives rejected` block:

```md
## Compliance

Which fitness function governs this decision — a named `scripts/check-*` guard,
a CI job, or a linter rule. If none exists, write `Manual — no guard exists`
rather than describing an intention. A recorded gap can be counted; a claimed
guard that nobody wrote cannot be told apart from a real one.
```

- [ ] **Step 8: Verify the template still parses as an ADR**

The template is excluded from the guard by `! -name '0000-*'`, so confirm the exclusion still holds and nothing regressed:

```bash
sh scripts/check-decisions.sh --strict
grep -n '^## ' decisions/0000-template.md
```

Expected: guard passes; the `grep` prints `## Context`, `## Decision`, `## Consequences`, `## Compliance`, `## Alternatives rejected`, in that order.

- [ ] **Step 9: Commit**

```bash
git add decisions/0000-template.md scripts/check-decisions.sh
git commit -F - <<'EOF'
feat(core): require a compliance section on new ADRs

ADR-0009 added the section; this is the guard behind it. ADRs 0001-0008 are
immutable and predate it, so the check starts at 0009 rather than failing a
log nobody is allowed to fix.
EOF
```

---

### Task 2: `contributing/pull-requests.md`

**Files:**
- Create: `contributing/pull-requests.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the doc `arch-contribute` routes to for pull request work (Task 6), and a `PATTERNS.md` row (Task 8).

- [ ] **Step 1: Create the directory and the doc**

`contributing/` is new and no stack owns it. Write the file with exactly these sections, in this order. The rules below are the decisions already made — reproduce them; do not soften or extend them.

Required content, section by section:

1. **Intro, two sentences.** What the doc governs (the body of a pull request) and who it binds (anyone opening one, human or agent).

2. **`## The body`** — the four-part shape, each with its purpose stated:
   - `Closes <ISSUE-KEY>` or the repo's equivalent link line.
   - `## What changed` — one paragraph, what a reviewer needs before reading the diff.
   - `## Why` — the reasoning not visible in the diff: what was ruled out, what surprised you, what the originating ticket got wrong. Quote the principle that justifies it: *why is more important than how* — the Second Law of Software Architecture, Richards and Ford.
   - `## Verification` — pasted command output, never a claim. State this rule verbatim: **"A check that could not be run is named, with the reason. An honest gap beats an implied pass."**
   - `## Risk` — migrations, data changes, anything irreversible, anything needing an ops step after merge. Must say `none` rather than being left blank.

3. **`## Deleting sections`** — a section that does not apply is deleted. State: an empty heading is worse than no heading.

4. **`## Attribution`** — the description is written by the person opening the pull request. No agent attribution trailers in the body or in the commits it carries. Note that this matches the practice of the largest repositories surveyed, and give the reason: a description is a claim about work someone is accountable for.

5. **`## Stacked pull requests`** — when one branch targets another: bases retarget automatically as parents merge, so re-check the base before each merge; use a merge or rebase merge rather than a squash merge, because squashing a parent makes every child's diff show duplicated commits.

6. **`## What a guard checks`** — name the fitness functions from ADR-0010 without pinning versions: `danger` for body structure, non-blank `## Risk`, and unchecked boxes; `amannn/action-semantic-pull-request` for the title. State that a repository with neither is running on trust, and that this is a recordable gap, not a hidden one.

- [ ] **Step 2: Verify no consumer leaks in**

```bash
cd ~/GitHub/exx0dusss/architectures
grep -niE '<consumer-repo-names>|<consumer-org-names>|[A-Z]{2,4}-[0-9]' contributing/pull-requests.md
```

Expected: no output. A hit means a consumer name or ticket key leaked into blueprint doctrine, which ADR-0006 forbids. A real project prefix appearing as an *example* issue key is still a leak — use `PROJ-123`.

- [ ] **Step 3: Commit**

```bash
git add contributing/pull-requests.md
git commit -F - <<'EOF'
feat(core): add the pull request body doctrine

Verification carries pasted output rather than a checked box, and Risk states
none rather than staying blank. Both come from the consumer that solved this
first; the reasoning behind Why is the Second Law.
EOF
```

---

### Task 3: `contributing/commits.md`

**Files:**
- Create: `contributing/commits.md`

**Interfaces:**
- Consumes: `contributing/pull-requests.md` (Task 2) — this doc links to it for where long reasoning goes.
- Produces: the doc `arch-contribute` routes to for commit messages (Task 6), and a `PATTERNS.md` row (Task 8).

- [ ] **Step 1: Write the doc**

Required content:

1. **`## Subject`** — Conventional Commits. Give the matching expression so the rule is unambiguous:

```
/^(revert: )?(feat|fix|docs|style|refactor|perf|test|build|ci|chore)(\(.+\))?!?: .{1,50}/
```

State each rule the expression does not carry: imperative present tense ("change", not "changed" or "changes"); no capital after the type; no trailing dot; scope names the area, not the ticket.

2. **`## Body`** — a body only when the reason is not already visible in the diff. Reasoning that runs long belongs in the pull request, which is read once at review time; a commit body is read years later by someone bisecting. Cite the Second Law once, and do not repeat it from `pull-requests.md`.

3. **`## Trailers`** — no agent attribution trailers. `Co-Authored-By` for a human collaborator is unaffected.

4. **`## What a guard checks`** — `@commitlint/cli` with `@commitlint/config-conventional`, run in CI. Note it cannot check imperative mood or whether a body was warranted; those stay human.

- [ ] **Step 2: Verify the expression is correct by testing it**

```bash
cd ~/GitHub/exx0dusss/architectures
python3 - <<'PY'
import re
rx = re.compile(r"^(revert: )?(feat|fix|docs|style|refactor|perf|test|build|ci|chore)(\(.+\))?!?: .{1,50}")
cases = [
    ("feat(core): add the pull request body doctrine", True),
    ("fix: resolve the permission decorator", True),
    ("perf(build)!: remove the foo option", True),
    ("revert: feat(core): add the doctrine", True),
    ("Feat(core): capitalised type", False),
    ("chore: ", False),
    ("added a thing", False),
]
bad = [(s, want) for s, want in cases if bool(rx.match(s)) != want]
print("MISMATCH", bad) if bad else print("expression OK")
PY
```

Expected: `expression OK`. If it prints `MISMATCH`, the expression pasted into the doc is wrong — fix the doc, not the test.

- [ ] **Step 3: Verify this repo's own history mostly complies**

```bash
git log --format='%s' -40 | grep -cvE '^(revert: )?(feat|fix|docs|style|refactor|perf|test|build|ci|chore)(\(.+\))?!?: .{1,50}'
```

Expected: a small number. Merge commits (`Merge pull request #11 from …`) legitimately fail and are not a problem — confirm any other failures are merges before moving on:

```bash
git log --format='%s' -40 | grep -vE '^(revert: )?(feat|fix|docs|style|refactor|perf|test|build|ci|chore)(\(.+\))?!?: .{1,50}'
```

- [ ] **Step 4: Commit**

```bash
git add contributing/commits.md
git commit -F - <<'EOF'
feat(core): add the commit message doctrine

Carries the matching expression so the subject rule is unambiguous, and says
where long reasoning goes instead: a commit body is read while bisecting, a
pull request body is read once at review.
EOF
```

---

### Task 4: `contributing/comments.md`

**Files:**
- Create: `contributing/comments.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the doc `arch-contribute` routes to for comment work (Task 6), a `PATTERNS.md` row (Task 8), and the banned-term list that consumer ESLint configs copy into `no-warning-comments`.

- [ ] **Step 1: Write the doc**

Required content:

1. **`## The reader`** — a contributor reading the code at HEAD, months later, with no access to the conversation, the pull request, the issue, or the diff. Two consequences follow and must be stated as consequences, not as separate rules: never narrate change history, and never address the reviewer.

2. **`## Three kinds, three jobs`** — a table:

| Kind | Syntax | Job | Carries |
|---|---|---|---|
| Module overview | `/** */` at the top of the file | Explanation | Why the module exists, the concepts it defines, design rationale |
| Item docs | `/** */` above a declaration | Reference | The contract: behaviour, parameters, return, thrown errors, invariants |
| Inline | `//` inside a body | Rationale | Only what the code cannot say: constraints, workarounds, non-obvious coupling |

State that the jobs do not mix: implementation detail does not go in the contract, and the contract does not get scattered across inline comments.

3. **`## The deletion test`** — before writing any comment, ask whether it states something the reader cannot recover from the code. If names, types or structure already carry it, do not write it; if the name fails to carry it, fix the name. State explicitly: **there is no line limit.** A long comment that passes the test stays. Length is a symptom, not the disease.

4. **`## Banned`** — each with a one-line reason:
   - Narrating the next line.
   - Change-history narration — `now`, `previously`, `no longer`, `the new approach`. Meaningless at HEAD, where only one approach exists.
   - Reviewer-addressed justification — `this correctly handles…`. That argument belongs in the pull request; the comment must justify the code permanently.
   - Restated declarations — a `/** */` that rewords the function name says nothing.
   - Vague hedging — `some cases`, `various reasons`, `handles edge cases`, `etc.` Name them or drop the sentence.
   - Emoji.
   - Ad-hoc section banners. If a file is long enough to want one, split the file.

5. **`## Workarounds`** — a comment explaining a workaround, a hack or a dependency's surprising behaviour must link the issue or pull request that motivates it. State the reason verbatim: **a workaround with no link is indistinguishable from a mistake.**

6. **`## Editing existing comments`** — when a change makes a comment false, fix it in the same diff. Do not replace specific prose with generic text; extend or correct it. Do not rewrite comments your change did not touch.

7. **`## What a guard checks`** — per ADR-0010: ESLint core `no-warning-comments` covers the banned terms and TODO, matching whole words, case-insensitively, accepting multi-word terms, with `location: "anywhere"`. `eslint-plugin-jsdoc` covers contract shape. Give the configuration a consumer copies:

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

State what no rule covers: emoji in source, and the deletion test itself, which is a judgement no linter makes.

- [ ] **Step 2: Prove the ESLint terms behave as documented**

The claim that matching is whole-word and case-insensitive is load-bearing — if `no longer` matched inside another word the rule would be unusable. Verify against the installed ESLint in a consumer rather than trusting the doc:

```bash
cd <the monorepo consumer's frontend package>
cat > /tmp/eslint-comment-probe.mjs <<'EOF'
import { Linter } from "eslint";
const linter = new Linter();
const opts = { terms: ["previously", "no longer", "this correctly"], location: "anywhere" };
const cases = [
  ["// Previously this returned null.", 1],
  ["// The cache is no longer warm here.", 1],
  ["// nolongerword should not match", 0],
  ["// preview of the layout", 0],
];
for (const [code, want] of cases) {
  const got = linter.verify(code, { rules: { "no-warning-comments": ["error", opts] } }).length;
  console.log(got === want ? "ok  " : "FAIL", JSON.stringify(code), `got=${got} want=${want}`);
}
EOF
bunx --bun node /tmp/eslint-comment-probe.mjs || node /tmp/eslint-comment-probe.mjs
```

Expected: four `ok` lines. Any `FAIL` means the configuration in the doc is wrong — correct the doc before committing, and record what actually happened.

- [ ] **Step 3: Clean up the probe**

```bash
rm -f /tmp/eslint-comment-probe.mjs
```

- [ ] **Step 4: Commit**

```bash
cd ~/GitHub/exx0dusss/architectures
git add contributing/comments.md
git commit -F - <<'EOF'
feat(core): add the code comment doctrine

The rule is the deletion test, not a line limit: a comment earns its place by
stating what the code cannot. Banned patterns are the ones a reader at HEAD
cannot use — change history, reviewer address, restated declarations.
EOF
```

---

### Task 5: Bundle `contributing/` into the plugin reference

**Files:**
- Modify: `scripts/build-skill-refs.sh`
- Create (generated): `plugins/arch-core/reference/contributing/pull-requests.md`, `.../commits.md`, `.../comments.md`

**Interfaces:**
- Consumes: the three docs from Tasks 2–4.
- Produces: `${CLAUDE_PLUGIN_ROOT}/reference/contributing/*.md`, the paths Task 6's skill routes to.

- [ ] **Step 1: Confirm the reference is currently in sync**

Run: `sh scripts/build-skill-refs.sh --check`
Expected: `skill refs: IN SYNC`. If it reports STALE, stop — something earlier in the branch edited a stack doc without regenerating, and that must be resolved first.

- [ ] **Step 2: Add the shared loop**

`build-skill-refs.sh` defines `STACKS="nextjs tanstack-start nestjs-backend"` and loops it. Add a second variable beside it:

```sh
SHARED="contributing"
```

Then, after the existing `for stack in $STACKS; do … done` loop and before the `cat > "$DEST/README.md"` heredoc, add:

```sh
# Stack-agnostic doctrine. No README to skip here — every file is doctrine.
for dir in $SHARED; do
    src="$ROOT/$dir"
    [ -d "$src" ] || { echo "missing shared dir: $dir" >&2; exit 1; }

    out="$DEST/$dir"
    rm -rf "$out"
    mkdir -p "$out"

    for f in "$src"/*.md; do
        [ -e "$f" ] || continue
        cp "$f" "$out/"
    done
done
```

Also extend the generated `reference/README.md` heredoc so it does not describe only stacks. Change the line reading `Edit the source (`nextjs/`, `tanstack-start/`, `nestjs-backend/`) and re-run the script.` to:

```
Edit the source (`nextjs/`, `tanstack-start/`, `nestjs-backend/`, `contributing/`) and re-run
the script.
```

- [ ] **Step 3: Confirm the guard now reports STALE**

Run: `sh scripts/build-skill-refs.sh --check; echo "exit=$?"`
Expected: `exit=1` and `skill refs: STALE — run 'sh scripts/build-skill-refs.sh' and commit`. The script now knows about a directory the committed reference does not contain, which is exactly the state the guard exists to catch.

- [ ] **Step 4: Regenerate**

Run: `sh scripts/build-skill-refs.sh`
Expected: `skill refs: regenerated into plugins/arch-core/reference/`

- [ ] **Step 5: Confirm the copies landed and are verbatim**

```bash
ls plugins/arch-core/reference/contributing/
diff contributing/comments.md plugins/arch-core/reference/contributing/comments.md && echo "verbatim OK"
sh scripts/build-skill-refs.sh --check
```

Expected: three files listed; `verbatim OK`; `skill refs: IN SYNC`.

- [ ] **Step 6: Commit**

```bash
git add scripts/build-skill-refs.sh plugins/arch-core/reference/
git commit -F - <<'EOF'
build(core): bundle the contributing docs into the reference

contributing/ is the first source directory no stack owns, so the ref builder
grows a second loop rather than pretending it is a stack.
EOF
```

---

### Task 6: The `arch-contribute` skill

**Files:**
- Create: `plugins/arch-core/skills/arch-contribute/SKILL.md`

**Interfaces:**
- Consumes: `reference/contributing/*.md` from Task 5.
- Produces: the skill name `arch-contribute`, which Task 8 lists in `PATTERNS.md` and Task 9 names in the README table.

- [ ] **Step 1: Read a sibling skill for house style**

Run: `cat plugins/arch-core/skills/arch-decision/SKILL.md`

Match its shape exactly: YAML frontmatter with `name`, `description` and `stacks`; a one-paragraph statement of why the skill exists; a trigger list; a "when a plain commit is enough"-style negative section; a red-flag table; numbered steps; a `## Report` section. Do not invent a new layout.

- [ ] **Step 2: Write the skill**

Frontmatter:

```yaml
---
name: arch-contribute
description: Use when opening a pull request, writing a commit message, or writing or editing comments in source — including comments added incidentally while fixing a bug. Routes to the contribution doctrine and names the fitness functions that guard it.
stacks: [nextjs, tanstack-start, nestjs-backend]
---
```

Body requirements:

- **Why it exists.** A pull request body, a commit message and a comment are the three artefacts a contributor produces that no compiler checks. Left unstated they get invented per repository.
- **Triggers** — opening or updating a pull request; writing a commit message; writing or editing a comment; being asked how to describe a change.
- **Routing table** — which doc answers which question:

| Working on | Read |
|---|---|
| A pull request body | `reference/contributing/pull-requests.md` |
| A commit message | `reference/contributing/commits.md` |
| Comments in source | `reference/contributing/comments.md` |

- **Consumer precedence.** If the repository has its own `docs/conventions/pull-requests.md`, `commits.md` or `comments.md`, that file wins for the topic it covers. State the reason: a consumer's copy records a deliberate local deviation, and the blueprint yields to it rather than overriding it silently. This matches every other `arch-*` skill.
- **Red flags** — a table in the house format. At minimum:

| Thought | Reality |
|---------|---------|
| "The diff explains itself, skip the Why" | The diff shows what changed. Why is what a reader cannot reconstruct. |
| "I ran the checks, I will tick the boxes" | Verification carries pasted output. A tick is a claim, not evidence. |
| "This comment explains what the change fixes" | The reader is at HEAD and has no diff. Describe the code, not the change. |
| "Risk is obviously none, leave it blank" | Blank reads as unconsidered. Write `none`. |
| "I will note the workaround and link the issue later" | A workaround with no link is indistinguishable from a mistake. |

- **Steps** — check which artefact is being written; read the matching doc, preferring the repo's own; apply it; before finishing, re-read only the comments in the diff in isolation and delete what fails the deletion test.
- **Report** — which doc was applied, whether the repo's own copy took precedence, and which fitness functions ran.

- [ ] **Step 3: Verify the frontmatter parses and the routing paths resolve**

```bash
cd ~/GitHub/exx0dusss/architectures
head -6 plugins/arch-core/skills/arch-contribute/SKILL.md
for f in pull-requests commits comments; do
  test -f "plugins/arch-core/reference/contributing/$f.md" && echo "ok  $f" || echo "FAIL $f"
done
```

Expected: frontmatter shows `name: arch-contribute`; three `ok` lines. A `FAIL` means Task 5 did not run.

- [ ] **Step 4: Commit**

```bash
git add plugins/arch-core/skills/arch-contribute/
git commit -F - <<'EOF'
feat(core): add the arch-contribute skill

Routes the three contribution artefacts to their doctrine and yields to a
consumer's own copy, the same precedence every other arch-* skill uses.
EOF
```

---

### Task 7: Name the fitness function categories

**Files:**
- Modify: `plugins/arch-core/skills/arch-decision/SKILL.md`
- Modify: `plugins/arch-core/skills/arch-init/SKILL.md`
- Modify: `PATTERNS.md`

**Interfaces:**
- Consumes: the `## Compliance` contract from Task 1.
- Produces: the term *fitness function*, used consistently, which Task 8's `PATTERNS.md` rows rely on.

This task deliberately has no ADR. `arch-decision` lists "expanding a doc" under when a plain commit is enough, and naming the categories expands ADR-0009's vocabulary without reversing anything.

- [ ] **Step 1: Add the Compliance step to `arch-decision`**

The numbered steps currently run 1–9, with step 5 `Alternatives rejected` and step 6 the supersede chain. Insert a new step between them, renumbering the rest:

```md
6. **Name the fitness function.** `## Compliance` says which mechanism governs the decision —
   a `scripts/check-*` guard, a CI job, or a linter rule. A fitness function is any mechanism
   that evaluates whether a solution still meets its intent; static analysis is the common kind
   here, and a runtime monitor or a tracked metric is equally one. If nothing governs it, write
   `Manual — no guard exists`, which is a countable gap rather than a fabricated guard.
```

Renumber the steps that followed so the list runs 1–10 with no repeats.

- [ ] **Step 2: Name the term in `arch-init`**

In the target-layout block, the line currently reads:

```
scripts/check-*.ts       # a CI guard for every mechanically-checkable rule
```

Replace with:

```
scripts/check-*.ts       # a fitness function for every mechanically-checkable rule
                         # — prefer an existing linter rule or tool over a new script
```

Add one sentence beneath the block: a fitness function is any mechanism that evaluates whether the code still meets its intent, and per ADR-0010 an existing tool is preferred over a bespoke script wherever one covers the rule.

- [ ] **Step 3: Name the term in `PATTERNS.md`**

In the preamble, after the paragraph explaining the `Decisions` column, add one sentence: guards in `scripts/` are fitness functions in the sense ADR-0009 adopted, and each decision's `## Compliance` names the one that governs it.

- [ ] **Step 4: Verify the renumbering is intact**

```bash
cd ~/GitHub/exx0dusss/architectures
grep -nE '^[0-9]+\. \*\*' plugins/arch-core/skills/arch-decision/SKILL.md
```

Expected: a contiguous run `1.` through `10.` with no duplicates and no gaps.

- [ ] **Step 5: Regenerate the reference and verify**

The stack docs were not touched, but run the guard anyway — `PATTERNS.md` is not bundled, and this confirms nothing drifted:

```bash
sh scripts/build-skill-refs.sh --check
sh scripts/check-decisions.sh --strict
```

Expected: `skill refs: IN SYNC` and `decision log OK`.

- [ ] **Step 6: Commit**

```bash
git add plugins/arch-core/skills/arch-decision/SKILL.md plugins/arch-core/skills/arch-init/SKILL.md PATTERNS.md
git commit -F - <<'EOF'
docs(core): name guards as fitness functions

ADR-0009 adopted the term and only ever meant static analysis. Names the wider
categories so a later runtime guard has somewhere to belong, and adds the
Compliance step arch-decision was missing.
EOF
```

---

### Task 8: Register the new docs and skill in `PATTERNS.md`

**Files:**
- Modify: `PATTERNS.md`
- Modify: `DECISIONS.md`

**Interfaces:**
- Consumes: Tasks 2, 3, 4, 6.
- Produces: the registry rows Task 9's release depends on being complete.

- [ ] **Step 1: Add the skill row**

In the `## Skills (all stacks)` table, add in alphabetical position among the `arch-*` entries:

```md
| arch-contribute | `plugins/arch-core/skills/arch-contribute/SKILL.md` | stable | ADR-0008, ADR-0010 |
```

- [ ] **Step 2: Add a section for the new docs**

`PATTERNS.md` sections are per-stack. `contributing/` is not. Add a new section immediately after `## Skills (all stacks)` and before `## Agents (all stacks)`:

```md
## Contribution doctrine (all stacks)

Stack-agnostic — the artefacts a contributor produces that no compiler checks. Bundled into the
plugin by `scripts/build-skill-refs.sh` and routed by `arch-contribute`.

| Pattern | File | Status | Decisions |
|---------|------|--------|-----------|
| Pull request body | `contributing/pull-requests.md` | stable | ADR-0008, ADR-0011 |
| Commit messages | `contributing/commits.md` | stable | ADR-0008 |
| Code comments | `contributing/comments.md` | stable | ADR-0008, ADR-0010 |
```

- [ ] **Step 3: Fill the Links column on the new ADR rows**

The four ADR rows added on this branch have an empty final column. Fill each with the `PATTERNS.md` rows it now governs, matching how existing rows express relationships:

- 0008 → `contributing/*`
- 0009 → `decisions/0000-template.md`
- 0010 → `contributing/comments.md`, `scripts/check-decisions.sh`
- 0011 → `—` (it governs ownership, not a pattern row)

- [ ] **Step 4: Verify every referenced file exists**

```bash
cd ~/GitHub/exx0dusss/architectures
grep -oE '`[^`]+\.(md|sh|ts)`' PATTERNS.md | tr -d '`' | sort -u | while read -r f; do
  [ -e "$f" ] || echo "MISSING $f"
done
```

Expected: no `MISSING` lines.

- [ ] **Step 5: Run both guards**

```bash
sh scripts/check-decisions.sh --strict
sh scripts/build-skill-refs.sh --check
```

Expected: `decision log OK` and `skill refs: IN SYNC`. The decisions guard resolves every `ADR-NNNN` reference, so the new `PATTERNS.md` mentions are checked here.

- [ ] **Step 6: Commit**

```bash
git add PATTERNS.md DECISIONS.md
git commit -F - <<'EOF'
docs(core): register the contribution docs and arch-contribute

Every doc needs an owner and a status, and contributing/ is the first section
that is not per-stack.
EOF
```

---

### Task 9: Release `arch-core` 1.5.0

**Files:**
- Modify: `plugins/arch-core/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `README.md`

**Interfaces:**
- Consumes: Tasks 1–8.
- Produces: `arch-core` 1.5.0, the version consumer plans pin against.

- [ ] **Step 1: Bump the plugin manifest**

In `plugins/arch-core/.claude-plugin/plugin.json`, change `"version": "1.4.1"` to `"version": "1.5.0"`. Minor, not patch: new skill and new doctrine, no breaking change.

Add `"contributing"` to the `keywords` array, after `"conventions"`.

- [ ] **Step 2: Bump the marketplace manifest**

In `.claude-plugin/marketplace.json`, change the `arch-core` entry's `"version"` to `"1.5.0"`, and `metadata.version` to `"1.5.0"`.

Extend the `arch-core` `description` so it names the new surface. Change the phrase `the arch-decision ADR workflow` to `the arch-decision ADR workflow, the arch-contribute contribution doctrine`.

- [ ] **Step 3: Run the version guard**

Run: `sh scripts/check-plugin-versions.sh; echo "exit=$?"`
Expected: `exit=0`. This is the guard written after the manifests disagreed once and left consumers reporting BEHIND forever — a non-zero exit here means the two files do not match.

- [ ] **Step 4: Add the skill to the README table**

In `README.md`, the `## Skills` section says `arch-core` ships seven doctrine skills. It is now eight — update that sentence. Add to the table, after the `arch-decision` row:

```md
| `arch-contribute` | Pull request bodies, commit messages, comments in source | all |
```

- [ ] **Step 5: Run every guard together**

```bash
cd ~/GitHub/exx0dusss/architectures
sh scripts/check-decisions.sh --strict
sh scripts/check-plugin-versions.sh
sh scripts/build-skill-refs.sh --check
```

Expected, in order: `decision log OK` including `ok    compliance sections present`; the version guard exiting 0; `skill refs: IN SYNC`. All three must pass before committing. If any fails, fix it in this task rather than deferring.

- [ ] **Step 6: Verify the count claims in the README are true**

```bash
ls -d plugins/arch-core/skills/*/ | wc -l
grep -c '^| `arch-\|^| arch-' README.md
```

Expected: the directory count is 10 (eight `arch-*` skills plus `arch-init` and `promote-pattern`); confirm the README sentence you edited in step 4 matches what is actually on disk rather than what this plan guessed. Correct the sentence to the real number.

- [ ] **Step 7: Commit**

```bash
git add plugins/arch-core/.claude-plugin/plugin.json .claude-plugin/marketplace.json README.md
git commit -F - <<'EOF'
chore(core): arch-core 1.4.1 -> 1.5.0

Adds the contribution doctrine and the arch-contribute skill. Minor: new
surface, nothing removed or renamed.
EOF
```

- [ ] **Step 8: Open the pull request**

Use the doctrine this branch just wrote — that is the first real test of it:

```bash
git push -u origin feat/contribution-doctrine
gh pr create --title "feat(core): contribution doctrine and arch-contribute" --body-file - <<'EOF'
## What changed

Adds stack-agnostic contribution doctrine — pull request bodies, commit
messages, code comments — as `contributing/`, routed by a new `arch-contribute`
skill and bundled into the plugin reference. The ADR template gains the
Compliance section from ADR-0009, and `check-decisions.sh` enforces it from
ADR-0009 onward.

## Why

ADR-0004 fixed the instruction layout and left the artefacts a contributor
produces unowned, so two consumer repos invented two different answers. The
parts that were open — whether to cap comment length, whether to gate merges on
checkboxes, whether to write guards by hand — are settled in ADR-0008 and
ADR-0010 against a survey of nine reference repositories, none of which gates on
checkboxes and one of which has the only written comment policy among them.

## Verification

```
$ sh scripts/check-decisions.sh --strict
<paste the real output>

$ sh scripts/check-plugin-versions.sh
<paste the real output>

$ sh scripts/build-skill-refs.sh --check
<paste the real output>
```

## Risk

none. No consumer is affected until it runs `claude plugin update`, and the two
consumer adoptions are planned separately against 1.5.0.
EOF
```

Replace each `<paste the real output>` with the actual command output before creating the pull request. A body claiming a check ran without its output is the exact failure this branch's own doctrine bans.

---

## Self-Review

**Spec coverage.** ADR-0008: `contributing/` docs (Tasks 2–4), `arch-contribute` (Task 6), bundling (Task 5) — covered. ADR-0009: `## Compliance` in the template and the guard (Task 1), fitness-function vocabulary (Task 7) — covered. ADR-0010: the guard mapping is written into each doc's "What a guard checks" section (Tasks 2–4), and `check-decisions.sh` is kept (Task 1 extends rather than replaces it) — covered. ADR-0011: the approval criteria are consumer-facing and land in the consumer plans, not here; this plan's only obligation is not contradicting them, and no task adds a repository-root file to a consumer. Noted as deliberate, not a gap.

**Placeholders.** The `<paste the real output>` markers in Task 9 Step 8 are instructions to the executor to substitute real output, with the reason stated, not unfinished plan content. Everything else carries literal commands and literal file content.

**Type consistency.** `SHARED` is defined in Task 5 Step 2 and used only there. The `section "compliance sections present"` string introduced in Task 1 Step 3 is the same string Task 9 Step 5 expects to see. The skill name `arch-contribute` is identical in Tasks 6, 8 and 9. Reference paths are `plugins/arch-core/reference/contributing/<name>.md` in Tasks 5, 6 and 8 with no variation.

**Known soft spot.** Task 1 Step 3 describes an insertion point in `check-decisions.sh` by quoting a nearby line, because the file's exact line numbers shift as it is edited. The executor must read the script and place the block after the frontmatter loop; the instruction says so rather than pretending a line number will hold.

**Not in this plan.** The two consumer adoptions (the monorepo consumer, the CRM consumer) and the layer-doctrine fitness function ADR-0010 names as still missing. Both are separate plans; neither is blocked by anything here beyond 1.5.0 existing.
