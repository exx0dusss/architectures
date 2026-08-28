# 7-File Service Resource Convention

Every backend resource lives in `src/services/{service}/{resource}/` and follows this strict 7-file pattern.

## File overview

| # | File | Purpose | Directive |
|---|------|---------|-----------|
| 1 | `schema.ts` | DTO schemas, enums, create/update schemas | — |
| 2 | `api-schema.ts` | Request shape schemas (path, query, data, headers) | — |
| 3 | `queries.ts` | Server-only data fetching with `cache()` | `"server-only"` |
| 4 | `query-options.ts` | TanStack Query key factories and query options | — |
| 5 | `actions.ts` | Server actions wrapped in `safeAction` | `"use server"` |
| 6 | `use-{resource}.ts` | Client hooks (useSuspenseQuery, useMutation, useQuery for edge cases) | `"use client"` |
| 7 | `search-params.ts` | URL state parsers (nuqs) and query converters | — |

---

## 1. `schema.ts` — DTO Definitions

```typescript
// Enums at the TOP
export const FLOW_STATUSES = ["ACTIVE", "ERROR", "ARCHIVED"] as const;
export const FlowStatusEnum = z.enum(FLOW_STATUSES);
export type FlowStatus = z.infer<typeof FlowStatusEnum>;

// Create schema factory (for i18n validation messages)
export function createCreateFlowSchema(t: TranslateFn) {
  const f = createSchemaFactory(t);
  return z.object({
    name: f.requiredString().max(255),
    botId: f.requiredStringNoTrim(),
    channelId: f.requiredStringNoTrim(),
  });
}
export const createFlowSchema = createCreateFlowSchema(identityTranslate);
export type CreateFlow = z.infer<typeof createFlowSchema>;

// Update schema (partial of create)
export function createUpdateFlowSchema(t: TranslateFn) {
  return createCreateFlowSchema(t).partial();
}
export const updateFlowSchema = createUpdateFlowSchema(identityTranslate);
export type UpdateFlow = z.infer<typeof updateFlowSchema>;

// DTO schema
export function createFlowDtoSchema(t: TranslateFn) {
  return z.object({
    id: z.coerce.string(),
    name: z.string(),
    status: FlowStatusEnum,
    createdAt: z.iso.datetime({ local: true }),
  });
}
export const flowSchema = createFlowDtoSchema(identityTranslate);
export type Flow = z.infer<typeof flowSchema>;
```

**Rules:**
- Enums go at the top of the file
- Use `z.infer` for all types (post-transform)
- Export type immediately after its schema
- Factory pattern (`createXxxSchema(t)`) for user-facing validation messages
- Export a default instance with `identityTranslate` for non-i18n contexts

---

## 2. `api-schema.ts` — Request Schemas

```typescript
const flowPathParamsSchema = workspacePathParamsSchema.extend({
  flowId: z.coerce.string(),
});

export const getAllFlowsRequestSchema = z.object({
  path: workspacePathParamsSchema,
  query: baseQuerySchema.extend({
    userId: z.string().optional(),
    statusFilter: FlowStatusEnum.optional(),
  }),
  headers: workspaceHeaderSchema,
});
export type GetAllFlowsRequest = z.infer<typeof getAllFlowsRequestSchema>;

export const createFlowRequestSchema = z.object({
  path: workspacePathParamsSchema,
  query: z.object({ userId: z.string() }),
  data: createFlowSchema,
  headers: workspaceHeaderSchema,
});
export type CreateFlowRequest = z.infer<typeof createFlowRequestSchema>;
```

**Rules:**
- Request shape is always `{ path, query, data, headers }` (omit unused fields)
- Extend shared schemas (`workspacePathParamsSchema`, `workspaceHeaderSchema`)
- Use `z.infer` (these are already-parsed types)

---

## 3. `queries.ts` — Server-Only Data Fetching

