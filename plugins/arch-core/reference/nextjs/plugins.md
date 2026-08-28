# Plugins, DevTools & AI Skills

Required tooling integrations for projects using this architecture.

## TanStack DevTools (unified panel)

All TanStack DevTools are unified into a single panel via `@tanstack/react-devtools`.

### Installation

```bash
pnpm add -D @tanstack/react-devtools @tanstack/react-query-devtools @tanstack/react-router-devtools @tanstack/react-form-devtools
```

### Setup in root layout

```tsx
// app/layout.tsx (or providers.tsx)
import { TanStackDevtools } from '@tanstack/react-devtools'
import { ReactQueryDevtoolsPanel } from '@tanstack/react-query-devtools'
import { ReactFormDevtoolsPanel } from '@tanstack/react-form-devtools'

// In the provider tree (client component):
{process.env.NODE_ENV === 'development' && (
  <TanStackDevtools
    plugins={[
      { name: 'TanStack Query', render: <ReactQueryDevtoolsPanel /> },
      { name: 'TanStack Form', render: <ReactFormDevtoolsPanel /> },
    ]}
  />
)}
```

**Rule:** Always guard with env check — never ship to production.

## TanStack Intent (AI skills from npm packages)

TanStack packages ship AI skills that teach Claude Code about their APIs.

### Commands

```bash
npx @tanstack/intent@latest list      # Show available skills
npx @tanstack/intent@latest install   # Print CLAUDE.md/AGENTS.md setup instructions
```

### Integration

Run `npx @tanstack/intent@latest install` after adding TanStack packages. It generates skill mappings in CLAUDE.md:

```markdown
<!-- intent-skills:start -->
| Task | Skill | Path |
|------|-------|------|
| Data fetching | `core` | `node_modules/@tanstack/react-query/skills/core/SKILL.md` |
| Forms | `core` | `node_modules/@tanstack/form/skills/core/SKILL.md` |
<!-- intent-skills:end -->
```

**Rule:** Re-run after package updates — skills update with the package version.

## shadcn (UI component tooling)

Three integration points:

### 1. shadcn CLI

```bash
npx shadcn@latest add button           # Install from default registry
npx shadcn@latest add @custom/avatar   # Install from custom registry
npx shadcn@latest init                 # Initialize components.json
```

### 2. shadcn MCP server

Enable in `.claude/settings.json`:
```json
{ "enabledMcpjsonServers": ["shadcn"] }
```

Gives Claude Code registry search, install, and audit capabilities.

### 3. shadcn Skills

Auto-discovered SKILL.md files that teach AI agents component composition, CVA variants, form integration, and styling conventions.

## context7 — library documentation

Fetches up-to-date docs for any library before writing code.

```json
{ "enabledMcpjsonServers": ["context7"] }
```

## Required plugins (every project)

| Tool | Type | Purpose |
|------|------|---------|
| TanStack DevTools | npm packages | Unified dev panel for Query/Form |
| TanStack Intent | CLI + CLAUDE.md | AI skills from TanStack packages |
| shadcn CLI | npm tool | Component installation |
| shadcn MCP | MCP server | AI-powered component operations |
| context7 | MCP server | Library documentation |

## Optional (project-specific)

| Tool | Type | Purpose |
|------|------|---------|
| Playwright | MCP server | E2E testing |
| Figma | MCP server | Design-to-code |
| Atlassian | MCP server | Jira/Confluence |

## settings.json template

```json
{
  "enabledMcpjsonServers": ["shadcn", "context7"],
  "enabledPlugins": {}
}
```

## WebFetch allowlist (settings.local.json)

```json
{
  "permissions": {
    "allow": [
      "WebFetch(domain:base-ui.com)",
      "WebFetch(domain:github.com)",
      "WebFetch(domain:raw.githubusercontent.com)",
      "WebFetch(domain:next-intl.dev)",
      "WebFetch(domain:zod.dev)",
      "WebFetch(domain:tanstack.com)",
      "WebFetch(domain:nuqs.47ng.com)",
      "WebFetch(domain:ui.shadcn.com)"
    ]
  }
}
```

## New project setup checklist

```bash
# 1. Install TanStack DevTools
pnpm add -D @tanstack/react-devtools @tanstack/react-query-devtools @tanstack/react-form-devtools

# 2. Configure DevTools in root layout

# 3. Install TanStack Intent skills
npx @tanstack/intent@latest install

# 4. Configure shadcn
npx shadcn@latest init

# 5. Enable MCP servers in .claude/settings.json

# 6. Add WebFetch allowlist to settings.local.json
```
