# Pattern registry

One row per pattern doc in this repo, so every doc has an owner and a status.

**This repo is the source of truth.** Every doc here is authored here. Consumers install its
plugins and read doctrine from them — nothing is copied into a consumer repo, so there is
no mirror to drift and nothing here points at a downstream project. When a pattern proves itself
in a project and is **general** — nothing of that project survives the rewrite — promote it here
first and reference it from both sides (ADR-0012). The promoting project decides when; this repo
never tracks who consumes what.

The **Decisions** column links the ADRs that shaped a row — see [`DECISIONS.md`](./DECISIONS.md).
A doc says what the rule is; its ADR says why it changed and what was rejected. `—` means no
decision has been recorded for that row yet, which is normal for patterns that never reversed
anything.

Guards in `scripts/` are fitness functions in the sense ADR-0009 adopted; each decision's
`## Compliance` names the one that governs it.

**Status legend:**

| Status | Meaning |
|--------|---------|
| `stable` | Actively followed; safe to adopt in a new project |
| `maintenance` | Frozen — kept accurate for existing code, no new consumers expected (the whole Next.js stack) |
| `deprecated` | Superseded or completed-migration tooling kept for history (archived agents) |

`README.md` files are stack indexes, not patterns, and are not listed. Neither is
`plugins/arch-core/reference/` — it holds generated verbatim copies of the stack docs and the
contribution doctrine (see `scripts/build-skill-refs.sh`), so the originals below are the rows
that count.

## Skills (all stacks)

Shipped in the `arch-core` plugin. Each skill is a router: it declares its triggers, carries the
red-flag list, and points at the stack docs that own the detail. Those docs are the rows in the
per-stack sections below — a skill is never a second copy of doctrine.

| Pattern | File | Status | Decisions |
|---------|------|--------|-----------|
| arch-decision | `plugins/arch-core/skills/arch-decision/SKILL.md` | stable | — |
| arch-contribute | `plugins/arch-core/skills/arch-contribute/SKILL.md` | stable | ADR-0008, ADR-0010 |
| arch-init | `plugins/arch-core/skills/arch-init/SKILL.md` | stable | ADR-0005 |
| arch-services | `plugins/arch-core/skills/arch-services/SKILL.md` | stable | ADR-0005 |
| arch-state | `plugins/arch-core/skills/arch-state/SKILL.md` | stable | ADR-0005 |
| arch-ui | `plugins/arch-core/skills/arch-ui/SKILL.md` | stable | ADR-0005 |
| arch-auth | `plugins/arch-core/skills/arch-auth/SKILL.md` | stable | ADR-0005 |
| arch-forms | `plugins/arch-core/skills/arch-forms/SKILL.md` | stable | ADR-0005 |
| arch-modules | `plugins/arch-core/skills/arch-modules/SKILL.md` | stable | ADR-0005 |
| promote-pattern | `plugins/arch-core/skills/promote-pattern/SKILL.md` | stable | ADR-0005, ADR-0006 |

## Product design (all frontend stacks)

Shipped in the `product-design` plugin. Source docs express reusable judgment; skill and agent apply
it against each consumer's own design system and product context.

| Pattern | File | Status | Decisions |
|---------|------|--------|-----------|
| Product prototyping | `product-design/prototyping.md` | stable | ADR-0013 |
| Component source routing | `product-design/component-sources.md` | stable | ADR-0013 |
| Visual language | `product-design/visual-language.md` | stable | ADR-0013 |
| product-prototype | `plugins/product-design/skills/product-prototype/SKILL.md` | stable | ADR-0013 |
| product-design-review | `plugins/product-design/agents/product-design-review.md` | stable | ADR-0013 |

## Contribution doctrine (all stacks)

Stack-agnostic — the artefacts a contributor produces that no compiler checks. Bundled into the
plugin by `scripts/build-skill-refs.sh` and routed by `arch-contribute`.