```typescript
import "server-only";
import { cache } from "react";

export const getAllFlows = cache(async (request: GetAllFlowsRequest) => {
  const { path, query, headers } = getAllFlowsRequestSchema.parse(request);
  return apiServer.main.v1.get(`/flows/getAll/workspace/${path.workspaceId}`, {
    headers,
    query: { userId: query.userId, page: query.page },
    schema: paginate(flowSchema),
  });
});

export const getFlowById = cache(async (request: GetFlowByIdRequest) => {
  const { path, headers } = getFlowByIdRequestSchema.parse(request);
  return apiServer.main.v1.get(`/flows/${path.flowId}/workspace/${path.workspaceId}`, {
    headers,
    schema: flowSchema,
  });
});
```

**Rules:**
- `"server-only"` import at top — these NEVER run on the client
- Wrap in React `cache()` for per-request deduplication (NOT `next/cache`)
- Use `apiServer` — calls backends directly (no proxy)
- Always validate input with `.parse(request)`
- Pass `schema` to the fetch call for response validation

---

## 4. `query-options.ts` — TanStack Query Factories

```typescript
// Key factory
export const flowKeys = {
  all: ["buying", "flows"] as const,
  lists: () => [...flowKeys.all, KEY_SEGMENTS.LISTS] as const,
  list: (scope = "main", params = "skipped") =>
    [...flowKeys.lists(), scope, params] as const,
  details: () => [...flowKeys.all, KEY_SEGMENTS.DETAILS] as const,
  detail: (scope = "main", params = "skipped") =>
    [...flowKeys.details(), scope, params] as const,
};

// Query option factories
export const flowQueries = {
  list: (request: GetAllFlowsRequest, opts?: { _scope?: QueryScope }) => {
    const parsed = getAllFlowsRequestSchema.parse(request);
    return queryOptions<PaginatedResponse<Flow>>({
      queryKey: flowKeys.list(opts?._scope ?? "main", parsed),
      queryFn: async () =>
        apiClient.main.v1.get(`/flows/getAll/workspace/${parsed.path.workspaceId}`, {
          headers: parsed.headers,
          query: parsed.query,
          schema: paginate(flowSchema),
        }),
      placeholderData: keepPreviousData,
    });
  },
  detail: (request: GetFlowByIdRequest, opts?: { _scope?: QueryScope }) => {
    const parsed = getFlowByIdRequestSchema.parse(request);
    return queryOptions<Flow>({
      queryKey: flowKeys.detail(opts?._scope ?? "main", parsed),
      queryFn: async () =>
        apiClient.main.v1.get(`/flows/${parsed.path.flowId}/workspace/${parsed.path.workspaceId}`, {
          headers: parsed.headers,
          schema: flowSchema,
        }),
      staleTime: 10 * 60 * 1000,
      gcTime: 30 * 60 * 1000,
      refetchOnMount: false,
      refetchOnWindowFocus: false,
    });
  },
};
```

**Rules:**
- Key structure: `[domain, resource, "lists"|"details", scope, params]`
- Use `apiClient` (routes through `/api/{service}/...` proxy)
- List queries: `placeholderData: keepPreviousData`
- Detail queries: `staleTime: 10min`, `gcTime: 30min`
- `_scope` param enables multiple independent lists of the same resource

---

## 5. `actions.ts` — Server Actions

```typescript
"use server";

export async function createFlow(
  request: CreateFlowRequest,
): Promise<ApiResult<Flow>> {
  return safeAction(
    async () => {
      const { path, query, data, headers } = createFlowRequestSchema.parse(request);
      return await apiServer.main.v1.post(
        `/flows/create/workspace/${path.workspaceId}`,
        data,
        { query, headers, schema: flowSchema },
      );
    },
    { code: "FLOWS_CREATE_FAILED", message: "Failed to create flow" },
  );
}

export async function deleteFlow(
  request: DeleteFlowRequest,
): Promise<ApiResult<void>> {
  return safeAction(
    async () => {
      const { path, headers } = deleteFlowRequestSchema.parse(request);
      await apiServer.main.v1.delete(
        `/flows/${path.flowId}/workspace/${path.workspaceId}`,
        { headers },
      );
    },
    { code: "FLOWS_DELETE_FAILED", message: "Failed to delete flow" },
  );
}
```

