# State Management

Three state layers, each with a clear responsibility. No overlap.

## Overview

| Layer | Tool | What it manages | Where it lives |
|-------|------|----------------|----------------|
| Server state | TanStack Query | API data, caching, sync | `query-options.ts`, `use-{resource}.ts` |
| URL state | nuqs | Pagination, filters, sort, search | `search-params.ts` |
| Client global | Zustand | Cross-component UI state | `src/stores/` |

## Server state (TanStack Query)

**The sole caching layer.** All API data flows through TanStack Query.

### Defaults

```typescript
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60_000,          // 1 minute
      gcTime: 5 * 60_000,         // 5 minutes
      refetchOnWindowFocus: false,
      refetchOnReconnect: true,
      retry: (count, error) => {
        if (error.status >= 400 && error.status < 500) return false;
        return count < 2;
      },
    },
  },
});
```

### Per-query tuning

| Query type | staleTime | gcTime | Other |
|-----------|-----------|--------|-------|
| List | default (1min) | default (5min) | `placeholderData: keepPreviousData` |
| Detail | 10 min | 30 min | `refetchOnMount: false`, `refetchOnWindowFocus: false` |
| Rarely changing | higher as needed | higher as needed | — |

### Mutation → invalidation pattern

```typescript
export function useCreateFlowMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (req) => unwrap(await createFlow(req)),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: flowKeys.all });
    },
  });
}
```

Always invalidate the entire resource key (`flowKeys.all`) on any mutation. TanStack Query handles refetching only active queries.

## URL state (nuqs)

Type-safe search params that drive table pagination, filtering, and sorting.

### Global parsers (shared by all tables)

```typescript
// src/services/_shared/search-params.ts
export const globalParsers = {
  page: parseAsInteger.withDefault(1),
  size: parseAsInteger.withDefault(25),
  sort: parseAsArrayOf(parseAsString).withDefault([]),
  search: parseAsString.withDefault(""),
};
```

### Resource-specific parsers

```typescript
// src/services/main/flows/search-params.ts
export const flowsParsers = {
  ...globalParsers,
  status: parseAsStringEnum([...FlowStatusEnum.options, "all"]).withDefault("all"),
  archive: parseAsStringEnum(["LIVE", "ARCHIVE", "all"]).withDefault("all"),
  user: parseAsString.withDefault("all"),
};
```

### URL → API conversion

```typescript
export function toFlowsQuery(params: FlowsSearchParams) {
  return {
    page: params.page - 1,       // API is 0-indexed
    size: params.size,
    flowSort: params.sort.length ? params.sort : undefined,
    searchBy: params.search || undefined,
    statusFilter: params.status !== "all" ? params.status : undefined,
  };
}
```

### Usage in components

```typescript
"use client";

function FlowsToolbar() {
  const [params, setParams] = useQueryStates(flowsParsers);

  return (
    <FilterBar>
      <SearchInput
        value={params.search}
        onChange={(v) => setParams({ search: v, page: 1 })}
      />
      <StatusFilter
        value={params.status}
        onChange={(v) => setParams({ status: v, page: 1 })}
      />
    </FilterBar>
  );
}
```

Changing a filter resets page to 1. URL is the source of truth — shareable, bookmarkable, back-button friendly.

## Client global state (Zustand)

For cross-component UI state that doesn't fit URL or server state.

Examples:
- Sidebar open/close state
- Modal stacking
- Temporary selections before save
- WebSocket connection status

```typescript
// src/stores/sidebar-store.ts
export const useSidebarStore = create<SidebarState>((set) => ({
  isOpen: true,
  toggle: () => set((s) => ({ isOpen: !s.isOpen })),
  close: () => set({ isOpen: false }),
}));
```

**Rule:** If data comes from the API → TanStack Query. If it's in the URL → nuqs. Only use Zustand for everything else.
