# Data Fetching Architecture

Multi-layer proxy pattern where the client never talks to backends directly.

## Request flow

```
Browser → apiClient → /api/[service]/[...path] (Next.js proxy) → Backend API
Server Component → apiServer → Backend API (direct)
Server Action → apiServer → Backend API (direct)
```

## Layer 1: Client-side fetch (`apiClient`)

Used in client components via TanStack Query. Routes through the Next.js API proxy.

```typescript
// src/services/_shared/fetch-client/api-client.ts
export const apiClient = {
  main: {
    v1: createClientModule("main", "/api/v1"),
    workspace: createClientModule("main", "/workspace"),
  },
  auth: {
    api: createClientModule("auth", "/api"),
  },
  chatting: {
    v1: createClientModule("chatting", "/api/v1"),
  },
};

// Usage in query-options.ts
apiClient.main.v1.get(`/flows/getAll/workspace/${workspaceId}`, {
  headers,
  query,
  schema: paginate(flowSchema),  // Response validated with Zod
});
```

Handles 401 automatically via `refreshWithLock()` — mutex prevents concurrent refresh races.

## Layer 2: API route proxy

Single dynamic route handles ALL backend services:

```typescript
// app/api/[service]/[...path]/route.ts
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ service: string; path: string[] }> }
) {
  const { service, path } = await params;
  const baseUrl = SERVICE_URLS[service]; // Maps "main" → env.API_BASE_URL, etc.
  return handleProxy(request, path, { baseUrl });
}

// Export GET, POST, PUT, PATCH, DELETE
```

`handleProxy()` forwards the request, attaches auth headers from cookies, and returns the response.

## Layer 3: Server-side fetch (`apiServer`)

Used in server components, server actions, and `queries.ts`. Calls backends directly — no proxy needed.

```typescript
// src/services/_shared/fetch-client/api-server.ts
import "server-only";

export const apiServer = {
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

## Layer 4: Low-level fetcher (`serverFetch`)

Both `apiClient` proxy and `apiServer` ultimately use this:

```typescript
// src/services/_shared/fetch-client/server-fetch.ts
import "server-only";

export async function serverFetch(endpoint: string, init: FetchOptions = {}) {
  const headers = new Headers(init.headers);

  // Auto-attach auth from cookies
  const cookieStore = await cookies();
  const accessToken = cookieStore.get(COOKIE_KEYS.ACCESS_TOKEN)?.value;
  if (!init.skipAuth && accessToken) {
    headers.set("Authorization", `Bearer ${accessToken}`);
  }

  const response = await fetch(fullUrl, {
    ...init,
    headers,
    cache: init.cache ?? "no-store",  // CRITICAL: never cache
  });

  if (!response.ok) {
    throw new ServerApiError(errorData.message, response.status);
  }

  return response;
}
```

## Caching strategy

**CRITICAL: TanStack Query is the SOLE caching layer.**

| What | Use | Don't use |
|------|-----|-----------|
| Per-request dedup | React `cache()` in `queries.ts` | — |
| Persistent client cache | TanStack Query | Next.js fetch cache |
| Server-side revalidation | — | `revalidateTag()`, `revalidatePath()` |
| ISR | — | `next: { revalidate }` |
| Unstable cache | — | `unstable_cache()` |

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
        if (error.status >= 400 && error.status < 500) return false; // No retry on 4xx
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

## Server → client hydration

Use `HydrationBoundary` to prefetch on the server and hydrate on the client:

```typescript
// Server component (page.tsx)
const queryClient = getQueryClient();
await queryClient.prefetchQuery(flowQueries.list(request));

return (
  <HydrationBoundary state={dehydrate(queryClient)}>
    <FlowsTable />
  </HydrationBoundary>
);
```

The client picks up the prefetched data instantly — no loading state on first render.

## useSuspenseQuery is the default

**All client data-fetching components MUST use `useSuspenseQuery`**, not `useQuery`. This guarantees:
- `data` is always defined (no `data | undefined` checks)
- Loading states are handled by the nearest `<Suspense>` boundary
- Error states are handled by `error.tsx` or `<ErrorBoundary>`

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
