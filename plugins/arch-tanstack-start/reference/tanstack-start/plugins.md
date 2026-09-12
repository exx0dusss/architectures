# Plugins, DevTools & AI Skills

Required tooling integrations for projects using this architecture.

## TanStack DevTools (unified panel)

All TanStack DevTools are unified into a single panel via `@tanstack/react-devtools`.

### Installation

```bash
pnpm add -D @tanstack/react-devtools @tanstack/react-query-devtools @tanstack/react-router-devtools @tanstack/react-form-devtools
```

For Vite-based projects (TanStack Start), also add the Vite plugin:

```bash
pnpm add -D @tanstack/devtools-vite
```

### Setup in root layout

```tsx
// routes/__root.tsx
import { TanStackDevtools } from '@tanstack/react-devtools'
import { ReactQueryDevtoolsPanel } from '@tanstack/react-query-devtools'
import { TanStackRouterDevtoolsPanel } from '@tanstack/react-router-devtools'
import { ReactFormDevtoolsPanel } from '@tanstack/react-form-devtools'

function RootComponent() {
  return (
    <html>
      <body>
        <Outlet />
        {import.meta.env.DEV && (
          <TanStackDevtools
            plugins={[
              { name: 'TanStack Query', render: <ReactQueryDevtoolsPanel /> },
              { name: 'TanStack Router', render: <TanStackRouterDevtoolsPanel router={router} /> },
              { name: 'TanStack Form', render: <ReactFormDevtoolsPanel /> },
            ]}
          />
        )}
      </body>
    </html>
  )
}
```

### Vite plugin (enables Vite integration)

```typescript
// vite.config.ts
import { TanStackDevtools } from '@tanstack/devtools-vite'

export default defineConfig({
  plugins: [
    TanStackDevtools(),
    // ... other plugins
  ],
})
```

### Configuration options

```tsx
<TanStackDevtools
  config={{
    position: 'bottom-right',     // button position
    panelLocation: 'bottom',      // panel position
    theme: 'dark',                // 'dark' | 'light'
    hideUntilHover: false,        // auto-hide button
    openHotkey: ['Shift', 'D'],   // keyboard shortcut
    defaultOpen: false,           // start open?
  }}
  plugins={[...]}
/>
```

**Rule:** Always wrap DevTools in `import.meta.env.DEV` check — never ship to production.

## TanStack Intent (AI skills from npm packages)

TanStack packages ship AI skills that teach Claude Code about their APIs. These are automatically discovered from `node_modules`.

### Commands

```bash
# List available skills from installed TanStack packages
npx @tanstack/intent@latest list

# Print setup instructions for CLAUDE.md
npx @tanstack/intent@latest install
```

### Integration with CLAUDE.md

Run `npx @tanstack/intent@latest install` after adding TanStack packages. It generates a skill mapping block:

```markdown
<!-- intent-skills:start -->
## TanStack Intent Skills

| Task | Skill | Path |
|------|-------|------|
| Routes, navigation | `router-core` | `node_modules/.../router-core/skills/router-core/SKILL.md` |
| Server functions | `server-functions` | `node_modules/.../start-core/server-functions/SKILL.md` |
| Search params | `search-params` | `node_modules/.../router-core/search-params/SKILL.md` |
<!-- intent-skills:end -->
```

**Rule:** Re-run `npx @tanstack/intent@latest install` after updating TanStack packages — skills update with the package version.

### Available skills by package

| Package | Skills |
|---------|--------|
| `@tanstack/router-core` | router-core, navigation, path-params, search-params, data-loading, auth-and-guards, code-splitting, not-found-and-errors, ssr, type-safety |
| `@tanstack/start-client-core` | start-core, server-functions, middleware, execution-model, server-routes |
| `@tanstack/router-plugin` | router-plugin (Vite integration) |
| `@tanstack/react-start` | react-start (React bindings) |

## shadcn (UI component tooling)

shadcn provides three integration points:

### 1. shadcn CLI — component installation

```bash
# Install a component from the registry
npx shadcn@latest add button

# Install from your own registry
npx shadcn@latest add @acme/avatar

# Overwrite existing component
npx shadcn@latest add @acme/sheet --overwrite
```

Configure in `components.json`:

```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "base-nova",
  "rsc": false,
  "tsx": true,
  "aliases": {
    "components": "~/components",
    "utils": "~/lib/utils",
    "ui": "~/components/ui"
  },
  "registries": {
    "@acme": {
      "url": "https://raw.githubusercontent.com/<your-org>/<your-ui-repo>/master/public/r/{name}.json"
    }
  }
}
```

### 2. shadcn MCP server — AI-powered component operations

