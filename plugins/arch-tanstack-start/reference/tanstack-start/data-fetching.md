# Data Fetching Architecture

Server functions replace the multi-layer proxy. The client never talks to backends directly — `createServerFn` handles it.

## Request flow

```
Route loader → server function → apiFetch → Backend API (direct, server-side)
Component (useSuspenseQuery) → server function → apiFetch → Backend API (direct, server-side)
Mutation → server function → apiFetch → Backend API (direct, server-side)
```

There is NO proxy layer. Server functions run on the server regardless of where they're called from.

## Server functions (`createServerFn`)

The core primitive. Replaces Next.js API routes, `"server-only"` queries, and `"use server"` actions.

```typescript
import { createServerFn } from "@tanstack/react-start";
import { apiFetch } from "~/services/_shared/fetch-client/api-fetch";

// GET (default method) — used for data fetching (route loaders, query options)
export const getFlows = createServerFn({ method: "GET" })
  .inputValidator(getAllFlowsRequestSchema)
  .handler(async ({ data: { path, query, headers } }) => {
    return apiFetch.main.v1.get(`/flows/getAll/workspace/${path.workspaceId}`, {
      headers,
      query,
      schema: paginate(flowSchema),
    });
  });

// POST — used for mutations (create, update, delete)
export const createFlow = createServerFn({ method: "POST" })
  .inputValidator(createFlowRequestSchema)
  .handler(async ({ data: { path, data, headers } }) => {
    return apiFetch.main.v1.post(
      `/flows/create/workspace/${path.workspaceId}`,
      data,
      { headers, schema: flowSchema },
    );
  });
```

**Validation:** `.inputValidator()` accepts a Zod schema directly (Standard Schema support), a schema with `.parse()`, or a `(input) => output` function. Passing a Zod schema is preferred — no manual `.parse()` call needed.

### Key differences from Next.js proxy

| Next.js | TanStack Start |
|---------|---------------|
| `apiClient` → proxy route → backend | Server function → backend (direct) |
| `apiServer` → backend (server only) | Server function → backend (same) |
| Manual `"server-only"` import | Automatic — server functions always run server-side |
| `"use server"` directive | `createServerFn()` declaration |
| `safeAction()` wrapper | Error handling in `apiFetch` or middleware |
| Proxy hides backend URLs | Server functions hide backend URLs natively |
| `refreshWithLock()` in apiClient | Auth middleware on server functions |

## Fetch client (`apiFetch`)

Single server-side fetch module. Used inside server functions only.

```typescript
// src/services/_shared/fetch-client/api-fetch.ts
import { getWebRequest } from "@tanstack/react-start/server";
import { env } from "~/env";

function createServerModule(baseUrl: string, prefix: string) {
  const buildUrl = (path: string) => `${prefix}${path}`;

  return {
    get: <T>(path: string, opts?: RequestOptions) =>
      serverFetch<T>(buildUrl(path), {
        method: "GET",
        baseUrl,
        ...opts,
      }),

    post: <T>(path: string, data?: unknown, opts?: RequestOptions) =>
      serverFetch<T>(buildUrl(path), {
        method: "POST",
        baseUrl,
        body: data ? JSON.stringify(data) : undefined,
        headers: { "Content-Type": "application/json", ...opts?.headers },
        ...opts,
      }),

    // put, patch, delete...
  };
}

export const apiFetch = {
  main: {
    v1: createServerModule(env.API_BASE_URL, "/api/v1"),
  },
  auth: {
    api: createServerModule(env.AUTH_BASE_URL, "/api"),
  },
  chatting: {
    v1: createServerModule(env.CHATTING_BASE_URL, "/api/v1"),
  },
};
```

### Auth injection

Inside `serverFetch`, use `getWebRequest()` to read cookies from the incoming request:

```typescript
import { getWebRequest } from "@tanstack/react-start/server";

async function serverFetch<T>(endpoint: string, init: FetchOptions = {}): Promise<T> {
  const headers = new Headers(init.headers);

  // Auto-attach auth from the incoming request's cookies
  if (!init.skipAuth) {
    const request = getWebRequest();
    const cookieHeader = request.headers.get("cookie") ?? "";
    const accessToken = parseCookie(cookieHeader, "access_token");
    if (accessToken) {
      headers.set("Authorization", `Bearer ${accessToken}`);
    }
  }

  const response = await fetch(fullUrl, {
    ...init,
    headers,
  });

  if (!response.ok) {
    throw new ServerApiError(/* ... */);
  }

  const data = await response.json();
  return init.schema ? init.schema.parse(data) : data;
}
```

## Route loaders + TanStack Query SSR

Use route loaders to prefetch data on the server. TanStack Router + Query SSR integration handles hydration automatically.

```typescript
// src/routes/_authed/_workspace/buying/flows.tsx
import { createFileRoute } from "@tanstack/react-router";
import { flowQueries } from "~/services/main/flows/flows.query-options";

export const Route = createFileRoute("/_authed/_workspace/buying/flows")({
  loader: ({ context }) => {
    // Prefetch on server, hydrate on client
    context.queryClient.ensureQueryData(flowQueries.list(/* request */));
  },
  component: FlowsPage,
  pendingComponent: FlowsPageLoader,
  errorComponent: FlowsErrorPage,
});
```

No `HydrationBoundary` wrapper needed — `@tanstack/react-router-ssr-query` handles this automatically when `setupRouterSsrQueryIntegration` is configured in the router.

## Caching strategy

**CRITICAL: TanStack Query is the SOLE caching layer.**

| What | Use |
|------|-----|
| Client cache + sync | TanStack Query |
| SSR prefetch | Route `loader` + `ensureQueryData` |
| Server dedup | Not needed — server functions handle their own requests |

### TanStack Query defaults

```typescript
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60 * 1000,        // 1 minute
      gcTime: 5 * 60 * 1000,       // 5 minutes
      refetchOnWindowFocus: false,
      refetchOnReconnect: true,
      retry: (failureCount, error) => {
        if (error.status >= 400 && error.status < 500) return false;
        return failureCount < 2;
      },
    },
  },
});
```

### Per-query overrides

- **List queries:** `placeholderData: keepPreviousData` (smooth pagination)
- **Detail queries:** `staleTime: 10min`, `gcTime: 30min`, `refetchOnMount: false`
- **Rarely-changing data:** higher stale/gc times as appropriate

## useSuspenseQuery is the default

**All data-fetching components MUST use `useSuspenseQuery`**, not `useQuery`. This guarantees:
- `data` is always defined (no `data | undefined` checks)
- Loading states are handled by the nearest `<Suspense>` boundary
- Error states are handled by `errorComponent` on the route or `<ErrorBoundary>`

```typescript
// ✅ Correct — data is always defined, loading handled by Suspense
function FlowsList() {
  const { data } = useSuspenseQuery(flowQueries.list(request));
  return data.content.map(flow => <FlowItem key={flow.id} flow={flow} />);
}

// Usage: wrap in Suspense boundary
<Suspense fallback={<FlowsListSkeleton />}>
  <FlowsList />
</Suspense>
```

### When to use `useQuery` (last resort)

`useQuery` is acceptable ONLY for:

| Case | Why | Example |
|------|-----|---------|
| Auth state check | Need `isLoading`/`isError` before routing decisions | `useSession()` in auth guard |
| Background polling | Silent refresh, should not trigger Suspense fallback | WebSocket fallback polling |
| Optional/conditional data | Request may be `undefined`, component renders without it | Sidebar widget that degrades gracefully |

## What gets deleted from Next.js

| Deleted | Why |
|---------|-----|
| `app/api/[service]/[...path]/route.ts` | Server functions replace the proxy |
| `services/_shared/fetch-client/api-client.ts` | No client-side fetch through proxy |
| `services/_shared/proxy-handler.ts` | No proxy handler |
| `services/_shared/safe-action.ts` | Replaced by server function error handling |
| `proxy.ts` (Next.js middleware) | Replaced by TanStack Start middleware |
| `queries.ts` per resource | Merged into `{resource}.functions.ts` |
| `actions.ts` per resource | Merged into `{resource}.functions.ts` |
