# Scaffolding & Auditing Agents

Specialized Claude Code agents that automate repetitive work and enforce architecture rules.

Agent definitions ship in the `arch-nextjs` plugin (`plugins/arch-nextjs/agents/`). Project-local agents still go in `.claude/agents/` at the project root.

## Scaffolding agents

### service-scaffold
Generate all 7 files for a new service resource. Input: service name, resource name, backend endpoints. Output: `schema.ts`, `api-schema.ts`, `queries.ts`, `query-options.ts`, `actions.ts`, `use-{resource}.ts`, `search-params.ts`.

### page-scaffold
Generate the `_components/` directory for a new table page. Input: resource name, columns. Output: `columns.tsx`, `{resource}-table.tsx`, `{resource}-toolbar.tsx`, `{resource}-header.tsx`, `{resource}-page-loader.tsx`, and `modals/` directory.

### msw-mock
Generate MSW mock handlers for a service resource. Reads the existing `schema.ts` to create realistic mock data and handlers matching the API endpoints.

### unit-test
Create unit tests for service files. Generates vitest tests for `queries.ts`, `actions.ts`, hooks, and schema validation.

### i18n-sync
Sync translation files. Scans for `useTranslations` and `getTranslations` calls, identifies missing keys, and adds placeholders to locale files.

## Auditing agents

### arch-review
Audit for architecture rule violations. Checks:
- Service files follow the 7-file pattern
- `"server-only"` / `"use server"` / `"use client"` directives are correct
- No Next.js fetch cache usage (no `revalidateTag`, `unstable_cache`, ISR)
- Zod validation at all boundaries
- Result pattern in all server actions
- Correct imports (all UI primitives from `components/ui/`)

### openapi-check
Validate schemas against backend Swagger/OpenAPI specs. Fetches the spec, compares Zod schemas to OpenAPI definitions, and reports mismatches.

### ui-migrator
Find components with legacy import paths and migrate them to `components/ui/`.

### icon-migrator
Replace `react-icons` imports with `lucide-react` equivalents.

### color-token-auditor
Find hardcoded colors (`text-white`, `bg-purple-400`, etc.) and replace with semantic tokens.

### dependency-auditor
Check dependency health — outdated packages, security advisories, unused dependencies.

### migration-planner
Plan major upgrades (Next.js, React, TanStack) with step-by-step migration guides.