The shadcn MCP server gives Claude Code direct access to the component registry for searching, installing, and auditing components.

Enable in `.claude/settings.json`:

```json
{
  "enabledMcpjsonServers": ["shadcn"]
}
```

Capabilities:
- Search the registry for components
- Install components directly
- Audit installed components against registry versions
- Read component documentation

### 3. shadcn Skills — component composition patterns

shadcn ships SKILL.md files that teach AI agents how to compose components correctly. These cover:
- Component composition patterns (compound components, CVA variants)
- Form integration (TanStack Form + shadcn fields)
- Styling conventions (data-slot, Tailwind tokens)
- Icon usage (lucide-react with XIcon convention)

The skills are auto-discovered when shadcn is installed as an MCP server.

## context7 — library documentation

Fetches up-to-date documentation for any library. Use it before writing code that depends on external APIs.

```json
{
  "enabledMcpjsonServers": ["context7"]
}
```

**When to use:** Before scaffolding pages, services, or components that use TanStack Query, TanStack Router, nuqs, Zod, Motion, or any other library. Training data may not reflect recent API changes.

## Required Claude Code Skills

Install globally with `npx skills add <source> -g -y`. These are checked by the `arch-init` skill.

| Skill | Source | Purpose |
|-------|--------|---------|
| `web-design-guidelines` | `vercel-labs/agent-skills` | UI compliance auditing — catches UX anti-patterns, accessibility issues |
| `vercel-composition-patterns` | `vercel-labs/agent-skills` | React composition at scale — prevents boolean-prop proliferation |
| `ui-audit` | `mblode/agent-skills` | Pre-ship accessibility, typography, UX polish audit |
| `review-pr` | `mblode/agent-skills` | Diff review against CLAUDE.md rules before commit |
| `ui-design-review` | `mastepanoski/claude-skills` | 10-dimension visual design evaluation |
| `frontend-design` | `anthropics/skills` | Production-grade UI generation |

### Mandatory skill loading rules

Add this to CLAUDE.md so skills get loaded before touching code:

| Working on | Load skill FIRST |
|------------|-----------------|
| Any `components/ui/` change | `shadcn` skill |
| Routes, Link, navigation | TanStack `navigation` intent skill |
| Data loading, loaders | TanStack `data-loading` intent skill |
| Server functions | TanStack `server-functions` intent skill |
| New UI surfaces / pages | `frontend-design` skill |
| Before committing UI work | `ui-audit` + `review-pr` skills |

## Complete plugin setup

### Required plugins (every project)

| Tool | Type | Purpose |
|------|------|---------|
| TanStack DevTools | npm packages | Unified dev panel for Query/Router/Form |
| TanStack Intent | CLI + CLAUDE.md | AI skills from TanStack packages |
| shadcn CLI | npm tool | Component installation from registry |
| shadcn MCP | MCP server | AI-powered component operations |

### Recommended plugins

| Tool | Type | Purpose |
|------|------|---------|
| context7 | MCP server | Up-to-date library documentation |
| Playwright | MCP server | Browser automation for E2E testing |
| Figma | MCP server | Design-to-code workflow |

### Optional (project-specific)

| Tool | Type | Purpose |
|------|------|---------|
| Atlassian | MCP server | Jira/Confluence integration |
| Telegram | MCP server | Telegram bot/channel integration |
| Supabase | MCP server | Supabase database/auth |

### settings.json template

```json
{
  "enabledMcpjsonServers": ["shadcn", "context7"],
  "enabledPlugins": {}
}
```

### WebFetch allowlist (settings.local.json)

```json
{
  "permissions": {
    "allow": [
      "WebFetch(domain:base-ui.com)",
      "WebFetch(domain:github.com)",
      "WebFetch(domain:raw.githubusercontent.com)",
      "WebFetch(domain:zod.dev)",
      "WebFetch(domain:tanstack.com)",
      "WebFetch(domain:nuqs.47ng.com)",
      "WebFetch(domain:nitro.build)",
      "WebFetch(domain:ui.shadcn.com)"
    ]
  }
}
```

## New project setup checklist

```bash
# 1. Install TanStack DevTools
pnpm add -D @tanstack/react-devtools @tanstack/react-query-devtools \
  @tanstack/react-router-devtools @tanstack/react-form-devtools \
  @tanstack/devtools-vite

# 2. Configure DevTools in root layout and vite.config.ts

# 3. Install TanStack Intent skills
npx @tanstack/intent@latest install

# 4. Configure shadcn
npx shadcn@latest init

# 5. Enable MCP servers in .claude/settings.json
# shadcn, context7

# 6. Add WebFetch allowlist to settings.local.json
```
