---
name: arch-init
description: Use when setting up a repository to follow the exx0dusss/architectures blueprint, when the user asks to initialize, bootstrap, or re-sync a project's architecture dev environment, or when a repo built on the blueprint is missing its AGENTS.md index, settings permissions, component registry, or required third-party skills.
stacks: [nextjs, tanstack-start, nestjs-backend]
---

# Architecture init

Bootstraps a target project to follow the `exx0dusss/architectures` blueprint.

**Most of what this skill used to do is now the plugin's job.** Installing the `arch-<stack>`
plugin already delivers the doctrine skills, the scaffolding and audit agents, and the hook
config, and `claude plugin update` re-syncs them. This skill covers only what a plugin cannot
touch: files inside the consumer repo, and tooling installed from elsewhere.

## Prerequisite — the plugin

Confirm the stack plugin is installed before doing anything else:

```bash
claude plugin marketplace add exx0dusss/architectures
claude plugin install arch-nextjs@architectures --scope project          # or
claude plugin install arch-tanstack-start@architectures --scope project  # or
claude plugin install arch-nestjs-backend@architectures --scope project
```

`--scope project` writes to `.claude/settings.json`, so the whole team picks it up from git.
Each stack plugin depends on `arch-core`; if the dependency does not resolve automatically,
install `arch-core@architectures` as well.

## Phase 1 — detect and confirm

Detect the stack from `package.json`:

| Dependency | Stack |
| --- | --- |
| `@tanstack/react-start` | `tanstack-start` |
| `next` | `nextjs` |
| `@nestjs/core` | `nestjs-backend` |

Report the detected stack and the plugin that should be installed. Confirm with the user before
writing anything.

## Phase 2 — the instruction index

The consumer repo owns its own instruction files. The blueprint does not overwrite them, because
they describe *this project's instantiation* — its real folder layout, middleware, ports, and
commands — not generic doctrine. Doctrine arrives through the plugin's skills.

Target layout:

```
CLAUDE.md                # exactly one line: @AGENTS.md
AGENTS.md                # the index — project overview, then:
                         #   @import per always-loaded docs/conventions/*.md
                         #   a "read before work" table for docs/patterns/*.md
docs/conventions/*.md    # ONE topic per file, always loaded
docs/patterns/*.md       # heavyweight specs, loaded on demand
scripts/check-*.ts       # a fitness function for every mechanically-checkable rule
                         # — prefer an existing linter rule or tool over a new script
```

A fitness function is any mechanism that evaluates how well a solution performs against a
desired outcome; per ADR-0010, an existing tool is preferred over a bespoke script wherever one
covers the rule.

Keep in `docs/conventions/` (always loaded) only what is specific to this project: its stack
table, its real folder layout, its commands and branch policy, its safety rules. Anything that is
generic blueprint doctrine — the service file contract, state layering, component layers and
tokens, auth enforcement — should **not** be duplicated there; the `arch-*` skills carry it and
load on demand.

Report what is missing rather than silently generating it, then offer to write each piece.

## Phase 3 — required third-party skills

The plugin cannot install skills from other sources. Check `~/.claude/skills/` and install what
is missing:

**All stacks**

| Skill | Source |
| --- | --- |
| `web-design-guidelines` | `vercel-labs/agent-skills` |
| `vercel-composition-patterns` | `vercel-labs/agent-skills` |
| `ui-audit` | `mblode/agent-skills` |
| `review-pr` | `mblode/agent-skills` |
| `ui-design-review` | `mastepanoski/claude-skills` |

**Frontend stacks only**

| Skill | Source |
| --- | --- |
| `frontend-design` | `anthropics/skills` |

```bash
npx skills add <source> -g -y
```

Report installed versus already present.

## Phase 4 — settings and registry

