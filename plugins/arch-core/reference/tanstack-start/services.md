# 6-File Service Resource Convention

Every backend resource lives in `src/services/{service}/{resource}/` and follows the `x.z` naming convention with 6 files.

## File overview

| # | File | Purpose | Runs on |
|---|------|---------|---------|
| 1 | `{resource}.schema.ts` | DTO schemas, enums, create/update schemas | Both |
| 2 | `{resource}.api-schema.ts` | Request shape schemas (path, query, data, headers) | Both |
| 3 | `{resource}.functions.ts` | Server functions (GET + POST) via `createServerFn` | Server |
| 4 | `{resource}.query-options.ts` | TanStack Query key factories and query options | Both |
| 5 | `{resource}.hooks.ts` | Client hooks (useSuspenseQuery, useMutation, useQuery for edge cases) | Client |
| 6 | `{resource}.search-params.ts` | URL state parsers (nuqs) and query converters | Both |

### What changed from Next.js 7-file pattern

The Next.js architecture had separate `queries.ts` (server-only fetch with `cache()`) and `actions.ts` (`"use server"` with `safeAction`). In TanStack Start, both merge into **`{resource}.functions.ts`** using `createServerFn`:

- GET server functions replace `queries.ts`
- POST server functions replace `actions.ts`
- No need for `"server-only"` import or `"use server"` directive — `createServerFn` handles it
- Keep `createServerFn` visible to the compiler; use middleware for shared error handling.
  A handler helper is not a custom factory that hides the server-function boundary.

---

## 1. `{resource}.schema.ts` — DTO Definitions

```typescript
import * as z from "zod";
import { createSchemaFactory, identityTranslate, type TranslateFn } from "~/i18n/zod";

// ── Enums (at the TOP) ──────────────────────────────────────────

export const {RESOURCE}_STATUSES = ["ACTIVE", "ERROR", "ARCHIVED"] as const;
export const {Resource}StatusEnum = z.enum({RESOURCE}_STATUSES);
export type {Resource}Status = z.infer<typeof {Resource}StatusEnum>;

// ── Create schema (factory for i18n) ────────────────────────────

export function createCreate{Resource}Schema(t: TranslateFn) {
  const f = createSchemaFactory(t);
  return z.object({
    name: f.requiredString().max(255, f.maxLength(255)),
    // Add fields...
  });
}
export const create{Resource}Schema = createCreate{Resource}Schema(identityTranslate);
export type Create{Resource} = z.infer<typeof create{Resource}Schema>;

// ── Update schema ───────────────────────────────────────────────

export function createUpdate{Resource}Schema(t: TranslateFn) {
  return createCreate{Resource}Schema(t).partial();
}
export const update{Resource}Schema = createUpdate{Resource}Schema(identityTranslate);
export type Update{Resource} = z.infer<typeof update{Resource}Schema>;

// ── DTO schema ──────────────────────────────────────────────────

export function create{Resource}DtoSchema(t: TranslateFn) {
  return z.object({
    id: z.coerce.string(),
    name: z.string(),
    status: {Resource}StatusEnum,
    createdAt: z.iso.datetime({ local: true }),
    updatedAt: z.iso.datetime({ local: true }).optional(),
  });
}
export const {resource}Schema = create{Resource}DtoSchema(identityTranslate);
export type {Resource} = z.infer<typeof {resource}Schema>;
```

**Rules:**
- Enums go at the top of the file
- Use `z.infer` for all types (post-transform)
- Export type immediately after its schema
- Factory pattern (`createXxxSchema(t)`) for user-facing validation messages
- Export a default instance with `identityTranslate` for non-i18n contexts

---

## 2. `{resource}.api-schema.ts` — Request Schemas