| Pattern | File | Status | Decisions |
|---------|------|--------|-----------|
| Pull request body | `contributing/pull-requests.md` | stable | ADR-0008, ADR-0010 |
| Commit messages | `contributing/commits.md` | stable | ADR-0008, ADR-0010 |
| Code comments | `contributing/comments.md` | stable | ADR-0008, ADR-0010 |

## Agents (all stacks)

Shipped in the `arch-core` plugin. Stack-agnostic because consumer drift is stack-agnostic.

| Pattern | File | Status | Decisions |
|---------|------|--------|-----------|
| arch-drift | `plugins/arch-core/agents/arch-drift.md` | stable | ADR-0005 |
| contract-drift | `plugins/arch-core/agents/contract-drift.md` | stable | ADR-0012 |
| guard-writer | `plugins/arch-core/agents/guard-writer.md` | stable | ADR-0009, ADR-0010, ADR-0012 |

## Maintainer agents

Not shipped to consumers. These audit **this** repo and live in `.claude/agents/`, so they are
available when working here and invisible to anyone who installs a plugin.

| Pattern | File | Status | Decisions |
|---------|------|--------|-----------|
| consumer-leak-auditor | `.claude/agents/consumer-leak-auditor.md` | stable | ADR-0006 |
| stack-parity-auditor | `.claude/agents/stack-parity-auditor.md` | stable | ADR-0003 |

## TanStack Start — docs

| Pattern | File | Status | Decisions |
|---------|------|--------|-----------|
| agents | `tanstack-start/agents.md` | stable | — |
| auth-rbac | `tanstack-start/auth-rbac.md` | stable | — |
| components | `tanstack-start/components.md` | stable | — |
| data-fetching | `tanstack-start/data-fetching.md` | stable | — |
| forms | `tanstack-start/forms.md` | stable | — |
| migration | `tanstack-start/migration.md` | stable | — |
| patterns | `tanstack-start/patterns.md` | stable | ADR-0002 |
| plugins | `tanstack-start/plugins.md` | stable | — |
| rules | `tanstack-start/rules.md` | stable | — |
| services | `tanstack-start/services.md` | stable | — |
| state | `tanstack-start/state.md` | stable | — |
| structure | `tanstack-start/structure.md` | stable | — |

## TanStack Start — building blocks

| Pattern | File | Status | Decisions |
|---------|------|--------|-----------|
| auth | `tanstack-start/building-blocks/auth.md` | stable | — |
| data-loading | `tanstack-start/building-blocks/data-loading.md` | stable | — |
| enumeration-controls | `tanstack-start/building-blocks/enumeration-controls.md` | stable | — |
| errors-and-result | `tanstack-start/building-blocks/errors-and-result.md` | stable | — |
| fetch-client | `tanstack-start/building-blocks/fetch-client.md` | stable | — |
| i18n | `tanstack-start/building-blocks/i18n.md` | stable | — |
| mutation-feedback | `tanstack-start/building-blocks/mutation-feedback.md` | stable | — |
| page-layout | `tanstack-start/building-blocks/page-layout.md` | stable | — |
| providers | `tanstack-start/building-blocks/providers.md` | stable | — |
| rbac | `tanstack-start/building-blocks/rbac.md` | stable | — |
| service-template | `tanstack-start/building-blocks/service-template.md` | stable | — |
| shared-schemas | `tanstack-start/building-blocks/shared-schemas.md` | stable | — |
| table-actions | `tanstack-start/building-blocks/table-actions.md` | stable | — |
| testing | `tanstack-start/building-blocks/testing.md` | stable | — |
| utilities | `tanstack-start/building-blocks/utilities.md` | stable | — |
| workspace | `tanstack-start/building-blocks/workspace.md` | stable | — |

## TanStack Start — agents

