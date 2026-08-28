# Next.js Architecture

> **⚠️ Maintenance mode (2026-08).** This blueprint's only consumer has been dormant since 2026-02. It is kept accurate as of its last active use but no longer receives the convention syncs the TanStack Start blueprint gets. For new projects, prefer [tanstack-start](../tanstack-start/); pull newer doctrine (chrome tokens, type scale, mutation feedback, table actions) from there.

Full-stack Next.js architecture with App Router, multi-service proxy, TanStack-driven data layer, Zod schema validation, and RBAC.

## Philosophy

- **Type-safe everywhere** — Zod schemas at every API boundary, `z.infer` for types
- **TanStack Query is the sole caching layer** — never use Next.js fetch cache, ISR, or `revalidateTag`
- **Result pattern over exceptions** — server actions return `Result<T, E>`, never throw
- **Domain-driven collocated structure** — services organized by backend domain, pages colocate their components
- **Multi-service proxy** — client never talks to backends directly, Next.js API routes proxy everything

## Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 16+ (App Router) |
| React | React 19+ |
| Server state | TanStack Query v5 |
| Forms | TanStack Form |
| Tables | TanStack Table |
| Schema validation | Zod v4 |
| URL state | nuqs |
| Client global state | Zustand |
| Styling | Tailwind CSS v4 + semantic tokens |
| UI primitives | shadcn/Base UI (`components/ui/`) |
| i18n | next-intl |
| Auth | Cookie-based JWT (access + refresh) |
| Mocking | MSW v2 |
| Testing | Vitest + Playwright |
| Package manager | pnpm |

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
| [services.md](./services.md) | The 7-file service resource convention |
| [data-fetching.md](./data-fetching.md) | Multi-layer fetch architecture |
| [auth-rbac.md](./auth-rbac.md) | Authentication and authorization |
| [components.md](./components.md) | Component organization and design system |
| [forms.md](./forms.md) | The `useAppForm` factory, validation, `ApiResult` submission, wizards |
| [state.md](./state.md) | State management strategy |
| [agents.md](./agents.md) | Scaffolding and auditing agents |
| [rules.md](./rules.md) | Critical rules that must never be broken |
| [plugins.md](./plugins.md) | Required/optional MCP plugins and configuration |

## Agentic doc structure

New consumer repos should follow the converged instruction layout in the [root README](../README.md#agentic-doc-structure-converged): `CLAUDE.md` containing only `@AGENTS.md`, `AGENTS.md` as an index of one-topic `docs/conventions/*.md` imports + `docs/patterns/` load-before-work specs, and `scripts/check-*.ts` CI guards for mechanically-checkable conventions.

## Claude Code setup (install the plugin)

Agents, hooks, and the doctrine skills ship as plugins — install rather than copy, so
`claude plugin update` keeps them current:

```bash
claude plugin marketplace add exx0dusss/architectures
claude plugin install arch-nextjs@architectures --scope project
```

Then run `/arch-init` for the consumer-owned pieces (instruction index, permissions, registry,
third-party skills). Sources live in `plugins/arch-nextjs/` and `plugins/arch-core/`.

### What's included

**Agents** (`plugins/arch-nextjs/agents/`):

| Agent | Type | Purpose |
|-------|------|---------|
| `service-scaffold` | Scaffolding | Generate all 7 service resource files |
| `page-scaffold` | Scaffolding | Generate table page `_components/` directory |
| `msw-mock` | Scaffolding | Generate MSW mock handlers + data |
| `unit-test` | Scaffolding | Generate Vitest unit tests |
| `i18n-sync` | Scaffolding | Sync translation keys across locale files |
| `arch-review` | Auditing | Find architecture rule violations |
| `openapi-check` | Auditing | Validate schemas against OpenAPI spec |
| `color-token-auditor` | Auditing | Find hardcoded colors, legacy CSS vars |
| `dependency-auditor` | Auditing | Find unused/duplicate/deprecated packages |
| `ui-migrator` | Migration (**archived**) | Migrate legacy component imports to `components/ui/` — completed; in `plugins/arch-nextjs/archive/` |
| `icon-migrator` | Migration (**archived**) | Replace `react-icons` with `lucide-react` — completed; in `plugins/arch-nextjs/archive/` |
| `migration-planner` | Migration | Plan component migration order |

**Settings template** (`plugins/arch-nextjs/settings-template.json`) — merged into your `.claude/settings.json` by `/arch-init`:
- Pre-configured permissions for git, pnpm, gh CLI
- Deny rules for destructive operations

## Building blocks (copy-ready code)

Actual code templates ready to drop into a new project. Located in [`building-blocks/`](./building-blocks/).

| File | What it provides |
|------|-----------------|
| [service-template.md](./building-blocks/service-template.md) | Full 7-file service resource template (copy & replace placeholders) |
| [fetch-client.md](./building-blocks/fetch-client.md) | Multi-layer HTTP client (`apiClient`, `apiServer`, `serverFetch`) |
| [proxy-handler.md](./building-blocks/proxy-handler.md) | Dynamic API route proxy for backend services |
| [errors-and-result.md](./building-blocks/errors-and-result.md) | Result type, error classes, `safeAction` wrapper |
| [shared-schemas.md](./building-blocks/shared-schemas.md) | Pagination, query, request schemas, query keys, URL parsers |
| [auth.md](./building-blocks/auth.md) | Cookie-based JWT auth (external backend integration) |
| [rbac.md](./building-blocks/rbac.md) | Role hierarchy, permissions, server/client access checks |
| [workspace.md](./building-blocks/workspace.md) | Multi-tenant workspace isolation |
| [providers.md](./building-blocks/providers.md) | Provider stack, query client, middleware, env validation |
| [i18n.md](./building-blocks/i18n.md) | next-intl + Zod schema factory for localized validation |
| [utilities.md](./building-blocks/utilities.md) | cn(), date formatting, query builder, logger, dayjs, socket |
| [testing.md](./building-blocks/testing.md) | Custom RTL render, test query client, MSW handlers |
