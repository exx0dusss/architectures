# Scaffolding & Auditing Agents

Specialized Claude Code agents that automate repetitive work and enforce architecture rules.

Agent definitions ship in the `arch-tanstack-start` plugin (`plugins/arch-tanstack-start/agents/`). Project-local agents still go in `.claude/agents/` at the project root.

## Scaffolding agents

### service-scaffold
Generate all 6 files for a new service resource using the `x.z` convention. Input: service name, resource name, backend endpoints. Output: `{r}.schema.ts`, `{r}.api-schema.ts`, `{r}.functions.ts`, `{r}.query-options.ts`, `{r}.hooks.ts`, `{r}.search-params.ts`.

### page-scaffold
Generate the `-components/` directory for a new table route. Input: resource name, columns. Output: `columns.tsx`, `{resource}-table.tsx`, `{resource}-toolbar.tsx`, `{resource}-header.tsx`, `{resource}-page-loader.tsx`, and `modals/` directory.

### msw-mock
Generate MSW mock handlers for a service resource. Reads the existing `{r}.schema.ts` to create realistic mock data and handlers matching the API endpoints.

### unit-test
Create unit tests for service files. Generates vitest tests for server functions, hooks, and schema validation.

## Auditing agents

### arch-review
Audit for architecture rule violations. Checks:
- Service files follow the 6-file `x.z` pattern
- Server functions use `createServerFn` with `.inputValidator()` for input validation
- No direct backend calls from client code (all through server functions)
- Zod validation at all boundaries
- Correct imports (all UI primitives from `components/ui/`)
- No proxy routes or `apiClient` patterns (should be server functions)

### openapi-check
Validate schemas against backend Swagger/OpenAPI specs. Fetches the spec, compares Zod schemas to OpenAPI definitions, and reports mismatches.

### color-token-auditor
Find hardcoded colors (`text-white`, `bg-purple-400`, etc.) and replace with semantic tokens.

### dependency-auditor
Check dependency health — outdated packages, security advisories, unused dependencies.