| Pattern | File | Status | Decisions |
|---------|------|--------|-----------|
| arch-review | `plugins/arch-tanstack-start/agents/arch-review.md` | stable | — |
| architect | `plugins/arch-tanstack-start/agents/architect.md` | stable | — |
| color-token-auditor | `plugins/arch-tanstack-start/agents/color-token-auditor.md` | stable | ADR-0002 |
| dependency-auditor | `plugins/arch-tanstack-start/agents/dependency-auditor.md` | stable | — |
| enum-badge-scaffold | `plugins/arch-tanstack-start/agents/enum-badge-scaffold.md` | stable | — |
| i18n-sync | `plugins/arch-tanstack-start/agents/i18n-sync.md` | stable | — |
| msw-mock | `plugins/arch-tanstack-start/agents/msw-mock.md` | stable | — |
| openapi-check | `plugins/arch-tanstack-start/agents/openapi-check.md` | stable | — |
| page-scaffold | `plugins/arch-tanstack-start/agents/page-scaffold.md` | stable | — |
| service-scaffold | `plugins/arch-tanstack-start/agents/service-scaffold.md` | stable | — |
| suspense-audit | `plugins/arch-tanstack-start/agents/suspense-audit.md` | stable | — |
| unit-test | `plugins/arch-tanstack-start/agents/unit-test.md` | stable | — |
| widget-scaffold | `plugins/arch-tanstack-start/agents/widget-scaffold.md` | stable | — |
| registry-audit | `plugins/arch-tanstack-start/agents/registry-audit.md` | stable | ADR-0012 |
| form-migrator (archived) | `plugins/arch-tanstack-start/archive/form-migrator.md` | deprecated | ADR-0003 |

## Next.js — docs (maintenance mode)

| Pattern | File | Status | Decisions |
|---------|------|--------|-----------|
| agents | `nextjs/agents.md` | maintenance | ADR-0003 |
| auth-rbac | `nextjs/auth-rbac.md` | maintenance | ADR-0003 |
| components | `nextjs/components.md` | maintenance | ADR-0003 |
| data-fetching | `nextjs/data-fetching.md` | maintenance | ADR-0003 |
| forms | `nextjs/forms.md` | maintenance | ADR-0003 |
| patterns | `nextjs/patterns.md` | maintenance | ADR-0003 |
| plugins | `nextjs/plugins.md` | maintenance | ADR-0003 |
| rules | `nextjs/rules.md` | maintenance | ADR-0003 |
| services | `nextjs/services.md` | maintenance | ADR-0003 |
| state | `nextjs/state.md` | maintenance | ADR-0003 |
| structure | `nextjs/structure.md` | maintenance | ADR-0003 |

## Next.js — building blocks (maintenance mode)

| Pattern | File | Status | Decisions |
|---------|------|--------|-----------|
| auth | `nextjs/building-blocks/auth.md` | maintenance | ADR-0003 |
| errors-and-result | `nextjs/building-blocks/errors-and-result.md` | maintenance | ADR-0003 |
| fetch-client | `nextjs/building-blocks/fetch-client.md` | maintenance | ADR-0003 |
| i18n | `nextjs/building-blocks/i18n.md` | maintenance | ADR-0003 |
| providers | `nextjs/building-blocks/providers.md` | maintenance | ADR-0003 |
| proxy-handler | `nextjs/building-blocks/proxy-handler.md` | maintenance | ADR-0003 |
| rbac | `nextjs/building-blocks/rbac.md` | maintenance | ADR-0003 |
| service-template | `nextjs/building-blocks/service-template.md` | maintenance | ADR-0003 |
| shared-schemas | `nextjs/building-blocks/shared-schemas.md` | maintenance | ADR-0003 |
| testing | `nextjs/building-blocks/testing.md` | maintenance | ADR-0003 |
| utilities | `nextjs/building-blocks/utilities.md` | maintenance | ADR-0003 |
| workspace | `nextjs/building-blocks/workspace.md` | maintenance | ADR-0003 |

## Next.js — agents (maintenance mode)