```typescript
import * as z from "zod";
import {
  workspacePathParamsSchema,
  workspaceHeaderSchema,
} from "~/services/_shared/schema/request";
import { querySchema } from "~/services/_shared/schema/query";
import { create{Resource}Schema, {Resource}StatusEnum } from "./{resource}.schema";

// ── Path params ─────────────────────────────────────────────────

const {resource}PathParamsSchema = workspacePathParamsSchema.extend({
  {resource}Id: z.coerce.string(),
});

// ── List request ────────────────────────────────────────────────

export const getAll{Resource}sRequestSchema = z.object({
  path: workspacePathParamsSchema,
  query: querySchema.extend({
    statusFilter: {Resource}StatusEnum.optional(),
  }),
  headers: workspaceHeaderSchema,
});
export type GetAll{Resource}sRequest = z.infer<typeof getAll{Resource}sRequestSchema>;

// ── Detail request ──────────────────────────────────────────────

export const get{Resource}ByIdRequestSchema = z.object({
  path: {resource}PathParamsSchema,
  headers: workspaceHeaderSchema,
});
export type Get{Resource}ByIdRequest = z.infer<typeof get{Resource}ByIdRequestSchema>;

// ── Create request ──────────────────────────────────────────────

export const create{Resource}RequestSchema = z.object({
  path: workspacePathParamsSchema,
  data: create{Resource}Schema,
  headers: workspaceHeaderSchema,
});
export type Create{Resource}Request = z.infer<typeof create{Resource}RequestSchema>;

// ── Update request ──────────────────────────────────────────────

export const update{Resource}RequestSchema = z.object({
  path: {resource}PathParamsSchema,
  data: create{Resource}Schema.partial(),
  headers: workspaceHeaderSchema,
});
export type Update{Resource}Request = z.infer<typeof update{Resource}RequestSchema>;

// ── Delete request ──────────────────────────────────────────────

export const delete{Resource}RequestSchema = z.object({
  path: {resource}PathParamsSchema,
  headers: workspaceHeaderSchema,
});
export type Delete{Resource}Request = z.infer<typeof delete{Resource}RequestSchema>;
```

**Rules:**
- Request shape is always `{ path, query, data, headers }` (omit unused fields)
- Extend shared schemas (`workspacePathParamsSchema`, `workspaceHeaderSchema`)
- Use `z.infer` (these are already-parsed types)

---

## 3. `{resource}.functions.ts` — Server Functions

This file replaces both `queries.ts` and `actions.ts` from the Next.js architecture.

```typescript
import { createServerFn } from "@tanstack/react-start";
import { apiFetch } from "~/services/_shared/fetch-client/api-fetch";
import { paginate } from "~/services/_shared/schema/paginate";
import { {resource}Schema } from "./{resource}.schema";
import {
  getAll{Resource}sRequestSchema,
  get{Resource}ByIdRequestSchema,
  create{Resource}RequestSchema,
  update{Resource}RequestSchema,
  delete{Resource}RequestSchema,
  type GetAll{Resource}sRequest,
  type Get{Resource}ByIdRequest,
  type Create{Resource}Request,
  type Update{Resource}Request,
  type Delete{Resource}Request,
} from "./{resource}.api-schema";

// ── GET: List ───────────────────────────────────────────────────

export const getAll{Resource}s = createServerFn({ method: "GET" })
  .inputValidator(getAll{Resource}sRequestSchema)
  .handler(async ({ data: { path, query, headers } }) => {
    return apiFetch.{service}.v1.get(`/{path}/getAll/workspace/${path.workspaceId}`, {
      headers,
      query,
      schema: paginate({resource}Schema),
    });
  });

// ── GET: Detail ─────────────────────────────────────────────────

export const get{Resource}ById = createServerFn({ method: "GET" })
  .inputValidator(get{Resource}ByIdRequestSchema)
  .handler(async ({ data: { path, headers } }) => {
    return apiFetch.{service}.v1.get(
      `/{path}/${path.{resource}Id}/workspace/${path.workspaceId}`,
      { headers, schema: {resource}Schema },
    );
  });

// ── POST: Create ────────────────────────────────────────────────

export const create{Resource} = createServerFn({ method: "POST" })
  .inputValidator(create{Resource}RequestSchema)
  .handler(async ({ data: { path, data, headers } }) => {
    return apiFetch.{service}.v1.post(
      `/{path}/create/workspace/${path.workspaceId}`,
      data,
      { headers, schema: {resource}Schema },
    );
  });

// ── POST: Update ────────────────────────────────────────────────

export const update{Resource} = createServerFn({ method: "POST" })
  .inputValidator(update{Resource}RequestSchema)
  .handler(async ({ data: { path, data, headers } }) => {
    return apiFetch.{service}.v1.put(
      `/{path}/${path.{resource}Id}/workspace/${path.workspaceId}`,
      data,
      { headers, schema: {resource}Schema },
    );
  });

// ── POST: Delete ────────────────────────────────────────────────

export const delete{Resource} = createServerFn({ method: "POST" })
  .inputValidator(delete{Resource}RequestSchema)
  .handler(async ({ data: { path, headers } }) => {
    await apiFetch.{service}.v1.delete(
      `/{path}/${path.{resource}Id}/workspace/${path.workspaceId}`,
      { headers },
    );
  });
```

