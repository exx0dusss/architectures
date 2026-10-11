# Scope verification to the change

Agents verify after every turn, and several agents often share one machine. Whole-app test
suites, a full typecheck and repo-wide lint after each edit hold the machine at a load where every
runner result is unreliable. Contention manufactures failures shaped exactly like real defects —
timeouts, flaky assertions, leaked DOM — and each one costs an investigation. It never hides a
real bug, so the cost is all false reds.

## What runs when

| When | Run |
|---|---|
| Each turn, as often as useful | Lint on the changed files, plus the tests whose import graph reaches a changed file |
| Once, before pushing | The above, plus an incremental whole-program typecheck of every touched workspace and every workspace that depends on a touched package |
| At the tip of a stack before merge, or on request | The full suites, once, on a quiet machine |
| UI prototyping | Nothing — open the page and look |

- **The changed set** is the diff against the merge-base with the base branch, plus staged,
  unstaged and untracked files. A stacked branch diffs against its parent branch, not the default
  branch. Generated output is not part of it.
- **Lint scopes safely to files** only when every rule is per-file. A type-aware rule can change
  verdict on a file the diff never touched; run those workspace-wide before pushing.
- **"No related tests" is a gap, not a pass.** When nothing imports the changed module from a
  test, say so in the report.
- **A hub module relates to most of the suite.** Changing a schema or a shared UI primitive
  legitimately selects hundreds of tests. Run that once, not per turn, and inspect the plan first.

## Never typecheck per file

`tsc a.ts b.ts` compiles those files and whatever they import. It never sees the files that
import them, so a signature change that breaks every caller passes — a false green on exactly the
change most likely to break the build. Naming files on the command line also drops the tsconfig
(`paths`, `jsx`, `lib`, `types`), so it reports errors the real build does not have — a false red.
The only safe way to make the typecheck cheap is to keep the whole program and make re-runs
incremental, with a build-info file kept per worktree so parallel checkouts do not overwrite each
other's cache.

## One heavy job at a time

A typecheck or a full test run can take several gigabytes. Several of them started at once next
to containers and dev servers push the machine into swap and stall everyone. Run heavy jobs —
full typecheck, full suites — under one machine-wide lock so only one is active and the rest wait.
Edits, reads, changed-file lint and related tests stay parallel and take no lock.

File locks are usually not re-entrant: a heavy job started by a script that already holds the
lock waits forever on its own parent and stalls every other heavy job behind it. A runner that
takes the lock itself must detect that an ancestor holds it — an inherited environment flag set by
whoever took the lock, or an ancestor lock process on the same file — and skip re-acquiring. Do
not wrap such a runner in the lock again; it then holds the lock for its unlocked steps too.

## A red needs isolation before it is a defect

A scoped run lowers load; it does not remove other people's. Before filing a timeout-shaped or
flaky failure, re-run only the failing file on a quiet machine — load average below the core
count. A failure that reproduces in isolation is real; one that only fails under load proves
nothing. A suspected flake is settled by repeated paired runs counted on both arms, never by one
green run.