- **Permissions.** Merge the stack's allow/deny lists into `.claude/settings.json` if absent. Never overwrite existing entries.
- **MCP servers.** Check for `shadcn` and `context7`; report and offer to enable what is missing.
- **Component registry.** For frontend stacks, check `components.json` names the project's registry.
- **TanStack Start only.** Run `npx @tanstack/intent@latest install` and verify the intent skills table lands in the instruction index.

## Phase 5 — record the blueprint version, then check it is actually in use

Run the sync check from this plugin:

```bash
sh "${CLAUDE_PLUGIN_ROOT}"/scripts/arch-sync-check.sh --write
```

It answers two questions and writes both to `.claude/blueprint-sync.json`. Commit that file — it
makes "which blueprint is this repo on" answerable from git rather than from someone's terminal.

1. **Registrations** — effective user/project/local settings and project/worktree installation
   records, not the highest machine cache. States: `CURRENT`, `BEHIND`, `AHEAD`, `MISSING`,
   `INVALID`, `UNKNOWN`. `--strict` rejects every non-current registration. The report does not
   prove live session loading; verify capabilities in a fresh session. The resolver supports
   Claude only; use a runtime-specific resolver for other hosts rather than inferring parity.
2. **Shadowing** — project-level `.claude/agents/<name>.md` files that override a plugin agent of
   the same name. Project agents win, so a vendored copy silently disables the plugin's version.
   `DUPLICATE` is byte-identical and safe to delete; `FORK` differs and needs a ruling.

**Version equality is not sync.** A repo can report every plugin `CURRENT` while every plugin
agent is shadowed by a stale local copy and the plugins do nothing at all. If the script reports
any `FORK`, or the repo predates the plugins, run the drift audit:

```
Use the arch-drift agent to audit this repo against the installed blueprint.
```

It rules on each `FORK` (stale ancestor to delete, or a real local patch to promote), and finds
what no script can: doctrine duplicated into always-loaded conventions, local rules that now
contradict current doctrine, and conventions with no CI guard.

Pass `--strict` to exit non-zero when anything is `BEHIND` or shadowed; that is the form to put in
CI if the team wants a gate on blueprint currency.

The check lives here, on the consumer side, because the consumer is what depends on the
blueprint. The blueprint repo tracks no consumers and holds no pointers to them.

## Phase 6 — report

```
Architecture Init — <stack> — Status Report
════════════════════════════════════════════

Stack plugin:       ✅ arch-<stack>@architectures (project scope)
Doctrine skills:    ✅ via plugin — arch-services, arch-state, arch-ui, arch-auth, arch-forms,
                       arch-modules (backend only)
Agents:             ✅ via plugin (<n> agents)
Instruction index:  ⚠️  AGENTS.md missing the patterns trigger table
Third-party skills: ✅ all 6 installed
Permissions:        ✅ merged
MCP servers:        ✅ shadcn + context7
Registry:           ✅ connected
Blueprint version:  ✅ arch-core 1.1.0 (current)
Shadowed agents:    ⚠️  3 FORK, 1 DUPLICATE — run the arch-drift agent
```

## Re-syncing

Doctrine and agents re-sync with `claude plugin update`, then re-run `arch-sync-check.sh` to
refresh `.claude/blueprint-sync.json`. Re-run this skill only to re-check the consumer-owned
pieces: the instruction index, permissions, registry, third-party skills.

`claude plugin update` moves doctrine underneath conventions that were written against the old
version, and nothing errors when it does. That is the drift the `arch-drift` agent exists to
catch — run it after any update that bumps a doctrine skill.

## Promoting a pattern back

When a pattern proves itself here and a second project is about to copy it, promote it to the
blueprint **first**, then reference it from both. Add it to the right stack doc, give it a row in
`PATTERNS.md`, and run `sh scripts/build-skill-refs.sh` there so the bundled reference picks it
up.

Rewrite the doctrine in general terms as you promote it: drop this repo's name, its file paths,
its dated findings. Keep the rule and the reason. The blueprint must not end up pointing back at
the project it came from.

Never promote automatically — a pattern earns its row by proving itself in a project.
