# Architectures

Personal engineering playbook: opinionated, battle-tested software architecture and product-building
doctrine delivered as reusable plugins.

Architecture remains one collection. Adjacent collections earn their place when docs encode reusable
judgment and skills or agents turn that judgment into repeatable work. Consumer-specific product
facts stay downstream.

## Frontend

| Stack | Description |
|-------|-------------|
| [Next.js](./nextjs/) | Full-stack Next.js with App Router, Radix UI, TanStack Query, Zod, RBAC, multi-service proxy |
| [TanStack Start](./tanstack-start/) | Full-stack TanStack Start with Base UI, TanStack Query/Form/Table, Zod, file-based routing |

Both stacks share the same component architecture (atom/molecule/organism with category folders), design token system, and data-fetching patterns. The difference is routing (App Router vs TanStack Router) and UI primitives (Radix vs Base UI).

## Backend

| Stack | Description |
|-------|-------------|
| [NestJS](./nestjs-backend/) | DDD modular monolith with Drizzle ORM, BullMQ, CASL RBAC, WebSocket, two-process deployment |

## Install

This repo is a Claude Code plugin marketplace. Consumers install rather than copy, so
`claude plugin update` re-syncs doctrine, skills, and agents everywhere at once.

```bash
claude plugin marketplace add exx0dusss/architectures
claude plugin install arch-nextjs@architectures --scope project
```

| Plugin | Ships |
|--------|-------|
| `arch-core` | The `arch-*` skills, the `arch-drift` audit agent, the bundled stack reference. Required by the others. |
| `arch-nextjs` | Next.js agents, hooks, settings template |
| `arch-tanstack-start` | TanStack Start agents, hooks, settings template |
| `arch-nestjs-backend` | NestJS doctrine + module scaffolding and audit agents |
| `product-design` | Product prototyping skill, visual-language doctrine, rendered-page review agent |

`--scope project` writes to `.claude/settings.json`, so the whole team picks the plugin up from
git. Then run `/arch-init` once for the pieces a plugin cannot touch — the consumer's own
`AGENTS.md` index, permissions, component registry, and third-party skills.

The skills also work through the `skills` CLI for non-plugin setups:
`npx skills add exx0dusss/architectures`.

### Codex and general Agent Skills

The shared `SKILL.md` files are the portable layer. Install them through the general Agent Skills
CLI for Codex or another supported agent:

```bash
npx skills add exx0dusss/architectures --agent codex
```

This installs skills only. Claude-specific agents, hooks, and settings stay Claude-specific.

The repo also contains a native Codex marketplace at
[`.agents/plugins/marketplace.json`](./.agents/plugins/marketplace.json). Register it from the repo
root, then install plugins through the Codex plugin UI:

```bash
codex plugin marketplace add .
codex plugin marketplace list
```

Native Codex packages currently cover skill-bearing plugins: `arch-core`, `arch-nestjs-backend`,
and `product-design`. `arch-nextjs` and `arch-tanstack-start` currently ship Claude agents only;
their agent workflows need Codex-specific skill ports before claiming parity.

## Skills

`arch-core` ships eight doctrine skills plus the init and promotion workflows. Each declares triggers, carries a
red-flag list, and routes to the bundled reference for the stack it detects in `package.json` —
so one skill set serves all three stacks with no duplication.

| Skill | Fires on | Stacks |
|-------|----------|:------:|
| `arch-services` | Service/data layer: resources, schemas, server actions and functions, query keys, prefetch, invalidation, pagination | all |
| `arch-state` | Where state belongs; Zustand stores, URL search params, persisted state | frontend |
| `arch-ui` | Components, layers, CVA variants, design tokens, icons, skeletons | frontend |
| `arch-auth` | Sessions, tokens, refresh, roles, guards, middleware | all |
| `arch-forms` | The `useAppForm` factory, fields, validation, submit, wizards | frontend |
| `arch-modules` | Module boundaries, domain events, BullMQ jobs, layer direction | backend |
| `arch-decision` | Recording an architecture decision: a rule reverses, a status changes, a promotion rejects an alternative | all |
| `arch-contribute` | Pull request bodies, commit messages, comments in source | all |
| `arch-init` | Bootstrapping or re-syncing a consumer repo | all |
| `promote-pattern` | Lifting a proven pattern from a consumer into this blueprint | all |

Doctrine is **lazy** — a skill loads only when its triggers fire. What stays always-loaded in a
consumer is that project's own instantiation: its real folder layout, commands, ports, and safety
rules. Mixing the two is what makes an instruction index expensive.

## Agents

Each stack plugin ships Claude Code agents in `plugins/arch-<stack>/agents/`:

| Agent | Purpose | Both stacks |
|-------|---------|:-----------:|
| `architect` | Analyze repo + generate migration plan | Yes |
| `arch-review` | P0-P3 architecture compliance audit | Yes |
| `page-scaffold` | Generate route + components | Yes |
| `service-scaffold` | Generate service resource files | Yes |
| `widget-scaffold` | Generate widget/list/item decomposition | Yes |
| `enum-badge-scaffold` | Generate domain badge from enum | Yes |
| `suspense-audit` | Flag useQuery where useSuspenseQuery should be | Yes |
| `color-token-auditor` | Scan for hardcoded colors + chrome/dark token misuse | Yes |
| `unit-test` | Generate tests for service files | Yes |
| `msw-mock` | Generate MSW mock handlers | Yes |

## Product design

`product-design` applies beyond one stack. Its `product-prototype` skill builds high-fidelity
application pages inside real product structure, using replaceable integration seams and rendered
visual verification. Root [`product-design/`](./product-design/) docs hold source doctrine; plugin
bundles generated copies. `product-design-review` supplies independent visual judgment before a
variant is accepted.

Local design systems remain authoritative. Before composing a major primitive, workflow routes to
its provider skill and MCP/docs, then checks local wrapper and existing usage. Plugin sharpens
hierarchy, composition, density, state coverage, and verification without imposing one product's
tokens or component names on another.

## Staying in sync

Two questions, answered separately, because version equality is not sync.

`arch-core` ships `scripts/arch-sync-check.sh`, run inside the consumer checkout. It reads
Claude's enabled settings and installation registry, resolves project/worktree scope, and checks
installed manifests against the marketplace. A newer machine cache does not count as a project
installation. `MISSING`, `INVALID`, `UNKNOWN`, `BEHIND`, and `AHEAD` remain distinct; `--strict`
fails every non-current registration and every shadowed agent. No requested plugins is an empty
report, not a fallback to unrelated machine caches.

Inspection is read-only by default (`--check`). Use `--write` deliberately to save
`.claude/blueprint-sync.json`; `--json` emits structured provenance. The report checks registered
installations, **not live session loading**. Verify loaded capabilities in a fresh runtime session.
The resolver currently supports `--runtime claude`; Codex registration needs its own resolver and
must not be inferred from Claude caches. `--project PATH` selects the consumer checkout.

Hook scripts consume PostToolUse JSON from stdin and return model-visible `additionalContext`.
The shared transport source is `scripts/hook_reminder.py`; run
`python3 scripts/build-hook-helpers.py` after editing it. Bundled copies keep each plugin
self-contained. `python3 -m unittest discover -s scripts/tests -v` covers hook payloads and
installation resolution; CI also verifies bundle equality. Hooks are advisory, not safety gates.

What a script cannot judge, the `arch-drift` agent does: whether a forked agent is a stale
ancestor or a real local patch, whether doctrine has been copied into always-loaded conventions,
whether a local rule now contradicts current doctrine, and which checkable rules have no CI guard.

