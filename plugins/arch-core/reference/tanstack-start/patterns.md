---
status: stable
---

# Implementation Patterns

Cross-cutting patterns used throughout the architecture.

## Error handling

Server functions throw on error — no Result pattern needed for mutations.

### Server-side errors

```typescript
// src/services/_shared/errors.ts
export class ServerApiError extends Error {
  status: number;
  code: string;
  fieldErrors?: Record<string, string[]>;
  rawData?: unknown;

  constructor(
    message: string,
    status: number,
    code?: string,
    fieldErrors?: Record<string, string[]>,
    rawData?: unknown,
  ) {
    super(message);
    this.name = "ServerApiError";
    this.status = status;
    this.code = code ?? "UNKNOWN_ERROR";
    this.fieldErrors = fieldErrors;
    this.rawData = rawData;
  }
}

export function isApiError(error: unknown): error is ServerApiError {
  return error instanceof ServerApiError;
}
```

### Server function error handling

Server functions throw `ServerApiError` when `apiFetch` gets a non-OK response. TanStack Query catches these in `onError`. No `safeAction`/`unwrap` dance needed:

```typescript
// In {resource}.functions.ts — errors throw naturally
export const createFlow = createServerFn({ method: "POST" })
  .validator((data: CreateFlowRequest) => createFlowRequestSchema.parse(data))
  .handler(async ({ data: { path, data, headers } }) => {
    // apiFetch throws ServerApiError on non-OK response
    return apiFetch.main.v1.post("/flows/create/...", data, {
      headers,
      schema: flowSchema,
    });
  });

// In {resource}.hooks.ts — TanStack Query catches the throw
export function useCreateFlowMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (req: CreateFlowRequest) => createFlow({ data: req }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: flowKeys.all }),
    onError: (error) => {
      if (isApiError(error)) {
        toast.error(error.message);
      }
    },
  });
}
```

### Result pattern (optional, for complex flows)

If you need the Result pattern for specific use cases (multi-step operations, partial failures):

```typescript
import type { Result, ApiResult } from "~/lib/utils/result";

// Still available but not the default for mutations
export type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };
```

## Schema validation at every boundary

```
Client input → Zod schema (form validation)
Server function input → .inputValidator(zodSchema)
API response → Zod schema (passed to apiFetch)
URL params → nuqs parsers (type-safe)
Environment → t3-env + Zod (env.ts)
```

No unvalidated data crosses any boundary.

## i18n validation (schema factory pattern)

User-facing validation messages need translation. Use factory functions:

```typescript
export function createCreateFlowSchema(t: TranslateFn) {
  const f = createSchemaFactory(t);
  return z.object({
    name: f.requiredString().max(255, { message: t("validation.max", { max: 255 }) }),
    botId: f.requiredStringNoTrim(),
  });
}

// Default export for non-i18n contexts (server functions, tests)
export const createFlowSchema = createCreateFlowSchema(identityTranslate);

// In form components, call with real translator
const schema = createCreateFlowSchema(t);
```

## Environment validation

```typescript
// src/env.ts
import { createEnv } from "@t3-oss/env-core";
import { z } from "zod";

export const env = createEnv({
  server: {
    API_BASE_URL: z.url(),
    AUTH_BASE_URL: z.url(),
    CHATTING_BASE_URL: z.url(),
    COOKIE_SECURE: z.string().optional().transform(v => v === "true"),
    LOG_LEVEL: z.enum(["info", "debug", "error"]).default("info"),
  },
  clientPrefix: "VITE_",
  client: {
    VITE_APP_TITLE: z.string().optional(),
    VITE_MSW_ENABLED: z.string().optional().transform(v => v === "true"),
  },
  runtimeEnv: {
    API_BASE_URL: process.env.API_BASE_URL,
    AUTH_BASE_URL: process.env.AUTH_BASE_URL,
    CHATTING_BASE_URL: process.env.CHATTING_BASE_URL,
    COOKIE_SECURE: process.env.COOKIE_SECURE,
    LOG_LEVEL: process.env.LOG_LEVEL,
    VITE_APP_TITLE: import.meta.env.VITE_APP_TITLE,
    VITE_MSW_ENABLED: import.meta.env.VITE_MSW_ENABLED,
  },
});
```

App fails to start if env vars are missing or malformed.

**Key difference from Next.js:** Client env vars use `VITE_` prefix instead of `NEXT_PUBLIC_`. Use `@t3-oss/env-core` instead of `@t3-oss/env-nextjs`.

## Workspace isolation

