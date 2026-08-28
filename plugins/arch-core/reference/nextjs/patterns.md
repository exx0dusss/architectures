# Implementation Patterns

Cross-cutting patterns used throughout the architecture.

## Error handling — Result pattern

All server actions return `Result<T, E>` instead of throwing.

```typescript
// src/lib/utils/result.ts
export type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

export type ApiResult<T> = Result<T, ApiError>;

// Unwrap: converts Result to value or throws (for use in mutationFn)
export function unwrap<T>(result: Result<T>): T {
  if (!result.ok) throw result.error;
  return result.value;
}
```

### Server actions use `safeAction`

```typescript
"use server";

export async function createFlow(request: CreateFlowRequest): Promise<ApiResult<Flow>> {
  return safeAction(
    async () => {
      const parsed = createFlowRequestSchema.parse(request);
      return await apiServer.main.v1.post("/flows/create/...", parsed.data, {
        headers: parsed.headers,
        schema: flowSchema,
      });
    },
    { code: "FLOWS_CREATE_FAILED", message: "Failed to create flow" },
  );
}
```

`safeAction` catches any thrown error and wraps it in `{ ok: false, error: { code, message } }`.

### Client mutations unwrap

```typescript
useMutation({
  mutationFn: async (req) => unwrap(await createFlow(req)),  // throws on error → caught by TanStack
  onSuccess: () => queryClient.invalidateQueries({ queryKey: flowKeys.all }),
  onError: (error) => toast.error(error.message),
});
```

## Error classes

```typescript
// Server-side errors (direct backend calls)
class ServerApiError extends BaseApiError {
  message: string;
  status: number;
  code: string;
  fieldErrors?: Record<string, string[]>;  // Per-field validation errors from backend
}

// Client-side errors (proxy calls)
class ClientApiError extends BaseApiError {
  // Same shape, used when apiClient gets an error response from proxy
}
```

## Schema validation at every boundary

```
Client input → Zod schema (form validation)
Server action input → Zod schema (.parse)
API response → Zod schema (passed to fetch call)
URL params → nuqs parsers (type-safe)
Environment → t3-env + Zod (env.ts)
```

No unvalidated data crosses any boundary.

## i18n validation (schema factory pattern)

User-facing validation messages need translation. Use factory functions:

```typescript
// Creates schema with translated error messages
export function createCreateFlowSchema(t: TranslateFn) {
  const f = createSchemaFactory(t);
  return z.object({
    name: f.requiredString().max(255, { message: t("validation.max", { max: 255 }) }),
    botId: f.requiredStringNoTrim(),
  });
}

// Default export for non-i18n contexts (server actions, tests)
export const createFlowSchema = createCreateFlowSchema(identityTranslate);

// In form components, call with real translator
const schema = createCreateFlowSchema(t);
```

## Multi-service proxy pattern

The app proxies all client API calls through Next.js API routes. This:
- Hides backend URLs from the browser
- Attaches auth tokens from httpOnly cookies
- Enables per-service routing

```
apiClient.main.v1.get("/flows/...")
  → fetch("/api/main/api/v1/flows/...")
  → API route maps "main" to env.API_BASE_URL
  → handleProxy forwards to backend
```

Service URL mapping:

```typescript
const SERVICE_URLS: Record<string, string> = {
  main: env.API_BASE_URL,
  auth: env.AUTH_BASE_URL,
  chatting: env.CHATTING_BASE_URL,
  // Add more services here
};
```

## Environment validation

```typescript
// src/env.ts
import { createEnv } from "@t3-oss/env-nextjs";

export const env = createEnv({
  server: {
    API_BASE_URL: z.url(),
    AUTH_BASE_URL: z.url(),
    CHATTING_BASE_URL: z.url(),
    COOKIE_SECURE: z.string().optional().transform(v => v === "true"),
    LOG_LEVEL: z.enum(["info", "debug", "error"]).default("info"),
  },
  client: {
    NEXT_PUBLIC_URL: z.url().default("http://localhost:3000"),
    NEXT_PUBLIC_APP_MODE: z.enum(["development", "production"]),
    NEXT_PUBLIC_MSW_ENABLED: z.string().optional().transform(v => v === "true"),
  },
});
```

