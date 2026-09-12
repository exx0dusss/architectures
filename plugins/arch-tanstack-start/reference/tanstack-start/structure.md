# Folder Structure

```
src/
├── routes/                        # TanStack Router file-based routing
│   ├── __root.tsx                 # Root layout (HTML shell, providers, devtools)
│   ├── index.tsx                  # Home / landing
│   ├── _authed.tsx                # Auth layout (protected routes)
│   ├── _authed/
│   │   ├── workspaces.tsx         # Workspace picker
│   │   └── workspace/
│   │       └── $workspaceId/
│   │           ├── _workspace.tsx # Workspace layout (sidebar, header)
│   │           ├── _workspace/
│   │           │   ├── {module}/
│   │           │   │   ├── _module.tsx          # Module layout (module sidebar)
│   │           │   │   ├── _module/
│   │           │   │   │   ├── {resource}.tsx           # List page
│   │           │   │   │   └── {resource}.$id.tsx       # Detail page
│   │           │   │   └── -components/                 # Route-scoped (non-routable)
│   │           │   │       ├── columns.tsx
│   │           │   │       ├── {resource}-table.tsx
│   │           │   │       ├── {resource}-toolbar.tsx
│   │           │   │       ├── {resource}-header.tsx
│   │           │   │       ├── {resource}-page-loader.tsx
│   │           │   │       └── modals/
│   │           │   └── ...
│   │           └── ...
│   ├── auth/
│   │   ├── login.tsx              # Login page
│   │   ├── register.tsx           # Register page
│   │   └── reset-password.tsx     # Password reset
│   └── api/                       # API routes (if needed for webhooks, etc.)
│       └── auth/
│           └── refresh.ts         # Token refresh endpoint
│
├── components/                    # Shared React components
│   ├── ui/                        # UI primitives (shadcn/Base UI components)
│   │   ├── button.tsx
│   │   ├── input.tsx
│   │   ├── dialog.tsx
│   │   ├── select.tsx
│   │   └── ...
│   ├── layout/                    # Header, sidebar, footer
│   │   ├── header/
│   │   └── sidebar/
│   ├── avatars/
│   ├── badges/
│   ├── buttons/                   # Composed buttons
│   ├── data-table/                # Generic data table
│   ├── filters/
│   ├── form/                      # Form field components (TanStack Form)
│   ├── icons/
│   ├── inputs/
│   ├── loaders/
│   ├── modals/
│   ├── selectors/
│   ├── sheets/
│   ├── suspense/
│   └── table/
│
├── hooks/                         # Shared custom hooks
│   ├── use-mobile.tsx
│   ├── use-data-table.ts
│   ├── form.tsx
│   └── ...
│
├── i18n/                          # Internationalization
│   ├── config.ts                  # Locales, default locale
│   └── zod.ts                     # Schema factory for i18n validation messages
│
├── integrations/                  # Third-party integrations
│   └── tanstack-query/
│       ├── root-provider.tsx      # QueryClient setup + SSR integration
│       └── devtools.tsx           # Query devtools
│
├── lib/                           # Core libraries
│   ├── auth/
│   │   ├── core/
│   │   │   └── roles.ts                       # Role allowlist (isCrmRole)
│   │   └── server/
│   │       ├── session.ts                     # useAppSession, getSessionUser,
│   │       │                                  # clearAuthSession, getAuthLogoutState
│   │       ├── refresh.ts                     # performRefresh (pure HTTP, no session writes)
│   │       ├── ensure-access-token.ts         # race-safe bridge — shared HTTP refresh,
│   │       │                                  # per-request session write (see auth-rbac.md)
│   │       ├── ensure-access-token.test.ts    # concurrency proofs
│   │       └── login.ts                       # loginWithCredentials — full login flow
│   ├── rbac/
│   │   ├── permissions.ts         # Permission flat strings
│   │   ├── roles.ts               # Role hierarchy
│   │   ├── types.ts
│   │   ├── validate.ts
│   │   ├── server/                # requirePermission, requireRole
│   │   └── client/                # useAccess hook, <Can> component
│   ├── workspace/
│   │   ├── hooks.ts               # useWorkspace, useWorkspaceId
│   │   ├── routes.ts
│   │   ├── navigation.ts
│   │   └── storage.ts
│   ├── utils/
│   │   ├── result.ts              # Result<T, E> type
│   │   ├── cn.ts                  # tailwind-merge + clsx
│   │   ├── date.ts
│   │   ├── timezone.ts
│   │   └── query.ts
│   ├── logger.ts
│   ├── dayjs.ts                   # Pre-configured dayjs
│   └── socket.ts                  # Socket.IO client
│
├── mocks/                         # MSW mock handlers
│   ├── handlers/
│   │   ├── {service}/             # Mirrors services/ structure
│   │   └── ...
│   ├── msw-init.tsx               # Provider component
│   └── data/                      # Mock data factories
│
├── services/                      # Backend API integrations
│   ├── _shared/                   # Shared service infrastructure
│   │   ├── fetch-client/
│   │   │   ├── api-fetch.ts       # Server fetch — calls ensureAccessToken(),
│   │   │   │                      # attaches Bearer, retries once on 401 with
│   │   │   │                      # ensureAccessToken({ force: true })
│   │   │   └── constants.ts
│   │   ├── schema/
│   │   │   ├── query.ts           # Base query schema
│   │   │   ├── paginate.ts        # Pagination wrapper
│   │   │   └── request.ts         # Common request schemas
│   │   ├── errors.ts              # Error classes
│   │   ├── safe-server-fn.ts      # Server function error wrapper
│   │   ├── query-keys.ts          # Key segment constants
│   │   ├── query-times.ts         # Stale/GC time presets
│   │   ├── search-params.ts       # Global URL parsers
│   │   └── types.ts
│   ├── {service}/                 # One folder per backend service
│   │   └── {resource}/            # 6-file resource pattern (x.z convention)
│   │       ├── {resource}.schema.ts
│   │       ├── {resource}.api-schema.ts
│   │       ├── {resource}.functions.ts
│   │       ├── {resource}.query-options.ts
│   │       ├── {resource}.hooks.ts
│   │       └── {resource}.search-params.ts
│   └── ...
│
├── stores/                        # Zustand stores
│   └── sidebar-store.ts
│
├── styles/
│   └── styles.css                 # Tailwind v4 + semantic design tokens
│
├── testing/
│   └── render.tsx                 # Custom RTL render with providers
│
├── types/                         # Global TypeScript declarations
│
├── env.ts                         # Runtime env validation (t3-env + Zod)
├── router.tsx                     # Router creation + context
└── routeTree.gen.ts               # Auto-generated route tree
```