All data is scoped to a workspace. Every API call includes:
- Path param: `/workspace/${workspaceId}/...`
- Header: `X-Workspace-Id: ${workspaceId}`

```typescript
// src/lib/workspace/hooks.ts
import { useParams } from "@tanstack/react-router";

export function useWorkspaceId(): string {
  const { workspaceId } = useParams({ strict: false });
  return workspaceId as string;
}
```

## Server function middleware

TanStack Start supports composable middleware for server functions:

```typescript
import { createMiddleware } from "@tanstack/react-start";
import { getWebRequest } from "@tanstack/react-start/server";

// Auth middleware — attaches session to context
export const authMiddleware = createMiddleware().server(async ({ next }) => {
  const request = getWebRequest();
  const session = await getSessionFromCookies(request);

  if (!session) {
    throw new ServerApiError("Unauthorized", 401, "UNAUTHORIZED");
  }

  return next({ context: { session } });
});

// Usage in server functions
export const getFlows = createServerFn({ method: "GET" })
  .middleware([authMiddleware])
  .validator(/* ... */)
  .handler(async ({ data, context }) => {
    // context.session is available from middleware
    const { session } = context;
    // ...
  });
```

Important constraint:
- use middleware to add typed context or shared checks
- do not hide `createServerFn(...)` behind custom wrappers that Start can no longer recognize
- keep server-only helpers in `*.server.ts`

## Toast error with detail overlay

User-facing mutation errors use `toastError()` instead of raw `toast.error()`:

```typescript
// lib/toast-error.tsx
toastError('Failed to create product', error)
```

**Features:**
- Brief toast shows label + status code + truncated message
- "Details" button opens a full overlay with: status, code, validation field errors, timestamp, copy-to-clipboard
- Parses JSON-serialized errors from server functions automatically
- Handles `Error`, `string`, API errors with `{ status, code, message, details }`, and unknown types

**Usage in hooks:**

```typescript
onError: (error) => toastError('Failed to update order', error)
```

Never use raw `toast.error(error.message)` — it loses structured error info and gives poor UX.

## Filter pattern: FilterChip + FilterCard

Composable filter system for list/table pages:

```
FilterChip (container)     → toggle/expand, active indicator, clear button
  └─ FilterCard* (content) → the actual filter UI inside the chip
```

**FilterCard variants** (separate files, different DOM):

| Component | Renders |
|-----------|---------|
| `FilterCardSelect` | Checkbox multi-select with Select All/Clear All |
| `FilterCardToggle` | Three-state segment control (All / Yes / No) |
| `FilterCardPeriod` | Date range picker |
| `FilterCardRange` | Numeric range slider |

Parent manages state (`expanded`, `active`, `value`). FilterChip is a pure molecule; FilterCards are pure molecules. The table page (organism) wires them together.

## Real-time updates (WebSocket + Query invalidation)

For dashboards and chat, WebSocket events trigger TanStack Query cache invalidation:

```typescript
// hooks/use-realtime.ts
export function useRealtime() {
  const queryClient = useQueryClient()

  useEffect(() => {
    wsManager.connect(apiUrl, token)

    wsManager.subscribe('orders', () => {
      queryClient.invalidateQueries({ queryKey: ['orders'] })
    })

    wsManager.subscribe('inventory', (event) => {
      if (event.type === 'stock.low') {
        toast.warning(`Low stock: ${event.data.productName}`)
      }
    })

    return () => wsManager.disconnect()
  }, [])
}
```

**Pattern:** WebSocket is the notification channel, TanStack Query is the data channel. Socket events trigger `invalidateQueries()`, which re-fetches from the API. Never update the query cache directly from socket data — it can be stale or incomplete.

## Multi-app shared UI registry

When multiple apps share a component registry:

1. **Components must work on any surface** — gray page bg (store), white card bg (CRM), dark sections
2. **Never fork per app** — add `variant` props instead of `button-crm.tsx`
3. **Token-only styling** — guarantees portability across themes
4. **Sync scripts** — `ui:check` validates local matches registry, `ui:sync` pulls updates
5. **API stability** — never remove or rename props, only add optional ones

## Chrome tokens vs genuine dark surfaces

App chrome (global header, sidebar, subheader/`PageHeaderBar`, toolbars, and any menu/popover portaled from chrome) does **not** reuse the app's dark/inverse tokens. It paints its own dedicated token group, so the chrome's look (e.g. light frosted glass) can be retuned without touching genuinely dark pages:

