# TanStack Start Architecture

Full-stack TanStack Start architecture with file-based routing, server functions, TanStack-driven data layer, Zod schema validation, and RBAC.

## Philosophy

- **Type-safe everywhere** — Zod schemas at every API boundary, `z.infer` for types
- **TanStack Query is the sole caching layer** — never use framework-level caching
- **Server functions over proxy** — `createServerFn` replaces manual API route proxying
- **TanStack Start session is the auth source of truth** — app auth state lives in `useSession()`, while external JWTs stay in server-only bridge modules
- **Domain-driven colocated structure** — services organized by backend domain, routes colocate their components
- **`x.z` naming convention** — dot-delimited flat files: `{resource}.schema.ts`, `{resource}.functions.ts`
- **No Next.js RSC directives** — do not use `"use client"` or `"use server"`; server work uses `createServerFn` (see [migration.md](./migration.md) — *Server actions → Server functions*).

## Stack

| Layer | Technology |
|-------|-----------|
| Framework | TanStack Start |
| React | React 19+ |
| Bundler | Vite |
| Server runtime | Nitro |
| Server state | TanStack Query v5 |
| Forms | TanStack Form |
| Tables | TanStack Table |
| Schema validation | Zod v4 |
| URL state | nuqs |
| Client global state | Zustand (optional — most apps need only Query + nuqs + local state) |
| Styling | Tailwind CSS v4 + semantic tokens |
| UI primitives | shadcn on **Base UI** (not Radix) — `components/ui/` |
| i18n | paraglide-js (or custom) |
| Auth | TanStack Start session + server-only JWT bridge |
| Mocking | MSW v2 (optional) |
| Testing | Vitest + Playwright |
| Package manager | bun |

## When to use

- Multi-service backends with REST APIs (OpenAPI/Swagger)
- Apps needing RBAC, workspaces, multi-tenancy
- CRM, SaaS, dashboards, admin panels, e-commerce
- Teams that want strict conventions and scaffolding agents

## When NOT to use

- Simple static sites or landings (use Astro instead)
- GraphQL-first backends (data layer patterns differ)
- Solo prototypes where convention overhead isn't worth it

## Files in this architecture

| File | What it covers |
|------|---------------|
| [structure.md](./structure.md) | Full folder layout |
| [patterns.md](./patterns.md) | Implementation patterns and conventions |
| [services.md](./services.md) | The 6-file service resource convention |
| [data-fetching.md](./data-fetching.md) | Server functions and fetch architecture |
| [auth-rbac.md](./auth-rbac.md) | Authentication and authorization |
| [components.md](./components.md) | Component organization and design system |
| [forms.md](./forms.md) | The `useAppForm` factory, field anatomy, muted variant, escape hatches |
| [state.md](./state.md) | State management strategy |
| [agents.md](./agents.md) | Scaffolding and auditing agents |
| [rules.md](./rules.md) | Critical rules that must never be broken |
| [plugins.md](./plugins.md) | Required/optional MCP plugins and configuration |

## Migration from Next.js

See [migration.md](./migration.md) for a detailed mapping from the Next.js architecture to this one.

## TanStack Intent

Install TanStack Intent for AI skill integration with TanStack libraries:

```bash
npx @tanstack/intent@latest install   # Print setup instructions
npx @tanstack/intent@latest list      # Show available skills from installed packages
```

Intent scans `node_modules` for intent-enabled packages (Query, Router, Form, etc.) and generates skill mappings so AI agents know how to use them properly.

## Agentic doc structure

Consumer repos follow the converged instruction layout described in the [root README](../README.md#agentic-doc-structure-converged): `CLAUDE.md` containing only `@AGENTS.md`; `AGENTS.md` as an index (intent skill-mappings header + `@import` of one-topic `docs/conventions/*.md` files + a trigger table for `docs/patterns/` load-before-work specs); and `scripts/check-*.ts` CI guards for every mechanically-checkable convention.

## Claude Code setup (install the plugin)

Agents, hooks, and the doctrine skills ship as plugins — install rather than copy, so
`claude plugin update` keeps them current:

```bash
claude plugin marketplace add exx0dusss/architectures
claude plugin install arch-tanstack-start@architectures --scope project
```

Then run `/arch-init` for the consumer-owned pieces (instruction index, permissions, registry,
third-party skills). Sources live in `plugins/arch-tanstack-start/` and `plugins/arch-core/`.

### What's included

**Agents** (`plugins/arch-tanstack-start/agents/`):

| Agent | Type | Purpose |
|-------|------|---------|
| `service-scaffold` | Scaffolding | Generate all 6 service resource files |
| `page-scaffold` | Scaffolding | Generate route `-components/` directory |
| `msw-mock` | Scaffolding | Generate MSW mock handlers + data |
| `unit-test` | Scaffolding | Generate Vitest unit tests |
| `arch-review` | Auditing | Find architecture rule violations |
| `openapi-check` | Auditing | Validate schemas against OpenAPI spec |
| `color-token-auditor` | Auditing | Find hardcoded colors, legacy CSS vars |
| `dependency-auditor` | Auditing | Find unused/duplicate/deprecated packages |

Completed-migration agents (`form-migrator`) live in `plugins/arch-tanstack-start/archive/` — reference only, outside the plugin's agent scan.

**Settings template** (`plugins/arch-tanstack-start/settings-template.json`) — merged into your `.claude/settings.json` by `/arch-init`:
- Pre-configured permissions for git, bun, gh CLI
- Deny rules for destructive operations

## Building blocks (copy-ready code)

Actual code templates ready to drop into a new project. Located in [`building-blocks/`](./building-blocks/).

| File | What it provides |
|------|-----------------|
| [service-template.md](./building-blocks/service-template.md) | Full 6-file service resource template (copy & replace placeholders) |
| [fetch-client.md](./building-blocks/fetch-client.md) | Server fetch infrastructure (`apiFetch`, `createServerModule`) |
| [errors-and-result.md](./building-blocks/errors-and-result.md) | Result type, error classes, `safeServerFn` wrapper |
| [shared-schemas.md](./building-blocks/shared-schemas.md) | Pagination, query, request schemas, query keys, URL parsers |
| [auth.md](./building-blocks/auth.md) | Cookie-based JWT auth (external backend integration) |
| [rbac.md](./building-blocks/rbac.md) | Role hierarchy, permissions, server/client access checks |
| [workspace.md](./building-blocks/workspace.md) | Multi-tenant workspace isolation |
| [providers.md](./building-blocks/providers.md) | Provider stack, query client, env validation |
| [utilities.md](./building-blocks/utilities.md) | cn(), date formatting, query builder, logger, dayjs, socket |
| [testing.md](./building-blocks/testing.md) | Custom RTL render, test query client, MSW handlers |
| [mutation-feedback.md](./building-blocks/mutation-feedback.md) | Global MutationCache error net, skipGlobalError, success-toast rules, CI guard |
| [table-actions.md](./building-blocks/table-actions.md) | One `RowAction[]` driving kebab + context menu + bulk bar; `useBulkRunner` |
| [data-loading.md](./building-blocks/data-loading.md) | Colocated `XSkeleton` + `SkeletonGroup`, marks vs skeletons, Suspense boundary granularity |
| [page-layout.md](./building-blocks/page-layout.md) | The 8-pattern page taxonomy (A–H), composition law, plan requirement |
| [enumeration-controls.md](./building-blocks/enumeration-controls.md) | Icons on enum options *and* on the filter trigger; `allOption.icon ?? emptyIcon ?? placeholderIcon` |