App fails to start if env vars are missing or malformed.

## Workspace isolation

All data is scoped to a workspace. Every API call includes:
- Path param: `/workspace/${workspaceId}/...`
- Header: `X-Workspace-Id: ${workspaceId}`

```typescript
// src/lib/workspace/hooks.ts
export function useWorkspaceId(): string {
  const params = useParams();
  return params.workspaceId as string;
}

export function useWorkspace() {
  const workspaceId = useWorkspaceId();
  // Returns workspace data, navigation helpers, etc.
}
```

## i18n (next-intl)

```typescript
// Config
export const locales = ["uk", "ru", "en"] as const;
export const defaultLocale = "uk";
export const localePrefix = "never";  // Managed via cookies, not URL prefix

// Server components
const t = await getTranslations("flows");
return <h1>{t("title")}</h1>;

// Client components
const t = useTranslations("flows");
return <h1>{t("title")}</h1>;
```

## Toast error with detail overlay

User-facing mutation errors use `toastError()` instead of raw `toast.error()`:

```typescript
// lib/toast-error.tsx
toastError('Failed to create flow', error)
```

**Features:**
- Brief toast shows label + status code + truncated message
- "Details" button opens a full overlay with: status, code, validation field errors, timestamp, copy-to-clipboard
- Parses JSON-serialized errors from server actions automatically
- Handles `Error`, `string`, API errors with `{ status, code, message, details }`, and unknown types

**Usage in hooks:**

```typescript
onError: (error) => toastError('Failed to update flow', error)
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

Parent manages state. FilterChip and FilterCards are pure molecules.

## Real-time updates (WebSocket + Query invalidation)

WebSocket events trigger TanStack Query cache invalidation:

```typescript
wsManager.subscribe('orders', () => {
  queryClient.invalidateQueries({ queryKey: ['orders'] })
})
```

**Pattern:** WebSocket is the notification channel, TanStack Query is the data channel. Socket events trigger `invalidateQueries()`, which re-fetches from the API. Never update the query cache directly from socket data.

## Multi-app shared UI registry

When multiple apps share a component registry:

1. **Components must work on any surface** — gray page bg, white card bg, dark sections
2. **Never fork per app** — add `variant` props instead of `button-crm.tsx`
3. **Token-only styling** — guarantees portability across themes
4. **API stability** — never remove or rename props, only add optional ones

## Dark surface variant system

For components that render on `bg-surface-dark`:

| Element | Token |
|---------|-------|
| Primary text | `text-inverse` |
| Secondary text | `text-inverse/60` |
| Muted text | `text-inverse/40` |
| Inputs | `bg-inverse/10 border-inverse/20 text-inverse` |
| Buttons | `variant="ghost-light"` |
| Borders | `border-surface-dark-border` |
| Icons (dimmed) | `opacity-40 hover:opacity-100` (element-level) |

Never use `bg-white/10` or `border-white/10` — use the semantic tokens above.

## MSW integration

Mock handlers mirror the services structure:

```
src/mocks/handlers/
├── main/
│   ├── flows.ts          # Mock /api/v1/flows/... endpoints
│   ├── channels.ts
│   └── ...
├── auth/
│   └── authentication.ts
└── chatting/
    └── chats.ts
```

Enable with `NEXT_PUBLIC_MSW_ENABLED=true`. The `<MswInit>` provider initializes the service worker in development.

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
| Files | kebab-case | `flow-create-dialog.tsx` |
| Schemas | `schema.ts`, `api-schema.ts` | — |
| Hooks | `use-{resource}.ts` | `use-flows.ts` |
| Actions | `actions.ts` | — |
| Queries | `queries.ts` | — |
| Query options | `query-options.ts` | — |
| Search params | `search-params.ts` | — |
| Types | No "Schema" suffix | `Flow`, `CreateFlow` |
| Private folders | Underscore prefix | `_components/` |
| Route groups | Parentheses | `(auth)`, `(app)` |
