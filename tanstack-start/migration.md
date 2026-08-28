# Migration Guide: Next.js → TanStack Start

## Overview

This document maps every Next.js-specific pattern to its TanStack Start equivalent.

## What gets deleted

| Next.js file/pattern | Why it's gone |
|---------------------|---------------|
| `app/api/[service]/[...path]/route.ts` | Server functions replace the proxy |
| `services/_shared/fetch-client/api-client.ts` | No client-side fetch through proxy |
| `services/_shared/proxy-handler.ts` | No proxy handler needed |
| `services/_shared/safe-action.ts` | Server functions throw naturally |
| `proxy.ts` (middleware) | Replaced by TanStack Start middleware + `beforeLoad` |
| `queries.ts` per resource | Merged into `{r}.functions.ts` |
| `actions.ts` per resource | Merged into `{r}.functions.ts` |
| `use-{resource}.ts` per resource | Renamed to `{r}.hooks.ts` |
| `query-options.ts` per resource | Renamed to `{r}.query-options.ts` |
| `search-params.ts` per resource | Renamed to `{r}.search-params.ts` |
| `schema.ts` per resource | Renamed to `{r}.schema.ts` |
| `api-schema.ts` per resource | Renamed to `{r}.api-schema.ts` |

## What stays the same

| Pattern | Notes |
|---------|-------|
| TanStack Query setup | Same defaults, same query key structure |
| Zod schemas | Identical schema definitions |
| RBAC (`lib/rbac/`) | Framework-agnostic, no changes |
| Component architecture | Same layers (ui/ → shared → route-scoped) |
| nuqs URL state | Same parsers, different adapter (`nuqs/adapters/react`) |
| Zustand stores | Identical |
| Design tokens (Tailwind v4) | Identical CSS variables |
| MSW mock handlers | Identical |
| Testing (Vitest + RTL) | Same setup, different providers |

## Structural mapping

### Routing

| Next.js App Router | TanStack Start |
|-------------------|---------------|
| `app/[locale]/(auth)/auth/login/page.tsx` | `routes/auth/login.tsx` |
| `app/[locale]/(app)/layout.tsx` | `routes/_authed.tsx` (pathless layout) |
| `app/[locale]/(app)/workspace/[workspaceId]/layout.tsx` | `routes/_authed/workspace/$workspaceId/_workspace.tsx` |
| `app/[locale]/(app)/workspace/[workspaceId]/buying/flows/page.tsx` | `routes/_authed/workspace/$workspaceId/_workspace/buying/flows.tsx` |
| `app/[locale]/(app)/workspace/[workspaceId]/buying/flows/[id]/page.tsx` | `routes/_authed/workspace/$workspaceId/_workspace/buying/flows.$id.tsx` |

### Layout system

| Next.js | TanStack Start | Purpose |
|---------|---------------|---------|
| `layout.tsx` | Pathless layout route (`_name.tsx`) | Wrap children with UI |
| `loading.tsx` | `pendingComponent` on route | Loading state |
| `error.tsx` | `errorComponent` on route | Error boundary |
| `not-found.tsx` | `notFoundComponent` on route | 404 handler |
| Route groups `(auth)`, `(app)` | Pathless routes `_authed.tsx` | Layout without URL segment |
| `_components/` | `-components/` | Non-routable colocated components |

### Data fetching

| Next.js | TanStack Start |
|---------|---------------|
| Server component + `queries.ts` | Route `loader` + server function |
| `HydrationBoundary` + `dehydrate` | Automatic via `setupRouterSsrQueryIntegration` |
| `apiClient` (client fetch through proxy) | Server functions (called from anywhere, run on server) |
| `apiServer` (server-only direct fetch) | `apiFetch` (used inside server functions) |
| `cache()` from react (request dedup) | Not needed — server functions handle their own requests |

### Auth

| Next.js | TanStack Start |
|---------|---------------|
| `cookies()` from `next/headers` | `getWebRequest()` from `@tanstack/react-start/server` |
| `NextResponse.redirect()` | Throw redirect or use `beforeLoad` guard |
| Next.js middleware (`proxy.ts`) | `beforeLoad` on route + server function middleware |
| `app/api/auth/refresh/route.ts` | `routes/api/auth/refresh.ts` (API file route) |

### Server actions → Server functions

| Next.js | TanStack Start |
|---------|---------------|
| `"use server"` directive | `createServerFn()` declaration |
| `"use client"` directive | **Not used** — Start is not React Server Components; route and UI modules are isomorphic. Remove it when migrating; do not add it in new code. |
| `safeAction()` wrapper | Error handling in `apiFetch` / try-catch in handler |
| `unwrap()` in mutation | Not needed — server functions throw naturally |
| Manual `.parse()` on input | `.inputValidator(schema)` on `createServerFn` |

### Environment

| Next.js | TanStack Start |
|---------|---------------|
| `NEXT_PUBLIC_*` env vars | `VITE_*` env vars |
| `@t3-oss/env-nextjs` | `@t3-oss/env-core` |
| `process.env.NEXT_PUBLIC_*` | `import.meta.env.VITE_*` |

## Service file mapping (7-file → 6-file)

| Next.js (kebab-case) | TanStack Start (`x.z`) | Change |
|---------------------|----------------------|--------|
| `schema.ts` | `{r}.schema.ts` | Rename |
| `api-schema.ts` | `{r}.api-schema.ts` | Rename |
| `queries.ts` | **→ merged into `{r}.functions.ts`** | GET server functions |
| `actions.ts` | **→ merged into `{r}.functions.ts`** | POST server functions |
| `query-options.ts` | `{r}.query-options.ts` | Rename, uses server fns as queryFn |
| `use-{resource}.ts` | `{r}.hooks.ts` | Rename, no `unwrap()` needed |
| `search-params.ts` | `{r}.search-params.ts` | Rename only |

## Provider stack migration

### Next.js
```
<MswInit>
  <ThemeProvider>
    <QueryClientProvider>
      <NuqsAdapter>            ← nuqs/adapters/next/app
        <ToastProvider>
          <AuthProvider>
            <WorkspaceProvider>
              <HydrationBoundary>
                <SidebarProvider>
                  {children}
```

### TanStack Start
```
__root.tsx:
  <ThemeProvider>
    <NuqsAdapter>              ← nuqs/adapters/react
      <Toaster />
      <Outlet />
    </NuqsAdapter>
  </ThemeProvider>

router.tsx:
  QueryClient created in getContext()
  setupRouterSsrQueryIntegration({ router, queryClient })
  // No manual QueryClientProvider or HydrationBoundary needed
```

## Package changes

| Remove | Add |
|--------|-----|
| `next` | `@tanstack/react-start` |
| `@t3-oss/env-nextjs` | `@t3-oss/env-core` |
| `next-intl` | TBD (paraglide-js or custom) |
| `next-themes` | Keep (works with any React framework) |
| — | `@tanstack/react-router` |
| — | `@tanstack/react-router-ssr-query` |
| — | `vite` |
| — | `@vitejs/plugin-react` |
| — | `nitro` |
| — | `vinxi` (for cookie helpers) |

## Import alias

Both architectures use `~/` as the import alias:

```json
{
  "compilerOptions": {
    "paths": {
      "~/*": ["./src/*"]
    }
  }
}
```

No change needed.