| Pattern | File | Status | Decisions |
|---------|------|--------|-----------|
| arch-review | `plugins/arch-nextjs/agents/arch-review.md` | maintenance | ADR-0003 |
| architect | `plugins/arch-nextjs/agents/architect.md` | maintenance | ADR-0003 |
| color-token-auditor | `plugins/arch-nextjs/agents/color-token-auditor.md` | maintenance | ADR-0003 |
| dependency-auditor | `plugins/arch-nextjs/agents/dependency-auditor.md` | maintenance | ADR-0003 |
| enum-badge-scaffold | `plugins/arch-nextjs/agents/enum-badge-scaffold.md` | maintenance | ADR-0003 |
| i18n-sync | `plugins/arch-nextjs/agents/i18n-sync.md` | maintenance | ADR-0003 |
| migration-planner | `plugins/arch-nextjs/agents/migration-planner.md` | maintenance | ADR-0003 |
| msw-mock | `plugins/arch-nextjs/agents/msw-mock.md` | maintenance | ADR-0003 |
| openapi-check | `plugins/arch-nextjs/agents/openapi-check.md` | maintenance | ADR-0003 |
| page-scaffold | `plugins/arch-nextjs/agents/page-scaffold.md` | maintenance | ADR-0003 |
| service-scaffold | `plugins/arch-nextjs/agents/service-scaffold.md` | maintenance | ADR-0003 |
| suspense-audit | `plugins/arch-nextjs/agents/suspense-audit.md` | maintenance | ADR-0003 |
| unit-test | `plugins/arch-nextjs/agents/unit-test.md` | maintenance | ADR-0003 |
| widget-scaffold | `plugins/arch-nextjs/agents/widget-scaffold.md` | maintenance | ADR-0003 |
| baseui-migrator (archived) | `plugins/arch-nextjs/archive/baseui-migrator.md` | deprecated | ADR-0003 |
| icon-migrator (archived) | `plugins/arch-nextjs/archive/icon-migrator.md` | deprecated | ADR-0003 |

## NestJS backend

| Pattern | File | Status | Decisions |
|---------|------|--------|-----------|
| auth-rbac | `nestjs-backend/auth-rbac.md` | stable | — |
| data-layer | `nestjs-backend/data-layer.md` | stable | — |
| deployment | `nestjs-backend/deployment.md` | stable | — |
| patterns | `nestjs-backend/patterns.md` | stable | — |
| real-time | `nestjs-backend/real-time.md` | stable | — |
| rules | `nestjs-backend/rules.md` | stable | — |
| services | `nestjs-backend/services.md` | stable | — |
| structure | `nestjs-backend/structure.md` | stable | — |
| testing | `nestjs-backend/testing.md` | stable | — |

## NestJS backend — agents

| Pattern | File | Status | Decisions |
|---------|------|--------|-----------|
| arch-review | `plugins/arch-nestjs-backend/agents/arch-review.md` | stable | — |
| module-boundary-audit | `plugins/arch-nestjs-backend/agents/module-boundary-audit.md` | stable | — |
| module-scaffold | `plugins/arch-nestjs-backend/agents/module-scaffold.md` | stable | — |
| migration-reviewer | `plugins/arch-nestjs-backend/agents/migration-reviewer.md` | stable | ADR-0012 |

## NestJS backend — skills

Shipped in the `arch-nestjs-backend` plugin rather than `arch-core`: the rule is Drizzle-specific,
so it holds for one stack and must not be routed to the others.

| Pattern | File | Status | Decisions |
|---------|------|--------|-----------|
| db-migration | `plugins/arch-nestjs-backend/skills/db-migration/SKILL.md` | stable | ADR-0012 |

## Agent context routing

| Pattern | Source | Decisions |
|---|---|---|
| Task-scoped conventions and owning-workspace detection | [Context routing](./agent-workflows/context-routing.md) | [0014](./decisions/0014-load-conventions-by-task.md) |