**Rules:**
- `"use server"` directive at top
- ALWAYS wrap in `safeAction(fn, { code, message })`
- Return `Promise<ApiResult<T>>` — never throw
- Use `apiServer` for direct backend calls
- Parse input with schema before use

---

## 6. `use-{resource}.ts` — Client Hooks

**Default: `useSuspenseQuery`.** Components that fetch data use `useSuspenseQuery` and live inside a `<Suspense>` boundary. `useQuery` is a last resort for auth checks, background polling, or optional conditional data.

```typescript
"use client";

// ── Suspense hooks (primary — use these by default) ─────────────

export function useSuspenseFlows(request: GetAllFlowsRequest) {
  return useSuspenseQuery(flowQueries.list(request));
}

export function useSuspenseFlow(request: GetFlowByIdRequest) {
  return useSuspenseQuery(flowQueries.detail(request));
}

// ── useQuery hooks (last resort — auth, polling, optional data) ─

export function useFlows(request?: GetAllFlowsRequest) {
  const options = request ? flowQueries.list(request) : null;
  return useQuery({
    queryKey: options?.queryKey ?? flowKeys.list("skipped"),
    queryFn: options?.queryFn ?? skipToken,
    ...options,
    placeholderData: keepPreviousData,
  });
}

export function useFlow(request?: GetFlowByIdRequest) {
  const options = request ? flowQueries.detail(request) : null;
  return useQuery({
    queryKey: options?.queryKey ?? flowKeys.detail("skipped"),
    queryFn: options?.queryFn ?? skipToken,
    ...options,
  });
}

// ── Mutations ───────────────────────────────────────────────────

export function useCreateFlowMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (request: CreateFlowRequest) => {
      return unwrap(await createFlow(request));
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: flowKeys.all });
    },
  });
}

export function useDeleteFlowMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (request: DeleteFlowRequest) => {
      return unwrap(await deleteFlow(request));
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: flowKeys.all });
    },
  });
}
```

**Rules:**
- `"use client"` directive at top
- **Default to `useSuspenseQuery`** — the Suspense variant is the primary hook for data fetching
- Export `useXxx` (optional request, uses `skipToken`) only for auth checks, background polling, or optional conditional data
- Mutations call server actions, then `unwrap()` the Result to throw on failure
- Invalidate the entire feature key (`flowKeys.all`) on mutation success

---

## 7. `search-params.ts` — URL State

```typescript
import { parseAsString, parseAsStringEnum, createSerializer } from "nuqs/server";

// Resource-specific filter parsers
export const flowFiltersParsers = {
  status: parseAsStringEnum([...FlowStatusEnum.options, "all"] as const)
    .withDefault("all"),
  archive: parseAsStringEnum(["LIVE", "ARCHIVE", "all"] as const)
    .withDefault("all"),
  user: parseAsString.withDefault("all"),
  channel: parseAsString.withDefault("all"),
};

// Full parsers (extend global)
export const flowsParsers = {
  ...globalParsers,           // page, size, sort, search
  ...flowFiltersParsers,
};

export type FlowsSearchParams = inferParserType<typeof flowsParsers>;

// Convert URL params to API query params
export function toFlowsQuery(params: FlowsSearchParams) {
  return {
    page: params.page - 1,      // API is 0-indexed, URL is 1-indexed
    size: params.size,
    flowSort: params.sort.length ? params.sort : undefined,
    searchBy: params.search || undefined,
    statusFilter: params.status !== "all" ? params.status : undefined,
  };
}

export const flowsSerializer = createSerializer(flowsParsers);
```

**Rules:**
- Extend `globalParsers` (page, size, sort, search) for every table resource
- Use `toXxxQuery()` to convert URL param names to API param names
- "all" means "no filter" — convert to `undefined` for the API
- Export serializer for type-safe URL construction
