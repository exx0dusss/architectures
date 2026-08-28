# Folder Structure

```
src/
├── app/                           # Next.js App Router
│   ├── [locale]/                  # i18n locale wrapper
│   │   ├── (auth)/auth/           # Public auth pages (login, register, reset)
│   │   ├── (app)/                 # Authenticated app routes
│   │   │   ├── workspaces/        # Workspace picker
│   │   │   └── workspace/[workspaceId]/
│   │   │       ├── {module}/      # Feature modules (e.g. buying, chatting)
│   │   │       │   ├── {resource}/
│   │   │       │   │   ├── page.tsx
│   │   │       │   │   ├── [id]/
│   │   │       │   │   │   └── page.tsx
│   │   │       │   │   └── _components/     # Private, colocated
│   │   │       │   │       ├── columns.tsx
│   │   │       │   │       ├── {resource}-table.tsx
│   │   │       │   │       ├── {resource}-toolbar.tsx
│   │   │       │   │       ├── {resource}-header.tsx
│   │   │       │   │       ├── {resource}-page-loader.tsx
│   │   │       │   │       └── modals/
│   │   │       │   └── layout.tsx           # Module sidebar
│   │   │       └── layout.tsx               # Workspace layout
│   │   └── layout.tsx                       # Root locale layout
│   └── api/
│       ├── [service]/[...path]/   # Dynamic proxy for all backend services
│       │   └── route.ts           # GET, POST, PUT, PATCH, DELETE handlers
│       └── auth/                  # Auth-specific routes (login, refresh, logout)
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
│   ├── routing.ts                 # next-intl routing config
│   └── zod.ts                     # Schema factory for i18n validation messages
│
├── lib/                           # Core libraries
│   ├── auth/
│   │   ├── core/                  # Config, types, JWT utils
│   │   ├── server/                # Session, cookies, proxy auth
│   │   ├── client/                # Refresh lock (mutex)
│   │   └── refresh.ts
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
├── providers/                     # Root context providers
│   ├── providers.tsx              # Provider stack orchestrator
│   ├── theme-provider.tsx
│   ├── query-client-provider.tsx
│   └── devtools-provider.tsx
│
├── services/                      # Backend API integrations
│   ├── _shared/                   # Shared service infrastructure
│   │   ├── fetch-client/
│   │   │   ├── api-client.ts      # Client-side fetch (through proxy)
│   │   │   ├── api-server.ts      # Server-side fetch (direct)
│   │   │   ├── server-fetch.ts    # Low-level server fetcher
│   │   │   └── constants.ts
│   │   ├── schema/
│   │   │   ├── query.ts           # Base query schema
│   │   │   ├── paginate.ts        # Pagination wrapper
│   │   │   └── request.ts         # Common request schemas
│   │   ├── errors.ts              # Error classes
│   │   ├── safe-action.ts         # Server action wrapper
│   │   ├── proxy-handler.ts       # API route proxy logic
│   │   ├── query-keys.ts          # Key segment constants
│   │   ├── query-times.ts         # Stale/GC time presets
│   │   ├── search-params.ts       # Global URL parsers
│   │   └── types.ts
│   ├── {service}/                 # One folder per backend service
│   │   └── {resource}/            # 7-file resource pattern
│   │       ├── schema.ts
│   │       ├── api-schema.ts
│   │       ├── queries.ts
│   │       ├── query-options.ts
│   │       ├── actions.ts
│   │       ├── use-{resource}.ts
│   │       └── search-params.ts
│   └── ...
│
├── styles/
│   └── globals.css                # Tailwind v4 + semantic design tokens
│
├── testing/
│   └── render.tsx                 # Custom RTL render with all providers
│
├── types/                         # Global TypeScript declarations
│
├── env.ts                         # Runtime env validation (t3-env + Zod)
└── proxy.ts                       # Next.js middleware (auth + i18n)
```

## Key conventions

- **Private folders** use underscore prefix: `_components/`, `_providers/`
- **Route groups** use parentheses: `(auth)`, `(app)`, `(with-sidebar)`, `(chat)`
- **Dynamic segments**: `[locale]`, `[workspaceId]`, `[id]`
- **API catch-all**: `[service]/[...path]/route.ts` handles all proxy routes
- **Colocation**: page-specific components live in `_components/` next to `page.tsx`
- **Services mirror backends**: each backend service gets its own folder under `services/`