**Rules:**
- Use `createServerFn({ method: "GET" })` for reads, `{ method: "POST" }` for mutations
- Always validate input with `.inputValidator(schema)` — Zod schemas are passed directly via Standard Schema support
- Server functions can be called from route loaders, components, or other server functions
- Server functions automatically hide backend URLs — no proxy needed
- Auth tokens are attached inside `apiFetch` using `getWebRequest()` headers/cookies

---

## 4. `{resource}.query-options.ts` — TanStack Query Factories

```typescript
import {
  queryOptions,
  keepPreviousData,
} from "@tanstack/react-query";
import { KEY_SEGMENTS, type QueryScope } from "~/services/_shared/query-keys";
import type { PaginatedResponse } from "~/services/_shared/schema/paginate";
import { type {Resource} } from "./{resource}.schema";
import {
  getAll{Resource}sRequestSchema,
  get{Resource}ByIdRequestSchema,
  type GetAll{Resource}sRequest,
  type Get{Resource}ByIdRequest,
} from "./{resource}.api-schema";
import { getAll{Resource}s, get{Resource}ById } from "./{resource}.functions";

export const {resource}Keys = {
  all: ["{module}", "{resources}"] as const,
  lists: () => [...{resource}Keys.all, KEY_SEGMENTS.LISTS] as const,
  list: (scope: QueryScope = "main", params: unknown = KEY_SEGMENTS.SKIPPED) =>
    [...{resource}Keys.lists(), scope, params] as const,
  details: () => [...{resource}Keys.all, KEY_SEGMENTS.DETAILS] as const,
  detail: (scope: QueryScope = "main", params: unknown = KEY_SEGMENTS.SKIPPED) =>
    [...{resource}Keys.details(), scope, params] as const,
};

export const {resource}Queries = {
  list: (request: GetAll{Resource}sRequest, opts?: { _scope?: QueryScope }) => {
    const parsed = getAll{Resource}sRequestSchema.parse(request);
    return queryOptions<PaginatedResponse<{Resource}>>({
      queryKey: {resource}Keys.list(opts?._scope ?? "main", parsed),
      queryFn: () => getAll{Resource}s({ data: request }),
      placeholderData: keepPreviousData,
    });
  },

  detail: (request: Get{Resource}ByIdRequest, opts?: { _scope?: QueryScope }) => {
    const parsed = get{Resource}ByIdRequestSchema.parse(request);
    return queryOptions<{Resource}>({
      queryKey: {resource}Keys.detail(opts?._scope ?? "main", parsed),
      queryFn: () => get{Resource}ById({ data: request }),
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
- `queryFn` calls server functions directly — no `apiClient` proxy needed
- List queries: `placeholderData: keepPreviousData`
- Detail queries: `staleTime: 10min`, `gcTime: 30min`
- `_scope` param enables multiple independent lists of the same resource

---

## 5. `{resource}.hooks.ts` — Client Hooks

**Default: `useSuspenseQuery`.** Components that fetch data should use `useSuspenseQuery` and be wrapped in a `<Suspense>` boundary. This guarantees `data` is always defined and pushes loading states to the nearest boundary.

```typescript
import {
  useSuspenseQuery,
  useQuery,
  useMutation,
  useQueryClient,
  skipToken,
  keepPreviousData,
} from "@tanstack/react-query";
import { {resource}Keys, {resource}Queries } from "./{resource}.query-options";
import { create{Resource}, update{Resource}, delete{Resource} } from "./{resource}.functions";
import type {
  GetAll{Resource}sRequest,
  Get{Resource}ByIdRequest,
  Create{Resource}Request,
  Update{Resource}Request,
  Delete{Resource}Request,
} from "./{resource}.api-schema";