On this side, two maintainer agents in `.claude/agents/` guard the blueprint itself —
`consumer-leak-auditor` (has a consumer's name, vendor, or currency leaked into general doctrine?)
and `stack-parity-auditor` (does one stack have a capability its peer is owed?).

## How to use

1. Pick the architecture for your stack
2. Install its plugin (see [Install](#install)) and run `/arch-init`
3. Read the stack README for philosophy and trade-offs
4. Follow `structure.md` for folder layout
5. Let the `arch-*` skills carry the rest — they load the right doc when you touch that surface
6. Use the scaffolding agents to generate boilerplate

## Repo layout

```
nextjs/  tanstack-start/  nestjs-backend/   # architecture docs — source of truth
product-design/                              # product-design doctrine — source of truth
DECISIONS.md  decisions/                  # the decision timeline + one ADR each
plugins/
  arch-core/
    skills/arch-*/SKILL.md                  # triggers + red flags, hand-authored
    reference/<stack>/*.md                  # GENERATED verbatim copies of the stack docs
  arch-core/agents/arch-drift.md            # consumer-side drift audit
  arch-<stack>/{agents,hooks,scripts}/      # per-stack tooling
  product-design/{skills,agents,reference}/   # stack-agnostic product-building workflow
.agents/plugins/marketplace.json             # Codex plugin marketplace
plugins/*/.codex-plugin/plugin.json          # Codex manifests inside skill-bearing plugins
.claude/agents/                             # maintainer-only audits of THIS repo
.claude-plugin/marketplace.json             # what `claude plugin marketplace add` reads
scripts/build-skill-refs.sh                 # regenerates reference/ — CI fails if stale
scripts/check-consumer-leaks.sh             # ADR-0006 guard — no consumer names, paths or links
```

Edit a stack doc, then run `sh scripts/build-skill-refs.sh` and commit the result. The
`Skill refs` workflow fails any PR where the two have diverged.
Reverse a rule and you also write an ADR — see [Architecture decisions](#architecture-decisions).

## Agentic doc structure (converged)

Consumer repos converge on one instruction layout so agents load the right context at the right time:

```
CLAUDE.md                     # exactly one line: @AGENTS.md
AGENTS.md                     # the index — nothing else lives here:
                              #   1. intent skill-mappings header (a `skills:` list
                              #      mapping "task" → SKILL.md path in node_modules,
                              #      generated/refreshed via `npx @tanstack/intent`)
                              #   2. one @import line per docs/conventions/*.md file
                              #   3. a "Related docs" list pointing at docs/patterns/
docs/conventions/*.md         # ONE topic per file (stack, architecture, forms,
                              #   overlays, data-loading, mutation-feedback, …) —
                              #   always-loaded via @import; edit the source file,
                              #   never duplicate content into the index
docs/patterns/*.md            # load-before-work specs (page-layout, card,
                              #   table-actions, …) — referenced from the index with
                              #   a "read X first" trigger table, loaded on demand
scripts/check-*.ts            # CI guard scripts for every mechanically-checkable
                              #   convention (type scale, mutation feedback, …) —
                              #   a convention without a guard is a suggestion
```

Rules of thumb:

- **CLAUDE.md contains only `@AGENTS.md`** — the index is tool-agnostic; Claude-specific config stays in `.claude/`.
- **The index imports, it never explains.** Each convention doc owns its topic; the index's job is routing (which doc, when).
- **Import the project, skill the doctrine.** `docs/conventions/` is for what is specific to *this* repo — its real folder layout, commands, ports, safety rules. Generic blueprint doctrine (the service file contract, state layering, component layers and tokens, auth enforcement) belongs to the `arch-*` skills and loads on demand. Duplicating it into an always-loaded convention doc is what makes an index cost 10k+ tokens on every prompt.
- **Patterns vs conventions:** conventions are always-on rules (short, imported); patterns are heavyweight specs an agent loads before touching that surface (referenced with an explicit "load before any X work" trigger).
- **Guard what you can grep.** Every rule that reduces to a grep gets a `scripts/check-*.ts` CI guard and a mention in the convention doc it enforces.

## Architecture decisions

[`DECISIONS.md`](./DECISIONS.md) is the timeline; [`decisions/`](./decisions/) holds one file per
decision. `PATTERNS.md` says what a rule **is** — an ADR says why it changed and what was rejected.
Without the second, nobody downstream can tell a deliberate constraint from an accident, so the
rule gets either cargo-culted or broken.

An ADR is **required** when doctrine reverses, when a stack or pattern changes status, when stack
parity is deliberately broken, when a promotion rejects a real alternative, or when distribution
or the consumer instruction layout changes. A plain commit is enough for everything else — new
patterns that contradict nothing, wording fixes, expanding a doc, adding a scaffolding agent,
regenerating `reference/`. An ADR per commit is a log nobody reads.

**An accepted ADR is immutable.** Reversing a decision means writing the next one and wiring the
supersede chain in both directions; the old ADR is kept, because the reversal is only legible next
to what it reversed. The `arch-decision` skill walks it, and `scripts/check-decisions.sh --strict`
guards it in CI (`decisions.yml`) — ID/filename agreement, index and files in step, bidirectional
supersede chains, live ADR references, and stale `Proposed`.

ADRs 0001–0006 were reconstructed from git history; each names the commit it came from, and says
so where the alternatives considered at the time were never written down.

## Pattern promotion

This repo is the **source of truth**, not a mirror. Every doc here is authored here, and nothing
here points at a downstream project — a blueprint that depends on its consumers is backwards, and
it makes the repo unshareable.

[`PATTERNS.md`](./PATTERNS.md) is the registry: one row per doc, with a status. No source column,
no consumer list.

**Promotion** — the moment you are about to copy a pattern from one project into another, promote
it here first, then reference it from both. Never promote automatically; a pattern earns its row
by proving itself in a project. Promoting means rewriting the doctrine in general terms: drop the
originating repo's name, its file paths, its dated findings. Keep the rule and the reason.

`scripts/check-consumer-leaks.sh` gates the part of that a pattern can settle — a ticket key, a
local path, a link out to another repo — and the `Consumer leaks` workflow runs it on every
push and pull request. A vendor, a currency, a locale, a dated finding: those need the
`consumer-leak-auditor` agent, which is judgment and stays manual.

**Sync is the consumers' business.** They install the `arch-*` plugins and read doctrine straight
out of them, so no blueprint doc is ever copied into a consumer repo and there is no mirror that
can silently drift. A consumer that wants to know whether it is current runs `arch-sync-check`
from the `arch-core` plugin, which compares its installed plugin versions against the marketplace.
That check lives on the consumer side, where the dependency actually is.

After editing any stack doc, run `sh scripts/build-skill-refs.sh` so the plugin's bundled
reference follows, and commit both.

## License

MIT — see [LICENSE](./LICENSE).