## Key conventions

- **Route-scoped folders** use dash prefix: `-components/` (non-routable in TanStack Router)
- **Pathless layouts**: `_authed.tsx`, `_workspace.tsx` — layout wrappers without URL segments
- **Dynamic segments**: `$workspaceId`, `$id` (dollar sign, not brackets)
- **Dot convention (`x.z`)**: service files are `{resource}.{concern}.ts` — e.g. `flows.schema.ts`, `flows.functions.ts`
- **Colocation**: route-scoped components live in `-components/` next to route files
- **Services mirror backends**: each backend service gets its own folder under `services/`
- **No proxy routes**: server functions handle all backend communication directly
- **No barrels in `lib/auth/`**: import directly from the owning file. `index.ts` inside `lib/auth/` or `lib/auth/server/` is forbidden — it hides dead exports and risks pulling server-only modules into client-reachable graphs.
- **No `client/` subdir in `lib/auth/`**: TanStack Start refreshes tokens inside server functions via `ensureAccessToken()`. There is no browser-side refresh lock because the browser never talks to the API directly. (The Next.js architecture has a `client/refresh-lock.ts` for exactly that reason — don't port it over.)

## Next.js → TanStack Start naming map

| Next.js | TanStack Start |
|---------|---------------|
| `app/` | `routes/` |
| `layout.tsx` | `_layout.tsx` or pathless routes (`_authed.tsx`) |
| `page.tsx` | `{name}.tsx` (route file) |
| `[param]` | `$param` |
| `[...catchAll]` | `$.tsx` (splat route) |
| `(group)` | Pathless layout routes (`_name.tsx`) |
| `_components/` | `-components/` |
| `loading.tsx` | `pendingComponent` on route |
| `error.tsx` | `errorComponent` on route |
| `not-found.tsx` | `notFoundComponent` on route |
| `NEXT_PUBLIC_*` | `VITE_*` |