| Token | Aliases | Utility |
|-------|---------|---------|
| `--chrome-bg` | = `--background` | `bg-chrome-bg` |
| `--chrome-raised` | = `--card` | `bg-chrome-raised` |
| `--chrome-border` | = `--border` | `border-chrome-border` |
| `--chrome-fg` | = `--foreground` | `text-chrome-fg` |
| `--chrome-raised-hover` | = `--muted` | `hover:bg-chrome-raised-hover` |
| `--chrome-border-hover` | = `--border-strong` | `hover:border-chrome-border-hover` |

Rules:

1. **Dedicated variants consume the group directly.** Button variants `ghost-chrome` / `ghost-chrome-quiet` and a `chrome` field variant (Input/Selector/etc.) read the `--chrome-*` tokens. Anything living in chrome uses these — never `ghost-light` / `ghost-inverse` / `variant="inverse"`, which are reserved for genuine dark surfaces.
2. **No scope-flip attributes.** Don't re-tint dark tokens per-scope with a `[data-chrome]` attribute/selector mechanism — that approach was tried and retired. A dedicated always-consistent token group is simpler and greppable.
3. **Chrome bars: 2 max** — one global breadcrumb header + at most one contextual nav row (back · title · inline tabs · actions in a single row).
4. **Translucent chrome overlays** (portaled dropdowns/popovers) own ONE glass/blur fill at the portal container; child bars inside a frosted container paint `bg-transparent` + `text-chrome-fg` — never stack a second blur layer.

### Genuine dark surfaces (immersive pages only)

`bg-surface-dark` / inverse tokens remain for pages that are *deliberately* dark (AI-assistant or team-chat style immersive surfaces) and for opaque `*-inverse` badge recipes (`destructive-inverse`, `success-inverse` — `color-mix` of the tone into `--surface-dark`). On those surfaces:

| Element | Token |
|---------|-------|
| Primary text | `text-inverse` |
| Secondary text | `text-inverse/60` |
| Muted text | `text-inverse/40` |
| Inputs | `bg-inverse/10 border-inverse/20 text-inverse` |
| Buttons | `variant="ghost-light"` (resting raised fill) / `ghost-inverse` (quiet, glyph-only) |
| Borders | `border-surface-dark-border` |
| Icons (dimmed) | `opacity-40 hover:opacity-100` (element-level, not color opacity) |
| Popovers from dark | `bg-surface-dark text-inverse border-inverse/20` |

Never use `bg-white/10` or `border-white/10` — use the semantic tokens above. And never paint chrome with these dark tokens: chrome is its own token group (above), even when it happens to be dark in one theme.

## Animation baseline

When using `tw-animate-css` with dialogs, sheets, popovers, dropdowns, or other portal content, add the close-state fill-mode fix in the global stylesheet:

```css
/* Fix tw-animate-css close animation flickering — holds final state until DOM removal */
[data-closed],
[data-state="closed"] {
  --tw-animation-fill-mode: forwards;
}
```

Apply this once in the app stylesheet:
- `src/styles/styles.css`

This avoids the common close-animation flicker where the element snaps back to its pre-animation state right before unmount.

## MSW integration

Mock handlers mirror the services structure:

```
src/mocks/handlers/
├── main/
│   ├── flows.ts
│   ├── channels.ts
│   └── ...
├── auth/
│   └── authentication.ts
└── chatting/
    └── chats.ts
```

Enable with `VITE_MSW_ENABLED=true`.

## Icon imports (lucide-react)

When using `lucide-react`, always import with the `Icon` postfix:

```typescript
// ✅ Correct — use XIcon imports
import { SearchIcon, UserIcon, ShoppingCartIcon, ChevronDownIcon } from "lucide-react";

// ❌ Wrong — bare names without Icon postfix
import { Search, User, ShoppingCart, ChevronDown } from "lucide-react";
```

This avoids naming collisions with component names and makes it clear at a glance that something is an icon.

## Naming conventions

| Category | Pattern | Example |
|----------|---------|---------|
| Files | `x.z` (dot convention) | `flows.schema.ts`, `flows.functions.ts` |
| Component files | kebab-case | `flow-create-dialog.tsx` |
| Hooks file | `{resource}.hooks.ts` | `flows.hooks.ts` |
| Functions file | `{resource}.functions.ts` | `flows.functions.ts` |
| Query options file | `{resource}.query-options.ts` | `flows.query-options.ts` |
| Search params file | `{resource}.search-params.ts` | `flows.search-params.ts` |
| Types | No "Schema" suffix | `Flow`, `CreateFlow` |
| Route-scoped folders | Dash prefix | `-components/` |
| Pathless layouts | Underscore prefix | `_authed.tsx`, `_workspace.tsx` |
| Route params | Dollar sign | `$workspaceId`, `$id` |