// ── List hooks (prefer Suspense variant) ────────────────────────

export function useSuspense{Resource}s(request: GetAll{Resource}sRequest) {
  return useSuspenseQuery({resource}Queries.list(request));
}

export function useSuspense{Resource}(request: Get{Resource}ByIdRequest) {
  return useSuspenseQuery({resource}Queries.detail(request));
}

// ── useQuery — last resort (see "When to use useQuery" below) ──

export function use{Resource}s(request?: GetAll{Resource}sRequest) {
  const options = request ? {resource}Queries.list(request) : null;
  return useQuery({
    queryKey: options?.queryKey ?? {resource}Keys.list("skipped"),
    queryFn: options?.queryFn ?? skipToken,
    ...options,
    placeholderData: keepPreviousData,
  });
}

export function use{Resource}(request?: Get{Resource}ByIdRequest) {
  const options = request ? {resource}Queries.detail(request) : null;
  return useQuery({
    queryKey: options?.queryKey ?? {resource}Keys.detail("skipped"),
    queryFn: options?.queryFn ?? skipToken,
    ...options,
  });
}

// ── Mutation hooks ──────────────────────────────────────────────

export function useCreate{Resource}Mutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (request: Create{Resource}Request) =>
      create{Resource}({ data: request }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: {resource}Keys.all });
    },
  });
}

export function useUpdate{Resource}Mutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (request: Update{Resource}Request) =>
      update{Resource}({ data: request }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: {resource}Keys.all });
    },
  });
}

export function useDelete{Resource}Mutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (request: Delete{Resource}Request) =>
      delete{Resource}({ data: request }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: {resource}Keys.all });
    },
  });
}
```

**Rules:**
- **Default to `useSuspenseQuery`** — the Suspense variant is the primary hook for all data fetching
- Export `useXxx` (optional request, uses `skipToken`) only for edge cases (see below)
- Mutations call server functions directly — no `unwrap()` needed (server functions throw on error)
- Invalidate the entire feature key (`{resource}Keys.all`) on mutation success

### When to use `useQuery` (last resort)

`useQuery` is acceptable ONLY for these cases:

| Case | Why `useQuery` | Example |
|------|----------------|---------|
| Auth state check | Need `isLoading`/`isError` to decide routing before any UI renders | `useSession()` in auth guard |
| Background polling | Data refreshes silently, should not trigger Suspense fallback | WebSocket fallback polling |
| Optional/conditional data | Request may be `undefined`, component still renders without it | Sidebar widget that degrades gracefully |

For everything else, use `useSuspenseQuery` + `<Suspense>` boundary.

---

## 6. `{resource}.search-params.ts` — URL State

```typescript
import {
  parseAsString,
  parseAsStringEnum,
  createSerializer,
  type inferParserType,
} from "nuqs/server";
import { globalParsers } from "~/services/_shared/search-params";
import { {Resource}StatusEnum, type {Resource}Status } from "./{resource}.schema";

// ── Resource-specific filter parsers ────────────────────────────

export const {resource}FiltersParsers = {
  status: parseAsStringEnum([...{Resource}StatusEnum.options, "all"] as const)
    .withDefault("all"),
  // Add more filters as needed...
};

// ── Full parsers (extend global) ────────────────────────────────

export const {resources}Parsers = {
  ...globalParsers,
  ...{resource}FiltersParsers,
};

export type {Resource}sSearchParams = inferParserType<typeof {resources}Parsers>;

// ── URL → API query converter ───────────────────────────────────

export function to{Resource}sQuery(params: {Resource}sSearchParams) {
  return {
    page: params.page - 1,          // API is 0-indexed, URL is 1-indexed
    size: params.size,
    sort: params.sort.length ? params.sort : undefined,
    searchBy: params.search || undefined,
    statusFilter: params.status !== "all" ? (params.status as {Resource}Status) : undefined,
  };
}

// ── Serializer for type-safe URL construction ───────────────────

export const {resources}Serializer = createSerializer({resources}Parsers);
```

**Rules:**
- Extend `globalParsers` (page, size, sort, search) for every table resource
- Use `to{Resource}sQuery()` to convert URL param names to API param names
- "all" means "no filter" — convert to `undefined` for the API
- Export serializer for type-safe URL construction
